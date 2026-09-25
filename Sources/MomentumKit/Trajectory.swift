/// The Trend reading: dashboard/rows.py:_compute_rank_trajectories. A negative
/// slope means the rank number is falling, i.e. the theme is climbing.
public enum Trajectory: String, Codable, Sendable, CaseIterable {
    case strongUp = "strong_up"
    case up
    case flat
    case down
    case strongDown = "strong_down"

    /// Thresholds as in Python: <= -1.5, <= -0.3, < 0.3, < 1.5, else.
    public init(slope: Double) {
        if slope <= -1.5 {
            self = .strongUp
        } else if slope <= -0.3 {
            self = .up
        } else if slope < 0.3 {
            self = .flat
        } else if slope < 1.5 {
            self = .down
        } else {
            self = .strongDown
        }
    }

    public var glyph: String {
        switch self {
        case .strongUp: "↑↑"
        case .up: "↑"
        case .flat: "→"
        case .down: "↓"
        case .strongDown: "↓↓"
        }
    }

    /// dashboard/rows.py:TRAJECTORY_WORDS.
    public var word: String {
        switch self {
        case .strongUp: "surging"
        case .up: "rising"
        case .flat: "flat"
        case .down: "falling"
        case .strongDown: "sliding"
        }
    }
}

/// Least-squares slope over x = 0...n-1; 0 for fewer than two points.
public func olsSlope(_ values: [Double]) -> Double {
    let n = values.count
    guard n >= 2 else { return 0 }
    let xMean = Double(n - 1) / 2
    let yMean = values.reduce(0, +) / Double(n)
    var num = 0.0
    var den = 0.0
    for (i, y) in values.enumerated() {
        let dx = Double(i) - xMean
        num += dx * (y - yMean)
        den += dx * dx
    }
    return den == 0 ? 0 : num / den
}

/// Slope and Trend for a rank series in scan order. Python rounds the slope to
/// 3 dp BEFORE thresholding (`round(num / den, 3)`), so -0.2996 reads "up",
/// not "flat" -- this does the same, half-to-even like Python's round().
public func trajectory(forRankSeries ranks: [Double]) -> (slope: Double, trajectory: Trajectory) {
    guard ranks.count >= 2 else { return (0, .flat) }
    let slope = (olsSlope(ranks) * 1000).rounded(.toNearestOrEven) / 1000
    return (slope, Trajectory(slope: slope))
}
