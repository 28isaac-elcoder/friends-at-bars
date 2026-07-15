import SwiftUI

/// Amber strip matching web Activities “Click Here to Enable Location…”.
struct LocationAllowStrip: View {
    @ObservedObject private var auth = LocationAuthorizationStore.shared
    var label: String =
        "Tap here to enable Location and see how busy each bar is right now!"
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

                if let msg = auth.lastPromptMessage {
                    Text(msg)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// Full-screen style prompt for Map (web MapLocationPermissionPrompt parity).
struct LocationAllowOverlay: View {
    @ObservedObject private var auth = LocationAuthorizationStore.shared
    var title: String = "Allow location access"
    var description: String =
        "Enable location to browse attendance and deals at your favorite bars."
    @State private var busy = false

    var body: some View {
        if !auth.isAuthorized {
            ZStack {
                Color.black.opacity(0.72).ignoresSafeArea()
                VStack(spacing: 16) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 40))
                    Text(title)
                        .font(.title2.bold())
                    Text(description)
                        .font(.subheadline)
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
                        Text(busy ? "Opening…" : "Allow location access")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .padding(.horizontal, 24)
                    .disabled(busy)

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
