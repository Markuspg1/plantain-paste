// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PBP",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "PBP",
            path: "Sources/PBP"
        )
    ]
)
