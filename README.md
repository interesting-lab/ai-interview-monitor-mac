# Interesting Lab - 音频捕获应用

一个支持麦克风和系统音频捕获的macOS应用程序，具有现代化的用户界面和完整的权限管理。

## ✨ 主要功能

- 🎤 麦克风音频捕获
- 🖥️ 系统音频捕获 
- 🎨 动态主题切换（跟随系统深色/浅色模式）
- 🔐 完整的权限管理系统
- 🌐 WebSocket音频转发服务
- 📊 实时音频可视化

## 🛠️ 构建应用

### 方法1：使用构建脚本（推荐）

```bash
# 运行自动构建脚本
./build_app.sh
```

### 方法2：手动构建

```bash
# 1. 构建可执行文件
swift build -c release --arch arm64 --arch x86_64

# 2. 创建应用包
mkdir -p ".build/Interesting Lab.app/Contents/MacOS"
mkdir -p ".build/Interesting Lab.app/Contents/Resources"

# 3. 复制可执行文件
cp .build/release/InterestingLab ".build/Interesting Lab.app/Contents/MacOS/"

# 4. 复制Info.plist
cp Sources/AudioCaptureMacApp/Info.plist ".build/Interesting Lab.app/Contents/"

# 5. 设置权限
chmod +x ".build/Interesting Lab.app/Contents/MacOS/InterestingLab"
```

## 🚀 运行应用

构建完成后，你可以通过以下方式运行：

```bash
# 直接打开应用
open ".build/Interesting Lab.app"

# 或者双击应用图标
```

## 🔐 权限要求

应用需要以下系统权限：

- **麦克风权限**：用于捕获用户声音输入
- **屏幕录制权限**：用于捕获系统音频输出

首次运行时，应用会自动引导用户完成权限设置。

## 🎨 主题支持

应用支持动态主题切换：

- **自动跟随系统**：支持 macOS 深色/浅色模式自动切换
- **实时响应**：系统主题变化时界面立即更新
- **完整适配**：所有UI元素都支持主题切换

## 📦 分发应用

如果需要分发给其他用户，建议进行代码签名：

```bash
# 使用开发者证书签名
codesign --force --deep --sign "Developer ID Application: Your Name" ".build/Interesting Lab.app"

# 或使用临时签名（仅本机使用）
codesign --force --deep --sign - ".build/Interesting Lab.app"
```

## 🔧 开发环境

- **macOS**: 11.0+
- **Swift**: 5.9+
- **Xcode**: 15.0+

## 📋 依赖项

- [Vapor](https://github.com/vapor/vapor) - Web框架
- [WebSocketKit](https://github.com/vapor/websocket-kit) - WebSocket支持
- ScreenCaptureKit - 系统音频捕获（macOS内置）
- AVFoundation - 音频处理（macOS内置）

## 🐛 故障排除

### 权限问题
如果遇到权限相关问题：
1. 打开 系统设置 > 隐私与安全性
2. 检查 麦克风 和 屏幕录制 权限
3. 确保应用已被授权

### 构建问题
如果构建失败：
1. 确保已安装 Xcode Command Line Tools
2. 检查 Swift 版本：`swift --version`
3. 清理构建缓存：`swift package clean`

### 运行问题
如果应用无法启动：
1. 检查系统版本是否为 macOS 11.0+
2. 尝试从终端运行查看错误信息
3. 检查应用签名状态

## 📄 许可证

本项目仅供学习和研究使用。

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！ 