import SwiftUI

/// Shared area filter chip — outline + colored text until selected, then filled.
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
                .foregroundStyle(selected ? Color.white : area.accentColor)
                .background(
                    Capsule()
                        .fill(selected ? area.accentColor : Color.clear)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(area.accentColor, lineWidth: selected ? 0 : 1.5)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
