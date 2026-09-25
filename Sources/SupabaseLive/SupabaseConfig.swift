import Foundation

/// Where the app signs in and reads scores. Both values are public by design:
/// the publishable key is the same one baked into the public dashboard HTML
/// (window.SUPABASE_CONFIG), and protection is RLS at the database, not key
/// secrecy -- see sector_momentum's CLAUDE.md, "Secrets".
enum SupabaseConfig {
    static let url = URL(string: "https://cwhqolfpailtxkiszuvn.supabase.co")!
    static let publishableKey = "sb_publishable_KPGamyDoFP7DAmUPI6VgYA_6uIfUx0n"
}
