// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PrankLock",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "PrankLock",
            path: "Sources/PrankLock",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
