// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "InterestingLab",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .executable(name: "InterestingLab", targets: ["AudioCaptureMacApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.89.0"),
        .package(url: "https://github.com/vapor/websocket-kit.git", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "AudioCaptureMacApp",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "WebSocketKit", package: "websocket-kit")
            ]
        )
    ]
) 