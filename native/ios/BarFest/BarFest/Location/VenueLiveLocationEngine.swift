import CoreLocation
import Foundation

/// Haversine nearest venue + heartbeat writes (runs on native threads, not WebView).
final class VenueLiveLocationEngine: NSObject, CLLocationManagerDelegate {
    static let shared = VenueLiveLocationEngine()

    enum Keys {
        static let supabaseUrl = "barfest_native_supabaseUrl"
        static let supabaseAnonKey = "barfest_native_supabaseAnonKey"
        static let userId = "barfest_native_userId"
        static let venuesJson = "barfest_native_venuesJson"
        static let heartbeatMs = "barfest_native_heartbeatMs"
        static let pollIntervalMs = "barfest_native_pollIntervalMs"
        static let venueRadiusM = "barfest_native_venueRadiusM"
        static let skipSupabase = "barfest_native_skipSupabase"
        static let trackingEnabled = "barfest_native_trackingEnabled"
    }

    weak var eventDelegate: VenueLiveLocationEngineDelegate?

    private let manager = CLLocationManager()
    private let queue = DispatchQueue(label: "com.barfest.native-live-location", qos: .userInitiated)

    private var venues: [VenueRecord] = []
    private var supabase: SupabaseLiveLocationAPI?
    private var userId: String = ""
    private var heartbeatMs: Int = AppConfig.liveLocationHeartbeatMs
    private var pollIntervalMs: Int = 10_000
    private var venueRadiusM: Double = 100
    private var skipSupabase = false

    private var isRunning = false
    private var lastProcessTime: TimeInterval = 0
    private var lastWrittenVenue: String?
    private var lastWriteAtMs: TimeInterval = 0
    private var hadActiveVenueRow = false
    private var lastKnownLocation: CLLocation?
    private var lastGpsCallbackAtMs: TimeInterval = 0
    private var gpsCallbackCount = 0
    private var watchdogTimer: DispatchSourceTimer?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 25
        manager.pausesLocationUpdatesAutomatically = false
        manager.activityType = .other
        if #available(iOS 11.0, *) {
            manager.showsBackgroundLocationIndicator = true
        }
    }

    func applyConfiguration(
        supabaseUrl: String,
        supabaseAnonKey: String,
        userId: String,
        venues: [VenueRecord],
        heartbeatMs: Int,
        pollIntervalMs: Int,
        venueRadiusM: Double,
        skipSupabase: Bool
    ) throws {
        let defaults = UserDefaults.standard
        defaults.set(supabaseUrl, forKey: Keys.supabaseUrl)
        defaults.set(supabaseAnonKey, forKey: Keys.supabaseAnonKey)
        defaults.set(userId, forKey: Keys.userId)
        defaults.set(heartbeatMs, forKey: Keys.heartbeatMs)
        defaults.set(pollIntervalMs, forKey: Keys.pollIntervalMs)
        defaults.set(venueRadiusM, forKey: Keys.venueRadiusM)
        defaults.set(skipSupabase, forKey: Keys.skipSupabase)

        let venuesData = try JSONEncoder().encode(venues)
        defaults.set(String(data: venuesData, encoding: .utf8), forKey: Keys.venuesJson)

        let previousCount = queue.sync { self.venues.count }
        try queue.sync {
            self.userId = userId
            self.venues = venues
            self.heartbeatMs = heartbeatMs
            self.pollIntervalMs = pollIntervalMs
            self.venueRadiusM = venueRadiusM
            self.skipSupabase = skipSupabase
            if skipSupabase {
                self.supabase = nil
            } else {
                self.supabase = try SupabaseLiveLocationAPI(
                    supabaseUrl: supabaseUrl,
                    anonKey: supabaseAnonKey
                )
            }
        }

        let testHit = venues.first(where: { $0.name.localizedCaseInsensitiveContains("Test Location") })
        if let testHit, testHit.coordinates.count >= 2 {
            logLocationDiag(
                "config venues=\(venues.count) (was \(previousCount)) testVenue=\(testHit.name) @ \(String(format: "%.5f", testHit.coordinates[0])),\(String(format: "%.5f", testHit.coordinates[1])) radius=\(Int(venueRadiusM))m skipSupabase=\(skipSupabase)"
            )
        } else {
            logLocationDiag(
                "config venues=\(venues.count) (was \(previousCount)) testVenue=(none in list) radius=\(Int(venueRadiusM))m skipSupabase=\(skipSupabase)",
                level: venues.isEmpty ? "warn" : "info"
            )
        }

        // Standing still often yields no new CoreLocation callbacks (distanceFilter=25m).
        // Re-scan last fix once the venue list arrives so we don't stay stuck after venuesConfigured=0.
        if isRunning, !venues.isEmpty {
            if let last = queue.sync(execute: { lastKnownLocation }) {
                logLocationDiag("config: re-scanning last known GPS against \(venues.count) venues")
                queue.sync { lastProcessTime = 0 }
                processLocation(last)
            } else {
                logLocationDiag("config: no last GPS yet — requesting one-shot location")
                manager.requestLocation()
            }
        }
    }

    func loadConfigurationFromDefaults() -> Bool {
        let defaults = UserDefaults.standard
        guard
            let supabaseUrl = defaults.string(forKey: Keys.supabaseUrl),
            let anonKey = defaults.string(forKey: Keys.supabaseAnonKey),
            let userId = defaults.string(forKey: Keys.userId),
            let venuesJson = defaults.string(forKey: Keys.venuesJson),
            let venuesData = venuesJson.data(using: .utf8)
        else {
            return false
        }

        let venues = (try? JSONDecoder().decode([VenueRecord].self, from: venuesData)) ?? []
        let heartbeatMs = defaults.integer(forKey: Keys.heartbeatMs)
        let pollIntervalMs = defaults.integer(forKey: Keys.pollIntervalMs)
        let venueRadiusM = defaults.double(forKey: Keys.venueRadiusM)
        let skipSupabase = defaults.bool(forKey: Keys.skipSupabase)

        do {
            try applyConfiguration(
                supabaseUrl: supabaseUrl,
                supabaseAnonKey: anonKey,
                userId: userId,
                venues: venues,
                heartbeatMs: heartbeatMs > 0 ? heartbeatMs : AppConfig.liveLocationHeartbeatMs,
                pollIntervalMs: pollIntervalMs > 0 ? pollIntervalMs : 10_000,
                venueRadiusM: venueRadiusM > 0 ? venueRadiusM : 100,
                skipSupabase: skipSupabase
            )
            return true
        } catch {
            return false
        }
    }

    func startTracking() throws {
        let status = manager.authorizationStatus
        guard status == .authorizedAlways else {
            let message =
                "Always location permission is required for background live tracking (status=\(status.rawValue))."
            DispatchQueue.main.async {
                DiagnosticLog.shared.append(
                    category: "location",
                    message: message,
                    level: "warn"
                )
            }
            throw NSError(
                domain: "BarFestNativeLiveLocation",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }

        let servicesOn = CLLocationManager.locationServicesEnabled()
        var accuracyNote = "full"
        if #available(iOS 14.0, *) {
            switch manager.accuracyAuthorization {
            case .fullAccuracy: accuracyNote = "precise"
            case .reducedAccuracy: accuracyNote = "reduced"
            @unknown default: accuracyNote = "unknown"
            }
        }

        UserDefaults.standard.set(true, forKey: Keys.trackingEnabled)
        manager.allowsBackgroundLocationUpdates = true
        manager.startUpdatingLocation()
        // One-shot helps when standing still (distanceFilter may suppress continuous updates).
        manager.requestLocation()
        isRunning = true
        startWatchdog()

        let auth = manager.authorizationStatus.rawValue
        let venueCount = queue.sync { venues.count }
        let uidPrefix = String(userId.prefix(12))
        logLocationDiag(
            "engine startTracking ok auth=\(auth) services=\(servicesOn) accuracy=\(accuracyNote) venues=\(venueCount) userId=\(uidPrefix)… radius=\(Int(venueRadiusM))m poll=\(pollIntervalMs)ms distanceFilter=25m heartbeatMs=\(heartbeatMs)"
        )
    }

    func stopTracking(deactivate: Bool = true) {
        stopWatchdog()
        UserDefaults.standard.set(false, forKey: Keys.trackingEnabled)
        manager.stopUpdatingLocation()
        isRunning = false

        if deactivate, hadActiveVenueRow, !skipSupabase, let api = supabase, !userId.isEmpty {
            api.deactivateLiveLocation(userId: userId) { _ in }
        }

        queue.sync {
            lastWrittenVenue = nil
            lastWriteAtMs = 0
            hadActiveVenueRow = false
        }
    }

    func restoreIfNeeded() {
        guard UserDefaults.standard.bool(forKey: Keys.trackingEnabled) else { return }
        guard loadConfigurationFromDefaults() else { return }
        guard manager.authorizationStatus == .authorizedAlways else { return }
        try? startTracking()
    }

    func currentState() -> (isRunning: Bool, lastVenue: String?, lastWriteAtMs: Int64) {
        queue.sync {
            (
                isRunning,
                lastWrittenVenue,
                Int64(lastWriteAtMs)
            )
        }
    }

    // MARK: - Watchdog (explains silence when standing still)

    private func startWatchdog() {
        stopWatchdog()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 20, repeating: 30)
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            guard self.isRunning else { return }
            let now = Date().timeIntervalSince1970 * 1000
            let lastGps = self.lastGpsCallbackAtMs
            let venueCount = self.venues.count
            let callbacks = self.gpsCallbackCount
            if lastGps == 0 {
                self.logLocationDiag(
                    "watchdog: tracking but no GPS callbacks yet venues=\(venueCount) — check Precise Location / outdoors / Settings",
                    level: "warn"
                )
                DispatchQueue.main.async { self.manager.requestLocation() }
            } else {
                let ageSec = Int((now - lastGps) / 1000)
                if ageSec >= 45 {
                    self.logLocationDiag(
                        "watchdog: last GPS \(ageSec)s ago callbacks=\(callbacks) venues=\(venueCount) (standing still often pauses updates; requesting location)",
                        level: "warn"
                    )
                    DispatchQueue.main.async { self.manager.requestLocation() }
                }
            }
        }
        timer.resume()
        watchdogTimer = timer
    }

    private func stopWatchdog() {
        watchdogTimer?.cancel()
        watchdogTimer = nil
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        DispatchQueue.main.async {
            DiagnosticLog.shared.append(
                category: "location",
                message: "engine authChanged status=\(status.rawValue) isRunning=\(self.isRunning)"
            )
        }
        if status != .authorizedAlways, isRunning {
            stopTracking(deactivate: true)
            DispatchQueue.main.async { [weak self] in
                self?.eventDelegate?.engineDidLoseAuthorization(self!)
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let code = (error as NSError).code
        logLocationDiag(
            "GPS didFail code=\(code) \(error.localizedDescription)",
            level: "error"
        )
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.eventDelegate?.engine(self, didFailWrite: "GPS: \(error.localizedDescription)")
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        queue.sync {
            lastKnownLocation = location
            lastGpsCallbackAtMs = Date().timeIntervalSince1970 * 1000
            gpsCallbackCount += 1
        }

        let acc = location.horizontalAccuracy
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        logLocationDiag(
            String(
                format: "GPS fix #\(queue.sync { gpsCallbackCount }) %.5f,%.5f ±%.0fm venues=%d running=%@",
                lat,
                lon,
                acc,
                queue.sync { venues.count },
                isRunning ? "true" : "false"
            )
        )

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.eventDelegate?.engine(
                self,
                didUpdateCoordinate: location.coordinate
            )
        }

        let now = Date().timeIntervalSince1970 * 1000
        let shouldProcess: Bool = queue.sync {
            if now - lastProcessTime < Double(pollIntervalMs) {
                return false
            }
            lastProcessTime = now
            return true
        }
        if !shouldProcess {
            let wait = queue.sync { Int((Double(pollIntervalMs) - (now - lastProcessTime)) / 1000) }
            logLocationDiag("GPS throttled — next geofence scan in ~\(max(0, wait))s")
            return
        }

        processLocation(location)
    }

    private func processLocation(_ location: CLLocation) {
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        let venueCount = queue.sync { venues.count }
        let nearestFew = nearestVenues(latitude: lat, longitude: lon, limit: 3)
        let nearest = nearestFew.first
        let venueName = nearest.flatMap { $0.distance < venueRadiusM ? $0.name : nil }

        if venueCount == 0 {
            logLocationDiag(
                "scan blocked: venuesConfigured=0 (catalog not applied yet) — cannot upsert",
                level: "warn"
            )
            return
        }

        if let nearest {
            let inside = nearest.distance < venueRadiusM
            let top = nearestFew
                .map { "\($0.name)=\(Int($0.distance))m" }
                .joined(separator: ", ")
            logLocationDiag(
                "scan nearest=\(nearest.name) dist=\(Int(nearest.distance))m radius=\(Int(venueRadiusM))m inside=\(inside) top3=[\(top)]"
            )
            if !inside {
                logLocationDiag(
                    "outside geofence — need <\(Int(venueRadiusM))m of a catalog venue (closest \(Int(nearest.distance))m from \(nearest.name))"
                )
            }
        } else {
            logLocationDiag(
                "scan nearest=(none) venuesConfigured=\(venueCount) — venue coords missing?",
                level: "warn"
            )
        }

        if venueName == nil {
            let shouldDeactivate: Bool = queue.sync {
                guard hadActiveVenueRow else { return false }
                hadActiveVenueRow = false
                lastWrittenVenue = nil
                lastWriteAtMs = 0
                return true
            }
            if shouldDeactivate, !skipSupabase, let api = supabase {
                logLocationDiag("deactivating live_locations (left venue geofence)")
                api.deactivateLiveLocation(userId: userId) { [weak self] result in
                    guard let self = self else { return }
                    switch result {
                    case .success:
                        DispatchQueue.main.async {
                            self.eventDelegate?.engine(self, didWrite: "deactivate", venueName: nil)
                        }
                    case .failure(let err):
                        self.notifyWriteError(err)
                    }
                }
            } else if !shouldDeactivate {
                logLocationDiag("no Supabase write — not inside any venue radius")
            }
            return
        }

        let writeDecision: (venueChanged: Bool, heartbeatDue: Bool, name: String) = queue.sync {
            let name = venueName!
            let venueChanged = name != lastWrittenVenue
            let heartbeatDue = Date().timeIntervalSince1970 * 1000 - lastWriteAtMs >= Double(heartbeatMs)
            return (venueChanged, heartbeatDue, name)
        }

        guard writeDecision.venueChanged || writeDecision.heartbeatDue else {
            let msSince = queue.sync { Date().timeIntervalSince1970 * 1000 - lastWriteAtMs }
            let nextIn = max(0, Double(heartbeatMs) - msSince)
            logLocationDiag(
                "skipWrite venue=\(writeDecision.name) already active — next heartbeat in \(Int(nextIn / 1000))s"
            )
            return
        }
        guard !skipSupabase, let api = supabase else {
            logLocationDiag(
                "skipWrite venue=\(writeDecision.name) skipSupabase=\(skipSupabase) apiNil=\(supabase == nil)",
                level: "warn"
            )
            return
        }

        logLocationDiag(
            "upserting live_locations venue=\(writeDecision.name) changed=\(writeDecision.venueChanged) heartbeat=\(writeDecision.heartbeatDue) @ \(String(format: "%.5f", lat)),\(String(format: "%.5f", lon))"
        )

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.eventDelegate?.engine(
                self,
                willWrite: "upsert",
                venueName: writeDecision.name,
                venueChanged: writeDecision.venueChanged,
                heartbeatDue: writeDecision.heartbeatDue
            )
        }

        api.upsertLiveLocation(
            userId: userId,
            venueName: writeDecision.name,
            latitude: lat,
            longitude: lon
        ) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                self.queue.sync {
                    self.lastWrittenVenue = writeDecision.name
                    self.lastWriteAtMs = Date().timeIntervalSince1970 * 1000
                    self.hadActiveVenueRow = true
                }
                self.logLocationDiag("Supabase upsert ok venue=\(writeDecision.name)")
                DispatchQueue.main.async {
                    self.eventDelegate?.engine(
                        self,
                        didWrite: "upsert",
                        venueName: writeDecision.name
                    )
                }
            case .failure(let err):
                self.notifyWriteError(err)
            }
        }
    }

    private func nearestVenues(
        latitude: Double,
        longitude: Double,
        limit: Int
    ) -> [(name: String, distance: Double)] {
        let venuesSnapshot = queue.sync { venues }
        var scored: [(name: String, distance: Double)] = []
        for venue in venuesSnapshot {
            guard venue.coordinates.count >= 2 else { continue }
            let d = Self.haversineMeters(
                lat1: latitude,
                lon1: longitude,
                lat2: venue.coordinates[0],
                lon2: venue.coordinates[1]
            )
            scored.append((venue.name, d))
        }
        return scored.sorted { $0.distance < $1.distance }.prefix(limit).map { $0 }
    }

    private func nearestVenueDetail(latitude: Double, longitude: Double) -> (name: String, distance: Double)? {
        nearestVenues(latitude: latitude, longitude: longitude, limit: 1).first
    }

    private func logLocationDiag(_ message: String, level: String = "info") {
        DispatchQueue.main.async {
            DiagnosticLog.shared.append(category: "location", message: message, level: level)
        }
    }

    private func notifyWriteError(_ error: Error) {
        let message: String
        if let apiErr = error as? SupabaseAPIError,
           case .httpStatus(let code, let body) = apiErr {
            message = "HTTP \(code): \(body)"
        } else {
            message = error.localizedDescription
        }
        logLocationDiag("Supabase write failed: \(message)", level: "error")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.eventDelegate?.engine(self, didFailWrite: message)
        }
    }

    private static func haversineMeters(
        lat1: Double,
        lon1: Double,
        lat2: Double,
        lon2: Double
    ) -> Double {
        let R = 6_371_000.0
        let phi1 = lat1 * .pi / 180
        let phi2 = lat2 * .pi / 180
        let dPhi = (lat2 - lat1) * .pi / 180
        let dLambda = (lon2 - lon1) * .pi / 180
        let a =
            sin(dPhi / 2) * sin(dPhi / 2)
            + cos(phi1) * cos(phi2) * sin(dLambda / 2) * sin(dLambda / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return R * c
    }
}

protocol VenueLiveLocationEngineDelegate: AnyObject {
    func engine(_ engine: VenueLiveLocationEngine, didUpdateCoordinate coordinate: CLLocationCoordinate2D)
    func engine(
        _ engine: VenueLiveLocationEngine,
        willWrite action: String,
        venueName: String,
        venueChanged: Bool,
        heartbeatDue: Bool
    )
    func engine(_ engine: VenueLiveLocationEngine, didWrite action: String, venueName: String?)
    func engine(_ engine: VenueLiveLocationEngine, didFailWrite message: String)
    func engineDidLoseAuthorization(_ engine: VenueLiveLocationEngine)
}
