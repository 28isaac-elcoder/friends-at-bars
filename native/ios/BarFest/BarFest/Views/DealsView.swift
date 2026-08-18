import SwiftUI

struct DealsView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var dayFilter: DayFilter = .today
    @State private var areaFilter: String?
    @State private var venueSearch = ""
    @FocusState private var searchFocused: Bool

    private var searchQuery: String {
        venueSearch.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredListings: [CatalogListing] {
        appModel.scopedListings
            .filter { listing in
                if dayFilter != .all {
                    let day = dayFilter.rawValue
                    if !listing.days_of_week.isEmpty && !listing.days_of_week.contains(day) {
                        return false
                    }
                }
                if let areaFilter {
                    if listing.area != areaFilter {
                        return false
                    }
                }
                if !searchQuery.isEmpty {
                    if !listing.venue_name.localizedCaseInsensitiveContains(searchQuery) {
                        return false
                    }
                }
                return true
            }
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
                return lhs.venue_name < rhs.venue_name
            }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    Menu {
                        ForEach(DayFilter.allCases) { day in
                            Button {
                                dayFilter = day
                                searchFocused = false
                            } label: {
                                HStack {
                                    Text(day.label)
                                    if dayFilter == day { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(dayFilter.label)
                                .font(.title2.bold())
                            Image(systemName: "chevron.down")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                        }
                        .foregroundStyle(.primary)
                    }

                    HorizontalChipScroll {
                        ForEach(appModel.scopedAreas) { area in
                            AreaFilterChip(
                                title: area.short_name,
                                accent: area.accentColor,
                                selected: areaFilter == area.long_name
                            ) {
                                searchFocused = false
                                if areaFilter == area.long_name {
                                    areaFilter = nil
                                } else {
                                    areaFilter = area.long_name
                                }
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search bars", text: $venueSearch)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.search)
                            .focused($searchFocused)
                            .onSubmit { searchFocused = false }
                        if !venueSearch.isEmpty {
                            Button {
                                venueSearch = ""
                                searchFocused = false
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Clear search")
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 12)

                if filteredListings.isEmpty {
                    if !searchQuery.isEmpty {
                        ContentUnavailableView(
                            "No Deals Found From That Search",
                            systemImage: "magnifyingglass",
                            description: Text("Try another bar name, day, or area.")
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .dismissKeyboardOnTap()
                    } else {
                        ContentUnavailableView(
                            "No deals",
                            systemImage: "tag",
                            description: Text("Try another day or area, or pull to refresh.")
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .dismissKeyboardOnTap()
                    }
                } else {
                    List(filteredListings) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(item.venue_name)
                                    .font(.headline)
                                Spacer()
                                if !item.area.isEmpty {
                                    Text(item.area)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            if !item.title.isEmpty {
                                Text(item.title).font(.subheadline.weight(.semibold))
                            }
                            if !item.time_label.isEmpty {
                                Text(item.time_label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if !item.details.isEmpty {
                                Text(item.details).font(.body)
                            }
                            HStack(spacing: 6) {
                                ForEach(item.type_labels, id: \.self) { label in
                                    Text(label)
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.white.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                                if !item.days_of_week.isEmpty {
                                    Text(dayNames(item.days_of_week))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground))
                    }
                    .listStyle(.plain)
                    .scrollDismissesKeyboard(.interactively)
                    .dismissKeyboardOnTap()
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await appModel.refreshCatalog() }
            .onAppear { logDealsDiagnostics(event: "appear") }
            .onChange(of: appModel.listings.count) { _, _ in
                logDealsDiagnostics(event: "listings-changed")
            }
            .onChange(of: dayFilter) { _, _ in logDealsDiagnostics(event: "day-filter") }
            .onChange(of: areaFilter) { _, _ in logDealsDiagnostics(event: "area-filter") }
            .onChange(of: appModel.resolvedGeography?.id) { _, _ in
                areaFilter = nil
            }
        }
    }

    private func logDealsDiagnostics(event: String) {
        let areas = Dictionary(grouping: appModel.listings, by: \.area).mapValues(\.count)
        let areaSummary = areas.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        DiagnosticLog.shared.append(
            category: "system",
            message: """
            Deals[\(event)] total=\(appModel.listings.count) visible=\(filteredListings.count) \
            day=\(dayFilter.label) area=\(areaFilter ?? "All")
            """
        )
        if !areaSummary.isEmpty {
            DiagnosticLog.shared.append(
                category: "system",
                message: "Deals listing areas: \(areaSummary)"
            )
        }
        if appModel.listings.count <= 6 {
            DiagnosticLog.shared.append(
                category: "system",
                message: "Deals: Supabase returned only \(appModel.listings.count) listings — UI cannot show more until DB is re-seeded"
            )
        }
    }

    private func dayNames(_ days: [Int]) -> String {
        let map = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return days.sorted().compactMap { d in
            (0 ..< map.count).contains(d) ? map[d] : nil
        }.joined(separator: ", ")
    }
}
