// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FlowApp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "FlowApp", targets: ["FlowApp"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "FlowApp",
            dependencies: [],
            path: "Sources/FlowApp"
        )
    ]
)
