import SwiftUI
import AVFoundation

struct PlayerView: View {
    @ObservedObject var projectManager: ProjectManager  // 🔧 修正: プロジェクト変更を監視
    let initialProject: Project  // 🔧 修正: 初期プロジェクト情報
    let onBack: () -> Void
    let onDeleteSegment: (Project, VideoSegment) -> Void
    
    // 🔧 追加: 現在のプロジェクトを動的に取得
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
    
    // 🆕 追加: セグメント削除機能の状態管理
    @State private var showDeleteSegmentAlert = false
    @State private var segmentToDelete: VideoSegment?
    
    private var hasSegments: Bool {
        !project.segments.isEmpty
    }
    
    private var currentSegment: VideoSegment? {
        guard hasSegments, currentSegmentIndex < project.segments.count else { return nil }
        return project.segments[currentSegmentIndex]
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // 🔧 修正: 映像表示の改善
            if hasSegments {
                customPlayerView
            } else {
                emptyStateView
            }
            
            // コントロールを常に最前面に表示
            VStack {
                // ヘッダー（常に表示）
                headerView
                
                Spacer()
                
                // 再生コントロール（常に表示）
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
        // 🆕 追加: セグメント削除確認アラート
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
                // 戻るボタン
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
                
                // セグメント情報
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
            .padding(.horizontal, 20)
            
            // プロジェクト名
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
            // 再生進捗表示
            progressView
            
            // メイン再生コントロール
            mainControls
            
            // セグメント情報（削除機能付き）
            segmentInfoWithDelete
        }
        .padding(.bottom, 50)
    }
    
    // MARK: - Progress View
    private var progressView: some View {
        VStack(spacing: 8) {
            // 時間表示
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
            
            // プログレスバー
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
    
    // 🆕 修正: セグメント情報に削除機能を追加
    private var segmentInfoWithDelete: some View {
        VStack(spacing: 8) {
            if let segment = currentSegment {
                // セグメント基本情報
                VStack(spacing: 4) {
                    Text("Segment \(segment.order)")
                        .font(.caption)
                        .foregroundColor(.yellow)
                        .fontWeight(.semibold)
                    
                    Text(formatDate(segment.timestamp))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                // 🆕 削除ボタン（条件付き表示）
                if project.segments.count > 1 {  // セグメントが2つ以上ある場合のみ表示
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
                    // セグメントが1つしかない場合の説明
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
    
    // 🆕 追加: セグメント削除処理関数
    private func handleSegmentDeletion(_ segment: VideoSegment) {
        print("🗑️ Starting segment deletion: Segment \(segment.order)")
        
        // 1. プレイヤーを停止
        player.pause()
        isPlaying = false
        
        // 2. 削除処理をメイン画面に委譲
        onDeleteSegment(project, segment)
        
        // 3. 現在のセグメントが削除された場合の処理
        let deletedIndex = project.segments.firstIndex { $0.id == segment.id } ?? -1
        
        if deletedIndex == currentSegmentIndex {
            // 現在再生中のセグメントが削除された場合
            if currentSegmentIndex >= project.segments.count - 1 {
                // 削除後、インデックスが範囲外になる場合は前のセグメントに移動
                currentSegmentIndex = max(0, project.segments.count - 2)
            }
            // 新しいセグメントを読み込み
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.loadCurrentSegment()
            }
        } else if deletedIndex < currentSegmentIndex {
            // 現在より前のセグメントが削除された場合、インデックスを調整
            currentSegmentIndex -= 1
        }
        
        print("✅ Segment deletion completed")
    }
    
    private func resetDeleteState() {
        segmentToDelete = nil
        showDeleteSegmentAlert = false
    }
    
    // MARK: - Functions
    
    private func setupPlayer() {
        print("🎬 PlayerView setup started")
        loadCurrentSegment()
    }
    
    // 🔧 修正済み: ファイルパス問題解決
    private func loadCurrentSegment() {
        guard let segment = currentSegment else {
            print("❌ No segment to play")
            return
        }
        
        // 🔧 修正: 既存の通知監視を完全にクリア
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        
        // 既存の時間監視を停止
        removeTimeObserver()
        
        // Documents ディレクトリから相対パスで読み込み
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL: URL
        
        // ファイル名のみの場合（新しい形式）
        if !segment.uri.hasPrefix("/") {
            fileURL = documentsPath.appendingPathComponent(segment.uri)
        } else {
            // 絶対パスの場合（旧い形式）- 後方互換性
            fileURL = URL(fileURLWithPath: segment.uri)
        }
        
        // ファイルの存在確認
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("❌ File not found: \(fileURL.path)")
            print("🔍 Search location: \(documentsPath.path)")
            
            // デバッグ: Documents ディレクトリの内容を確認
            do {
                let files = try FileManager.default.contentsOfDirectory(atPath: documentsPath.path)
                print("📁 Documents directory contents:")
                files.forEach { print("  - \($0)") }
            } catch {
                print("❌ Directory read error: \(error)")
            }
            
            return
        }
        
        // 新しいプレイヤーアイテムを作成
        let newPlayerItem = AVPlayerItem(url: fileURL)
        
        // 🔧 修正: クロージャ方式で再生終了監視
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: newPlayerItem,
            queue: .main
        ) { _ in
            print("🔔 Segment playback completed - Segment \(self.currentSegmentIndex + 1)")
            self.handleSegmentEnd()
        }
        
        // プレイヤーアイテムを設定
        player.replaceCurrentItem(with: newPlayerItem)
        playerItem = newPlayerItem
        
        // 再生準備
        player.pause()
        isPlaying = false
        currentTime = 0
        
        print("✅ Segment loaded: \(segment.order), File: \(fileURL.lastPathComponent)")
        print("🔄 Notification observer set: Monitoring playback end for segment \(segment.order)")
        
        // 時間監視を開始
        startTimeObserver()
    }
    
    // 🔧 修正: 再生終了時の処理（最後のセグメント後に最初に戻る）
    private func handleSegmentEnd() {
        print("🔔 Segment playback ended - Current: \(currentSegmentIndex + 1)/\(project.segments.count)")
        
        if currentSegmentIndex < project.segments.count - 1 {
            // 次のセグメントがある場合: 自動で次へ移行
            print("🔄 Auto advancing to next segment")
            let nextIndex = currentSegmentIndex + 1
            print("🔄 Advancing to: Segment \(nextIndex + 1)")
            
            currentSegmentIndex = nextIndex
            loadCurrentSegment()
            
            // isPlayingを強制的にtrueに設定してから再生
            isPlaying = true
            
            // 自動再生継続
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                print("🔄 Auto playback executing: Segment \(self.currentSegmentIndex + 1)")
                self.player.play()
                print("▶️ Auto playback continued")
            }
        } else {
            // 最後のセグメントが終了した場合: 最初に戻って停止
            print("🏁 All segments completed - Returning to first segment")
            
            // 最初のセグメントに戻る
            currentSegmentIndex = 0
            loadCurrentSegment()
            
            // 停止状態にする
            isPlaying = false
            
            print("🔄 Returned to first segment (1st)")
            print("⏹️ Stopped - Press play button to replay")
        }
    }
    
    private func startTimeObserver() {
        // 既存の監視を削除
        removeTimeObserver()
        
        // 時間監視を追加
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            self.updateCurrentTime()
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
        
        print("⏮️ Previous segment: \(currentSegmentIndex + 1)")
    }
    
    private func nextSegment() {
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
        
        print("⏭️ Next segment: \(currentSegmentIndex + 1)")
    }
    
    private func cleanupPlayer() {
        player.pause()
        removeTimeObserver()
        // 🔧 修正: 明示的に通知監視を削除
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        player.replaceCurrentItem(with: nil)
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
// 🔧 修正: 映像表示の完全な実装
struct VideoPlayerView: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        
        // プレイヤーレイヤーを作成
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect
        view.layer.addSublayer(playerLayer)
        
        // ビューのサイズ変更時にレイヤーサイズも更新
        DispatchQueue.main.async {
            playerLayer.frame = view.bounds
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // フレーム更新
        if let playerLayer = uiView.layer.sublayers?.first as? AVPlayerLayer {
            playerLayer.frame = uiView.bounds
        }
    }
}

// MARK: - Preview
struct PlayerView_Previews: PreviewProvider {
    static var previews: some View {
        PlayerView(
            projectManager: ProjectManager(),  // 🔧 修正: ProjectManagerのインスタンスを作成
            initialProject: Project(name: "Test Project"),
            onBack: { },
            onDeleteSegment: { _, _ in }
        )
    }
}
