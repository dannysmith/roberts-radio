// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RadioBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "RadioBar",
            path: "Sources"
        ),
    ]
)
