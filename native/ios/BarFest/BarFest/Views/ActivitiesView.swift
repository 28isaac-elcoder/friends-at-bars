import SwiftUI

struct ActivitiesView: View {
    @EnvironmentObject private var appModel: AppModel
    @ObservedObject private var testMode = TestModeStore.shared
    @ObservedObject private var locationAuth = LocationAuthorizationStore.shared
    @State private var checkIns: [CheckInRow] = []
    @State private var error: String?
    @State private var populationSort: PopulationSort = .mostPopulated
    @State private var areaFilter: CampusArea?

    private var priorityDeals: [CatalogListing] {
        appModel.listings
            .filter { $0.priority > 0 }
            .sorted { $0.priority < $1.priority }
    }

    private var filteredVenues: [CatalogVenue] {
        var list = appModel.venues
        if let areaFilter {
            list = list.filter { $0.area == areaFilter.rawValue }
        }
        list.sort { a, b in
            let ca = appModel.venueCounts[a.name, default: 0]
            let cb = appModel.venueCounts[b.name, default: 0]
            if ca != cb {
                return populationSort == .mostPopulated ? ca > cb : ca < cb
            }
            return a.sort_order < b.sort_order
        }
        return list
    }

    /// Show live bar headcounts when OS location is allowed (mock mode still uses mock counts).
    private var showBarAttendance: Bool {
        locationAuth.isAuthorized
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if testMode.useMockCheckIns {
                        Text("Test Mode: showing mock headcounts")
                            .font(.caption)
                            .foregroundStyle(.cyan)
                    }

                    PriorityDealsCarousel(items: priorityDeals)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Menu {
                                ForEach(PopulationSort.allCases) { sort in
                                    Button {
                                        populationSort = sort
                                    } label: {
                                        HStack {
                                            Text(sort.rawValue)
                                            if populationSort == sort {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                Label(populationSort.rawValue, systemImage: "arrow.up.arrow.down")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                            .disabled(!showBarAttendance)

                            if areaFilter != nil {
                                Button {
                                    areaFilter = nil
                                    populationSort = .mostPopulated
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                }
                                .accessibilityLabel("Clear area filter")
                            }
                        }

                        if showBarAttendance {
                            HorizontalChipScroll {
                                ForEach(CampusArea.allCases) { area in
                                    Button {
                                        if areaFilter == area {
                                            areaFilter = nil
                                            populationSort = .mostPopulated
                                        } else {
                                            areaFilter = area
                                            populationSort = .mostPopulated
                                        }
                                    } label: {
                                        Text(shortAreaLabel(area))
                                            .font(.caption.weight(.semibold))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 7)
                                            .background(
                                                areaFilter == area
                                                    ? Color.accentColor.opacity(0.35)
                                                    : Color.white.opacity(0.1)
                                            )
                                            .foregroundStyle(areaFilter == area ? Color.accentColor : .primary)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    Text(areaFilter == nil ? "Bars" : areaFilter!.rawValue)
                        .font(.headline)

                    if showBarAttendance {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredVenues) { venue in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(venue.name)
                                            .font(.body.weight(.medium))
                                        Text(venue.area)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("\(appModel.venueCounts[venue.name, default: 0])")
                                        .font(.body.monospacedDigit().weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 14)
                                Divider().opacity(0.35)
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                        )
                    } else {
                        ActivitiesLocationInlineGate()
                    }

                    if showBarAttendance && !testMode.useMockCheckIns {
                        Text("Recent check-ins")
                            .font(.headline)
                            .padding(.top, 4)
                        if let error {
                            Text(error).font(.caption).foregroundStyle(.red)
                        }
                        ForEach(checkIns.prefix(10)) { row in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.venue).font(.subheadline.weight(.semibold))
                                Text(row.displaySubtitle)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                        }
                    }
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Activities")
            .refreshable { await reload() }
            .task { await reload() }
            .onChange(of: testMode.useMockCheckIns) { _, _ in
                Task { await appModel.refreshCatalog(); await reload() }
            }
            .onAppear { locationAuth.refresh() }
        }
    }

    private func shortAreaLabel(_ area: CampusArea) -> String {
        switch area {
        case .northCampus: return "North Campus"
        case .southCampus: return "South Campus"
        case .shortNorth: return "Short North"
        case .grandview: return "Grandview"
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
