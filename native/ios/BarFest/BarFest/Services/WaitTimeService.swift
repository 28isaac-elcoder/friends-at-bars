import Foundation

enum WaitTimeService {
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// Fetches reports still within the longest possible influence window (45+ bucket).
    static func fetchReports(geographyId: UUID) async throws -> [WaitTimeReport] {
        let cutoff = Date().addingTimeInterval(-TimeInterval(AppConfig.waitTimeMaxInfluenceSeconds))
        let cutoffString = isoFormatter.string(from: cutoff)

        let rows: [WaitTimeReportRow] = try await SupabaseClient.shared.get(
            path: "rest/v1/venue_wait_reports",
            query: [
                URLQueryItem(name: "geography_id", value: "eq.\(geographyId.uuidString)"),
                URLQueryItem(name: "updated_at", value: "gt.\(cutoffString)"),
                URLQueryItem(name: "select", value: "venue_name,wait_minutes,updated_at,author_id"),
                URLQueryItem(name: "order", value: "updated_at.desc"),
            ]
        )
        return rows.map { WaitTimeReport(row: $0, formatter: isoFormatter) }
    }

    static func submitReport(
        venueName: String,
        waitMinutes: Int,
        latitude: Double?,
        longitude: Double?,
        isMock: Bool
    ) async throws {
        var params: [String: Any] = [
            "p_author_id": AnonymousIdentity.userId(),
            "p_venue_name": venueName,
            "p_wait_minutes": waitMinutes,
            "p_is_mock": isMock,
        ]
        if let latitude, let longitude {
            params["p_latitude"] = latitude
            params["p_longitude"] = longitude
        } else {
            params["p_latitude"] = NSNull()
            params["p_longitude"] = NSNull()
        }

        DiagnosticLog.log(
            category: "location",
            message: "wait report submit venue=\(venueName) min=\(waitMinutes) mock=\(isMock)"
        )
        do {
            try await SupabaseClient.shared.rpcVoid("submit_venue_wait_report", params: params)
            DiagnosticLog.log(category: "location", message: "wait report submit ok venue=\(venueName)")
        } catch {
            DiagnosticLog.log(
                category: "location",
                message: "wait report submit failed: \(error.localizedDescription)",
                level: "error"
            )
            throw error
        }
    }
}
