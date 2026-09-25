// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ETFMomentum",
    platforms: [.iOS(.v18), .macOS(.v15)],
    targets: [
        // The board rules, mirroring sector_momentum's Python. No dependencies.
        .target(name: "MomentumKit", resources: [.copy("SampleData")]),

        .testTarget(
            name: "MomentumKitTests",
            dependencies: ["MomentumKit"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
