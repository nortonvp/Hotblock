// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Hotblock",
    platforms: [
        .macOS(.v14),
    ],
    targets: [
        .executableTarget(
            name: "Hotblock"
        ),
    ]
)
