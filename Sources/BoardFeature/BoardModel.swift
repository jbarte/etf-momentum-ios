import BoardCacheClient
import Dependencies
import FeedClient
import Foundation
import MomentumKit
import Observation
import ScoresClient

public enum BoardError: LocalizedError, Equatable, Sendable {
    /// The response had no row in a configured cohort, or the config had no presets.
    case noScores

    public var errorDescription: String? {
        switch self {
        case .noScores: "The latest scan came back empty."
        }
    }
}

/// The last load's outcome, and the board derived from it for a preset.
@MainActor
@Observable
public final class BoardModel {
    public enum Outcome: Equatable, Sendable {
        /// No usable session -- the app returns to sign-in.
        case signedOut
        case live(BoardSnapshot)
        /// A fetch failed; showing the last good board, with why.
        case cached(BoardSnapshot, reason: String)
        /// A fetch failed and there is nothing to fall back to.
        case failed(String)
    }

    public private(set) var outcome: Outcome?
    public private(set) var isLoading = false

    // Resolved when the model is created, so overrides must wrap the
    // construction of the model (see the previews and tests).
    @ObservationIgnored @Dependency(\.scoresClient) private var scoresClient
    @ObservationIgnored @Dependency(\.feedClient) private var feedClient
    @ObservationIgnored @Dependency(\.boardCacheClient) private var cache
    @ObservationIgnored @Dependency(\.date) private var date

    public init() {}

    /// Both fetches succeed -> `.live`, and cached. A rejected session ->
    /// `.signedOut`. Anything else -> the last good board as `.cached`, or
    /// `.failed` when there is none. Never guesses a preset or invents a band.
    public func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            async let feed = feedClient.fetchConfig()
            async let rows = scoresClient.fetchRecentScores()
            // Scores first: a rejected session must win over a feed error that
            // happens at the same time, or the reader would sit on a stale
            // cached board instead of being sent back to sign in.
            let fetchedRows = try await rows
            let snapshot = BoardSnapshot(config: try await feed, rows: fetchedRows)
            guard snapshot.hasBoard else { throw BoardError.noScores }
            try? await cache.save(snapshot)
            outcome = .live(snapshot)
        } catch ScoresError.signedOut {
            outcome = .signedOut
        } catch is CancellationError {
            // The view went away mid-request; keep whatever is on screen.
        } catch {
            if let cached = await cache.load() {
                outcome = .cached(cached, reason: error.localizedDescription)
            } else {
                outcome = .failed(error.localizedDescription)
            }
        }
    }

    /// On sign-out: forget the board, on screen and on disk.
    public func reset() async {
        outcome = nil
        await cache.clear()
    }

    public var snapshot: BoardSnapshot? {
        switch outcome {
        case .live(let snapshot), .cached(let snapshot, _): snapshot
        default: nil
        }
    }

    /// Why the board on screen is not fresh, if it isn't.
    public var cachedReason: String? {
        if case .cached(_, let reason) = outcome { reason } else { nil }
    }

    /// The board for a preset: the saved one if it still exists, else the
    /// configured default.
    public func board(horizonKey: String?) -> Board? {
        guard let snapshot, let horizon = snapshot.config.horizon(forKey: horizonKey) else { return nil }
        return buildBoard(rows: snapshot.rows, config: snapshot.config, horizon: horizon)
    }

    /// Whether the newest scan is too old to present as current.
    public func isStale(_ board: Board) -> Bool {
        ScanDate.isStale(board.runAt, now: date.now)
    }
}
