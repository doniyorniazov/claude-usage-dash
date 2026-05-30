// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "UsageDash",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "UsageDash",
            path: "Sources/UsageDash",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
