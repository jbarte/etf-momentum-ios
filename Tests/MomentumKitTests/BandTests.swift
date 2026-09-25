import Foundation
import Testing
@testable import MomentumKit

@Suite("Band rule matches Python")
struct BandTests {
    @Test func everyFixtureCaseMatches() throws {
        let fixture = try BandFixture.load()
        #expect(fixture.fixture_version == 1)
        #expect(!fixture.band.isEmpty)
        for c in fixture.band {
            let h = Horizon(key: c.horizon, label: c.horizon, rebalance: "",
                            topN: c.top_n, bufferFrac: c.buffer_frac)
            let label = "\(c.horizon) n=\(c.universe_size)"
            #expect(h.exitRank(universeSize: c.universe_size) == c.exit_rank, "\(label) exit rank")
            for r in c.ranks {
                #expect(setupForRank(r.rank, horizon: h, universeSize: c.universe_size) == r.setup,
                        "\(label) rank \(r.rank) setup")
                #expect(inBuyBand(r.rank, horizon: h) == r.in_buy_band, "\(label) rank \(r.rank) band")
            }
        }
    }

    /// The cut lines are drawn from `section`, so it must agree with the
    /// Python band everywhere: buy exactly when in the buy band, out exactly
    /// when past the exit rank.
    @Test func sectionsAgreeWithTheFixture() throws {
        let fixture = try BandFixture.load()
        for c in fixture.band {
            let h = Horizon(key: c.horizon, label: c.horizon, rebalance: "",
                            topN: c.top_n, bufferFrac: c.buffer_frac)
            for r in c.ranks {
                let want: BandSection = r.in_buy_band ? .buy : (r.setup == .exit ? .out : .hold)
                #expect(section(for: r.rank, horizon: h, universeSize: c.universe_size) == want,
                        "\(c.horizon) n=\(c.universe_size) rank \(r.rank)")
            }
        }
    }

    @Test func missingRankHasNoSetupAndIsNotInTheBand() {
        let h = Horizon(key: "medium", label: "Medium", rebalance: "M", topN: 4, bufferFrac: 5.0 / 18)
        #expect(setupForRank(nil, horizon: h, universeSize: 18) == nil)
        #expect(inBuyBand(nil, horizon: h) == false)
    }

    @Test func roundHalfUpRoundsHalvesUpLikePython() {
        // Python's round() is banker's rounding (round(2.5) == 2); the band
        // uses _round_half_up precisely to avoid that.
        #expect(roundHalfUp(2.5) == 3)
        #expect(roundHalfUp(4.5) == 5)
        #expect(roundHalfUp(2.4999) == 2)
    }

    @Test func horizonDecodesTheFeedsSnakeCase() throws {
        let json = #"{"key":"medium","label":"Medium","rebalance":"M","top_n":4,"buffer_frac":0.277778,"review_dates":["2026-09-30"]}"#
        let h = try JSONDecoder().decode(Horizon.self, from: Data(json.utf8))
        #expect(h.topN == 4 && h.bufferFrac == 0.277778 && h.reviewDates == ["2026-09-30"])
    }
}
