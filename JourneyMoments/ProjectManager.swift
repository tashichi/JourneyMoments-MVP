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
        let projectName = "Project  \(projects.count + 1)"
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
    
    // プロジェクト削除（完全版：データ + 動画ファイル削除）
    func deleteProject(_ project: Project) {
        print("🗑 プロジェクト削除開始: \(project.name)")
        
        // 1. 動画ファイルを物理削除
        deleteVideoFiles(for: project)
        
        // 2. プロジェクトリストから削除
        projects.removeAll { $0.id == project.id }
        
        // 3. UserDefaultsに保存
        saveProjects()
        
        print("✅ プロジェクト削除完了: \(project.name)")
        print("📊 残りプロジェクト数: \(projects.count)")
    }
    
    // 動画ファイルの物理削除
    private func deleteVideoFiles(for project: Project) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        var deletedCount = 0
        var errorCount = 0
        
        print("🔍 削除対象セグメント数: \(project.segments.count)")
        
        for segment in project.segments {
            let fileURL: URL
            
            // ファイル名のみの場合（新しい形式）
            if !segment.uri.hasPrefix("/") {
                fileURL = documentsPath.appendingPathComponent(segment.uri)
            } else {
                // 絶対パスの場合（旧い形式）- 後方互換性
                fileURL = URL(fileURLWithPath: segment.uri)
            }
            
            do {
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    try FileManager.default.removeItem(at: fileURL)
                    deletedCount += 1
                    print("🗑 ファイル削除: \(fileURL.lastPathComponent)")
                } else {
                    print("⚠️ ファイル未発見: \(fileURL.lastPathComponent)")
                }
            } catch {
                errorCount += 1
                print("❌ ファイル削除エラー: \(fileURL.lastPathComponent) - \(error)")
            }
        }
        
        print("📊 ファイル削除結果: 成功 \(deletedCount)件、エラー \(errorCount)件")
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
    
    // 全プロジェクト削除（開発・テスト用）
    func deleteAllProjects() {
        print("🗑 全プロジェクト削除開始")
        
        for project in projects {
            deleteVideoFiles(for: project)
        }
        
        projects.removeAll()
        saveProjects()
        
        print("✅ 全プロジェクト削除完了")
    }
}
