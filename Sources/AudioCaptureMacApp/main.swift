import Foundation
import Vapor
import WebSocketKit
import AVFoundation
import Cocoa

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

func configure(_ app: Application) throws {
    // 配置端口
    app.http.server.configuration.port = 9047
    app.http.server.configuration.hostname = "127.0.0.1"
    
    // 健康检查端点
    app.get("health") { req in
        return HealthResponse(
            data: HealthData(ok: true),
            success: true
        )
    }
    
    // 配置端点
    app.get("config") { req in
        return ConfigResponse(
            data: ConfigData(
                audioConfig: AudioConfig(
                    bufferDurationMs: 50.0,
                    sampleRate: 16000.0
                ),
                deviceInfo: DeviceInfo(
                    build: "15",
                    id: getDeviceId(),
                    name: getDeviceName(),
                    platform: "macos",
                    version: "2.1.0"
                )
            ),
            success: true
        )
    }
    
    // WebSocket端点
    app.webSocket("ws") { req, ws async in
        if #available(macOS 12.3, *) {
            let audioCapture = AudioCapture.shared
            audioCapture.addWebSocket(ws)
            
            // 如果还没有开始捕获，启动全局音频捕获
            do {
                try await audioCapture.startGlobalAudioCapture()
            } catch {
                print("WebSocket音频捕获错误: \(error)")
            }
        } else {
            print("❌ 需要 macOS 12.3 或更高版本")
            try await ws.close(code: .unsupportedData)
        }
    }
    
    print("Server starting on port 9047...")
}

// MARK: - 数据结构定义

struct HealthResponse: Content {
    let data: HealthData
    let success: Bool
}

struct HealthData: Content {
    let ok: Bool
}

struct ConfigResponse: Content {
    let data: ConfigData
    let success: Bool
}

struct ConfigData: Content {
    let audioConfig: AudioConfig
    let deviceInfo: DeviceInfo
}

struct AudioConfig: Content {
    let bufferDurationMs: Double
    let sampleRate: Double
}

struct DeviceInfo: Content {
    let build: String
    let id: String
    let name: String
    let platform: String
    let version: String
}

struct AudioDataEvent: Content {
    let id: String
    let payload: AudioPayload
    let type: String?
    let wsEventType: String
}

struct AudioPayload: Content {
    let audioType: String
    let data: [Double]
}

// MARK: - 辅助函数

func getDeviceId() -> String {
    if let uuid = IORegistryEntryCreateCFProperty(
        IORegistryEntryFromPath(kIOMainPortDefault, "IOService:/"),
        "IOPlatformUUID" as CFString,
        kCFAllocatorDefault,
        0
    )?.takeRetainedValue() as? String {
        return uuid
    }
    return UUID().uuidString
}

func getDeviceName() -> String {
    return Host.current().localizedName ?? "Unknown Mac"
} 