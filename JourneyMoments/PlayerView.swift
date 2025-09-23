import SwiftUI
import AVFoundation
import Photos

struct PlayerView: View {
    @ObservedObject var projectManager: ProjectManager
    let initialProject: Project
    let onBack: () -> Void
    let onDeleteSegment: (Project, VideoSegment) -> Void
    
    // Dynamically get current project
    private var project: Project {
        return projectManager.projects.first { $0.id == initialProject.id } ?? initialProject
    }
    
    @State private var player = AVPlayer()
    @State private var currentSegmentIndex = 0
    @State private var isPlaying = false
    @State private var showControls = true
    @State private var playerItem: AVPlayerItem?
    @State private var playbackTimer: Timer?
    @State private var autoHideTimer: Timer?
    @State private var currentTime: Double = 0
    @State private var duration: Double = 1.0
    @State private var timeObserver: Any?
    
    // Segment deletion state management
    @State private var showDeleteSegmentAlert = false
    @State private var segmentToDelete: VideoSegment?
    
    // Seamless playback state management
    @State private var useSeamlessPlayback = true  // Default to seamless playback
    @State private var composition: AVComposition?
    @State private var segmentTimeRanges: [(segment: VideoSegment, timeRange: CMTimeRange)] = []
    
    // Export functionality state management
    @State private var showExportAlert = false
    @State private var isExporting = false
    @State private var exportProgress: Float = 0.0
    @State private var exportError: String?
    @State private var showExportSuccess = false
    
    // Loading functionality state management
    @State private var isLoadingComposition = false
    @State private var loadingProgress: Double = 0.0
    @State private var loadingMessage: String = "Preparing playback..."
    @State private var processedSegments: Int = 0
    @State private var loadingStartTime = Date()
    
    private var hasSegments: Bool {
        !project.segments.isEmpty
    }
    
    private var currentSegment: VideoSegment? {
        guard hasSegments, currentSegmentIndex >= 0, currentSegmentIndex < project.segments.count else {
            print("Current segment index out of range: \(currentSegmentIndex) / \(project.segments.count)")
            return nil
        }
        return project.segments[currentSegmentIndex]
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if hasSegments {
                customPlayerView
            } else {
                emptyStateView
            }
            
            // Always display controls in front
            VStack {
                headerView
                Spacer()
                if hasSegments {
                    playbackControls
                }
            }
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.6), Color.clear, Color.black.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            // Loading overlay
            if isLoadingComposition {
                loadingOverlay
            }
        }
        .onAppear {
            setupPlayer()
            print("PlayerView display started")
        }
        .onDisappear {
            cleanupPlayer()
        }
        .navigationBarHidden(true)
        .alert("Delete Segment", isPresented: $showDeleteSegmentAlert) {
            Button("Delete", role: .destructive) {
                if let segment = segmentToDelete {
                    handleSegmentDeletion(segment)
                }
                resetDeleteState()
            }
            Button("Cancel", role: .cancel) {
                resetDeleteState()
            }
        } message: {
            if let segment = segmentToDelete {
                Text("Delete Segment \(segment.order)?\nThis action cannot be undone.")
            }
        }
        .alert("Export Status", isPresented: $showExportAlert) {
            Button("OK") {
                exportError = nil
            }
        } message: {
            if let error = exportError {
                Text("Export failed: \(error)")
            }
        }
        .alert("Export Successful", isPresented: $showExportSuccess) {
            Button("OK") { }
        } message: {
            Text("Video has been saved to your photo library!")
        }
    }
    
    // MARK: - Loading Overlay
    private var loadingOverlay: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Loading animation
                VStack(spacing: 16) {
                    // Rotating icon
                    Image(systemName: "gearshape.2")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(loadingProgress * 360))
                        .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: loadingProgress)
                    
                    // Main message
                    Text(loadingMessage)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    // Segment processing status
                    Text("\(processedSegments) / \(project.segments.count) segments")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .monospacedDigit()
                }
                
                // Progress bar
                VStack(spacing: 8) {
                    // Progress bar body
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 8)
                                .cornerRadius(4)
                            
                            // Progress
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * loadingProgress, height: 8)
                                .cornerRadius(4)
                                .animation(.easeInOut(duration: 0.3), value: loadingProgress)
                        }
                    }
                    .frame(height: 8)
                    
                    // Percentage display
                    HStack {
                        Text("Progress")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Text("\(Int(loadingProgress * 100))%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .monospacedDigit()
                    }
                }
                
                // Estimated remaining time (optional)
                if loadingProgress > 0.1 {
                    let estimatedTimeRemaining = estimateRemainingTime()
                    if estimatedTimeRemaining > 0 {
                        Text("Estimated time: \(Int(estimatedTimeRemaining))s remaining")
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .italic()
                    }
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.9))
                    .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Custom Player View
    private var customPlayerView: some View {
        VideoPlayerView(player: player)
            .ignoresSafeArea()
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "video.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No videos to play")
                .font(.title2)
                .foregroundColor(.white)
            
            Text("Please record videos in camera view")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 10) {
            HStack {
                Button(action: {
                    print("Back button tapped")
                    onBack()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.9))
                    .foregroundColor(.black)
                    .cornerRadius(15)
                }
                
                Spacer()
                
                // Playback mode display
                HStack(spacing: 8) {
                    
                    
                    if hasSegments {
                        Text("\(currentSegmentIndex + 1) / \(project.segments.count)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(15)
                    }
                }
            }
            .padding(.horizontal, 20)
            
            Text(project.name)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .shadow(color: .black, radius: 2, x: 1, y: 1)
        }
        .padding(.top, 60)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Playback Controls
    private var playbackControls: some View {
        VStack(spacing: 20) {
            progressView
            
            // Export progress display (during export only)
            if isExporting {
                exportProgressView
            }
            
            mainControls
            
           
            
            segmentInfoWithDelete
        }
        .padding(.bottom, 50)
    }
    
    // MARK: - Progress View (with seek functionality)
    private var progressView: some View {
        VStack(spacing: 8) {
            HStack {
                Text(timeString(from: currentTime))
                    .foregroundColor(.white)
                    .font(.caption)
                    .monospacedDigit()
                
                Spacer()
                
                Text(timeString(from: duration))
                    .foregroundColor(.white)
                    .font(.caption)
                    .monospacedDigit()
            }
            
            // Seekable progress bar
            if useSeamlessPlayback && !segmentTimeRanges.isEmpty {
                // Seek functionality only available in seamless playback
                seekableProgressBar
            } else {
                // Traditional progress bar for individual playback
                ProgressView(value: currentTime, total: duration)
                    .progressViewStyle(LinearProgressViewStyle(tint: .white))
                    .scaleEffect(y: 2)
            }
        }
        .padding(.horizontal, 40)
    }
    
    // MARK: - Seekable Progress Bar
    private var seekableProgressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background bar
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 4)
                    .cornerRadius(2)
                
                // Progress bar
                Rectangle()
                    .fill(Color.white)
                    .frame(width: max(0, geometry.size.width * (currentTime / duration)), height: 4)
                    .cornerRadius(2)
                
                // Segment divider lines (lightly displayed)
                ForEach(0..<segmentTimeRanges.count, id: \.self) { index in
                    if index > 0 { // No line for first segment
                        let segmentStartTime = segmentTimeRanges[index].timeRange.start.seconds
                        let xPosition = geometry.size.width * (segmentStartTime / duration)
                        
                        Rectangle()
                            .fill(Color.yellow.opacity(0.6))
                            .frame(width: 1, height: 8)
                            .position(x: xPosition, y: 4)
                    }
                }
                
                // Seek handle
                Circle()
                    .fill(Color.white)
                    .frame(width: 12, height: 12)
                    .position(
                        x: max(6, min(geometry.size.width - 6, geometry.size.width * (currentTime / duration))),
                        y: 4
                    )
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            }
            .contentShape(Rectangle()) // Expand tap area to entire area
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        // Handle during drag
                        handleSeekGesture(
                            location: value.location,
                            geometryWidth: geometry.size.width,
                            isDragging: true
                        )
                    }
                    .onEnded { value in
                        // Handle when drag ends
                        handleSeekGesture(
                            location: value.location,
                            geometryWidth: geometry.size.width,
                            isDragging: false
                        )
                    }
            )
            .onTapGesture { location in
                // Handle tap
                handleSeekGesture(
                    location: location,
                    geometryWidth: geometry.size.width,
                    isDragging: false
                )
            }
        }
        .frame(height: 20)
    }
    
    // MARK: - Seek Gesture Handler
    private func handleSeekGesture(location: CGPoint, geometryWidth: CGFloat, isDragging: Bool) {
        // Only available in seamless mode
        guard useSeamlessPlayback, !segmentTimeRanges.isEmpty else {
            print("Seek not available - not in seamless mode")
            return
        }
        
        // Calculate time from tap position
        let tapProgress = max(0, min(1, location.x / geometryWidth))
        let targetTime = tapProgress * duration
        
        // Identify target segment
        var targetSegmentIndex = 0
        for (index, (_, timeRange)) in segmentTimeRanges.enumerated() {
            let segmentStartTime = timeRange.start.seconds
            let segmentEndTime = (timeRange.start + timeRange.duration).seconds
            
            if targetTime >= segmentStartTime && targetTime < segmentEndTime {
                targetSegmentIndex = index
                break
            } else if targetTime >= segmentEndTime && index == segmentTimeRanges.count - 1 {
                // If beyond last segment range
                targetSegmentIndex = index
                break
            }
        }
        
        // Log segment change
        if targetSegmentIndex != currentSegmentIndex {
            print("Seek: Segment \(currentSegmentIndex + 1) → \(targetSegmentIndex + 1)")
        }
        
        // Update current segment index
        currentSegmentIndex = targetSegmentIndex
        
        // Seek player
        if targetSegmentIndex < segmentTimeRanges.count {
            let targetCMTime = segmentTimeRanges[targetSegmentIndex].timeRange.start
            player.seek(to: targetCMTime) { _ in
                // Post-seek processing
                if !isDragging {
                    print("Seek completed to Segment \(targetSegmentIndex + 1)")
                }
            }
        }
        
        // Feedback (can add haptics in future)
        if !isDragging {
            print("Jumped to Segment \(targetSegmentIndex + 1)/\(segmentTimeRanges.count)")
        }
    }
    
    // MARK: - Export Progress View
    private var exportProgressView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Exporting...")
                    .foregroundColor(.white)
                    .font(.caption)
                
                Spacer()
                
                Text("\(Int(exportProgress * 100))%")
                    .foregroundColor(.white)
                    .font(.caption)
                    .monospacedDigit()
            }
            
            ProgressView(value: exportProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                .scaleEffect(y: 2)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.8))
        .cornerRadius(10)
    }
    
    // MARK: - Export Button
    private var exportButton: some View {
        Button(action: {
            print("Export button tapped")
            requestPhotoLibraryPermission()
        }) {
            HStack(spacing: 6) {
                Image(systemName: isExporting ? "arrow.down.circle" : "square.and.arrow.up")
                    .font(.title3)
                Text(isExporting ? "Exporting..." : "Export Video")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                isExporting ? Color.orange.opacity(0.8) : Color.blue.opacity(0.8)
            )
            .foregroundColor(.white)
            .cornerRadius(12)
            .disabled(isExporting || !hasSegments)
        }
        .opacity(hasSegments ? 1.0 : 0.6)
    }
    
    // MARK: - Main Controls
    private var mainControls: some View {
        HStack(spacing: 40) {
            // Previous segment
            Button(action: {
                print("Previous segment button tapped")
                previousSegment()
            }) {
                Image(systemName: "backward.fill")
                    .font(.title)
                    .foregroundColor(currentSegmentIndex > 0 ? .white : .gray)
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(25)
            }
            .disabled(currentSegmentIndex <= 0)
            
            // Play/pause
            Button(action: {
                print("Play/Pause button tapped")
                togglePlayback()
            }) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(30)
            }
            
            // Next segment
            Button(action: {
                print("Next segment button tapped")
                nextSegment()
            }) {
                Image(systemName: "forward.fill")
                    .font(.title)
                    .foregroundColor(currentSegmentIndex < project.segments.count - 1 ? .white : .gray)
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(25)
            }
            .disabled(currentSegmentIndex >= project.segments.count - 1)
        }
    }
    
    // MARK: - Segment Info with Delete
    private var segmentInfoWithDelete: some View {
        VStack(spacing: 8) {
            if let segment = currentSegment {
                VStack(spacing: 4) {
                    Text("Segment \(segment.order)")
                        .font(.caption)
                        .foregroundColor(.yellow)
                        .fontWeight(.semibold)
                    
                    Text(formatDate(segment.timestamp))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                if project.segments.count > 1 {
                    Button(action: {
                        print("Delete segment button tapped: Segment \(segment.order)")
                        segmentToDelete = segment
                        showDeleteSegmentAlert = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash.fill")
                                .font(.caption2)
                            Text("Delete Segment")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                } else {
                    Text("Cannot delete last segment")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .italic()
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.6))
        .cornerRadius(10)
    }
    
    // MARK: - Helper Functions
    
    // Estimate remaining time
    private func estimateRemainingTime() -> Double {
        guard loadingProgress > 0.1 else { return 0 }
        
        // Calculate estimated remaining time from current progress
        let elapsedTime = Date().timeIntervalSince(loadingStartTime)
        let totalEstimatedTime = elapsedTime / loadingProgress
        let remainingTime = totalEstimatedTime - elapsedTime
        
        return max(0, remainingTime)
    }
    
    // Create Composition with progress
    private func createCompositionWithProgress() async -> AVComposition? {
        return await withCheckedContinuation { continuation in
            Task {
                let result = await projectManager.createCompositionWithProgress(
                    for: project,
                    progressCallback: { processed, total in
                        // Update progress on main thread
                        DispatchQueue.main.async {
                            self.processedSegments = processed
                            self.loadingProgress = Double(processed) / Double(total) * 0.8 // Up to 80%
                            
                            if processed % 10 == 0 || processed == total {
                                print("Composition progress: \(processed)/\(total) (\(Int(self.loadingProgress * 100))%)")
                            }
                        }
                    }
                )
                continuation.resume(returning: result)
            }
        }
    }
    
    // MARK: - Export Functions
    
    // Request photo library access permission
    private func requestPhotoLibraryPermission() {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        switch status {
        case .authorized:
            startExport()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized {
                        self.startExport()
                    } else {
                        self.showExportAlert = true
                        self.exportError = "Photo library access denied"
                    }
                }
            }
        case .denied, .restricted:
            showExportAlert = true
            exportError = "Photo library access denied. Please enable in Settings."
        case .limited:
            startExport() // Export still possible with limited access
        @unknown default:
            showExportAlert = true
            exportError = "Unknown authorization status"
        }
    }
    
    // Start export process
    private func startExport() {
        print("Starting export process")
        
        // Set exporting state
        isExporting = true
        exportProgress = 0.0
        exportError = nil
        
        Task {
            do {
                let success = await exportVideo()
                
                await MainActor.run {
                    self.isExporting = false
                    
                    if success {
                        self.showExportSuccess = true
                        print("Export completed successfully")
                    } else {
                        self.showExportAlert = true
                        self.exportError = "Export failed"
                        print("Export failed")
                    }
                }
            } catch {
                await MainActor.run {
                    self.isExporting = false
                    self.showExportAlert = true
                    self.exportError = error.localizedDescription
                    print("Export error: \(error)")
                }
            }
        }
    }
    
    // Actual video export process
    private func exportVideo() async -> Bool {
        print("Creating composition for export")
        
        // Use existing composition or create new one
        var exportComposition: AVComposition
        
        if let existingComposition = composition {
            exportComposition = existingComposition
            print("Using existing composition")
        } else {
            guard let newComposition = await projectManager.createComposition(for: project) else {
                print("Failed to create composition for export")
                return false
            }
            exportComposition = newComposition
            print("Created new composition for export")
        }
        
        // Create output file URL
        let outputURL = createExportURL()
        
        // Remove existing file if present
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }
        
        // Create AVAssetExportSession
        guard let exportSession = AVAssetExportSession(
            asset: exportComposition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            print("Failed to create export session")
            return false
        }
        
        // Export settings
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        print("Export settings:")
        print("   Output URL: \(outputURL.lastPathComponent)")
        print("   Preset: \(AVAssetExportPresetHighestQuality)")
        print("   File Type: MP4")
        
        // Start progress monitoring
        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            DispatchQueue.main.async {
                self.exportProgress = exportSession.progress
            }
        }
        
        // Execute export
        await withCheckedContinuation { continuation in
            exportSession.exportAsynchronously {
                DispatchQueue.main.async {
                    progressTimer.invalidate()
                    self.exportProgress = 1.0
                }
                continuation.resume()
            }
        }
        
        // Check export result
        switch exportSession.status {
        case .completed:
            print("Export session completed")
            return await saveToPhotoLibrary(url: outputURL)
        case .failed:
            print("Export session failed: \(exportSession.error?.localizedDescription ?? "Unknown error")")
            return false
        case .cancelled:
            print("Export session cancelled")
            return false
        default:
            print("Export session unknown status: \(exportSession.status)")
            return false
        }
    }
    
    // Generate export file URL
    private func createExportURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timestamp = DateFormatter().apply {
            $0.dateFormat = "yyyyMMdd_HHmmss"
        }.string(from: Date())
        
        // Replace special characters that could cause export issues
        let safeProjectName = project.name.replacingOccurrences(of: "/", with: "_")
                                         .replacingOccurrences(of: "\\", with: "_")
                                         .replacingOccurrences(of: ":", with: "_")
                                         .replacingOccurrences(of: "*", with: "_")
                                         .replacingOccurrences(of: "?", with: "_")
                                         .replacingOccurrences(of: "\"", with: "_")
                                         .replacingOccurrences(of: "<", with: "_")
                                         .replacingOccurrences(of: ">", with: "_")
                                         .replacingOccurrences(of: "|", with: "_")
                                         .replacingOccurrences(of: " ", with: "_")
        
        let filename = "\(safeProjectName)_\(timestamp).mp4"
        return documentsPath.appendingPathComponent(filename)
    }
    
    // Save to photo library
    private func saveToPhotoLibrary(url: URL) async -> Bool {
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }) { success, error in
                if success {
                    print("Video saved to photo library: \(url.lastPathComponent)")
                    // Remove temporary file
                    try? FileManager.default.removeItem(at: url)
                    continuation.resume(returning: true)
                } else {
                    print("Failed to save to photo library: \(error?.localizedDescription ?? "Unknown error")")
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    // MARK: - Player Setup Functions
    
    private func setupPlayer() {
        print("PlayerView setup started - Mode: \(useSeamlessPlayback ? "Seamless" : "Individual")")
        
        if useSeamlessPlayback {
            loadComposition()
        } else {
            loadCurrentSegment()
        }
    }
    
    // Setup AVComposition integrated playback (with progress display)
    private func loadComposition() {
        print("Loading composition for seamless playback")
        
        // Start loading state
        isLoadingComposition = true
        loadingProgress = 0.0
        loadingMessage = "Preparing seamless playback..."
        processedSegments = 0
        loadingStartTime = Date()
        
        Task {
            // Create Composition with progress
            guard let newComposition = await createCompositionWithProgress() else {
                print("Failed to create composition")
                
                await MainActor.run {
                    // End loading
                    isLoadingComposition = false
                    
                    // Fallback to individual playback
                    useSeamlessPlayback = false
                    loadCurrentSegment()
                }
                return
            }
            
            // Get segment time ranges
            await MainActor.run {
                loadingMessage = "Finalizing playback setup..."
                loadingProgress = 0.9
            }
            
            segmentTimeRanges = await projectManager.getSegmentTimeRanges(for: project)
            
            // Update UI on main thread
            await MainActor.run {
                // Remove existing observers
                removeTimeObserver()
                NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
                
                // Create new player item
                let newPlayerItem = AVPlayerItem(asset: newComposition)
                
                // Monitor overall playback completion
                NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: newPlayerItem,
                    queue: .main
                ) { _ in
                    print("Composition playback completed")
                    self.handleCompositionEnd()
                }
                
                composition = newComposition
                player.replaceCurrentItem(with: newPlayerItem)
                playerItem = newPlayerItem
                
                // Prepare for playback
                player.pause()
                isPlaying = false
                currentTime = 0
                duration = newComposition.duration.seconds
                
                // Final progress update
                loadingProgress = 1.0
                loadingMessage = "Ready to play!"
                
                print("Composition loaded successfully")
                print("Total composition duration: \(duration)s")
                print("Segment time ranges: \(segmentTimeRanges.count)")
                
                // Start time monitoring
                startTimeObserver()
                
                // Update current segment index
                updateCurrentSegmentIndex()
                
                // End loading after short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.isLoadingComposition = false
                }
            }
        }
    }
    
    // Update current segment for integrated playback
    private func updateCurrentSegmentIndex() {
        let currentPlayerTime = player.currentTime()
        
        for (index, (_, timeRange)) in segmentTimeRanges.enumerated() {
            if CMTimeRangeContainsTime(timeRange, time: currentPlayerTime) {
                if currentSegmentIndex != index {
                    currentSegmentIndex = index
                    print("Current segment updated to: \(index + 1)")
                }
                break
            }
        }
    }
    
    // Handle integrated playback completion
    private func handleCompositionEnd() {
        print("Composition playback completed - Returning to start")
        player.seek(to: .zero)
        currentSegmentIndex = 0
        isPlaying = false
        print("Stopped - Press play button to replay")
    }
    
    // Existing individual segment playback (for compatibility)
    private func loadCurrentSegment() {
        guard let segment = currentSegment else {
            print("No segment to play")
            return
        }
        
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        removeTimeObserver()
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL: URL
        
        if !segment.uri.hasPrefix("/") {
            fileURL = documentsPath.appendingPathComponent(segment.uri)
        } else {
            fileURL = URL(fileURLWithPath: segment.uri)
        }
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("File not found: \(fileURL.path)")
            return
        }
        
        let newPlayerItem = AVPlayerItem(url: fileURL)
        
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: newPlayerItem,
            queue: .main
        ) { _ in
            print("Segment playback completed - Segment \(self.currentSegmentIndex + 1)")
            self.handleSegmentEnd()
        }
        
        player.replaceCurrentItem(with: newPlayerItem)
        playerItem = newPlayerItem
        
        player.pause()
        isPlaying = false
        currentTime = 0
        
        print("Segment loaded: \(segment.order), File: \(fileURL.lastPathComponent)")
        
        startTimeObserver()
    }
    
    // Existing individual segment completion handling
    private func handleSegmentEnd() {
        print("Segment playback ended - Current: \(currentSegmentIndex + 1)/\(project.segments.count)")
        
        if currentSegmentIndex < project.segments.count - 1 {
            print("Auto advancing to next segment")
            let nextIndex = currentSegmentIndex + 1
            print("Advancing to: Segment \(nextIndex + 1)")
            
            currentSegmentIndex = nextIndex
            loadCurrentSegment()
            
            isPlaying = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                print("Auto playback executing: Segment \(self.currentSegmentIndex + 1)")
                self.player.play()
                print("Auto playback continued")
            }
        } else {
            print("All segments completed - Returning to first segment")
            currentSegmentIndex = 0
            loadCurrentSegment()
            isPlaying = false
            print("Returned to first segment (1st)")
            print("Stopped - Press play button to replay")
        }
    }
    
    // MARK: - Control Functions
    
    private func togglePlayback() {
        if isPlaying {
            player.pause()
            isPlaying = false
            print("Playback paused")
        } else {
            player.play()
            isPlaying = true
            print("Playback started")
        }
    }
    
    private func previousSegment() {
        if useSeamlessPlayback {
            // Segment navigation in integrated playback
            guard currentSegmentIndex > 0 else {
                print("No previous segment available")
                return
            }
            
            currentSegmentIndex -= 1
            if currentSegmentIndex < segmentTimeRanges.count {
                let targetTime = segmentTimeRanges[currentSegmentIndex].timeRange.start
                player.seek(to: targetTime)
                print("Seamless: Previous segment: \(currentSegmentIndex + 1)")
            }
        } else {
            // Segment navigation in individual playback
            guard currentSegmentIndex > 0 else {
                print("No previous segment available")
                return
            }
            
            currentSegmentIndex -= 1
            loadCurrentSegment()
            
            if isPlaying {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.player.play()
                }
            }
            print("Individual: Previous segment: \(currentSegmentIndex + 1)")
        }
    }
    
    private func nextSegment() {
        if useSeamlessPlayback {
            // Segment navigation in integrated playback
            guard currentSegmentIndex < project.segments.count - 1 else {
                print("No next segment available")
                return
            }
            
            currentSegmentIndex += 1
            if currentSegmentIndex < segmentTimeRanges.count {
                let targetTime = segmentTimeRanges[currentSegmentIndex].timeRange.start
                player.seek(to: targetTime)
                print("Seamless: Next segment: \(currentSegmentIndex + 1)")
            }
        } else {
            // Segment navigation in individual playback
            guard currentSegmentIndex < project.segments.count - 1 else {
                print("No next segment available")
                return
            }
            
            currentSegmentIndex += 1
            loadCurrentSegment()
            
            if isPlaying {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.player.play()
                }
            }
            print("Individual: Next segment: \(currentSegmentIndex + 1)")
        }
    }
    
    // MARK: - Segment Deletion
    
    private func handleSegmentDeletion(_ segment: VideoSegment) {
        print("Starting segment deletion: Segment \(segment.order)")
        
        // Record playback mode before deletion
        let wasSeamless = useSeamlessPlayback
        
        // Switch to individual playback if in integrated playback
        if useSeamlessPlayback {
            print("Switching to individual playback for deletion")
            useSeamlessPlayback = false
            player.pause()
            isPlaying = false
        }
        
        // Record state before deletion
        let segmentCountBeforeDeletion = project.segments.count
        let currentIndexBeforeDeletion = currentSegmentIndex
        
        // Delegate deletion to main screen
        onDeleteSegment(project, segment)
        
        // Post-deletion processing - wait a bit for project update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let updatedSegmentCount = self.project.segments.count
            print("Segment count: \(segmentCountBeforeDeletion) → \(updatedSegmentCount)")
            
            // Only adjust index if deletion was successful
            guard updatedSegmentCount < segmentCountBeforeDeletion else {
                print("Segment deletion may have failed")
                return
            }
            
            // Safe index adjustment
            if updatedSegmentCount == 0 {
                print("No segments remaining")
                return
            }
            
            // Adjust if current index is out of range
            if self.currentSegmentIndex >= updatedSegmentCount {
                self.currentSegmentIndex = max(0, updatedSegmentCount - 1)
                print("Current index adjusted: \(currentIndexBeforeDeletion) → \(self.currentSegmentIndex)")
            }
            
            // Reload segment
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                print("Reloading segment after deletion")
                self.loadCurrentSegment()
                
                // Return to seamless playback if it was originally seamless
                if wasSeamless && updatedSegmentCount > 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        print("Returning to seamless playback after deletion")
                        self.useSeamlessPlayback = true
                        self.loadComposition()
                    }
                }
            }
        }
        
        print("Segment deletion completed")
    }
    
    private func resetDeleteState() {
        segmentToDelete = nil
        showDeleteSegmentAlert = false
    }
    
    // MARK: - Observer Functions
    
    private func startTimeObserver() {
        removeTimeObserver()
        
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            self.updateCurrentTime()
            
            // Also update current segment index in integrated playback
            if self.useSeamlessPlayback {
                self.updateCurrentSegmentIndex()
            }
        }
    }
    
    private func removeTimeObserver() {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
    }
    
    private func updateCurrentTime() {
        guard let playerItem = playerItem else { return }
        
        let current = player.currentTime().seconds
        let total = playerItem.duration.seconds
        
        if current.isFinite && total.isFinite {
            currentTime = current
            duration = total
        }
    }
    
    private func cleanupPlayer() {
        player.pause()
        removeTimeObserver()
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        player.replaceCurrentItem(with: nil)
        composition = nil
        segmentTimeRanges = []
        print("PlayerView cleanup completed")
    }
    
    // MARK: - Helper Functions
    
    private func timeString(from seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00" }
        
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - DateFormatter Extension
extension DateFormatter {
    func apply(_ closure: (DateFormatter) -> Void) -> DateFormatter {
        closure(self)
        return self
    }
}

// MARK: - Video Player View
struct VideoPlayerView: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect
        view.layer.addSublayer(playerLayer)
        
        DispatchQueue.main.async {
            playerLayer.frame = view.bounds
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let playerLayer = uiView.layer.sublayers?.first as? AVPlayerLayer {
            playerLayer.frame = uiView.bounds
        }
    }
}

// MARK: - Preview
struct PlayerView_Previews: PreviewProvider {
    static var previews: some View {
        PlayerView(
            projectManager: ProjectManager(),
            initialProject: Project(name: "Test Project"),
            onBack: { },
            onDeleteSegment: { _, _ in }
        )
    }
}
