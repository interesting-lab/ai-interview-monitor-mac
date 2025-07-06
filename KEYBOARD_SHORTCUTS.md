# 🎹 键盘快捷键功能说明

## 支持的快捷键

### Primary 事件（ID: oHPzFsnoFYUNlxJGIkCme）
以下快捷键会发送 Primary 键盘事件到 WebSocket：

1. **`Command + Shift + Enter`** - 组合键触发 Primary 事件
2. **`Tab`** - 单独按键触发 Primary 事件

### Secondary 事件（ID: 1muj9eJVcJ1QfVrj6M9-V）
以下快捷键会发送 Secondary 键盘事件到 WebSocket：cd

1. **`Command + Shift + Backspace`** - 组合键触发 Secondary 事件
2. **`Esc`** - 单独按键触发 Secondary 事件

### 其他功能
- **`Command + Shift + Space`** - 截图功能（发送截图到 WebSocket）

## WebSocket 数据格式

### Primary 事件
```json
{
  "id": "oHPzFsnoFYUNlxJGIkCme",
  "payload": {
    "keyEventType": "primary"
  },
  "type": "keydown-event",
  "wsEventType": "keydown-event"
}
```

### Secondary 事件
```json
{
  "id": "1muj9eJVcJ1QfVrj6M9-V",
  "payload": {
    "keyEventType": "secondary"
  },
  "type": "keydown-event",
  "wsEventType": "keydown-event"
}
```

## 键码映射

| 按键 | 键码 | 事件类型 |
|------|------|----------|
| Tab | 48 | Primary |
| Space | 49 | 截图 |
| Backspace | 51 | Secondary |
| Esc | 53 | Secondary |
| Enter | 36 | Primary |

## 测试方法

1. **运行应用**：`swift run`
2. **打开测试页面**：`open test_keydown_events.html`
3. **测试快捷键**：按下上述任意快捷键
4. **查看日志**：在测试页面中查看实时事件日志

## 注意事项

- 需要辅助功能权限才能监听全局快捷键
- WebSocket 连接地址：`ws://localhost:9047/ws`
- 单独按键（Tab/Esc）不需要修饰键
- 组合键需要同时按下 Command + Shift + 对应按键

## 权限要求

- **辅助功能权限**：用于全局快捷键监听
- **麦克风权限**：音频捕获功能
- **屏幕录制权限**：截图和系统音频捕获功能 