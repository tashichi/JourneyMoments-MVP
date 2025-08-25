import Foundation
import AVFoundation

// MARK: - VideoSegment
// React Native版の videoSegment と同等の構造
struct VideoSegment: Codable, Identifiable {
    let id: Int
    let uri: String
    let timestamp: Date
    let facing: String // "back" or "front" - AVCaptureDevice.Position.rawValueはInt型
    let order: Int
    
    init(id: Int = Int(Date().timeIntervalSince1970 * 1000), uri: String, timestamp: Date = Date(), facing: String, order: Int) {
        self.id = id
        self.uri = uri
        self.timestamp = timestamp
        self.facing = facing
        self.order = order
    }
    
    // AVCaptureDevice.Positionから文字列に変換するヘルパー
    init(id: Int = Int(Date().timeIntervalSince1970 * 1000), uri: String, timestamp: Date = Date(), cameraPosition: AVCaptureDevice.Position, order: Int) {
        self.id = id
        self.uri = uri
        self.timestamp = timestamp
        self.facing = cameraPosition == .back ? "back" : "front"
        self.order = order
    }
}

// MARK: - Project
// React Native版の project と同等の構造
struct Project: Codable, Identifiable {
    let id: Int
    var name: String
    var segments: [VideoSegment]
    let createdAt: Date
    var lastModified: Date
    
    init(id: Int = Int(Date().timeIntervalSince1970 * 1000), name: String, segments: [VideoSegment] = [], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.segments = segments
        self.createdAt = createdAt
        self.lastModified = createdAt
    }
    
    // セグメント追加用のメソッド
    mutating func addSegment(_ segment: VideoSegment) {
        segments.append(segment)
        lastModified = Date()
    }
    
    // セグメント数の取得
    var segmentCount: Int {
        return segments.count
    }
}

// MARK: - AppScreen
// React Native版の currentScreen と同等
enum AppScreen {
    case projects    // プロジェクト一覧
    case camera      // カメラ撮影
    case player      // 動画再生
}
