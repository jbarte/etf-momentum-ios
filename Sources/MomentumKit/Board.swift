/// Which band a row sits in, for the cut lines between them.
public enum BandSection: Sendable, Equatable {
    case buy
    case hold
    case out
}

public enum DeltaDirection: Sendable, Equatable {
    case up
    case down
    case none
}

public struct BoardRow: Equatable, Sendable, Identifiable {
    public let key: String
    public let theme: String
    /// nil when the theme is not (yet) in the published config.
    public let ticker: String?
    public let unbuyable: Bool
    public let rank: Double?
    public let composite: Double?
    public let level: Double?
    public let change: Double?
    public let deltaRank: Double
    public let deltaText: String
    public let deltaDirection: DeltaDirection
    public let trajectory: Trajectory
    public let setup: Setup?
    public let inBuyBand: Bool
    public let section: BandSection

    public var id: String { key }

    /// Whole ranks as "4"; a tie's average rank as "4.5" rather than
    /// truncating or rounding it into a neighbour's number.
    public var rankText: String {
        guard let rank else { return "—" }
        return rank == rank.rounded() ? String(Int(rank)) : String(rank)
    }
}

public struct Board: Equatable, Sendable {
    public let scanID: Int
    public let runAt: String
    public let horizon: Horizon
    public let universeSize: Int
    public let exitRank: Int
    public let rows: [BoardRow]
}

/// Everything the board shows, derived from ONE v_recent_scores response and
/// the config loaded with it. Keeping it to one source is deliberate: the web
/// once showed a headline from one scan above a table from another
/// (sector_momentum#310).
///
/// `nil` when no row belongs to a configured cohort.
public func buildBoard(rows: [ScoreRow], config: FeedConfig, horizon: Horizon) -> Board? {
    // Filtered like the web table (window.COHORTS in renderLatestRows).
    let cohortRows = rows.filter { config.cohorts.contains($0.region) }
    guard let history = ScanHistory(rows: cohortRows) else { return nil }
    // Python passes len(leaderboard_rows): the latest scan's rows, NOT the
    // config universe. A theme the DB scored before Pages rebuilt the config
    // still counts, or the band would silently narrow.
    let universeSize = history.latestRows.count
    let exitRank = horizon.exitRank(universeSize: universeSize)
    let built = history.latestRows.map { row -> BoardRow in
        let entry = config.entry(region: row.region, theme: row.theme)
        let delta = history.deltaRank(for: row.key)
        return BoardRow(
            key: row.key,
            theme: row.theme,
            ticker: entry?.ticker,
            unbuyable: entry?.unbuyable ?? false,
            rank: row.rank,
            composite: row.composite,
            level: row.levelScore,
            change: row.changeScore,
            deltaRank: delta,
            deltaText: formatDelta(delta),
            deltaDirection: delta > 0 ? .up : (delta < 0 ? .down : .none),
            trajectory: history.trajectory(for: row.key).trajectory,
            setup: setupForRank(row.rank, horizon: horizon, universeSize: universeSize),
            inBuyBand: inBuyBand(row.rank, horizon: horizon),
            section: section(for: row.rank, horizon: horizon, universeSize: universeSize)
        )
    }
    // Rank ascending, unranked last -- pandas sort_values puts NaN last.
    let sorted = built.sorted { ($0.rank ?? .infinity) < ($1.rank ?? .infinity) }
    return Board(scanID: history.latestScanID, runAt: history.latestRows.first?.runAt ?? "",
                 horizon: horizon, universeSize: universeSize, exitRank: exitRank, rows: sorted)
}

/// Which band a rank sits in, derived from the band rule itself
/// (`inBuyBand`, `setupForRank`) rather than a second copy of it -- so the cut
/// lines can never be drawn somewhere the Enter/Exit badges disagree with.
/// Pinned against the Python fixture in BandTests.
func section(for rank: Double?, horizon: Horizon, universeSize: Int) -> BandSection {
    guard rank != nil else { return .out }
    if inBuyBand(rank, horizon: horizon) { return .buy }
    if setupForRank(rank, horizon: horizon, universeSize: universeSize) == .exit { return .out }
    return .hold
}

/// The web's band cut lines (index.html.j2's insertCutRow), same wording.
public enum CutLabel {
    public static let buy = "BUY BAND ENDS"
    public static let hold = "HOLD BAND ENDS"
}

public enum BoardItem: Equatable, Sendable, Identifiable {
    case row(BoardRow)
    case cut(String)

    public var id: String {
        switch self {
        case .row(let row): row.id
        case .cut(let label): "cut:\(label)"
        }
    }
}

/// Rows with the cut lines between them: "BUY BAND ENDS" after the last
/// buy-band row, "HOLD BAND ENDS" after the last hold-band row -- each only
/// when a row follows it.
public func boardItems(_ rows: [BoardRow]) -> [BoardItem] {
    var items: [BoardItem] = []
    for (i, row) in rows.enumerated() {
        items.append(.row(row))
        guard i + 1 < rows.count else { continue }
        let next = rows[i + 1].section
        if row.section == .buy && next != .buy { items.append(.cut(CutLabel.buy)) }
        if row.section != .out && next == .out { items.append(.cut(CutLabel.hold)) }
    }
    return items
}
