# 🔐 权限问题解决指南

## 问题描述

如果你遇到每次打开.app文件都需要重新授权权限的问题，这是因为应用没有进行代码签名导致的。

## 为什么会出现这个问题？

1. **未签名的应用**：macOS会把每次运行的未签名应用视为"新"应用
2. **权限绑定**：macOS的权限是与应用的数字签名绑定的
3. **安全机制**：这是macOS的安全机制，防止恶意应用绕过权限控制

## 🚀 解决方案

### 方案1：重新构建并自动签名（推荐）

使用更新后的构建脚本，它会自动进行代码签名：

```bash
# 重新构建应用
./build_app.sh
```

构建脚本现在会：
- ✅ 自动检测是否有开发者证书
- ✅ 优先使用开发者证书签名
- ✅ 如果没有开发者证书，使用临时签名
- ✅ 验证签名是否成功

### 方案2：手动签名现有.app文件

如果你已经有构建好的.app文件：

```bash
# 给现有的.app文件签名
./sign_app.sh
```

### 方案3：命令行手动签名

```bash
# 使用临时签名（仅本机有效）
codesign --force --deep --sign - InterestingLab.app

# 或使用开发者证书（如果有的话）
codesign --force --deep --sign "Developer ID Application: Your Name" InterestingLab.app
```

## 🔍 验证签名

签名完成后，可以验证签名状态：

```bash
# 验证签名
codesign --verify --deep --strict InterestingLab.app

# 查看签名信息
codesign -dv InterestingLab.app
```

## 📋 签名类型说明

### 1. 临时签名 (Ad-hoc Signing)
- **命令**: `codesign --sign -`
- **优点**: 无需开发者证书，免费
- **缺点**: 只能在本机使用，无法分发给其他用户
- **适用**: 个人使用

### 2. 开发者证书签名
- **命令**: `codesign --sign "Developer ID Application: Your Name"`
- **优点**: 可以分发给其他用户，权限稳定
- **缺点**: 需要付费的Apple开发者账号
- **适用**: 分发给其他用户

## 🎯 预期效果

签名完成后：
- ✅ 权限将被保持，不需要每次重新授权
- ✅ 麦克风权限记住你的选择
- ✅ 屏幕录制权限记住你的选择
- ✅ 辅助功能权限记住你的选择

## ⚠️ 注意事项

1. **应用位置**: 签名后尽量不要移动.app文件的位置
2. **修改应用**: 如果修改了.app内容，需要重新签名
3. **系统更新**: 某些系统更新可能需要重新授权，这是正常的

## 🔧 故障排除

### 如果签名失败

```bash
# 检查证书
security find-identity -p codesigning -v

# 检查应用权限
ls -la InterestingLab.app/Contents/MacOS/InterestingLab

# 强制重新签名
codesign --force --deep --sign - InterestingLab.app
```

### 如果仍然要求权限

1. 检查应用是否确实已签名：
   ```bash
   codesign -dv InterestingLab.app
   ```

2. 确保应用位置没有变化

3. 在系统设置中完全删除应用的权限记录，然后重新授权

## 🎉 完成！

按照以上步骤操作后，你的应用应该不再每次都要求权限了。如果仍有问题，请检查签名状态和系统设置。