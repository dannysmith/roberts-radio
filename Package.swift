// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "RadioBar",
    platforms: [.macOS(.v27)],
    dependencies: [
        .package(url: "https://github.com/orchetect/MenuBarExtraAccess", from: "1.3.1"),
    ],
    targets: [
        .executableTarget(
            name: "RadioBar",
            dependencies: ["MenuBarExtraAccess"],
            path: "Sources"
        ),
        .testTarget(
            name: "RadioBarTests",
            dependencies: ["RadioBar"],
            path: "Tests/RadioBarTests"
        ),
    ]
)
