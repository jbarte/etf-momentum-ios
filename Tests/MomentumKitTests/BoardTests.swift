import Foundation
import Testing
@testable import MomentumKit

private let medium = Horizon(key: "medium", label: "Medium", rebalance: "M", topN: 2, bufferFrac: 0.25)
private let long = Horizon(key: "long", label: "Long", rebalance: "2M", topN: 3, bufferFrac: 0.5)

private func config(universe: [String] = ["Alpha", "Bravo", "Charlie"]) -> FeedConfig {
    FeedConfig(defaultHorizon: "medium", cohorts: ["THEME"], horizons: [medium, long],
               universe: universe.map {
                   UniverseEntry(region: "THEME", theme: $0, ticker: $0.prefix(3).uppercased(),
                                 unbuyable: $0 == "Charlie")
               })
}

private func row(_ theme: String, rank: Double?, scan: Int = 2, region: String = "THEME") -> ScoreRow {
    ScoreRow(scanID: scan, runAt: "2026-09-1\(scan)T11:00:00+00:00", region: region, theme: theme,
             levelScore: 0.1, changeScore: -0.1, composite: 0.2, rank: rank)
}

@Suite("Building the board")
struct BoardTests {
    @Test func retiredCohortRowsAreIgnored() throws {
        let board = try #require(buildBoard(
            rows: [row("Alpha", rank: 1), row("Technology", rank: 0.5, region: "US")],
            config: config(), horizon: medium))
        #expect(board.rows.map(\.theme) == ["Alpha"])
    }

    @Test func universeSizeComesFromTheLatestScanNotTheConfig() throws {
        // "Delta" was scored before the published config caught up: it still
        // counts, and still renders -- just without a ticker.
        let rows = ["Alpha", "Bravo", "Charlie", "Delta"].enumerated().map {
            row($1, rank: Double($0 + 1))
        }
        let board = try #require(buildBoard(rows: rows, config: config(), horizon: medium))
        #expect(board.universeSize == 4)
        #expect(board.exitRank == 2 + 1)          // 2 + round_half_up(0.25 * 4)
        let delta = try #require(board.rows.first { $0.theme == "Delta" })
        #expect(delta.ticker == nil && delta.unbuyable == false)
    }

    @Test func tickerAndUnbuyableComeFromConfig() throws {
        let board = try #require(buildBoard(rows: [row("Charlie", rank: 1)], config: config(), horizon: medium))
        #expect(board.rows[0].ticker == "CHA" && board.rows[0].unbuyable)
    }

    @Test func rowsSortByRankWithUnrankedLast() throws {
        let board = try #require(buildBoard(
            rows: [row("Bravo", rank: nil), row("Charlie", rank: 2), row("Alpha", rank: 1)],
            config: config(), horizon: medium))
        #expect(board.rows.map(\.theme) == ["Alpha", "Charlie", "Bravo"])
        #expect(board.rows.last?.rankText == "—")
    }

    @Test func setupAndSectionFollowTheHorizon() throws {
        let rows = (1...8).map { row("T\($0)", rank: Double($0)) }
        let board = try #require(buildBoard(rows: rows, config: config(), horizon: medium))
        // topN 2, exitRank 2 + round_half_up(0.25 * 8) = 4
        #expect(board.rows.map(\.setup) == [.entry, .entry, nil, nil, .exit, .exit, .exit, .exit])
        #expect(board.rows.map(\.section) == [.buy, .buy, .hold, .hold, .out, .out, .out, .out])
        #expect(boardItems(board.rows).map(\.id).filter { $0.hasPrefix("cut:") } ==
                ["cut:\(CutLabel.buy)", "cut:\(CutLabel.hold)"])
    }

    @Test func cutLinesNeedARowBelowThem() throws {
        let board = try #require(buildBoard(rows: [row("Alpha", rank: 1)], config: config(), horizon: medium))
        #expect(boardItems(board.rows) == [.row(board.rows[0])])
    }

    @Test func noCohortRowsMeansNoBoard() {
        #expect(buildBoard(rows: [], config: config(), horizon: medium) == nil)
        #expect(buildBoard(rows: [row("Technology", rank: 1, region: "US")], config: config(), horizon: medium) == nil)
    }

    @Test func horizonFallsBackToTheDefaultThenTheFirst() {
        #expect(config().horizon(forKey: "long")?.key == "long")
        #expect(config().horizon(forKey: "retired-preset")?.key == "medium")
        #expect(config().horizon(forKey: nil)?.key == "medium")
        let noDefault = FeedConfig(defaultHorizon: "gone", cohorts: ["THEME"], horizons: [long], universe: [])
        #expect(noDefault.horizon(forKey: nil)?.key == "long")
    }

    @Test func tiedRanksShowTheirAverage() throws {
        let board = try #require(buildBoard(rows: [row("Alpha", rank: 1.5), row("Bravo", rank: 1.5)],
                                            config: config(), horizon: medium))
        #expect(board.rows.map(\.rankText) == ["1.5", "1.5"])
    }
}

@Suite("Feed, dates and formatting")
struct FeedAndFormattingTests {
    @Test func publishedDataJsonDecodes() throws {
        let url = try #require(Bundle.module.url(forResource: "data-json-v2", withExtension: "json",
                                                 subdirectory: "Fixtures"))
        let feed = try JSONDecoder().decode(DataFeed.self, from: Data(contentsOf: url))
        let config = try #require(feed.config)
        #expect(feed.schemaVersion == 2)
        #expect(config.cohorts == ["THEME"])
        #expect(config.horizon(forKey: nil)?.key == config.defaultHorizon)
        #expect(config.horizons.allSatisfy { !$0.reviewDates.isEmpty })
        #expect(config.universe.contains { $0.theme == "Shipping" && $0.unbuyable })
    }

    @Test func aVersionOneFeedHasNoConfig() throws {
        let feed = try JSONDecoder().decode(DataFeed.self, from: Data(#"{"schema_version":1,"themes":[]}"#.utf8))
        #expect(feed.schemaVersion == 1 && feed.config == nil)
    }

    @Test func runAtParsesInBothShapes() throws {
        let a = try #require(ScanDate.parse("2026-09-18T11:05:52.187557+00:00"))
        let b = try #require(ScanDate.parse("2026-09-18 11:05:52"))
        #expect(a == b)
        #expect(ScanDate.day("2026-09-18T11:05:52.187557+00:00") == "2026-09-18")
    }

    @Test func staleAfterTwoDays() throws {
        let scanned = try #require(ScanDate.parse("2026-09-18T11:00:00+00:00"))
        #expect(!ScanDate.isStale("2026-09-18T11:00:00+00:00", now: scanned.addingTimeInterval(47 * 3600)))
        #expect(ScanDate.isStale("2026-09-18T11:00:00+00:00", now: scanned.addingTimeInterval(49 * 3600)))
        #expect(ScanDate.isStale("not a date"))
    }

    @Test func barFractionClampsAtFullScale() {
        #expect(BarScale.fraction(0.8) == 0.5)
        #expect(BarScale.fraction(-3.2) == 1)
        #expect(BarScale.fraction(nil) == nil)
    }

    @Test func signedTextUsesARealMinus() {
        #expect(signedText(1.337) == "+1.34")
        #expect(signedText(-0.7) == "\u{2212}0.70")
        #expect(signedText(nil) == "—")
    }
}
