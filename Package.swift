// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Komo",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "Komo", targets: ["Komo"])],
    targets: [
        .executableTarget(name: "Komo", path: "Sources/Komo"),
        .testTarget(name: "KomoTests", dependencies: ["Komo"], path: "Tests/KomoTests")
    ]
)
