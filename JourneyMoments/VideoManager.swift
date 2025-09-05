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
    private var audioDeviceInput: AVCaptureDeviceInput?
    private var movieOutput: AVCaptureMovieFileOutput?
    
    @Published var currentCameraPosition: AVCaptureDevice.Position = .back
    @Published var isSessionRunning = false
    @Published var cameraPermissionGranted = false
    @Published var microphonePermissionGranted = false
    @Published var isSetupComplete = false  // 🔧 追加: セットアップ完了状態
    
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    private var recordingCompletion: ((Result<URL, Error>) -> Void)?
    
    // MARK: - Permissions
    
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
    
    func requestMicrophonePermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        
        switch status {
        case .authorized:
            microphonePermissionGranted = true
        case .notDetermined:
            microphonePermissionGranted = await AVCaptureDevice.requestAccess(for: .audio)
        default:
            microphonePermissionGranted = false
        }
    }
    
    // MARK: - Camera Setup
    
    func setupCamera() async {
        print("🔧 setupCamera() 開始")
        
        guard cameraPermissionGranted else {
            print("❌ カメラ権限が許可されていません")
            return
        }
        
        // マイク権限もリクエスト
        await requestMicrophonePermission()
        
        captureSession = AVCaptureSession()
        guard let captureSession = captureSession else {
            print("❌ CaptureSession作成失敗")
            return
        }
        
        captureSession.beginConfiguration()
        
        // セッション品質設定
        if captureSession.canSetSessionPreset(.high) {
            captureSession.sessionPreset = .high
        }
        
        // カメラデバイス設定
        await setupCameraDevice(position: currentCameraPosition)
        
        // 音声デバイス設定
        await setupAudioDevice()
        
        // 動画出力設定
        setupMovieOutput()
        
        captureSession.commitConfiguration()
        
        // プレビューレイヤー作成
        setupPreviewLayer()
        
        // セッション開始
        await startSession()
        
        // 🔧 修正: セットアップ完了を明示的にマーク
        isSetupComplete = true
        print("✅ カメラセットアップ完全完了")
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
    
    private func setupAudioDevice() async {
        guard let captureSession = captureSession else { return }
        guard microphonePermissionGranted else {
            print("❌ マイク権限が許可されていません")
            return
        }
        
        // 既存の音声入力を削除
        if let currentAudioInput = audioDeviceInput {
            captureSession.removeInput(currentAudioInput)
        }
        
        // マイクデバイスを取得
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
            print("❌ 音声デバイスが見つかりません")
            return
        }
        
        do {
            let audioInput = try AVCaptureDeviceInput(device: audioDevice)
            
            if captureSession.canAddInput(audioInput) {
                captureSession.addInput(audioInput)
                audioDeviceInput = audioInput
                print("✅ 音声デバイス設定完了")
            } else {
                print("❌ 音声入力を追加できません")
            }
        } catch {
            print("❌ 音声デバイス作成エラー: \(error)")
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
            
            // 音声接続の確認
            if let audioConnection = movieOutput.connection(with: .audio) {
                print("✅ 音声出力接続確認: \(audioConnection.isEnabled)")
            } else {
                print("⚠️ 音声出力接続が見つかりません")
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
    
    // 🔧 修正: awaitを追加してセッション開始の完了を確実に待つ
    private func startSession() async {
        guard let captureSession = captureSession else { return }
        
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                if !captureSession.isRunning {
                    captureSession.startRunning()
                    print("✅ カメラセッション開始完了")
                }
                
                DispatchQueue.main.async {
                    self.isSessionRunning = captureSession.isRunning
                    continuation.resume()
                }
            }
        }
    }
    
    func stopSession() {
        guard let captureSession = captureSession else { return }
        
        Task {
            await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    if captureSession.isRunning {
                        captureSession.stopRunning()
                        print("🛑 カメラセッション停止")
                    }
                    
                    DispatchQueue.main.async {
                        self.isSessionRunning = false
                        self.isSetupComplete = false  // 🔧 追加: 停止時にセットアップ状態をリセット
                        continuation.resume()
                    }
                }
            }
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
        
        // 録画前に音声接続を確認
        if let audioConnection = movieOutput.connection(with: .audio) {
            print("🎤 音声録音設定: \(audioConnection.isEnabled ? "有効" : "無効")")
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
        for connection in connections {
            if let inputPort = connection.inputPorts.first {
                if inputPort.mediaType == .video {
                    print("📹 映像接続: 有効")
                } else if inputPort.mediaType == .audio {
                    print("🎤 音声接続: 有効")
                }
            }
        }
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
