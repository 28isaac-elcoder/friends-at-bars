import CoreLocation
import SwiftUI

enum GeographyResolver {
    static let milesToMeters = 1609.344

    static func haversineMeters(
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

    /// Strict: returns geography only when coordinate is inside its radius (no default fallback).
    static func geographyContaining(
        coordinate: CLLocationCoordinate2D?,
        from geographies: [CatalogGeography]
    ) -> CatalogGeography? {
        guard let coordinate else { return nil }
        let inside = geographies.compactMap { geo -> (CatalogGeography, Double)? in
            let meters = haversineMeters(
                lat1: coordinate.latitude,
                lon1: coordinate.longitude,
                lat2: geo.latitude,
                lon2: geo.longitude
            )
            let radius = geo.radius_miles * milesToMeters
            guard meters <= radius else { return nil }
            return (geo, meters)
        }
        return inside.min(by: { $0.1 < $1.1 })?.0
    }

    static func automatic(
        coordinate: CLLocationCoordinate2D?,
        from geographies: [CatalogGeography]
    ) -> CatalogGeography? {
        guard !geographies.isEmpty else { return nil }
        let fallback = geographies.first(where: \.is_default) ?? geographies.first
        guard let coordinate else { return fallback }

        let inside = geographies.compactMap { geo -> (CatalogGeography, Double)? in
            let meters = haversineMeters(
                lat1: coordinate.latitude,
                lon1: coordinate.longitude,
                lat2: geo.latitude,
                lon2: geo.longitude
            )
            let radius = geo.radius_miles * milesToMeters
            guard meters <= radius else { return nil }
            return (geo, meters)
        }
        return inside.min(by: { $0.1 < $1.1 })?.0 ?? fallback
    }
}

extension CatalogArea {
    var accentColor: Color {
        Color(hex: accent_hex) ?? CampusArea.matching(areaRaw: long_name)?.accentColor ?? .blue
    }
}

extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt64(s, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self = Color(red: r, green: g, blue: b)
    }
}
