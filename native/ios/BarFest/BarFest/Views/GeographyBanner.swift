import SwiftUI

struct GeographyBanner: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        Menu {
            Button {
                KeyboardObserver.dismiss()
                appModel.setManualGeography(nil)
            } label: {
                HStack {
                    Text("Automatic")
                    if appModel.manualGeographyId == nil {
                        Image(systemName: "checkmark")
                    }
                }
            }
            ForEach(appModel.geographies) { geo in
                Button {
                    KeyboardObserver.dismiss()
                    appModel.setManualGeography(geo.id)
                } label: {
                    HStack {
                        Text(geo.name)
                        if appModel.manualGeographyId == geo.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text("Bar Fest - \(appModel.resolvedGeography?.name ?? "Columbus")")
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .accessibilityLabel("Geography")
    }
}
