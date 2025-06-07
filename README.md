# Audio Capture macOS App

一个原生的macOS应用程序，提供音频捕获服务，支持麦克风和系统音频数据的实时传输。

## 功能特性

- **原生macOS应用**：使用Swift和AppKit开发
- **HTTP API服务**：监听端口9047，提供RESTful API
- **WebSocket支持**：实时音频数据流传输
- **音频捕获**：同时捕获麦克风和系统音频
- **图形界面**：简洁的GUI控制界面

## API 端点

### HTTP API

#### 1. 健康检查
```
GET /health
```
响应：
```json
{
    "data": {
        "ok": true
    },
    "success": true
}
```

#### 2. 配置信息
```
GET /config
```
响应：
```json
{
    "data": {
        "audioConfig": {
            "bufferDurationMs": 50.0,
            "sampleRate": 16000.0
        },
        "deviceInfo": {
            "build": "15",
            "id": "10F7F6DD-2D66-55C3-9128-E80E85EFBF1D",
            "name": "zihjiang's MBPM4",
            "platform": "macos",
            "version": "2.1.0"
        }
    },
    "success": true
}
```

### WebSocket API

#### 音频数据流
```
WebSocket /ws
```

**麦克风数据**：
```json
{
    "id": "GAocFtaxX6X2Lc_xAi8Ev",
    "payload": {
        "audioType": "mic",
        "data": [-0.0028614969924092293, -0.0029907075222581625, ...]
    },
    "type": null,
    "wsEventType": "audio-data-event"
}
```

**系统音频数据**：
```json
{
    "id": "-kjugMPCCSoqmOer3lapx",
    "payload": {
        "audioType": "system",
        "data": [0.0, 0.0, 0.0, ...]
    },
    "type": null,
    "wsEventType": "audio-data-event"
}
```

## 系统要求

- macOS 13.0 或更高版本
- Xcode 14.0 或更高版本
- Swift 5.9 或更高版本

## 安装和使用

### 1. 编译和运行

```bash
# 编译项目
make build

# 运行命令行版本
make run

# 运行GUI版本
.build/release/AudioCaptureMacApp --gui

# 或者运行调试版本
make debug
```

### 2. 创建应用包

```bash
# 创建 .app 包
make package

# 安装到应用程序文件夹
make install
```

### 3. 测试API

启动应用后，可以使用以下命令测试API：

```bash
# 运行完整的API测试套件
./test_api.sh

# 或者单独测试各个端点
make test          # 测试健康检查
make test-config   # 测试配置端点

# 手动测试WebSocket（使用wscat）
npm install -g wscat
wscat -c ws://localhost:9047/ws
```

## 权限要求

应用需要以下权限：

- **麦克风访问权限**：用于捕获麦克风音频
- **网络权限**：用于提供HTTP和WebSocket服务

首次运行时，系统会提示授权麦克风访问权限。

## 开发和调试

### 查看日志

应用会在控制台输出详细的日志信息，包括：
- 服务器启动状态
- 音频捕获状态
- WebSocket连接状态
- 错误信息

### 清理编译文件

```bash
make clean
```

## 技术栈

- **Swift 5.9**：主要编程语言
- **AppKit**：macOS原生GUI框架
- **AVFoundation**：音频捕获和处理
- **Vapor**：HTTP和WebSocket服务器
- **Swift Package Manager**：依赖管理

## 故障排除

### 1. 麦克风权限被拒绝
- 前往 系统偏好设置 > 安全性与隐私 > 隐私 > 麦克风
- 确保应用已被授权

### 2. 端口被占用
- 检查端口9047是否被其他应用占用
- 使用 `lsof -i :9047` 查看端口使用情况

### 3. 编译错误
- 确保已安装Xcode和Swift
- 运行 `swift --version` 检查Swift版本
- 运行 `make clean` 清理后重新编译

## 许可证

MIT License 