import Foundation
import Vapor
import WebSocketKit
import AVFoundation
import IOKit
import Cocoa

@main
struct SimpleAudioServer {
    static func main() {
        // 默认启动GUI版本，除非指定 --cli 参数
        if !CommandLine.arguments.contains("--cli") {
            // GUI模式（默认）
            let app = NSApplication.shared
            let delegate = AudioServerApp()
            app.delegate = delegate
            
            // 设置应用激活策略
            app.setActivationPolicy(.regular)
            app.activate(ignoringOtherApps: true)
            
            app.run()
            return
        }
        
        // 命令行版本 - 启动异步任务
        Task {
            do {
                try await startCommandLineServer()
            } catch {
                print("服务器启动失败: \(error.localizedDescription)")
                exit(1)
            }
        }
        
        // 保持主线程运行
        RunLoop.main.run()
    }
    
    private static func startCommandLineServer() async throws {
        // 命令行版本 - 使用标准的Vapor启动方式
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)
        
        let app = try await Application.make(.detect())
        defer { 
            Task {
                try? await app.asyncShutdown()
            }
        }
        
        // 配置路由
        try await configure(app)
        
        print("🚀 Audio Capture Server starting on port 9047...")
        print("📡 Available endpoints:")
        print("   GET  /health - Health check")
        print("   GET  /config - Configuration")
        print("   WS   /ws     - Audio data stream")
        print("")
        print("💡 Tip: Use --gui flag for graphical interface (default), --cli for command line only")
        print("Press Ctrl+C to stop the server")
        
        // 启动服务器，但避免使用execute()以防止命令行参数冲突
        try await app.server.start(address: .hostname("127.0.0.1", port: 9047))
        
        // 保持服务器运行
        try await withTaskCancellationHandler {
            while !Task.isCancelled {
                try await Task.sleep(for: .seconds(1))
            }
        } onCancel: {
            Task {
                try? await app.asyncShutdown()
            }
        }
    }
}

func configure(_ app: Application) async throws {
    // 配置CORS中间件 - 支持跨域访问
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .DELETE, .OPTIONS],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent, .accessControlAllowOrigin]
    )
    app.middleware.use(CORSMiddleware(configuration: corsConfiguration))
    
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
            // 将WebSocket添加到全局音频捕获管理器
            AudioCapture.shared.addWebSocket(ws)
        } else {
            try? await ws.close()
        }
    }
    
    print("Server starting on port 9047...")
    
    // 启动全局音频捕获
    if #available(macOS 12.3, *) {
        Task {
            do {
                try await AudioCapture.shared.startGlobalAudioCapture()
            } catch {
                print("⚠️ 全局音频捕获启动失败: \(error)")
            }
        }
    }
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

// 语音识别事件结构
struct SpeechRecognitionEvent: Content {
    let id: String
    let payload: SpeechPayload
    let type: String?
    let wsEventType: String
}

struct SpeechPayload: Content {
    let text: String
    let isFinal: Bool
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