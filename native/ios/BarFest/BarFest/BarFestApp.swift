import SwiftUI

@main
struct BarFestApp: App {
    @StateObject private var appModel = AppModel()
    @StateObject private var testMode = TestModeStore.shared

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(appModel)
                .environmentObject(testMode)
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
        DiagnosticLog.shared.append(
            category: "system",
            message: "Bootstrap bundle=\(Bundle.main.bundleIdentifier ?? "?") testUI=\(DevTestMode.isUIEnabled)"
        )
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
        let state = VenueLiveLocationEngine.shared.currentState()
        lastVenueName = state.lastVenue
    }

    func refreshCatalog() async {
        isRefreshing = true
        defer { isRefreshing = false }
        let includeTest = DevTestMode.isUIEnabled || TestModeStore.shared.useMockCheckIns
        do {
            try await CatalogStore.shared.refresh(includeTest: includeTest)
            venues = await CatalogStore.shared.venues
            listings = await CatalogStore.shared.listings
            wordPackReady = !(await CatalogStore.shared.wordPack.isEmpty)
            if TestModeStore.shared.useMockCheckIns {
                venueCounts = mockVenueCounts(from: venues)
            } else {
                venueCounts = try await LiveLocationService.venueCounts()
            }
            locationBridge.updateVenues(venues)
            errorMessage = nil
            DiagnosticLog.shared.append(
                category: "system",
                message: "Catalog refresh venues=\(venues.count) listings=\(listings.count) mock=\(TestModeStore.shared.useMockCheckIns)"
            )
        } catch {
            errorMessage = error.localizedDescription
            venues = await CatalogStore.shared.venues
            DiagnosticLog.shared.append(
                category: "error",
                message: "Catalog refresh failed: \(error.localizedDescription)",
                level: "error"
            )
        }
    }

    private func mockVenueCounts(from venues: [CatalogVenue]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for (i, v) in venues.prefix(12).enumerated() {
            counts[v.name] = (i % 5) + 1
        }
        return counts
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
            LocationAuthorizationStore.shared.softStartTrackingIfPossible()
            Task { @MainActor in
                DiagnosticLog.shared.append(category: "location", message: "Tracking start requested")
            }
        } catch {
            print("LocationBridge start: \(error)")
            Task { @MainActor in
                DiagnosticLog.shared.append(
                    category: "location",
                    message: "Tracking start failed: \(error.localizedDescription)",
                    level: "error"
                )
            }
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

    func engine(_ engine: VenueLiveLocationEngine, didUpdateCoordinate coordinate: CLLocationCoordinate2D) {
        Task { @MainActor in
            DiagnosticLog.shared.append(
                category: "location",
                message: String(format: "Fix %.5f, %.5f", coordinate.latitude, coordinate.longitude)
            )
        }
    }

    func engine(
        _ engine: VenueLiveLocationEngine,
        willWrite action: String,
        venueName: String,
        venueChanged: Bool,
        heartbeatDue: Bool
    ) {
        Task { @MainActor in
            DiagnosticLog.shared.append(
                category: "location",
                message: "willWrite \(action) venue=\(venueName) changed=\(venueChanged) heartbeat=\(heartbeatDue)"
            )
        }
    }

    func engine(_ engine: VenueLiveLocationEngine, didWrite action: String, venueName: String?) {
        onVenue?(venueName)
        Task { @MainActor in
            DiagnosticLog.shared.append(
                category: "location",
                message: "didWrite \(action) venue=\(venueName ?? "nil")"
            )
        }
    }

    func engine(_ engine: VenueLiveLocationEngine, didFailWrite message: String) {
        print("live location write failed: \(message)")
        Task { @MainActor in
            DiagnosticLog.shared.append(
                category: "location",
                message: "write failed: \(message)",
                level: "error"
            )
        }
    }

    func engineDidLoseAuthorization(_ engine: VenueLiveLocationEngine) {
        onVenue?(nil)
        Task { @MainActor in
            DiagnosticLog.shared.append(
                category: "location",
                message: "Lost Always authorization",
                level: "warn"
            )
        }
    }
}

import CoreLocation

// CLLocationManagerProbe removed — use LocationAuthorizationStore.shared
