import Foundation

/// Shared venue presence gate for Chat + Ranked (mirrors live_locations freshness rules).
enum VenuePresenceGate {
    /// Client-side: engine reports current matched venue (within radius).
    static var currentVenueName: String? {
        VenueLiveLocationEngine.shared.currentState().lastVenue
    }

    static var isAtVenue: Bool { currentVenueName != nil }
}
