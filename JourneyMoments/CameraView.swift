import SwiftUI
import AVFoundation

struct CameraView: View {
    let currentProject: Project?
    let onRecordingComplete: (VideoSegment) -> Void
    let onBackToProjects: () -> Void
    
    @StateObject private var videoManager = VideoManager()
    @State private var isRecording = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showSuccessToast = false
    @State private var successMessage = ""
    
    var body: some View {
        ZStack {
            // カメラプレビュー背景
            Color.black
                .ignoresSafeArea(.all)
            
            // 🔧 修正: 権限確認のみでプレビュー表示
            if videoManager.cameraPermissionGranted {
                CameraPreviewRepresentable(videoManager: videoManager)
                    .ignoresSafeArea(.all)
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("Please allow camera access")
                        .foregroundColor(.white)
                        .padding()
                }
            }
            
            // オーバーレイUI
            VStack {
                // ヘッダー
                headerView
                
                Spacer()
                
                // 撮影コントロール
                controlsView
            }
            
            // 録画中表示
            if isRecording {
                VStack {
                    Spacer()
                    recordingStatusView
                    Spacer()
                }
            }
            
            // 成功トースト表示
            if showSuccessToast {
                VStack {
                    Spacer()
                    successToastView
                    Spacer()
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear {
            setupCamera()
        }
        .onDisappear {
            videoManager.stopSession()
        }
        .alert("Recording Error", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 10) {
            HStack {
                // 戻るボタン
                Button(action: onBackToProjects) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Projects")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(15)
                }
                
                Spacer()
                
                // カメラ切り替えボタン
                Button(action: toggleCamera) {
                    Image(systemName: "camera.rotate.fill")
                        .font(.title2)
                        .padding(8)
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(20)
                }
                .disabled(isRecording)
            }
            .padding(.horizontal, 20)
            
            // プロジェクト情報
            if let project = currentProject {
                VStack(spacing: 4) {
                    Text(project.name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 2, x: 1, y: 1)
                    
                    Text("\(project.segmentCount)s recorded")
                        .font(.caption)
                        .foregroundColor(.yellow)
                        .fontWeight(.semibold)
                        .shadow(color: .black, radius: 2, x: 1, y: 1)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.5))
                .cornerRadius(12)
            }
        }
        .padding(.top, 60)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Controls View
    private var controlsView: some View {
        VStack(spacing: 20) {
            HStack {
                Spacer()
                
                // 撮影ボタン
                Button(action: recordOneSecondVideo) {
                    ZStack {
                        Circle()
                            .fill(isRecording ? Color.red : Color.white)
                            .frame(width: 100, height: 100)
                            .overlay(
                                Circle()
                                    .stroke(Color.red, lineWidth: 6)
                            )
                        
                        Text(isRecording ? "Recording" : "REC")
                            .font(isRecording ? .caption : .body)
                            .fontWeight(.bold)
                            .foregroundColor(isRecording ? .white : .black)
                    }
                }
                .disabled(isRecording || currentProject == nil)
                
                Spacer()
            }
        }
        .padding(.bottom, 50)
    }
    
    private var recordingStatusView: some View {
        VStack {
            Text("📹 Recording...")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.red)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.9))
                .cornerRadius(20)
                .shadow(radius: 5)
        }
    }
    
    private var successToastView: some View {
        VStack {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                
                Text(successMessage)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.9))
            .cornerRadius(20)
            .shadow(radius: 5)
        }
    }
    
    // MARK: - Functions
    
    private func setupCamera() {
        print("🔧 CameraView setupCamera() 開始")
        Task {
            print("🔧 権限リクエスト開始")
            await videoManager.requestCameraPermission()
            print("🔧 権限リクエスト完了: \(videoManager.cameraPermissionGranted)")
            
            if videoManager.cameraPermissionGranted {
                print("🔧 カメラセットアップ開始")
                await videoManager.setupCamera()
                print("🔧 カメラセットアップ完了: \(videoManager.isSetupComplete)")
            } else {
                print("❌ カメラ権限が拒否されました")
            }
        }
    }
    
    private func toggleCamera() {
        Task {
            await videoManager.toggleCamera()
        }
    }
    
    private func recordOneSecondVideo() {
        guard let project = currentProject else { return }
        
        Task {
            isRecording = true
            
            do {
                let videoURL = try await videoManager.recordOneSecond()
                
                // ファイル名のみを保存（相対パス）
                let filename = videoURL.lastPathComponent
                
                // 新しいセグメントを作成
                let newSegment = VideoSegment(
                    uri: filename,
                    cameraPosition: videoManager.currentCameraPosition,
                    order: project.segments.count + 1
                )
                
                // 撮影完了をメイン画面に通知
                onRecordingComplete(newSegment)
                
                // 成功トースト表示
                successMessage = "✅ Segment \(project.segments.count + 1) recorded"
                withAnimation(.easeInOut(duration: 0.3)) {
                    showSuccessToast = true
                }
                
                // 1.5秒後に自動で消す
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showSuccessToast = false
                    }
                }
                
                print("✅ Segment saved: \(filename) - Segment \(project.segments.count + 1) recorded")
                
            } catch {
                alertMessage = "Recording failed: \(error.localizedDescription)"
                showingAlert = true
                print("❌ Recording error: \(error)")
            }
            
            isRecording = false
        }
    }
}

// MARK: - Camera Preview Representable
struct CameraPreviewRepresentable: UIViewRepresentable {
    let videoManager: VideoManager
    
    func makeUIView(context: Context) -> UIView {
        print("🔧 makeUIView 開始")
        let view = CameraContainerView()
        view.backgroundColor = .black
        view.videoManager = videoManager
        print("🔧 makeUIView 完了")
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        print("🔧 updateUIView 開始 - Frame: \(uiView.bounds)")
        
        guard let containerView = uiView as? CameraContainerView else {
            print("❌ CameraContainerView キャスト失敗")
            return
        }
        
        containerView.updatePreviewLayer()
        print("🔧 updateUIView 完了")
    }
}

// 🔧 新規追加: 専用のカメラコンテナビュー
class CameraContainerView: UIView {
    weak var videoManager: VideoManager?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override func layoutSubviews() {
        super.layoutSubviews()
        print("🔧 layoutSubviews - Frame: \(bounds)")
        
        // 🔧 重要: レイアウト完了後にプレビューレイヤーを更新
        DispatchQueue.main.async {
            self.updatePreviewLayer()
        }
    }
    
    func updatePreviewLayer() {
        // bounds がゼロの場合は処理しない
        guard bounds.width > 0 && bounds.height > 0 else {
            print("⚠️ View bounds がゼロのため、プレビューレイヤー更新をスキップ")
            return
        }
        
        guard let videoManager = videoManager,
              let newPreviewLayer = videoManager.previewLayer else {
            print("⚠️ VideoManager またはプレビューレイヤーが準備されていません")
            return
        }
        
        // 既存のプレビューレイヤーを削除
        if let existingLayer = previewLayer {
            existingLayer.removeFromSuperlayer()
            print("🔧 既存のプレビューレイヤーを削除")
        }
        
        // 新しいプレビューレイヤーを設定
        newPreviewLayer.frame = bounds
        newPreviewLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(newPreviewLayer)
        previewLayer = newPreviewLayer
        
        print("✅ プレビューレイヤー追加完了 - Frame: \(bounds)")
        
        // セッション状態確認
        if let session = newPreviewLayer.session, session.isRunning {
            print("✅ セッションは実行中です")
        } else {
            print("⚠️ セッションが実行されていません")
        }
    }
}

// MARK: - Preview
struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        CameraView(
            currentProject: Project(name: "Test Project"),
            onRecordingComplete: { _ in },
            onBackToProjects: { }
        )
    }
}
