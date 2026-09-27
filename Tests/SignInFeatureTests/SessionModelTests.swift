import SignInClient
import Dependencies
import DependenciesTestSupport
import Foundation
import SignInFeature
import Testing

extension BaseSuite {
    @MainActor
    @Suite
    struct SessionModelTests {
        @Test(.dependency(\.signInClient, .signedIn(email: "me@example.invalid")))
        func restoreFindsASession() async {
            let model = SessionModel()

            await model.restore()

            #expect(model.state == .signedIn(email: "me@example.invalid"))
        }

        /// No session at launch (e.g. revoked while the app was closed) also
        /// forgets the previous session's cached board.
        @Test(.dependency(\.signInClient, .signedOut()))
        func restoreWithNoSessionIsSignedOutAndRunsTheHook() async {
            let hookRan = LockIsolated(false)
            let model = SessionModel(onSignOut: { hookRan.setValue(true) })

            await model.restore()

            #expect(model.state == .signedOut)
            #expect(hookRan.value)
        }

        @Test func sendLinkTrimsAndLowercasesTheEmail() async {
            let sentTo = LockIsolated<String?>(nil)
            let model = withDependencies {
                $0.signInClient.sendLink = { email in sentTo.setValue(email) }
            } operation: {
                SessionModel()
            }

            await model.sendLink(to: "  Me@Example.INVALID \n")

            #expect(sentTo.value == "me@example.invalid")
            #expect(model.linkSentTo == "me@example.invalid")
            #expect(model.errorMessage == nil)
            #expect(model.isWorking == false)
        }

        @Test(.dependency(\.signInClient, .failing(TestError())))
        func aRejectedEmailShowsTheServersMessage() async {
            let model = SessionModel()

            await model.sendLink(to: "stranger@example.invalid")

            #expect(model.linkSentTo == nil)
            #expect(model.errorMessage == TestError().localizedDescription)
            #expect(model.isWorking == false)
        }

        @Test func openingTheLinkSignsIn() async {
            let opened = LockIsolated<URL?>(nil)
            let model = withDependencies {
                $0.signInClient.currentUserEmail = { nil }
                $0.signInClient.sendLink = { _ in }
                $0.signInClient.completeSignIn = { url in
                    opened.setValue(url)
                    return "me@example.invalid"
                }
            } operation: {
                SessionModel()
            }
            await model.restore()
            await model.sendLink(to: "me@example.invalid")

            await model.completeSignIn(from: link)

            #expect(opened.value == link)
            #expect(model.state == .signedIn(email: "me@example.invalid"))
            #expect(model.linkSentTo == nil)
        }

        /// The app was closed while the reader was in Mail, so the link is what
        /// launches it: nothing was sent in this run, and the launch-time
        /// restore hasn't happened yet.
        @Test(.dependency(\.signInClient, .signedOut(linkSignsInAs: "me@example.invalid")))
        func aLinkThatLaunchesTheAppSignsIn() async {
            let model = SessionModel()

            await model.completeSignIn(from: link)

            #expect(model.state == .signedIn(email: "me@example.invalid"))
        }

        /// The restore finding no stored session must not land after the link
        /// has signed in, sending the reader back to the sign-in screen.
        @Test(.timeLimit(.minutes(1)))
        func aSlowRestoreCannotUndoTheLinksSignIn() async {
            let gate = Gate()
            let restoreStarted = LockIsolated(false)
            let lookups = LockIsolated(0)
            let model = withDependencies {
                $0.signInClient.currentUserEmail = {
                    lookups.withValue { $0 += 1 }
                    restoreStarted.setValue(true)
                    await gate.wait()
                    return nil
                }
                $0.signInClient.completeSignIn = { _ in "me@example.invalid" }
            } operation: {
                SessionModel()
            }

            let restoring = Task { await model.restore() }
            while !restoreStarted.value { await Task.yield() }
            let signingIn = Task { await model.completeSignIn(from: link) }
            for _ in 0..<100 { await Task.yield() }
            gate.open()
            await restoring.value
            await signingIn.value

            #expect(model.state == .signedIn(email: "me@example.invalid"))
            #expect(lookups.value == 1)
        }

        @Test(.dependency(\.signInClient, .failing(TestError())))
        func anExpiredLinkShowsTheServersMessage() async {
            let model = SessionModel()

            await model.completeSignIn(from: link)

            #expect(model.state == .signedOut)
            #expect(model.errorMessage == TestError().localizedDescription)
        }

        // completeSignIn is left unimplemented: calling it would be an issue.
        @Test(.dependency(\.signInClient.currentUserEmail, { "me@example.invalid" }))
        func aLinkWhileSignedInIsIgnored() async {
            let model = SessionModel()

            await model.completeSignIn(from: link)

            #expect(model.state == .signedIn(email: "me@example.invalid"))
        }

        @Test func signingOutRunsTheHookEvenIfTheServerFails() async {
            let hookRan = LockIsolated(false)
            let model = withDependencies {
                $0.signInClient.currentUserEmail = { "me@example.invalid" }
                $0.signInClient.signOut = { throw TestError() }
            } operation: {
                SessionModel(onSignOut: { hookRan.setValue(true) })
            }
            await model.restore()

            await model.signOut()

            #expect(hookRan.value)
            #expect(model.state == .signedOut)
        }

        @Test func anExpiredSessionRunsTheHook() async {
            let hookRan = LockIsolated(false)
            let model = SessionModel(onSignOut: { hookRan.setValue(true) })

            await model.sessionExpired()

            #expect(hookRan.value)
            #expect(model.state == .signedOut)
        }

        // No override: the test value is unimplemented, so calling it is
        // reported as an issue. This proves the tripwire works.
        @Test func unstubbedClientReportsIssue() async {
            let model = SessionModel()

            await withKnownIssue {
                await model.sendLink(to: "me@example.invalid")
            }

            #expect(model.errorMessage != nil)
        }
    }
}

private let link = URL(string: "etfmomentum://login-callback?code=test-code")!

private struct TestError: LocalizedError {
    var errorDescription: String? { "Signups not allowed for otp" }
}

/// Holds a stubbed call until the test opens it.
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
