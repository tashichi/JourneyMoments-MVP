import SwiftUI
import Photos
import AVFoundation

struct MainView: View {
    @StateObject private var projectManager = ProjectManager()
    @StateObject private var purchaseManager = PurchaseManager()
    
    @State private var selectedProject: Project?
    @State private var currentScreen: AppScreen = .projects
    @State private var isEditingProjectName = false
    @State private var editingProject: Project?
    @State private var newProjectName = ""
    @State private var showProjectLimitAlert = false
    
    // エクスポート機能の状態管理
    @State private var showExportAlert = false
    @State private var exportError: String?
    @State private var showExportSuccess = false
    @State private var exportingProject: Project?
    @State private var exportProgress: Float = 0.0
    
    enum AppScreen {
        case projects
        case camera
        case player
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerView
                purchaseStatusView
                
                // プロジェクトリストとボタンをScrollViewで囲む
                ScrollView {
                    VStack(spacing: 30) {
                        if !projectManager.projects.isEmpty {
                            projectListContent
                        }
                        
                        actionButtons
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 50)
                }
            }
        }
        .onAppear {
            print("MainView appeared")
        }
        .navigationBarHidden(true)
        .statusBarHidden()
        .fullScreenCover(isPresented: .constant(currentScreen == .camera)) {
            if let project = selectedProject {
                CameraView(
                    currentProject: project,
                    onRecordingComplete: { videoSegment in
                        // 新しいセグメントをプロジェクトに追加
                        var updatedProject = project
                        updatedProject.segments.append(videoSegment)
                        projectManager.updateProject(updatedProject)
                    },
                    onBackToProjects: {
                        currentScreen = .projects
                    }
                )
            }
        }
        .fullScreenCover(isPresented: .constant(currentScreen == .player)) {
            if let project = selectedProject {
                PlayerView(
                    projectManager: projectManager,
                    initialProject: project,
                    onBack: {
                        currentScreen = .projects
                    },
                    onDeleteSegment: { project, segment in
                        projectManager.deleteSegment(from: project, segment: segment)
                    }
                )
            }
        }
        .alert("Rename Project", isPresented: $isEditingProjectName) {
            TextField("Project name", text: $newProjectName)
            Button("Save") {
                if let project = editingProject {
                    projectManager.renameProject(project, newName: newProjectName)
                }
                resetEditingState()
            }
            Button("Cancel", role: .cancel) {
                resetEditingState()
            }
        } message: {
            Text("Enter a new name for this project")
        }
        .alert("Project Limit Reached", isPresented: $showProjectLimitAlert) {
            Button("Upgrade to Full Version") {
                purchaseManager.simulatePurchase() // 暫定的に購入シミュレーション
                // 後で本物の購入画面に変更予定
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Free version allows up to 3 projects. Upgrade to Full Version for unlimited projects and export features.")
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
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 12) {
            Text("ClipFlow")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.top, 60)
        .padding(.bottom, 20)
    }
    
    // MARK: - Purchase Status View
    private var purchaseStatusView: some View {
        HStack {
            Text(purchaseManager.isPurchased ? "Full Version" : "Free Version")
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(purchaseManager.isPurchased ? Color.green.opacity(0.8) : Color.orange.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(8)
            
            Spacer()
            
            // テスト用ボタン（後で削除予定）
            Button(purchaseManager.isPurchased ? "Reset" : "Simulate Purchase") {
                if purchaseManager.isPurchased {
                    purchaseManager.resetPurchase()
                } else {
                    purchaseManager.simulatePurchase()
                }
            }
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(6)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }
    
    // MARK: - Project List Content
    private var projectListContent: some View {
        VStack(spacing: 16) {
            Text("Your Projects")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            LazyVStack(spacing: 12) {
                ForEach(projectManager.projects) { project in
                    projectCard(project)
                }
            }
        }
    }
    
    private func projectCard(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text("\(project.segmentCount) segments")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("Created: \(formatDate(project.createdAt))")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    Button(action: {
                        openProject(project, screen: .camera)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "camera")
                            Text("Rec")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(minWidth: 85)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(8)
                    }
                    
                    Button(action: {
                        openProject(project, screen: .player)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "play")
                            Text("Play")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(minWidth: 85)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.8))
                        .cornerRadius(8)
                    }
                    .disabled(project.segmentCount == 0)
                    .opacity(project.segmentCount == 0 ? 0.5 : 1.0)
                    
                    Button(action: {
                        exportProject(project)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(minWidth: 85)
                        .padding(.vertical, 6)
                        .background(purchaseManager.canExportVideo() ? Color.orange.opacity(0.8) : Color.gray.opacity(0.6))
                        .cornerRadius(8)
                    }
                    .disabled(project.segmentCount == 0)
                    .opacity(project.segmentCount == 0 ? 0.5 : 1.0)
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .onTapGesture {
            // タップでプロジェクト選択
            selectedProject = project
        }
        .contextMenu {
            Button(action: {
                startEditingProjectName(project)
            }) {
                Label("Rename", systemImage: "pencil")
            }
            
            Button(action: {
                deleteProject(project)
            }) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 20) {
            // New Project Button
            Button(action: {
                createNewProject()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle")
                        .font(.title2)
                    Text("New Project")
                        .font(.title3)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue.opacity(0.8))
                .cornerRadius(25)
            }
            
            if projectManager.projects.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "video.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("No Projects Yet")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Text("Create your first project to start recording 1-second memories")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.vertical, 40)
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func createNewProject() {
        print("New project button tapped")
        
        // 購入制限チェック
        if !purchaseManager.canCreateNewProject(currentProjectCount: projectManager.projects.count) {
            print("プロジェクト作成制限: 無料版は3個まで")
            showProjectLimitAlert = true
            return
        }
        
        let newProject = projectManager.createNewProject()
        selectedProject = newProject
        currentScreen = .camera
        print("New project created and selected: \(newProject.name)")
    }
    
    private func openProject(_ project: Project, screen: AppScreen) {
        selectedProject = project
        currentScreen = screen
        print("Project opened: \(project.name) in \(screen) mode")
    }
    
    private func startEditingProjectName(_ project: Project) {
        editingProject = project
        newProjectName = project.name
        isEditingProjectName = true
    }
    
    private func resetEditingState() {
        editingProject = nil
        newProjectName = ""
        isEditingProjectName = false
    }
    
    private func deleteProject(_ project: Project) {
        print("Deleting project: \(project.name)")
        
        // 選択中のプロジェクトを削除する場合
        if selectedProject?.id == project.id {
            selectedProject = nil
            currentScreen = .projects
        }
        
        projectManager.deleteProject(project)
        print("Project deleted: \(project.name)")
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
    
    // MARK: - Export Functions
    
    private func exportProject(_ project: Project) {
        print("Export button tapped for project: \(project.name)")
        
        // エクスポート制限チェック
        if !purchaseManager.canExportVideo() {
            print("Export blocked: Free version limitation")
            showProjectLimitAlert = true
            return
        }
        
        print("Export initiated for project: \(project.name)")
        
        // 写真ライブラリアクセス権限をリクエスト
        requestPhotoLibraryPermission { granted in
            if granted {
                startExport(for: project)
            } else {
                DispatchQueue.main.async {
                    self.exportError = "Photo library access denied. Please enable in Settings."
                    self.showExportAlert = true
                }
            }
        }
    }
    
    private func requestPhotoLibraryPermission(completion: @escaping (Bool) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        switch status {
        case .authorized:
            completion(true)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                completion(newStatus == .authorized)
            }
        case .denied, .restricted:
            completion(false)
        case .limited:
            completion(true)
        @unknown default:
            completion(false)
        }
    }
    
    private func startExport(for project: Project) {
        print("Starting export process for: \(project.name)")
        
        exportingProject = project
        exportProgress = 0.0
        
        Task {
            do {
                let success = await exportVideo(project: project)
                
                await MainActor.run {
                    self.exportingProject = nil
                    self.exportProgress = 0.0
                    
                    if success {
                        self.showExportSuccess = true
                        print("Export completed successfully for: \(project.name)")
                    } else {
                        self.exportError = "Export failed"
                        self.showExportAlert = true
                        print("Export failed for: \(project.name)")
                    }
                }
            } catch {
                await MainActor.run {
                    self.exportingProject = nil
                    self.exportProgress = 0.0
                    self.exportError = error.localizedDescription
                    self.showExportAlert = true
                    print("Export error for \(project.name): \(error)")
                }
            }
        }
    }
    
    private func exportVideo(project: Project) async -> Bool {
        print("Creating composition for export: \(project.name)")
        
        guard let exportComposition = await projectManager.createComposition(for: project) else {
            print("Failed to create composition for export: \(project.name)")
            return false
        }
        
        let outputURL = createExportURL(for: project)
        
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }
        
        guard let exportSession = AVAssetExportSession(
            asset: exportComposition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            print("Failed to create export session for: \(project.name)")
            return false
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            DispatchQueue.main.async {
                self.exportProgress = exportSession.progress
            }
        }
        
        await withCheckedContinuation { continuation in
            exportSession.exportAsynchronously {
                DispatchQueue.main.async {
                    progressTimer.invalidate()
                    self.exportProgress = 1.0
                }
                continuation.resume()
            }
        }
        
        switch exportSession.status {
        case .completed:
            print("Export session completed for: \(project.name)")
            return await saveToPhotoLibrary(url: outputURL, projectName: project.name)
        case .failed:
            print("Export session failed for \(project.name): \(exportSession.error?.localizedDescription ?? "Unknown error")")
            return false
        case .cancelled:
            print("Export session cancelled for: \(project.name)")
            return false
        default:
            print("Export session unknown status for \(project.name): \(exportSession.status)")
            return false
        }
    }
    
    private func createExportURL(for project: Project) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timestamp = DateFormatter().apply {
            $0.dateFormat = "yyyyMMdd_HHmmss"
        }.string(from: Date())
        
        let safeName = project.name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: " ", with: "_")
        
        let filename = "\(safeName)_\(timestamp).mp4"
        return documentsPath.appendingPathComponent(filename)
    }
    
    private func saveToPhotoLibrary(url: URL, projectName: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }) { success, error in
                if success {
                    print("Video saved to photo library: \(url.lastPathComponent) (Project: \(projectName))")
                    try? FileManager.default.removeItem(at: url)
                    continuation.resume(returning: true)
                } else {
                    print("Failed to save to photo library for \(projectName): \(error?.localizedDescription ?? "Unknown error")")
                    continuation.resume(returning: false)
                }
            }
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
