// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ETFMomentum",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        // The app links only the composition root.
        .library(name: "AppFeature", targets: ["AppFeature"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.17.1"),
        // v3 is unreleased and changes verifyOTP's return type and the
        // initialSession semantics; stay on 2.x until it ships and is read.
        .package(url: "https://github.com/supabase/supabase-swift.git", .upToNextMajor(from: "2.55.2")),
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

        // Board: clients carry their small live values inline.
        .target(name: "ScoresClient", dependencies: ["MomentumKit", .dependencies, .dependenciesMacros]),
        .target(name: "FeedClient", dependencies: ["MomentumKit", .dependencies, .dependenciesMacros]),
        .target(name: "BoardCacheClient", dependencies: ["MomentumKit", .dependencies, .dependenciesMacros]),
        .target(
            name: "BoardFeature",
            dependencies: [
                "BoardCacheClient",
                "FeedClient",
                "MomentumKit",
                "ScoresClient",
                .dependencies,
            ]
        ),
        .testTarget(
            name: "BoardFeatureTests",
            dependencies: [
                "BoardCacheClient",
                "BoardFeature",
                "FeedClient",
                "MomentumKit",
                "ScoresClient",
                .dependenciesTestSupport,
            ]
        ),

        // The live SignInClient and ScoresClient: the only module that builds
        // supabase-swift. They share one SupabaseClient, because the signed-in
        // session is what authorises the scores query.
        .target(
            name: "SupabaseLive",
            dependencies: [
                "ScoresClient",
                "SignInClient",
                .dependencies,
                .product(name: "Supabase", package: "supabase-swift"),
            ]
        ),

        // Composition root: the only target allowed to link SupabaseLive.
        .target(
            name: "AppFeature",
            dependencies: [
                "BoardCacheClient",
                "BoardFeature",
                "FeedClient",
                "ScoresClient",
                "SignInClient",
                "SignInFeature",
                "SupabaseLive",
                .dependencies,
            ]
        ),
    ]
)

extension Target.Dependency {
    static let dependencies = Self.product(name: "Dependencies", package: "swift-dependencies")
    static let dependenciesMacros = Self.product(name: "DependenciesMacros", package: "swift-dependencies")
    static let dependenciesTestSupport = Self.product(name: "DependenciesTestSupport", package: "swift-dependencies")
}
