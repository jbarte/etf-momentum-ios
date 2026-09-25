import SignInClient
import Dependencies
import Foundation
import Observation

/// Who is signed in, and the two-step email-code sign-in.
@MainActor
@Observable
public final class SessionModel {
    public enum State: Equatable, Sendable {
        case checking
        case signedOut
        case signedIn(email: String)
    }

    public private(set) var state: State = .checking
    /// Set once a code has been sent; the sign-in screen then asks for it.
    public private(set) var codeSentTo: String?
    public private(set) var errorMessage: String?
    public private(set) var isWorking = false

    // Resolved when the model is created, so overrides must wrap the
    // construction of the model (see the previews and tests).
    @ObservationIgnored
    @Dependency(\.signInClient) private var signInClient

    /// Runs on every sign-out, voluntary or not -- the app uses it to forget
    /// the board, on screen and on disk.
    private let onSignOut: @MainActor () async -> Void

    public init(onSignOut: @escaping @MainActor () async -> Void = {}) {
        self.onSignOut = onSignOut
    }

    public func restore() async {
        if let email = await signInClient.currentUserEmail() {
            state = .signedIn(email: email)
        } else {
            state = .signedOut
        }
    }

    public func sendCode(to email: String) async {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !email.isEmpty else { return }
        await perform {
            try await self.signInClient.sendCode(email: email)
            self.codeSentTo = email
        }
    }

    public func verify(code: String) async {
        guard let email = codeSentTo else { return }
        await perform {
            try await self.signInClient.verify(email: email, code: code)
            self.codeSentTo = nil
            self.state = .signedIn(email: email)
        }
    }

    public func useDifferentEmail() {
        codeSentTo = nil
        errorMessage = nil
    }

    public func signOut() async {
        // Signed out locally even if the server call fails: the reader asked
        // to leave, and the board is forgotten either way.
        try? await signInClient.signOut()
        await sessionEnded()
    }

    /// The board found no usable session (e.g. the refresh token was revoked).
    public func sessionExpired() async {
        await sessionEnded()
    }

    /// Supabase's email OTP length is configurable: 6 by default, up to 10.
    public static func isPlausibleCode(_ code: String) -> Bool {
        (6...10).contains(code.count) && code.allSatisfy(\.isNumber)
    }

    private func sessionEnded() async {
        await onSignOut()
        codeSentTo = nil
        state = .signedOut
    }

    private func perform(_ work: @MainActor () async throws -> Void) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await work()
        } catch is CancellationError {
            // The view went away mid-request; that isn't an error to show.
        } catch {
            // Supabase's AuthError is a LocalizedError carrying the server's own
            // message (rate limits, "Signups not allowed for otp", ...).
            errorMessage = error.localizedDescription
        }
    }
}
