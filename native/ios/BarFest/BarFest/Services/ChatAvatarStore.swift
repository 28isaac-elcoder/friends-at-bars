import Foundation
import Combine

/// Persists the user's chat avatar and enforces a 72-hour change cooldown.
@MainActor
final class ChatAvatarStore: ObservableObject {
    static let shared = ChatAvatarStore()

    static let cooldownSeconds: TimeInterval = 72 * 60 * 60

    @Published private(set) var selection: ChatAvatarSelection
    @Published private(set) var lastChangedAt: Date?

    private let selectionKey = "chat_avatar_selection_v1"
    private let changedKey = "chat_avatar_last_changed_v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: selectionKey),
           let decoded = try? JSONDecoder().decode(ChatAvatarSelection.self, from: data) {
            selection = decoded
        } else {
            selection = ChatAvatarResolver.derived(from: AnonymousIdentity.userId())
            persistSelection()
        }
        let ts = UserDefaults.standard.double(forKey: changedKey)
        lastChangedAt = ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }

    var canChange: Bool {
        guard let lastChangedAt else { return true }
        return Date().timeIntervalSince(lastChangedAt) >= Self.cooldownSeconds
    }

    var cooldownRemaining: TimeInterval {
        guard let lastChangedAt else { return 0 }
        return max(0, Self.cooldownSeconds - Date().timeIntervalSince(lastChangedAt))
    }

    var cooldownMessage: String {
        let hours = Int(ceil(cooldownRemaining / 3600))
        if hours <= 1 {
            return "You can change your icon again in about an hour."
        }
        return "You can change your icon again in \(hours) hours."
    }

    /// Returns nil on success, or a wait message if still in cooldown.
    @discardableResult
    func tryUpdate(icon: ChatAvatarIcon, color: ChatAvatarColor) -> String? {
        let next = ChatAvatarSelection(icon: icon, color: color)
        if next == selection { return nil }
        guard canChange else { return cooldownMessage }
        selection = next
        lastChangedAt = Date()
        persistSelection()
        UserDefaults.standard.set(lastChangedAt!.timeIntervalSince1970, forKey: changedKey)
        DiagnosticLog.shared.append(
            category: "chat",
            message: "Avatar updated icon=\(icon.rawValue) color=\(color.rawValue)"
        )
        return nil
    }

    private func persistSelection() {
        if let data = try? JSONEncoder().encode(selection) {
            UserDefaults.standard.set(data, forKey: selectionKey)
        }
    }
}
