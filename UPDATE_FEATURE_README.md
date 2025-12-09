# 应用程序更新功能说明

## 功能概述

本应用程序已集成自动更新检测功能，支持：
- 自动检查更新
- 手动检查更新
- 热更新提示
- 自动下载和安装
- 用户偏好设置

## 主要组件

### 1. UpdateManager.swift
核心更新管理器，负责：
- 版本检查
- 更新下载
- 更新安装
- 用户通知

### 2. UpdateConfig.swift
更新配置管理，包含：
- API地址配置
- 检查间隔设置
- 功能开关
- 日志级别

### 3. UpdatePreferences.swift
用户偏好设置，支持：
- 启用/禁用自动检查
- 忽略特定版本
- 自动下载设置
- 检查时间记录

## 使用方法

### 自动更新检查
应用程序启动时会自动检查更新（如果配置允许），默认每小时检查一次。

### 手动检查更新
1. 在主界面点击"检查更新"按钮
2. 在状态栏菜单选择"检查更新"

### 更新提示
当检测到新版本时，会显示更新对话框，用户可以选择：
- 立即更新
- 稍后提醒
- 忽略此版本

## 配置说明

### 修改更新服务器地址
编辑 `UpdateConfig.swift` 文件中的 `updateCheckURL`：

```swift
static let updateCheckURL = "https://your-server.com/updates/check"
```

### 调整检查间隔
修改 `updateCheckInterval` 值（单位：秒）：

```swift
static let updateCheckInterval: TimeInterval = 7200 // 2小时
```

### 禁用自动检查
设置 `enableAutoUpdateCheck` 为 `false`：

```swift
static let enableAutoUpdateCheck = false
```

## 测试更新功能

### 启动测试服务器
1. 安装Python依赖：
   ```bash
   pip install -r requirements.txt
   ```

2. 启动测试服务器：
   ```bash
   python test_update_server.py
   ```

3. 服务器将在 `http://localhost:8000` 启动

### 测试更新检查
测试服务器会模拟版本检查：
- 当前版本为1.0.0时，返回有更新
- 其他版本返回无更新

## API接口格式

### 更新检查请求
```
GET /api/updates/check?version=1.0.0&platform=macOS&build=1
```

### 响应格式
```json
{
    "hasUpdate": true,
    "updateInfo": {
        "version": "1.1.0",
        "downloadUrl": "https://download.shiwen-ai.com/releases/shiwen-ai-assistant-1.1.0-macos.dmg",
        "releaseNotes": [
            "🎉 新增移动端10%顶部空白适配，优化移动浏览器体验",
            "🔧 修复了语音识别在某些设备上的兼容性问题",
            "⚡ 提升了AI回答的响应速度和准确性",
            "🐛 修复了若干已知bug，提升系统稳定性",
            "💼 优化了用户界面，提供更好的交互体验"
        ],
        "releaseNotesText": "🎉 新增移动端10%顶部空白适配，优化移动浏览器体验\n🔧 修复了语音识别在某些设备上的兼容性问题\n⚡ 提升了AI回答的响应速度和准确性\n🐛 修复了若干已知bug，提升系统稳定性\n💼 优化了用户界面，提供更好的交互体验",
        "isForceUpdate": false,
        "isCritical": false,
        "releaseDate": "2025-01-15",
        "platform": "macOS",
        "fileSizeMB": 85.2,
        "language": "zh"
    },
    "currentVersion": "1.0.0",
    "latestVersion": "1.1.0",
    "platform": "macOS",
    "checkTime": "2025-08-14T20:56:29.284849"
}
```

## 注意事项

1. **权限要求**：更新安装需要管理员权限
2. **网络连接**：确保应用程序有网络访问权限
3. **文件验证**：建议启用文件完整性验证
4. **备份数据**：更新前建议备份重要数据

## 故障排除

### 更新检查失败
- 检查网络连接
- 验证API地址是否正确
- 查看控制台日志

### 更新安装失败
- 确认有管理员权限
- 检查磁盘空间
- 验证下载文件完整性

### 权限问题
- 在系统偏好设置中检查应用程序权限
- 确保应用程序有网络和文件系统访问权限

## 开发说明

### 添加新的更新源
1. 修改 `UpdateManager.swift` 中的 `performUpdateCheck` 方法
2. 添加新的API调用逻辑
3. 更新响应数据结构

### 自定义更新流程
1. 继承 `UpdateManager` 类
2. 重写相关方法
3. 在 `GUIMain.swift` 中使用自定义管理器

### 扩展配置选项
1. 在 `UpdateConfig.swift` 中添加新配置项
2. 在 `UpdatePreferences.swift` 中添加对应的用户设置
3. 更新UI界面以支持新选项
