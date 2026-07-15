import Foundation

struct CatalogVenue: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let area: String
    let latitude: Double
    let longitude: Double
    let radius_m: Int
    let is_test: Bool
    let is_active: Bool
    let sort_order: Int
    let updated_at: String?
}

struct CatalogListing: Codable, Identifiable, Hashable {
    let id: UUID
    let venue_name: String
    let title: String
    let time_label: String
    let details: String
    let area: String
    let listing_kind: String
    let type_labels: [String]
    let days_of_week: [Int]
    let priority: Int
    let is_active: Bool
}

struct ChatPost: Codable, Identifiable, Hashable {
    let id: UUID
    let author_id: String
    let body: String
    let venue_name: String
    var score: Int
    var is_hidden: Bool
    let created_at: String
    let expires_at: String
    var my_vote: Int?
}

struct CheckInRow: Codable, Hashable, Identifiable {
    let id: String
    let user_id: String
    let venue_name: String
    let created_at: String

    enum CodingKeys: String, CodingKey {
        case rawId = "id"
        case user_id, venue_name, created_at
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let uuid = try? c.decode(UUID.self, forKey: .rawId) {
            id = uuid.uuidString
        } else if let s = try? c.decode(String.self, forKey: .rawId) {
            id = s
        } else {
            let uid = try c.decode(String.self, forKey: .user_id)
            let venue = try c.decode(String.self, forKey: .venue_name)
            let created = try c.decode(String.self, forKey: .created_at)
            id = "\(uid)-\(created)-\(venue)"
            user_id = uid
            venue_name = venue
            created_at = created
            return
        }
        user_id = try c.decode(String.self, forKey: .user_id)
        venue_name = try c.decode(String.self, forKey: .venue_name)
        created_at = try c.decode(String.self, forKey: .created_at)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .rawId)
        try c.encode(user_id, forKey: .user_id)
        try c.encode(venue_name, forKey: .venue_name)
        try c.encode(created_at, forKey: .created_at)
    }
}
