// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "拾问AI助手-monitor",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .executable(name: "拾问AI助手-monitor", targets: ["拾问AI助手-monitor"])
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.89.0"),
        .package(url: "https://github.com/vapor/websocket-kit.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "拾问AI助手-monitor",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "WebSocketKit", package: "websocket-kit"),
                .product(name: "NIOSSL", package: "swift-nio-ssl")
            ]
        )
    ]
) 