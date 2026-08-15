import SwiftUI

/// Shared area filter chip — outline + colored text until selected, then filled.
struct AreaFilterChip: View {
    let title: String
    let accent: Color
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .foregroundStyle(selected ? Color.white : accent)
                .background(
                    Capsule()
                        .fill(selected ? accent : Color.clear)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(accent, lineWidth: selected ? 0 : 1.5)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
