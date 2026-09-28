import Dependencies
import DependenciesMacros
import Foundation

/// Invite-only sign-in with an emailed magic link that opens the app.
///
/// This module is the interface only. The live implementation lives in
/// `SupabaseLive`, so features, tests and previews never build supabase-swift.
///
/// The link returns to the app through the `etfmomentum://` URL scheme, which a
/// free developer account can register (universal links would need Associated
/// Domains, which it cannot). An emailed code would avoid the round trip, but
/// Supabase only lets you add the code to its email with custom SMTP.
@DependencyClient
public struct SignInClient: Sendable {
    /// The signed-in user's email from the session stored on the device, even
    /// if its access token has expired -- so a reader who is offline still
    /// reaches their cached board. nil when there is no stored session.
    public var currentUserEmail: @Sendable () async -> String? = { nil }
    /// Emails a sign-in link that opens this app. Never creates an account
    /// (invite-only).
    public var sendLink: @Sendable (_ email: String) async throws -> Void
    /// Completes sign-in from the link the app was opened with, returning the
    /// signed-in email. Throws the server's message for an expired, used or
    /// superseded link.
    public var completeSignIn: @Sendable (_ url: URL) async throws -> String
    public var signOut: @Sendable () async throws -> Void
}

extension SignInClient {
    /// Where the emailed link returns to the app. Supabase must list it under
    /// Authentication -> URL Configuration -> Redirect URLs, or the link opens
    /// the website instead; the scheme is registered in App/Info.plist.
    public static let redirectURL = URL(string: "etfmomentum://login-callback")!
}

extension DependencyValues {
    public var signInClient: SignInClient {
        get { self[SignInClient.self] }
        set { self[SignInClient.self] = newValue }
    }
}
