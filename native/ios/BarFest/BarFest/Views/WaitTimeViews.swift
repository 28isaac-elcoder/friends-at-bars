import SwiftUI

struct WaitTimeLabel: View {
    let summary: WaitTimeSummary

    var body: some View {
        Text(summary.displayText)
            .font(.caption2)
            .foregroundStyle(summary.mode == .none ? .tertiary : .secondary)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
    }
}

struct WaitTimeBucketPicker: View {
    let selectedMinutes: Int?
    let isSubmitting: Bool
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(WaitTimeBucket.allCases) { bucket in
                Button {
                    onSelect(bucket.rawValue)
                } label: {
                    Text(bucket.shortLabel)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(selectedMinutes == bucket.rawValue
                                      ? Color.accentColor
                                      : Color.white.opacity(0.1))
                        )
                        .foregroundStyle(selectedMinutes == bucket.rawValue ? .white : .primary)
                }
                .buttonStyle(.plain)
                .disabled(isSubmitting)
            }
        }
    }
}

/// Centered check-in card shown when the user is at a bar (Activities overlay).
struct WaitTimeCheckInPopup: View {
    let venueName: String
    let selectedMinutes: Int?
    let isSubmitting: Bool
    let errorMessage: String?
    let onSelect: (Int) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Check In")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                        .tracking(0.5)
                    Text(venueName)
                        .font(.title3.bold())
                    Text("Report your wait time or projected wait")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if selectedMinutes != nil {
                        Text("Tap another time to update your report")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer(minLength: 8)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(6)
                }
                .buttonStyle(.plain)
            }

            WaitTimeBucketPicker(
                selectedMinutes: selectedMinutes,
                isSubmitting: isSubmitting,
                onSelect: onSelect
            )

            if isSubmitting {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }

            if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.35), radius: 12, y: 4)
        )
        .padding(.horizontal, 20)
    }
}

/// Test Mode: pick any bar and submit a mock wait report.
struct MockWaitReportSheet: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var venueSearch = ""
    @State private var selectedVenue: CatalogVenue?
    @State private var selectedMinutes: Int?
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var searchQuery: String {
        venueSearch.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredVenues: [CatalogVenue] {
        guard !searchQuery.isEmpty else { return appModel.scopedVenues.prefix(20).map { $0 } }
        return appModel.scopedVenues
            .filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                TextField("Search bars", text: $venueSearch)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                if let venue = selectedVenue {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(venue.name)
                            .font(.headline)
                        Text("Select wait time for mock report")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        WaitTimeBucketPicker(
                            selectedMinutes: selectedMinutes,
                            isSubmitting: isSubmitting,
                            onSelect: { minutes in
                                selectedMinutes = minutes
                                Task { await submit(venue: venue, minutes: minutes) }
                            }
                        )
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredVenues) { venue in
                                Button {
                                    selectedVenue = venue
                                    selectedMinutes = appModel.myWaitMinutes(for: venue.name)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(venue.name)
                                                .foregroundStyle(.primary)
                                            Text(venue.area)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(.vertical, 10)
                                }
                                .buttonStyle(.plain)
                                Divider().opacity(0.35)
                            }
                        }
                    }
                }

                if isSubmitting {
                    ProgressView().frame(maxWidth: .infinity)
                }
                if let errorMessage {
                    Text(errorMessage).font(.caption).foregroundStyle(.red)
                }

                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("Mock Wait Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if selectedVenue != nil {
                        Button("Back") {
                            selectedVenue = nil
                            selectedMinutes = nil
                            errorMessage = nil
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func submit(venue: CatalogVenue, minutes: Int) async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            try await appModel.submitWaitReport(
                venueName: venue.name,
                waitMinutes: minutes,
                isMock: true
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
