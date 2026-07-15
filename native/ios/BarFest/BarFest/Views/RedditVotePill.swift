import SwiftUI

/// Horizontal Reddit-style vote control: ▲ score | ▼ inside a pill.
struct RedditVotePill: View {
    let score: Int
    let myVote: Int?
    let disabled: Bool
    let onUp: () -> Void
    let onDown: () -> Void

    private var upTint: Color {
        if myVote == 1 { return Color.orange }
        return .secondary
    }

    private var downTint: Color {
        if myVote == -1 { return Color.blue }
        return .secondary
    }

    private var scoreTint: Color {
        if myVote == 1 { return .orange }
        if myVote == -1 { return .blue }
        if score > 0 { return Color(red: 0.2, green: 0.55, blue: 0.3) }
        if score < 0 { return Color(red: 0.75, green: 0.2, blue: 0.2) }
        return .primary
    }

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onUp) {
                Image(systemName: myVote == 1 ? "arrow.up" : "arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(upTint)
                    .frame(width: 32, height: 28)
            }
            .buttonStyle(.plain)
            .disabled(disabled)

            Text("\(score)")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(scoreTint)
                .frame(minWidth: 24)

            Divider()
                .frame(height: 18)
                .overlay(Color.white.opacity(0.2))

            Button(action: onDown) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(downTint)
                    .frame(width: 32, height: 28)
            }
            .buttonStyle(.plain)
            .disabled(disabled)
        }
        .padding(.horizontal, 4)
        .background(Color.white.opacity(0.08))
        .overlay(
            Capsule()
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        )
        .clipShape(Capsule())
    }
}
