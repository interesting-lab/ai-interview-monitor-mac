// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AudioCaptureMacApp",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "AudioCaptureMacApp", targets: ["AudioCaptureMacApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/websocket-kit.git", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "AudioCaptureMacApp",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "WebSocketKit", package: "websocket-kit")
            ],
            exclude: ["main.swift", "AppDelegate.swift"]
        )
    ]
) 