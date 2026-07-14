import SwiftUI

struct DealsView: View {
    @EnvironmentObject private var appModel: AppModel

    private var todayIndex: Int {
        Calendar.current.component(.weekday, from: Date()) - 1 // 0 = Sunday
    }

    private var todayListings: [CatalogListing] {
        appModel.listings
            .filter { $0.days_of_week.isEmpty || $0.days_of_week.contains(todayIndex) }
            .sorted { $0.priority > $1.priority }
    }

    var body: some View {
        NavigationStack {
            List(todayListings) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.venue_name)
                        .font(.headline)
                    if !item.title.isEmpty {
                        Text(item.title).font(.subheadline.weight(.semibold))
                    }
                    if !item.time_label.isEmpty {
                        Text(item.time_label).font(.caption).foregroundStyle(.secondary)
                    }
                    if !item.details.isEmpty {
                        Text(item.details).font(.body)
                    }
                    HStack {
                        ForEach(item.type_labels, id: \.self) { label in
                            Text(label)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Deals")
            .overlay {
                if todayListings.isEmpty {
                    ContentUnavailableView(
                        "No deals yet",
                        systemImage: "tag",
                        description: Text("Pull to refresh after seeding catalog_listings in Supabase.")
                    )
                }
            }
            .refreshable { await appModel.refreshCatalog() }
        }
    }
}
