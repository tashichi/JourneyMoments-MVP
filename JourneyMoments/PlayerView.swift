import SwiftUI
import AVFoundation

struct PlayerView: View {
    let project: Project
    let onBack: () -> Void
    
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
            print("🎬 PlayerView表示開始")
        }
        .onDisappear {
            cleanupPlayer()
        }
        .navigationBarHidden(true)
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
            
            Text("再生できる動画がありません")
                .font(.title2)
                .foregroundColor(.white)
            
            Text("カメラ画面で動画を撮影してください")
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
                    print("🔙 戻るボタンタップ")
                    onBack()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("戻る")
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
            
            // セグメント情報
            segmentInfo
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
                print("🔙 前のセグメントボタンタップ")
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
                print("⏯️ 再生/停止ボタンタップ")
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
                print("🔜 次のセグメントボタンタップ")
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
    
    // MARK: - Segment Info
    private var segmentInfo: some View {
        VStack(spacing: 4) {
            if let segment = currentSegment {
                Text("セグメント \(segment.order)")
                    .font(.caption)
                    .foregroundColor(.yellow)
                    .fontWeight(.semibold)
                
                Text(formatDate(segment.timestamp))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.black.opacity(0.6))
        .cornerRadius(10)
    }
    
    // MARK: - Functions
    
    private func setupPlayer() {
        print("🎬 PlayerView セットアップ開始")
        loadCurrentSegment()
    }
    
    // 🔧 修正済み: ファイルパス問題解決
    private func loadCurrentSegment() {
        guard let segment = currentSegment else {
            print("❌ 再生するセグメントがありません")
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
            print("❌ ファイルが見つかりません: \(fileURL.path)")
            print("🔍 探索場所: \(documentsPath.path)")
            
            // デバッグ: Documents ディレクトリの内容を確認
            do {
                let files = try FileManager.default.contentsOfDirectory(atPath: documentsPath.path)
                print("📁 Documents ディレクトリ内容:")
                files.forEach { print("  - \($0)") }
            } catch {
                print("❌ ディレクトリ読み込みエラー: \(error)")
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
            print("🔔 セグメント再生完了通知受信 - セグメント\(self.currentSegmentIndex + 1)")
            self.handleSegmentEnd()
        }
        
        // プレイヤーアイテムを設定
        player.replaceCurrentItem(with: newPlayerItem)
        playerItem = newPlayerItem
        
        // 再生準備
        player.pause()
        isPlaying = false
        currentTime = 0
        
        print("✅ セグメント読み込み完了: \(segment.order), ファイル: \(fileURL.lastPathComponent)")
        print("🔄 通知監視設定完了: セグメント\(segment.order)の再生終了を監視")
        
        // 時間監視を開始
        startTimeObserver()
    }
    
    // 🔧 修正: 再生終了時の処理（最後のセグメント後に最初に戻る）
    private func handleSegmentEnd() {
        print("🔔 セグメント再生終了 - 現在: \(currentSegmentIndex + 1)/\(project.segments.count)")
        
        if currentSegmentIndex < project.segments.count - 1 {
            // 次のセグメントがある場合: 自動で次へ移行
            print("🔄 次のセグメントへ自動移行開始")
            let nextIndex = currentSegmentIndex + 1
            print("🔄 移行先: セグメント\(nextIndex + 1)")
            
            currentSegmentIndex = nextIndex
            loadCurrentSegment()
            
            // isPlayingを強制的にtrueに設定してから再生
            isPlaying = true
            
            // 自動再生継続
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                print("🔄 自動再生実行: セグメント\(self.currentSegmentIndex + 1)")
                self.player.play()
                print("▶️ 自動再生継続完了")
            }
        } else {
            // 最後のセグメントが終了した場合: 最初に戻って停止
            print("🏁 全セグメント再生完了 - 最初のセグメントに戻ります")
            
            // 最初のセグメントに戻る
            currentSegmentIndex = 0
            loadCurrentSegment()
            
            // 停止状態にする
            isPlaying = false
            
            print("🔄 最初のセグメント（1番目）に戻りました")
            print("⏹️ 停止状態 - 再生ボタンで再度再生可能")
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
            print("⏸️ 再生停止")
        } else {
            player.play()
            isPlaying = true
            print("▶️ 再生開始")
        }
    }
    
    private func previousSegment() {
        guard currentSegmentIndex > 0 else {
            print("❌ これ以上前のセグメントはありません")
            return
        }
        
        currentSegmentIndex -= 1
        loadCurrentSegment()
        
        if isPlaying {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.player.play()
            }
        }
        
        print("⏮️ 前のセグメント: \(currentSegmentIndex + 1)")
    }
    
    private func nextSegment() {
        guard currentSegmentIndex < project.segments.count - 1 else {
            print("❌ これ以上次のセグメントはありません")
            return
        }
        
        currentSegmentIndex += 1
        loadCurrentSegment()
        
        if isPlaying {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.player.play()
            }
        }
        
        print("⏭️ 次のセグメント: \(currentSegmentIndex + 1)")
    }
    
    private func cleanupPlayer() {
        player.pause()
        removeTimeObserver()
        // 🔧 修正: 明示的に通知監視を削除
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        player.replaceCurrentItem(with: nil)
        print("🧹 PlayerView クリーンアップ完了")
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
            project: Project(name: "テストプロジェクト"),
            onBack: { }
        )
    }
}
