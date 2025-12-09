// 生产环境配置示例
// 将此文件重命名为 UpdateConfig.swift 并替换现有配置

import Foundation

// MARK: - 更新配置
struct UpdateConfig {
    // 更新检查的API地址 - 生产环境
    static let updateCheckURL = "https://api.shiwen-ai.com/api/updates/check"
    
    // 更新检查间隔（秒）
    static let updateCheckInterval: TimeInterval = 3600 // 1小时
    
    // 是否启用自动更新检查
    static let enableAutoUpdateCheck = true
    
    // 是否在启动时检查更新
    static let checkOnLaunch = true
    
    // 是否显示更新通知
    static let showUpdateNotifications = true
    
    // 更新文件下载超时时间（秒）
    static let downloadTimeout: TimeInterval = 300 // 5分钟
    
    // 是否启用更新文件完整性验证
    static let enableFileValidation = true
    
    // 更新日志级别
    static let logLevel: UpdateLogLevel = .info
    
    // 强制更新版本（如果当前版本低于此版本，将强制更新）
    static let forceUpdateVersion = "1.0.0"
    
    // 是否显示详细的更新信息
    static let showDetailedUpdateInfo = true
    
    // 是否在更新通知中显示文件大小
    static let showFileSizeInNotification = true
    
    // 是否在更新通知中显示下载地址
    static let showDownloadUrlInNotification = false
    
    // 生产环境特定配置
    static let productionMode = true
    static let enableSSLVerification = true
    static let enableCertificatePinning = true
    static let retryCount = 3
    static let retryDelay: TimeInterval = 5 // 秒
}

// MARK: - 更新日志级别
enum UpdateLogLevel: String, CaseIterable {
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"
    
    var shouldLog: Bool {
        switch self {
        case .debug:
            return !UpdateConfig.productionMode
        case .info:
            return true
        case .warning:
            return true
        case .error:
            return true
        }
    }
}

// MARK: - 用户偏好设置
class UpdatePreferences {
    static let shared = UpdatePreferences()
    
    private let userDefaults = UserDefaults.standard
    private let updateCheckKey = "UpdateCheckEnabled"
    private let lastUpdateCheckKey = "LastUpdateCheck"
    private let ignoredVersionsKey = "IgnoredVersions"
    private let autoDownloadKey = "AutoDownloadUpdates"
    private let productionModeKey = "ProductionMode"
    
    private init() {}
    
    // 是否启用更新检查
    var isUpdateCheckEnabled: Bool {
        get {
            return userDefaults.object(forKey: updateCheckKey) as? Bool ?? true
        }
        set {
            userDefaults.set(newValue, forKey: updateCheckKey)
        }
    }
    
    // 上次更新检查时间
    var lastUpdateCheck: Date? {
        get {
            return userDefaults.object(forKey: lastUpdateCheckKey) as? Date
        }
        set {
            userDefaults.set(newValue, forKey: lastUpdateCheckKey)
        }
    }
    
    // 被忽略的版本列表
    var ignoredVersions: [String] {
        get {
            return userDefaults.stringArray(forKey: ignoredVersionsKey) ?? []
        }
        set {
            userDefaults.set(newValue, forKey: ignoredVersionsKey)
        }
    }
    
    // 是否自动下载更新
    var autoDownloadUpdates: Bool {
        get {
            return userDefaults.object(forKey: autoDownloadKey) as? Bool ?? false
        }
        set {
            userDefaults.set(newValue, forKey: autoDownloadKey)
        }
    }
    
    // 生产模式状态
    var isProductionMode: Bool {
        get {
            return userDefaults.object(forKey: productionModeKey) as? Bool ?? UpdateConfig.productionMode
        }
        set {
            userDefaults.set(newValue, forKey: productionModeKey)
        }
    }
    
    // 添加忽略的版本
    func ignoreVersion(_ version: String) {
        var versions = ignoredVersions
        if !versions.contains(version) {
            versions.append(version)
            ignoredVersions = versions
        }
    }
    
    // 移除忽略的版本
    func removeIgnoredVersion(_ version: String) {
        var versions = ignoredVersions
        versions.removeAll { $0 == version }
        ignoredVersions = versions
    }
    
    // 检查版本是否被忽略
    func isVersionIgnored(_ version: String) -> Bool {
        return ignoredVersions.contains(version)
    }
    
    // 更新最后检查时间
    func updateLastCheckTime() {
        lastUpdateCheck = Date()
    }
    
    // 检查是否需要更新检查（基于时间间隔）
    func shouldCheckForUpdates() -> Bool {
        guard isUpdateCheckEnabled else { return false }
        
        if let lastCheck = lastUpdateCheck {
            let timeSinceLastCheck = Date().timeIntervalSince(lastCheck)
            return timeSinceLastCheck >= UpdateConfig.updateCheckInterval
        }
        
        return true
    }
    
    // 重置所有设置到默认值
    func resetToDefaults() {
        isUpdateCheckEnabled = true
        lastUpdateCheck = nil
        ignoredVersions = []
        autoDownloadUpdates = false
        isProductionMode = UpdateConfig.productionMode
    }
}

