// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "KMonitor",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "KMonitor", targets: ["KMonitor"])],
    targets: [
        .executableTarget(name: "KMonitor", path: "Sources/KMonitor"),
        .testTarget(name: "KMonitorTests", dependencies: ["KMonitor"], path: "Tests/KMonitorTests")
    ]
)
