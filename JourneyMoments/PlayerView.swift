import SwiftUI
import AVFoundation
import Photos

struct PlayerView: View {
    @ObservedObject var projectManager: ProjectManager
    let initialProject: Project
    let onBack: () -> Void
    let onDeleteSegment: (Project, VideoSegment) -> Void
    
    // 現在のプロジェクトを動的に取得
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
    
    // セグメント削除機能の状態管理
    @State private var showDeleteSegmentAlert = false
    @State private var segmentToDelete: VideoSegment?
    
    // シームレス再生機能の状態管理
    @State private var useSeamlessPlayback = true  // シームレス再生をデフォルトに
    @State private var composition: AVComposition?
    @State private var segmentTimeRanges: [(segment: VideoSegment, timeRange: CMTimeRange)] = []
    
    // エクスポート機能の状態管理
    @State private var showExportAlert = false
    @State private var isExporting = false
    @State private var exportProgress: Float = 0.0
    @State private var exportError: String?
    @State private var showExportSuccess = false
    
    private var hasSegments: Bool {
        !project.segments.isEmpty
    }
    
    private var currentSegment: VideoSegment? {
        guard hasSegments, currentSegmentIndex >= 0, currentSegmentIndex < project.segments.count else {
            print("⚠️ Current segment index out of range: \(currentSegmentIndex) / \(project.segments.count)")
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
            
            // コントロールを常に最前面に表示
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
                
                // 再生モード表示
                HStack(spacing: 8) {
                    Text(useSeamlessPlayback ? "Seamless" : "Individual")
                        .font(.caption2)
                        .foregroundColor(useSeamlessPlayback ? .green : .yellow)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(6)
                    
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
            
            // エクスポート進捗表示（エクスポート中のみ）
            if isExporting {
                exportProgressView
            }
            
            mainControls
            
            // エクスポートボタンを追加
            if hasSegments && !isExporting {
                exportButton
            }
            
            segmentInfoWithDelete
        }
        .padding(.bottom, 50)
    }
    
    // MARK: - Progress View
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
            
            ProgressView(value: currentTime, total: duration)
                .progressViewStyle(LinearProgressViewStyle(tint: .white))
                .scaleEffect(y: 2)
        }
        .padding(.horizontal, 40)
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
            // 前のセグメント
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
            
            // 再生/停止
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
            
            // 次のセグメント
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
    
    // MARK: - Export Functions
    
    // 写真ライブラリアクセス権限をリクエスト
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
            startExport() // limited access でも保存は可能
        @unknown default:
            showExportAlert = true
            exportError = "Unknown authorization status"
        }
    }
    
    // エクスポート処理を開始
    private func startExport() {
        print("Starting export process")
        
        // エクスポート中の状態に設定
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
    
    // 実際の動画エクスポート処理
    private func exportVideo() async -> Bool {
        print("Creating composition for export")
        
        // 既存のcompositionを使用するか、新規作成
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
        
        // 出力ファイルのURL作成
        let outputURL = createExportURL()
        
        // 既存ファイルがあれば削除
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }
        
        // AVAssetExportSession作成
        guard let exportSession = AVAssetExportSession(
            asset: exportComposition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            print("Failed to create export session")
            return false
        }
        
        // エクスポート設定
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        print("Export settings:")
        print("   Output URL: \(outputURL.lastPathComponent)")
        print("   Preset: \(AVAssetExportPresetHighestQuality)")
        print("   File Type: MP4")
        
        // 進捗監視を開始
        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            DispatchQueue.main.async {
                self.exportProgress = exportSession.progress
            }
        }
        
        // エクスポート実行
        await withCheckedContinuation { continuation in
            exportSession.exportAsynchronously {
                DispatchQueue.main.async {
                    progressTimer.invalidate()
                    self.exportProgress = 1.0
                }
                continuation.resume()
            }
        }
        
        // エクスポート結果の確認
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
    
    // エクスポートファイルのURL生成
    private func createExportURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timestamp = DateFormatter().apply {
            $0.dateFormat = "yyyyMMdd_HHmmss"
        }.string(from: Date())
        
        let filename = "\(project.name.replacingOccurrences(of: " ", with: "_"))_\(timestamp).mp4"
        return documentsPath.appendingPathComponent(filename)
    }
    
    // 写真ライブラリに保存
    private func saveToPhotoLibrary(url: URL) async -> Bool {
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }) { success, error in
                if success {
                    print("Video saved to photo library: \(url.lastPathComponent)")
                    // 一時ファイルを削除
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
    
    // AVComposition統合再生の設定
    private func loadComposition() {
        print("Loading composition for seamless playback")
        
        Task {
            guard let newComposition = await projectManager.createComposition(for: project) else {
                print("Failed to create composition")
                // フォールバックとして個別再生に切り替え
                useSeamlessPlayback = false
                loadCurrentSegment()
                return
            }
            
            // セグメント時間範囲を取得
            segmentTimeRanges = await projectManager.getSegmentTimeRanges(for: project)
            
            // メインスレッドでUI更新
            await MainActor.run {
                // 既存の監視を削除
                removeTimeObserver()
                NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
                
                // 新しいプレイヤーアイテムを作成
                let newPlayerItem = AVPlayerItem(asset: newComposition)
                
                // 全体再生終了監視
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
                
                // 再生準備
                player.pause()
                isPlaying = false
                currentTime = 0
                duration = newComposition.duration.seconds
                
                print("Composition loaded successfully")
                print("Total composition duration: \(duration)s")
                print("Segment time ranges: \(segmentTimeRanges.count)")
                
                // 時間監視開始
                startTimeObserver()
                
                // 現在のセグメントインデックスを更新
                updateCurrentSegmentIndex()
            }
        }
    }
    
    // 統合再生の現在セグメント更新
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
    
    // 統合再生終了処理
    private func handleCompositionEnd() {
        print("Composition playback completed - Returning to start")
        player.seek(to: .zero)
        currentSegmentIndex = 0
        isPlaying = false
        print("Stopped - Press play button to replay")
    }
    
    // 既存の個別セグメント再生（互換性維持）
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
    
    // 既存の個別セグメント終了処理
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
            // 統合再生時のセグメント移動
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
            // 個別再生時のセグメント移動
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
            // 統合再生時のセグメント移動
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
            // 個別再生時のセグメント移動
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
        
        // 削除前の再生モードを記録
        let wasSeamless = useSeamlessPlayback
        
        // 統合再生中の場合は個別再生に切り替え
        if useSeamlessPlayback {
            print("Switching to individual playback for deletion")
            useSeamlessPlayback = false
            player.pause()
            isPlaying = false
        }
        
        // 削除前の状態を記録
        let segmentCountBeforeDeletion = project.segments.count
        let currentIndexBeforeDeletion = currentSegmentIndex
        
        // 削除処理をメイン画面に委譲
        onDeleteSegment(project, segment)
        
        // 削除後の処理 - プロジェクトが更新されるまで少し待つ
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let updatedSegmentCount = self.project.segments.count
            print("Segment count: \(segmentCountBeforeDeletion) → \(updatedSegmentCount)")
            
            // セグメント削除が成功した場合のみインデックス調整
            guard updatedSegmentCount < segmentCountBeforeDeletion else {
                print("Segment deletion may have failed")
                return
            }
            
            // インデックスの安全な調整
            if updatedSegmentCount == 0 {
                print("No segments remaining")
                return
            }
            
            // 現在のインデックスが範囲外になった場合の調整
            if self.currentSegmentIndex >= updatedSegmentCount {
                self.currentSegmentIndex = max(0, updatedSegmentCount - 1)
                print("Current index adjusted: \(currentIndexBeforeDeletion) → \(self.currentSegmentIndex)")
            }
            
            // セグメント再読み込み
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                print("Reloading segment after deletion")
                self.loadCurrentSegment()
                
                // 元がシームレス再生だった場合、削除完了後にシームレス再生に復帰
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
            
            // 統合再生時は現在のセグメントインデックスも更新
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
