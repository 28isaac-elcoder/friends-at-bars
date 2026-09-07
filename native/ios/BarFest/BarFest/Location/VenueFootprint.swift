import Foundation
import CoreLocation

/// One corner of a venue footprint polygon (NW → NE → SE → SW).
struct VenueFootprintCorner: Codable, Hashable {
    var lat: Double
    var lng: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

enum VenueFootprintGeometry {
    static let defaultHalfMeters: Double = 10
    static let stickyBufferMeters: Double = 15

    /// Default axis-aligned square: halfMeters toward NW / NE / SE / SW from center.
    static func defaultCorners(
        centerLat: Double,
        centerLng: Double,
        halfMeters: Double = defaultHalfMeters
    ) -> [VenueFootprintCorner] {
        [
            offset(lat: centerLat, lng: centerLng, northM: halfMeters, eastM: -halfMeters), // NW
            offset(lat: centerLat, lng: centerLng, northM: halfMeters, eastM: halfMeters),  // NE
            offset(lat: centerLat, lng: centerLng, northM: -halfMeters, eastM: halfMeters), // SE
            offset(lat: centerLat, lng: centerLng, northM: -halfMeters, eastM: -halfMeters), // SW
        ]
    }

    static func offset(
        lat: Double,
        lng: Double,
        northM: Double,
        eastM: Double
    ) -> VenueFootprintCorner {
        let cosLat = max(cos(lat * .pi / 180), 0.01)
        return VenueFootprintCorner(
            lat: lat + northM / 111_320.0,
            lng: lng + eastM / (111_320.0 * cosLat)
        )
    }

    static func resolveCorners(
        footprint: [VenueFootprintCorner]?,
        centerLat: Double,
        centerLng: Double
    ) -> [VenueFootprintCorner] {
        if let footprint, footprint.count >= 3 {
            return footprint
        }
        return defaultCorners(centerLat: centerLat, centerLng: centerLng)
    }

    /// Ray-cast point-in-polygon.
    static func contains(
        latitude: Double,
        longitude: Double,
        corners: [VenueFootprintCorner]
    ) -> Bool {
        guard corners.count >= 3 else { return false }
        var inside = false
        var j = corners.count - 1
        for i in 0 ..< corners.count {
            let yi = corners[i].lat
            let xi = corners[i].lng
            let yj = corners[j].lat
            let xj = corners[j].lng
            let intersect =
                ((yi > latitude) != (yj > latitude))
                && (longitude < (xj - xi) * (latitude - yi) / (yj - yi) + xi)
            if intersect { inside.toggle() }
            j = i
        }
        return inside
    }

    /// Meters to nearest edge (0 if inside).
    static func distanceMetersToEdge(
        latitude: Double,
        longitude: Double,
        corners: [VenueFootprintCorner]
    ) -> Double {
        guard corners.count >= 2 else { return .greatestFiniteMagnitude }
        if contains(latitude: latitude, longitude: longitude, corners: corners) {
            return 0
        }
        let cosLat = max(cos(latitude * .pi / 180), 0.01)
        var minD = Double.greatestFiniteMagnitude
        var j = corners.count - 1
        for i in 0 ..< corners.count {
            let ax = (corners[j].lng - longitude) * 111_320.0 * cosLat
            let ay = (corners[j].lat - latitude) * 111_320.0
            let bx = (corners[i].lng - longitude) * 111_320.0 * cosLat
            let by = (corners[i].lat - latitude) * 111_320.0
            let dx = bx - ax
            let dy = by - ay
            let denom = dx * dx + dy * dy
            let t: Double
            if denom <= 0 {
                t = 0
            } else {
                t = max(0, min(1, (-ax * dx + -ay * dy) / denom))
            }
            let px = ax + t * dx
            let py = ay + t * dy
            minD = min(minD, sqrt(px * px + py * py))
            j = i
        }
        return minD
    }

    static func isInStickyZone(
        latitude: Double,
        longitude: Double,
        corners: [VenueFootprintCorner],
        bufferMeters: Double = stickyBufferMeters
    ) -> Bool {
        distanceMetersToEdge(latitude: latitude, longitude: longitude, corners: corners) <= bufferMeters
    }

    static func centerDistanceMeters(
        latitude: Double,
        longitude: Double,
        centerLat: Double,
        centerLng: Double
    ) -> Double {
        haversineMeters(
            lat1: latitude,
            lon1: longitude,
            lat2: centerLat,
            lon2: centerLng
        )
    }

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
}

extension CatalogVenue {
    var footprintCorners: [VenueFootprintCorner] {
        VenueFootprintGeometry.resolveCorners(
            footprint: footprint,
            centerLat: latitude,
            centerLng: longitude
        )
    }
}
