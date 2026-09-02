import SwiftUI

/// Centered geography selector — white text, compact, no chevron (all tabs).
struct GeographyPicker: View {
    @EnvironmentObject private var appModel: AppModel
    /// When true, tap dismisses keyboard instead of opening the menu (Deals search active).
    var suppressMenuWhileKeyboard = false
    var onSuppressTap: (() -> Void)?

    private var title: String {
        "Bar Fest - \(appModel.resolvedGeography?.name ?? "Columbus")"
    }

    var body: some View {
        Group {
            if suppressMenuWhileKeyboard {
                Button(action: dismissKeyboardInstead) {
                    label
                }
                .buttonStyle(.plain)
            } else {
                Menu {
                    ForEach(appModel.geographies) { geo in
                        Button {
                            KeyboardObserver.dismiss()
                            appModel.setManualGeography(geo.id, source: "picker")
                        } label: {
                            HStack {
                                Text(geo.name)
                                if appModel.resolvedGeography?.id == geo.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    label
                }
            }
        }
        .accessibilityLabel("Geography")
    }

    private var label: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
    }

    private func dismissKeyboardInstead() {
        onSuppressTap?()
        KeyboardObserver.dismiss()
    }
}

/// Centered geography row shown below the ribbon on Activity, Deals, and Chat.
struct GeographyBanner: View {
    var suppressMenuWhileKeyboard = false
    var onSuppressTap: (() -> Void)?

    var body: some View {
        GeographyPicker(
            suppressMenuWhileKeyboard: suppressMenuWhileKeyboard,
            onSuppressTap: onSuppressTap
        )
        .padding(.horizontal)
        .padding(.vertical, 6)
    }
}
