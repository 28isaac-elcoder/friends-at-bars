import SwiftUI
import UIKit

struct LogView: View {
    @EnvironmentObject private var appModel: AppModel
    @ObservedObject private var log = DiagnosticLog.shared
    @ObservedObject private var testMode = TestModeStore.shared
    @State private var filter = "all"
    @State private var statusText = ""
    @State private var copyFlash: String?

    private var filtered: [DiagnosticEntry] {
        let list = log.entries.reversed()
        if filter == "all" { return Array(list) }
        return list.filter { $0.category == filter }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                HorizontalChipScroll {
                    ForEach(["all", "location", "system", "chat", "error"], id: \.self) { cat in
                        Button(cat) { filter = cat }
                            .buttonStyle(.bordered)
                            .tint(filter == cat ? .accentColor : .secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                Text(statusText)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 6)
                    .textSelection(.enabled)

                if let copyFlash {
                    Text(copyFlash)
                        .font(.caption2)
                        .foregroundStyle(.cyan)
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                }

                List(filtered) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(entry.category.uppercased())
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(entry.date, style: .time)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Text(entry.message)
                            .font(.caption.monospaced())
                            .foregroundStyle(entry.level == "error" ? .red : .primary)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 2)
                    .contextMenu {
                        Button("Copy line") {
                            copyText(formatEntry(entry), flash: "Copied line")
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button("Copy") {
                            copyText(formatEntry(entry), flash: "Copied line")
                        }
                        .tint(.blue)
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Log")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Refresh") { refreshStatus() }
                }
                ToolbarItem(placement: .principal) {
                    Button {
                        copyVisibleLogs()
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                            .font(.subheadline.weight(.semibold))
                    }
                    .disabled(filtered.isEmpty)
                    .accessibilityLabel("Copy visible logs (\(filtered.count))")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear") { log.clear() }
                }
            }
            .task {
                DiagnosticLog.shared.append(category: "system", message: "Log page opened")
                refreshStatus()
            }
        }
    }

    private func copyVisibleLogs() {
        let filterLabel = filter == "all" ? "all" : filter
        let body = filtered.map(formatEntry).joined(separator: "\n")
        copyText(body, flash: "Copied \(filtered.count) \(filterLabel) log\(filtered.count == 1 ? "" : "s")")
    }

    private func formatEntry(_ entry: DiagnosticEntry) -> String {
        let df = ISO8601DateFormatter()
        return "[\(df.string(from: entry.date))] \(entry.level.uppercased()) \(entry.category): \(entry.message)"
    }

    private func copyText(_ text: String, flash: String) {
        UIPasteboard.general.string = text
        copyFlash = flash
        DiagnosticLog.shared.append(category: "system", message: flash)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if copyFlash == flash { copyFlash = nil }
        }
    }

    private func refreshStatus() {
        let engine = VenueLiveLocationEngine.shared.currentState()
        let uid = AnonymousIdentity.userId()
        let prefix = String(uid.prefix(20))
        let auth = LocationAuthorizationStore.shared.status.rawValue
        statusText = """
        bundle=\(Bundle.main.bundleIdentifier ?? "?")
        userId=\(prefix)…
        lastVenue=\(appModel.lastVenueName ?? "nil")
        engineRunning=\(engine.isRunning) lastWrite=\(engine.lastWriteAtMs)
        locationAuth=\(auth)
        testModeMock=\(testMode.useMockCheckIns) simLoc=\(testMode.simulateLocationAllowed)
        supabaseURL=\(AppConfig.supabaseURL.prefix(40))…
        venues=\(appModel.venues.count) listings=\(appModel.listings.count)
        """
        DiagnosticLog.shared.append(category: "system", message: "Status refresh")
    }
}
