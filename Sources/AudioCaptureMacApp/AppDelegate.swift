import Cocoa
import Vapor

class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var window: NSWindow!
    private var statusLabel: NSTextField!
    private var startButton: NSButton!
    private var stopButton: NSButton!
    private var app: Application?
    private var serverTask: Task<Void, Error>?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        createMainWindow()
        setupUI()
    }
    
    private func createMainWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Audio Capture Server"
        window.center()
        window.makeKeyAndOrderFront(nil)
    }
    
    private func setupUI() {
        let contentView = NSView(frame: window.contentView!.bounds)
        window.contentView = contentView
        
        // 标题标签
        let titleLabel = NSTextField(labelWithString: "Audio Capture Server")
        titleLabel.font = NSFont.systemFont(ofSize: 18, weight: .bold)
        titleLabel.frame = NSRect(x: 50, y: 220, width: 300, height: 30)
        titleLabel.alignment = .center
        contentView.addSubview(titleLabel)
        
        // 状态标签
        statusLabel = NSTextField(labelWithString: "服务器已停止")
        statusLabel.frame = NSRect(x: 50, y: 180, width: 300, height: 20)
        statusLabel.alignment = .center
        contentView.addSubview(statusLabel)
        
        // 启动按钮
        startButton = NSButton(frame: NSRect(x: 80, y: 130, width: 100, height: 30))
        startButton.title = "启动服务器"
        startButton.target = self
        startButton.action = #selector(startServer)
        contentView.addSubview(startButton)
        
        // 停止按钮  
        stopButton = NSButton(frame: NSRect(x: 220, y: 130, width: 100, height: 30))
        stopButton.title = "停止服务器"
        stopButton.target = self
        stopButton.action = #selector(stopServer)
        stopButton.isEnabled = false
        contentView.addSubview(stopButton)
        
        // 信息标签
        let infoLabel = NSTextField(wrappingLabelWithString: """
        端口: 9047
        API端点:
        • GET /health - 健康检查
        • GET /config - 配置信息
        • WebSocket /ws - 音频数据流
        """)
        infoLabel.frame = NSRect(x: 50, y: 30, width: 300, height: 80)
        infoLabel.font = NSFont.systemFont(ofSize: 12)
        contentView.addSubview(infoLabel)
    }
    
    @objc private func startServer() {
        serverTask = Task {
            do {
                let app = try await Application.make(.development)
                
                try configure(app)
                
                await MainActor.run {
                    self.app = app
                    self.statusLabel.stringValue = "服务器运行中 - 端口 9047"
                    self.startButton.isEnabled = false
                    self.stopButton.isEnabled = true
                }
                
                try await app.execute()
            } catch {
                await MainActor.run {
                    self.statusLabel.stringValue = "服务器启动失败: \(error.localizedDescription)"
                    self.startButton.isEnabled = true
                    self.stopButton.isEnabled = false
                }
            }
        }
    }
    
    @objc private func stopServer() {
        statusLabel.stringValue = "正在停止服务器..."
        stopButton.isEnabled = false
        
        Task {
            // 首先停止音频捕获
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
                _ = await task.result
                print("✅ 服务器任务已完成")
            }
            
            // 优雅地关闭 Vapor 应用
            if let app = self.app {
                print("🛑 关闭 Vapor 应用...")
                do {
                    try await app.asyncShutdown()
                    print("✅ Vapor 应用已关闭")
                } catch {
                    print("⚠️ 关闭 Vapor 应用时出错: \(error)")
                }
            }
            
            // 更新UI
            await MainActor.run {
                self.app = nil
                self.serverTask = nil
                self.statusLabel.stringValue = "服务器已停止"
                self.startButton.isEnabled = true
                self.stopButton.isEnabled = false
            }
            
            print("✅ 服务器停止完成")
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        stopServer()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
} 