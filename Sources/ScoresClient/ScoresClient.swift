import Dependencies
import DependenciesMacros
import MomentumKit

/// Reads `v_recent_scores`: the last 20 scans (sector_momentum's HISTORY_SCANS, the window Python reads), every region. Signed-in only.
///
/// Interface only; the live implementation lives in `SupabaseLive`.
@DependencyClient
public struct ScoresClient: Sendable {
    public var fetchRecentScores: @Sendable () async throws -> [ScoreRow]
}

public enum ScoresError: Error, Equatable, Sendable {
    /// No usable session: the refresh token is gone or was revoked.
    case signedOut
}

extension DependencyValues {
    public var scoresClient: ScoresClient {
        get { self[ScoresClient.self] }
        set { self[ScoresClient.self] = newValue }
    }
}
