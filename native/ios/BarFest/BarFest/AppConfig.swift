import Foundation

enum AppConfig {
    static var supabaseURL: String {
        let fromPlist = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String
        if let fromPlist, !fromPlist.isEmpty, !fromPlist.contains("$(") {
            return fromPlist
        }
        return ProcessInfo.processInfo.environment["SUPABASE_URL"]
            ?? "https://YOUR_PROJECT.supabase.co"
    }

    static var supabaseAnonKey: String {
        let fromPlist = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String
        if let fromPlist, !fromPlist.isEmpty, !fromPlist.contains("$(") {
            return fromPlist
        }
        return ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"]
            ?? "YOUR_ANON_KEY"
    }

    static let venueRadiusMeters: Double = 100
    static let maxChatChars = 150
}
