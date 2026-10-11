// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "FitsCull",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "FitsCull", targets: ["FitsCull"]),
    ],
    targets: [
        .target(name: "FitsCullCore"),
        .executableTarget(
            name: "FitsCull",
            dependencies: ["FitsCullCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(name: "FitsCullCoreTests", dependencies: ["FitsCullCore"]),
    ]
)
