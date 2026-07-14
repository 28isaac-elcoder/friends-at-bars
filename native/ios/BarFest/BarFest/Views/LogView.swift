import SwiftUI

struct LogView: View {
    @EnvironmentObject private var appModel: AppModel
    @ObservedObject private var log = DiagnosticLog.shared
    @ObservedObject private var testMode = TestModeStore.shared
    @State private var filter = "all"
    @State private var statusText = ""

    private var filtered: [DiagnosticEntry] {
        let list = log.entries.reversed()
        if filter == "all" { return Array(list) }
        return list.filter { $0.category == filter }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(["all", "location", "system", "chat", "error"], id: \.self) { cat in
                            Button(cat) { filter = cat }
                                .buttonStyle(.bordered)
                                .tint(filter == cat ? .accentColor : .secondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                Text(statusText)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 6)

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
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.plain)
            }
            .navigationTitle("Log")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear") { log.clear() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Refresh") { refreshStatus() }
                }
            }
            .task {
                DiagnosticLog.shared.append(category: "system", message: "Log page opened")
                refreshStatus()
            }
        }
    }

    private func refreshStatus() {
        let engine = VenueLiveLocationEngine.shared.currentState()
        let uid = AnonymousIdentity.userId()
        let prefix = String(uid.prefix(20))
        statusText = """
        bundle=\(Bundle.main.bundleIdentifier ?? "?")
        userId=\(prefix)…
        lastVenue=\(appModel.lastVenueName ?? "nil")
        engineRunning=\(engine.isRunning) lastWrite=\(engine.lastWriteAtMs)
        testModeMock=\(testMode.useMockCheckIns) simLoc=\(testMode.simulateLocationAllowed)
        supabaseURL=\(AppConfig.supabaseURL.prefix(40))…
        venues=\(appModel.venues.count)
        """
        DiagnosticLog.shared.append(category: "system", message: "Status refresh")
    }
}
