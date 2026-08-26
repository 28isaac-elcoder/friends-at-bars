import Foundation
import UserNotifications

/// Local notifications prompting users at a bar to report wait time.
@MainActor
enum WaitTimeNotificationManager {
    private static let promptIdentifierPrefix = "barfest-wait-checkin-"
    private static let lastPromptKey = "barfest_wait_notif_last_venue"
    private static let permissionRequestedKey = "barfest_wait_notif_permission_requested"

    static func requestPermissionIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: permissionRequestedKey) else { return }
        UserDefaults.standard.set(true, forKey: permissionRequestedKey)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DiagnosticLog.log(
                category: "system",
                message: "wait-time notification permission granted=\(granted)"
            )
        }
    }

    /// Schedule a one-shot local notification when presence is detected at a new bar.
    static func notifyCheckInIfNeeded(venueName: String, userAlreadyReported: Bool) {
        guard !userAlreadyReported else { return }

        let last = UserDefaults.standard.string(forKey: lastPromptKey)
        if last == venueName { return }

        requestPermissionIfNeeded()
        UserDefaults.standard.set(venueName, forKey: lastPromptKey)

        let content = UNMutableNotificationContent()
        content.title = "Check in at \(venueName)"
        content.body = "Report the line wait so others know what to expect."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let id = promptIdentifierPrefix + venueName.replacingOccurrences(of: " ", with: "-")
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                DiagnosticLog.log(
                    category: "system",
                    message: "wait-time notification schedule failed: \(error.localizedDescription)",
                    level: "error"
                )
            }
        }
    }

    static func clearVenueTracking() {
        UserDefaults.standard.removeObject(forKey: lastPromptKey)
    }
}
