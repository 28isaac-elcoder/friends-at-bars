import SwiftUI

/// Shared privacy footnote under Allow Location CTAs.
enum LocationPrivacyCopy {
    static let underButton =
        "Only used to count you in — never sold, never shown to anyone."
}

/// Amber strip matching web Activities “Click Here to Enable Location…”.
struct LocationAllowStrip: View {
    @ObservedObject private var auth = LocationAuthorizationStore.shared
    var label: String =
        "Tap here to enable Location Always and see how busy each bar is right now!"
    var busyLabel: String = "Opening…"
    @State private var busy = false

    var body: some View {
        if !auth.isAuthorized {
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    busy = true
                    auth.requestAllowLocation()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        busy = false
                    }
                } label: {
                    Text(busy ? busyLabel : label)
                        .font(.caption2.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .padding(.horizontal, 8)
                        .background(Color(red: 0.47, green: 0.27, blue: 0.08))
                        .foregroundStyle(Color(red: 1, green: 0.96, blue: 0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(busy)

                Text(LocationPrivacyCopy.underButton)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                if let msg = auth.lastPromptMessage {
                    Text(msg)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// Full-screen style prompt for Map.
struct LocationAllowOverlay: View {
    @ObservedObject private var auth = LocationAuthorizationStore.shared
    @State private var busy = false

    var body: some View {
        if !auth.isAuthorized {
            ZStack {
                Color.black.opacity(0.72).ignoresSafeArea()
                VStack(spacing: 16) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 40))

                    Text("See where the night is happening.")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)

                    Text(
                        "Location Always lets Bar Fest update the map in real time, so you always know which bars are lighting up."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                    Text("Your location stays private — always.")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button {
                        busy = true
                        auth.requestAllowLocation()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            busy = false
                        }
                    } label: {
                        Text(
                            busy
                                ? "Opening…"
                                : (auth.needsAlwaysUpgrade ? "Upgrade to Always" : "Light Up the Map")
                        )
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .padding(.horizontal, 24)
                    .disabled(busy)

                    Text(LocationPrivacyCopy.underButton)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    if auth.needsAlwaysUpgrade {
                        Text("You chose While Using — switch to Always in Settings for live counts.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    if let msg = auth.lastPromptMessage {
                        Text(msg)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding()
            }
        }
    }
}

/// Horizontal chip row that cannot scroll vertically (fixes Deals filter rubber-band).
struct HorizontalChipScroll<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                content()
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(height: 34)
        .clipped()
    }
}

/// Inline Activity gate — replaces bar list when location is off.
struct ActivitiesLocationInlineGate: View {
    @ObservedObject private var auth = LocationAuthorizationStore.shared
    @State private var busy = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "map.fill")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.9))
                .symbolRenderingMode(.hierarchical)

            Text("Who Wants to Guess Which Bars are Popular")
                .font(.title3.bold())
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            Text(
                "Turn on Location Always to see real headcounts at bars near you — and add yourself to the count."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)

            Text("Your location is never shared or shown to other users.")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            if auth.needsAlwaysUpgrade {
                Text("Currently set to While Using — change it to Always to unlock live attendance.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            Button {
                busy = true
                auth.requestAllowLocation()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    busy = false
                }
            } label: {
                Text(
                    busy
                        ? "Opening…"
                        : (auth.needsAlwaysUpgrade ? "Upgrade to Always" : "Show Me What's Busy")
                )
                .font(.headline)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(busy)
            .padding(.horizontal, 24)

            Text(LocationPrivacyCopy.underButton)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            if let msg = auth.lastPromptMessage {
                Text(msg)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }
}
