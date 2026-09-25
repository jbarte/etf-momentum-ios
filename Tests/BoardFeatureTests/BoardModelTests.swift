import BoardCacheClient
import BoardFeature
import Dependencies
import DependenciesTestSupport
import FeedClient
import Foundation
import MomentumKit
import ScoresClient
import Testing

private let config = SampleData.config
private let rows = SampleData.scores(now: Date(timeIntervalSince1970: 1_790_000_000))
private let snapshot = BoardSnapshot(config: config, rows: rows)

extension BaseSuite {
    @MainActor
    @Suite
    struct BoardModelTests {
        @Test func aSuccessfulLoadIsLiveAndCached() async {
            let saved = LockIsolated<BoardSnapshot?>(nil)
            let model = withDependencies {
                $0.feedClient = .mock(config)
                $0.scoresClient = .mock(rows)
                $0.boardCacheClient.save = { saved.setValue($0) }
            } operation: {
                BoardModel()
            }

            await model.load()

            #expect(model.outcome == .live(snapshot))
            #expect(saved.value == snapshot)
            #expect(model.isLoading == false)
        }

        @Test(.dependencies {
            $0.feedClient = .mock(config)
            $0.scoresClient = .failing(ScoresError.signedOut)
        })
        func aRejectedSessionIsSignedOutAndReported() async {
            let reported = LockIsolated(false)
            let model = BoardModel()
            model.onSessionExpired = { reported.setValue(true) }

            await model.load()

            #expect(model.outcome == .signedOut)
            #expect(reported.value)
        }

        /// A sign-out while a load is in flight: the load's result belongs to
        /// the previous session and must write nothing, on screen or on disk.
        @Test(.timeLimit(.minutes(1)))
        func aSignOutDuringALoadDiscardsItsResult() async {
            let gate = Gate()
            let saved = LockIsolated(false)
            let model = withDependencies {
                $0.feedClient = .mock(config)
                $0.scoresClient.fetchRecentScores = {
                    await gate.wait()
                    return rows
                }
                $0.boardCacheClient = .inMemory()
                $0.boardCacheClient.save = { _ in saved.setValue(true) }
            } operation: {
                BoardModel()
            }

            let loading = Task { await model.load() }
            while !model.isLoading { await Task.yield() }
            await model.reset()
            gate.open()
            await loading.value

            #expect(model.outcome == nil)
            #expect(model.isLoading == false)
            #expect(saved.value == false)
        }

        /// Pull-to-refresh during a load waits for that load instead of
        /// returning at once, and does not start a second request.
        @Test(.timeLimit(.minutes(1)))
        func aRefreshDuringALoadFollowsTheRunningRequest() async {
            let gate = Gate()
            let fetches = LockIsolated(0)
            let model = withDependencies {
                $0.feedClient = .mock(config)
                $0.scoresClient.fetchRecentScores = {
                    fetches.withValue { $0 += 1 }
                    await gate.wait()
                    return rows
                }
                $0.boardCacheClient = .inMemory()
            } operation: {
                BoardModel()
            }

            let first = Task { await model.load() }
            while !model.isLoading { await Task.yield() }
            let refresh = Task { await model.load() }
            await Task.yield()
            gate.open()
            await first.value
            await refresh.value

            #expect(fetches.value == 1)
            #expect(model.outcome == .live(snapshot))
        }

        /// URLSession reports cancellation as URLError(.cancelled). That is the
        /// view going away mid-request, not a failure to show.
        @Test(.dependencies {
            $0.feedClient = .mock(config)
            $0.scoresClient = .failing(URLError(.cancelled))
            $0.boardCacheClient = .inMemory()
        })
        func aCancelledRequestLeavesTheOutcomeAlone() async {
            let model = BoardModel()

            await model.load()

            #expect(model.outcome == nil)
            #expect(model.isLoading == false)
        }

        // A feed error at the same moment must not mask the rejected session,
        // or the reader would sit on a stale cached board instead of signing in.
        @Test(.dependencies {
            $0.feedClient = .failing(FeedError.http(status: 503))
            $0.scoresClient = .failing(ScoresError.signedOut)
        })
        func aRejectedSessionWinsOverAFeedError() async {
            let model = BoardModel()

            await model.load()

            #expect(model.outcome == .signedOut)
        }

        @Test(.dependencies {
            $0.feedClient = .mock(config)
            $0.scoresClient = .failing(TestError())
            $0.boardCacheClient = .inMemory(snapshot)
        })
        func aFailedFetchFallsBackToTheLastGoodBoard() async {
            let model = BoardModel()

            await model.load()

            #expect(model.outcome == .cached(snapshot, reason: TestError().localizedDescription))
            #expect(model.cachedReason == TestError().localizedDescription)
        }

        @Test(.dependencies {
            $0.feedClient = .failing(FeedError.noConfig(schemaVersion: 1))
            $0.scoresClient = .mock(rows)
            $0.boardCacheClient = .inMemory()
        })
        func noConfigAndNoCacheIsAFailure() async {
            let model = BoardModel()

            await model.load()

            #expect(model.outcome == .failed(FeedError.noConfig(schemaVersion: 1).localizedDescription))
            #expect(model.board(horizonKey: nil) == nil)
        }

        @Test(.dependencies {
            $0.feedClient = .mock(config)
            $0.scoresClient = .mock([])
            $0.boardCacheClient = .inMemory()
        })
        func anEmptyResponseIsAFailureNotABlankBoard() async {
            let model = BoardModel()

            await model.load()

            #expect(model.outcome == .failed(BoardError.noScores.localizedDescription))
        }

        @Test(.dependencies {
            $0.feedClient = .mock(config)
            $0.scoresClient = .mock(rows)
            $0.boardCacheClient = .inMemory()
        })
        func theBoardFollowsTheSavedPresetAndFallsBackToTheDefault() async throws {
            let model = BoardModel()
            await model.load()

            #expect(try #require(model.board(horizonKey: "long")).horizon.key == "long")
            #expect(try #require(model.board(horizonKey: "retired")).horizon.key == config.defaultHorizon)
            #expect(try #require(model.board(horizonKey: nil)).rows.count == config.universe.count)
        }

        @Test func stalenessReadsTheDateDependency() async throws {
            let scanned = Date(timeIntervalSince1970: 1_790_000_000)
            func model(now: Date) -> BoardModel {
                withDependencies {
                    $0.feedClient = .mock(config)
                    $0.scoresClient = .mock(SampleData.scores(now: scanned))
                    $0.boardCacheClient = .inMemory()
                    $0.date.now = now
                } operation: {
                    BoardModel()
                }
            }
            let fresh = model(now: scanned)
            let stale = model(now: scanned.addingTimeInterval(3 * 86_400))
            await fresh.load()
            await stale.load()

            #expect(fresh.isStale(try #require(fresh.board(horizonKey: nil))) == false)
            #expect(stale.isStale(try #require(stale.board(horizonKey: nil))) == true)
        }

        @Test func resetForgetsTheBoardAndClearsTheCache() async {
            let cleared = LockIsolated(false)
            let model = withDependencies {
                $0.feedClient = .mock(config)
                $0.scoresClient = .mock(rows)
                $0.boardCacheClient = .inMemory()
                $0.boardCacheClient.clear = { cleared.setValue(true) }
            } operation: {
                BoardModel()
            }
            await model.load()

            await model.reset()

            #expect(model.outcome == nil)
            #expect(cleared.value)
        }

        // No override: the test values are unimplemented, so calling them is
        // reported as an issue. This proves the tripwire works.
        @Test func unstubbedClientsReportIssues() async {
            let model = BoardModel()

            await withKnownIssue {
                await model.load()
            }

            #expect(model.outcome != nil)
        }
    }
}

/// Holds every request until `open()`, then releases ALL of them at once. A
/// regression that starts a second request therefore makes a test fail on
/// its assertions rather than hang waiting for a release that never comes.
private final class Gate: Sendable {
    private let isOpen = LockIsolated(false)

    func open() {
        isOpen.setValue(true)
    }

    func wait() async {
        while !isOpen.value {
            await Task.yield()
        }
    }
}

private struct TestError: LocalizedError {
    var errorDescription: String? { "The network connection was lost." }
}
