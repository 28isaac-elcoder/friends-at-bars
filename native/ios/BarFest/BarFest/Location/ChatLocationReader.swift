import CoreLocation
import Combine

/// Lightweight GPS updates for Chat when When In Use is enough (presence engine needs Always).
@MainActor
final class ChatLocationReader: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = ChatLocationReader()

    @Published private(set) var coordinate: CLLocationCoordinate2D?

    private let manager = CLLocationManager()
    private var onUpdate: ((CLLocationCoordinate2D) -> Void)?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 50
    }

    func start(onUpdate: @escaping (CLLocationCoordinate2D) -> Void) {
        guard LocationAuthorizationStore.shared.canUseChatLocation else { return }
        self.onUpdate = onUpdate
        manager.delegate = self
        manager.startUpdatingLocation()
        manager.requestLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
        onUpdate = nil
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            self.coordinate = loc.coordinate
            self.onUpdate?(loc.coordinate)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            DiagnosticLog.shared.append(
                category: "location",
                message: "ChatLocationReader failed: \(error.localizedDescription)",
                level: "warn"
            )
        }
    }
}
