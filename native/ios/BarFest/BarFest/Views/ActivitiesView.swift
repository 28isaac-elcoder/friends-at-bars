import SwiftUI

struct ActivitiesView: View {
    @EnvironmentObject private var appModel: AppModel
    @ObservedObject private var testMode = TestModeStore.shared
    @ObservedObject private var locationAuth = LocationAuthorizationStore.shared
    @State private var populationSort: PopulationSort = .mostPopulated
    @State private var areaFilter: CampusArea?
    @State private var selectedVenue: CatalogVenue?

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

    /// Live: OS location. Test Mode + mock: simulate-location toggle (Chat parity).
    private var showBarAttendance: Bool {
        if testMode.uiEnabled && testMode.useMockCheckIns {
            return testMode.simulateLocationAllowed
        }
        return locationAuth.isAuthorized
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if testMode.useMockCheckIns {
                        HStack(spacing: 10) {
                            Text("Test Mode: showing mock headcounts")
                                .font(.caption)
                                .foregroundStyle(.cyan)
                            Spacer(minLength: 8)
                            Button {
                                testMode.simulateLocationAllowed.toggle()
                                DiagnosticLog.shared.append(
                                    category: "system",
                                    message: "Activities simulate location allowed=\(testMode.simulateLocationAllowed)"
                                )
                            } label: {
                                Image(systemName: testMode.simulateLocationAllowed
                                      ? "location.fill"
                                      : "location.slash")
                                    .font(.body.weight(.semibold))
                            }
                            .accessibilityLabel(
                                testMode.simulateLocationAllowed
                                    ? "Simulate location on"
                                    : "Simulate location off"
                            )
                        }
                    }

                    PriorityDealsCarousel(items: priorityDeals)

                    if showBarAttendance {
                        HorizontalChipScroll {
                            ForEach(CampusArea.allCases) { area in
                                AreaFilterChip(
                                    area: area,
                                    selected: areaFilter == area
                                ) {
                                    if areaFilter == area {
                                        areaFilter = nil
                                        populationSort = .mostPopulated
                                    } else {
                                        areaFilter = area
                                        populationSort = .mostPopulated
                                    }
                                }
                            }
                        }
                    }

                    HStack(alignment: .center, spacing: 8) {
                        Text(areaFilter == nil ? "Bars" : areaFilter!.rawValue)
                            .font(.headline)
                        Spacer(minLength: 8)
                        Button {
                            populationSort.toggle()
                        } label: {
                            Label(populationSort.rawValue, systemImage: "arrow.up.arrow.down")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(!showBarAttendance)
                        .accessibilityLabel("Toggle population sort")
                    }

                    if showBarAttendance {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredVenues) { venue in
                                Button {
                                    selectedVenue = venue
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(venue.name)
                                                .font(.body.weight(.medium))
                                                .foregroundStyle(.primary)
                                            Text(venue.area)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text("\(appModel.venueCounts[venue.name, default: 0])")
                                            .font(.body.monospacedDigit().weight(.semibold))
                                            .foregroundStyle(.secondary)
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 14)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
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
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await reload(fromPullToRefresh: true) }
            .task { await reload() }
            .onChange(of: testMode.useMockCheckIns) { _, _ in
                Task { await appModel.refreshCatalog(); await reload() }
            }
            .onAppear { locationAuth.refresh() }
            .sheet(item: $selectedVenue) { venue in
                VenueBarSheet(
                    venue: venue,
                    listings: todaysListings(for: venue)
                )
                .presentationDetents([.medium, .large])
            }
        }
    }

    /// Deals/events for this venue that apply today (empty `days_of_week` = any day).
    private func todaysListings(for venue: CatalogVenue) -> [CatalogListing] {
        let day = DayFilter.today.rawValue
        return appModel.listings
            .filter { listing in
                listing.venue_name.caseInsensitiveCompare(venue.name) == .orderedSame
                    && (listing.days_of_week.isEmpty || listing.days_of_week.contains(day))
            }
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
                return lhs.title < rhs.title
            }
    }

    private func reload(fromPullToRefresh: Bool = false) async {
        if fromPullToRefresh {
            DiagnosticLog.shared.append(
                category: "location",
                message: "Activities pull-to-refresh — refreshing live headcounts"
            )
            await appModel.refreshHeadcounts(source: "activities-pull")
        } else {
            await appModel.refreshCatalog()
        }
    }
}
