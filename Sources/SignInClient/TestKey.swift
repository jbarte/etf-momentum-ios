import Dependencies

extension SignInClient: TestDependencyKey {
    /// Every endpoint is unimplemented: a test that calls one without
    /// overriding it fails.
    public static let testValue = Self()

    public static let previewValue = Self.signedIn(email: "preview@example.invalid")
}

extension SignInClient {
    /// A session exists; sending, verifying and signing out all succeed.
    public static func signedIn(email: String) -> Self {
        Self(
            currentUserEmail: { email },
            sendCode: { _ in },
            verify: { _, _ in },
            signOut: {}
        )
    }

    /// No session yet; sending and verifying a code succeed.
    public static let signedOut = Self(
        currentUserEmail: { nil },
        sendCode: { _ in },
        verify: { _, _ in },
        signOut: {}
    )

    /// No session, and sending or verifying a code throws `error`.
    public static func failing(_ error: any Error) -> Self {
        Self(
            currentUserEmail: { nil },
            sendCode: { _ in throw error },
            verify: { _, _ in throw error },
            signOut: {}
        )
    }
}
