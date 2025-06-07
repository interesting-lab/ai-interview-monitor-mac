# 服务器启动错误修复

## 问题描述

用户遇到服务器启动失败的错误：
```
[20:57:59] 服务器启动失败: The operation couldn't be completed.
(ConsoleKitCommands.CommandError error 0.)
```

## 错误原因

问题出现在 `SimpleMain.swift` 中，我们使用了 `@main` 结构体并试图直接调用 `app.execute()`，这与Vapor框架的命令行处理系统产生了冲突。

### 原始代码问题
```swift
@main
struct SimpleAudioServer {
    static func main() async throws {
        // ...
        let app = try await Application.make(.development)
        try configure(app)  // 同步调用
        try await app.execute()  // 与Vapor命令系统冲突
    }
}

func configure(_ app: Application) throws {  // 同步函数
    // ...
}
```

## 解决方案

### 1. 修复Application初始化
使用标准的Vapor环境检测和应用创建方式：

```swift
// 修复前
let app = try await Application.make(.development)

// 修复后
var env = try Environment.detect()
try LoggingSystem.bootstrap(from: &env)
let app = try await Application.make(.detect())
```

### 2. 修复配置函数
将配置函数改为异步：

```swift
// 修复前
func configure(_ app: Application) throws {
    // ...
}

// 修复后
func configure(_ app: Application) async throws {
    // ...
}
```

### 3. 更新函数调用
在所有调用配置函数的地方添加await：

```swift
// SimpleMain.swift
try await configure(app)

// GUIMain.swift
try await configure(app)
```

## 验证修复

修复后的应用可以正常启动：

### 1. 直接运行
```bash
.build/debug/AudioCaptureMacApp
```

### 2. 使用Vapor命令
```bash
.build/debug/AudioCaptureMacApp serve
```

### 3. GUI模式
```bash
.build/debug/AudioCaptureMacApp --gui
```

### 4. API测试
```bash
# Health check
curl http://localhost:9047/health

# Config
curl http://localhost:9047/config

# WebSocket连接也正常工作
```

## 技术细节

- **Environment.detect()**: 自动检测运行环境（开发/生产）
- **LoggingSystem.bootstrap()**: 正确初始化日志系统
- **Application.make(.detect())**: 使用检测到的环境创建应用
- **异步配置**: 允许在配置阶段使用异步操作

## 最终状态

✅ 服务器启动正常  
✅ 所有API端点工作正常  
✅ WebSocket连接成功  
✅ ScreenCaptureKit音频捕获正常  
✅ GUI模式也可以正常启动

这次修复确保了应用与Vapor框架的完全兼容性，解决了命令行处理冲突问题。 