import Foundation
import Combine

/// Local Test Mode chat feed (web `testChatService` parity).
@MainActor
final class TestChatStore: ObservableObject {
    static let shared = TestChatStore()
    static nonisolated let otherAuthorId = "test_chat_other"

    enum Sender: String, CaseIterable, Identifiable {
        case user
        case other
        var id: String { rawValue }
        var label: String { self == .user ? "You" : "Other user" }
    }

    @Published private(set) var posts: [ChatPost] = []
    @Published var sender: Sender = .user
    @Published var simulatedVenueName: String = "Test Location 1"

    private var votes: [String: Int] = [:]
    private let postsKey = "barfest_test_chat_posts"
    private let votesKey = "barfest_test_chat_votes"

    private init() {
        load()
    }

    func feed(sort: String) -> [ChatPost] {
        let active = posts.filter { !$0.is_hidden && expiryOk($0) }
        if sort == "popular" {
            return active.sorted {
                if $0.score != $1.score { return $0.score > $1.score }
                return $0.created_at > $1.created_at
            }
        }
        return active.sorted { $0.created_at > $1.created_at }
    }

    func createPost(
        body: String,
        avatar: ChatAvatarSelection,
        venueName: String?,
        geographyId: UUID
    ) throws {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ChatLocalError.message("Message cannot be empty") }
        guard trimmed.count <= AppConfig.maxChatChars else {
            throw ChatLocalError.message("150 Character Limit")
        }
        let author =
            sender == .other
            ? Self.otherAuthorId
            : AnonymousIdentity.userId()
        let venue = venueName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let now = ISO8601DateFormatter().string(from: Date())
        let expires = ISO8601DateFormatter().string(
            from: Date().addingTimeInterval(24 * 60 * 60)
        )
        let post = ChatPost(
            id: UUID(),
            author_id: author,
            body: trimmed,
            venue_name: venue,
            geography_id: geographyId,
            score: 0,
            is_hidden: false,
            created_at: now,
            expires_at: expires,
            my_vote: nil,
            avatar_icon: avatar.icon.rawValue,
            avatar_color: avatar.color.rawValue
        )
        posts.insert(post, at: 0)
        persist()
    }

    func setVote(postId: UUID, direction: String) throws {
        let userId = AnonymousIdentity.userId()
        guard let idx = posts.firstIndex(where: { $0.id == postId }) else {
            throw ChatLocalError.message("Post not found")
        }
        var post = posts[idx]
        if post.author_id == userId {
            throw ChatLocalError.message("Cannot vote on your own post")
        }
        let desired = direction == "up" ? 1 : -1
        let key = postId.uuidString
        let existing = votes[key]
        var delta = 0
        if existing == desired {
            votes.removeValue(forKey: key)
            delta = -desired
        } else if existing == nil {
            votes[key] = desired
            delta = desired
        } else {
            votes[key] = desired
            delta = desired - (existing ?? 0)
        }
        post.score += delta
        if post.score <= -4 { post.is_hidden = true }
        post.my_vote = votes[key]
        posts[idx] = post
        persist()
    }

    func forceVote(postIds: [UUID], direction: String) {
        let desired = direction == "up" ? 1 : -1
        for id in postIds {
            guard let idx = posts.firstIndex(where: { $0.id == id }) else { continue }
            var post = posts[idx]
            let key = id.uuidString
            let existing = votes[key] ?? 0
            if existing == desired { continue }
            let delta = desired - existing
            votes[key] = desired
            post.score += delta
            if post.score <= -4 { post.is_hidden = true }
            post.my_vote = desired
            posts[idx] = post
        }
        persist()
    }

    func hide(postIds: [UUID]) {
        for id in postIds {
            guard let idx = posts.firstIndex(where: { $0.id == id }) else { continue }
            posts[idx].is_hidden = true
            votes.removeValue(forKey: id.uuidString)
        }
        persist()
    }

    func clearAll() {
        posts = []
        votes = [:]
        persist()
    }

    private func expiryOk(_ post: ChatPost) -> Bool {
        guard let d = ISO8601DateFormatter().date(from: post.expires_at)
            ?? ISO8601DateFormatter().date(from: post.expires_at.replacingOccurrences(of: "\\.\\d+", with: "", options: .regularExpression))
        else { return true }
        return d > Date()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: postsKey),
              let decoded = try? JSONDecoder().decode([ChatPost].self, from: data)
        else {
            posts = []
            return
        }
        posts = decoded
        if let vdata = UserDefaults.standard.data(forKey: votesKey),
           let v = try? JSONDecoder().decode([String: Int].self, from: vdata) {
            votes = v
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(posts) {
            UserDefaults.standard.set(data, forKey: postsKey)
        }
        if let data = try? JSONEncoder().encode(votes) {
            UserDefaults.standard.set(data, forKey: votesKey)
        }
    }
}

enum ChatLocalError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        if case .message(let s) = self { return s }
        return nil
    }
}
