#!/bin/bash

# 清理之前的构建
echo "🧹 清理之前的构建..."
rm -rf build/
rm -rf "拾问AI助手-monitor.app"

# 生成SSL证书
echo "🔐 生成SSL证书..."
./generate_cert.sh

# 构建项目 - 支持多架构 (arm64 + x86_64)
echo "🔨 构建项目 (多架构支持)..."
swift build -c release --triple x86_64-apple-macosx11.0
swift build -c release --triple arm64-apple-macosx11.0

if [ $? -ne 0 ]; then
    echo "❌ 构建失败"
    exit 1
fi

# 创建通用二进制文件
echo "🔗 创建通用二进制文件..."
mkdir -p .build/universal
lipo -create \
    .build/x86_64-apple-macosx/release/拾问AI助手-monitor \
    .build/arm64-apple-macosx/release/拾问AI助手-monitor \
    -output .build/universal/拾问AI助手-monitor

# 创建.app包结构
echo "📦 创建.app包结构..."
mkdir -p "拾问AI助手-monitor.app/Contents/MacOS"
mkdir -p "拾问AI助手-monitor.app/Contents/Resources"

# 复制通用可执行文件
echo "📋 复制通用可执行文件..."
cp .build/universal/拾问AI助手-monitor "拾问AI助手-monitor.app/Contents/MacOS/"

# 复制Info.plist
echo "📋 复制Info.plist..."
cp Info.plist "拾问AI助手-monitor.app/Contents/"

# 复制SSL证书
echo "📋 复制SSL证书..."
cp cert.pem "拾问AI助手-monitor.app/Contents/Resources/"
cp key.pem "拾问AI助手-monitor.app/Contents/Resources/"

# 复制应用图标
echo "🎨 复制应用图标..."
if [ -f "AppIcon.icns" ]; then
    cp AppIcon.icns "拾问AI助手-monitor.app/Contents/Resources/"
    echo "✅ 图标已添加"
else
    echo "⚠️ 没有找到图标文件 AppIcon.icns"
fi

# 设置可执行权限
chmod +x "拾问AI助手-monitor.app/Contents/MacOS/拾问AI助手-monitor"

# 验证架构支持
echo "🔍 验证架构支持..."
file "拾问AI助手-monitor.app/Contents/MacOS/拾问AI助手-monitor"

echo "✅ .app包构建完成！"
echo "📍 位置: $(pwd)/拾问AI助手-monitor.app"
echo ""

# 创建DMG文件
echo "📀 创建DMG安装包..."
APP_NAME="拾问AI助手-monitor"
DMG_NAME="${APP_NAME}.dmg"
DMG_TEMP_NAME="${APP_NAME}_temp.dmg"
DMG_VOLUME_NAME="${APP_NAME} 安装包"

# 移除旧的DMG文件（如果存在）
if [ -f "${DMG_NAME}" ]; then
    rm -f "${DMG_NAME}"
fi
if [ -f "${DMG_TEMP_NAME}" ]; then
    rm -f "${DMG_TEMP_NAME}"
fi

# 创建临时目录用于构建DMG内容
mkdir -p ./dmg_contents
cp -R "${APP_NAME}.app" ./dmg_contents/
# 创建一个指向Applications文件夹的符号链接
ln -s /Applications ./dmg_contents/

# 创建一个可读写的临时DMG文件
hdiutil create -fs HFS+ -volname "${DMG_VOLUME_NAME}" -srcfolder ./dmg_contents -format UDRW "${DMG_TEMP_NAME}"

# 转换DMG为只读格式
hdiutil convert "${DMG_TEMP_NAME}" -format UDZO -o "${DMG_NAME}"

# 清理
rm -f "${DMG_TEMP_NAME}"
rm -rf ./dmg_contents

echo "✅ DMG安装包创建完成！"
echo "📍 位置: $(pwd)/${DMG_NAME}"
echo ""

# 代码签名 - 尽量使用固定证书，避免 TCC 反复弹窗
echo "🔐 开始代码签名..."
SIGN_RESULT=0

# 如果设置了环境变量 CODESIGN_ID，则优先使用
if [ -n "$CODESIGN_ID" ]; then
    echo "📝 使用环境变量证书签名: $CODESIGN_ID"
    KEYCHAIN_OPT=()
    # 可选：指定 keychain 路径（例如 CI 中创建的临时 keychain）
    if [ -n "$CODESIGN_KEYCHAIN" ]; then
        KEYCHAIN_OPT=(--keychain "$CODESIGN_KEYCHAIN")
    fi
    codesign --force --deep --options runtime "${KEYCHAIN_OPT[@]}" --sign "$CODESIGN_ID" "${APP_NAME}.app"
    SIGN_RESULT=$?
else
    # 尝试自动寻找 Developer ID 证书
    DEV_CERT=$(security find-identity -p codesigning -v | grep "Developer ID Application" | head -1 | cut -d'"' -f2)
    if [ ! -z "$DEV_CERT" ]; then
        echo "📝 使用开发者证书签名: $DEV_CERT"
        codesign --force --deep --options runtime --sign "$DEV_CERT" "${APP_NAME}.app"
        SIGN_RESULT=$?
    else
        echo "📝 未提供证书，使用临时签名（仅本机有效，TCC 可能反复弹窗）"
        codesign --force --deep --sign - "${APP_NAME}.app"
        SIGN_RESULT=$?
    fi
fi

if [ $SIGN_RESULT -eq 0 ]; then
    echo "✅ 代码签名完成"
    # 验证签名
    echo "🔍 验证代码签名..."
    codesign --verify --deep --strict "${APP_NAME}.app"
    if [ $? -eq 0 ]; then
        echo "✅ 签名验证通过"
    else
        echo "⚠️ 签名验证失败，但应用仍可使用"
    fi
else
    echo "⚠️ 代码签名失败，应用可能每次都需要重新授权"
fi

echo ""
echo "🚀 运行方式："
echo "   双击打开: open ${APP_NAME}.app"
echo "   命令行: ./${APP_NAME}.app/Contents/MacOS/${APP_NAME}"
echo ""
echo "💡 提示: 使用.app包运行时，Dock图标将完全隐藏"
echo "🖥️  支持架构: arm64 (Apple Silicon) + x86_64 (Intel)"
echo "🔒 支持HTTPS: 使用自签名证书 (端口9048)" 
echo "📦 安装包: 双击 ${DMG_NAME} 打开后，将应用拖到Applications文件夹安装"
echo ""
echo "🔐 代码签名状态: $(if [ $SIGN_RESULT -eq 0 ]; then echo "✅ 已签名 - 权限将被保持"; else echo "❌ 未签名 - 可能需要重新授权"; fi)" 