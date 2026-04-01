// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RadioBar",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/orchetect/MenuBarExtraAccess", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "RadioBar",
            dependencies: ["MenuBarExtraAccess"],
            path: "Sources"
        ),
    ]
)
