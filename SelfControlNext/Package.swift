// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SelfControlNext",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "SelfControlNext",
            path: "Sources/SelfControlNext"
        ),
    ]
)
