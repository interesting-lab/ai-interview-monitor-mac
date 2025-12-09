#!/bin/bash

# 生成自签名SSL证书脚本
# 用于开发和测试环境
# 生成的证书将在开发环境中使用，不适合生产环境

echo "🔐 开始生成自签名SSL证书..."

# 确保工作目录干净
echo "🧹 清理旧证书文件..."
rm -f cert.pem key.pem

# 生成私钥
echo "🔑 生成私钥..."
openssl genrsa -out key.pem 2048

# 生成证书签名请求
echo "📝 生成证书签名请求..."
openssl req -new -key key.pem -out cert.csr -subj "/CN=localhost/O=拾问AI助手-monitor/C=CN"

# 生成自签名证书，有效期10年
echo "📜 生成自签名证书..."
openssl x509 -req -in cert.csr -signkey key.pem -out cert.pem -days 3650

# 清理临时文件
echo "🧹 清理临时文件..."
rm -f cert.csr

# 检查生成的文件
echo "✅ 证书生成完成:"
ls -la cert.pem key.pem

echo ""
echo "📋 使用说明:"
echo "1. 证书文件已生成: cert.pem 和 key.pem"
echo "2. 这些文件将被应用程序自动使用"
echo "3. 首次通过HTTPS访问时，浏览器可能会显示警告，这是正常的"
echo "4. 在开发/测试环境中接受证书即可"
echo "" 