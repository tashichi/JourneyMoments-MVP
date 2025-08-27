import Foundation
import AVFoundation

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
    
    // セグメント削除機能
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
    
    // 🆕 追加: AVComposition作成機能（シームレス再生用）
    func createComposition(for project: Project) async -> AVComposition? {
        print("🎬 Creating composition for project: \(project.name)")
        print("📊 Total segments: \(project.segments.count)")
        
        let composition = AVMutableComposition()
        
        guard !project.segments.isEmpty else {
            print("❌ No segments to compose")
            return nil
        }
        
        // 動画トラックと音声トラックを作成
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            print("❌ Failed to create composition tracks")
            return nil
        }
        
        var currentTime = CMTime.zero
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // セグメントを順序通りに処理
        let sortedSegments = project.segments.sorted { $0.order < $1.order }
        
        for (index, segment) in sortedSegments.enumerated() {
            // ファイルURL構築
            let fileURL: URL
            if !segment.uri.hasPrefix("/") {
                fileURL = documentsPath.appendingPathComponent(segment.uri)
            } else {
                fileURL = URL(fileURLWithPath: segment.uri)
            }
            
            // ファイル存在確認
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                print("❌ Segment file not found: \(fileURL.lastPathComponent)")
                continue
            }
            
            // AVURLAsset作成（iOS 18対応）
            let asset = AVURLAsset(url: fileURL)
            
            do {
                // 非推奨API対応: loadTracks使用
                let assetVideoTracks = try await asset.loadTracks(withMediaType: .video)
                let assetAudioTracks = try await asset.loadTracks(withMediaType: .audio)
                let assetDuration = try await asset.load(.duration)
                
                // 動画トラックを追加
                if let assetVideoTrack = assetVideoTracks.first {
                    let timeRange = CMTimeRange(start: .zero, duration: assetDuration)
                    try videoTrack.insertTimeRange(timeRange, of: assetVideoTrack, at: currentTime)
                    
                    // 🔧 追加: 動画の向き補正を適用
                    if index == 0 {
                        // 最初のセグメントから向き情報を取得してcomposition全体に適用
                        let transform = assetVideoTrack.preferredTransform
                        let naturalSize = assetVideoTrack.naturalSize
                        
                        // compositionに向き情報を設定
                        videoTrack.preferredTransform = transform
                        
                        // 向きに応じてcompositionのサイズを調整
                        let angle = atan2(transform.b, transform.a)
                        let isRotated = abs(angle) > .pi / 4
                        
                        if isRotated {
                            // 90度または270度回転の場合、幅と高さを入れ替え
                            composition.naturalSize = CGSize(width: naturalSize.height, height: naturalSize.width)
                            print("🔄 Composition rotated: \(naturalSize) → \(composition.naturalSize)")
                        } else {
                            composition.naturalSize = naturalSize
                            print("🔄 Composition normal: \(naturalSize)")
                        }
                        
                        print("🔄 Transform applied: \(transform)")
                    }
                    
                    print("✅ Video track added: Segment \(segment.order)")
                }
                
                // 音声トラックを追加
                if let assetAudioTrack = assetAudioTracks.first {
                    let timeRange = CMTimeRange(start: .zero, duration: assetDuration)
                    try audioTrack.insertTimeRange(timeRange, of: assetAudioTrack, at: currentTime)
                    print("✅ Audio track added: Segment \(segment.order)")
                }
                
                // 次のセグメントの開始時間を更新
                currentTime = CMTimeAdd(currentTime, assetDuration)
                print("🔄 Current composition time: \(currentTime.seconds)s")
                
            } catch {
                print("❌ Failed to add segment \(segment.order): \(error)")
            }
        }
        
        let totalDuration = currentTime.seconds
        print("🎬 Composition created successfully")
        print("📊 Total duration: \(totalDuration)s")
        print("📊 Total segments processed: \(sortedSegments.count)")
        
        return composition
    }
    
    // 🆕 追加: セグメント位置計算機能（統合再生用）
    func getSegmentTimeRanges(for project: Project) async -> [(segment: VideoSegment, timeRange: CMTimeRange)] {
        var result: [(VideoSegment, CMTimeRange)] = []
        var currentTime = CMTime.zero
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        let sortedSegments = project.segments.sorted { $0.order < $1.order }
        
        for segment in sortedSegments {
            // ファイルURL構築
            let fileURL: URL
            if !segment.uri.hasPrefix("/") {
                fileURL = documentsPath.appendingPathComponent(segment.uri)
            } else {
                fileURL = URL(fileURLWithPath: segment.uri)
            }
            
            // ファイル存在確認
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                continue
            }
            
            do {
                let asset = AVURLAsset(url: fileURL)
                let duration = try await asset.load(.duration)
                let timeRange = CMTimeRange(start: currentTime, duration: duration)
                
                result.append((segment, timeRange))
                currentTime = CMTimeAdd(currentTime, duration)
            } catch {
                print("❌ Failed to load duration for segment \(segment.order): \(error)")
            }
        }
        
        return result
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
