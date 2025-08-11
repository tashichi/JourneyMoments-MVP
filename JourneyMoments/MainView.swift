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
                        onPlayProject: playProject
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
                                
                                Text("プロジェクトが選択されていません")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                
                                Button("プロジェクト一覧に戻る") {
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
        print("🎬 プレイヤー画面に遷移: \(project.name)")
    }
    
    // MARK: - Recording Handler
    
    private func handleRecordingComplete(_ segment: VideoSegment) {
        guard let project = currentProject else { return }
        
        var updatedProject = project
        updatedProject.addSegment(segment)
        
        currentProject = updatedProject
        projectManager.updateProject(updatedProject)
        
        print("✅ セグメント追加完了: \(updatedProject.name), 総セグメント数: \(updatedProject.segmentCount)")
    }
}

// MARK: - Preview
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
