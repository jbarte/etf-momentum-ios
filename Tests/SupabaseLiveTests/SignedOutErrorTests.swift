import Foundation
import Supabase
import Testing
@testable import SupabaseLive

@Suite
struct SignedOutErrorTests {
    private func api(status: Int, code: String = "refresh_token_not_found") -> AuthError {
        .api(
            message: "refresh failed",
            errorCode: ErrorCode(code),
            underlyingData: Data(),
            underlyingResponse: HTTPURLResponse(
                url: URL(string: "https://example.supabase.co/auth/v1/token")!,
                statusCode: status, httpVersion: nil, headerFields: nil)!
        )
    }

    @Test func noSessionIsSignedOut() {
        #expect(isSignedOutError(AuthError.sessionMissing))
    }

    @Test(arguments: [400, 401, 403])
    func aRejectedRefreshTokenIsSignedOut(status: Int) {
        #expect(isSignedOutError(api(status: status)))
    }

    /// The offline case the cached board exists for: a refresh that never
    /// reached the server must not sign the reader out and wipe the cache.
    @Test(arguments: [URLError.Code.notConnectedToInternet, .timedOut, .networkConnectionLost])
    func aRefreshThatCouldNotReachTheServerIsNot(code: URLError.Code) {
        #expect(!isSignedOutError(URLError(code)))
    }

    @Test(arguments: [429, 500, 503])
    func rateLimitsAndServerErrorsAreNot(status: Int) {
        #expect(!isSignedOutError(api(status: status, code: "unexpected_failure")))
    }
}
