// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ZoomCaptionSaver",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "ZoomCaptionSaver", targets: ["CaptionApp"])],
    targets: [
        .target(name: "CaptionCore"),
        .executableTarget(name: "CaptionApp", dependencies: ["CaptionCore"]),
        .testTarget(name: "CaptionCoreTests", dependencies: ["CaptionCore"])
    ]
)
