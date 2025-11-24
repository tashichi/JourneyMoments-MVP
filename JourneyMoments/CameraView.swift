import SwiftUI
import AVFoundation
import AVKit
import MediaPlayer

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
    @State private var isTorchOn = false
    
    // MARK: - Volume Button Shutter States
    @State private var lastVolumeLevel: Float = 0
    @State private var volumeObserver: NSObjectProtocol?
    @State private var volumeView: MPVolumeView?
    @State private var volumeCheckTimer: Timer?
    
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
            setupVolumeButtonShutter()
        }
        .onDisappear {
            if isTorchOn {
                toggleTorch()
            }
            // ✅ ここだけ追加
                if let timer = volumeCheckTimer {
                    timer.invalidate()
                    volumeCheckTimer = nil
                }
            videoManager.stopSession()
            removeVolumeButtonShutter()
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
            ZStack {
                // Light button (left side)
                HStack {
                    Button(action: toggleTorch) {
                        Image(systemName: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                            .font(.system(size: 24))
                            .foregroundColor(isTorchOn ? .yellow : .gray)
                            .frame(width: 50, height: 50)
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(10)
                    }
                    .padding(.leading, 20)
                    
                    Spacer()
                }
                
                // Recording button (center)
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
                
                let filename = videoURL.lastPathComponent
                
                let newSegment = VideoSegment(
                    uri: filename,
                    cameraPosition: videoManager.currentCameraPosition,
                    order: (currentProject?.segments.count ?? 0) + 1
                )
                
                onRecordingComplete(newSegment)
                
                successMessage = "✅ Segment \((currentProject?.segments.count ?? 0) + 1) recorded"
                withAnimation(.easeInOut(duration: 0.3)) {
                    showSuccessToast = true
                }
                
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
    
    private func toggleTorch() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                    for: .video,
                                                    position: .back) else {
            print("Back camera not found")
            return
        }
        
        guard device.hasTorch else {
            print("This device does not support torch")
            return
        }
        
        do {
            try device.lockForConfiguration()
            
            if isTorchOn {
                device.torchMode = .off
                isTorchOn = false
                print("Torch: OFF")
            } else {
                try device.setTorchModeOn(level: 1.0)
                isTorchOn = true
                print("Torch: ON")
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Torch control error: \(error)")
        }
    }
    
    // MARK: - Volume Button Shutter Implementation (Struct-Compatible)
    
    private func setupVolumeButtonShutter() {
        print("📍 Step 1: Setting up AVAudioSession")
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(
                .record,
                mode: .videoRecording,
                options: [.duckOthers, .allowBluetooth]
            )
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            lastVolumeLevel = audioSession.outputVolume
            print("✅ AVAudioSession configured - Initial volume: \(lastVolumeLevel)")
        } catch {
            print("❌ AVAudioSession configuration failed: \(error.localizedDescription)")
            return
        }
        
        print("📍 Step 2: Adding MPVolumeView to window")
        
        let volumeView = MPVolumeView()
        volumeView.frame = CGRect(x: -1000, y: -1000, width: 100, height: 100)
        
        if let keyWindow = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) {
            keyWindow.addSubview(volumeView)
            self.volumeView = volumeView
            print("✅ MPVolumeView added to key window")
        } else {
            print("❌ Key window not found")
            return
        }
        
        print("📍 Step 3: Setting up volume change notification observer")
        
        // Use NotificationCenter without capture list issues
        let observer = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { _ in
            // Handle volume change (cannot access self directly in struct closure)
            let audioSession = AVAudioSession.sharedInstance()
            let currentVolume = audioSession.outputVolume
            
            print("🔊 Volume changed: \(lastVolumeLevel) → \(currentVolume)")
            
            if currentVolume > lastVolumeLevel {
                print("🎥 🎥 🎥 VOLUME UP - RECORDING! 🎥 🎥 🎥")
                // Unable to call recordOneSecondVideo() directly from closure in Struct
                // Will use alternative approach below
            } else if currentVolume < lastVolumeLevel {
                print("🔇 Volume DOWN detected")
            }
        }
        
        volumeObserver = observer
        
        print("✅ Volume button shutter setup complete")
        
        // Alternative: Use Timer-based polling instead of NotificationCenter
        // This avoids closure capture issues in Struct
        setupVolumePolling()
    }
    
    private func setupVolumePolling() {
        print("📍 Setting up volume polling (alternative method)")
        
        volumeCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            let audioSession = AVAudioSession.sharedInstance()
            let currentVolume = audioSession.outputVolume
            
            // Detect volume change
            if abs(currentVolume - lastVolumeLevel) > 0.01 {
                print("🔊 Volume changed: \(lastVolumeLevel) → \(currentVolume)")
                
                if currentVolume > lastVolumeLevel {
                    print("🎥 🎥 🎥 VOLUME UP - RECORDING! 🎥 🎥 🎥")
                    // This will now properly call recordOneSecondVideo
                    DispatchQueue.main.async {
                        recordOneSecondVideo()
                    }
                } else if currentVolume < lastVolumeLevel {
                    print("🔇 Volume DOWN detected")
                }
                
                lastVolumeLevel = currentVolume
            }
        }
        
        print("✅ Volume polling started")
    }
    
    private func removeVolumeButtonShutter() {
        print("📍 Removing volume button shutter")
        
        if let observer = volumeObserver {
            NotificationCenter.default.removeObserver(observer)
            volumeObserver = nil
            print("✅ Volume observer removed")
        }
        
        if let timer = volumeCheckTimer {
            timer.invalidate()
            volumeCheckTimer = nil
            print("✅ Volume polling timer stopped")
        }
        
        if let view = volumeView {
            view.removeFromSuperview()
            volumeView = nil
            print("✅ MPVolumeView removed")
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

// MARK: - Camera Container View
class CameraContainerView: UIView {
    weak var videoManager: VideoManager?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override func layoutSubviews() {
        super.layoutSubviews()
        print("layoutSubviews - Frame: \(bounds)")
        
        DispatchQueue.main.async {
            self.updatePreviewLayer()
        }
    }
    
    func updatePreviewLayer() {
        guard bounds.width > 0 && bounds.height > 0 else {
            print("Skipping preview layer update due to zero bounds")
            return
        }
        
        guard let videoManager = videoManager,
              let newPreviewLayer = videoManager.previewLayer else {
            print("VideoManager or preview layer not ready")
            return
        }
        
        guard videoManager.isSetupComplete else {
            print("Skipping preview layer update - camera setup incomplete")
            return
        }
        
        if previewLayer === newPreviewLayer {
            newPreviewLayer.frame = bounds
            print("Updated existing preview layer frame only")
            return
        }
        
        if let existingLayer = previewLayer {
            existingLayer.removeFromSuperlayer()
            print("Removed existing preview layer")
        }
        
        newPreviewLayer.frame = bounds
        newPreviewLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(newPreviewLayer)
        previewLayer = newPreviewLayer
        
        print("Preview layer added successfully - Frame: \(bounds)")
        
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
