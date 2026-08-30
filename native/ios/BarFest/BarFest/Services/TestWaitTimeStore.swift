import Foundation
import Combine

/// Locally persisted wait reports for Test Mode (merged with live fetches).
@MainActor
final class TestWaitTimeStore: ObservableObject {
    static let shared = TestWaitTimeStore()
    private let reportsKey = "barfest_test_wait_time_reports"

    @Published private(set) var reports: [WaitTimeReport] = []

    private init() {
        load()
    }

    func upsert(venueName: String, minutes: Int) {
        let now = Date()
        reports.removeAll { $0.venueName == venueName && $0.isMine }
        reports.append(WaitTimeReport(venueName: venueName, minutes: minutes, updatedAt: now))
        persist()
    }

    func upsertMock(venueName: String, minutes: Int, authorSuffix: String = "mock") {
        let now = Date()
        let authorId = "\(AnonymousIdentity.userId())-\(authorSuffix)"
        reports.removeAll { $0.venueName == venueName && $0.authorId == authorId }
        reports.append(
            WaitTimeReport(venueName: venueName, minutes: minutes, updatedAt: now, authorId: authorId)
        )
        persist()
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
        persist()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: reportsKey),
              let saved = try? JSONDecoder().decode([WaitTimeReport].self, from: data)
        else {
            return
        }
        reports = saved
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(reports) else { return }
        UserDefaults.standard.set(data, forKey: reportsKey)
    }
}
