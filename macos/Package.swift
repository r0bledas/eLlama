// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "eLlama",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "eLlama", targets: ["eLlama"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "eLlama",
            dependencies: [],
            path: "Sources/eLlama"
        )
    ]
)
