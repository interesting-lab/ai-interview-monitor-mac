#!/bin/bash

# 手动签名现有.app文件的脚本
# 解决每次都要求权限的问题

APP_NAME="拾问AI助手-monitor.app"

if [ ! -d "$APP_NAME" ]; then
    echo "❌ 错误: 找不到 $APP_NAME"
    echo "请确保在包含.app文件的目录中运行此脚本"
    exit 1
fi

echo "🔐 开始为 $APP_NAME 签名..."

# 尝试使用开发者证书签名
DEV_CERT=$(security find-identity -p codesigning -v | grep "Developer ID Application" | head -1 | cut -d'"' -f2)
if [ ! -z "$DEV_CERT" ]; then
    echo "📝 使用开发者证书签名: $DEV_CERT"
    codesign --force --deep --sign "$DEV_CERT" "$APP_NAME"
    SIGN_RESULT=$?
else
    echo "📝 使用临时签名（仅本机有效）"
    codesign --force --deep --sign - "$APP_NAME"
    SIGN_RESULT=$?
fi

if [ $SIGN_RESULT -eq 0 ]; then
    echo "✅ 代码签名完成"
    
    # 验证签名
    echo "🔍 验证代码签名..."
    codesign --verify --deep --strict "$APP_NAME"
    if [ $? -eq 0 ]; then
        echo "✅ 签名验证通过"
        echo "🎉 现在应用权限将被保持，不需要每次重新授权"
    else
        echo "⚠️ 签名验证失败，但应用仍可使用"
    fi
    
    # 显示签名信息
    echo ""
    echo "📋 签名信息:"
    codesign -dv "$APP_NAME" 2>&1
else
    echo "❌ 代码签名失败"
    echo "请检查是否有足够的权限或证书配置"
    exit 1
fi

echo ""
echo "✅ 完成！现在你可以运行应用而不需要每次重新授权了。"