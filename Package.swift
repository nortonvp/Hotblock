// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Hotblock",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        .package(
            url: "https://github.com/spacenation/swiftui-sliders.git",
            revision: "0e7b1b664f4ec2de0e2cb530d3601f19dd6dd688"
        ),
    ],
    targets: [
        .executableTarget(
            name: "Hotblock",
            dependencies: [
                .product(name: "Sliders", package: "swiftui-sliders"),
            ]
        ),
    ]
)
