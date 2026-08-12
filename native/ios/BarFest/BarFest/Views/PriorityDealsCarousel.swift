import SwiftUI

/// Priority deals carousel (web Activities `BarDealsCarousel` parity) — dark theme.
/// Shows a "Hot Deals" placeholder for a short beat, then crossfades into the cycling deals.
struct PriorityDealsCarousel: View {
    let items: [CatalogListing]
    @State private var index = 0
    @State private var detailItem: CatalogListing?
    @State private var cycleToken = UUID()
    @State private var showPlaceholder = true
    private let rotateSeconds: TimeInterval = 3
    private let placeholderSeconds: TimeInterval = 1.6

    private static let fullDayNames = [
        "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday",
    ]

    private static let cardFill = Color(red: 0.18, green: 0.16, blue: 0.12)
    private static let cardStroke = Color(red: 0.45, green: 0.38, blue: 0.22).opacity(0.6)
    private static let gold = Color(red: 0.85, green: 0.72, blue: 0.45)

    var body: some View {
        ZStack {
            if showPlaceholder {
                hotDealsPlaceholder
                    .transition(.opacity)
            } else if !items.isEmpty {
                carouselBody
                    .transition(.opacity)
            }
        }
        .frame(
            maxWidth: .infinity,
            minHeight: (showPlaceholder || !items.isEmpty) ? 118 : 0,
            alignment: .top
        )
        .animation(.easeInOut(duration: 0.45), value: showPlaceholder)
        .animation(.easeInOut(duration: 0.45), value: items.isEmpty)
        .sheet(item: $detailItem) { item in
            PriorityDealDetailSheet(item: item)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            index = 0
        }
        .onChange(of: items.map(\.id)) { _, _ in
            index = 0
            cycleToken = UUID()
        }
        .task {
            guard showPlaceholder else { return }
            try? await Task.sleep(nanoseconds: UInt64(placeholderSeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.45)) {
                showPlaceholder = false
            }
        }
    }

    private var hotDealsPlaceholder: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BAR DEAL")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Self.gold)
                .tracking(0.6)
            Text("Hot Deals")
                .font(.title3.bold())
                .foregroundStyle(.white)
            Text(" ")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.7))
                .accessibilityHidden(true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Self.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Self.cardStroke, lineWidth: 1)
                )
        )
        .accessibilityLabel("Hot Deals loading")
    }

    private var current: CatalogListing { items[index % items.count] }

    private var carouselBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(carouselLabel(for: current.type_labels))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Self.gold)
                        .tracking(0.6)
                    HStack(spacing: 6) {
                        ForEach(current.type_labels, id: \.self) { label in
                            Text(label)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(badgeColor(for: label).opacity(0.25))
                                .foregroundStyle(badgeColor(for: label))
                                .clipShape(Capsule())
                        }
                    }
                }
                Spacer(minLength: 8)
                if items.count > 1 {
                    HStack(spacing: 5) {
                        ForEach(0 ..< items.count, id: \.self) { i in
                            Circle()
                                .fill(i == index ? Color(red: 0.78, green: 0.62, blue: 0.35) : Color.white.opacity(0.25))
                                .frame(width: 6, height: 6)
                        }
                    }
                }
            }

            if !current.title.isEmpty {
                Text(current.title)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            }
            Text(current.venue_name)
                .font(current.title.isEmpty ? .title3.bold() : .subheadline.weight(.semibold))
                .foregroundStyle(.white)
            if let when = dayTimeLabel(current), !when.isEmpty {
                Text(when)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Self.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Self.cardStroke, lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            detailItem = current
        }
        .simultaneousGesture(swipeGesture)
        .task(id: "\(items.count)-\(cycleToken.uuidString)-\(showPlaceholder)") {
            guard !showPlaceholder, items.count > 1 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(rotateSeconds * 1_000_000_000))
                guard !Task.isCancelled, !showPlaceholder, items.count > 1 else { break }
                guard detailItem == nil else { continue }
                withAnimation(.easeInOut(duration: 0.25)) {
                    index = (index + 1) % items.count
                }
            }
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                guard items.count > 1 else { return }
                let dx = value.translation.width
                let dy = value.translation.height
                guard abs(dx) > abs(dy), abs(dx) > 40 else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    if dx < 0 {
                        index = (index + 1) % items.count
                    } else {
                        index = (index - 1 + items.count) % items.count
                    }
                }
                cycleToken = UUID()
            }
    }

    private func carouselLabel(for labels: [String]) -> String {
        if labels.contains(where: { $0.localizedCaseInsensitiveContains("event") }) {
            return "BAR EVENT"
        }
        return "BAR DEAL"
    }

    private func badgeColor(for label: String) -> Color {
        if label.localizedCaseInsensitiveContains("event") {
            return .purple
        }
        return Color(red: 0.9, green: 0.75, blue: 0.35)
    }

    private func dayTimeLabel(_ item: CatalogListing) -> String? {
        let days = item.days_of_week.sorted()
        let dayPart: String
        if days.isEmpty {
            dayPart = ""
        } else if days.count == 1, let d = days.first, (0 ..< Self.fullDayNames.count).contains(d) {
            dayPart = Self.fullDayNames[d]
        } else {
            let short = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            dayPart = days.compactMap { d in
                (0 ..< short.count).contains(d) ? short[d] : nil
            }.joined(separator: ", ")
        }
        let time = item.time_label.trimmingCharacters(in: .whitespacesAndNewlines)
        if dayPart.isEmpty && time.isEmpty { return nil }
        if dayPart.isEmpty { return time }
        if time.isEmpty { return dayPart }
        return "\(dayPart)  \(time)"
    }
}

private struct PriorityDealDetailSheet: View {
    let item: CatalogListing
    @Environment(\.dismiss) private var dismiss

    private static let fullDayNames = [
        "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday",
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 6) {
                        ForEach(item.type_labels, id: \.self) { label in
                            Text(label)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }

                    if !item.title.isEmpty {
                        Text(item.title)
                            .font(.title2.bold())
                    }
                    Text(item.venue_name)
                        .font(.title3.weight(.semibold))
                    if !item.area.isEmpty {
                        Text(item.area)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if !item.time_label.isEmpty || !item.days_of_week.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            if !item.days_of_week.isEmpty {
                                Text(dayNames(item.days_of_week))
                                    .font(.subheadline.weight(.medium))
                            }
                            if !item.time_label.isEmpty {
                                Text(item.time_label)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if !item.details.isEmpty {
                        Divider()
                        Text(item.details)
                            .font(.body)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .navigationTitle(item.type_labels.contains(where: { $0.localizedCaseInsensitiveContains("event") }) ? "Bar Event" : "Bar Deal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func dayNames(_ days: [Int]) -> String {
        days.sorted().compactMap { d in
            (0 ..< Self.fullDayNames.count).contains(d) ? Self.fullDayNames[d] : nil
        }.joined(separator: ", ")
    }
}
