import Foundation
import Vapor
import WebSocketKit
import AVFoundation
import Cocoa
import IOKit
import CoreAudio
import AudioToolbox

class AudioServerApp: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    
    // 版本信息
    private var versionLabel: NSTextField!
    
    // 麦克风区域
    private var microphoneBox: NSBox!
    private var microphoneIndicator: NSView!
    private var microphoneLabel: NSTextField!
    private var microphoneDescLabel: NSTextField!
    private var microphonePopup: NSPopUpButton!
    private var microphoneRefreshButton: NSButton!
    
    // 系统音频区域
    private var systemAudioBox: NSBox!
    private var systemAudioIndicator: NSView!
    private var systemAudioLabel: NSTextField!
    private var systemAudioDescLabel: NSTextField!
    private var systemAudioPopup: NSPopUpButton!
    private var systemAudioRefreshButton: NSButton!
    
    // 服务控制区域
    private var serviceBox: NSBox!
    private var serviceStatusLabel: NSTextField!
    private var serviceDescLabel: NSTextField!
    private var restartButton: NSButton!
    private var startButton: NSButton!
    
    // 底部连接区域
    private var connectionBox: NSBox!
    private var connectionTitleLabel: NSTextField!
    private var newVersionButton: NSButton!
    private var qrCodeButton: NSButton!
    private var copyAllButton: NSButton!
    private var statusInfoLabel: NSTextField!
    
    private var app: Application?
    private var serverTask: Task<Void, Error>?
    
    // 用于跟踪日志系统是否已初始化
    private static var isLoggingInitialized = false
    
    // 音频动画相关
    private var microphoneAnimationTimer: Timer?
    private var systemAudioAnimationTimer: Timer?
    private var microphoneIsAnimating = false
    private var systemAudioIsAnimating = false
    
    // 音频级别监测
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var currentMicrophoneLevel: Float = 0.0
    private var currentSystemAudioLevel: Float = 0.0
    
    // 音频可视化相关
    private var microphoneBarViews: [NSView] = []
    private var systemAudioBarViews: [NSView] = []
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        createMainWindow()
        setupUI()
        setupAudioDevices()
        requestMicrophonePermission()
        logMessage("应用程序已启动")
    }
    
    private func requestMicrophonePermission() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                if granted {
                    print("✅ 麦克风权限已获得")
                } else {
                    print("❌ 麦克风权限被拒绝")
                }
            }
        }
    }
    
    private func createMainWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 450),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Offerin AI"
        window.center()
        window.makeKeyAndOrderFront(nil)
        
        // 设置深色主题背景
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0).cgColor
    }
    
    private func setupUI() {
        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        window.contentView = contentView
        
        var yPos: CGFloat = 425
        let margin: CGFloat = 20
        let boxHeight: CGFloat = 68
        let spacing: CGFloat = 8
        
        // 顶部导航栏
        setupNavigationBar(contentView: contentView, yPos: &yPos, margin: margin)
        yPos -= 40
        
        // 版本信息
        setupVersionLabel(contentView: contentView, yPos: &yPos, margin: margin)
        yPos -= 25
        
        // 麦克风区域
        setupMicrophoneSection(contentView: contentView, yPos: &yPos, margin: margin, boxHeight: boxHeight)
        yPos -= spacing
        
        // 系统音频区域
        setupSystemAudioSection(contentView: contentView, yPos: &yPos, margin: margin, boxHeight: boxHeight)
        yPos -= spacing
        
        // 服务控制区域
        setupServiceSection(contentView: contentView, yPos: &yPos, margin: margin, boxHeight: boxHeight)
        yPos -= spacing
        
        // 底部连接信息区域
        setupConnectionSection(contentView: contentView, yPos: &yPos, margin: margin)
    }
    
    private func setupNavigationBar(contentView: NSView, yPos: inout CGFloat, margin: CGFloat) {
        // 导航栏背景
        let navBar = NSView(frame: NSRect(x: margin, y: yPos - 40, width: contentView.bounds.width - 2 * margin, height: 40))
        navBar.wantsLayer = true
        navBar.layer?.backgroundColor = NSColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0).cgColor
        navBar.layer?.cornerRadius = 12
        navBar.layer?.borderWidth = 1
        navBar.layer?.borderColor = NSColor(red: 0.25, green: 0.25, blue: 0.25, alpha: 1.0).cgColor
        contentView.addSubview(navBar)
        
        // 左侧按钮组
        let leftButtonGroup = NSView(frame: NSRect(x: 15, y: 6, width: 160, height: 28))
        leftButtonGroup.wantsLayer = true
        leftButtonGroup.layer?.backgroundColor = NSColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1.0).cgColor
        leftButtonGroup.layer?.cornerRadius = 10
        navBar.addSubview(leftButtonGroup)
        
        let homeButton = NSButton(frame: NSRect(x: 8, y: 4, width: 70, height: 20))
        homeButton.title = "🏠 首页"
        homeButton.bezelStyle = .rounded
        homeButton.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        leftButtonGroup.addSubview(homeButton)
        
        let settingsButton = NSButton(frame: NSRect(x: 82, y: 4, width: 70, height: 20))
        settingsButton.title = "⚙️ 设置"
        settingsButton.bezelStyle = .rounded
        settingsButton.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        leftButtonGroup.addSubview(settingsButton)
        
        // 右侧按钮组
        let rightButtonGroup = NSView(frame: NSRect(x: 240, y: 6, width: 230, height: 28))
        rightButtonGroup.wantsLayer = true
        rightButtonGroup.layer?.backgroundColor = NSColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1.0).cgColor
        rightButtonGroup.layer?.cornerRadius = 10
        navBar.addSubview(rightButtonGroup)
        
        
        // 版权信息
        let copyrightLabel = NSTextField(labelWithString: "© www.offerin.cn, All Rights Reserved")
        copyrightLabel.frame = NSRect(x: contentView.bounds.width - 190, y: 3, width: 170, height: 12)
        copyrightLabel.font = NSFont.systemFont(ofSize: 8)
        copyrightLabel.textColor = NSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        copyrightLabel.alignment = .right
        copyrightLabel.isBordered = false
        copyrightLabel.isEditable = false
        copyrightLabel.backgroundColor = .clear
        contentView.addSubview(copyrightLabel)
    }
    
    private func setupVersionLabel(contentView: NSView, yPos: inout CGFloat, margin: CGFloat) {
        versionLabel = NSTextField(labelWithString: "当前版本: 2.1.0+15")
        versionLabel.frame = NSRect(x: margin + 5, y: yPos, width: 150, height: 16)
        versionLabel.font = NSFont.systemFont(ofSize: 11)
        versionLabel.textColor = .tertiaryLabelColor
        contentView.addSubview(versionLabel)
        yPos -= 25
    }
    
    private func setupMicrophoneSection(contentView: NSView, yPos: inout CGFloat, margin: CGFloat, boxHeight: CGFloat) {
        // 容器视图
        let containerView = NSView(frame: NSRect(x: margin, y: yPos - boxHeight, width: contentView.bounds.width - 2 * margin, height: boxHeight))
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0).cgColor
        containerView.layer?.cornerRadius = 12
        containerView.layer?.borderWidth = 1
        containerView.layer?.borderColor = NSColor(red: 0.25, green: 0.25, blue: 0.25, alpha: 1.0).cgColor
        contentView.addSubview(containerView)
        
        // 音频可视化指示器容器
        microphoneIndicator = NSView(frame: NSRect(x: 15, y: boxHeight/2 - 12, width: 10, height: 24))
        microphoneIndicator.wantsLayer = true
        containerView.addSubview(microphoneIndicator)
        
        // 创建音频条形图（3个条形）
        microphoneBarViews.removeAll()
        for i in 0..<3 {
            let barView = NSView(frame: NSRect(x: i * 3, y: 0, width: 2, height: 24))
            barView.wantsLayer = true
            barView.layer?.backgroundColor = NSColor.systemGreen.cgColor
            barView.layer?.cornerRadius = 1
            microphoneIndicator.addSubview(barView)
            microphoneBarViews.append(barView)
        }
        
        // 标题和描述
        microphoneLabel = NSTextField(labelWithString: "麦克风")
        microphoneLabel.frame = NSRect(x: 30, y: boxHeight - 28, width: 100, height: 22)
        microphoneLabel.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        microphoneLabel.textColor = .labelColor
        microphoneLabel.isBordered = false
        microphoneLabel.isEditable = false
        microphoneLabel.backgroundColor = .clear
        containerView.addSubview(microphoneLabel)
        
        microphoneDescLabel = NSTextField(labelWithString: "用于捕获您的声音")
        microphoneDescLabel.frame = NSRect(x: 30, y: 8, width: 150, height: 18)
        microphoneDescLabel.font = NSFont.systemFont(ofSize: 13)
        microphoneDescLabel.textColor = .secondaryLabelColor
        microphoneDescLabel.isBordered = false
        microphoneDescLabel.isEditable = false
        microphoneDescLabel.backgroundColor = .clear
        containerView.addSubview(microphoneDescLabel)
        
        // 设备选择下拉框
        microphonePopup = NSPopUpButton(frame: NSRect(x: 190, y: boxHeight/2 - 14, width: 230, height: 28))
        microphonePopup.wantsLayer = true
        microphonePopup.layer?.cornerRadius = 6
        microphonePopup.layer?.backgroundColor = NSColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0).cgColor
        microphonePopup.layer?.borderWidth = 1
        microphonePopup.layer?.borderColor = NSColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0).cgColor
        microphonePopup.font = NSFont.systemFont(ofSize: 15)
        containerView.addSubview(microphonePopup)
        
        // 刷新按钮
        microphoneRefreshButton = NSButton(frame: NSRect(x: 435, y: boxHeight/2 - 14, width: 28, height: 28))
        microphoneRefreshButton.title = "🔄"
        microphoneRefreshButton.bezelStyle = .rounded
        microphoneRefreshButton.target = self
        microphoneRefreshButton.action = #selector(refreshMicrophoneDevices)
        microphoneRefreshButton.font = NSFont.systemFont(ofSize: 14)
        containerView.addSubview(microphoneRefreshButton)
        
        yPos -= boxHeight
    }
    
    private func setupSystemAudioSection(contentView: NSView, yPos: inout CGFloat, margin: CGFloat, boxHeight: CGFloat) {
        // 容器视图
        let containerView = NSView(frame: NSRect(x: margin, y: yPos - boxHeight, width: contentView.bounds.width - 2 * margin, height: boxHeight))
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0).cgColor
        containerView.layer?.cornerRadius = 12
        containerView.layer?.borderWidth = 1
        containerView.layer?.borderColor = NSColor(red: 0.25, green: 0.25, blue: 0.25, alpha: 1.0).cgColor
        contentView.addSubview(containerView)
        
        // 系统音频可视化指示器容器
        systemAudioIndicator = NSView(frame: NSRect(x: 15, y: boxHeight/2 - 12, width: 10, height: 24))
        systemAudioIndicator.wantsLayer = true
        containerView.addSubview(systemAudioIndicator)
        
        // 创建系统音频条形图（3个条形）
        systemAudioBarViews.removeAll()
        for i in 0..<3 {
            let barView = NSView(frame: NSRect(x: i * 3, y: 0, width: 2, height: 24))
            barView.wantsLayer = true
            barView.layer?.backgroundColor = NSColor.systemOrange.cgColor
            barView.layer?.cornerRadius = 1
            systemAudioIndicator.addSubview(barView)
            systemAudioBarViews.append(barView)
        }
        
        // 标题和描述
        systemAudioLabel = NSTextField(labelWithString: "系统音频")
        systemAudioLabel.frame = NSRect(x: 30, y: boxHeight - 28, width: 100, height: 22)
        systemAudioLabel.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        systemAudioLabel.textColor = .labelColor
        systemAudioLabel.isBordered = false
        systemAudioLabel.isEditable = false
        systemAudioLabel.backgroundColor = .clear
        containerView.addSubview(systemAudioLabel)
        
        systemAudioDescLabel = NSTextField(labelWithString: "用于捕获对方的声音")
        systemAudioDescLabel.frame = NSRect(x: 30, y: 8, width: 150, height: 18)
        systemAudioDescLabel.font = NSFont.systemFont(ofSize: 13)
        systemAudioDescLabel.textColor = .secondaryLabelColor
        systemAudioDescLabel.isBordered = false
        systemAudioDescLabel.isEditable = false
        systemAudioDescLabel.backgroundColor = .clear
        containerView.addSubview(systemAudioDescLabel)
        
        // 设备选择下拉框
        systemAudioPopup = NSPopUpButton(frame: NSRect(x: 190, y: boxHeight/2 - 14, width: 230, height: 28))
        systemAudioPopup.wantsLayer = true
        systemAudioPopup.layer?.cornerRadius = 6
        systemAudioPopup.layer?.backgroundColor = NSColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0).cgColor
        systemAudioPopup.layer?.borderWidth = 1
        systemAudioPopup.layer?.borderColor = NSColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0).cgColor
        systemAudioPopup.font = NSFont.systemFont(ofSize: 15)
        containerView.addSubview(systemAudioPopup)
        
        // 刷新按钮
        systemAudioRefreshButton = NSButton(frame: NSRect(x: 435, y: boxHeight/2 - 14, width: 28, height: 28))
        systemAudioRefreshButton.title = "🔄"
        systemAudioRefreshButton.bezelStyle = .rounded
        systemAudioRefreshButton.target = self
        systemAudioRefreshButton.action = #selector(refreshSystemAudioDevices)
        systemAudioRefreshButton.font = NSFont.systemFont(ofSize: 14)
        containerView.addSubview(systemAudioRefreshButton)
        
        yPos -= boxHeight
    }
    
    private func setupServiceSection(contentView: NSView, yPos: inout CGFloat, margin: CGFloat, boxHeight: CGFloat) {
        // 容器视图
        let containerView = NSView(frame: NSRect(x: margin, y: yPos - boxHeight, width: contentView.bounds.width - 2 * margin, height: boxHeight))
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0).cgColor
        containerView.layer?.cornerRadius = 12
        containerView.layer?.borderWidth = 1
        containerView.layer?.borderColor = NSColor(red: 0.25, green: 0.25, blue: 0.25, alpha: 1.0).cgColor
        contentView.addSubview(containerView)
        
        // 状态标签
        serviceStatusLabel = NSTextField(labelWithString: "转发服务已停止")
        serviceStatusLabel.frame = NSRect(x: 30, y: boxHeight - 28, width: 200, height: 22)
        serviceStatusLabel.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        serviceStatusLabel.textColor = .labelColor
        serviceStatusLabel.isBordered = false
        serviceStatusLabel.isEditable = false
        serviceStatusLabel.backgroundColor = .clear
        containerView.addSubview(serviceStatusLabel)
        
        serviceDescLabel = NSTextField(labelWithString: "用于转发音频数据")
        serviceDescLabel.frame = NSRect(x: 30, y: 8, width: 150, height: 18)
        serviceDescLabel.font = NSFont.systemFont(ofSize: 13)
        serviceDescLabel.textColor = .secondaryLabelColor
        serviceDescLabel.isBordered = false
        serviceDescLabel.isEditable = false
        serviceDescLabel.backgroundColor = .clear
        containerView.addSubview(serviceDescLabel)
        
        // 按钮容器
        let buttonContainer = NSView(frame: NSRect(x: 300, y: boxHeight/2 - 20, width: 150, height: 40))
        buttonContainer.wantsLayer = true
        buttonContainer.layer?.backgroundColor = NSColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1.0).cgColor
        buttonContainer.layer?.cornerRadius = 10
        containerView.addSubview(buttonContainer)
        
        // 重启按钮
        restartButton = NSButton(frame: NSRect(x: 10, y: 10, width: 60, height: 20))
        restartButton.title = "🔄 重启"
        restartButton.bezelStyle = .rounded
        restartButton.target = self
        restartButton.action = #selector(restartServer)
        restartButton.isEnabled = false
        restartButton.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        buttonContainer.addSubview(restartButton)
        
        // 启动按钮
        startButton = NSButton(frame: NSRect(x: 80, y: 10, width: 80, height: 20))
        startButton.title = "▶ 启动"
        startButton.bezelStyle = .rounded
        startButton.target = self
        startButton.action = #selector(startServer)
        startButton.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        startButton.wantsLayer = true
        startButton.layer?.backgroundColor = NSColor.systemBlue.cgColor
        startButton.layer?.cornerRadius = 8
        buttonContainer.addSubview(startButton)
        
        yPos -= boxHeight
    }
    
    private func setupConnectionSection(contentView: NSView, yPos: inout CGFloat, margin: CGFloat) {
        // 容器视图
        let containerView = NSView(frame: NSRect(x: margin, y: yPos - 110, width: contentView.bounds.width - 2 * margin, height: 110))
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0).cgColor
        containerView.layer?.cornerRadius = 12
        containerView.layer?.borderWidth = 1
        containerView.layer?.borderColor = NSColor(red: 0.25, green: 0.25, blue: 0.25, alpha: 1.0).cgColor
        contentView.addSubview(containerView)
        
        // 标题
        connectionTitleLabel = NSTextField(labelWithString: "双端互联地址")
        connectionTitleLabel.frame = NSRect(x: 30, y: 80, width: 150, height: 22)
        connectionTitleLabel.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        connectionTitleLabel.textColor = .labelColor
        connectionTitleLabel.isBordered = false
        connectionTitleLabel.isEditable = false
        connectionTitleLabel.backgroundColor = .clear
        containerView.addSubview(connectionTitleLabel)
        
        // 功能按钮容器
        let buttonGroup = NSView(frame: NSRect(x: 190, y: 75, width: 250, height: 28))
        buttonGroup.wantsLayer = true
        buttonGroup.layer?.backgroundColor = NSColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1.0).cgColor
        buttonGroup.layer?.cornerRadius = 10
        containerView.addSubview(buttonGroup)
        
        newVersionButton = NSButton(frame: NSRect(x: 10, y: 4, width: 74, height: 20))
        newVersionButton.title = "使用新版"
        newVersionButton.bezelStyle = .rounded
        newVersionButton.target = self
        newVersionButton.action = #selector(useNewVersion)
        newVersionButton.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        buttonGroup.addSubview(newVersionButton)
        
        qrCodeButton = NSButton(frame: NSRect(x: 90, y: 4, width: 74, height: 20))
        qrCodeButton.title = "扫码连接"
        qrCodeButton.bezelStyle = .rounded
        qrCodeButton.target = self
        qrCodeButton.action = #selector(showQRCode)
        qrCodeButton.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        buttonGroup.addSubview(qrCodeButton)
        
        copyAllButton = NSButton(frame: NSRect(x: 170, y: 4, width: 74, height: 20))
        copyAllButton.title = "复制全部"
        copyAllButton.bezelStyle = .rounded
        copyAllButton.target = self
        copyAllButton.action = #selector(copyAll)
        copyAllButton.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        buttonGroup.addSubview(copyAllButton)
        
        // 状态信息
        statusInfoLabel = NSTextField(wrappingLabelWithString: "服务尚未启动，请点击\"启动\"按钮。启动后若出现网络权限弹窗，请允许，否则会连接失败。")
        statusInfoLabel.frame = NSRect(x: 30, y: 15, width: containerView.bounds.width - 60, height: 55)
        statusInfoLabel.font = NSFont.systemFont(ofSize: 12)
        statusInfoLabel.textColor = NSColor(red: 1.0, green: 0.6, blue: 0.6, alpha: 1.0)
        statusInfoLabel.isBordered = false
        statusInfoLabel.isEditable = false
        statusInfoLabel.backgroundColor = .clear
        statusInfoLabel.maximumNumberOfLines = 0
        containerView.addSubview(statusInfoLabel)
    }
    
    private func setupAudioDevices() {
        refreshMicrophoneDevices()
        refreshSystemAudioDevices()
    }
    
    @objc private func refreshMicrophoneDevices() {
        microphonePopup.removeAllItems()
        
        // 获取音频输入设备（使用兼容的API）
        if #available(macOS 14.0, *) {
            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.microphone, .builtInMicrophone],
                mediaType: .audio,
                position: .unspecified
            )
            let devices = discoverySession.devices
            for device in devices {
                microphonePopup.addItem(withTitle: device.localizedName)
            }
        } else {
            // 使用较旧的API
            let devices = AVCaptureDevice.devices(for: .audio)
            for device in devices {
                microphonePopup.addItem(withTitle: device.localizedName)
            }
        }
        
        if microphonePopup.numberOfItems == 0 {
            microphonePopup.addItem(withTitle: "无可用设备")
        } else {
            // 默认选择MacBook内置麦克风
            for i in 0..<microphonePopup.numberOfItems {
                let itemTitle = microphonePopup.item(at: i)?.title ?? ""
                if itemTitle.contains("MacBook") || itemTitle.contains("Built-in") {
                    microphonePopup.selectItem(at: i)
                    break
                }
            }
        }
        
        // 设置下拉框菜单项样式
        if let menu = microphonePopup.menu {
            for item in menu.items {
                item.attributedTitle = NSAttributedString(
                    string: item.title,
                    attributes: [
                        .font: NSFont.systemFont(ofSize: 15),
                        .foregroundColor: NSColor.labelColor
                    ]
                )
            }
        }
    }
    
    @objc private func refreshSystemAudioDevices() {
        systemAudioPopup.removeAllItems()
        
        // 添加显示器音频选项
        systemAudioPopup.addItem(withTitle: "Display 1")
        systemAudioPopup.addItem(withTitle: "Display 2")
        systemAudioPopup.addItem(withTitle: "内置扬声器")
        
        // 默认选择Display 1
        systemAudioPopup.selectItem(at: 0)
        
        // 设置下拉框菜单项样式
        if let menu = systemAudioPopup.menu {
            for item in menu.items {
                item.attributedTitle = NSAttributedString(
                    string: item.title,
                    attributes: [
                        .font: NSFont.systemFont(ofSize: 15),
                        .foregroundColor: NSColor.labelColor
                    ]
                )
            }
        }
    }
    
    @objc private func startServer() {
        logMessage("正在启动服务器...")
        updateServiceStatus(isRunning: false, isStarting: true)
        
        serverTask = Task {
            do {
                // 检查现有应用实例
                if let existingApp = self.app {
                    print("🛑 停止现有服务...")
                    try? await existingApp.server.shutdown()
                }
                
                // 初始化日志系统（只在第一次调用）
                if !Self.isLoggingInitialized {
                    var env = try Environment.detect()
                    try LoggingSystem.bootstrap(from: &env)
                    Self.isLoggingInitialized = true
                }
                
                // 创建新的应用实例
                let app = try await Application.make(.detect())
                
                try await configure(app)
                
                await MainActor.run {
                    self.app = app
                    self.updateServiceStatus(isRunning: true, isStarting: false)
                    self.logMessage("✅ 服务器已在端口 9047 启动")
                    self.logMessage("🎵 音频监控已开始")
                    
                    // 启动音频级别监测和可视化
                    self.startAudioLevelMonitoring()
                }
                
                // 启动服务器但不使用execute()，避免命令行冲突
                try await app.server.start(address: .hostname("127.0.0.1", port: 9047))
                
                // 保持服务器运行，直到任务被取消
                // 不在这里调用 asyncShutdown，让停止逻辑统一处理
                while !Task.isCancelled {
                    try await Task.sleep(for: .seconds(1))
                }
            } catch {
                await MainActor.run {
                    self.updateServiceStatus(isRunning: false, isStarting: false)
                    self.logMessage("❌ 服务器启动失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    @objc private func stopServer() {
        logMessage("正在停止服务器...")
        updateServiceStatus(isRunning: false, isStarting: false)
        
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
                _ = await task.result
                print("✅ 服务器任务已完成")
            }
            
            // 停止Vapor服务器（不完全关闭应用）
            if let app = self.app {
                print("🛑 停止 Vapor 服务器...")
                do {
                    try await app.server.shutdown()
                    print("✅ Vapor 服务器已停止")
                } catch {
                    print("⚠️ 停止 Vapor 服务器时出错: \(error)")
                }
            }
            
            await MainActor.run {
                self.logMessage("✅ 服务器停止完成，应用保持运行")
                
                // 停止音频级别监测和可视化
                self.stopAudioLevelMonitoring()
            }
        }
    }
    
    @objc private func restartServer() {
        Task {
            await stopServer()
            try? await Task.sleep(for: .seconds(1))
            await MainActor.run {
                self.startServer()
            }
        }
    }
    
    @objc private func useNewVersion() {
        logMessage("🆕 使用新版功能")
    }
    
    @objc private func showQRCode() {
        logMessage("📱 显示二维码")
    }
    
    @objc private func copyAll() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("http://127.0.0.1:9047", forType: .string)
        logMessage("📋 已复制服务器地址到剪贴板")
    }
    
    private func updateServiceStatus(isRunning: Bool, isStarting: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if isStarting {
                self.serviceStatusLabel.stringValue = "转发服务启动中..."
                self.serviceStatusLabel.textColor = .systemOrange
                self.startButton.isEnabled = false
                self.restartButton.isEnabled = false
            } else if isRunning {
                self.serviceStatusLabel.stringValue = "转发服务已启动"
                self.serviceStatusLabel.textColor = .systemGreen
                self.startButton.title = "⏹ 停止"
                self.startButton.action = #selector(self.stopServer)
                self.startButton.isEnabled = true
                self.restartButton.isEnabled = true
                self.statusInfoLabel.stringValue = "✅ 服务已启动！连接地址: http://127.0.0.1:9047"
                self.statusInfoLabel.textColor = .systemGreen
            } else {
                self.serviceStatusLabel.stringValue = "转发服务已停止"
                self.serviceStatusLabel.textColor = .systemRed
                self.startButton.title = "▶ 启动"
                self.startButton.action = #selector(self.startServer)
                self.startButton.isEnabled = true
                self.restartButton.isEnabled = false
                self.statusInfoLabel.stringValue = "服务尚未启动，请点击\"启动\"按钮。启动后若出现网络权限弹窗，请允许，否则会连接失败。"
                self.statusInfoLabel.textColor = .systemRed
            }
        }
    }
    
    private func logMessage(_ message: String) {
        DispatchQueue.main.async {
            print("📝 \(message)")
        }
    }
    
    // MARK: - 音频级别监测和可视化
    
    private func startAudioLevelMonitoring() {
        setupAudioEngine()
        startMicrophoneVisualization()
        startSystemAudioVisualization()
    }
    
    private func stopAudioLevelMonitoring() {
        stopMicrophoneVisualization()
        stopSystemAudioVisualization()
        stopAudioEngine()
    }
    
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return }
        
        inputNode = audioEngine.inputNode
        guard let inputNode = inputNode else { return }
        
        let format = inputNode.outputFormat(forBus: 0)
        
        // 安装音频数据处理tap
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self = self else { return }
            
            // 计算音频级别
            let level = self.calculateAudioLevel(from: buffer)
            
            DispatchQueue.main.async {
                self.currentMicrophoneLevel = level
            }
        }
        
        do {
            try audioEngine.start()
        } catch {
            print("❌ 音频引擎启动失败: \(error)")
        }
    }
    
    private func stopAudioEngine() {
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
        audioEngine = nil
        inputNode = nil
    }
    
    private func calculateAudioLevel(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0.0 }
        
        let channelDataPointer = channelData[0]
        let frameLength = Int(buffer.frameLength)
        
        var sum: Float = 0.0
        for i in 0..<frameLength {
            let sample = channelDataPointer[i]
            sum += sample * sample
        }
        
        let rms = sqrt(sum / Float(frameLength))
        let db = 20 * log10(rms)
        
        // 将dB转换为0-1的范围（-60dB到0dB）
        let normalizedLevel = max(0.0, min(1.0, (db + 60.0) / 60.0))
        return normalizedLevel
    }
    
    private func startMicrophoneVisualization() {
        guard !microphoneIsAnimating else { return }
        microphoneIsAnimating = true
        
        microphoneAnimationTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.updateMicrophoneBars()
            }
        }
    }
    
    private func stopMicrophoneVisualization() {
        microphoneIsAnimating = false
        microphoneAnimationTimer?.invalidate()
        microphoneAnimationTimer = nil
        
        DispatchQueue.main.async {
            // 重置条形图到最小高度
            for barView in self.microphoneBarViews {
                barView.frame.size.height = 2
                barView.frame.origin.y = 22
            }
        }
    }
    
    private func updateMicrophoneBars() {
        let level = currentMicrophoneLevel
        
        for (index, barView) in microphoneBarViews.enumerated() {
            // 为每个条形图设置不同的阈值
            let threshold: Float = Float(index) * 0.3 + 0.1
            
            let shouldAnimate = level > threshold
            let targetHeight: CGFloat = shouldAnimate ? CGFloat(level * 24.0) : 2.0
            
            // 平滑动画
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.1)
            
            barView.frame.size.height = max(2, targetHeight)
            barView.frame.origin.y = 24 - barView.frame.size.height
            
            // 根据音量改变颜色强度
            let intensity = CGFloat(level)
            let greenColor = NSColor(red: 0, green: 0.8 + intensity * 0.2, blue: 0, alpha: 0.8 + intensity * 0.2)
            barView.layer?.backgroundColor = greenColor.cgColor
            
            CATransaction.commit()
        }
    }
    
    private func startSystemAudioVisualization() {
        guard !systemAudioIsAnimating else { return }
        systemAudioIsAnimating = true
        
        systemAudioAnimationTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.updateSystemAudioBars()
            }
        }
    }
    
    private func stopSystemAudioVisualization() {
        systemAudioIsAnimating = false
        systemAudioAnimationTimer?.invalidate()
        systemAudioAnimationTimer = nil
        
        DispatchQueue.main.async {
            // 重置条形图到最小高度
            for barView in self.systemAudioBarViews {
                barView.frame.size.height = 2
                barView.frame.origin.y = 22
            }
        }
    }
    
    private func updateSystemAudioBars() {
        // 模拟系统音频级别（因为获取系统音频输出比较复杂）
        // 这里使用随机值来模拟，实际项目中应该连接到系统音频输出
        let simulatedLevel = Float.random(in: 0.1...0.8)
        currentSystemAudioLevel = simulatedLevel
        
        for (index, barView) in systemAudioBarViews.enumerated() {
            // 为每个条形图设置不同的阈值
            let threshold: Float = Float(index) * 0.25 + 0.15
            
            let shouldAnimate = simulatedLevel > threshold
            let targetHeight: CGFloat = shouldAnimate ? CGFloat(simulatedLevel * 24.0) : 2.0
            
            // 平滑动画
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.1)
            
            barView.frame.size.height = max(2, targetHeight)
            barView.frame.origin.y = 24 - barView.frame.size.height
            
            // 根据音量改变颜色强度
            let intensity = CGFloat(simulatedLevel)
            let orangeColor = NSColor(red: 1.0, green: 0.5 + intensity * 0.3, blue: 0, alpha: 0.8 + intensity * 0.2)
            barView.layer?.backgroundColor = orangeColor.cgColor
            
            CATransaction.commit()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("🛑 应用即将退出，清理资源...")
        
        // 停止音频监测
        stopAudioLevelMonitoring()
        
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