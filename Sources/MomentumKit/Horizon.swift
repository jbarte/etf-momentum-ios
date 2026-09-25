/// One horizon preset, as published in data.json's `config.horizons`.
///
/// Mirrors `src/horizons.py:Horizon` in sector_momentum. The values are never
/// hardcoded here -- they arrive from the feed -- so a preset retune in
/// config/weights.yaml cannot drift from what the app computes. The *rule* can,
/// which is what the band-fixture tests are for.
public struct Horizon: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let key: String
    public let label: String
    public let rebalance: String
    public let topN: Int
    public let bufferFrac: Double
    public let reviewDates: [String]

    public var id: String { key }

    public init(key: String, label: String, rebalance: String, topN: Int,
                bufferFrac: Double, reviewDates: [String] = []) {
        self.key = key
        self.label = label
        self.rebalance = rebalance
        self.topN = topN
        self.bufferFrac = bufferFrac
        self.reviewDates = reviewDates
    }

    enum CodingKeys: String, CodingKey {
        case key, label, rebalance
        case topN = "top_n"
        case bufferFrac = "buffer_frac"
        case reviewDates = "review_dates"
    }

    /// Ranks above this leave the hold band: `topN + round_half_up(bufferFrac *
    /// universeSize)`, resolved fresh on every call because the buffer is a
    /// FRACTION of the universe. Never cache it.
    public func exitRank(universeSize: Int) -> Int {
        topN + roundHalfUp(bufferFrac * Double(universeSize))
    }
}

/// `int(math.floor(x + 0.5))` -- src/horizons.py:_round_half_up. Written out
/// rather than `.rounded()` so the Python it mirrors is visible.
func roundHalfUp(_ x: Double) -> Int {
    Int((x + 0.5).rounded(.down))
}

/// The position band a rank sits in: dashboard/rows.py:_compute_setup.
public enum Setup: String, Codable, Sendable {
    case entry
    case exit
}

/// Entry inside the buy band, Exit past the hold band, nothing in between.
/// A missing rank has no setup.
public func setupForRank(_ rank: Double?, horizon: Horizon, universeSize: Int) -> Setup? {
    guard let rank else { return nil }
    if rank <= Double(horizon.topN) { return .entry }
    if rank > Double(horizon.exitRank(universeSize: universeSize)) { return .exit }
    return nil
}

/// Whether a rank is inside the buy band -- rows.py's `in_buy_band`,
/// rescore.js's `inBuyBand`. Drives the highlighted rank badge.
public func inBuyBand(_ rank: Double?, horizon: Horizon) -> Bool {
    guard let rank else { return false }
    return rank <= Double(horizon.topN)
}
