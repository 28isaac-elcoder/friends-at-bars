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

    /// Tight radius used to confirm presence (write to Supabase) — "at the bar".
    static let venueRadiusMeters: Double = 100
    /// Larger OS geofence / approach radius — wakes the app before the tight radius.
    static let venueApproachRadiusMeters: Double = 400
    /// Outside this distance, sticky exit countdown starts (same as presence for a tight leave).
    static let venueExitRadiusMeters: Double = 100
    /// Clearly gone: clear sticky / deactivate immediately (no 90s wait).
    static let venueHardClearRadiusMeters: Double = 250
    /// Consecutive inside-presence fixes required before first upsert (dwell).
    static let presenceDwellFixCount: Int = 2
    /// Seconds continuously outside the exit radius before deactivating sticky presence
    /// (skipped when past hard-clear radius).
    static let presenceExitConfirmSeconds: TimeInterval = 90
    /// Ignore a GPS sample for exit decisions when horizontalAccuracy is worse than this.
    static let presenceMaxAccuracyForExitMeters: Double = 200

    static let maxChatChars = 150

    /// How often we re-upsert `live_locations` while staying at the same bar.
    static let liveLocationHeartbeatMs: Int = 15 * 60 * 1000 // 15 minutes
    /// Rows older than this are excluded from headcounts (heartbeat + grace).
    static let liveLocationCountMaxAgeSeconds: Int = 18 * 60 // 18 minutes
    /// Matches chat RPC freshness window (`create_chat_post`).
    static let liveLocationChatFreshnessSeconds: Int = liveLocationCountMaxAgeSeconds

    /// Reports inside this window count toward the "N reports" threshold.
    static let waitTimeCountingWindowSeconds: Int = 20 * 60
    /// Longest influence window (45+ bucket) used when fetching reports.
    static let waitTimeMaxInfluenceSeconds: Int = 45 * 60
}
