#!/bin/bash

# 权限问题诊断和修复脚本
# 检查应用签名状态并提供解决方案

APP_NAME="拾问AI助手-monitor.app"

echo "🔍 权限问题诊断工具"
echo "===================="
echo ""

# 检查.app文件是否存在
if [ ! -d "$APP_NAME" ]; then
    echo "❌ 找不到 $APP_NAME"
    echo "请确保在包含.app文件的目录中运行此脚本"
    echo ""
    echo "💡 解决方案："
    echo "1. 运行 ./build_app.sh 重新构建应用"
    echo "2. 确保在正确的目录中运行此脚本"
    exit 1
fi

echo "✅ 找到应用: $APP_NAME"
echo ""

# 检查代码签名状态
echo "🔐 检查代码签名状态..."
SIGN_CHECK=$(codesign -dv "$APP_NAME" 2>&1)
SIGN_STATUS=$?

if [ $SIGN_STATUS -eq 0 ]; then
    echo "✅ 应用已签名"
    echo "📋 签名信息:"
    echo "$SIGN_CHECK" | grep -E "(Identifier|Authority|Signature)"
    echo ""
    
    # 验证签名完整性
    echo "🔍 验证签名完整性..."
    codesign --verify --deep --strict "$APP_NAME" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "✅ 签名验证通过"
        echo ""
        echo "🎉 诊断结果: 应用已正确签名，权限应该会被保持"
        echo ""
        echo "如果仍然出现权限问题，可能的原因："
        echo "• 移动了应用位置"
        echo "• 系统设置中需要手动重置权限"
        echo "• 首次运行仍需要授权（这是正常的）"
    else
        echo "⚠️ 签名验证失败"
        echo "需要重新签名"
        NEEDS_SIGNING=true
    fi
else
    echo "❌ 应用未签名或签名无效"
    echo "这就是每次都要求权限的原因！"
    NEEDS_SIGNING=true
fi

# 如果需要签名，提供解决方案
if [ "$NEEDS_SIGNING" = true ]; then
    echo ""
    echo "🔧 解决方案："
    echo "===================="
    echo ""
    echo "选项1 - 自动修复（推荐）:"
    echo "  ./sign_app.sh"
    echo ""
    echo "选项2 - 手动签名:"
    echo "  codesign --force --deep --sign - $APP_NAME"
    echo ""
    echo "选项3 - 重新构建:"
    echo "  ./build_app.sh"
    echo ""
    
    # 询问是否自动修复
    read -p "是否现在自动修复签名问题？(y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🔄 开始自动修复..."
        echo ""
        
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
            echo "✅ 修复完成！"
            echo ""
            echo "🔍 验证修复结果..."
            codesign --verify --deep --strict "$APP_NAME"
            if [ $? -eq 0 ]; then
                echo "✅ 签名验证通过"
                echo "🎉 权限问题已修复！现在应用权限将被保持。"
            else
                echo "⚠️ 签名验证失败，但应用仍可使用"
            fi
        else
            echo "❌ 自动修复失败"
            echo "请手动运行签名命令或重新构建应用"
        fi
    fi
fi

echo ""
echo "📖 更多信息请查看: PERMISSION_FIX.md"