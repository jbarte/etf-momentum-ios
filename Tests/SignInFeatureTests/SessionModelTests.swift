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

        @Test(.dependency(\.signInClient, .signedOut))
        func restoreWithNoSessionIsSignedOut() async {
            let model = SessionModel()

            await model.restore()

            #expect(model.state == .signedOut)
        }

        @Test func sendCodeTrimsAndLowercasesTheEmail() async {
            let sentTo = LockIsolated<String?>(nil)
            let model = withDependencies {
                $0.signInClient.sendCode = { email in sentTo.setValue(email) }
            } operation: {
                SessionModel()
            }

            await model.sendCode(to: "  Me@Example.INVALID \n")

            #expect(sentTo.value == "me@example.invalid")
            #expect(model.codeSentTo == "me@example.invalid")
            #expect(model.errorMessage == nil)
            #expect(model.isWorking == false)
        }

        @Test(.dependency(\.signInClient, .failing(TestError())))
        func aRejectedEmailShowsTheServersMessage() async {
            let model = SessionModel()

            await model.sendCode(to: "stranger@example.invalid")

            #expect(model.codeSentTo == nil)
            #expect(model.errorMessage == TestError().localizedDescription)
            #expect(model.isWorking == false)
        }

        @Test func verifyingTheCodeSignsIn() async {
            let verified = LockIsolated<[String]>([])
            let model = withDependencies {
                $0.signInClient.sendCode = { _ in }
                $0.signInClient.verify = { email, code in verified.setValue([email, code]) }
            } operation: {
                SessionModel()
            }

            await model.sendCode(to: "me@example.invalid")
            await model.verify(code: "123456")

            #expect(verified.value == ["me@example.invalid", "123456"])
            #expect(model.state == .signedIn(email: "me@example.invalid"))
            #expect(model.codeSentTo == nil)
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

        @Test(arguments: [("123456", true), ("1234567890", true), ("12345", false),
                          ("12345678901", false), ("12345a", false)])
        func codeLengthFollowsSupabasesConfigurableRange(code: String, plausible: Bool) {
            #expect(SessionModel.isPlausibleCode(code) == plausible)
        }

        // No override: the test value is unimplemented, so calling it is
        // reported as an issue. This proves the tripwire works.
        @Test func unstubbedClientReportsIssue() async {
            let model = SessionModel()

            await withKnownIssue {
                await model.sendCode(to: "me@example.invalid")
            }

            #expect(model.errorMessage != nil)
        }
    }
}

private struct TestError: LocalizedError {
    var errorDescription: String? { "Signups not allowed for otp" }
}
