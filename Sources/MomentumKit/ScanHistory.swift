import Foundation

/// Rank delta and Trend for the latest scan, from a window of raw scans.
///
/// Mirrors dashboard/rows.py -- `distinct_scan_ids`, `_build_rows_common` and
/// `_compute_rank_trajectories` -- NOT the web's signed-in JS path
/// (rescore.js:latestRowMeta), which compares against the previous RAW scan.
/// The cron runs seven days a week against a five-day market, so Saturday,
/// Sunday and Monday scans replay Friday's close; against a replay every delta
/// reads "—". Python compares against the previous DISTINCT scan instead.
///
/// The app only ever sees v_recent_scores' last 6 raw scans. On a Monday that
/// is as few as 3 distinct ones, so the Trend can use fewer points than the
/// server's -- a data limit, not a rule difference: given the same scans, this
/// and Python agree (the fixture's "six raw scans, three distinct" case).
public struct ScanHistory: Sendable {
    public let latestScanID: Int
    /// The latest scan's rows, in input order.
    public let latestRows: [ScoreRow]
    /// Ascending; each duplicate run represented by its LAST id.
    public let distinctScanIDs: [Int]
    private let rowsByScan: [Int: [String: ScoreRow]]
    private let previousScanID: Int?

    /// rows.py's MAX_DUPLICATE_RUN: when the replays TRAILING the latest scan
    /// exceed this, the pipeline looks stuck and no delta is shown rather than a
    /// stale move. Only the trailing run counts (sector_momentum#314): replays
    /// earlier in the window, such as holidays and weekends, must not blank a
    /// healthy board. Out of reach with the app's 6 scans, kept so the rule
    /// reads, and behaves, the same as Python's.
    static let maxDuplicateRun = 7

    /// `nil` when there are no rows at all.
    public init?(rows: [ScoreRow]) {
        guard let latest = rows.map(\.scanID).max() else { return nil }
        var byScan: [Int: [String: ScoreRow]] = [:]
        for row in rows { byScan[row.scanID, default: [:]][row.key] = row }
        let distinct = MomentumKit.distinctScanIDs(rows)
        latestScanID = latest
        latestRows = rows.filter { $0.scanID == latest }
        distinctScanIDs = distinct
        rowsByScan = byScan
        if distinct.count >= 2 {
            let previous = distinct[distinct.count - 2]
            // The run of replays ENDING at the latest scan: every scan after the
            // previous distinct one is a copy of the latest, bar the latest itself.
            let trailingReplays = byScan.keys.filter { $0 > previous }.count - 1
            previousScanID = trailingReplays > Self.maxDuplicateRun ? nil : previous
        } else {
            previousScanID = nil
        }
    }

    /// Previous distinct rank minus current rank: positive = climbed. 0 when
    /// there is no previous distinct scan or the theme is new (Python's
    /// `fillna(0)`).
    public func deltaRank(for key: String) -> Double {
        guard let previousScanID,
              let now = rowsByScan[latestScanID]?[key]?.rank,
              let before = rowsByScan[previousScanID]?[key]?.rank else { return 0 }
        return before - now
    }

    /// Trend over the last five distinct scans the theme has a rank in.
    public func trajectory(for key: String) -> (slope: Double, trajectory: Trajectory) {
        let ranks = distinctScanIDs.suffix(5).compactMap { rowsByScan[$0]?[key]?.rank }
        return MomentumKit.trajectory(forRankSeries: ranks)
    }
}

/// rows.py's display: "+1.0" / "-1.0", or "—" (U+2014) for no change.
public func formatDelta(_ delta: Double) -> String {
    delta == 0 ? "—" : String(format: "%+.1f", delta)
}

/// dashboard/rows.py:distinct_scan_ids. Consecutive scans whose every
/// (region, theme, rank, composite) matches collapse into one, represented by
/// the run's LAST id so the newest scan is the one rendered.
public func distinctScanIDs(_ rows: [ScoreRow]) -> [Int] {
    let byScan = Dictionary(grouping: rows, by: \.scanID)
    var out: [Int] = []
    var previous: [Fingerprint]?
    for id in byScan.keys.sorted() {
        let fp = fingerprint(byScan[id] ?? [])
        if let previous, previous == fp {
            out[out.count - 1] = id
        } else {
            out.append(id)
        }
        previous = fp
    }
    return out
}

struct Fingerprint: Equatable {
    let region: String
    let theme: String
    let rank: Double?
    let composite: Double?
}

/// rows.py:_scan_fingerprint -- rank AND composite, rounded to 10 dp, sorted by
/// key. Covering composite too is deliberate: calling two different scans
/// identical would skip a real observation.
func fingerprint(_ rows: [ScoreRow]) -> [Fingerprint] {
    rows.map { Fingerprint(region: $0.region, theme: $0.theme,
                           rank: round10($0.rank), composite: round10($0.composite)) }
        .sorted { ($0.region, $0.theme) < ($1.region, $1.theme) }
}

func round10(_ x: Double?) -> Double? {
    x.map { ($0 * 1e10).rounded(.toNearestOrEven) / 1e10 }
}
