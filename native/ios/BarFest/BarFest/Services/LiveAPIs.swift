import Foundation

enum ChatService {
    static func fetchFeed(sort: String) async throws -> [ChatPost] {
        var query: [URLQueryItem] = [
            URLQueryItem(name: "is_hidden", value: "eq.false"),
            URLQueryItem(name: "expires_at", value: "gt.\(ISO8601DateFormatter().string(from: Date()))"),
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "limit", value: "50"),
        ]
        if sort == "popular" {
            query.append(URLQueryItem(name: "order", value: "score.desc,created_at.desc"))
        } else {
            query.append(URLQueryItem(name: "order", value: "created_at.desc"))
        }
        return try await SupabaseClient.shared.get(path: "rest/v1/chat_posts", query: query)
    }

    static func createPost(body: String, venueName: String) async throws {
        try await SupabaseClient.shared.rpcVoid("create_chat_post", params: [
            "p_author_id": AnonymousIdentity.userId(),
            "p_body": body,
            "p_venue_name": venueName,
        ])
    }

    /// direction: "up" | "down" — same direction again clears (RPC behavior).
    static func setVote(postId: UUID, direction: String) async throws {
        try await SupabaseClient.shared.rpcVoid("set_chat_vote", params: [
            "p_voter_id": AnonymousIdentity.userId(),
            "p_post_id": postId.uuidString,
            "p_direction": direction,
        ])
    }

    static func hideOwn(postId: UUID) async throws {
        try await SupabaseClient.shared.rpcVoid("hide_own_chat_post", params: [
            "p_author_id": AnonymousIdentity.userId(),
            "p_post_id": postId.uuidString,
        ])
    }

    static func report(postId: UUID, reason: String?) async throws {
        var params: [String: Any] = [
            "p_reporter_id": AnonymousIdentity.userId(),
            "p_post_id": postId.uuidString,
        ]
        if let reason {
            params["p_reason"] = reason
        } else {
            params["p_reason"] = NSNull()
        }
        try await SupabaseClient.shared.rpcVoid("report_chat_post", params: params)
    }
}

enum LiveLocationService {
    static func venueCounts(maxAgeSeconds: Int = 900) async throws -> [String: Int] {
        struct Row: Decodable {
            let venue_name: String
            let is_active: Bool?
            let last_updated: String?
        }
        let rows: [Row] = try await SupabaseClient.shared.get(
            path: "rest/v1/live_locations",
            query: [
                URLQueryItem(name: "is_active", value: "eq.true"),
                URLQueryItem(name: "select", value: "venue_name,is_active,last_updated"),
            ]
        )
        let cutoff = Date().addingTimeInterval(TimeInterval(-maxAgeSeconds))
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var counts: [String: Int] = [:]
        for row in rows {
            if let s = row.last_updated {
                let date = formatter.date(from: s)
                    ?? ISO8601DateFormatter().date(from: s)
                if let date, date < cutoff { continue }
            }
            counts[row.venue_name, default: 0] += 1
        }
        return counts
    }
}

enum CheckInService {
    static func recent(limit: Int = 40) async throws -> [CheckInRow] {
        try await SupabaseClient.shared.get(
            path: "rest/v1/checkins",
            query: [
                URLQueryItem(name: "order", value: "created_at.desc"),
                URLQueryItem(name: "limit", value: "\(limit)"),
                URLQueryItem(name: "select", value: "id,user_id,venue_name,created_at"),
            ]
        )
    }
}
