// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ConnectBar",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "ConnectBar", targets: ["ConnectBar"])],
    targets: [
        .executableTarget(name: "ConnectBar"),
        .testTarget(name: "ConnectBarTests", dependencies: ["ConnectBar"])
    ]
)
