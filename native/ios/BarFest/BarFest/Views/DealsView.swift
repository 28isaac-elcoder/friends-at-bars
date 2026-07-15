import SwiftUI

struct DealsView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var dayFilter: DayFilter = .all
    @State private var areaFilter: CampusArea? = nil
    /// When true, show all areas (alongside day filter). Distinct from nil area clearing.
    @State private var showAllAreas = true

    private var filteredListings: [CatalogListing] {
        appModel.listings
            .filter { listing in
                if dayFilter != .all {
                    let day = dayFilter.rawValue
                    if !listing.days_of_week.isEmpty && !listing.days_of_week.contains(day) {
                        return false
                    }
                }
                if !showAllAreas, let areaFilter {
                    if listing.area != areaFilter.rawValue {
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
                    // Day-of-week dropdown (red box region)
                    Menu {
                        ForEach(DayFilter.allCases) { day in
                            Button {
                                dayFilter = day
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

                    Text("Weekly specials and events. Use day and area filters above. Showing \(filteredListings.count) of \(appModel.listings.count).")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Area filters — horizontal-only (no vertical rubber-band)
                    HorizontalChipScroll {
                        areaChip(title: "All", selected: showAllAreas) {
                            showAllAreas = true
                            areaFilter = nil
                        }
                        ForEach(CampusArea.allCases) { area in
                            areaChip(
                                title: shortArea(area),
                                selected: !showAllAreas && areaFilter == area
                            ) {
                                showAllAreas = false
                                areaFilter = area
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 12)

                if filteredListings.isEmpty {
                    ContentUnavailableView(
                        "No deals",
                        systemImage: "tag",
                        description: Text("Try another day or area, or pull to refresh.")
                    )
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
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await appModel.refreshCatalog() }
        }
    }

    private func areaChip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(selected ? Color.accentColor.opacity(0.35) : Color.white.opacity(0.1))
                .foregroundStyle(selected ? Color.accentColor : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func shortArea(_ area: CampusArea) -> String {
        switch area {
        case .northCampus: return "North Campus"
        case .southCampus: return "South Campus"
        case .shortNorth: return "Short North"
        case .grandview: return "Grandview"
        }
    }

    private func dayNames(_ days: [Int]) -> String {
        let map = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return days.sorted().compactMap { d in
            (0 ..< map.count).contains(d) ? map[d] : nil
        }.joined(separator: ", ")
    }
}
