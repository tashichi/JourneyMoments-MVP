//
//  VideoManager.swift
//  JourneyMoments
//
//  Created by 谷澤健二 on 2025/08/11.
//

import Foundation
@preconcurrency import AVFoundation
import UIKit

@MainActor
class VideoManager: NSObject, ObservableObject {
    
    // MARK: - Properties
    private var captureSession: AVCaptureSession?
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var movieOutput: AVCaptureMovieFileOutput?
    
    @Published var currentCameraPosition: AVCaptureDevice.Position = .back
    @Published var isSessionRunning = false
    @Published var cameraPermissionGranted = false
    
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    private var recordingCompletion: ((Result<URL, Error>) -> Void)?
    
    // MARK: - Camera Setup
    
    func requestCameraPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            cameraPermissionGranted = true
        case .notDetermined:
            cameraPermissionGranted = await AVCaptureDevice.requestAccess(for: .video)
        default:
            cameraPermissionGranted = false
        }
    }
    
    func setupCamera() async {
        guard cameraPermissionGranted else {
            print("❌ カメラ権限が許可されていません")
            return
        }
        
        captureSession = AVCaptureSession()
        guard let captureSession = captureSession else { return }
        
        captureSession.beginConfiguration()
        
        // セッション品質設定
        if captureSession.canSetSessionPreset(.high) {
            captureSession.sessionPreset = .high
        }
        
        // カメラデバイス設定
        await setupCameraDevice(position: currentCameraPosition)
        
        // 動画出力設定
        setupMovieOutput()
        
        captureSession.commitConfiguration()
        
        // プレビューレイヤー作成
        setupPreviewLayer()
        
        // セッション開始
        startSession()
    }
    
    private func setupCameraDevice(position: AVCaptureDevice.Position) async {
        guard let captureSession = captureSession else { return }
        
        // 既存の入力を削除
        if let currentInput = videoDeviceInput {
            captureSession.removeInput(currentInput)
        }
        
        // 新しいカメラデバイスを取得
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            print("❌ カメラデバイスが見つかりません: \(position)")
            return
        }
        
        do {
            let deviceInput = try AVCaptureDeviceInput(device: camera)
            
            if captureSession.canAddInput(deviceInput) {
                captureSession.addInput(deviceInput)
                videoDeviceInput = deviceInput
                currentCameraPosition = position
                print("✅ カメラデバイス設定完了: \(position)")
            } else {
                print("❌ カメラ入力を追加できません")
            }
        } catch {
            print("❌ カメラデバイス作成エラー: \(error)")
        }
    }
    
    private func setupMovieOutput() {
        guard let captureSession = captureSession else { return }
        
        movieOutput = AVCaptureMovieFileOutput()
        guard let movieOutput = movieOutput else { return }
        
        if captureSession.canAddOutput(movieOutput) {
            captureSession.addOutput(movieOutput)
            
            // 動画安定化設定
            if let connection = movieOutput.connection(with: .video) {
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .auto
                }
            }
            
            print("✅ 動画出力設定完了")
        } else {
            print("❌ 動画出力を追加できません")
        }
    }
    
    private func setupPreviewLayer() {
        guard let captureSession = captureSession else { return }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = .resizeAspectFill
        
        print("✅ プレビューレイヤー作成完了")
    }
    
    // MARK: - Session Control
    
    private func startSession() {
        guard let captureSession = captureSession else { return }
        
        // 🔧 修正: バックグラウンドスレッドでセッション開始
        Task {
            await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    if !captureSession.isRunning {
                        captureSession.startRunning()
                        print("✅ カメラセッション開始")
                    }
                    continuation.resume()
                }
            }
            
            // メインスレッドでUI状態を更新
            isSessionRunning = captureSession.isRunning
        }
    }
    
    func stopSession() {
        guard let captureSession = captureSession else { return }
        
        // 🔧 修正: バックグラウンドスレッドでセッション停止
        Task {
            await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    if captureSession.isRunning {
                        captureSession.stopRunning()
                        print("🛑 カメラセッション停止")
                    }
                    continuation.resume()
                }
            }
            
            // メインスレッドでUI状態を更新
            isSessionRunning = false
        }
    }
    
    // MARK: - Camera Control
    
    func toggleCamera() async {
        let newPosition: AVCaptureDevice.Position = currentCameraPosition == .back ? .front : .back
        
        guard let captureSession = captureSession else { return }
        
        captureSession.beginConfiguration()
        await setupCameraDevice(position: newPosition)
        captureSession.commitConfiguration()
    }
    
    // MARK: - Recording
    
    func recordOneSecond() async throws -> URL {
        guard let movieOutput = movieOutput else {
            throw RecordingError.outputNotAvailable
        }
        
        guard !movieOutput.isRecording else {
            throw RecordingError.alreadyRecording
        }
        
        // 出力ファイルURL作成
        let outputURL = createOutputURL()
        
        return try await withCheckedThrowingContinuation { continuation in
            self.recordingCompletion = { result in
                continuation.resume(with: result)
            }
            
            // 録画開始
            movieOutput.startRecording(to: outputURL, recordingDelegate: self)
            
            // 1秒後に自動停止
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if movieOutput.isRecording {
                    movieOutput.stopRecording()
                }
            }
        }
    }
    
    private func createOutputURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let filename = "segment_\(timestamp).mov"
        return documentsPath.appendingPathComponent(filename)
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension VideoManager: AVCaptureFileOutputRecordingDelegate {
    
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        print("🎬 録画開始: \(fileURL.lastPathComponent)")
    }
    
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        
        Task { @MainActor in
            if let error = error {
                print("❌ 録画エラー: \(error)")
                recordingCompletion?(.failure(error))
            } else {
                print("✅ 録画完了: \(outputFileURL.lastPathComponent)")
                recordingCompletion?(.success(outputFileURL))
            }
            
            recordingCompletion = nil
        }
    }
}

// MARK: - Recording Errors

enum RecordingError: LocalizedError {
    case outputNotAvailable
    case alreadyRecording
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .outputNotAvailable:
            return "録画機能が利用できません"
        case .alreadyRecording:
            return "既に録画中です"
        case .permissionDenied:
            return "カメラの使用が許可されていません"
        }
    }
}
