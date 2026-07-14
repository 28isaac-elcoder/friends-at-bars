import SwiftUI

@main
struct BarFestApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(appModel)
                .task {
                    await appModel.bootstrap()
                }
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var venues: [CatalogVenue] = []
    @Published var listings: [CatalogListing] = []
    @Published var venueCounts: [String: Int] = [:]
    @Published var wordPackReady = false
    @Published var lastVenueName: String?
    @Published var errorMessage: String?
    @Published var isRefreshing = false

    private let locationBridge = LocationBridge()

    func bootstrap() async {
        await CatalogStore.shared.loadCachedVenuesIfNeeded()
        venues = await CatalogStore.shared.venues
        await refreshCatalog()
        locationBridge.start(
            venues: venues,
            onVenue: { [weak self] name in
                Task { @MainActor in
                    self?.lastVenueName = name
                }
            }
        )
        // Sync venue from engine for chat / ranked gates even if write events were missed.
        let state = VenueLiveLocationEngine.shared.currentState()
        lastVenueName = state.lastVenue
    }

    func refreshCatalog() async {
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            try await CatalogStore.shared.refresh(includeTest: false)
            venues = await CatalogStore.shared.venues
            listings = await CatalogStore.shared.listings
            wordPackReady = !(await CatalogStore.shared.wordPack.isEmpty)
            venueCounts = try await LiveLocationService.venueCounts()
            locationBridge.updateVenues(venues)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            venues = await CatalogStore.shared.venues
        }
    }
}

/// Wires catalog venues into VenueLiveLocationEngine.
final class LocationBridge: VenueLiveLocationEngineDelegate {
    private var onVenue: ((String?) -> Void)?

    func start(venues: [CatalogVenue], onVenue: @escaping (String?) -> Void) {
        self.onVenue = onVenue
        do {
            let records = venues.map {
                VenueRecord(name: $0.name, area: $0.area, coordinates: [$0.latitude, $0.longitude])
            }
            try VenueLiveLocationEngine.shared.applyConfiguration(
                supabaseUrl: AppConfig.supabaseURL,
                supabaseAnonKey: AppConfig.supabaseAnonKey,
                userId: AnonymousIdentity.userId(),
                venues: records,
                heartbeatMs: 300_000,
                pollIntervalMs: 10_000,
                venueRadiusM: AppConfig.venueRadiusMeters,
                skipSupabase: false
            )
            VenueLiveLocationEngine.shared.eventDelegate = self
            // Request always auth; start when granted (caller may re-call).
            let mgr = CLLocationManagerProbe.shared
            mgr.requestAlways()
            try? VenueLiveLocationEngine.shared.startTracking()
        } catch {
            // Permission may not be ready yet
            print("LocationBridge start: \(error)")
        }
    }

    func updateVenues(_ venues: [CatalogVenue]) {
        let records = venues.map {
            VenueRecord(name: $0.name, area: $0.area, coordinates: [$0.latitude, $0.longitude])
        }
        try? VenueLiveLocationEngine.shared.applyConfiguration(
            supabaseUrl: AppConfig.supabaseURL,
            supabaseAnonKey: AppConfig.supabaseAnonKey,
            userId: AnonymousIdentity.userId(),
            venues: records,
            heartbeatMs: 300_000,
            pollIntervalMs: 10_000,
            venueRadiusM: AppConfig.venueRadiusMeters,
            skipSupabase: false
        )
    }

    func engine(_ engine: VenueLiveLocationEngine, didUpdateCoordinate coordinate: CLLocationCoordinate2D) {}
    func engine(
        _ engine: VenueLiveLocationEngine,
        willWrite action: String,
        venueName: String,
        venueChanged: Bool,
        heartbeatDue: Bool
    ) {}
    func engine(_ engine: VenueLiveLocationEngine, didWrite action: String, venueName: String?) {
        onVenue?(venueName)
    }
    func engine(_ engine: VenueLiveLocationEngine, didFailWrite message: String) {
        print("live location write failed: \(message)")
    }
    func engineDidLoseAuthorization(_ engine: VenueLiveLocationEngine) {
        onVenue?(nil)
    }
}

import CoreLocation

final class CLLocationManagerProbe: NSObject, CLLocationManagerDelegate {
    static let shared = CLLocationManagerProbe()
    private let manager = CLLocationManager()

    private override init() {
        super.init()
        manager.delegate = self
    }

    func requestAlways() {
        manager.requestAlwaysAuthorization()
    }
}
