#!/bin/bash

# Interesting Lab 应用构建脚本
echo "🚀 开始构建 Interesting Lab.app..."

# 设置变量
APP_NAME="Interesting Lab"
EXECUTABLE_NAME="InterestingLab"
BUNDLE_ID="com.interestinglab.audioapp"
BUILD_DIR=".build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# 清理之前的构建
echo "🧹 清理之前的构建..."
rm -rf "$APP_DIR"

# 构建可执行文件
echo "🔨 构建可执行文件..."
swift build -c release

if [ $? -ne 0 ]; then
    echo "❌ 构建失败！"
    exit 1
fi

# 创建应用包结构
echo "📦 创建应用包结构..."
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# 复制可执行文件
echo "📋 复制可执行文件..."
cp ".build/release/$EXECUTABLE_NAME" "$MACOS_DIR/"

# 创建 Info.plist
echo "📄 创建 Info.plist..."
cat > "$CONTENTS_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleExecutable</key>
    <string>$EXECUTABLE_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>2.1.0</string>
    <key>CFBundleVersion</key>
    <string>15</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSRequiresAquaSystemAppearance</key>
    <false/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsLocalNetworking</key>
        <true/>
    </dict>
    <key>NSMicrophoneUsageDescription</key>
    <string>此应用需要麦克风权限来捕获您的声音输入，用于音频转发功能。</string>
    <key>NSSystemAdministrationUsageDescription</key>
    <string>此应用需要系统管理权限来捕获系统音频。</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>此应用需要控制其他应用程序来实现音频捕获功能。</string>
    <key>NSCameraUsageDescription</key>
    <string>此应用需要摄像头权限来实现屏幕录制功能。</string>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
    <key>com.apple.security.device.microphone</key>
    <true/>
    <key>com.apple.security.device.camera</key>
    <true/>
</dict>
</plist>
EOF

# 设置可执行权限
chmod +x "$MACOS_DIR/$EXECUTABLE_NAME"

# 创建桌面图标（可选）
echo "🎨 创建应用图标..."
# 这里可以添加图标文件，如果有的话

# 完成
echo "✅ 构建完成！"
echo "📍 应用位置: $APP_DIR"
echo ""
echo "🎉 您可以通过以下方式运行应用："
echo "   1. 双击: $APP_DIR"
echo "   2. 命令行: open \"$APP_DIR\""
echo ""
echo "📦 如果要分发应用，建议进行代码签名："
echo "   codesign --force --deep --sign - \"$APP_DIR\""
echo ""

# 可选：自动打开应用
read -p "是否立即运行应用？(y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🚀 正在启动应用..."
    open "$APP_DIR"
fi 