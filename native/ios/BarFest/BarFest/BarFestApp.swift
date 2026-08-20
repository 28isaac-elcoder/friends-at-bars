import SwiftUI
import CoreLocation

@main
struct BarFestApp: App {
    @StateObject private var appModel = AppModel()
    @StateObject private var testMode = TestModeStore.shared

    init() {
        // Re-attach geofences / significant-location ASAP so a cold wake from a region
        // event can resume presence writes before the catalog finishes loading.
        VenueLiveLocationEngine.shared.restoreIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(appModel)
                .environmentObject(testMode)
        }
    }
}

/// Hosts main UI plus cold-start splash overlay (once per process launch).
private struct AppRootView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var showSplash = true

    var body: some View {
        ZStack {
            RootTabView()
            if showSplash {
                StartupSplashView(isBootstrapComplete: appModel.initialBootstrapFinished) {
                    showSplash = false
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .animation(.easeOut(duration: 0.15), value: showSplash)
        .task {
            await appModel.bootstrap()
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var venues: [CatalogVenue] = []
    @Published var listings: [CatalogListing] = []
    @Published var geographies: [CatalogGeography] = []
    @Published var areas: [CatalogArea] = []
    @Published var venueCounts: [String: Int] = [:]
    @Published var wordPackReady = false
    @Published var lastVenueName: String?
    @Published var errorMessage: String?
    @Published var isRefreshing = false
    @Published var initialBootstrapFinished = false
    @Published var lastKnownCoordinate: CLLocationCoordinate2D?
    @Published var manualGeographyId: UUID?

    private let locationBridge = LocationBridge()
    private let manualGeographyKey = "barfest_manual_geography_id"

    /// Geography IDs the current catalog load exposes (active + non-test unless Test Mode).
    private var visibleGeographyIds: Set<UUID> {
        Set(geographies.map(\.id))
    }

    /// Venues whose parent geography is visible — geography active/test supersedes venue flags in the app.
    var venuesInVisibleGeographies: [CatalogVenue] {
        venues.filter { venue in
            guard let gid = venue.geography_id else { return false }
            return visibleGeographyIds.contains(gid)
        }
    }

    var resolvedGeography: CatalogGeography? {
        if let id = manualGeographyId, let match = geographies.first(where: { $0.id == id }) {
            return match
        }
        return GeographyResolver.automatic(coordinate: lastKnownCoordinate, from: geographies)
    }

    var scopedVenues: [CatalogVenue] {
        let base = venuesInVisibleGeographies
        guard let geo = resolvedGeography else { return base }
        return base.filter { $0.geography_id == geo.id }
    }

    var scopedListings: [CatalogListing] {
        let names = Set(scopedVenues.map(\.name))
        guard !names.isEmpty else { return [] }
        return listings.filter { names.contains($0.venue_name) }
    }

    var scopedAreas: [CatalogArea] {
        let visible = areas.filter { visibleGeographyIds.contains($0.geography_id) }
        guard let geo = resolvedGeography else { return visible }
        return visible.filter { $0.geography_id == geo.id }
    }

    /// GPS-derived geography (no manual banner override). Nil if outside all regions.
    var gpsGeography: CatalogGeography? {
        GeographyResolver.geographyContaining(
            coordinate: lastKnownCoordinate,
            from: geographies
        )
    }

    func setManualGeography(_ id: UUID?) {
        manualGeographyId = id
        if let id {
            UserDefaults.standard.set(id.uuidString, forKey: manualGeographyKey)
        } else {
            UserDefaults.standard.removeObject(forKey: manualGeographyKey)
        }
    }

    func bootstrap() async {
        defer { initialBootstrapFinished = true }
        DiagnosticLog.shared.append(
            category: "system",
            message: "Bootstrap bundle=\(Bundle.main.bundleIdentifier ?? "?") testUI=\(DevTestMode.isUIEnabled)"
        )
        await CatalogStore.shared.loadCachedVenuesIfNeeded()
        venues = await CatalogStore.shared.venues
        if let raw = UserDefaults.standard.string(forKey: manualGeographyKey) {
            manualGeographyId = UUID(uuidString: raw)
        }
        await refreshCatalog()
        locationBridge.start(
            venues: venuesInVisibleGeographies,
            onVenue: { [weak self] name in
                Task { @MainActor in
                    self?.lastVenueName = name
                }
            },
            onPresenceWrite: { [weak self] action in
                Task { @MainActor in
                    await self?.refreshLiveCountsOnly(source: "presence-\(action)")
                }
            },
            onCoordinate: { [weak self] coord in
                Task { @MainActor in
                    self?.lastKnownCoordinate = coord
                }
            }
        )
        let state = VenueLiveLocationEngine.shared.currentState()
        lastVenueName = state.lastVenue
    }

    /// Lightweight headcount refresh after our own upsert/deactivate (avoids full catalog round-trip).
    func refreshLiveCountsOnly(source: String) async {
        if TestModeStore.shared.useMockCheckIns {
            venueCounts = mockVenueCounts(from: venuesInVisibleGeographies)
            await logHeadcountSnapshot(source: source)
            return
        }
        do {
            venueCounts = try await LiveLocationService.venueCounts()
            await logHeadcountSnapshot(source: source)
        } catch {
            DiagnosticLog.shared.append(
                category: "location",
                message: "headcount refresh[\(source)] failed: \(error.localizedDescription)",
                level: "error"
            )
        }
    }

    func refreshCatalog() async {
        isRefreshing = true
        defer { isRefreshing = false }
        let includeTest = DevTestMode.isUIEnabled || TestModeStore.shared.useMockCheckIns
        do {
            try await CatalogStore.shared.refresh(includeTest: includeTest)
            venues = await CatalogStore.shared.venues
            listings = await CatalogStore.shared.listings
            geographies = await CatalogStore.shared.geographies
            areas = await CatalogStore.shared.areas
            if let id = manualGeographyId, !geographies.contains(where: { $0.id == id }) {
                setManualGeography(nil)
            }
            let cmsLibrary = await CatalogStore.shared.switchSearchLibrary
            let wordPack = await CatalogStore.shared.wordPack
            wordPackReady = cmsLibrary != nil || !wordPack.isEmpty
            if TestModeStore.shared.useMockCheckIns {
                venueCounts = mockVenueCounts(from: venuesInVisibleGeographies)
                DiagnosticLog.shared.append(
                    category: "location",
                    message: "venueCounts using Test Mode mock (\(venueCounts.count) venues)"
                )
            } else {
                venueCounts = try await LiveLocationService.venueCounts()
            }
            locationBridge.updateVenues(venuesInVisibleGeographies)
            errorMessage = nil
            await logCatalogDiagnostics(source: "refresh")
            await logHeadcountSnapshot(source: "refresh")
        } catch {
            errorMessage = error.localizedDescription
            venues = await CatalogStore.shared.venues
            listings = await CatalogStore.shared.listings
            geographies = await CatalogStore.shared.geographies
            areas = await CatalogStore.shared.areas
            DiagnosticLog.shared.append(
                category: "error",
                message: "Catalog refresh failed: \(error.localizedDescription)",
                level: "error"
            )
            await logCatalogDiagnostics(source: "refresh-failed-partial")
        }
    }

    /// Pull-to-refresh focused path: refresh catalog + live headcounts and log clearly.
    func refreshHeadcounts(source: String = "pull-to-refresh") async {
        DiagnosticLog.shared.append(
            category: "location",
            message: "headcount refresh begin source=\(source) authAlways=\(LocationAuthorizationStore.shared.isAuthorized) lastVenue=\(lastVenueName ?? "nil")"
        )
        await refreshCatalog()
    }

    private func logHeadcountSnapshot(source: String) async {
        let total = venueCounts.values.reduce(0, +)
        let top = venueCounts.sorted { $0.value > $1.value }.prefix(5)
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ", ")
        DiagnosticLog.shared.append(
            category: "location",
            message: "headcount snapshot[\(source)] people=\(total) venues=\(venueCounts.count) maxAgeSec=\(AppConfig.liveLocationCountMaxAgeSeconds) top=\(top.isEmpty ? "(none)" : top)"
        )
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
    private var onPresenceWrite: ((String) -> Void)?
    private var onCoordinate: ((CLLocationCoordinate2D) -> Void)?

    func start(
        venues: [CatalogVenue],
        onVenue: @escaping (String?) -> Void,
        onPresenceWrite: ((String) -> Void)? = nil,
        onCoordinate: ((CLLocationCoordinate2D) -> Void)? = nil
    ) {
        self.onVenue = onVenue
        self.onPresenceWrite = onPresenceWrite
        self.onCoordinate = onCoordinate
        do {
            let records = venues.map {
                VenueRecord(name: $0.name, area: $0.area, coordinates: [$0.latitude, $0.longitude])
            }
            try VenueLiveLocationEngine.shared.applyConfiguration(
                supabaseUrl: AppConfig.supabaseURL,
                supabaseAnonKey: AppConfig.supabaseAnonKey,
                userId: AnonymousIdentity.userId(),
                venues: records,
                heartbeatMs: AppConfig.liveLocationHeartbeatMs,
                pollIntervalMs: 10_000,
                venueRadiusM: AppConfig.venueRadiusMeters,
                skipSupabase: false
            )
            VenueLiveLocationEngine.shared.eventDelegate = self
            LocationAuthorizationStore.shared.softStartTrackingIfPossible()
            DiagnosticLog.shared.append(
                category: "location",
                message: "presence engine start venues=\(records.count) auth=\(LocationAuthorizationStore.shared.status.rawValue) presence=\(Int(AppConfig.venueRadiusMeters))m exit=\(Int(AppConfig.venueExitRadiusMeters))m hardClear=\(Int(AppConfig.venueHardClearRadiusMeters))m approach=\(Int(AppConfig.venueApproachRadiusMeters))m"
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
            heartbeatMs: AppConfig.liveLocationHeartbeatMs,
            pollIntervalMs: 10_000,
            venueRadiusM: AppConfig.venueRadiusMeters,
            skipSupabase: false
        )
    }

    nonisolated func engine(_ engine: VenueLiveLocationEngine, didUpdateCoordinate coordinate: CLLocationCoordinate2D) {
        Task { @MainActor in
            self.onCoordinate?(coordinate)
        }
    }

    nonisolated func engine(
        _ engine: VenueLiveLocationEngine,
        willWrite action: String,
        venueName: String,
        venueChanged: Bool,
        heartbeatDue: Bool
    ) {
        // Engine logs upsert intent; bridge only reacts to didWrite.
    }

    nonisolated func engine(_ engine: VenueLiveLocationEngine, didWrite action: String, venueName: String?) {
        Task { @MainActor in
            self.onVenue?(venueName)
            self.onPresenceWrite?(action)
        }
    }

    nonisolated func engine(_ engine: VenueLiveLocationEngine, didFailWrite message: String) {
        Task { @MainActor in
            DiagnosticLog.shared.append(
                category: "location",
                message: "bridge write failed: \(message)",
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
