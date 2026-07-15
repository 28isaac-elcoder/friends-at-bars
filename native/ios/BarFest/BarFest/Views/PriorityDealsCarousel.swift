import SwiftUI

/// Priority deals carousel (web Activities `BarDealsCarousel` parity) — dark theme.
struct PriorityDealsCarousel: View {
    let items: [CatalogListing]
    @State private var index = 0
    private let rotateSeconds: TimeInterval = 3

    var body: some View {
        Group {
            if items.isEmpty {
                EmptyView()
            } else {
                carouselBody
            }
        }
    }

    private var current: CatalogListing { items[index % items.count] }

    private var carouselBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(carouselLabel(for: current.type_labels))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color(red: 0.85, green: 0.72, blue: 0.45))
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
            if !current.time_label.isEmpty {
                Text(current.time_label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            ForEach(detailBullets(current), id: \.self) { line in
                HStack(alignment: .top, spacing: 6) {
                    Text("•")
                    Text(line)
                }
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.18, green: 0.16, blue: 0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color(red: 0.45, green: 0.38, blue: 0.22).opacity(0.6), lineWidth: 1)
                )
        )
        .onAppear { index = 0 }
        .onChange(of: items.map(\.id)) { _, _ in index = 0 }
        .task(id: items.count) {
            guard items.count > 1 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(rotateSeconds * 1_000_000_000))
                guard !Task.isCancelled, items.count > 1 else { break }
                withAnimation(.easeInOut(duration: 0.25)) {
                    index = (index + 1) % items.count
                }
            }
        }
        .onTapGesture {
            guard items.count > 1 else { return }
            withAnimation { index = (index + 1) % items.count }
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

    private func detailBullets(_ item: CatalogListing) -> [String] {
        let raw: String
        if item.title.isEmpty {
            raw = item.details
        } else if item.details.isEmpty {
            return []
        } else {
            raw = item.details
        }
        return raw
            .split(separator: ";")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
