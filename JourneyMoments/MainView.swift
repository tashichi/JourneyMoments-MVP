import SwiftUI
import Photos
import AVFoundation
import UIKit

struct MainView: View {
    // MARK: - State Management
    @StateObject private var projectManager = ProjectManager()
    @State private var currentScreen: AppScreen = .projects
    @State private var currentProject: Project?
    @State private var currentSegmentIndex: Int = 0
    @State private var isPlaying: Bool = false
    
    // エクスポート状態管理（改善版）
    @State private var showExportAlert = false
    @State private var exportError: String?
    @State private var showExportSuccess = false
    @State private var exportingProject: Project? // 🆕 追加: エクスポート中のプロジェクト
    @State private var exportProgress: Float = 0.0 // 🆕 追加: 進捗状況
    
    var body: some View {
        ZStack {
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
                            onExportProject: exportProject
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
            
            // 🆕 追加: エクスポート中の全画面オーバーレイ
            if let project = exportingProject {
                exportProgressOverlay(for: project)
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
    }
    
    // 🆕 追加: エクスポート進捗オーバーレイ
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
        print("Player screen transition: \(project.name)")
    }
    
    private func deleteProject(_ project: Project) {
        if currentProject?.id == project.id {
            currentProject = nil
            currentScreen = .projects
        }
        
        projectManager.deleteProject(project)
        
        print("Project deleted: \(project.name)")
        print("Remaining projects: \(projectManager.projects.count)")
    }
    
    private func renameProject(_ project: Project, _ newName: String) {
        projectManager.renameProject(project, newName: newName)
        
        if currentProject?.id == project.id {
            if let updatedProject = projectManager.projects.first(where: { $0.id == project.id }) {
                currentProject = updatedProject
            }
        }
        
        print("Project renamed: \(project.name) → \(newName)")
    }
    
    // 🔧 修正: エクスポート機能（進捗・スリープ防止対応）
    private func exportProject(_ project: Project) {
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
    
    private func deleteSegment(_ project: Project, _ segment: VideoSegment) {
        print("Starting segment deletion: Project \(project.name), Segment \(segment.order)")
        
        projectManager.deleteSegment(from: project, segment: segment)
        
        if currentProject?.id == project.id {
            if let updatedProject = projectManager.projects.first(where: { $0.id == project.id }) {
                currentProject = updatedProject
                print("Current project updated after segment deletion")
                
                if updatedProject.segments.isEmpty {
                    print("No segments left - returning to project list")
                    currentScreen = .projects
                    currentProject = nil
                }
            }
        }
        
        print("Segment deletion completed: \(segment.order)")
    }
    
    // MARK: - Recording Handler
    
    private func handleRecordingComplete(_ segment: VideoSegment) {
        guard let project = currentProject else { return }
        
        var updatedProject = project
        updatedProject.addSegment(segment)
        
        currentProject = updatedProject
        projectManager.updateProject(updatedProject)
        
        print("Segment added: \(updatedProject.name), Total segments: \(updatedProject.segmentCount)")
    }
    
    // MARK: - Export Functions
    
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
    
    // 🔧 修正: エクスポート開始（スリープ防止・進捗表示）
    private func startExport(for project: Project) {
        print("Starting export process for: \(project.name)")
        
        // エクスポート中状態を設定
        exportingProject = project
        exportProgress = 0.0
        
        // 🆕 追加: スリープ防止を有効化
        UIApplication.shared.isIdleTimerDisabled = true
        print("Sleep prevention enabled")
        
        Task {
            do {
                let success = await exportVideo(project: project)
                
                await MainActor.run {
                    // 🆕 追加: スリープ防止を無効化
                    UIApplication.shared.isIdleTimerDisabled = false
                    print("Sleep prevention disabled")
                    
                    // エクスポート状態をリセット
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
    
    // 🔧 修正: 動画エクスポート（進捗監視強化）
    private func exportVideo(project: Project) async -> Bool {
        print("Creating composition for export: \(project.name)")
        
        guard let exportComposition = await projectManager.createComposition(for: project) else {
            print("Failed to create composition for export: \(project.name)")
            return false
        }
        
        print("Composition created successfully for: \(project.name)")
        
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
        
        print("Export settings for \(project.name):")
        print("   Output URL: \(outputURL.lastPathComponent)")
        print("   Preset: \(AVAssetExportPresetHighestQuality)")
        print("   File Type: MP4")
        
        // 🔧 修正: より頻繁な進捗監視
        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            DispatchQueue.main.async {
                self.exportProgress = exportSession.progress
                print("Export progress: \(Int(exportSession.progress * 100))%")
            }
        }
        
        // エクスポート実行
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
    
    // 🔧 修正: 安全なファイル名生成
    private func createExportURL(for project: Project) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timestamp = DateFormatter().apply {
            $0.dateFormat = "yyyyMMdd_HHmmss"
        }.string(from: Date())
        
        // ファイル名に使用できない文字を除去
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


// MARK: - Preview
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
