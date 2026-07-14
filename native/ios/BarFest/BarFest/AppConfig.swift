import Foundation

enum AppConfig {
    static var supabaseURL: String {
        let fromPlist = Bundle.main.object(forInfoDictionaryKey: "VITE_SUPABASE_URL") as? String
        if let fromPlist, !fromPlist.isEmpty, !fromPlist.contains("$(") {
            return fromPlist
        }
        return ProcessInfo.processInfo.environment["VITE_SUPABASE_URL"]
            ?? "https://YOUR_PROJECT.supabase.co"
    }

    static var supabaseAnonKey: String {
        let fromPlist =
            Bundle.main.object(forInfoDictionaryKey: "VITE_SUPABASE_PUBLISHABLE_KEY") as? String
        if let fromPlist, !fromPlist.isEmpty, !fromPlist.contains("$(") {
            return fromPlist
        }
        return ProcessInfo.processInfo.environment["VITE_SUPABASE_PUBLISHABLE_KEY"]
            ?? "YOUR_PUBLISHABLE_KEY"
    }

    static let venueRadiusMeters: Double = 100
    static let maxChatChars = 150
}
