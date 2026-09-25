/// docs/data.json -- only what the app reads. Its gated `themes` array and the
/// UCITS details are ignored by design (Decodable skips unknown keys).
public struct DataFeed: Decodable, Sendable {
    public let schemaVersion: Int
    /// Absent before schema_version 2.
    public let config: FeedConfig?

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case config
    }
}

/// data.json's `config` block: presets, cohort regions and universe metadata.
/// Config only -- nothing in it comes from a scan.
public struct FeedConfig: Codable, Equatable, Sendable {
    public let defaultHorizon: String
    /// Regions the board shows (`["THEME"]`). v_recent_scores has no region
    /// filter and retired sector rows are still in it.
    public let cohorts: [String]
    public let horizons: [Horizon]
    public let universe: [UniverseEntry]

    public init(defaultHorizon: String, cohorts: [String], horizons: [Horizon],
                universe: [UniverseEntry]) {
        self.defaultHorizon = defaultHorizon
        self.cohorts = cohorts
        self.horizons = horizons
        self.universe = universe
    }

    enum CodingKeys: String, CodingKey {
        case defaultHorizon = "default_horizon"
        case cohorts, horizons, universe
    }

    /// The preset to render: the reader's saved choice if it still exists,
    /// else the configured default, else the first. `nil` only when the feed
    /// has no presets at all.
    public func horizon(forKey key: String?) -> Horizon? {
        if let key, let saved = horizons.first(where: { $0.key == key }) { return saved }
        return horizons.first(where: { $0.key == defaultHorizon }) ?? horizons.first
    }

    public func entry(region: String, theme: String) -> UniverseEntry? {
        universe.first { $0.region == region && $0.theme == theme }
    }
}

public struct UniverseEntry: Codable, Equatable, Sendable {
    public let region: String
    public let theme: String
    /// The US listing the scan scores (e.g. "SOXX").
    public let ticker: String
    /// No UCITS equivalent exists, so it cannot be bought from an EU account.
    public let unbuyable: Bool

    public init(region: String, theme: String, ticker: String, unbuyable: Bool) {
        self.region = region
        self.theme = theme
        self.ticker = ticker
        self.unbuyable = unbuyable
    }
}
