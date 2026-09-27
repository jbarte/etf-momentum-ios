import Foundation

/// A real config and invented scores, for previews, tests and the app's
/// `-UseStubData` mode: no network, no session.
public enum SampleData {
    /// Decoded from a bundled copy of the public data.json. Only its config
    /// block is used, and that is public anyway.
    public static let config: FeedConfig = {
        guard let url = Bundle.module.url(forResource: "sample-data", withExtension: "json",
                                          subdirectory: "SampleData"),
              let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(DataFeed.self, from: data).config else {
            preconditionFailure("MomentumKit's bundled sample-data.json is missing or not schema 2")
        }
        return config
    }()

    /// Six daily scans for the config's themes, ending an hour before `now`.
    /// The ranks are INVENTED -- deterministic drift, a third of the themes
    /// climbing and a third falling -- never real scores, so nothing shown in
    /// stub mode is content the gate protects.
    public static func scores(for config: FeedConfig = config, now: Date = Date(),
                              scanCount: Int = 6, latestScanID: Int = 999) -> [ScoreRow] {
        let themes = config.universe.filter { config.cohorts.contains($0.region) }
        var rows: [ScoreRow] = []
        for step in 0..<scanCount {
            let age = scanCount - 1 - step
            let runAt = now.addingTimeInterval(-Double(age) * 86_400 - 3_600).formatted(.iso8601)
            let scored = themes.enumerated().map { i, theme -> (UniverseEntry, Double) in
                let base = Double(themes.count - i) / Double(max(themes.count, 1)) * 2 - 1
                let drift = Double(i % 3 - 1) * Double(age) * 0.35
                return (theme, base + drift)
            }.sorted { $0.1 > $1.1 }
            for (rank, (theme, score)) in scored.enumerated() {
                let composite = (score * 1000).rounded() / 1000
                rows.append(ScoreRow(scanID: latestScanID - age, runAt: runAt, region: theme.region,
                                     theme: theme.theme, levelScore: composite + 0.1,
                                     changeScore: composite - 0.1, dataScore: composite,
                                     sentimentScore: nil, composite: composite, rank: Double(rank + 1)))
            }
        }
        return rows
    }
}
