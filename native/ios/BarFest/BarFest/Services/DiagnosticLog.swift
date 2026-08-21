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

    /// Safe from CoreLocation / URLSession callbacks off the main actor.
    nonisolated static func log(category: String, message: String, level: String = "info") {
        Task { @MainActor in
            shared.append(category: category, message: message, level: level)
        }
    }

    func clear() {
        entries.removeAll()
    }

    /// Plain-text dump for pasteboard (newest last).
    func exportText(limit: Int = 400) -> String {
        let slice = entries.suffix(limit)
        let df = ISO8601DateFormatter()
        return slice.map { entry in
            "[\(df.string(from: entry.date))] \(entry.level.uppercased()) \(entry.category): \(entry.message)"
        }.joined(separator: "\n")
    }
}
