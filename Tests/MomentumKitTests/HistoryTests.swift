import Foundation
import Testing
@testable import MomentumKit

@Suite("Delta and Trend match Python")
struct HistoryTests {
    @Test func everySeriesMatches() throws {
        let fixture = try BandFixture.load()
        #expect(Set(fixture.series.map(\.trajectory)) == Set(Trajectory.allCases))
        for s in fixture.series {
            let got = trajectory(forRankSeries: s.ranks)
            #expect(abs(got.slope - s.slope) < 1e-9, "\(s.ranks) slope")
            #expect(got.trajectory == s.trajectory, "\(s.ranks) trend")
        }
    }

    @Test func everyBoardMatches() throws {
        let fixture = try BandFixture.load()
        #expect(!fixture.boards.isEmpty)
        for board in fixture.boards {
            let history = try #require(ScanHistory(rows: board.rows), "\(board.name)")
            #expect(Set(history.latestRows.map(\.key)) == Set(board.expected.keys), "\(board.name) keys")
            for (key, want) in board.expected {
                let got = history.trajectory(for: key)
                #expect(formatDelta(history.deltaRank(for: key)) == want.delta_rank, "\(board.name) \(key) delta")
                #expect(got.trajectory == want.trajectory, "\(board.name) \(key) trend")
                #expect(abs(got.slope - want.slope) < 1e-9, "\(board.name) \(key) slope")
            }
        }
    }

    @Test func weekendReplaysCollapseToTheirLastScan() {
        func scan(_ id: Int, _ rank: Double, _ composite: Double) -> ScoreRow {
            ScoreRow(scanID: id, runAt: "2026-01-0\(id)T11:00:00+00:00", region: "THEME",
                     theme: "Alpha", composite: composite, rank: rank)
        }
        let rows = [scan(1, 2, 0.5), scan(2, 1, 0.9), scan(3, 1, 0.9), scan(4, 1, 0.9)]
        #expect(distinctScanIDs(rows) == [1, 4])
        #expect(ScanHistory(rows: rows)?.deltaRank(for: "THEME|Alpha") == 1)
    }

    /// Python's duplicate-run guard counts the replays TRAILING the latest scan
    /// (sector_momentum#314). Expected values were taken from Python itself:
    /// stuck -> "—"; early replays then a fresh move -> "+1.0"; exactly 7 -> "+1.0".
    @Test(arguments: [
        (replaysAtTheEnd: 8, expected: "—"),
        (replaysAtTheEnd: 7, expected: "+1.0"),
    ])
    func aStuckPipelineShowsNoDelta(replaysAtTheEnd: Int, expected: String) {
        var rows = [historyRow(1, rank: 2, composite: 0.5)]
        for id in 2...(replaysAtTheEnd + 2) { rows.append(historyRow(id, rank: 1, composite: 0.9)) }
        #expect(formatDelta(ScanHistory(rows: rows)?.deltaRank(for: "THEME|Alpha") ?? 0) == expected)
    }

    @Test func replaysEarlyInTheWindowDoNotBlankAHealthyBoard() {
        var rows = (1...9).map { historyRow($0, rank: 2, composite: 0.5) }
        rows.append(historyRow(10, rank: 1, composite: 0.9))
        #expect(formatDelta(ScanHistory(rows: rows)?.deltaRank(for: "THEME|Alpha") ?? 0) == "+1.0")
    }

    private func historyRow(_ id: Int, rank: Double, composite: Double) -> ScoreRow {
        ScoreRow(scanID: id, runAt: "2026-01-\(String(format: "%02d", id))T11:00:00+00:00",
                 region: "THEME", theme: "Alpha", composite: composite, rank: rank)
    }

    @Test func noRowsMeansNoHistory() {
        #expect(ScanHistory(rows: []) == nil)
    }

    @Test func deltaFormatsLikePython() {
        #expect(formatDelta(0) == "—")
        #expect(formatDelta(1) == "+1.0")
        #expect(formatDelta(-0.5) == "-0.5")
    }

    @Test func scoreRowDecodesTheViewsColumns() throws {
        let json = #"{"scan_id":195,"run_at":"2026-09-18T11:05:52.187557+00:00","region":"THEME","gics_sector":"Shipping","level_score":1.1,"change_score":0.8,"data_score":0.95,"sentiment_score":null,"composite":0.95,"rank":1}"#
        let row = try JSONDecoder().decode(ScoreRow.self, from: Data(json.utf8))
        #expect(row.key == "THEME|Shipping" && row.rank == 1 && row.sentimentScore == nil)
    }
}
