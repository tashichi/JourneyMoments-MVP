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
    @State private var showPurchaseView = false
    
    // エクスポート機能の状態管理
    @State private var showExportAlert = false
    @State private var exportError: String?
    @State private var showExportSuccess = false
    @State private var exportingProject: Project?
    @State private var exportProgress: Float = 0.0
    
    // 削除確認の状態管理
    @State private var showDeleteConfirmation = false
    @State private var projectToDelete: Project?
    
    enum AppScreen {
        case projects
        case camera
        case player
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // ← ProjectListViewに統合
                ProjectListView(
                    projects: projectManager.projects,
                    onCreateProject: {
                        createNewProject()
                    },
                    onOpenProject: { project in
                        openProject(project, screen: .camera)
                    },
                    onPlayProject: { project in
                        openProject(project, screen: .player)
                    },
                    onDeleteProject: { project in
                        confirmDeleteProject(project)
                    },
                    onRenameProject: { project, newName in
                        projectManager.renameProject(project, newName: newName)
                    },
                    onExportProject: { project in
                        exportProject(project)
                    },
                    purchaseManager: purchaseManager
                )
            }
            
            // エクスポート進捗オーバーレイ
            if let project = exportingProject {
                exportProgressOverlay(for: project)
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
                        // 最新のプロジェクト状態を取得
                        guard let currentProject = projectManager.projects.first(where: { $0.id == project.id }) else { return }
                        
                        var updatedProject = currentProject  // 最新の状態を使用
                        updatedProject.segments.append(videoSegment)
                        projectManager.updateProject(updatedProject)
                        
                        // selectedProjectも更新
                        selectedProject = updatedProject
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
        .alert("Project Limit Reached", isPresented: $showProjectLimitAlert) {
            Button("Upgrade to Full Version") {
                showPurchaseView = true
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Free version allows up to 3 projects. Upgrade to Full Version for unlimited projects and export features.")
        }
        .alert("Delete Project", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let project = projectToDelete {
                    deleteProject(project)
                }
                projectToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                projectToDelete = nil
            }
        } message: {
            if let project = projectToDelete {
                Text("Delete \"\(project.name)\"?\nThis action cannot be undone.")
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
        .sheet(isPresented: $showPurchaseView) {
            PurchaseView(purchaseManager: purchaseManager)
        }
    }
    
    // Export Progress Overlay
    private func exportProgressOverlay(for project: Project) -> some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // プロジェクト情報
                VStack(spacing: 8) {
                    Text("Exporting Video")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(project.name)
                        .font(.headline)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                }
                
                // 進捗表示
                VStack(spacing: 15) {
                    ProgressView(value: exportProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                        .frame(width: 280, height: 6)
                        .scaleEffect(y: 2)
                    
                    Text("\(Int(exportProgress * 100))%")
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .monospacedDigit()
                }
                
                // 注意事項
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                        Text("Keep app active during export")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Text("Do not switch apps or lock screen")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemGray6).opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 30)
        }
    }
    
    // MARK: - Helper Functions
    
    private func createNewProject() {
        print("New project button tapped")
        
        // 購入制限チェック
        if !purchaseManager.canCreateNewProject(currentProjectCount: projectManager.projects.count) {
            print("Project creation limit: Free version allows up to 3 - Show purchase screen")
            showPurchaseView = true
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
    
    private func confirmDeleteProject(_ project: Project) {
        projectToDelete = project
        showDeleteConfirmation = true
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
            print("Export blocked: Free version limitation - Show purchase screen")
            showPurchaseView = true
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
                // 権限許可直後の安全な処理
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    completion(newStatus == .authorized)
                }
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
        
        // スリープ防止を有効化
        UIApplication.shared.isIdleTimerDisabled = true
        print("Sleep prevention enabled")
        
        Task {
            do {
                let success = await exportVideo(project: project)
                
                await MainActor.run {
                    // スリープ防止を無効化
                    UIApplication.shared.isIdleTimerDisabled = false
                    print("Sleep prevention disabled")
                    
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
                    // エラー時もスリープ防止を無効化
                    UIApplication.shared.isIdleTimerDisabled = false
                    print("Sleep prevention disabled (error)")
                    
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
        
        // 頻繁な進捗監視
        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
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
