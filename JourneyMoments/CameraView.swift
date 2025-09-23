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
            // Camera preview background
            Color.black
                .ignoresSafeArea(.all)
            
            // Fixed: Ensure setup completion before preview display
            if videoManager.cameraPermissionGranted && videoManager.isSetupComplete {
                CameraPreviewRepresentable(videoManager: videoManager)
                    .ignoresSafeArea(.all)
            } else if videoManager.cameraPermissionGranted && !videoManager.isSetupComplete {
                // Setup in progress display
                VStack(spacing: 20) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    
                    Text("Setting up camera...")
                        .foregroundColor(.white)
                        .font(.caption)
                }
            } else {
                // No permission display
                VStack(spacing: 20) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("Please allow camera access")
                        .foregroundColor(.white)
                        .padding()
                }
            }
            
            // Overlay UI
            VStack {
                // Header
                headerView
                
                Spacer()
                
                // Recording controls
                controlsView
            }
            
            // Recording status display
            if isRecording {
                VStack {
                    Spacer()
                    recordingStatusView
                    Spacer()
                }
            }
            
            // Success toast display
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
                // Back button
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
                
                // Camera toggle button
                Button(action: toggleCamera) {
                    Image(systemName: "camera.rotate.fill")
                        .font(.title2)
                        .padding(8)
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(20)
                }
                .disabled(isRecording || !videoManager.isSetupComplete)
            }
            .padding(.horizontal, 20)
            
            // Project information
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
                
                // Recording button
                Button(action: recordOneSecondVideo) {
                    ZStack {
                        Circle()
                            .fill(isRecording ? Color.red : Color.white)
                            .frame(width: 100, height: 100)
                            .overlay(
                                Circle()
                                    .stroke(Color.red, lineWidth: 6)
                            )
                        
                        if videoManager.isSetupComplete {
                            Text(isRecording ? "Recording" : "REC")
                                .font(isRecording ? .caption : .body)
                                .fontWeight(.bold)
                                .foregroundColor(isRecording ? .white : .black)
                        } else {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        }
                    }
                }
                .disabled(isRecording || currentProject == nil || !videoManager.isSetupComplete)
                .opacity((videoManager.isSetupComplete && currentProject != nil) ? 1.0 : 0.5)
                
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
        print("CameraView setupCamera() started")
        Task {
            print("Permission request started")
            await videoManager.requestCameraPermission()
            print("Permission request completed: \(videoManager.cameraPermissionGranted)")
            
            if videoManager.cameraPermissionGranted {
                print("Camera setup started")
                await videoManager.setupCamera()
                print("Camera setup completed: \(videoManager.isSetupComplete)")
            } else {
                print("Camera permission denied")
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
        guard videoManager.isSetupComplete else { return }
        
        Task {
            isRecording = true
            
            do {
                let videoURL = try await videoManager.recordOneSecond()
                
                // Save filename only (relative path)
                let filename = videoURL.lastPathComponent
                
                // Create new segment
                let newSegment = VideoSegment(
                    uri: filename,
                    cameraPosition: videoManager.currentCameraPosition,
                    order: (currentProject?.segments.count ?? 0) + 1
                )

                // Notify main screen of recording completion
                onRecordingComplete(newSegment)

                // Show success toast
                successMessage = "✅ Segment \((currentProject?.segments.count ?? 0) + 1) recorded"
                withAnimation(.easeInOut(duration: 0.3)) {
                    showSuccessToast = true
                }
                
                // Auto-hide after 1.5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showSuccessToast = false
                    }
                }
                
                print("Segment saved: \(filename) - Segment \(project.segments.count + 1) recorded")
                
            } catch {
                alertMessage = "Recording failed: \(error.localizedDescription)"
                showingAlert = true
                print("Recording error: \(error)")
            }
            
            isRecording = false
        }
    }
}

// MARK: - Camera Preview Representable
struct CameraPreviewRepresentable: UIViewRepresentable {
    let videoManager: VideoManager
    
    func makeUIView(context: Context) -> UIView {
        print("makeUIView started")
        let view = CameraContainerView()
        view.backgroundColor = .black
        view.videoManager = videoManager
        print("makeUIView completed")
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        print("updateUIView started - Frame: \(uiView.bounds)")
        
        guard let containerView = uiView as? CameraContainerView else {
            print("CameraContainerView cast failed")
            return
        }
        
        containerView.updatePreviewLayer()
        print("updateUIView completed")
    }
}

// Camera Container View
class CameraContainerView: UIView {
    weak var videoManager: VideoManager?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override func layoutSubviews() {
        super.layoutSubviews()
        print("layoutSubviews - Frame: \(bounds)")
        
        // Update preview layer after layout completion
        DispatchQueue.main.async {
            self.updatePreviewLayer()
        }
    }
    
    func updatePreviewLayer() {
        // Skip processing if bounds are zero
        guard bounds.width > 0 && bounds.height > 0 else {
            print("Skipping preview layer update due to zero bounds")
            return
        }
        
        guard let videoManager = videoManager,
              let newPreviewLayer = videoManager.previewLayer else {
            print("VideoManager or preview layer not ready")
            return
        }
        
        // Confirm setup completion
        guard videoManager.isSetupComplete else {
            print("Skipping preview layer update - camera setup incomplete")
            return
        }
        
        // Skip if same preview layer is already set
        if previewLayer === newPreviewLayer {
            // Update frame only
            newPreviewLayer.frame = bounds
            print("Updated existing preview layer frame only")
            return
        }
        
        // Remove existing preview layer
        if let existingLayer = previewLayer {
            existingLayer.removeFromSuperlayer()
            print("Removed existing preview layer")
        }
        
        // Set new preview layer
        newPreviewLayer.frame = bounds
        newPreviewLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(newPreviewLayer)
        previewLayer = newPreviewLayer
        
        print("Preview layer added successfully - Frame: \(bounds)")
        
        // Check session status
        if let session = newPreviewLayer.session, session.isRunning {
            print("Session is running")
        } else {
            print("Session is not running")
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

