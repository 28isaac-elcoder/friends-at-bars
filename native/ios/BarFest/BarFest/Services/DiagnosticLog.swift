import Foundation
import Combine

struct DiagnosticEntry: Identifiable, Equatable {
    let id: UUID
    let date: Date
    let category: String
    let level: String
    let message: String

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        category: String,
        level: String = "info",
        message: String
    ) {
        self.id = id
        self.date = date
        self.category = category
        self.level = level
        self.message = message
    }
}

/// Ring buffer for the in-app Log screen (Cap `diagnosticLog` parity).
@MainActor
final class DiagnosticLog: ObservableObject {
    static let shared = DiagnosticLog()

    private let maxEntries = 400
    @Published private(set) var entries: [DiagnosticEntry] = []

    private init() {}

    func append(category: String, message: String, level: String = "info") {
        entries.append(
            DiagnosticEntry(category: category, level: level, message: message)
        )
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    func clear() {
        entries.removeAll()
    }
}
