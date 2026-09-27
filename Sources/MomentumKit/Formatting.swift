import Foundation

/// When the board's data is from. `scans.run_at` is TEXT the pipeline writes as
/// UTC isoformat(); second precision is plenty here, so only the first 19
/// characters are parsed (which also tolerates a space instead of the "T").
public enum ScanDate {
    public static func parse(_ runAt: String) -> Date? {
        let head = String(runAt.prefix(19)).replacingOccurrences(of: " ", with: "T")
        return try? Date.ISO8601FormatStyle().parse(head + "Z")
    }

    /// The UTC calendar day, as the web prints it (`scan_date[:10]`).
    public static func day(_ runAt: String) -> String {
        String(runAt.prefix(10))
    }

    /// Scans run daily, seven days a week (weekends replay Friday but still
    /// run), so a newest scan older than two days means the pipeline stalled.
    public static let staleAfter: TimeInterval = 48 * 60 * 60

    public static func isStale(_ runAt: String, now: Date = Date()) -> Bool {
        guard let date = parse(runAt) else { return true }
        return now.timeIntervalSince(date) > staleAfter
    }
}

/// The composite and its Level/Change parts are means of z-scores -- signed and
/// centred on zero -- so they're drawn as bars from the centre out. The scale is
/// FIXED (rescore.js / rows.py COMPOSITE_FULL_SCALE) rather than per-scan, so
/// bar lengths stay comparable between scans; values beyond it clamp.
public enum BarScale {
    public static let fullScale = 1.6

    /// How much of HALF the track to fill, 0...1; nil for a missing value.
    public static func fraction(_ value: Double?) -> Double? {
        value.map { min(abs($0) / fullScale, 1) }
    }
}

/// rescore.js:signedFmt -- two decimals, explicit sign, and a real minus sign
/// (U+2212) rather than a hyphen. "—" when missing.
public func signedText(_ value: Double?) -> String {
    guard let value else { return "—" }
    return (value >= 0 ? "+" : "\u{2212}") + String(format: "%.2f", abs(value))
}
