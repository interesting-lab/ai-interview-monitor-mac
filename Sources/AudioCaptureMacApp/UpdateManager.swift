import Foundation
import Cocoa
import Vapor

// MARK: - 更新相关数据结构
struct UpdateInfo: Codable {
    let version: String
    let downloadUrl: String
    let releaseNotes: [String]
    let releaseNotesText: String
    let isForceUpdate: Bool
    let isCritical: Bool
    let releaseDate: String
    let platform: String
    let fileSizeMB: Double
    let language: String
}

struct UpdateCheckResponse: Codable {
    let hasUpdate: Bool
    let updateInfo: UpdateInfo?
    let currentVersion: String
    let latestVersion: String
    let platform: String
    let checkTime: String
}

// MARK: - 更新管理器
class UpdateManager: ObservableObject {
    static let shared = UpdateManager()
    
    @Published var hasUpdate = false
    @Published var updateInfo: UpdateInfo?
    @Published var isChecking = false
    
    private let currentVersion: String
    private let updateCheckURL = UpdateConfig.updateCheckURL
    private let updateCheckInterval: TimeInterval = UpdateConfig.updateCheckInterval
    
    private init() {
        // 从Info.plist获取当前版本
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            self.currentVersion = version
        } else {
            self.currentVersion = "1.0.0"
        }
        
        // 启动定时检查
        startPeriodicUpdateCheck()
    }
    
    // MARK: - 公共方法
    
    /// 手动检查更新
    func checkForUpdates() async {
        await MainActor.run {
            isChecking = true
        }
        
        do {
            let response = try await performUpdateCheck()
            
            await MainActor.run {
                self.hasUpdate = response.hasUpdate
                self.updateInfo = response.updateInfo
                self.isChecking = false
                
                if response.hasUpdate {
                    self.showUpdateNotification()
                }
            }
        } catch {
            print("更新检查失败: \(error)")
            await MainActor.run {
                self.isChecking = false
            }
        }
    }
    
    /// 下载并安装更新
    func downloadAndInstallUpdate() async {
        guard let updateInfo = updateInfo else { return }
        
        do {
            // 显示下载进度
            await showDownloadProgress()
            
            // 下载更新文件
            let downloadPath = try await downloadUpdateFile(from: updateInfo.downloadUrl)
            
            // 验证下载文件
            try await validateDownloadedFile(at: downloadPath)
            
            // 安装更新
            try await installUpdate(from: downloadPath)
            
            // 显示安装完成提示
            await showInstallationComplete()
            
        } catch {
            print("更新安装失败: \(error)")
            await showUpdateError(error)
        }
    }
    
    // MARK: - 私有方法
    
    private func startPeriodicUpdateCheck() {
        guard UpdateConfig.enableAutoUpdateCheck else { return }
        
        Task {
            while true {
                // 检查用户偏好设置
                if UpdatePreferences.shared.shouldCheckForUpdates() {
                    await checkForUpdates()
                    UpdatePreferences.shared.updateLastCheckTime()
                }
                try await Task.sleep(nanoseconds: UInt64(updateCheckInterval * 1_000_000_000))
            }
        }
    }
    
    private func performUpdateCheck() async throws -> UpdateCheckResponse {
        // 构建请求URL
        var components = URLComponents(string: updateCheckURL)!
        components.queryItems = [
            URLQueryItem(name: "version", value: currentVersion),
            URLQueryItem(name: "platform", value: "macOS"),
            URLQueryItem(name: "build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
        ]
        
        guard let url = components.url else {
            throw UpdateError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = UpdateConfig.downloadTimeout
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw UpdateError.networkError
        }
        
        let updateResponse = try JSONDecoder().decode(UpdateCheckResponse.self, from: data)
        
        // 检查是否被忽略的版本
        if let updateInfo = updateResponse.updateInfo,
           UpdatePreferences.shared.isVersionIgnored(updateInfo.version) {
            // 返回没有更新的响应
            return UpdateCheckResponse(
                hasUpdate: false,
                updateInfo: nil,
                currentVersion: updateResponse.currentVersion,
                latestVersion: updateResponse.latestVersion,
                platform: updateResponse.platform,
                checkTime: updateResponse.checkTime
            )
        }
        
        return updateResponse
    }
    
    private func downloadUpdateFile(from urlString: String) async throws -> String {
        guard let url = URL(string: urlString) else {
            throw UpdateError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw UpdateError.downloadFailed
        }
        
        // 保存到临时目录
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "update_\(currentVersion)_\(updateInfo?.version ?? "latest").dmg"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        try data.write(to: fileURL)
        return fileURL.path
    }
    
    private func validateDownloadedFile(at path: String) async throws {
        guard UpdateConfig.enableFileValidation else { return }
        
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: path) else {
            throw UpdateError.fileNotFound
        }
        
        let attributes = try fileManager.attributesOfItem(atPath: path)
        guard let fileSize = attributes[.size] as? Int64,
              fileSize > 0 else {
            throw UpdateError.invalidFile
        }
        
        // 这里可以添加更多验证逻辑，如校验和验证
        // 例如：MD5、SHA256等
    }
    
    private func installUpdate(from path: String) async throws {
        // 挂载DMG文件
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["attach", path, "-mountpoint", "/Volumes/Update"]
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw UpdateError.mountFailed
        }
        
        // 查找应用程序
        let mountPoint = "/Volumes/Update"
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(atPath: mountPoint)
        
        guard let appName = contents.first(where: { $0.hasSuffix(".app") }) else {
            throw UpdateError.appNotFound
        }
        
        let appPath = "\(mountPoint)/\(appName)"
        let destinationPath = "/Applications/\(appName)"
        
        // 复制应用程序
        try fileManager.removeItem(atPath: destinationPath)
        try fileManager.copyItem(atPath: appPath, toPath: destinationPath)
        
        // 卸载DMG
        let unmountProcess = Process()
        unmountProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        unmountProcess.arguments = ["detach", mountPoint]
        
        try unmountProcess.run()
        unmountProcess.waitUntilExit()
        
        // 删除临时文件
        try fileManager.removeItem(atPath: path)
    }
    
    // MARK: - UI 相关方法
    
    private func showUpdateNotification() {
        guard UpdateConfig.showUpdateNotifications else { return }
        
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "发现新版本 \(self.updateInfo?.version ?? "")"
            
            // 构建详细的更新信息
            var infoText = "新版本已可用！\n\n"
            
            if let updateInfo = self.updateInfo {
                infoText += "📱 版本: \(updateInfo.version)\n"
                infoText += "📅 发布日期: \(updateInfo.releaseDate)\n"
                
                if UpdateConfig.showFileSizeInNotification {
                    infoText += "📦 文件大小: \(String(format: "%.1f", updateInfo.fileSizeMB)) MB\n"
                }
                
                infoText += "🌐 语言: \(updateInfo.language)\n\n"
                
                if UpdateConfig.showDetailedUpdateInfo && !updateInfo.releaseNotes.isEmpty {
                    infoText += "🆕 更新内容:\n"
                    for note in updateInfo.releaseNotes {
                        infoText += "• \(note)\n"
                    }
                    infoText += "\n"
                }
                
                if updateInfo.isForceUpdate {
                    infoText += "⚠️ 这是一个强制更新版本\n"
                }
                
                if updateInfo.isCritical {
                    infoText += "🚨 这是一个关键安全更新\n"
                }
            }
            
            infoText += "\n是否现在更新？"
            
            alert.informativeText = infoText
            alert.alertStyle = .informational
            alert.addButton(withTitle: "立即更新")
            alert.addButton(withTitle: "稍后提醒")
            alert.addButton(withTitle: "忽略此版本")
            
            let response = alert.runModal()
            
            switch response {
            case .alertFirstButtonReturn:
                Task {
                    await self.downloadAndInstallUpdate()
                }
            case .alertSecondButtonReturn:
                // 1小时后再次提醒
                DispatchQueue.main.asyncAfter(deadline: .now() + 3600) {
                    self.showUpdateNotification()
                }
            case .alertThirdButtonReturn:
                // 忽略此版本
                if let version = self.updateInfo?.version {
                    UpdatePreferences.shared.ignoreVersion(version)
                }
            default:
                break
            }
        }
    }
    
    private func showDownloadProgress() async {
        await MainActor.run {
            let alert = NSAlert()
            alert.messageText = "正在下载更新"
            
            var infoText = "请稍候，正在下载新版本..."
            if let updateInfo = self.updateInfo {
                infoText += "\n\n📱 版本: \(updateInfo.version)"
                
                if UpdateConfig.showFileSizeInNotification {
                    infoText += "\n📦 文件大小: \(String(format: "%.1f", updateInfo.fileSizeMB)) MB"
                }
                
                if UpdateConfig.showDownloadUrlInNotification {
                    infoText += "\n🌐 下载地址: \(updateInfo.downloadUrl)"
                }
            }
            
            alert.informativeText = infoText
            alert.alertStyle = .informational
            
            // 显示进度条
            let progressIndicator = NSProgressIndicator()
            progressIndicator.isIndeterminate = true
            progressIndicator.startAnimation(nil)
            
            alert.accessoryView = progressIndicator
            alert.runModal()
        }
    }
    
    private func showInstallationComplete() async {
        await MainActor.run {
            let alert = NSAlert()
            alert.messageText = "更新完成"
            alert.informativeText = "新版本已安装完成，需要重启应用程序。"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "立即重启")
            alert.addButton(withTitle: "稍后重启")
            
            let response = alert.runModal()
            
            if response == .alertFirstButtonReturn {
                // 重启应用程序
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }
    
    private func showUpdateError(_ error: Error) async {
        await MainActor.run {
            let alert = NSAlert()
            alert.messageText = "更新失败"
            alert.informativeText = "更新过程中发生错误：\(error.localizedDescription)"
            alert.alertStyle = .critical
            alert.addButton(withTitle: "确定")
            alert.runModal()
        }
    }
}

// MARK: - 错误类型
enum UpdateError: Error, LocalizedError {
    case invalidURL
    case networkError
    case downloadFailed
    case fileNotFound
    case invalidFile
    case mountFailed
    case appNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的URL地址"
        case .networkError:
            return "网络连接错误"
        case .downloadFailed:
            return "下载失败"
        case .fileNotFound:
            return "文件未找到"
        case .invalidFile:
            return "文件无效"
        case .mountFailed:
            return "挂载失败"
        case .appNotFound:
            return "应用程序未找到"
        }
    }
}
