import SwiftUI

/// Shared area filter chip with vibrant campus colors.
struct AreaFilterChip: View {
    let area: CampusArea
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(area.shortLabel)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(area.accentColor.opacity(selected ? 1.0 : 0.72))
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(selected ? 0.9 : 0), lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
