import Foundation
import AVFoundation
import UIKit
import Photos

// MARK: - ProjectManager
// Equivalent to React Native version project management logic
class ProjectManager: ObservableObject {
    @Published var projects: [Project] = []
    
    private let userDefaults = UserDefaults.standard
    private let projectsKey = "JourneyMoments_Projects"
    
    init() {
        loadProjects()
    }
    
    // MARK: - Project Operations
    
    // Create new project (equivalent to React Native createNewProject)
    func createNewProject() -> Project {
        let projectName = "Project \(projects.count + 1)"
        let newProject = Project(name: projectName)
        
        projects.append(newProject)
        saveProjects()
        
        print("New project created: \(projectName)")
        return newProject
    }
    
    // Update project (equivalent to React Native project update)
    func updateProject(_ updatedProject: Project) {
        if let index = projects.firstIndex(where: { $0.id == updatedProject.id }) {
            projects[index] = updatedProject
            saveProjects()
            print("Project updated: \(updatedProject.name), Segments: \(updatedProject.segmentCount)")
        }
    }
    
    // Project rename functionality
    func renameProject(_ project: Project, newName: String) {
        print("Project rename started: \(project.name) → \(newName)")
        
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            var updatedProject = projects[index]
            updatedProject.name = newName
            projects[index] = updatedProject
            saveProjects()
            
            print("Project renamed successfully: \(project.name) → \(newName)")
        } else {
            print("Project not found for rename: \(project.name)")
        }
    }
    
    // Segment deletion functionality
    func deleteSegment(from project: Project, segment: VideoSegment) {
        print("Segment deletion started: Project \(project.name), Segment \(segment.order)")
        
        guard let projectIndex = projects.firstIndex(where: { $0.id == project.id }) else {
            print("Project not found for segment deletion: \(project.name)")
            return
        }
        
        var updatedProject = projects[projectIndex]
        
        // 1. Only allow deletion if there are 2 or more segments
        guard updatedProject.segments.count > 1 else {
            print("Cannot delete last segment from project: \(project.name)")
            return
        }
        
        // 2. Delete physical file
        deleteVideoFile(for: segment)
        
        // 3. Remove segment from project
        updatedProject.segments.removeAll { $0.id == segment.id }
        
        // 4. Reorder segments (maintain continuity after deletion)
        updatedProject.segments = updatedProject.segments.enumerated().map { index, seg in
            var updatedSegment = seg
            updatedSegment.order = index + 1
            return updatedSegment
        }
        
        // 5. Update and save project
        projects[projectIndex] = updatedProject
        saveProjects()
        
        print("Segment deleted successfully: \(segment.order)")
        print("Remaining segments in project: \(updatedProject.segments.count)")
        print("Segment order rebalanced")
    }
    
    // MARK: - Export Functionality (Step-by-step debug version)
    func exportProject(_ project: Project, completion: @escaping (Bool) -> Void) {
        print("[Camera Conflict Avoidance] Export started")
        print("Project: \(project.name)")
        print("Segment count: \(project.segments.count)")
        
        // Step 1: Basic check
        guard !project.segments.isEmpty else {
            print("Empty project")
            completion(false)
            return
        }
        print("Step 1: Project validation completed")
        
        // Step 2: Wait for Face ID system stabilization
        print("Face ID system stabilization wait started...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            print("Wait completed, permission check started")
            
            let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
            print("Permission status after delay: \(status.rawValue)")
            
            switch status {
            case .authorized:
                print("Step 2: Permission granted (authorized)")
                completion(true)
            case .limited:
                print("Step 2: Permission granted (limited)")
                completion(true)
            case .notDetermined:
                print("Step 2: Permission undetermined - will not request")
                completion(false)
            case .denied:
                print("Step 2: Permission denied")
                completion(false)
            case .restricted:
                print("Step 2: Permission restricted")
                completion(false)
            @unknown default:
                print("Step 2: Unknown permission status")
                completion(false)
            }
        }
    }
    
    
    // Add: AVComposition creation functionality (for seamless playback)
    func createComposition(for project: Project) async -> AVComposition? {
        print("Creating composition for project: \(project.name)")
        print("Total segments: \(project.segments.count)")
        
        let composition = AVMutableComposition()
        
        guard !project.segments.isEmpty else {
            print("No segments to compose")
            return nil
        }
        
        // Create video and audio tracks
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            print("Failed to create composition tracks")
            return nil
        }
        
        var currentTime = CMTime.zero
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // Process segments in order
        let sortedSegments = project.segments.sorted { $0.order < $1.order }
        
        for (index, segment) in sortedSegments.enumerated() {
            // Build file URL
            let fileURL: URL
            if !segment.uri.hasPrefix("/") {
                fileURL = documentsPath.appendingPathComponent(segment.uri)
            } else {
                fileURL = URL(fileURLWithPath: segment.uri)
            }
            
            // Check file existence
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                print("Segment file not found: \(fileURL.lastPathComponent)")
                continue
            }
            
            // Create AVURLAsset (iOS 18 compatible)
            let asset = AVURLAsset(url: fileURL)
            
            do {
                // Deprecated API handling: use loadTracks
                let assetVideoTracks = try await asset.loadTracks(withMediaType: .video)
                let assetAudioTracks = try await asset.loadTracks(withMediaType: .audio)
                let assetDuration = try await asset.load(.duration)
                
                // Add video track
                if let assetVideoTrack = assetVideoTracks.first {
                    let timeRange = CMTimeRange(start: .zero, duration: assetDuration)
                    try videoTrack.insertTimeRange(timeRange, of: assetVideoTrack, at: currentTime)
                    
                    // Add: Apply video orientation correction
                    if index == 0 {
                        // Get orientation info from first segment and apply to entire composition
                        let transform = assetVideoTrack.preferredTransform
                        let naturalSize = assetVideoTrack.naturalSize
                        
                        // Set orientation info for composition
                        videoTrack.preferredTransform = transform
                        
                        // Adjust composition size based on orientation
                        let angle = atan2(transform.b, transform.a)
                        let isRotated = abs(angle) > .pi / 4
                        
                        if isRotated {
                            // For 90 or 270 degree rotation, swap width and height
                            composition.naturalSize = CGSize(width: naturalSize.height, height: naturalSize.width)
                            print("Composition rotated: \(naturalSize) → \(composition.naturalSize)")
                        } else {
                            composition.naturalSize = naturalSize
                            print("Composition normal: \(naturalSize)")
                        }
                        
                        print("Transform applied: \(transform)")
                    }
                    
                    print("Video track added: Segment \(segment.order)")
                }
                
                // Add audio track
                if let assetAudioTrack = assetAudioTracks.first {
                    let timeRange = CMTimeRange(start: .zero, duration: assetDuration)
                    try audioTrack.insertTimeRange(timeRange, of: assetAudioTrack, at: currentTime)
                    print("Audio track added: Segment \(segment.order)")
                }
                
                // Update start time for next segment
                currentTime = CMTimeAdd(currentTime, assetDuration)
                print("Current composition time: \(currentTime.seconds)s")
                
            } catch {
                print("Failed to add segment \(segment.order): \(error)")
            }
        }
        
        let totalDuration = currentTime.seconds
        print("Composition created successfully")
        print("Total duration: \(totalDuration)s")
        print("Total segments processed: \(sortedSegments.count)")
        
        return composition
    }
    
    // MARK: - Composition creation with progress (orientation correction fixed version)
    func createCompositionWithProgress(
        for project: Project,
        progressCallback: @escaping (Int, Int) -> Void
    ) async -> AVComposition? {
        
        guard !project.segments.isEmpty else {
            print("No segments to create composition")
            return nil
        }
        
        print("Creating composition with progress tracking for \(project.segments.count) segments")
        
        let composition = AVMutableComposition()
        
        // Create video and audio tracks
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            print("Failed to create composition tracks")
            return nil
        }
        
        var currentTime = CMTime.zero
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // Process segments in order
        let sortedSegments = project.segments.sorted { $0.order < $1.order }
        let totalSegments = sortedSegments.count
        
        // Process segments sequentially
        for (index, segment) in sortedSegments.enumerated() {
            // Call progress callback
            progressCallback(index, totalSegments)
            
            // Build file URL
            let fileURL: URL
            if !segment.uri.hasPrefix("/") {
                fileURL = documentsPath.appendingPathComponent(segment.uri)
            } else {
                fileURL = URL(fileURLWithPath: segment.uri)
            }
            
            // Check file existence
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                print("File not found: \(fileURL.path)")
                continue
            }
            
            // Create AVURLAsset (iOS 18 compatible)
            let asset = AVURLAsset(url: fileURL)
            
            do {
                // Deprecated API handling: use loadTracks
                let assetVideoTracks = try await asset.loadTracks(withMediaType: .video)
                let assetAudioTracks = try await asset.loadTracks(withMediaType: .audio)
                let assetDuration = try await asset.load(.duration)
                
                // Add video track
                if let assetVideoTrack = assetVideoTracks.first {
                    let timeRange = CMTimeRange(start: .zero, duration: assetDuration)
                    try videoTrack.insertTimeRange(timeRange, of: assetVideoTrack, at: currentTime)
                    
                    // Important: Apply video orientation correction (same as existing createComposition function)
                    if index == 0 {
                        // Get orientation info from first segment and apply to entire composition
                        let transform = assetVideoTrack.preferredTransform
                        let naturalSize = assetVideoTrack.naturalSize
                        
                        // Set orientation info for composition
                        videoTrack.preferredTransform = transform
                        
                        // Adjust composition size based on orientation
                        let angle = atan2(transform.b, transform.a)
                        let isRotated = abs(angle) > .pi / 4
                        
                        if isRotated {
                            // For 90 or 270 degree rotation, swap width and height
                            composition.naturalSize = CGSize(width: naturalSize.height, height: naturalSize.width)
                            print("Composition rotated: \(naturalSize) → \(composition.naturalSize)")
                        } else {
                            composition.naturalSize = naturalSize
                            print("Composition normal: \(naturalSize)")
                        }
                        
                        print("Transform applied: \(transform)")
                    }
                    
                    print("Video track added: Segment \(segment.order)")
                }
                
                // Add audio track
                if let assetAudioTrack = assetAudioTracks.first {
                    let timeRange = CMTimeRange(start: .zero, duration: assetDuration)
                    try audioTrack.insertTimeRange(timeRange, of: assetAudioTrack, at: currentTime)
                    print("Audio track added: Segment \(segment.order)")
                }
                
                // Update start time for next segment
                currentTime = CMTimeAdd(currentTime, assetDuration)
                print("Current composition time: \(currentTime.seconds)s")
                
                // Simulate some processing time (actual file processing time)
                try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
                
            } catch {
                print("Error processing segment \(segment.order): \(error)")
                continue
            }
            
            // Debug log (every 50 segments)
            if (index + 1) % 50 == 0 || index == totalSegments - 1 {
                print("Processed \(index + 1)/\(totalSegments) segments")
            }
        }
        
        // Final progress callback
        progressCallback(totalSegments, totalSegments)
        
        let totalDuration = currentTime.seconds
        print("Composition created: \(totalSegments) segments, total duration: \(totalDuration)s")
        
        return composition
    }
    
    // Add: Segment position calculation functionality (for integrated playback)
    func getSegmentTimeRanges(for project: Project) async -> [(segment: VideoSegment, timeRange: CMTimeRange)] {
        var result: [(VideoSegment, CMTimeRange)] = []
        var currentTime = CMTime.zero
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        let sortedSegments = project.segments.sorted { $0.order < $1.order }
        
        for segment in sortedSegments {
            // Build file URL
            let fileURL: URL
            if !segment.uri.hasPrefix("/") {
                fileURL = documentsPath.appendingPathComponent(segment.uri)
            } else {
                fileURL = URL(fileURLWithPath: segment.uri)
            }
            
            // Check file existence
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
                print("Failed to load duration for segment \(segment.order): \(error)")
            }
        }
        
        return result
    }
    
    // Individual file deletion for segments
    private func deleteVideoFile(for segment: VideoSegment) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL: URL
        
        // For filename only (new format)
        if !segment.uri.hasPrefix("/") {
            fileURL = documentsPath.appendingPathComponent(segment.uri)
        } else {
            // For absolute path (old format) - backward compatibility
            fileURL = URL(fileURLWithPath: segment.uri)
        }
        
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
                print("Segment file deleted: \(fileURL.lastPathComponent)")
            } else {
                print("Segment file not found: \(fileURL.lastPathComponent)")
            }
        } catch {
            print("Segment file deletion error: \(fileURL.lastPathComponent) - \(error)")
        }
    }
    
    // Project deletion (complete version: data + video file deletion)
    func deleteProject(_ project: Project) {
        print("Project deletion started: \(project.name)")
        
        // 1. Physically delete video files
        deleteVideoFiles(for: project)
        
        // 2. Remove from project list
        projects.removeAll { $0.id == project.id }
        
        // 3. Save to UserDefaults
        saveProjects()
        
        print("Project deletion completed: \(project.name)")
        print("Remaining projects: \(projects.count)")
    }
    
    // Physical deletion of video files
    private func deleteVideoFiles(for project: Project) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        var deletedCount = 0
        var errorCount = 0
        
        print("Target segments for deletion: \(project.segments.count)")
        
        for segment in project.segments {
            let fileURL: URL
            
            // For filename only (new format)
            if !segment.uri.hasPrefix("/") {
                fileURL = documentsPath.appendingPathComponent(segment.uri)
            } else {
                // For absolute path (old format) - backward compatibility
                fileURL = URL(fileURLWithPath: segment.uri)
            }
            
            do {
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    try FileManager.default.removeItem(at: fileURL)
                    deletedCount += 1
                    print("File deleted: \(fileURL.lastPathComponent)")
                } else {
                    print("File not found: \(fileURL.lastPathComponent)")
                }
            } catch {
                errorCount += 1
                print("File deletion error: \(fileURL.lastPathComponent) - \(error)")
            }
        }
        
        print("File deletion result: Success \(deletedCount), Errors \(errorCount)")
    }
    
    // MARK: - Data Persistence
    
    // Save projects (using UserDefaults)
    private func saveProjects() {
        do {
            let data = try JSONEncoder().encode(projects)
            userDefaults.set(data, forKey: projectsKey)
            print("Projects saved successfully: \(projects.count) items")
        } catch {
            print("Project save error: \(error)")
        }
    }
    
    // Load projects
    private func loadProjects() {
        guard let data = userDefaults.data(forKey: projectsKey) else {
            print("No saved projects found")
            return
        }
        
        do {
            projects = try JSONDecoder().decode([Project].self, from: data)
            print("Projects loaded successfully: \(projects.count) items")
        } catch {
            print("Project load error: \(error)")
            projects = []
        }
    }
    
    // MARK: - Helper Methods
    
    // Search project
    func findProject(by id: Int) -> Project? {
        return projects.first { $0.id == id }
    }
    
    // Statistics
    var totalSegments: Int {
        return projects.reduce(0) { $0 + $1.segmentCount }
    }
    
    // Delete all projects (for development/testing)
    func deleteAllProjects() {
        print("All projects deletion started")
        
        for project in projects {
            deleteVideoFiles(for: project)
        }
        
        projects.removeAll()
        saveProjects()
        
        print("All projects deletion completed")
    }
}
