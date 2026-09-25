import Dependencies
import DependenciesMacros

/// Invite-only sign-in with an emailed one-time code.
///
/// This module is the interface only. The live implementation lives in
/// `SupabaseLive`, so features, tests and previews never build supabase-swift.
/// A code rather than the magic link, because returning to the app from a link
/// needs Associated Domains, which a free developer account cannot enable.
@DependencyClient
public struct SignInClient: Sendable {
    /// The signed-in user's email, refreshing an expired session if it can;
    /// nil when there is no usable session.
    public var currentUserEmail: @Sendable () async -> String? = { nil }
    /// Emails a one-time code. Never creates an account (invite-only).
    public var sendCode: @Sendable (_ email: String) async throws -> Void
    public var verify: @Sendable (_ email: String, _ code: String) async throws -> Void
    public var signOut: @Sendable () async throws -> Void
}

extension DependencyValues {
    public var signInClient: SignInClient {
        get { self[SignInClient.self] }
        set { self[SignInClient.self] = newValue }
    }
}
