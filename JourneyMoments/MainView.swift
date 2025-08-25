import SwiftUI

struct MainView: View {
    // MARK: - State Management (React Native版と同等の状態管理)
    @StateObject private var projectManager = ProjectManager()
    @State private var currentScreen: AppScreen = .projects
    @State private var currentProject: Project?
    @State private var currentSegmentIndex: Int = 0
    @State private var isPlaying: Bool = false
    
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
                        onRenameProject: renameProject  // 🆕 追加: 名前変更機能
                    )
                    
                case .camera:
                    CameraView(
                        currentProject: currentProject,
                        onRecordingComplete: handleRecordingComplete,
                        onBackToProjects: { currentScreen = .projects }
                    )
                    
                case .player:
                    // 🎬 PlayerView統合
                    if let project = currentProject {
                        PlayerView(
                            project: project,
                            onBack: {
                                currentScreen = .projects
                                // プレイヤー終了時の状態リセット
                                isPlaying = false
                                currentSegmentIndex = 0
                            }
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
    }
    
    // MARK: - Navigation Actions (React Native版と同等の画面遷移)
    
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
        isPlaying = false  // 初期状態は停止
        currentScreen = .player
        print("🎬 Player screen transition: \(project.name)")
    }
    
    // 🔧 追加: プロジェクト削除機能
    private func deleteProject(_ project: Project) {
        // 現在選択中のプロジェクトが削除される場合、選択を解除
        if currentProject?.id == project.id {
            currentProject = nil
            currentScreen = .projects
        }
        
        // ProjectManagerで削除実行
        projectManager.deleteProject(project)
        
        print("✅ Project deleted: \(project.name)")
        print("📊 Remaining projects: \(projectManager.projects.count)")
    }
    
    // 🆕 追加: プロジェクト名変更機能
    private func renameProject(_ project: Project, _ newName: String) {
        // 現在選択中のプロジェクトの名前が変更される場合、currentProjectも更新
        if currentProject?.id == project.id {
            var updatedCurrentProject = project
            updatedCurrentProject.name = newName
            currentProject = updatedCurrentProject
        }
        
        // ProjectManagerで名前変更実行
        projectManager.renameProject(project, newName: newName)
        
        print("✅ Project renamed: \(project.name) → \(newName)")
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
}

// MARK: - Preview
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
