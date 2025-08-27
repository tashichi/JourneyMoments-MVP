import SwiftUI
import AVFoundation

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
    
    // 🆕 追加: シームレス再生機能の状態管理
    @State private var useSeamlessPlayback = true  // 初期は既存方式
    @State private var composition: AVComposition?
    @State private var segmentTimeRanges: [(segment: VideoSegment, timeRange: CMTimeRange)] = []
    
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
            print("🎬 PlayerView display started")
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
                    print("🔙 Back button tapped")
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
                
                // 🆕 追加: 再生モード表示
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
        VStack(spacing: 30) {
            progressView
            mainControls
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
    
    // MARK: - Main Controls
    private var mainControls: some View {
        HStack(spacing: 40) {
            // 前のセグメント
            Button(action: {
                print("🔙 Previous segment button tapped")
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
                print("⏯️ Play/Pause button tapped")
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
                print("🔜 Next segment button tapped")
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
                        print("🗑️ Delete segment button tapped: Segment \(segment.order)")
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
    
    // MARK: - Player Setup Functions
    
    private func setupPlayer() {
        print("🎬 PlayerView setup started - Mode: \(useSeamlessPlayback ? "Seamless" : "Individual")")
        
        if useSeamlessPlayback {
            loadComposition()
        } else {
            loadCurrentSegment()
        }
    }
    
    // 🆕 追加: AVComposition統合再生の設定
    private func loadComposition() {
        print("🎬 Loading composition for seamless playback")
        
        Task {
            guard let newComposition = await projectManager.createComposition(for: project) else {
                print("❌ Failed to create composition")
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
                    print("🔔 Composition playback completed")
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
                
                print("✅ Composition loaded successfully")
                print("📊 Total composition duration: \(duration)s")
                print("📊 Segment time ranges: \(segmentTimeRanges.count)")
                
                // 時間監視開始
                startTimeObserver()
                
                // 現在のセグメントインデックスを更新
                updateCurrentSegmentIndex()
            }
        }
    }
    
    // 🆕 追加: 統合再生の現在セグメント更新
    private func updateCurrentSegmentIndex() {
        let currentPlayerTime = player.currentTime()
        
        for (index, (_, timeRange)) in segmentTimeRanges.enumerated() {
            if CMTimeRangeContainsTime(timeRange, time: currentPlayerTime) {
                if currentSegmentIndex != index {
                    currentSegmentIndex = index
                    print("🔄 Current segment updated to: \(index + 1)")
                }
                break
            }
        }
    }
    
    // 🆕 追加: 統合再生終了処理
    private func handleCompositionEnd() {
        print("🏁 Composition playback completed - Returning to start")
        player.seek(to: .zero)
        currentSegmentIndex = 0
        isPlaying = false
        print("⏹️ Stopped - Press play button to replay")
    }
    
    // 既存の個別セグメント再生（互換性維持）
    private func loadCurrentSegment() {
        guard let segment = currentSegment else {
            print("❌ No segment to play")
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
            print("❌ File not found: \(fileURL.path)")
            return
        }
        
        let newPlayerItem = AVPlayerItem(url: fileURL)
        
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: newPlayerItem,
            queue: .main
        ) { _ in
            print("🔔 Segment playback completed - Segment \(self.currentSegmentIndex + 1)")
            self.handleSegmentEnd()
        }
        
        player.replaceCurrentItem(with: newPlayerItem)
        playerItem = newPlayerItem
        
        player.pause()
        isPlaying = false
        currentTime = 0
        
        print("✅ Segment loaded: \(segment.order), File: \(fileURL.lastPathComponent)")
        
        startTimeObserver()
    }
    
    // 既存の個別セグメント終了処理
    private func handleSegmentEnd() {
        print("🔔 Segment playback ended - Current: \(currentSegmentIndex + 1)/\(project.segments.count)")
        
        if currentSegmentIndex < project.segments.count - 1 {
            print("🔄 Auto advancing to next segment")
            let nextIndex = currentSegmentIndex + 1
            print("🔄 Advancing to: Segment \(nextIndex + 1)")
            
            currentSegmentIndex = nextIndex
            loadCurrentSegment()
            
            isPlaying = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                print("🔄 Auto playback executing: Segment \(self.currentSegmentIndex + 1)")
                self.player.play()
                print("▶️ Auto playback continued")
            }
        } else {
            print("🏁 All segments completed - Returning to first segment")
            currentSegmentIndex = 0
            loadCurrentSegment()
            isPlaying = false
            print("🔄 Returned to first segment (1st)")
            print("⏹️ Stopped - Press play button to replay")
        }
    }
    
    // MARK: - Control Functions
    
    private func togglePlayback() {
        if isPlaying {
            player.pause()
            isPlaying = false
            print("⏸️ Playback paused")
        } else {
            player.play()
            isPlaying = true
            print("▶️ Playback started")
        }
    }
    
    private func previousSegment() {
        if useSeamlessPlayback {
            // 統合再生時のセグメント移動
            guard currentSegmentIndex > 0 else {
                print("❌ No previous segment available")
                return
            }
            
            currentSegmentIndex -= 1
            if currentSegmentIndex < segmentTimeRanges.count {
                let targetTime = segmentTimeRanges[currentSegmentIndex].timeRange.start
                player.seek(to: targetTime)
                print("⏮️ Seamless: Previous segment: \(currentSegmentIndex + 1)")
            }
        } else {
            // 個別再生時のセグメント移動
            guard currentSegmentIndex > 0 else {
                print("❌ No previous segment available")
                return
            }
            
            currentSegmentIndex -= 1
            loadCurrentSegment()
            
            if isPlaying {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.player.play()
                }
            }
            print("⏮️ Individual: Previous segment: \(currentSegmentIndex + 1)")
        }
    }
    
    private func nextSegment() {
        if useSeamlessPlayback {
            // 統合再生時のセグメント移動
            guard currentSegmentIndex < project.segments.count - 1 else {
                print("❌ No next segment available")
                return
            }
            
            currentSegmentIndex += 1
            if currentSegmentIndex < segmentTimeRanges.count {
                let targetTime = segmentTimeRanges[currentSegmentIndex].timeRange.start
                player.seek(to: targetTime)
                print("⏭️ Seamless: Next segment: \(currentSegmentIndex + 1)")
            }
        } else {
            // 個別再生時のセグメント移動
            guard currentSegmentIndex < project.segments.count - 1 else {
                print("❌ No next segment available")
                return
            }
            
            currentSegmentIndex += 1
            loadCurrentSegment()
            
            if isPlaying {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.player.play()
                }
            }
            print("⏭️ Individual: Next segment: \(currentSegmentIndex + 1)")
        }
    }
    
    // MARK: - Segment Deletion
    
    private func handleSegmentDeletion(_ segment: VideoSegment) {
        print("🗑️ Starting segment deletion: Segment \(segment.order)")
        
        // 統合再生中の場合は個別再生に切り替え
        if useSeamlessPlayback {
            print("🔄 Switching to individual playback for deletion")
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
            print("🔍 Segment count: \(segmentCountBeforeDeletion) → \(updatedSegmentCount)")
            
            // セグメント削除が成功した場合のみインデックス調整
            guard updatedSegmentCount < segmentCountBeforeDeletion else {
                print("❌ Segment deletion may have failed")
                return
            }
            
            // インデックスの安全な調整
            if updatedSegmentCount == 0 {
                // 全セグメントが削除された場合（通常は起こらないはず）
                print("📭 No segments remaining")
                return
            }
            
            // 現在のインデックスが範囲外になった場合の調整
            if self.currentSegmentIndex >= updatedSegmentCount {
                self.currentSegmentIndex = max(0, updatedSegmentCount - 1)
                print("🔄 Current index adjusted: \(currentIndexBeforeDeletion) → \(self.currentSegmentIndex)")
            }
            
            // セグメント再読み込み
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                print("🔄 Reloading segment after deletion")
                self.loadCurrentSegment()
            }
        }
        
        print("✅ Segment deletion completed")
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
        print("🧹 PlayerView cleanup completed")
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
