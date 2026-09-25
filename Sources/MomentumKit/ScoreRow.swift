/// One row of `v_recent_scores` -- the columns the web's auth.js selects, under
/// the same names.
public struct ScoreRow: Codable, Equatable, Hashable, Sendable {
    public let scanID: Int
    /// `scans.run_at` is TEXT; the pipeline writes UTC `isoformat()`, e.g.
    /// "2026-09-18T11:05:52.187557+00:00". Kept as the string it arrives as.
    public let runAt: String
    public let region: String
    /// The `gics_sector` column: the theme's name. A legacy column name that is
    /// load-bearing in sector_momentum's schema, so it is only renamed here.
    public let theme: String
    public let levelScore: Double?
    public let changeScore: Double?
    public let dataScore: Double?
    public let sentimentScore: Double?
    public let composite: Double?
    /// REAL in Postgres: tied composites average to x.5.
    public let rank: Double?

    /// "THEME|Shipping" -- the key the Python and JS code use for a row.
    public var key: String { "\(region)|\(theme)" }

    public init(scanID: Int, runAt: String, region: String, theme: String,
                levelScore: Double? = nil, changeScore: Double? = nil,
                dataScore: Double? = nil, sentimentScore: Double? = nil,
                composite: Double?, rank: Double?) {
        self.scanID = scanID
        self.runAt = runAt
        self.region = region
        self.theme = theme
        self.levelScore = levelScore
        self.changeScore = changeScore
        self.dataScore = dataScore
        self.sentimentScore = sentimentScore
        self.composite = composite
        self.rank = rank
    }

    enum CodingKeys: String, CodingKey {
        case scanID = "scan_id"
        case runAt = "run_at"
        case region
        case theme = "gics_sector"
        case levelScore = "level_score"
        case changeScore = "change_score"
        case dataScore = "data_score"
        case sentimentScore = "sentiment_score"
        case composite
        case rank
    }
}
