import Dependencies
import DependenciesMacros
import Foundation
import MomentumKit

/// Reads the `config` block of sector_momentum's public data.json: presets,
/// cohort regions and universe metadata. Nothing in it comes from a scan.
@DependencyClient
public struct FeedClient: Sendable {
    public var fetchConfig: @Sendable () async throws -> FeedConfig
}

public enum FeedError: LocalizedError, Equatable, Sendable {
    /// The feed has no config block. Upstream's config step is fail-open, so a
    /// schema-2 feed can legitimately lack it while that step is failing.
    case noConfig(schemaVersion: Int)
    case http(status: Int)

    public var errorDescription: String? {
        switch self {
        case .noConfig(let v):
            "The published feed has no config block (schema version \(v)). The site may still be deploying, or its config step failed."
        case .http(let status):
            "The config feed returned HTTP \(status)."
        }
    }
}

extension DependencyValues {
    public var feedClient: FeedClient {
        get { self[FeedClient.self] }
        set { self[FeedClient.self] = newValue }
    }
}

extension FeedClient {
    /// Decodes data.json and returns its config block.
    public static func decode(_ data: Data) throws -> FeedConfig {
        let feed = try JSONDecoder().decode(DataFeed.self, from: data)
        guard let config = feed.config else {
            throw FeedError.noConfig(schemaVersion: feed.schemaVersion)
        }
        return config
    }
}
