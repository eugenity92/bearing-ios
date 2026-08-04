// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ReadinessCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ReadinessCore", targets: ["ReadinessCore"])
    ],
    targets: [
        .target(
            name: "ReadinessCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "ReadinessCoreTests",
            dependencies: ["ReadinessCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
