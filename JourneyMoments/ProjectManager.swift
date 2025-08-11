import Foundation

// MARK: - ProjectManager
// React Native版のプロジェクト管理ロジックと同等
class ProjectManager: ObservableObject {
    @Published var projects: [Project] = []
    
    private let userDefaults = UserDefaults.standard
    private let projectsKey = "JourneyMoments_Projects"
    
    init() {
        loadProjects()
    }
    
    // MARK: - プロジェクト操作
    
    // 新規プロジェクト作成 (React Native版の createNewProject と同等)
    func createNewProject() -> Project {
        let projectName = "プロジェクト \(projects.count + 1)"
        let newProject = Project(name: projectName)
        
        projects.append(newProject)
        saveProjects()
        
        print("✅ 新規プロジェクト作成: \(projectName)")
        return newProject
    }
    
    // プロジェクト更新 (React Native版のプロジェクト更新と同等)
    func updateProject(_ updatedProject: Project) {
        if let index = projects.firstIndex(where: { $0.id == updatedProject.id }) {
            projects[index] = updatedProject
            saveProjects()
            print("✅ プロジェクト更新: \(updatedProject.name), セグメント数: \(updatedProject.segmentCount)")
        }
    }
    
    // プロジェクト削除
    func deleteProject(_ project: Project) {
        projects.removeAll { $0.id == project.id }
        saveProjects()
        print("🗑 プロジェクト削除: \(project.name)")
    }
    
    // MARK: - データ永続化
    
    // プロジェクト保存 (UserDefaults使用)
    private func saveProjects() {
        do {
            let data = try JSONEncoder().encode(projects)
            userDefaults.set(data, forKey: projectsKey)
            print("💾 プロジェクト保存成功: \(projects.count)件")
        } catch {
            print("❌ プロジェクト保存エラー: \(error)")
        }
    }
    
    // プロジェクト読み込み
    private func loadProjects() {
        guard let data = userDefaults.data(forKey: projectsKey) else {
            print("📂 保存されたプロジェクトなし")
            return
        }
        
        do {
            projects = try JSONDecoder().decode([Project].self, from: data)
            print("📂 プロジェクト読み込み成功: \(projects.count)件")
        } catch {
            print("❌ プロジェクト読み込みエラー: \(error)")
            projects = []
        }
    }
    
    // MARK: - ヘルパーメソッド
    
    // プロジェクト検索
    func findProject(by id: Int) -> Project? {
        return projects.first { $0.id == id }
    }
    
    // 統計情報
    var totalSegments: Int {
        return projects.reduce(0) { $0 + $1.segmentCount }
    }
}
