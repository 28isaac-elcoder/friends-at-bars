import SwiftUI
import UIKit

/// Cold-start splash: black screen, centered logo, pop-and-vanish exit once bootstrap finishes.
struct StartupSplashView: View {
    let isBootstrapComplete: Bool
    let onFinished: () -> Void

    private enum Phase {
        case waiting
        case popping
        case vanishing
        case done
    }

    /// Minimum time the logo stays visible so the exit animation always reads.
    private let minimumVisibleSeconds: TimeInterval = 0.85
    private let popScale: CGFloat = 1.14
    private let logoSize: CGFloat = 120

    @State private var phase: Phase = .waiting
    @State private var logoScale: CGFloat = 1
    @State private var logoOpacity: Double = 1
    @State private var backdropOpacity: Double = 1
    @State private var minimumElapsed = false

    var body: some View {
        ZStack {
            Color.black
                .opacity(backdropOpacity)
                .ignoresSafeArea()

            if phase != .done {
                logoImage
                    .frame(width: logoSize, height: logoSize)
                    .clipShape(RoundedRectangle(cornerRadius: logoSize * 0.22, style: .continuous))
                    .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
            }
        }
        .task { await runMinimumTimer() }
        .onChange(of: isBootstrapComplete) { _, complete in
            if complete { tryBeginExit() }
        }
        .onAppear {
            if isBootstrapComplete { tryBeginExit() }
        }
    }

    @ViewBuilder
    private var logoImage: some View {
        if let uiImage = AppIconImage.current {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "tag.fill")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.accentColor)
        }
    }

    private func runMinimumTimer() async {
        try? await Task.sleep(nanoseconds: UInt64(minimumVisibleSeconds * 1_000_000_000))
        minimumElapsed = true
        tryBeginExit()
    }

    private func tryBeginExit() {
        guard minimumElapsed, isBootstrapComplete, phase == .waiting else { return }
        playExitAnimation()
    }

    private func playExitAnimation() {
        phase = .popping
        withAnimation(.spring(response: 0.28, dampingFraction: 0.62)) {
            logoScale = popScale
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            phase = .vanishing
            withAnimation(.easeIn(duration: 0.22)) {
                logoScale = 0.05
                logoOpacity = 0
                backdropOpacity = 0
            }
            try? await Task.sleep(nanoseconds: 240_000_000)
            phase = .done
            onFinished()
        }
    }
}

enum AppIconImage {
    /// Best-effort load of the marketing app icon for splash/branding.
    static var current: UIImage? {
        if let image = UIImage(named: "LaunchLogo") {
            return image
        }
        guard
            let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
            let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
            let files = primary["CFBundleIconFiles"] as? [String]
        else {
            return nil
        }
        for name in files.reversed() {
            if let image = UIImage(named: name) {
                return image
            }
        }
        return nil
    }
}
