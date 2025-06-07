# ScreenCaptureKit 音频捕获实现

## 概述

成功使用 ScreenCaptureKit API 重新实现了 macOS 音频捕获功能，提供更现代、高性能的音频捕获解决方案。

## 主要改进

### 1. 使用 ScreenCaptureKit 框架
- **系统音频捕获**: 使用 `SCStream` 和 `SCStreamConfiguration` 进行高质量系统音频捕获
- **权限管理**: 通过 `CGPreflightScreenCaptureAccess()` 和 `CGRequestScreenCaptureAccess()` 管理屏幕录制权限
- **音频质量**: 支持 44.1kHz 立体声音频捕获，避免了之前的格式转换问题

### 2. 版本兼容性
- **macOS 12.3+**: 基础 ScreenCaptureKit 功能
- **macOS 15.0+**: 支持麦克风捕获 (`SCStreamOutputType.microphone`)
- **向后兼容**: 在较低版本系统上自动回退到 AVAudioEngine

### 3. 架构优化
```swift
@available(macOS 12.3, *)
class AudioCapture: NSObject, SCStreamOutput, SCStreamDelegate {
    private var captureStream: SCStream?
    private var micAudioEngine: AVAudioEngine?  // 备用方案
    private var webSocket: WebSocket?
    private var isCapturing = false
}
```

## 核心功能

### 系统音频捕获
```swift
// 配置 ScreenCaptureKit 流
let configuration = SCStreamConfiguration()
configuration.capturesAudio = true
configuration.excludesCurrentProcessAudio = true
configuration.sampleRate = 44100
configuration.channelCount = 2

// 创建内容过滤器，排除当前应用
let filter = SCContentFilter(display: display, 
                           excludingApplications: excludedApps, 
                           exceptingWindows: [])

// 创建捕获流
captureStream = SCStream(filter: filter, 
                        configuration: configuration, 
                        delegate: self)
```

### 麦克风捕获
- **macOS 15+**: 使用 ScreenCaptureKit 的原生麦克风支持
- **macOS 12.3-14.x**: 使用 AVAudioEngine 作为备用方案

### 音频数据处理
```swift
func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
    switch type {
    case .audio:
        processSystemAudioSample(sampleBuffer: sampleBuffer)
    case .microphone:
        processMicrophoneAudioSample(sampleBuffer: sampleBuffer)
    default:
        break
    }
}
```

## API 端点

### 1. Health Check
```bash
GET /health
```
响应:
```json
{
  "data": {"ok": true},
  "success": true
}
```

### 2. 配置信息
```bash
GET /config
```
响应:
```json
{
  "data": {
    "audioConfig": {
      "bufferDurationMs": 50,
      "sampleRate": 16000
    },
    "deviceInfo": {
      "version": "2.1.0",
      "build": "15",
      "id": "10F7F6DD-2D66-55C3-9128-E80E85EFBF1D",
      "name": "zihjiang's MBPM4",
      "platform": "macos"
    }
  },
  "success": true
}
```

### 3. WebSocket 音频流
```bash
WS /ws
```
音频数据格式:
```json
{
  "payload": {
    "audioType": "system",  // 或 "mic"
    "data": [0,0,0,...]     // 音频数据数组
  },
  "id": "HMCfEbKFzLxDALPYIhRZf",
  "wsEventType": "audio-data-event"
}
```

## 权限要求

### 1. 屏幕录制权限
- 系统音频捕获需要屏幕录制权限
- 自动请求权限: `CGRequestScreenCaptureAccess()`

### 2. 麦克风权限
- 麦克风捕获需要音频输入权限
- 自动请求权限: `AVCaptureDevice.requestAccess(for: .audio)`

## 运行方式

### 1. 命令行模式
```bash
.build/debug/AudioCaptureMacApp
```

### 2. GUI 模式
```bash
.build/debug/AudioCaptureMacApp --gui
```

### 3. 应用包模式
```bash
make app
open AudioCaptureMacApp.app
```

## 测试验证

### API 测试
```bash
# Health check
curl http://localhost:9047/health

# Configuration
curl http://localhost:9047/config

# WebSocket 测试
curl --include --no-buffer \
  --header "Connection: Upgrade" \
  --header "Upgrade: websocket" \
  --header "Sec-WebSocket-Key: SGVsbG8sIHdvcmxkIQ==" \
  --header "Sec-WebSocket-Version: 13" \
  http://localhost:9047/ws
```

## 技术优势

1. **高性能**: ScreenCaptureKit 利用 GPU 加速，CPU 开销更低
2. **高质量**: 原生分辨率和帧率支持
3. **现代化**: 使用最新的 macOS 音频捕获 API
4. **隐私保护**: 内置全局隐私保护措施
5. **灵活配置**: 支持实时调整捕获参数

## 解决的问题

1. **格式转换错误**: 避免了 "Input HW format and tap format not matching" 错误
2. **权限管理**: 统一的权限请求和管理
3. **版本兼容**: 支持多个 macOS 版本
4. **性能优化**: 更低的 CPU 使用率和更高的音频质量

## 未来扩展

1. **HDR 支持**: 可扩展支持 HDR 内容捕获
2. **多显示器**: 支持多显示器音频捕获
3. **录制功能**: 可添加直接录制到文件的功能
4. **音频处理**: 可添加实时音频处理和滤波功能 