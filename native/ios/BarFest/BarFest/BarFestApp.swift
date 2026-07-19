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
            let cmsLibrary = await CatalogStore.shared.switchSearchLibrary
            let wordPack = await CatalogStore.shared.wordPack
            wordPackReady = cmsLibrary != nil || !wordPack.isEmpty
            if TestModeStore.shared.useMockCheckIns {
                venueCounts = mockVenueCounts(from: venues)
            } else {
                venueCounts = try await LiveLocationService.venueCounts()
            }
            locationBridge.updateVenues(venues)
            errorMessage = nil
            await logCatalogDiagnostics(source: "refresh")
        } catch {
            errorMessage = error.localizedDescription
            venues = await CatalogStore.shared.venues
            listings = await CatalogStore.shared.listings
            DiagnosticLog.shared.append(
                category: "error",
                message: "Catalog refresh failed: \(error.localizedDescription)",
                level: "error"
            )
            await logCatalogDiagnostics(source: "refresh-failed-partial")
        }
    }

    /// Logs listing/venue breakdown to help diagnose Deals showing fewer rows than expected.
    private func logCatalogDiagnostics(source: String) async {
        let includeTest = DevTestMode.isUIEnabled || TestModeStore.shared.useMockCheckIns
        let version = await CatalogStore.shared.contentVersion.map(String.init) ?? "nil"
        let areas = Dictionary(grouping: listings, by: \.area).mapValues(\.count)
        let areaSummary = areas.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        let withPriority = listings.filter { $0.priority > 0 }.count
        let venuesSample = listings.prefix(8).map(\.venue_name).joined(separator: ", ")
        let hint: String
        if listings.count <= 6 {
            hint = "HINT: only \(listings.count) rows in Supabase — re-run catalog_seed.sql or CMS Import web listings (47)"
        } else if listings.count < 40 {
            hint = "HINT: partial catalog (\(listings.count)/47 expected) — check Supabase catalog_listings"
        } else {
            hint = "catalog looks complete"
        }
        DiagnosticLog.shared.append(
            category: "system",
            message: """
            Catalog[\(source)] venues=\(venues.count) listings=\(listings.count) \
            priority=\(withPriority) version=\(version) includeTest=\(includeTest) mock=\(TestModeStore.shared.useMockCheckIns)
            """
        )
        DiagnosticLog.shared.append(
            category: "system",
            message: "Catalog areas: \(areaSummary.isEmpty ? "(none)" : areaSummary)"
        )
        DiagnosticLog.shared.append(
            category: "system",
            message: "Catalog sample venues: \(venuesSample.isEmpty ? "(none)" : venuesSample)"
        )
        DiagnosticLog.shared.append(category: "system", message: hint)
        DiagnosticLog.shared.append(
            category: "system",
            message: "Supabase host: \(AppConfig.supabaseURL)"
        )
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
@MainActor
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
            let auth = LocationAuthorizationStore.shared.status.rawValue
            let uid = String(AnonymousIdentity.userId().prefix(12))
            DiagnosticLog.shared.append(
                category: "location",
                message: "Tracking start requested venues=\(records.count) auth=\(auth) userId=\(uid)… radius=\(Int(AppConfig.venueRadiusMeters))m"
            )
        } catch {
            print("LocationBridge start: \(error)")
            DiagnosticLog.shared.append(
                category: "location",
                message: "Tracking start failed: \(error.localizedDescription)",
                level: "error"
            )
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

    nonisolated func engine(_ engine: VenueLiveLocationEngine, didUpdateCoordinate coordinate: CLLocationCoordinate2D) {
        Task { @MainActor in
            DiagnosticLog.shared.append(
                category: "location",
                message: String(format: "Fix %.5f, %.5f", coordinate.latitude, coordinate.longitude)
            )
        }
    }

    nonisolated func engine(
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

    nonisolated func engine(_ engine: VenueLiveLocationEngine, didWrite action: String, venueName: String?) {
        Task { @MainActor in
            self.onVenue?(venueName)
            DiagnosticLog.shared.append(
                category: "location",
                message: "didWrite \(action) venue=\(venueName ?? "nil")"
            )
        }
    }

    nonisolated func engine(_ engine: VenueLiveLocationEngine, didFailWrite message: String) {
        print("live location write failed: \(message)")
        Task { @MainActor in
            DiagnosticLog.shared.append(
                category: "location",
                message: "write failed: \(message)",
                level: "error"
            )
        }
    }

    nonisolated func engineDidLoseAuthorization(_ engine: VenueLiveLocationEngine) {
        Task { @MainActor in
            self.onVenue?(nil)
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
