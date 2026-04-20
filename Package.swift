// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MacPod",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MacPod",
            path: "Sources/MacPod"
        )
    ]
)
