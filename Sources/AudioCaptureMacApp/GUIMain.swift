import Foundation
import Vapor
import WebSocketKit
import AVFoundation
import Cocoa
import IOKit

class AudioServerApp: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var statusLabel: NSTextField!
    private var startButton: NSButton!
    private var stopButton: NSButton!
    private var logTextView: NSTextView!
    private var app: Application?
    private var serverTask: Task<Void, Error>?
    
    // 权限相关UI
    private var micPermissionLabel: NSTextField!
    private var screenPermissionLabel: NSTextField!
    private var micPermissionButton: NSButton!
    private var screenPermissionButton: NSButton!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        createMainWindow()
        setupUI()
        checkPermissions()
        logMessage("应用程序已启动")
    }
    
    private func createMainWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Audio Capture Server"
        window.center()
        window.makeKeyAndOrderFront(nil)
    }
    
    private func setupUI() {
        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        window.contentView = contentView
        
        // 标题标签
        let titleLabel = NSTextField(labelWithString: "🎵 Audio Capture Server")
        titleLabel.font = NSFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.frame = NSRect(x: 20, y: 450, width: 460, height: 30)
        titleLabel.alignment = .center
        contentView.addSubview(titleLabel)
        
        // 权限状态区域
        setupPermissionUI(contentView: contentView)
        
        // 状态标签
        statusLabel = NSTextField(labelWithString: "服务器已停止")
        statusLabel.frame = NSRect(x: 20, y: 330, width: 460, height: 20)
        statusLabel.alignment = .center
        statusLabel.textColor = .systemRed
        contentView.addSubview(statusLabel)
        
        // 按钮容器
        let buttonContainer = NSView(frame: NSRect(x: 20, y: 280, width: 460, height: 40))
        contentView.addSubview(buttonContainer)
        
        // 启动按钮
        startButton = NSButton(frame: NSRect(x: 100, y: 5, width: 120, height: 30))
        startButton.title = "🚀 启动服务器"
        startButton.target = self
        startButton.action = #selector(startServer)
        startButton.bezelStyle = .rounded
        buttonContainer.addSubview(startButton)
        
        // 停止按钮  
        stopButton = NSButton(frame: NSRect(x: 240, y: 5, width: 120, height: 30))
        stopButton.title = "⏹ 停止服务器"
        stopButton.target = self
        stopButton.action = #selector(stopServer)
        stopButton.bezelStyle = .rounded
        stopButton.isEnabled = false
        buttonContainer.addSubview(stopButton)
        
        // 信息标签
        let infoLabel = NSTextField(wrappingLabelWithString: """
        📡 API端点 (端口 9047):
        • GET  /health - 健康检查
        • GET  /config - 配置信息  
        • WebSocket /ws - 音频数据流 (麦克风 + 系统音频)
        """)
        infoLabel.frame = NSRect(x: 20, y: 200, width: 460, height: 70)
        infoLabel.font = NSFont.systemFont(ofSize: 12)
        contentView.addSubview(infoLabel)
        
        // 日志区域
        let logLabel = NSTextField(labelWithString: "📋 服务器日志:")
        logLabel.frame = NSRect(x: 20, y: 170, width: 460, height: 20)
        logLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        contentView.addSubview(logLabel)
        
        let scrollView = NSScrollView(frame: NSRect(x: 20, y: 20, width: 460, height: 140))
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = false
        
        logTextView = NSTextView(frame: scrollView.contentView.bounds)
        logTextView.isEditable = false
        logTextView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        logTextView.textColor = .labelColor
        logTextView.backgroundColor = .controlBackgroundColor
        
        scrollView.documentView = logTextView
        contentView.addSubview(scrollView)
    }
    
    private func setupPermissionUI(contentView: NSView) {
        // 权限状态区域标题
        let permissionTitleLabel = NSTextField(labelWithString: "🔐 系统权限状态:")
        permissionTitleLabel.frame = NSRect(x: 20, y: 410, width: 460, height: 20)
        permissionTitleLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        contentView.addSubview(permissionTitleLabel)
        
        // 麦克风权限状态
        micPermissionLabel = NSTextField(labelWithString: "🎤 麦克风权限: 检查中...")
        micPermissionLabel.frame = NSRect(x: 40, y: 380, width: 300, height: 20)
        micPermissionLabel.font = NSFont.systemFont(ofSize: 12)
        contentView.addSubview(micPermissionLabel)
        
        micPermissionButton = NSButton(title: "请求权限", target: self, action: #selector(requestMicrophonePermission))
        micPermissionButton.frame = NSRect(x: 350, y: 378, width: 80, height: 24)
        micPermissionButton.isHidden = true
        contentView.addSubview(micPermissionButton)
        
        // 屏幕录制权限状态
        screenPermissionLabel = NSTextField(labelWithString: "🖥️ 屏幕录制权限: 检查中...")
        screenPermissionLabel.frame = NSRect(x: 40, y: 355, width: 300, height: 20)
        screenPermissionLabel.font = NSFont.systemFont(ofSize: 12)
        contentView.addSubview(screenPermissionLabel)
        
        screenPermissionButton = NSButton(title: "请求权限", target: self, action: #selector(requestScreenPermission))
        screenPermissionButton.frame = NSRect(x: 350, y: 353, width: 80, height: 24)
        screenPermissionButton.isHidden = true
        contentView.addSubview(screenPermissionButton)
    }
    
    private func checkPermissions() {
        Task { @MainActor in
            await checkMicrophonePermission()
            await checkScreenPermission()
        }
    }
    
    @MainActor
    private func checkMicrophonePermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        
        switch status {
        case .authorized:
            micPermissionLabel.stringValue = "🎤 麦克风权限: ✅ 已授权"
            micPermissionLabel.textColor = .systemGreen
            micPermissionButton.isHidden = true
        case .denied:
            micPermissionLabel.stringValue = "🎤 麦克风权限: ❌ 已拒绝"
            micPermissionLabel.textColor = .systemRed
            micPermissionButton.isHidden = false
        case .notDetermined:
            micPermissionLabel.stringValue = "🎤 麦克风权限: ⚠️ 未请求"
            micPermissionLabel.textColor = .systemOrange
            micPermissionButton.isHidden = false
        case .restricted:
            micPermissionLabel.stringValue = "🎤 麦克风权限: 🚫 受限制"
            micPermissionLabel.textColor = .systemOrange
            micPermissionButton.isHidden = false
        @unknown default:
            micPermissionLabel.stringValue = "🎤 麦克风权限: ❓ 未知状态"
            micPermissionLabel.textColor = .systemGray
            micPermissionButton.isHidden = false
        }
    }
    
    @MainActor
    private func checkScreenPermission() async {
        let hasPermission = CGPreflightScreenCaptureAccess()
        
        if hasPermission {
            screenPermissionLabel.stringValue = "🖥️ 屏幕录制权限: ✅ 已授权"
            screenPermissionLabel.textColor = .systemGreen
            screenPermissionButton.isHidden = true
        } else {
            screenPermissionLabel.stringValue = "🖥️ 屏幕录制权限: ❌ 未授权"
            screenPermissionLabel.textColor = .systemRed
            screenPermissionButton.isHidden = false
        }
    }
    
    @objc private func requestMicrophonePermission() {
        Task {
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            
            await MainActor.run {
                Task {
                    await self.checkMicrophonePermission()
                }
                if granted {
                    self.logMessage("麦克风权限已授予")
                } else {
                    self.logMessage("麦克风权限被拒绝")
                }
            }
        }
    }
    
    @objc private func requestScreenPermission() {
        let hasPermission = CGRequestScreenCaptureAccess()
        
        Task { @MainActor in
            await checkScreenPermission()
            if hasPermission {
                logMessage("屏幕录制权限已授予")
            } else {
                logMessage("屏幕录制权限被拒绝或需要用户手动在系统设置中启用")
            }
        }
    }
    
    private func logMessage(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logEntry = "[\(timestamp)] \(message)\n"
        
        DispatchQueue.main.async {
            self.logTextView.string += logEntry
            self.logTextView.scrollToEndOfDocument(nil)
        }
    }
    
    // 全局标志，确保日志系统只初始化一次
    private static var isLoggingInitialized = false
    
    @objc private func startServer() {
        // 重新检查权限状态
        checkPermissions()
        
        logMessage("正在启动服务器...")
        
        serverTask = Task {
            do {
                // 如果app已存在，先清理
                if let existingApp = self.app {
                    print("🛑 清理现有应用实例...")
                    try? await existingApp.server.shutdown()
                    // 不调用 asyncShutdown，避免完全关闭
                }
                
                // 使用标准的Vapor启动方式
                var env = try Environment.detect()
                
                // 只在第一次启动时初始化日志系统
                if !AudioServerApp.isLoggingInitialized {
                    try LoggingSystem.bootstrap(from: &env)
                    AudioServerApp.isLoggingInitialized = true
                    print("✅ 日志系统已初始化")
                } else {
                    print("✅ 日志系统已存在，跳过初始化")
                }
                
                let app = try await Application.make(.detect())
                
                try await configure(app)
                
                await MainActor.run {
                    self.app = app
                    self.statusLabel.stringValue = "🟢 服务器运行中 - 端口 9047"
                    self.statusLabel.textColor = .systemGreen
                    self.startButton.isEnabled = false
                    self.stopButton.isEnabled = true
                    self.logMessage("服务器已启动在端口 9047")
                    self.logMessage("🎵 音频监控已开始")
                }
                
                // 启动服务器但不使用execute()，避免命令行冲突
                try await app.server.start(address: .hostname("127.0.0.1", port: 9047))
                
                // 保持服务器运行，直到任务被取消
                // 不在这里调用 asyncShutdown，让停止逻辑统一处理
                while !Task.isCancelled {
                    try await Task.sleep(for: .seconds(1))
                }
                
            } catch is CancellationError {
                await MainActor.run {
                    self.logMessage("服务器已被用户停止")
                }
            } catch {
                await MainActor.run {
                    self.statusLabel.stringValue = "❌ 服务器启动失败"
                    self.statusLabel.textColor = .systemRed
                    self.startButton.isEnabled = true
                    self.stopButton.isEnabled = false
                    self.logMessage("服务器启动失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    @objc private func stopServer() {
        logMessage("正在停止服务器...")
        stopButton.isEnabled = false
        
        Task {
            // 停止全局音频捕获
            if #available(macOS 12.3, *) {
                print("🛑 停止音频捕获...")
                await AudioCapture.shared.stopGlobalAudioCapture()
                print("✅ 音频捕获已停止")
            }
            
            // 取消服务器任务并等待其完成
            print("🛑 取消服务器任务...")
            if let task = serverTask {
                task.cancel()
                print("🛑 等待服务器任务完成...")
                // 等待任务完成，忽略取消错误
                do {
                    _ = try await task.value
                } catch is CancellationError {
                    print("✅ 服务器任务已被取消")
                } catch {
                    print("⚠️ 服务器任务错误: \(error)")
                }
                print("✅ 服务器任务已完成")
            }
            
            // 停止 Vapor 应用的服务器部分，但不关闭整个应用
            if let app = self.app {
                print("🛑 停止 Vapor 服务器...")
                do {
                    // 只停止HTTP服务器，不关闭整个Application
                    try await app.server.shutdown()
                    print("✅ Vapor 服务器已停止")
                } catch {
                    print("⚠️ 停止 Vapor 服务器时出错: \(error)")
                }
            }
            
            // 更新UI - 注意：不设置 app = nil，以便可以重新启动
            await MainActor.run {
                self.serverTask = nil
                self.statusLabel.stringValue = "🔴 服务器已停止"
                self.statusLabel.textColor = .systemRed
                self.startButton.isEnabled = true
                self.stopButton.isEnabled = false
                
                // 重新检查权限状态
                self.checkPermissions()
                
                self.logMessage("服务器已停止")
                self.logMessage("🎵 音频监控已停止")
                self.logMessage("💡 您可以再次点击\"启动服务器\"重新启动")
            }
            
            print("✅ 服务器停止完成，应用保持运行")
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("🛑 应用即将退出，清理资源...")
        
        Task {
            // 停止音频捕获
            if #available(macOS 12.3, *) {
                await AudioCapture.shared.stopGlobalAudioCapture()
            }
            
            // 取消服务器任务
            serverTask?.cancel()
            
            // 完全关闭Vapor应用
            if let app = self.app {
                try? await app.asyncShutdown()
            }
            
            print("✅ 资源清理完成")
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// GUI应用类定义完成 