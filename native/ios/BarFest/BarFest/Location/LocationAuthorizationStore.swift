import CoreLocation
import Combine
import UIKit

/// Observes location authorization and requests Always/When In Use like the web Allow Location CTAs.
@MainActor
final class LocationAuthorizationStore: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationAuthorizationStore()

    @Published private(set) var status: CLAuthorizationStatus

    private let manager = CLLocationManager()

    var isAuthorized: Bool {
        status == .authorizedAlways
    }

    /// True when OS location is on but not Always — UI should push upgrade, not unlock live features.
    var needsAlwaysUpgrade: Bool {
        status == .authorizedWhenInUse
    }

    private override init() {
        status = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }

    func refresh() {
        status = manager.authorizationStatus
    }

    /// Quiet start on app launch — request only if never asked; never open Settings here.
    func softStartTrackingIfPossible() {
        refresh()
        switch status {
        case .notDetermined:
            manager.requestAlwaysAuthorization()
            DiagnosticLog.shared.append(
                category: "location",
                message: "softStart: requesting Always (notDetermined)"
            )
        case .authorizedAlways:
            DiagnosticLog.shared.append(
                category: "location",
                message: "softStart: Always — starting presence engine"
            )
            do {
                try VenueLiveLocationEngine.shared.startTracking()
            } catch {
                DiagnosticLog.shared.append(
                    category: "location",
                    message: "softStart startTracking failed: \(error.localizedDescription)",
                    level: "error"
                )
            }
        case .authorizedWhenInUse:
            DiagnosticLog.shared.append(
                category: "location",
                message: "softStart: WhenInUse only — engine needs Always; requesting upgrade",
                level: "warn"
            )
            manager.requestAlwaysAuthorization()
        default:
            DiagnosticLog.shared.append(
                category: "location",
                message: "softStart: cannot track status=\(status.rawValue)",
                level: "warn"
            )
        }
    }

    /// User-tapped Allow Location (Activities strip, Map overlay, Chat gate).
    func requestAllowLocation(thenStartTracking: Bool = true) {
        refresh()
        switch status {
        case .notDetermined:
            manager.requestAlwaysAuthorization()
        case .denied, .restricted:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
            DiagnosticLog.shared.append(
                category: "location",
                message: "Allow Location: WhenInUse — requesting Always upgrade",
                level: "warn"
            )
        case .authorizedAlways:
            if thenStartTracking {
                do {
                    try VenueLiveLocationEngine.shared.startTracking()
                } catch {
                    DiagnosticLog.shared.append(
                        category: "location",
                        message: "Allow Location startTracking failed: \(error.localizedDescription)",
                        level: "error"
                    )
                }
            }
        @unknown default:
            manager.requestAlwaysAuthorization()
        }
        DiagnosticLog.shared.append(
            category: "location",
            message: "Allow Location tapped status=\(status.rawValue)"
        )
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.status = manager.authorizationStatus
            DiagnosticLog.shared.append(
                category: "location",
                message: "Authorization changed status=\(manager.authorizationStatus.rawValue)"
            )
            if manager.authorizationStatus == .authorizedAlways {
                do {
                    try VenueLiveLocationEngine.shared.startTracking()
                } catch {
                    DiagnosticLog.shared.append(
                        category: "location",
                        message: "authChanged startTracking failed: \(error.localizedDescription)",
                        level: "error"
                    )
                }
            } else if manager.authorizationStatus == .authorizedWhenInUse {
                DiagnosticLog.shared.append(
                    category: "location",
                    message: "authChanged WhenInUse — live_locations upserts need Always",
                    level: "warn"
                )
            }
        }
    }
}