import Foundation
import AVFoundation
import WebSocketKit
import Vapor
import ScreenCaptureKit

// 让WebSocket可以在Set中使用
extension WebSocket: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
    
    public static func == (lhs: WebSocket, rhs: WebSocket) -> Bool {
        return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
}

@available(macOS 12.3, *)
class AudioCapture: NSObject, @unchecked Sendable, SCStreamOutput, SCStreamDelegate {
    static let shared = AudioCapture()
    
    private var captureStream: SCStream?
    private var micAudioEngine: AVAudioEngine?
    @MainActor private var webSockets: Set<WebSocket> = []
    private var isCapturing = false
    
    private override init() {
        super.init()
    }
    
    func addWebSocket(_ webSocket: WebSocket) async {
        _ = await MainActor.run {
            webSockets.insert(webSocket)
        }
        
        // 监听WebSocket关闭事件
        webSocket.onClose.whenComplete { [weak self] _ in
            Task {
                await self?.removeWebSocket(webSocket)
            }
        }
    }
    
    func removeWebSocket(_ webSocket: WebSocket) async {
        _ = await MainActor.run {
            webSockets.remove(webSocket)
        }
    }
    
    func startGlobalAudioCapture() async throws {
        guard !isCapturing else { 
            print("⚠️ 音频捕获已在运行中")
            return 
        }
        
        print("🎙️ 开始启动音频捕获...")
        self.isCapturing = true
        
        // 检查屏幕录制权限
        let hasScreenRecordingPermission = await checkAndRequestScreenRecordingPermission()
        print("📺 屏幕录制权限状态: \(hasScreenRecordingPermission ? "✅ 已授权" : "❌ 未授权")")
        
        // 检查麦克风权限
        let hasMicrophonePermission = await checkAndRequestMicrophonePermission()
        print("🎤 麦克风权限状态: \(hasMicrophonePermission ? "✅ 已授权" : "❌ 未授权")")
        
        // 启动ScreenCaptureKit音频捕获
        try await startScreenCaptureAudio()
        
        print("✅ 音频捕获系统已启动")
    }
    
    private func checkAndRequestScreenRecordingPermission() async -> Bool {
        let canRecord = CGPreflightScreenCaptureAccess()
        if !canRecord {
            print("🔐 正在请求屏幕录制权限...")
            return CGRequestScreenCaptureAccess()
        }
        return true
    }
    
    private func checkAndRequestMicrophonePermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        print("🎤 当前麦克风权限状态: \(status.rawValue)")
        
        switch status {
        case .notDetermined:
            print("🔐 正在请求麦克风权限...")
            return await AVCaptureDevice.requestAccess(for: .audio)
        case .authorized:
            return true
        case .denied, .restricted:
            print("❌ 麦克风权限被拒绝")
            return false
        @unknown default:
            return false
        }
    }
    
    private func startScreenCaptureAudio() async throws {
        print("🔍 获取可捕获内容...")
        let availableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        print("📱 找到 \(availableContent.displays.count) 个显示器")
        print("📱 找到 \(availableContent.applications.count) 个应用程序")
        
        try await setupSystemAudioCapture(availableContent: availableContent)
        try await setupMicrophoneCapture()
    }
    
    private func setupSystemAudioCapture(availableContent: SCShareableContent) async throws {
        guard let display = availableContent.displays.first else { 
            print("❌ 未找到可用显示器")
            return 
        }
        
        print("🖥️ 使用显示器: \(display.displayID)")
        
        let excludedApps = availableContent.applications.filter { app in
            Bundle.main.bundleIdentifier == app.bundleIdentifier
        }
        
        print("🚫 排除的应用程序数量: \(excludedApps.count)")
        
        let filter = SCContentFilter(display: display, excludingApplications: excludedApps, exceptingWindows: [])
        
        let configuration = SCStreamConfiguration()
        if #available(macOS 13.0, *) {
            configuration.capturesAudio = true
            configuration.excludesCurrentProcessAudio = true
            configuration.sampleRate = 16000
            configuration.channelCount = 2
        }
        
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        configuration.queueDepth = 8
        
        if #available(macOS 15.0, *) {
            if let defaultMicrophone = AVCaptureDevice.default(for: .audio) {
                configuration.captureMicrophone = true
                configuration.microphoneCaptureDeviceID = defaultMicrophone.uniqueID
                print("🎤 使用内置麦克风: \(defaultMicrophone.localizedName)")
            }
        }
        
        captureStream = SCStream(filter: filter, configuration: configuration, delegate: self)
        
        if #available(macOS 13.0, *) {
            try captureStream?.addStreamOutput(self, type: .audio, sampleHandlerQueue: DispatchQueue.global(qos: .userInteractive))
        }
        
        if #available(macOS 15.0, *) {
            try captureStream?.addStreamOutput(self, type: .microphone, sampleHandlerQueue: DispatchQueue.global(qos: .userInteractive))
        }
        
        print("🚀 启动ScreenCaptureKit捕获...")
        try await captureStream?.startCapture()
        print("✅ ScreenCaptureKit捕获已启动")
    }
    
    private func setupMicrophoneCapture() async throws {
        if #unavailable(macOS 15.0) {
            micAudioEngine = AVAudioEngine()
            
            guard let micAudioEngine = micAudioEngine else { return }
            
            let inputNode = micAudioEngine.inputNode
            let inputFormat = inputNode.outputFormat(forBus: 0)
            
            print("🎤 麦克风格式: \(inputFormat)")
            
            // 使用硬件原生格式，避免格式不匹配问题，增加缓冲区大小
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] (buffer, time) in
                self?.processMicrophoneAudio(buffer: buffer)
            }
            
            micAudioEngine.prepare()
            try micAudioEngine.start()
            print("✅ AVAudioEngine麦克风捕获已启动")
        }
    }
    
    private func processMicrophoneAudio(buffer: AVAudioPCMBuffer) {
        guard isCapturing,
              let channelData = buffer.floatChannelData?[0] else { 
            return 
        }
        
        let frameCount = Int(buffer.frameLength)
        let audioData = Array(UnsafeBufferPointer(start: channelData, count: frameCount)).map(Double.init)
        
        // 计算音频强度（暂时不使用）
        let _ = sqrt(audioData.map { $0 * $0 }.reduce(0, +) / Double(audioData.count))
        
        // 发送音频数据到WebSocket客户端
        let event = AudioDataEvent(
            id: generateId(),
            payload: AudioPayload(audioType: "mic", data: audioData),
            type: nil,
            wsEventType: "audio-data-event"
        )
        
        sendToAllWebSockets(event: event)
    }
    
    private func processSystemAudio(buffer: AVAudioPCMBuffer) {
        guard isCapturing else { return }
        
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        

        
        var audioData: [Double] = []
        
        if channelCount == 1 {
            // 单声道
            guard let channelData = buffer.floatChannelData?[0] else { return }
            audioData = Array(UnsafeBufferPointer(start: channelData, count: frameCount)).map(Double.init)
        } else if channelCount == 2 {
            // 立体声 - 混合两个声道
            guard let leftChannel = buffer.floatChannelData?[0],
                  let rightChannel = buffer.floatChannelData?[1] else { return }
            
            audioData.reserveCapacity(frameCount)
            for i in 0..<frameCount {
                // 将左右声道混合为单声道
                let mixedSample = Double((leftChannel[i] + rightChannel[i]) / 2.0)
                audioData.append(mixedSample)
            }
        } else {
            // 多声道 - 只取第一个声道
            guard let channelData = buffer.floatChannelData?[0] else { return }
            audioData = Array(UnsafeBufferPointer(start: channelData, count: frameCount)).map(Double.init)
        }
        
        // 计算音频强度（暂时不使用）
        let _ = sqrt(audioData.map { $0 * $0 }.reduce(0, +) / Double(audioData.count))
        
        let event = AudioDataEvent(
            id: generateId(),
            payload: AudioPayload(audioType: "system", data: audioData),
            type: nil,
            wsEventType: "audio-data-event"
        )
        
        sendToAllWebSockets(event: event)
    }
    
    private func generateId() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-"
        let length = 21
        return String((0..<length).map { _ in characters.randomElement()! })
    }
    
    private func sendToAllWebSockets<T: Codable>(event: T) {
        Task { @MainActor in
            let currentWebSockets = webSockets
            
            guard !currentWebSockets.isEmpty else { return }
            
            do {
                let encoder = JSONEncoder()
                // 设置最高的浮点数精度
                encoder.outputFormatting = [.withoutEscapingSlashes]
                
                let jsonData = try encoder.encode(event)
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    for webSocket in currentWebSockets {
                        try await webSocket.send(jsonString)
                    }
                }
            } catch {
                print("❌ WebSocket发送失败: \(error)")
            }
        }
    }
    
    func stopGlobalAudioCapture() async {
        print("🛑 停止音频捕获...")
        isCapturing = false
        
        // 首先关闭所有 WebSocket 连接
        let socketsToClose = await MainActor.run {
            let sockets = webSockets
            webSockets.removeAll()
            return sockets
        }
        
        // 关闭所有WebSocket连接
        for socket in socketsToClose {
            try? await socket.close()
        }
        
        // 停止ScreenCaptureKit流
        if let stream = captureStream {
            print("🛑 停止ScreenCaptureKit流...")
            do {
                try await stream.stopCapture()
                print("✅ ScreenCaptureKit流已停止")
            } catch {
                print("⚠️ 停止ScreenCaptureKit流时出错: \(error)")
            }
        }
        captureStream = nil
        
        // 停止麦克风引擎
        if let engine = micAudioEngine {
            print("🛑 停止麦克风引擎...")
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        micAudioEngine = nil
        
        print("✅ 音频捕获已完全停止")
    }
    
    // MARK: - SCStreamOutput
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        switch type {
        case .screen:
            break
        case .audio:
            processSystemAudioSample(sampleBuffer: sampleBuffer)
        case .microphone:
            processMicrophoneAudioSample(sampleBuffer: sampleBuffer)
        @unknown default:
            break
        }
    }
    
    // MARK: - SCStreamDelegate
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("❌ ScreenCaptureKit流错误: \(error)")
    }
    
    // MARK: - Audio Processing
    private func processSystemAudioSample(sampleBuffer: CMSampleBuffer) {
        guard let audioBuffer = convertSampleBufferToPCMBuffer(sampleBuffer) else {
            return
        }
        processSystemAudio(buffer: audioBuffer)
    }
    
    private func processMicrophoneAudioSample(sampleBuffer: CMSampleBuffer) {
        guard let audioBuffer = convertSampleBufferToPCMBuffer(sampleBuffer) else {
            return
        }
        processMicrophoneAudio(buffer: audioBuffer)
    }
    
    private func convertSampleBufferToPCMBuffer(_ sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else {
            print("❌ 无法获取音频格式描述")
            return nil
        }
        
        guard let sourceFormat = AVAudioFormat(streamDescription: audioStreamBasicDescription) else {
            print("❌ 无法创建源音频格式")
            return nil
        }
        
        let frameCount = CMSampleBufferGetNumSamples(sampleBuffer)
        
        guard let sourceBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: AVAudioFrameCount(frameCount)) else {
            print("❌ 无法创建源PCM缓冲区")
            return nil
        }
        
        sourceBuffer.frameLength = AVAudioFrameCount(frameCount)
        
        if let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) {
            var dataPointer: UnsafeMutablePointer<Int8>?
            var lengthAtOffset: Int = 0
            let status = CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: &lengthAtOffset, totalLengthOut: nil, dataPointerOut: &dataPointer)
            
            if status == noErr, let data = dataPointer {
                let audioBufferList = sourceBuffer.mutableAudioBufferList
                let bytesToCopy = min(lengthAtOffset, Int(audioBufferList.pointee.mBuffers.mDataByteSize))
                audioBufferList.pointee.mBuffers.mData?.copyMemory(from: data, byteCount: bytesToCopy)
            }
        }
        
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sourceFormat.sampleRate,
            channels: sourceFormat.channelCount,
            interleaved: false
        ) else {
            print("❌ 无法创建目标音频格式")
            return nil
        }
        
        if sourceFormat.commonFormat == .pcmFormatFloat32 {
            return sourceBuffer
        }
        
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: AVAudioFrameCount(frameCount)) else {
            print("❌ 无法创建输出PCM缓冲区")
            return nil
        }
        
        guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
            print("❌ 无法创建音频转换器")
            return nil
        }
        
        var error: NSError?
        let status = converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            outStatus.pointee = .haveData
            return sourceBuffer
        }
        
        if status == .error {
            return nil
        }
        return outputBuffer
    }
}

enum AudioCaptureError: Error {
    case formatError
    case permissionDenied
    case engineError
    case screenCaptureNotAvailable
} 