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
        let projectName = "Project \(projects.count + 1)"
        let newProject = Project(name: projectName)
        
        projects.append(newProject)
        saveProjects()
        
        print("✅ New project created: \(projectName)")
        return newProject
    }
    
    // プロジェクト更新 (React Native版のプロジェクト更新と同等)
    func updateProject(_ updatedProject: Project) {
        if let index = projects.firstIndex(where: { $0.id == updatedProject.id }) {
            projects[index] = updatedProject
            saveProjects()
            print("✅ Project updated: \(updatedProject.name), Segments: \(updatedProject.segmentCount)")
        }
    }
    
    // プロジェクト名変更機能
    func renameProject(_ project: Project, newName: String) {
        print("🏷️ Project rename started: \(project.name) → \(newName)")
        
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            var updatedProject = projects[index]
            updatedProject.name = newName
            projects[index] = updatedProject
            saveProjects()
            
            print("✅ Project renamed successfully: \(project.name) → \(newName)")
        } else {
            print("❌ Project not found for rename: \(project.name)")
        }
    }
    
    // 🆕 追加: セグメント削除機能
    func deleteSegment(from project: Project, segment: VideoSegment) {
        print("🗑️ Segment deletion started: Project \(project.name), Segment \(segment.order)")
        
        guard let projectIndex = projects.firstIndex(where: { $0.id == project.id }) else {
            print("❌ Project not found for segment deletion: \(project.name)")
            return
        }
        
        var updatedProject = projects[projectIndex]
        
        // 1. セグメントが2つ以上ある場合のみ削除可能
        guard updatedProject.segments.count > 1 else {
            print("❌ Cannot delete last segment from project: \(project.name)")
            return
        }
        
        // 2. 物理ファイル削除
        deleteVideoFile(for: segment)
        
        // 3. プロジェクトからセグメントを削除
        updatedProject.segments.removeAll { $0.id == segment.id }
        
        // 4. セグメントの順序を再調整（削除後の連続性を保つ）
        updatedProject.segments = updatedProject.segments.enumerated().map { index, seg in
            var updatedSegment = seg
            updatedSegment.order = index + 1
            return updatedSegment
        }
        
        // 5. プロジェクトを更新して保存
        projects[projectIndex] = updatedProject
        saveProjects()
        
        print("✅ Segment deleted successfully: \(segment.order)")
        print("📊 Remaining segments in project: \(updatedProject.segments.count)")
        print("🔄 Segment order rebalanced")
    }
    
    // セグメント用の個別ファイル削除
    private func deleteVideoFile(for segment: VideoSegment) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
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
                print("🗑 Segment file deleted: \(fileURL.lastPathComponent)")
            } else {
                print("⚠️ Segment file not found: \(fileURL.lastPathComponent)")
            }
        } catch {
            print("❌ Segment file deletion error: \(fileURL.lastPathComponent) - \(error)")
        }
    }
    
    // プロジェクト削除（完全版：データ + 動画ファイル削除）
    func deleteProject(_ project: Project) {
        print("🗑 Project deletion started: \(project.name)")
        
        // 1. 動画ファイルを物理削除
        deleteVideoFiles(for: project)
        
        // 2. プロジェクトリストから削除
        projects.removeAll { $0.id == project.id }
        
        // 3. UserDefaultsに保存
        saveProjects()
        
        print("✅ Project deletion completed: \(project.name)")
        print("📊 Remaining projects: \(projects.count)")
    }
    
    // 動画ファイルの物理削除
    private func deleteVideoFiles(for project: Project) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        var deletedCount = 0
        var errorCount = 0
        
        print("🔍 Target segments for deletion: \(project.segments.count)")
        
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
                    print("🗑 File deleted: \(fileURL.lastPathComponent)")
                } else {
                    print("⚠️ File not found: \(fileURL.lastPathComponent)")
                }
            } catch {
                errorCount += 1
                print("❌ File deletion error: \(fileURL.lastPathComponent) - \(error)")
            }
        }
        
        print("📊 File deletion result: Success \(deletedCount), Errors \(errorCount)")
    }
    
    // MARK: - データ永続化
    
    // プロジェクト保存 (UserDefaults使用)
    private func saveProjects() {
        do {
            let data = try JSONEncoder().encode(projects)
            userDefaults.set(data, forKey: projectsKey)
            print("💾 Projects saved successfully: \(projects.count) items")
        } catch {
            print("❌ Project save error: \(error)")
        }
    }
    
    // プロジェクト読み込み
    private func loadProjects() {
        guard let data = userDefaults.data(forKey: projectsKey) else {
            print("📂 No saved projects found")
            return
        }
        
        do {
            projects = try JSONDecoder().decode([Project].self, from: data)
            print("📂 Projects loaded successfully: \(projects.count) items")
        } catch {
            print("❌ Project load error: \(error)")
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
        print("🗑 All projects deletion started")
        
        for project in projects {
            deleteVideoFiles(for: project)
        }
        
        projects.removeAll()
        saveProjects()
        
        print("✅ All projects deletion completed")
    }
}
