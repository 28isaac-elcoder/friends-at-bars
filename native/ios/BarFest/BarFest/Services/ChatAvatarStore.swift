import Foundation
import Combine

/// Persists chat avatars. Own icon has a 72-hour change cooldown; Test Mode "other user" does not.
@MainActor
final class ChatAvatarStore: ObservableObject {
    static let shared = ChatAvatarStore()

    static let cooldownSeconds: TimeInterval = 72 * 60 * 60

    @Published private(set) var selection: ChatAvatarSelection
    @Published private(set) var otherSelection: ChatAvatarSelection
    @Published private(set) var lastChangedAt: Date?

    private let selectionKey = "chat_avatar_selection_v1"
    private let otherSelectionKey = "chat_avatar_other_selection_v1"
    private let changedKey = "chat_avatar_last_changed_v1"

    private init() {
        let own: ChatAvatarSelection
        let persistOwn: Bool
        if let data = UserDefaults.standard.data(forKey: selectionKey),
           let decoded = try? JSONDecoder().decode(ChatAvatarSelection.self, from: data) {
            own = decoded
            persistOwn = false
        } else {
            own = ChatAvatarSelection.random()
            persistOwn = true
        }

        let other: ChatAvatarSelection
        let persistOther: Bool
        if let data = UserDefaults.standard.data(forKey: otherSelectionKey),
           let decoded = try? JSONDecoder().decode(ChatAvatarSelection.self, from: data) {
            other = decoded
            persistOther = false
        } else {
            other = ChatAvatarSelection.random()
            persistOther = true
        }

        let ts = UserDefaults.standard.double(forKey: changedKey)
        selection = own
        otherSelection = other
        lastChangedAt = ts > 0 ? Date(timeIntervalSince1970: ts) : nil

        if persistOwn { Self.write(own, key: selectionKey) }
        if persistOther { Self.write(other, key: otherSelectionKey) }
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
        Self.write(selection, key: selectionKey)
        UserDefaults.standard.set(lastChangedAt!.timeIntervalSince1970, forKey: changedKey)
        DiagnosticLog.shared.append(
            category: "chat",
            message: "Avatar updated icon=\(icon.rawValue) color=\(color.rawValue)"
        )
        return nil
    }

    /// Test Mode other-user avatar — no cooldown.
    func updateOther(icon: ChatAvatarIcon, color: ChatAvatarColor) {
        let next = ChatAvatarSelection(icon: icon, color: color)
        guard next != otherSelection else { return }
        otherSelection = next
        Self.write(otherSelection, key: otherSelectionKey)
        DiagnosticLog.shared.append(
            category: "chat",
            message: "Other avatar updated icon=\(icon.rawValue) color=\(color.rawValue)"
        )
    }

    private static func write(_ value: ChatAvatarSelection, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
