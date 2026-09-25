// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ETFMomentum",
    platforms: [.iOS(.v18), .macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.17.1"),
    ],
    targets: [
        // The board rules, mirroring sector_momentum's Python. No dependencies.
        .target(name: "MomentumKit", resources: [.copy("SampleData")]),

        .testTarget(
            name: "MomentumKitTests",
            dependencies: ["MomentumKit"],
            resources: [.copy("Fixtures")]
        ),

        // Sign-in
        .target(name: "SignInClient", dependencies: [.dependencies, .dependenciesMacros]),
        .target(name: "SignInFeature", dependencies: ["SignInClient", .dependencies]),
        .testTarget(
            name: "SignInFeatureTests",
            dependencies: ["SignInClient", "SignInFeature", .dependenciesTestSupport]
        ),
    ]
)

extension Target.Dependency {
    static let dependencies = Self.product(name: "Dependencies", package: "swift-dependencies")
    static let dependenciesMacros = Self.product(name: "DependenciesMacros", package: "swift-dependencies")
    static let dependenciesTestSupport = Self.product(name: "DependenciesTestSupport", package: "swift-dependencies")
}
