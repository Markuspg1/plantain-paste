// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PlantainPaste",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "PlantainPaste",
            path: "Sources/PlantainPaste"
        )
    ]
)
