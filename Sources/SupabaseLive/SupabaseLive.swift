import Dependencies
import Foundation
import MomentumKit
import Supabase
@_exported import SignInClient
@_exported import ScoresClient

// The live implementations sit in their own module so that features, tests and
// previews depend only on the lightweight interfaces and never build
// supabase-swift.
//
// One client for both: the scores query is authorised by the signed-in
// session, so auth and data must share it -- the web learned the same lesson
// (dashboard/assets/supabase-client.js). A global `let` is created lazily, so
// stub mode and tests never construct it.
private let supabase = SupabaseClient(
    supabaseURL: SupabaseConfig.url,
    supabaseKey: SupabaseConfig.publishableKey
)

/// Where the emailed link sends the reader after Supabase has checked it. It
/// must be listed under Authentication -> URL Configuration -> Redirect URLs,
/// or Supabase falls back to the website. The scheme is registered in
/// App/Info.plist.
let signInRedirectURL = URL(string: "etfmomentum://login-callback")!

extension SignInClient: DependencyKey {
    public static let liveValue = Self(
        currentUserEmail: {
            // The LOCAL session, even if its access token has expired. Asking
            // `auth.session` instead would try a network refresh, and offline
            // that fails -- which would send a reader with a perfectly valid
            // refresh token to the sign-in screen instead of their cached
            // board. The board's own load refreshes the token, and reports a
            // session the server has really rejected (ScoresError.signedOut).
            supabase.auth.currentSession?.user.email
        },
        sendLink: { email in
            // Invite-only, as on the web (auth.js): never create an account.
            // supabase-swift uses the PKCE flow: it keeps a code verifier on
            // this device, so the link only completes here, and a newer link
            // replaces the verifier of an older one.
            try await supabase.auth.signInWithOTP(
                email: email,
                redirectTo: signInRedirectURL,
                shouldCreateUser: false
            )
        },
        completeSignIn: { url in
            // An expired or used link arrives as ...#error_description=...,
            // which this throws as the server's message.
            let session = try await supabase.auth.session(from: url)
            // Always set for a user who signed in by email.
            return session.user.email ?? ""
        },
        signOut: {
            try await supabase.auth.signOut()
        }
    )
}

extension ScoresClient: DependencyKey {
    public static let liveValue = Self(
        fetchRecentScores: {
            do {
                _ = try await supabase.auth.session
            } catch where isSignedOutError(error) {
                throw ScoresError.signedOut
            }
            // Any other error (offline, a timeout, a 5xx) propagates as it is,
            // so the board falls back to the last good board it cached.
            // Same columns and order as auth.js's upgradeLeaderboard().
            return try await supabase.from("v_recent_scores")
                .select("scan_id, run_at, region, gics_sector, level_score, change_score, data_score, sentiment_score, composite, rank")
                .order("scan_id", ascending: true)
                .order("rank", ascending: true)
                .execute()
                .value
        }
    )
}

/// Whether an error from `auth.session` means the reader is really signed out:
/// there is no session, or the server rejected the refresh token. Only these
/// may send the reader back to sign in, because that path deletes the cached
/// board. A refresh that could not reach the server is NOT one of them -- that
/// is the offline case the cached board exists for.
func isSignedOutError(_ error: any Error) -> Bool {
    guard let error = error as? AuthError else { return false }
    switch error {
    case .sessionMissing:
        return true
    case .api(_, _, _, let response):
        // 4xx from the token endpoint: an invalid, revoked or reused refresh
        // token. 429 is a rate limit, not a verdict on the session.
        return (400..<500).contains(response.statusCode) && response.statusCode != 429
    default:
        return false
    }
}
