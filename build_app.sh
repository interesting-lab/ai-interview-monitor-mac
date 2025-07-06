#!/bin/bash

# 清理之前的构建
echo "🧹 清理之前的构建..."
rm -rf build/
rm -rf InterestingLab.app

# 构建项目
echo "🔨 构建项目..."
swift build -c release

if [ $? -ne 0 ]; then
    echo "❌ 构建失败"
    exit 1
fi

# 创建.app包结构
echo "📦 创建.app包结构..."
mkdir -p InterestingLab.app/Contents/MacOS
mkdir -p InterestingLab.app/Contents/Resources

# 复制可执行文件
echo "📋 复制可执行文件..."
cp .build/release/InterestingLab InterestingLab.app/Contents/MacOS/

# 复制Info.plist
echo "📋 复制Info.plist..."
cp Info.plist InterestingLab.app/Contents/

# 设置可执行权限
chmod +x InterestingLab.app/Contents/MacOS/InterestingLab

echo "✅ .app包构建完成！"
echo "📍 位置: $(pwd)/InterestingLab.app"
echo ""
echo "🚀 运行方式："
echo "   双击打开: open InterestingLab.app"
echo "   命令行: ./InterestingLab.app/Contents/MacOS/InterestingLab"
echo ""
echo "💡 提示: 使用.app包运行时，Dock图标将完全隐藏" 