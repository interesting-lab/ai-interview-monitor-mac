import Foundation
import Vapor
import WebSocketKit
import AVFoundation
import Cocoa
import IOKit
import CoreAudio
import AudioToolbox
import ScreenCaptureKit
import Carbon
import ApplicationServices

// MARK: - 数据结构定义
struct AudioDataEvent: Content {
    let id: String
    let payload: AudioPayload
    let type: String?
    let wsEventType: String
}

struct AudioPayload: Content {
    let audioType: String  // "system" or "mic"
    let data: [Double]
}

struct HealthResponse: Content {
    let data: HealthData
    let success: Bool
}

struct HealthData: Content {
    let ok: Bool
}

struct ConfigResponse: Content {
    let data: ConfigData
    let success: Bool
}

struct ConfigData: Content {
    let audioConfig: AudioConfig
    let deviceInfo: DeviceInfo
}

struct AudioConfig: Content {
    let bufferDurationMs: Double
    let sampleRate: Double
}

struct DeviceInfo: Content {
    let build: String
    let id: String
    let name: String
    let platform: String
    let version: String
}

// 截图命令相关数据结构
struct ScreenshotCommand: Content {
    let type: String
    let wsEventType: String
    let payload: String
    let id: String
}

struct ScreenshotResponse: Content {
    let id: String
    let payload: ScreenshotPayload
    let wsEventType: String
}

struct ScreenshotPayload: Content {
    let base64: String
}

// 剪贴板文本事件相关数据结构
struct ClipboardTextEvent: Content {
    let id: String
    let payload: ClipboardTextPayload
    let type: String
    let wsEventType: String
}

struct ClipboardTextPayload: Content {
    let text: String
}

// 剪贴板图片事件数据结构
struct ClipboardImageEvent: Content {
    let id: String
    let payload: ClipboardImagePayload
    let wsEventType: String
}

struct ClipboardImagePayload: Content {
    let base64: String
}

// 主题模式枚举
enum ThemeMode: String, CaseIterable {
    case auto = "auto"
    case light = "light"
    case dark = "dark"
    
    var displayName: String {
        switch self {
        case .auto: return "跟随系统"
        case .light: return "浅色模式"
        case .dark: return "深色模式"
        }
    }
}

class AudioServerApp: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var permissionWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var isShowingPermissionScreen = false
    
    // 全局快捷键相关
    private var globalHotKey: Any?
    private var localHotKey: Any?
    private var screenshotHotKeyCode: UInt16 = 49  // 空格键的键码
    private var screenshotModifierFlags: NSEvent.ModifierFlags = [.command, .shift]
    
    // 主题设置
    private var currentThemeMode: ThemeMode = .auto
    
    // 主题相关
    private var isDarkMode: Bool {
        if #available(macOS 10.14, *) {
            // 首先检查系统偏好设置
            let userDefaults = UserDefaults.standard
            let appleInterfaceStyle = userDefaults.string(forKey: "AppleInterfaceStyle")
            if appleInterfaceStyle == "Dark" {
                return true
            }
            
            // 备用检测方法：使用外观
            let appearance = window?.effectiveAppearance ?? NSApp.effectiveAppearance
            if let appearanceName = appearance.bestMatch(from: [.aqua, .darkAqua]) {
                return appearanceName == .darkAqua
            }
            
            // 更多备用检测方法
            return appearance.name == .darkAqua || appearance.name == .vibrantDark
        }
        return false
    }
    
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
    
    // 剪贴板监听
    private var clipboardTimer: Timer?
    private var lastClipboardContent: String = ""
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupThemeObserver()
        loadUserPreferences()
        createMainWindow()
        checkInitialPermissions()
        startClipboardMonitoring()
        logMessage("应用程序已启动")
    }
    
    private func setupThemeObserver() {
        if #available(macOS 10.14, *) {
            // 监听系统主题变化
            DistributedNotificationCenter.default.addObserver(
                self,
                selector: #selector(systemThemeChanged),
                name: Notification.Name("AppleInterfaceThemeChangedNotification"),
                object: nil
            )
            
            // 另一个主题变化通知
            DistributedNotificationCenter.default.addObserver(
                self,
                selector: #selector(systemThemeChanged),
                name: Notification.Name("AppleAquaColorVariantChanged"),
                object: nil
            )
        }
    }
    
    @objc private func systemThemeChanged() {
        DispatchQueue.main.async {
            print("🎨 主题变化检测到，当前是深色模式: \(self.isDarkMode)")
            self.updateTheme()
        }
    }
    
    private func updateTheme() {
        // 更新主窗口主题
        updateWindowTheme(window)
        
        // 更新权限窗口主题
        if let permissionWindow = permissionWindow {
            updateWindowTheme(permissionWindow)
            setupPermissionUI() // 重新设置权限界面以应用新主题
        }
        
        // 如果主界面已显示，重新设置UI
        if !isShowingPermissionScreen {
            setupUI()
            setupAudioDevices()
        }
    }
    
    private func updateWindowTheme(_ window: NSWindow) {
        if #available(macOS 10.14, *) {
            window.appearance = nil // 使用系统默认外观
        }
        
        // 更新背景色
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = getBackgroundColor()
    }
    
    private func getBackgroundColor() -> CGColor {
        if isDarkMode {
            return NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0).cgColor
        } else {
            return NSColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0).cgColor
        }
    }
    
    private func getContainerBackgroundColor() -> NSColor {
        if isDarkMode {
            return NSColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0)
        } else {
            return NSColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0)
        }
    }
    
    private func getContainerBorderColor() -> NSColor {
        if isDarkMode {
            return NSColor(red: 0.25, green: 0.25, blue: 0.25, alpha: 1.0)
        } else {
            return NSColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1.0)
        }
    }
    
    private func getButtonBackgroundColor() -> NSColor {
        if isDarkMode {
            return NSColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1.0)
        } else {
            return NSColor(red: 0.92, green: 0.92, blue: 0.92, alpha: 1.0)
        }
    }
    
    private func checkInitialPermissions() {
        let microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let screenRecordingGranted = checkScreenRecordingPermission()
        
        if microphoneStatus == .authorized && screenRecordingGranted {
            // 所有权限已获得，显示主界面
            setupMainInterface()
        } else {
            // 显示权限请求界面
            showPermissionScreen()
        }
    }
    
    private func checkScreenRecordingPermission() -> Bool {
        if #available(macOS 11.0, *) {
            // 创建一个测试的 CGDisplayStream 来检查屏幕录制权限
            let displayID = CGMainDisplayID()
            let stream = CGDisplayStream(
                dispatchQueueDisplay: displayID,
                outputWidth: 1,
                outputHeight: 1,
                pixelFormat: Int32(kCVPixelFormatType_32BGRA),
                properties: nil,
                queue: DispatchQueue.global(),
                handler: { _, _, _, _ in }
            )
            return stream != nil
        } else {
            // 较旧版本假设有权限
            return true
        }
    }
    
    private func setupMainInterface() {
        print("🔧 设置主界面...")
        
        setupUI()
        setupAudioDevices()
        window.makeKeyAndOrderFront(nil)
        if let permissionWindow = permissionWindow {
            permissionWindow.close()
            self.permissionWindow = nil
        }
        isShowingPermissionScreen = false
        
        // 确保主题正确设置
        updateTheme()
        
        // 设置全局快捷键
        print("🎯 准备设置全局快捷键...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.setupGlobalHotKey()
        }
        
        // 自动启动服务器
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.startServer()
        }
        
        print("✅ 主界面设置完成")
    }
    
    private func showPermissionScreen() {
        isShowingPermissionScreen = true
        createPermissionWindow()
        window.orderOut(nil) // 隐藏主窗口
    }
    
    private func createPermissionWindow() {
        permissionWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        guard let permissionWindow = permissionWindow else { return }
        
        permissionWindow.title = "Interesting Lab"
        permissionWindow.center()
        permissionWindow.isReleasedWhenClosed = false
        permissionWindow.delegate = self
        
        // 禁用窗口大小调整，但允许拖动
        permissionWindow.minSize = NSSize(width: 500, height: 360)
        permissionWindow.maxSize = NSSize(width: 500, height: 360)
        
        // 设置动态主题
        updateWindowTheme(permissionWindow)
        
        setupPermissionUI()
        permissionWindow.makeKeyAndOrderFront(nil)
    }
    
    private func setupPermissionUI() {
        guard let contentView = permissionWindow?.contentView else { return }
        
        // 清除现有内容
        contentView.subviews.removeAll()
        
        // 主标题
        let titleLabel = NSTextField(labelWithString: "授权所需权限")
        titleLabel.frame = NSRect(x: 0, y: 220, width: 480, height: 30)
        titleLabel.font = NSFont.systemFont(ofSize: 24, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .center
        contentView.addSubview(titleLabel)
        
        // 副标题
        let subtitleLabel = NSTextField(labelWithString: "正在检查所需的系统权限")
        subtitleLabel.frame = NSRect(x: 0, y: 190, width: 480, height: 20)
        subtitleLabel.font = NSFont.systemFont(ofSize: 14)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.alignment = .center
        contentView.addSubview(subtitleLabel)
        
        // 权限图标
        let iconView = NSView(frame: NSRect(x: 220, y: 130, width: 40, height: 40))
        iconView.wantsLayer = true
        iconView.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        iconView.layer?.cornerRadius = 20
        contentView.addSubview(iconView)
        
        // 在图标中添加盾牌符号
        let shieldLabel = NSTextField(labelWithString: "🛡")
        shieldLabel.frame = NSRect(x: 8, y: 8, width: 24, height: 24)
        shieldLabel.font = NSFont.systemFont(ofSize: 20)
        shieldLabel.alignment = .center
        shieldLabel.isBordered = false
        shieldLabel.isEditable = false
        shieldLabel.backgroundColor = .clear
        iconView.addSubview(shieldLabel)
        
        // 麦克风权限项
        setupPermissionItem(
            contentView: contentView,
            yPos: 90,
            icon: "🎤",
            title: "麦克风权限",
            description: "需要此权限以捕获您的声音",
            status: AVCaptureDevice.authorizationStatus(for: .audio)
        )
        
        // 屏幕录制权限项
        let screenRecordingStatus: AVAuthorizationStatus = checkScreenRecordingPermission() ? .authorized : .notDetermined
        setupPermissionItem(
            contentView: contentView,
            yPos: 50,
            icon: "🖥️",
            title: "屏幕录制权限",
            description: "需要此权限以捕获系统音频",
            status: screenRecordingStatus
        )
        
        // 底部帮助按钮
        let helpButton = NSButton(frame: NSRect(x: 190, y: 15, width: 100, height: 24))
        helpButton.title = "📖 获取帮助"
        helpButton.bezelStyle = .rounded
        helpButton.target = self
        helpButton.action = #selector(showHelp)
        helpButton.font = NSFont.systemFont(ofSize: 12)
        contentView.addSubview(helpButton)
    }
    
    private func setupPermissionItem(contentView: NSView, yPos: CGFloat, icon: String, title: String, description: String, status: AVAuthorizationStatus) {
        let containerView = NSView(frame: NSRect(x: 40, y: yPos, width: 420, height: 48))
        contentView.addSubview(containerView)
        
        // 图标
        let iconLabel = NSTextField(labelWithString: icon)
        iconLabel.frame = NSRect(x: 0, y: 12, width: 28, height: 28)
        iconLabel.font = NSFont.systemFont(ofSize: 20)
        iconLabel.alignment = .center
        iconLabel.isBordered = false
        iconLabel.isEditable = false
        iconLabel.backgroundColor = .clear
        containerView.addSubview(iconLabel)
        
        // 标题
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.frame = NSRect(x: 38, y: 22, width: 140, height: 22)
        titleLabel.font = NSFont.systemFont(ofSize: 15, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.isBordered = false
        titleLabel.isEditable = false
        titleLabel.backgroundColor = .clear
        containerView.addSubview(titleLabel)
        
        // 描述
        let descLabel = NSTextField(wrappingLabelWithString: description)
        descLabel.frame = NSRect(x: 38, y: 2, width: 220, height: 20)
        descLabel.font = NSFont.systemFont(ofSize: 12)
        descLabel.textColor = .secondaryLabelColor
        descLabel.isBordered = false
        descLabel.isEditable = false
        descLabel.backgroundColor = .clear
        descLabel.maximumNumberOfLines = 2
        containerView.addSubview(descLabel)
        
        // 状态按钮
        let statusButton = NSButton(frame: NSRect(x: 270, y: 10, width: 120, height: 32))
        statusButton.bezelStyle = .rounded
        statusButton.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        
        switch status {
        case .authorized:
            statusButton.title = "✅ 已授权"
            statusButton.isEnabled = false
        case .denied, .restricted:
            statusButton.title = "⚠ 重新授权"
            statusButton.target = self
            statusButton.action = #selector(requestPermissionAgain)
        case .notDetermined:
            statusButton.title = "📤 前往授权"
            statusButton.target = self
            statusButton.action = #selector(requestInitialPermission)
        @unknown default:
            statusButton.title = "❓ 检查状态"
            statusButton.target = self
            statusButton.action = #selector(checkPermissionStatus)
        }
        
        containerView.addSubview(statusButton)
    }
    
    @objc private func requestInitialPermission() {
        // 检查点击的是哪个权限项，这里简化处理，先请求麦克风权限
        let microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        if microphoneStatus == .notDetermined {
            requestMicrophonePermission()
        } else {
            requestScreenRecordingPermission()
        }
    }
    
    @objc private func requestPermissionAgain() {
        openSystemPreferences()
    }
    
    private func requestScreenRecordingPermission() {
        if #available(macOS 14.0, *) {
            // 使用 ScreenCaptureKit 请求权限
            Task {
                do {
                    _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                    await MainActor.run {
                        self.logMessage("✅ 屏幕录制权限检查完成")
                        self.checkAllPermissionsAndProceed()
                    }
                } catch {
                    await MainActor.run {
                        self.logMessage("❌ 屏幕录制权限被拒绝: \(error.localizedDescription)")
                        self.showScreenRecordingPermissionAlert()
                    }
                }
            }
        } else {
            // 较旧版本的权限请求
            showScreenRecordingPermissionAlert()
        }
    }
    
    private func showScreenRecordingPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "需要屏幕录制权限"
        alert.informativeText = "为了捕获系统音频，本应用需要屏幕录制权限。\n\n请在系统设置中手动授予权限：\n1. 打开系统设置\n2. 前往隐私与安全性 > 屏幕录制\n3. 找到并勾选本应用"
        alert.alertStyle = .warning
        
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "稍后设置")
        alert.addButton(withTitle: "重新检查")
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn:
            openScreenRecordingPreferences()
        case .alertSecondButtonReturn:
            logMessage("⚠️ 用户选择稍后设置屏幕录制权限")
        case .alertThirdButtonReturn:
            checkAllPermissionsAndProceed()
        default:
            break
        }
    }
    
    private func openScreenRecordingPreferences() {
        if #available(macOS 13.0, *) {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        } else {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
        logMessage("🔧 已打开屏幕录制设置，请手动授予权限")
    }
    
    @objc private func checkPermissionStatus() {
        checkInitialPermissions()
    }
    
    @objc private func showHelp() {
        let alert = NSAlert()
        alert.messageText = "权限设置帮助"
        alert.informativeText = "为了正常使用音频捕获功能，本应用需要以下权限：\n\n• 麦克风权限：用于录制您的声音\n• 屏幕录制权限：用于录制系统播放的声音\n\n如果权限被拒绝，请：\n1. 打开系统设置\n2. 前往隐私与安全性 > 麦克风/屏幕录制\n3. 找到并勾选本应用"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "了解")
        alert.addButton(withTitle: "打开系统设置")
        
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            openSystemPreferences()
        }
    }
    
    @objc private func checkAndRequestPermissions() {
        // 检查麦克风权限状态
        let microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        
        switch microphoneStatus {
        case .notDetermined:
            // 首次使用，请求权限
            requestMicrophonePermission()
        case .denied, .restricted:
            // 权限被拒绝，显示引导界面
            showPermissionGuideAlert()
        case .authorized:
            print("✅ 麦克风权限已获得")
        @unknown default:
            print("⚠️ 未知的权限状态")
            requestMicrophonePermission()
        }
    }
    
    private func requestMicrophonePermission() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                if granted {
                    print("✅ 麦克风权限已获得")
                    self.logMessage("✅ 麦克风权限已获得")
                    
                    // 如果当前显示权限界面，检查是否可以切换到主界面
                    if self.isShowingPermissionScreen {
                        self.checkAllPermissionsAndProceed()
                    }
                } else {
                    print("❌ 麦克风权限被拒绝")
                    self.logMessage("❌ 麦克风权限被拒绝")
                    
                    // 如果显示权限界面，更新界面状态
                    if self.isShowingPermissionScreen {
                        self.setupPermissionUI()
                    } else {
                        self.showPermissionGuideAlert()
                    }
                }
            }
        }
    }
    
    private func checkAllPermissionsAndProceed() {
        let microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let screenRecordingGranted = checkScreenRecordingPermission()
        
        if microphoneStatus == .authorized && screenRecordingGranted {
            // 所有权限都已获得，切换到主界面
            setupMainInterface()
        } else {
            // 更新权限界面显示
            setupPermissionUI()
        }
    }
    
    private func showPermissionGuideAlert() {
        let alert = NSAlert()
        alert.messageText = "需要麦克风权限"
        alert.informativeText = "为了正常使用音频捕获功能，请在系统设置中授予本应用麦克风权限。\n\n步骤：\n1. 点击下方\"打开系统设置\"按钮\n2. 在隐私与安全性 > 麦克风中找到本应用\n3. 勾选旁边的复选框以授予权限\n4. 重启应用以使权限生效"
        alert.alertStyle = .warning
        
        // 添加按钮
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "稍后设置")
        alert.addButton(withTitle: "重新检查权限")
        
        // 设置图标
        alert.icon = NSImage(named: NSImage.cautionName)
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn:
            // 打开系统设置
            openSystemPreferences()
        case .alertSecondButtonReturn:
            // 稍后设置，记录日志
            logMessage("⚠️ 用户选择稍后设置权限")
        case .alertThirdButtonReturn:
            // 重新检查权限
            checkAndRequestPermissions()
        default:
            break
        }
    }
    
    @objc private func openSystemPreferences() {
        // macOS Ventura (13.0) 及以上使用新的设置路径
        if #available(macOS 13.0, *) {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                NSWorkspace.shared.open(url)
            }
        } else {
            // 较旧版本的macOS
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                NSWorkspace.shared.open(url)
            }
        }
        
        logMessage("🔧 已打开系统设置，请手动授予麦克风权限")
    }
    
    private func createMainWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 450),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Interesting Lab"
        window.center()
        
        // 禁用窗口大小调整，但允许拖动
        window.minSize = NSSize(width: 500, height: 450)
        window.maxSize = NSSize(width: 500, height: 450)
        
        // 设置动态主题
        updateWindowTheme(window)
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
        yPos -= 15
        
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
        navBar.layer?.backgroundColor = getContainerBackgroundColor().cgColor
        navBar.layer?.cornerRadius = 12
        navBar.layer?.borderWidth = 1
        navBar.layer?.borderColor = getContainerBorderColor().cgColor
        contentView.addSubview(navBar)
        
        // 左侧按钮组
        let leftButtonGroup = NSView(frame: NSRect(x: 15, y: 6, width: 160, height: 28))
        leftButtonGroup.wantsLayer = true
        leftButtonGroup.layer?.backgroundColor = getButtonBackgroundColor().cgColor
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
        settingsButton.target = self
        settingsButton.action = #selector(openSettings)
        settingsButton.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        leftButtonGroup.addSubview(settingsButton)
        
        // 右侧按钮组
        let rightButtonGroup = NSView(frame: NSRect(x: 240, y: 6, width: 230, height: 28))
        rightButtonGroup.wantsLayer = true
        rightButtonGroup.layer?.backgroundColor = getButtonBackgroundColor().cgColor
        rightButtonGroup.layer?.cornerRadius = 10
        navBar.addSubview(rightButtonGroup)
        
        
        // 版权信息
        let copyrightLabel = NSTextField(labelWithString: "©")
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
        let versionString = getAppVersion()
        versionLabel = NSTextField(labelWithString: "当前版本: \(versionString)")
        versionLabel.frame = NSRect(x: margin + 5, y: yPos, width: 150, height: 16)
        versionLabel.font = NSFont.systemFont(ofSize: 11)
        versionLabel.textColor = .tertiaryLabelColor
        contentView.addSubview(versionLabel)
        
        // 权限状态标签
        let permissionStatusLabel = NSTextField(labelWithString: "")
        permissionStatusLabel.frame = NSRect(x: margin + 180, y: yPos, width: 250, height: 16)
        permissionStatusLabel.font = NSFont.systemFont(ofSize: 11)
        permissionStatusLabel.isBordered = false
        permissionStatusLabel.isEditable = false
        permissionStatusLabel.backgroundColor = .clear
        updatePermissionStatusLabel(permissionStatusLabel)
        contentView.addSubview(permissionStatusLabel)
        
        yPos -= 25
    }
    
    private func updatePermissionStatusLabel(_ label: NSTextField) {
        let microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        
        switch microphoneStatus {
        case .authorized:
            label.stringValue = ""
            label.textColor = .systemGreen
        case .denied, .restricted:
            label.stringValue = "🚫 麦克风权限：未授权（点击设置进行配置）"
            label.textColor = .systemRed
        case .notDetermined:
            label.stringValue = "❓ 麦克风权限：待确定"
            label.textColor = .systemOrange
        @unknown default:
            label.stringValue = "⚠️ 麦克风权限：状态未知"
            label.textColor = .systemYellow
        }
    }
    
    private func setupMicrophoneSection(contentView: NSView, yPos: inout CGFloat, margin: CGFloat, boxHeight: CGFloat) {
        // 容器视图
        let containerView = NSView(frame: NSRect(x: margin, y: yPos - boxHeight, width: contentView.bounds.width - 2 * margin, height: boxHeight))
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = getContainerBackgroundColor().cgColor
        containerView.layer?.cornerRadius = 12
        containerView.layer?.borderWidth = 1
        containerView.layer?.borderColor = getContainerBorderColor().cgColor
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
        microphonePopup.layer?.backgroundColor = getButtonBackgroundColor().cgColor
        microphonePopup.layer?.borderWidth = 1
        microphonePopup.layer?.borderColor = getContainerBorderColor().cgColor
        microphonePopup.font = NSFont.systemFont(ofSize: 15)
        containerView.addSubview(microphonePopup)
        
        // 刷新按钮
        microphoneRefreshButton = NSButton(frame: NSRect(x: 424, y: boxHeight/2 - 18, width: 36, height: 36))
        if #available(macOS 11.0, *) {
            microphoneRefreshButton.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "刷新")
            microphoneRefreshButton.title = ""
        } else {
            microphoneRefreshButton.title = "⟲"
            microphoneRefreshButton.font = NSFont.systemFont(ofSize: 24)
        }
        microphoneRefreshButton.bezelStyle = .rounded
        microphoneRefreshButton.target = self
        microphoneRefreshButton.action = #selector(refreshMicrophoneDevices)
        microphoneRefreshButton.isBordered = true
        containerView.addSubview(microphoneRefreshButton)
        
        yPos -= boxHeight
    }
    
    private func setupSystemAudioSection(contentView: NSView, yPos: inout CGFloat, margin: CGFloat, boxHeight: CGFloat) {
        // 容器视图
        let containerView = NSView(frame: NSRect(x: margin, y: yPos - boxHeight, width: contentView.bounds.width - 2 * margin, height: boxHeight))
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = getContainerBackgroundColor().cgColor
        containerView.layer?.cornerRadius = 12
        containerView.layer?.borderWidth = 1
        containerView.layer?.borderColor = getContainerBorderColor().cgColor
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
        
        systemAudioDescLabel = NSTextField(labelWithString: "用于捕获屏幕音频")
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
        systemAudioPopup.layer?.backgroundColor = getButtonBackgroundColor().cgColor
        systemAudioPopup.layer?.borderWidth = 1
        systemAudioPopup.layer?.borderColor = getContainerBorderColor().cgColor
        systemAudioPopup.font = NSFont.systemFont(ofSize: 15)
        systemAudioPopup.target = self
        systemAudioPopup.action = #selector(systemAudioDisplayChanged)
        containerView.addSubview(systemAudioPopup)
        
        // 刷新按钮
        systemAudioRefreshButton = NSButton(frame: NSRect(x: 424, y: boxHeight/2 - 18, width: 36, height: 36))
        if #available(macOS 11.0, *) {
            systemAudioRefreshButton.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "刷新")
            systemAudioRefreshButton.title = ""
        } else {
            systemAudioRefreshButton.title = "⟲"
            systemAudioRefreshButton.font = NSFont.systemFont(ofSize: 24)
        }
        systemAudioRefreshButton.bezelStyle = .rounded
        systemAudioRefreshButton.target = self
        systemAudioRefreshButton.action = #selector(refreshSystemAudioDevices)
        systemAudioRefreshButton.isBordered = true
        containerView.addSubview(systemAudioRefreshButton)
        
        yPos -= boxHeight
    }
    
    private func setupServiceSection(contentView: NSView, yPos: inout CGFloat, margin: CGFloat, boxHeight: CGFloat) {
        // 容器视图
        let containerView = NSView(frame: NSRect(x: margin, y: yPos - boxHeight, width: contentView.bounds.width - 2 * margin, height: boxHeight))
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = getContainerBackgroundColor().cgColor
        containerView.layer?.cornerRadius = 12
        containerView.layer?.borderWidth = 1
        containerView.layer?.borderColor = getContainerBorderColor().cgColor
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
        let buttonContainer = NSView(frame: NSRect(x: 280, y: boxHeight/2 - 18, width: 180, height: 36))
        buttonContainer.wantsLayer = true
        buttonContainer.layer?.backgroundColor = getButtonBackgroundColor().cgColor
        buttonContainer.layer?.cornerRadius = 12
        containerView.addSubview(buttonContainer)
        
        // 重启按钮
        restartButton = NSButton(frame: NSRect(x: 12, y: 6, width: 75, height: 24))
        restartButton.title = "🔄 重启"
        restartButton.bezelStyle = .rounded
        restartButton.target = self
        restartButton.action = #selector(restartServer)
        restartButton.isEnabled = false
        restartButton.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        buttonContainer.addSubview(restartButton)
        
        // 启动按钮
        startButton = NSButton(frame: NSRect(x: 93, y: 6, width: 75, height: 24))
        startButton.title = "▶ 启动"
        startButton.bezelStyle = .rounded
        startButton.target = self
        startButton.action = #selector(startServer)
        startButton.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        buttonContainer.addSubview(startButton)
        
        yPos -= boxHeight
    }
    
    private func setupConnectionSection(contentView: NSView, yPos: inout CGFloat, margin: CGFloat) {
        // 容器视图
        let containerView = NSView(frame: NSRect(x: margin, y: yPos - 110, width: contentView.bounds.width - 2 * margin, height: 110))
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = getContainerBackgroundColor().cgColor
        containerView.layer?.cornerRadius = 12
        containerView.layer?.borderWidth = 1
        containerView.layer?.borderColor = getContainerBorderColor().cgColor
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
        buttonGroup.layer?.backgroundColor = getButtonBackgroundColor().cgColor
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
        
        // 获取音频输入设备（兼容不同macOS版本）
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
            // 对于较旧版本，只使用 builtInMicrophone
            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInMicrophone],
                mediaType: .audio,
                position: .unspecified
            )
            let devices = discoverySession.devices
            for device in devices {
                microphonePopup.addItem(withTitle: device.localizedName)
            }
            
            // 如果没有找到设备，尝试获取默认音频设备
            if devices.isEmpty {
                if let defaultDevice = AVCaptureDevice.default(for: .audio) {
                    microphonePopup.addItem(withTitle: defaultDevice.localizedName)
                }
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
    
    @objc private func systemAudioDisplayChanged() {
        guard let selectedItem = systemAudioPopup.selectedItem else { return }
        
        if let displayID = selectedItem.representedObject as? CGDirectDisplayID {
            logMessage("🖥️ 已选择显示器 ID: \(displayID) - \(selectedItem.title)")
        } else {
            logMessage("🖥️ 已选择显示器: \(selectedItem.title)")
        }
    }
    
    @objc private func refreshSystemAudioDevices() {
        systemAudioPopup.removeAllItems()
        
        if #available(macOS 12.3, *) {
            // 使用 ScreenCaptureKit 获取可用的显示器
            Task {
                do {
                    let availableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                    
                    await MainActor.run {
                        // 添加所有可用的显示器
                        for (index, display) in availableContent.displays.enumerated() {
                            let displayName = "显示器 \(index + 1) (\(Int(display.width))×\(Int(display.height)))"
                            self.systemAudioPopup.addItem(withTitle: displayName)
                            
                            // 为每个菜单项存储对应的显示器ID
                            if let menuItem = self.systemAudioPopup.menu?.items.last {
                                menuItem.representedObject = display.displayID
                            }
                        }
                        
                        // 如果没有找到显示器，添加默认选项
                        if availableContent.displays.isEmpty {
                            self.systemAudioPopup.addItem(withTitle: "主显示器")
                        }
                        
                        // 默认选择第一个显示器
                        if self.systemAudioPopup.numberOfItems > 0 {
                            self.systemAudioPopup.selectItem(at: 0)
                        }
                        
                        // 设置下拉框菜单项样式
                        if let menu = self.systemAudioPopup.menu {
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
                        
                        self.logMessage("🖥️ 已刷新显示器列表，找到 \(availableContent.displays.count) 个显示器")
                    }
                } catch {
                    await MainActor.run {
                        // 如果获取失败，添加默认选项
                        self.systemAudioPopup.addItem(withTitle: "主显示器")
                        self.systemAudioPopup.addItem(withTitle: "所有显示器")
                        self.systemAudioPopup.selectItem(at: 0)
                        
                        // 设置下拉框菜单项样式
                        if let menu = self.systemAudioPopup.menu {
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
                        
                        self.logMessage("⚠️ 无法获取显示器信息: \(error.localizedDescription)")
                    }
                }
            }
        } else {
            // 较旧版本的 macOS，使用默认选项
            systemAudioPopup.addItem(withTitle: "主显示器")
            systemAudioPopup.addItem(withTitle: "所有显示器")
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
            
            logMessage("ℹ️ 当前 macOS 版本不支持 ScreenCaptureKit，使用默认显示器选项")
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
                    await existingApp.server.shutdown()
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
                
                // 启动音频捕获系统
                if #available(macOS 12.3, *) {
                    do {
                        self.logMessage("🎙️ 启动音频捕获系统...")
                        try await AudioCapture.shared.startGlobalAudioCapture()
                        self.logMessage("✅ 音频捕获系统已启动")
                    } catch {
                        self.logMessage("❌ 音频捕获启动失败: \(error.localizedDescription)")
                    }
                }
                
                // 启动服务器但不使用execute()，避免命令行冲突
                try await app.server.start(address: .hostname("0.0.0.0", port: 9047))
                
                await MainActor.run {
                    self.app = app
                    self.updateServiceStatus(isRunning: true, isStarting: false)
                    self.logMessage("✅ 服务器已在端口 9047 启动")
                    
                    // 获取所有网络接口
                    let networkIPs = getNetworkInterfaces()
                    self.logMessage("🌐 可访问的接口:")
                    for ip in networkIPs {
                        self.logMessage("   • HTTP: http://\(ip):9047")
                        self.logMessage("   • WebSocket: ws://\(ip):9047/ws")
                        self.logMessage("   • 健康检查: http://\(ip):9047/health")
                        self.logMessage("   • 配置信息: http://\(ip):9047/config")
                        if ip != networkIPs.last {
                            self.logMessage("   ----")
                        }
                    }
                    self.logMessage("🎵 音频监控和转发已全面启动")
                    
                    // 启动音频级别监测和可视化
                    self.startAudioLevelMonitoring()
                }
                
                // 保持服务器运行，直到任务被取消
                // 不在这里调用 asyncShutdown，让停止逻辑统一处理
                while !Task.isCancelled {
                    if #available(macOS 13.0, *) {
                        try await Task.sleep(for: .seconds(1))
                    } else {
                        try await Task.sleep(nanoseconds: 1_000_000_000)
                    }
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
                await app.server.shutdown()
                print("✅ Vapor 服务器已停止")
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
            stopServer()
            if #available(macOS 13.0, *) {
                try? await Task.sleep(for: .seconds(1))
            } else {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
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
        let networkIPs = getNetworkInterfaces()
        let addresses = networkIPs.map { "http://\($0):9047" }.joined(separator: "\n")
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(addresses, forType: .string)
        logMessage("📋 已复制所有服务器地址到剪贴板")
    }
    
    @objc private func openSettings() {
        if settingsWindow != nil {
            settingsWindow?.makeKeyAndOrderFront(nil)
            return
        }
        createSettingsWindow()
    }
    
    private func createSettingsWindow() {
        settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        settingsWindow?.title = "设置"
        settingsWindow?.center()
        settingsWindow?.delegate = self
        
        // 设置动态主题
        updateWindowTheme(settingsWindow!)
        
        setupSettingsUI()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
    
    private func setupSettingsUI() {
        guard let settingsWindow = settingsWindow else { return }
        
        let contentView = NSView(frame: settingsWindow.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        settingsWindow.contentView = contentView
        
        var yPos: CGFloat = 360
        let margin: CGFloat = 20
        
        // 标题
        let titleLabel = NSTextField(labelWithString: "应用设置")
        titleLabel.frame = NSRect(x: margin, y: yPos, width: 200, height: 30)
        titleLabel.font = NSFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .labelColor
        titleLabel.isBordered = false
        titleLabel.isEditable = false
        titleLabel.backgroundColor = .clear
        contentView.addSubview(titleLabel)
        yPos -= 50
        
        // 版本信息区域
        setupVersionSection(contentView: contentView, yPos: &yPos, margin: margin)
        
        // 主题设置区域
        setupThemeSection(contentView: contentView, yPos: &yPos, margin: margin)
        
        // 全局快捷键设置区域
        setupHotKeySection(contentView: contentView, yPos: &yPos, margin: margin)
        
        // 权限设置区域
        setupPermissionSection(contentView: contentView, yPos: &yPos, margin: margin)
    }
    
    private func setupVersionSection(contentView: NSView, yPos: inout CGFloat, margin: CGFloat) {
        let versionBox = NSBox(frame: NSRect(x: margin, y: yPos - 50, width: contentView.bounds.width - 2 * margin, height: 50))
        versionBox.title = "版本信息"
        versionBox.boxType = .primary
        versionBox.cornerRadius = 8
        versionBox.fillColor = getContainerBackgroundColor()
        versionBox.borderColor = getContainerBorderColor()
        contentView.addSubview(versionBox)
        
        let versionString = getAppVersion()
        let versionLabel = NSTextField(labelWithString: "当前版本：\(versionString)")
        versionLabel.frame = NSRect(x: 15, y: 8, width: 300, height: 20)
        versionLabel.font = NSFont.systemFont(ofSize: 14)
        versionLabel.textColor = .labelColor
        versionLabel.isBordered = false
        versionLabel.isEditable = false
        versionLabel.backgroundColor = .clear
        versionBox.addSubview(versionLabel)
        
        yPos -= 70
    }
    
    private func setupThemeSection(contentView: NSView, yPos: inout CGFloat, margin: CGFloat) {
        let themeBox = NSBox(frame: NSRect(x: margin, y: yPos - 80, width: contentView.bounds.width - 2 * margin, height: 80))
        themeBox.title = "主题设置"
        themeBox.boxType = .primary
        themeBox.cornerRadius = 8
        themeBox.fillColor = getContainerBackgroundColor()
        themeBox.borderColor = getContainerBorderColor()
        contentView.addSubview(themeBox)
        
        let themeLabel = NSTextField(labelWithString: "主题模式：")
        themeLabel.frame = NSRect(x: 15, y: 40, width: 80, height: 20)
        themeLabel.font = NSFont.systemFont(ofSize: 14)
        themeLabel.textColor = .labelColor
        themeLabel.isBordered = false
        themeLabel.isEditable = false
        themeLabel.backgroundColor = .clear
        themeBox.addSubview(themeLabel)
        
        let themePopup = NSPopUpButton(frame: NSRect(x: 100, y: 38, width: 150, height: 24))
        for mode in ThemeMode.allCases {
            themePopup.addItem(withTitle: mode.displayName)
            themePopup.lastItem?.representedObject = mode
        }
        themePopup.selectItem(withTitle: currentThemeMode.displayName)
        themePopup.target = self
        themePopup.action = #selector(themeChanged(_:))
        themeBox.addSubview(themePopup)
        
        let themeDescLabel = NSTextField(labelWithString: "选择应用的主题模式，跟随系统会根据系统设置自动切换")
        themeDescLabel.frame = NSRect(x: 15, y: 8, width: 400, height: 20)
        themeDescLabel.font = NSFont.systemFont(ofSize: 12)
        themeDescLabel.textColor = .secondaryLabelColor
        themeDescLabel.isBordered = false
        themeDescLabel.isEditable = false
        themeDescLabel.backgroundColor = .clear
        themeBox.addSubview(themeDescLabel)
        
        yPos -= 100
    }
    
    private func setupHotKeySection(contentView: NSView, yPos: inout CGFloat, margin: CGFloat) {
        let hotKeyBox = NSBox(frame: NSRect(x: margin, y: yPos - 100, width: contentView.bounds.width - 2 * margin, height: 100))
        hotKeyBox.title = "全局快捷键"
        hotKeyBox.boxType = .primary
        hotKeyBox.cornerRadius = 8
        hotKeyBox.fillColor = getContainerBackgroundColor()
        hotKeyBox.borderColor = getContainerBorderColor()
        contentView.addSubview(hotKeyBox)
        
        let hotKeyLabel = NSTextField(labelWithString: "截图快捷键：")
        hotKeyLabel.frame = NSRect(x: 15, y: 60, width: 100, height: 20)
        hotKeyLabel.font = NSFont.systemFont(ofSize: 14)
        hotKeyLabel.textColor = .labelColor
        hotKeyLabel.isBordered = false
        hotKeyLabel.isEditable = false
        hotKeyLabel.backgroundColor = .clear
        hotKeyBox.addSubview(hotKeyLabel)
        
        let hotKeyDisplay = NSTextField(labelWithString: "Ctrl + Shift + 空格")
        hotKeyDisplay.frame = NSRect(x: 120, y: 60, width: 200, height: 20)
        hotKeyDisplay.font = NSFont.systemFont(ofSize: 14)
        hotKeyDisplay.textColor = .systemBlue
        hotKeyDisplay.isBordered = false
        hotKeyDisplay.isEditable = false
        hotKeyDisplay.backgroundColor = .clear
        hotKeyBox.addSubview(hotKeyDisplay)
        
        let enableHotKeyCheckbox = NSButton(checkboxWithTitle: "启用全局截图快捷键", target: self, action: #selector(toggleHotKey(_:)))
        enableHotKeyCheckbox.frame = NSRect(x: 15, y: 35, width: 200, height: 20)
        enableHotKeyCheckbox.state = (globalHotKey != nil || localHotKey != nil) ? .on : .off
        hotKeyBox.addSubview(enableHotKeyCheckbox)
        
        // 添加测试按钮
        let testButton = NSButton(title: "测试截图", target: self, action: #selector(testScreenshot))
        testButton.frame = NSRect(x: 220, y: 33, width: 80, height: 24)
        testButton.bezelStyle = .rounded
        hotKeyBox.addSubview(testButton)
        
        // 添加权限检查按钮
        let checkPermButton = NSButton(title: "检查权限", target: self, action: #selector(checkHotKeyPermissions))
        checkPermButton.frame = NSRect(x: 310, y: 33, width: 80, height: 24)
        checkPermButton.bezelStyle = .rounded
        hotKeyBox.addSubview(checkPermButton)
        
        let hotKeyDescLabel = NSTextField(labelWithString: "按下快捷键后会截取屏幕并通过WebSocket发送到客户端")
        hotKeyDescLabel.frame = NSRect(x: 15, y: 8, width: 400, height: 20)
        hotKeyDescLabel.font = NSFont.systemFont(ofSize: 12)
        hotKeyDescLabel.textColor = .secondaryLabelColor
        hotKeyDescLabel.isBordered = false
        hotKeyDescLabel.isEditable = false
        hotKeyDescLabel.backgroundColor = .clear
        hotKeyBox.addSubview(hotKeyDescLabel)
        
        yPos -= 120
    }
    
    private func setupPermissionSection(contentView: NSView, yPos: inout CGFloat, margin: CGFloat) {
        let permissionBox = NSBox(frame: NSRect(x: margin, y: yPos - 80, width: contentView.bounds.width - 2 * margin, height: 80))
        permissionBox.title = "权限设置"
        permissionBox.boxType = .primary
        permissionBox.cornerRadius = 8
        permissionBox.fillColor = getContainerBackgroundColor()
        permissionBox.borderColor = getContainerBorderColor()
        contentView.addSubview(permissionBox)
        
        let checkPermissionButton = NSButton(title: "检查权限状态", target: self, action: #selector(checkAndRequestPermissions))
        checkPermissionButton.frame = NSRect(x: 15, y: 35, width: 120, height: 24)
        checkPermissionButton.bezelStyle = .rounded
        permissionBox.addSubview(checkPermissionButton)
        
        let openSystemSettingsButton = NSButton(title: "打开系统设置", target: self, action: #selector(openSystemPreferences))
        openSystemSettingsButton.frame = NSRect(x: 150, y: 35, width: 120, height: 24)
        openSystemSettingsButton.bezelStyle = .rounded
        permissionBox.addSubview(openSystemSettingsButton)
        
        let permissionDescLabel = NSTextField(labelWithString: "管理麦克风和屏幕录制权限")
        permissionDescLabel.frame = NSRect(x: 15, y: 8, width: 400, height: 20)
        permissionDescLabel.font = NSFont.systemFont(ofSize: 12)
        permissionDescLabel.textColor = .secondaryLabelColor
        permissionDescLabel.isBordered = false
        permissionDescLabel.isEditable = false
        permissionDescLabel.backgroundColor = .clear
        permissionBox.addSubview(permissionDescLabel)
    }
    
    // MARK: - 版本信息
    private func getAppVersion() -> String {
        if let infoDictionary = Bundle.main.infoDictionary {
            let version = infoDictionary["CFBundleShortVersionString"] as? String ?? "未知"
            let build = infoDictionary["CFBundleVersion"] as? String ?? "未知"
            return "\(version)+\(build)"
        }
        return "未知版本"
    }
    
    // MARK: - 主题相关
    @objc private func themeChanged(_ sender: NSPopUpButton) {
        guard let selectedItem = sender.selectedItem,
              let mode = selectedItem.representedObject as? ThemeMode else { return }
        
        currentThemeMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "themeMode")
        
        updateThemeForMode(mode)
    }
    
    private func updateThemeForMode(_ mode: ThemeMode) {
        switch mode {
        case .auto:
            // 跟随系统主题
            setupThemeObserver()
            updateTheme()
        case .light:
            forceTheme(.aqua)
        case .dark:
            forceTheme(.darkAqua)
        }
    }
    
    private func forceTheme(_ appearance: NSAppearance.Name) {
        if #available(macOS 10.14, *) {
            window?.appearance = NSAppearance(named: appearance)
            settingsWindow?.appearance = NSAppearance(named: appearance)
            permissionWindow?.appearance = NSAppearance(named: appearance)
        }
        updateTheme()
    }
    
    private var isDarkModeForced: Bool {
        switch currentThemeMode {
        case .dark: return true
        case .light: return false
        case .auto: return isDarkMode
        }
    }
    
    // MARK: - 全局快捷键
    @objc private func toggleHotKey(_ sender: NSButton) {
        if sender.state == .on {
            setupGlobalHotKey()
        } else {
            removeGlobalHotKey()
        }
    }
    
    private func setupGlobalHotKey() {
        removeGlobalHotKey() // 先移除现有的
        
        print("🔧 开始设置全局快捷键...")
        
        // 检查辅助功能权限
        let hasAccessibility = checkAccessibilityPermission()
        print("🔐 辅助功能权限状态: \(hasAccessibility ? "已授予" : "未授予")")
        
        if !hasAccessibility {
            print("❌ 需要辅助功能权限才能设置全局快捷键")
            requestAccessibilityPermission()
            return
        }
        
        let keyEventHandler: (NSEvent) -> Void = { [weak self] event in
            guard let self = self else { return }
            
            // 调试：打印所有按键事件
            print("🎹 按键事件: 键码=\(event.keyCode), 修饰键=\(event.modifierFlags.rawValue)")
            
            // 更精确的快捷键检测 (Command + Shift + Space)
            let modifierFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let expectedModifiers: NSEvent.ModifierFlags = [.command, .shift]
            
            
            if modifierFlags.contains(.command) && modifierFlags.contains(.shift) && event.keyCode == self.screenshotHotKeyCode {
                print("🎯 快捷键触发：Command + Shift + Space (键码: \(event.keyCode))")
                DispatchQueue.main.async {
                    self.handleScreenshotHotKey()
                }
            }
        }
        
        // 使用NSEvent监听全局快捷键（其他应用的事件）
        let options: NSEvent.EventTypeMask = [.keyDown]
        
        // 设置全局事件监听器
        globalHotKey = NSEvent.addGlobalMonitorForEvents(matching: options, handler: keyEventHandler)
        
        // 同时监听本地事件（自己应用的事件）
        localHotKey = NSEvent.addLocalMonitorForEvents(matching: options) { event in
            // 只处理特定的按键事件，减少对输入法的干扰
            if event.keyCode == self.screenshotHotKeyCode || 
               (event.modifierFlags.contains(.command) && event.modifierFlags.contains(.shift)) {
                keyEventHandler(event)
            }
            return event // 返回事件以继续传播
        }
        
        let globalSuccess = globalHotKey != nil
        let localSuccess = localHotKey != nil
        
        print("✅ 全局事件监听器: \(globalSuccess ? "成功" : "失败")")
        print("✅ 本地事件监听器: \(localSuccess ? "成功" : "失败")")
        
        if globalSuccess || localSuccess {
            print("✅ 全局快捷键注册成功 (Command + Shift + Space)")
            // 保存设置
            UserDefaults.standard.set(true, forKey: "hotKeyEnabled")
        } else {
            print("❌ 全局快捷键注册失败")
        }
    }
    
    private func checkAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }
    
    private func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        // 显示提示对话框
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "需要辅助功能权限"
            alert.informativeText = "为了使用全局快捷键功能，需要在系统设置中授予辅助功能权限。\n\n步骤：\n1. 系统设置 > 隐私与安全性 > 辅助功能\n2. 找到本应用并勾选\n3. 重新启动应用"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "打开系统设置")
            alert.addButton(withTitle: "稍后设置")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                self.openAccessibilitySettings()
            }
        }
    }
    
    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc private func testScreenshot() {
        print("🧪 测试截图功能...")
        handleScreenshotHotKey()
    }
    
    @objc private func checkHotKeyPermissions() {
        let hasAccessibility = checkAccessibilityPermission()
        let hasScreenRecording = checkScreenRecordingPermission()
        
        let alert = NSAlert()
        alert.messageText = "权限状态检查"
        
        var status = "权限状态：\n"
        status += "• 辅助功能权限：\(hasAccessibility ? "✅ 已授予" : "❌ 未授予")\n"
        status += "• 屏幕录制权限：\(hasScreenRecording ? "✅ 已授予" : "❌ 未授予")\n"
        status += "• 全局快捷键状态：\(globalHotKey != nil ? "✅ 已启用" : "❌ 未启用")"
        
        if !hasAccessibility {
            status += "\n\n需要辅助功能权限才能使用全局快捷键"
        }
        
        alert.informativeText = status
        alert.addButton(withTitle: "确定")
        
        if !hasAccessibility {
            alert.addButton(withTitle: "打开辅助功能设置")
        }
        
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            openAccessibilitySettings()
        }
    }
    
    private func removeGlobalHotKey() {
        if let monitor = globalHotKey {
            NSEvent.removeMonitor(monitor)
            globalHotKey = nil
            print("🗑️ 全局事件监听器已移除")
        }
        
        if let monitor = localHotKey {
            NSEvent.removeMonitor(monitor)
            localHotKey = nil
            print("🗑️ 本地事件监听器已移除")
        }
        
        UserDefaults.standard.set(false, forKey: "hotKeyEnabled")
    }
    
    private func handleScreenshotHotKey() {
        print("📸 ===== 快捷键触发，开始截图 =====")
        print("📸 当前时间: \(Date())")
        print("📸 主线程: \(Thread.isMainThread)")
        captureScreenAndSend()
    }
    
    private func captureScreenAndSend() {
        print("📸 开始截图...")
        
        Task {
            do {
                let image: NSImage
                
                if #available(macOS 14.0, *) {
                    // 使用现代的ScreenCaptureKit API
                    image = try await captureScreen()
                } else {
                    // 使用兼容的方法
                    image = captureScreenLegacy()
                }
                
                let base64String = imageToBase64(image: image)
                sendScreenshotToWebSocket(base64String: base64String)
                print("✅ 截图完成并发送")
            } catch {
                print("❌ 截图失败: \(error)")
            }
        }
    }
    
    private func captureScreenLegacy() -> NSImage {
        guard let screen = NSScreen.main else {
            print("❌ 无法获取主屏幕")
            return NSImage()
        }
        
        let rect = screen.frame
        print("📸 截图屏幕尺寸: \(rect.width)x\(rect.height)")
        
        guard let cgImage = CGWindowListCreateImage(rect, .optionOnScreenOnly, kCGNullWindowID, .nominalResolution) else {
            print("❌ 无法创建屏幕图像")
            return NSImage()
        }
        
        let nsImage = NSImage(cgImage: cgImage, size: rect.size)
        print("✅ 使用兼容方法截图成功")
        return nsImage
    }
    
    @available(macOS 12.3, *)
    private func captureScreen() async throws -> NSImage {
        
        let displays = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true).displays
        
        guard let display = displays.first else {
            throw NSError(domain: "ScreenCapture", code: 1, userInfo: [NSLocalizedDescriptionKey: "没有找到可用的显示器"])
        }
        
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.width = Int(display.width)
        configuration.height = Int(display.height)
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        
        if #available(macOS 14.0, *) {
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
            // 将 CGImage 转换为 NSImage
            let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
            return nsImage
        } else {
            // 对于 macOS 12.3-13.x，使用替代方法
            throw NSError(domain: "ScreenCapture", code: 2, userInfo: [NSLocalizedDescriptionKey: "截图功能需要 macOS 14.0 或更高版本"])
        }
    }
    
    private func imageToBase64(image: NSImage) -> String {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            return ""
        }
        
        return "data:image/jpeg;base64," + data.base64EncodedString()
    }
    
    private func sendScreenshotToWebSocket(base64String: String) {
        let clipboardEvent = ClipboardImageEvent(
            id: generateEventId(),
            payload: ClipboardImagePayload(base64: base64String),
            wsEventType: "clipboard-image-event"
        )
        
        // 发送到WebSocket
        Task {
            await sendEventToWebSockets(clipboardEvent)
        }
        
        print("📤 截图已发送到WebSocket")
    }
    
    private func generateEventId() -> String {
        return UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(21).lowercased()
    }
    
    private func sendEventToWebSockets<T: Content>(_ event: T) async {
        // 通过AudioCapture的WebSocket连接发送事件
        if #available(macOS 12.3, *) {
            let audioCapture = AudioCapture.shared
            await audioCapture.sendScreenshotEvent(event)
        }
    }
    
    // MARK: - 初始化设置
    private func loadUserPreferences() {
        print("🔧 加载用户偏好设置...")
        
        // 加载主题设置
        let themeString = UserDefaults.standard.string(forKey: "themeMode") ?? ThemeMode.auto.rawValue
        currentThemeMode = ThemeMode(rawValue: themeString) ?? .auto
        print("🎨 主题模式: \(currentThemeMode.displayName)")
        
        // 检查快捷键设置，默认启用
        let hasHotKeyPreference = UserDefaults.standard.object(forKey: "hotKeyEnabled") != nil
        let hotKeyEnabled = hasHotKeyPreference ? UserDefaults.standard.bool(forKey: "hotKeyEnabled") : true
        
        print("🎯 快捷键设置: \(hotKeyEnabled ? "启用" : "禁用") (是否有保存的偏好: \(hasHotKeyPreference))")
        
        if hotKeyEnabled {
            // 立即设置快捷键，确保在GUI初始化完成后
            DispatchQueue.main.async {
                self.setupGlobalHotKey()
            }
        }
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
                // 获取所有网络接口并显示
                let networkIPs = getNetworkInterfaces()
                let primaryIP = networkIPs.first ?? "127.0.0.1"
                let additionalCount = max(0, networkIPs.count - 1)
                
                if additionalCount > 0 {
                    self.statusInfoLabel.stringValue = "✅ 服务已启动！主要地址: http://\(primaryIP):9047 (共\(networkIPs.count)个地址)"
                } else {
                    self.statusInfoLabel.stringValue = "✅ 服务已启动！连接地址: http://\(primaryIP):9047"
                }
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
        // 获取真实的麦克风音频级别
        var audioLevel: Float = 0.0
        if #available(macOS 12.3, *) {
            audioLevel = AudioCapture.shared.getCurrentMicrophoneLevel()
        }
        
        // 应用音频级别的缩放和阈值
        let scaledLevel = min(max(audioLevel * 10.0, 0.0), 1.0) // 放大10倍并限制在0-1范围
        currentMicrophoneLevel = scaledLevel
        
        for (index, barView) in microphoneBarViews.enumerated() {
            // 为每个条形图设置不同的阈值
            let threshold: Float = Float(index) * 0.3 + 0.1
            
            let shouldAnimate = scaledLevel > threshold
            let targetHeight: CGFloat = shouldAnimate ? CGFloat(scaledLevel * 24.0) : 2.0
            
            // 平滑动画
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.1)
            
            barView.frame.size.height = max(2, targetHeight)
            barView.frame.origin.y = 24 - barView.frame.size.height
            
            // 根据音量改变颜色强度
            let intensity = CGFloat(scaledLevel)
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
        // 获取真实的系统音频级别
        var audioLevel: Float = 0.0
        if #available(macOS 12.3, *) {
            audioLevel = AudioCapture.shared.getCurrentSystemAudioLevel()
        }
        
        // 应用音频级别的缩放和阈值
        let scaledLevel = min(max(audioLevel * 10.0, 0.0), 1.0) // 放大10倍并限制在0-1范围
        currentSystemAudioLevel = scaledLevel
        
        for (index, barView) in systemAudioBarViews.enumerated() {
            // 为每个条形图设置不同的阈值
            let threshold: Float = Float(index) * 0.3 + 0.1
            
            let shouldAnimate = scaledLevel > threshold
            let targetHeight: CGFloat = shouldAnimate ? CGFloat(scaledLevel * 24.0) : 2.0
            
            // 平滑动画
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.1)
            
            barView.frame.size.height = max(2, targetHeight)
            barView.frame.origin.y = 24 - barView.frame.size.height
            
            // 根据音量改变颜色强度
            let intensity = CGFloat(scaledLevel)
            let orangeColor = NSColor(red: 1.0, green: 0.5 + intensity * 0.3, blue: 0, alpha: 0.8 + intensity * 0.2)
            barView.layer?.backgroundColor = orangeColor.cgColor
            
            CATransaction.commit()
        }
    }
    
    // MARK: - 剪贴板监听
    private func startClipboardMonitoring() {
        // 初始化剪贴板内容
        lastClipboardContent = getCurrentClipboardText()
        
        // 每0.5秒检查一次剪贴板变化
        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboardChange()
        }
        
        print("📋 剪贴板监听已启动")
    }
    
    private func stopClipboardMonitoring() {
        clipboardTimer?.invalidate()
        clipboardTimer = nil
        print("📋 剪贴板监听已停止")
    }
    
    private func getCurrentClipboardText() -> String {
        let pasteboard = NSPasteboard.general
        return pasteboard.string(forType: .string) ?? ""
    }
    
    private func checkClipboardChange() {
        let currentContent = getCurrentClipboardText()
        
        // 检查内容是否发生变化且不为空
        if !currentContent.isEmpty && currentContent != lastClipboardContent {
            lastClipboardContent = currentContent
            
            // 发送剪贴板变化事件到所有WebSocket连接
            sendClipboardTextEvent(text: currentContent)
        }
    }
    
    private func sendClipboardTextEvent(text: String) {
        guard !text.isEmpty else { return }
        
        let event = ClipboardTextEvent(
            id: generateResponseId(),
            payload: ClipboardTextPayload(text: text),
            type: "clipboard-text-event",
            wsEventType: "clipboard-text-event"
        )
        
        // 通过AudioCapture发送到所有WebSocket连接
        if #available(macOS 12.3, *) {
            Task {
                await AudioCapture.shared.sendClipboardEvent(event)
            }
        }
        
        print("📋 发送剪贴板文本事件，长度: \(text.count) 字符")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("🛑 应用即将退出，清理资源...")
        
        // 停止剪贴板监听
        stopClipboardMonitoring()
        
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

// MARK: - NSWindowDelegate
extension AudioServerApp: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // 如果是权限窗口且权限未完全获得，不允许关闭
        if sender == permissionWindow && isShowingPermissionScreen {
            let microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
            let screenRecordingGranted = checkScreenRecordingPermission()
            
            if microphoneStatus != .authorized || !screenRecordingGranted {
                let alert = NSAlert()
                alert.messageText = "需要权限才能继续"
                alert.informativeText = "请先授权必要的权限（麦克风权限和屏幕录制权限），否则应用无法正常工作。"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "继续授权")
                alert.addButton(withTitle: "退出应用")
                
                let response = alert.runModal()
                if response == .alertSecondButtonReturn {
                    NSApplication.shared.terminate(nil)
                }
                return false
            }
        }
        return true
    }
}

// MARK: - Vapor配置函数
func configure(_ app: Application) async throws {
    // 配置CORS
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent, .accessControlAllowOrigin]
    )
    let cors = CORSMiddleware(configuration: corsConfiguration)
    app.middleware.use(cors, at: .beginning)
    
    // 注册路由
    try routes(app)
}

func routes(_ app: Application) throws {
    // 健康检查
    app.get("health") { req -> HealthResponse in
        return HealthResponse(
            data: HealthData(ok: true),
            success: true
        )
    }
    
    // 配置信息
    app.get("config") { req -> ConfigResponse in
        return ConfigResponse(
            data: ConfigData(
                audioConfig: AudioConfig(
                    bufferDurationMs: 50.0,
                    sampleRate: 16000.0
                ),
                deviceInfo: DeviceInfo(
                    build: "15",
                    id: getDeviceId(),
                    name: getDeviceName(),
                    platform: "macos",
                    version: "2.1.0"
                )
            ),
            success: true
        )
    }
    
    // WebSocket连接 - 兼容多个路径
    let websocketHandler: @Sendable (Request, WebSocket) async -> Void = { req, ws in
        print("🔗 新的WebSocket连接")
        
        if #available(macOS 12.3, *) {
            await AudioCapture.shared.addWebSocket(ws)
        }
        
        // 发送欢迎消息
        try? await ws.send("Connected to Audio Capture Service")
        
        ws.onClose.whenComplete { result in
            print("🔌 WebSocket连接已关闭")
            if #available(macOS 12.3, *) {
                Task {
                    await AudioCapture.shared.removeWebSocket(ws)
                }
            }
        }
        
        // 在WebSocket的事件循环中设置文本消息处理器
        ws.eventLoop.execute {
            ws.onText { ws, text in
                Task {
                    await handleWebSocketMessage(ws: ws, text: text)
                }
            }
        }
    }
    
    // 支持多个WebSocket路径
    app.webSocket("audio", onUpgrade: websocketHandler)
    app.webSocket("ws", onUpgrade: websocketHandler)
    
    // 基本状态检查路由
    app.get { req -> String in
        return "Interesting Lab Audio Service is running!"
    }
}

// 处理WebSocket消息
func handleWebSocketMessage(ws: WebSocket, text: String) async {
    guard !text.isEmpty else { return }
    
    let decoder = JSONDecoder()
    guard let data = text.data(using: .utf8) else {
        print("❌ 无法将消息转换为数据")
        return
    }
    
    // 尝试解析为截图命令
    if let command = try? decoder.decode(ScreenshotCommand.self, from: data) {
        if command.type == "client-screenshot-command" && command.wsEventType == "client-screenshot-command" {
            print("📸 收到截图命令，ID: \(command.id)")
            // 直接处理截图命令
            await handleScreenshotCommand(ws: ws, commandId: command.id)
            return
        }
    }
    
    print("📨 收到未知WebSocket消息: \(text.prefix(100))...")
}

// 处理截图命令
func handleScreenshotCommand(ws: WebSocket, commandId: String) async {
    do {
        print("📸 开始处理截图命令...")
        
        // 检查WebSocket是否仍然连接
        guard !ws.isClosed else {
            print("❌ WebSocket已关闭，取消截图")
            return
        }
        
        let screenshot = await captureScreenshot()
        
        // 再次检查WebSocket状态
        guard !ws.isClosed else {
            print("❌ WebSocket已关闭，取消发送截图")
            return
        }
        
        let response = ScreenshotResponse(
            id: generateResponseId(),
            payload: ScreenshotPayload(base64: screenshot),
            wsEventType: "clipboard-image-event"
        )
        
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(response)
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            try await ws.send(jsonString)
            print("📸 截图已发送，响应ID: \(response.id)，大小: \(jsonString.count) 字符")
        }
    } catch {
        print("❌ 截图处理失败: \(error)")
        // 发送错误响应
        do {
            let errorResponse = ScreenshotResponse(
                id: generateResponseId(),
                payload: ScreenshotPayload(base64: "data:image/jpeg;base64,"),
                wsEventType: "clipboard-image-event"
            )
            let encoder = JSONEncoder()
            let jsonData = try encoder.encode(errorResponse)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                try await ws.send(jsonString)
            }
        } catch {
            print("❌ 发送错误响应失败: \(error)")
        }
    }
}

// 捕获屏幕截图
func captureScreenshot() async -> String {
    return await withCheckedContinuation { continuation in
        // 使用全局队列而不是主队列，避免阻塞UI
        DispatchQueue.global(qos: .userInitiated).async {
            autoreleasepool {
                guard let screen = NSScreen.main else {
                    print("❌ 无法获取主屏幕")
                    continuation.resume(returning: "data:image/jpeg;base64,")
                    return
                }
                
                let rect = screen.frame
                print("📸 开始截图，屏幕尺寸: \(rect.width)x\(rect.height)")
                
                guard let cgImage = CGWindowListCreateImage(rect, .optionOnScreenOnly, kCGNullWindowID, .nominalResolution) else {
                    print("❌ 无法创建屏幕图像")
                    continuation.resume(returning: "data:image/jpeg;base64,")
                    return
                }
                
                let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
                
                // 使用较低的压缩质量以减少内存使用
                guard let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.6]) else {
                    print("❌ 无法生成JPEG数据")
                    continuation.resume(returning: "data:image/jpeg;base64,")
                    return
                }
                
                print("📸 截图完成，JPEG大小: \(jpegData.count) 字节")
                
                let base64String = jpegData.base64EncodedString()
                continuation.resume(returning: "data:image/jpeg;base64,\(base64String)")
            }
        }
    }
}

// 生成响应ID
func generateResponseId() -> String {
    let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    let length = 17
    return String((0..<length).map { _ in characters.randomElement()! })
}

func getDeviceId() -> String {
    if #available(macOS 12.0, *) {
        // 使用较新的API
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        defer { IOObjectRelease(service) }
        
        if let serialNumber = IORegistryEntryCreateCFProperty(service, kIOPlatformSerialNumberKey as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String {
            return serialNumber
        }
    } else {
        // 较旧版本的兼容性代码
        let service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        defer { IOObjectRelease(service) }
        
        if let serialNumber = IORegistryEntryCreateCFProperty(service, kIOPlatformSerialNumberKey as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String {
            return serialNumber
        }
    }
    
    return "unknown-device"
}

func getDeviceName() -> String {
    let host = ProcessInfo.processInfo.hostName
    return host.isEmpty ? "Unknown Mac" : host
}

func getNetworkInterfaces() -> [String] {
    var addresses: [String] = []
    
    // 获取所有网络接口
    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0 else { return ["127.0.0.1"] }
    guard let firstAddr = ifaddr else { return ["127.0.0.1"] }
    
    defer { freeifaddrs(ifaddr) }
    
    // 需要排除的网络接口前缀
    let excludedPrefixes = [
        "127.",      // 本地回环
        "169.254.",  // 链路本地地址
        "198.18.",   // 测试网络
        "10.43.",    // 常见的虚拟网卡
        "10.8.",     // VPN网卡
        "172.17.",   // Docker网络
        "172.18.",   // Docker网络
        "172.19.",   // Docker网络
        "172.20.",   // Docker网络
    ]
    
    for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
        let interface = ptr.pointee
        
        // 获取接口名称
        let interfaceName = String(cString: interface.ifa_name)
        
        // 排除虚拟接口
        let excludedInterfaces = ["lo", "utun", "awdl", "llw", "bridge", "vnic", "anpi"]
        if excludedInterfaces.contains(where: { interfaceName.hasPrefix($0) }) {
            continue
        }
        
        // 检查地址族，只处理IPv4地址
        let addrFamily = interface.ifa_addr.pointee.sa_family
        if addrFamily == UInt8(AF_INET) {
            
            // 检查接口是否激活且不是回环接口
            let flags = interface.ifa_flags
            if (flags & UInt32(IFF_UP)) != 0 && (flags & UInt32(IFF_RUNNING)) != 0 && (flags & UInt32(IFF_LOOPBACK)) == 0 {
                
                // 转换地址
                let addr = interface.ifa_addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr }
                let ip = String(cString: inet_ntoa(addr))
                
                // 检查是否需要排除的IP地址
                let shouldExclude = excludedPrefixes.contains { ip.hasPrefix($0) }
                
                if !shouldExclude {
                    addresses.append(ip)
                }
            }
        }
    }
    
    // 如果没有找到有效地址，添加localhost作为备用
    if addresses.isEmpty {
        addresses.append("127.0.0.1")
    }
    
    // 对地址进行排序，优先显示最有用的地址
    addresses.sort { ip1, ip2 in
        // WiFi网络 (192.168.x.x) 优先级最高
        if ip1.hasPrefix("192.168.") && !ip2.hasPrefix("192.168.") {
            return true
        }
        if !ip1.hasPrefix("192.168.") && ip2.hasPrefix("192.168.") {
            return false
        }
        
        // 其他私有网络地址次之
        if ip1.hasPrefix("10.") && !ip2.hasPrefix("10.") {
            return true
        }
        if !ip1.hasPrefix("10.") && ip2.hasPrefix("10.") {
            return false
        }
        
        // 172.x.x.x 网络
        if ip1.hasPrefix("172.") && !ip2.hasPrefix("172.") {
            return true
        }
        if !ip1.hasPrefix("172.") && ip2.hasPrefix("172.") {
            return false
        }
        
        // 默认按字典序排序
        return ip1 < ip2
    }
    
    return addresses
} 