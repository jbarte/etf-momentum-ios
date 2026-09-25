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

extension SignInClient: DependencyKey {
    public static let liveValue = Self(
        currentUserEmail: {
            // `session` refreshes an expired session and throws when there is
            // none. Used instead of the authStateChanges stream, whose
            // initialSession semantics change in supabase-swift v3.
            try? await supabase.auth.session.user.email
        },
        sendCode: { email in
            // Invite-only, as on the web (auth.js): never create an account.
            try await supabase.auth.signInWithOTP(email: email, shouldCreateUser: false)
        },
        verify: { email, code in
            _ = try await supabase.auth.verifyOTP(email: email, token: code, type: .email)
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
            } catch {
                throw ScoresError.signedOut
            }
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
