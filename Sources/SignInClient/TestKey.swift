import Dependencies

extension SignInClient: TestDependencyKey {
    /// Every endpoint is unimplemented: a test that calls one without
    /// overriding it fails.
    public static let testValue = Self()

    public static let previewValue = Self.signedIn(email: "preview@example.invalid")
}

extension SignInClient {
    /// A session exists; sending a link, completing sign-in and signing out
    /// all succeed.
    public static func signedIn(email: String) -> Self {
        Self(
            currentUserEmail: { email },
            sendLink: { _ in },
            completeSignIn: { _ in email },
            signOut: {}
        )
    }

    /// No session yet; sending a link succeeds, and opening it signs in as
    /// `email`.
    public static func signedOut(linkSignsInAs email: String = "me@example.invalid") -> Self {
        Self(
            currentUserEmail: { nil },
            sendLink: { _ in },
            completeSignIn: { _ in email },
            signOut: {}
        )
    }

    /// No session, and sending a link or completing sign-in throws `error`.
    public static func failing(_ error: any Error) -> Self {
        Self(
            currentUserEmail: { nil },
            sendLink: { _ in throw error },
            completeSignIn: { _ in throw error },
            signOut: {}
        )
    }
}
