import Dependencies
import DependenciesMacros
import MomentumKit

/// The last good board, kept on disk so a failed load can still show
/// something. Cleared on sign-out: it is signed-in-only data and should not
/// outlive the session on the device.
@DependencyClient
public struct BoardCacheClient: Sendable {
    public var load: @Sendable () async -> BoardSnapshot? = { nil }
    public var save: @Sendable (_ snapshot: BoardSnapshot) async throws -> Void
    public var clear: @Sendable () async -> Void
}

extension DependencyValues {
    public var boardCacheClient: BoardCacheClient {
        get { self[BoardCacheClient.self] }
        set { self[BoardCacheClient.self] = newValue }
    }
}
