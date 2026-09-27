/// The config and the rows loaded with it, kept and cached TOGETHER so the
/// board never mixes a config from one load with rows from another. The web
/// once showed a headline from one scan above a table from another
/// (sector_momentum#310).
public struct BoardSnapshot: Codable, Equatable, Sendable {
    public let config: FeedConfig
    public let rows: [ScoreRow]

    public init(config: FeedConfig, rows: [ScoreRow]) {
        self.config = config
        self.rows = rows
    }

    /// Whether this snapshot can produce a board at all: at least one preset,
    /// and at least one row in a configured cohort.
    public var hasBoard: Bool {
        !config.horizons.isEmpty && rows.contains { config.cohorts.contains($0.region) }
    }
}
