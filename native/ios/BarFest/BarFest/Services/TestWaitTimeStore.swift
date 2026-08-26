import Foundation

/// In-memory wait reports for Test Mode (merged with live fetches).
@MainActor
final class TestWaitTimeStore: ObservableObject {
    static let shared = TestWaitTimeStore()

    @Published private(set) var reports: [WaitTimeReport] = []

    func upsert(venueName: String, minutes: Int) {
        let now = Date()
        reports.removeAll { $0.venueName == venueName && $0.isMine }
        reports.append(WaitTimeReport(venueName: venueName, minutes: minutes, updatedAt: now))
    }

    func upsertMock(venueName: String, minutes: Int, authorSuffix: String = "mock") {
        let now = Date()
        let authorId = "\(AnonymousIdentity.userId())-\(authorSuffix)"
        reports.removeAll { $0.venueName == venueName && $0.authorId == authorId }
        reports.append(
            WaitTimeReport(venueName: venueName, minutes: minutes, updatedAt: now, authorId: authorId)
        )
    }

    func reports(for venueNames: [String]) -> [WaitTimeReport] {
        let set = Set(venueNames)
        return reports.filter { set.contains($0.venueName) }
    }

    func myReport(for venueName: String) -> Int? {
        reports.first { $0.venueName == venueName && $0.isMine }?.minutes
    }

    func clear() {
        reports = []
    }
}
