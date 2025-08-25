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
    // 🔧 追加: 成功通知の状態管理
    @State private var showSuccessToast = false
    @State private var successMessage = ""
    
    var body: some View {
        ZStack {
            // カメラプレビュー背景
            Color.black
                .ignoresSafeArea(.all)
            
            // カメラプレビューまたはプレースホルダー
            if videoManager.cameraPermissionGranted {
                CameraPreviewRepresentable(videoManager: videoManager)
                    .ignoresSafeArea(.all)
            } else {
                VStack {
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
            
            // 🔧 修正: 録画中表示を別レイヤーで固定位置に
            if isRecording {
                VStack {
                    Spacer()
                    recordingStatusView
                    Spacer()
                }
            }
            
            // 🔧 修正: 成功トースト表示を録画中と同じ位置に
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
        // 🔧 修正: エラー時のみアラート表示
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
            // 🔧 修正: 撮影ボタンの位置とアニメーションを改善
            HStack {
                Spacer()
                
                // 撮影ボタン（位置固定）
                Button(action: recordOneSecondVideo) {
                    ZStack {
                        Circle()
                            .fill(isRecording ? Color.red : Color.white)
                            .frame(width: 100, height: 100)
                            .overlay(
                                Circle()
                                    .stroke(Color.red, lineWidth: 6)
                            )
                        
                        Text(isRecording ? "Recording" : "Tap to Record")
                            .font(isRecording ? .caption : .body)
                            .fontWeight(.bold)
                            .foregroundColor(isRecording ? .white : .black)
                    }
                }
                .disabled(isRecording || currentProject == nil)
                // 🔧 修正: scaleEffectを削除してボタン移動を防止
                
                Spacer()
            }
        }
        .padding(.bottom, 50)
    }
    
    // 🔧 修正: 録画中表示を独立した固定位置に
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
    
    // 🔧 修正: 成功トースト表示を録画中と同じスタイル・位置に
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
        print("🔧 setupCamera() started")
        Task {
            print("🔧 Permission request started")
            await videoManager.requestCameraPermission()
            print("🔧 Permission request completed: \(videoManager.cameraPermissionGranted)")
            
            print("🔧 Camera setup started")
            await videoManager.setupCamera()
            print("🔧 Camera setup completed")
        }
    }
    
    private func toggleCamera() {
        Task {
            await videoManager.toggleCamera()
        }
    }
    
    // 🔧 修正: 録画完了後の処理をシンプルに
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
                
                // 🔧 修正: 自動消失する成功トースト表示
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
                // エラー時のみアラート表示
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
        let view = UIView()
        view.backgroundColor = .black
        
        DispatchQueue.main.async {
            if let previewLayer = videoManager.previewLayer {
                previewLayer.frame = view.bounds
                previewLayer.videoGravity = .resizeAspectFill
                view.layer.addSublayer(previewLayer)
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            if let previewLayer = videoManager.previewLayer {
                previewLayer.frame = uiView.bounds
            }
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
