import SwiftUI

struct ActivitiesView: View {
    @EnvironmentObject private var appModel: AppModel
    @ObservedObject private var testMode = TestModeStore.shared
    @State private var checkIns: [CheckInRow] = []
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                if testMode.useMockCheckIns {
                    Section {
                        Text("Test Mode: showing mock headcounts")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
                Section("Live headcounts") {
                    ForEach(appModel.venues.prefix(20)) { venue in
                        HStack {
                            Text(venue.name)
                            Spacer()
                            Text("\(appModel.venueCounts[venue.name, default: 0])")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
                Section("Recent check-ins") {
                    if let error {
                        Text(error).foregroundStyle(.red)
                    }
                    ForEach(checkIns) { row in
                        VStack(alignment: .leading) {
                            Text(row.venue_name).font(.headline)
                            Text(row.created_at)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Activities")
            .refreshable { await reload() }
            .task { await reload() }
            .onChange(of: testMode.useMockCheckIns) { _, _ in
                Task { await appModel.refreshCatalog(); await reload() }
            }
        }
    }

    private func reload() async {
        await appModel.refreshCatalog()
        if testMode.useMockCheckIns {
            checkIns = []
            error = nil
            return
        }
        do {
            checkIns = try await CheckInService.recent()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}
