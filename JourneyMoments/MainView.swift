import SwiftUI
import Photos
import AVFoundation

struct MainView: View {
    // MARK: - State Management
    @StateObject private var projectManager = ProjectManager()
    @State private var currentScreen: AppScreen = .projects
    @State private var currentProject: Project?
    @State private var currentSegmentIndex: Int = 0
    @State private var isPlaying: Bool = false
    
    // 🆕 追加: エクスポート状態管理
    @State private var showExportAlert = false
    @State private var exportError: String?
    @State private var showExportSuccess = false
    
    var body: some View {
        NavigationView {
            Group {
                switch currentScreen {
                case .projects:
                    ProjectListView(
                        projects: projectManager.projects,
                        onCreateProject: createNewProject,
                        onOpenProject: openProject,
                        onPlayProject: playProject,
                        onDeleteProject: deleteProject,
                        onRenameProject: renameProject,
                        onExportProject: exportProject  // 🆕 追加
                    )
                    
                case .camera:
                    CameraView(
                        currentProject: currentProject,
                        onRecordingComplete: handleRecordingComplete,
                        onBackToProjects: { currentScreen = .projects }
                    )
                    
                case .player:
                    if let project = currentProject {
                        PlayerView(
                            projectManager: projectManager,
                            initialProject: project,
                            onBack: {
                                currentScreen = .projects
                                isPlaying = false
                                currentSegmentIndex = 0
                            },
                            onDeleteSegment: deleteSegment
                        )
                    } else {
                        // プロジェクトが選択されていない場合のフォールバック
                        ZStack {
                            Color.black.ignoresSafeArea(.all)
                            
                            VStack(spacing: 20) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 60))
                                    .foregroundColor(.yellow)
                                
                                Text("No Project Selected")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                
                                Button("Back to Projects") {
                                    currentScreen = .projects
                                }
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                        }
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        // 🆕 追加: エクスポート関連のアラート
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
    
    // MARK: - Navigation Actions
    
    private func createNewProject() {
        let newProject = projectManager.createNewProject()
        currentProject = newProject
        currentScreen = .camera
    }
    
    private func openProject(_ project: Project) {
        isPlaying = false
        currentSegmentIndex = 0
        currentProject = project
        currentScreen = .camera
    }
    
    private func playProject(_ project: Project) {
        currentProject = project
        currentSegmentIndex = 0
        isPlaying = false
        currentScreen = .player
        print("🎬 Player screen transition: \(project.name)")
    }
    
    // プロジェクト削除機能
    private func deleteProject(_ project: Project) {
        if currentProject?.id == project.id {
            currentProject = nil
            currentScreen = .projects
        }
        
        projectManager.deleteProject(project)
        
        print("✅ Project deleted: \(project.name)")
        print("📊 Remaining projects: \(projectManager.projects.count)")
    }
    
    // プロジェクト名変更機能
    private func renameProject(_ project: Project, _ newName: String) {
        projectManager.renameProject(project, newName: newName)
        
        if currentProject?.id == project.id {
            if let updatedProject = projectManager.projects.first(where: { $0.id == project.id }) {
                currentProject = updatedProject
            }
        }
        
        print("✅ Project renamed: \(project.name) → \(newName)")
    }
    
    // 🆕 追加: エクスポート機能
    private func exportProject(_ project: Project) {
        print("🟠 Export initiated for project: \(project.name)")
        
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
    
    // セグメント削除機能
    private func deleteSegment(_ project: Project, _ segment: VideoSegment) {
        print("🗑️ Starting segment deletion: Project \(project.name), Segment \(segment.order)")
        
        projectManager.deleteSegment(from: project, segment: segment)
        
        if currentProject?.id == project.id {
            if let updatedProject = projectManager.projects.first(where: { $0.id == project.id }) {
                currentProject = updatedProject
                print("🔄 Current project updated after segment deletion")
                
                if updatedProject.segments.isEmpty {
                    print("📭 No segments left - returning to project list")
                    currentScreen = .projects
                    currentProject = nil
                }
            }
        }
        
        print("✅ Segment deletion completed: \(segment.order)")
    }
    
    // MARK: - Recording Handler
    
    private func handleRecordingComplete(_ segment: VideoSegment) {
        guard let project = currentProject else { return }
        
        var updatedProject = project
        updatedProject.addSegment(segment)
        
        currentProject = updatedProject
        projectManager.updateProject(updatedProject)
        
        print("✅ Segment added: \(updatedProject.name), Total segments: \(updatedProject.segmentCount)")
    }
    
    // MARK: - Export Functions
    
    // 写真ライブラリアクセス権限をリクエスト
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
            completion(true) // limited access でも保存は可能
        @unknown default:
            completion(false)
        }
    }
    
    // エクスポート処理を開始
    private func startExport(for project: Project) {
        print("Starting export process for: \(project.name)")
        
        Task {
            do {
                let success = await exportVideo(project: project)
                
                await MainActor.run {
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
                    self.exportError = error.localizedDescription
                    self.showExportAlert = true
                    print("Export error for \(project.name): \(error)")
                }
            }
        }
    }
    
    // 実際の動画エクスポート処理
    private func exportVideo(project: Project) async -> Bool {
        print("Creating composition for export: \(project.name)")
        
        // コンポジション作成
        guard let exportComposition = await projectManager.createComposition(for: project) else {
            print("Failed to create composition for export: \(project.name)")
            return false
        }
        
        print("Composition created successfully for: \(project.name)")
        
        // 出力ファイルのURL作成
        let outputURL = createExportURL(for: project)
        
        // 既存ファイルがあれば削除
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }
        
        // AVAssetExportSession作成
        guard let exportSession = AVAssetExportSession(
            asset: exportComposition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            print("Failed to create export session for: \(project.name)")
            return false
        }
        
        // エクスポート設定
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        print("Export settings for \(project.name):")
        print("   Output URL: \(outputURL.lastPathComponent)")
        print("   Preset: \(AVAssetExportPresetHighestQuality)")
        print("   File Type: MP4")
        
        // エクスポート実行
        await withCheckedContinuation { continuation in
            exportSession.exportAsynchronously {
                continuation.resume()
            }
        }
        
        // エクスポート結果の確認
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
    
    // エクスポートファイルのURL生成
    private func createExportURL(for project: Project) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timestamp = DateFormatter().apply {
            $0.dateFormat = "yyyyMMdd_HHmmss"
        }.string(from: Date())
        
        // 🔧 修正: ファイル名に使用できない文字を除去
        let safeName = project.name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "?", with: "")
            .replacingOccurrences(of: "<", with: "")
            .replacingOccurrences(of: ">", with: "")
            .replacingOccurrences(of: "|", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: " ", with: "_")
        
        let filename = "\(safeName)_\(timestamp).mp4"
        return documentsPath.appendingPathComponent(filename)
    }
    
    // 写真ライブラリに保存
    private func saveToPhotoLibrary(url: URL, projectName: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }) { success, error in
                if success {
                    print("Video saved to photo library: \(url.lastPathComponent) (Project: \(projectName))")
                    // 一時ファイルを削除
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


// MARK: - Preview
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
