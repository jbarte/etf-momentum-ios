import SignInClient
import Dependencies
import Foundation
import Observation

/// Who is signed in, and the magic-link sign-in: send a link, then finish when
/// the app is opened from it.
@MainActor
@Observable
public final class SessionModel {
    public enum State: Equatable, Sendable {
        case checking
        case signedOut
        case signedIn(email: String)
    }

    public private(set) var state: State = .checking
    /// Set once a link has been sent; the sign-in screen then says to open it.
    /// Only in memory: a link opened after the app was closed still signs in,
    /// because the live client keeps what it needs on disk.
    public private(set) var linkSentTo: String?
    public private(set) var errorMessage: String?
    public private(set) var isWorking = false

    // Resolved when the model is created, so overrides must wrap the
    // construction of the model (see the previews and tests).
    @ObservationIgnored
    @Dependency(\.signInClient) private var signInClient

    /// Runs on every sign-out, voluntary or not -- the app uses it to forget
    /// the board, on screen and on disk.
    private let onSignOut: @MainActor () async -> Void

    /// The one launch-time restore. A sign-in link can open the app before the
    /// view has started it; both share this task, so a restore that finishes
    /// late can never overwrite the link's sign-in with "signed out".
    @ObservationIgnored
    private var restoring: Task<Void, Never>?

    /// A link opened twice (a double tap in Mail) is exchanged once: the
    /// second exchange would fail on the spent link after the first signed in.
    @ObservationIgnored
    private var isCompletingSignIn = false

    /// Requests in flight. `isWorking` stays true until the last one ends.
    @ObservationIgnored
    private var requestsInFlight = 0

    public init(onSignOut: @escaping @MainActor () async -> Void = {}) {
        self.onSignOut = onSignOut
    }

    /// Reads the stored session once per launch; later calls wait for that
    /// first read rather than repeating it.
    public func restore() async {
        if restoring == nil {
            restoring = Task { await self.restoreStoredSession() }
        }
        await restoring?.value
    }

    private func restoreStoredSession() async {
        if let email = await signInClient.currentUserEmail() {
            state = .signedIn(email: email)
        } else {
            // No session at all -- signed out, or revoked while the app was
            // closed. Forget any board cached for the previous session too.
            // (An expired token offline still counts as a session: see
            // SignInClient.currentUserEmail.)
            await sessionEnded()
        }
    }

    public func sendLink(to email: String) async {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !email.isEmpty else { return }
        let hadSentALink = linkSentTo != nil
        let sent = await perform {
            try await self.signInClient.sendLink(email: email)
            self.linkSentTo = email
        }
        guard !sent else { return }
        // Asking for a link replaces the key that completes the previous one,
        // even when the request then fails (a rate limit, most likely) -- so
        // there is no working link left to wait for.
        linkSentTo = nil
        if hadSentALink, let error = errorMessage {
            errorMessage = error + " The link sent earlier no longer works; send a new one."
        }
    }

    /// The app was opened from a sign-in link.
    public func completeSignIn(from url: URL) async {
        // Any page or app can open an etfmomentum:// URL; only the sign-in
        // callback is ours to act on.
        guard url.scheme == SignInClient.redirectURL.scheme,
              url.host() == SignInClient.redirectURL.host()
        else { return }
        // Finish the launch-time restore first (see `restoring`). A reader who
        // is already signed in has nothing to complete.
        await restore()
        if case .signedIn = state { return }
        guard !isCompletingSignIn else { return }
        isCompletingSignIn = true
        defer { isCompletingSignIn = false }
        await perform {
            let email = try await self.signInClient.completeSignIn(url: url)
            self.linkSentTo = nil
            self.state = .signedIn(email: email)
        }
    }

    public func useDifferentEmail() {
        linkSentTo = nil
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

    private func sessionEnded() async {
        await onSignOut()
        linkSentTo = nil
        errorMessage = nil
        state = .signedOut
    }

    /// Whether `work` finished without throwing.
    @discardableResult
    private func perform(_ work: @MainActor () async throws -> Void) async -> Bool {
        requestsInFlight += 1
        isWorking = true
        errorMessage = nil
        defer {
            requestsInFlight -= 1
            isWorking = requestsInFlight > 0
        }
        do {
            try await work()
            return true
        } catch is CancellationError {
            // The view went away mid-request; that isn't an error to show.
            return false
        } catch {
            // Supabase's AuthError is a LocalizedError carrying the server's own
            // message (rate limits, "Signups not allowed for otp", ...).
            errorMessage = error.localizedDescription
            return false
        }
    }
}
