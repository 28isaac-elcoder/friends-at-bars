import SwiftUI

/// Ride The Bus — presented via fullScreenCover from Games (no nav swipe-back).
struct RideTheBusView: View {
    @StateObject private var engine = RideTheBusEngine()
    @Environment(\.dismiss) private var dismiss

    @State private var activeFlipDegrees: Double = 0
    @State private var activeScale: CGFloat = 1
    @State private var activeOffset: CGSize = .zero
    @State private var activeOpacity: Double = 1
    @State private var showActiveFace = false
    @State private var glowColor: Color = .clear
    @State private var glowPulse = false
    @State private var slotsShake: CGFloat = 0
    @State private var slotsFallOffset: CGFloat = 0
    @State private var slotsOpacity: Double = 1
    @State private var dealFromDeck = false
    @State private var isBusy = false
    @State private var failMessageOpacity: Double = 1

    private let cardW: CGFloat = 110
    private let cardH: CGFloat = 154
    private let slotW: CGFloat = 72
    private let slotH: CGFloat = 100
    private let pileW: CGFloat = 70
    private let pileH: CGFloat = 98

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch engine.screen {
            case .lobby:
                lobbyScreen
            case .playing, .won:
                gameScreen
            }
        }
        .interactiveDismissDisabled(true)
    }

    // MARK: - Lobby

    private var lobbyScreen: some View {
        VStack(spacing: 0) {
            HStack {
                backButton
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)

            Spacer()
            Text("Ride The Bus")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
                .padding(.bottom, 28)

            RTBCardBackView(label: "Deck", showCount: nil)
                .frame(width: cardW + 20, height: cardH + 28)
                .shadow(color: .white.opacity(0.08), radius: 8, y: 4)

            Spacer()

            Button {
                withAnimation(.easeOut(duration: 0.25)) {
                    engine.startGame()
                }
                Task { await playDealIn() }
            } label: {
                Text("Start Game")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.green)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 28)
            .padding(.bottom, 36)
        }
    }

    // MARK: - Game / Win

    private var gameScreen: some View {
        VStack(spacing: 0) {
            topBar(showCongrats: engine.screen == .won)

            failOrStatusBanner
                .padding(.top, 6)

            Spacer(minLength: 8)

            activeRow
                .padding(.horizontal, 12)

            Spacer(minLength: 16)

            if engine.phase != .failInterstitial {
                slotsRow
                    .padding(.horizontal, 24)
            } else {
                Color.clear.frame(height: slotH)
            }

            Spacer(minLength: 20)

            bottomPiles
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
        }
    }

    @ViewBuilder
    private var failOrStatusBanner: some View {
        if engine.screen == .playing, let message = engine.message {
            VStack(spacing: 4) {
                Text(message)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(bannerColor)
                if let sub = engine.messageSubtitle {
                    Text(sub)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(bannerColor.opacity(0.95))
                        .multilineTextAlignment(.center)
                }
            }
            .opacity(failMessageOpacity)
            .padding(.horizontal, 20)
            .animation(.easeInOut(duration: 0.25), value: engine.messageSubtitle)
        } else {
            Color.clear.frame(height: 8)
        }
    }

    private var bannerColor: Color {
        if engine.lastResultCorrect == true { return .green }
        if engine.message?.contains("Engine") == true || engine.lastResultCorrect == false {
            return Color(red: 1.0, green: 0.45, blue: 0.42)
        }
        return .white.opacity(0.85)
    }

    private func topBar(showCongrats: Bool) -> some View {
        VStack(spacing: 6) {
            ZStack {
                HStack {
                    backButton
                    Spacer()
                }
                Text("Ride The Bus")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .shadow(color: .white.opacity(0.25), radius: 6)
            }
            .padding(.horizontal, 8)

            if showCongrats {
                Text("Congrats! You’ve Conquered The Bus!")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.green)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.top, 4)
    }

    private var backButton: some View {
        Button {
            engine.returnToLobby()
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Active + options

    private var activeRow: some View {
        HStack(alignment: .center, spacing: 10) {
            if engine.screen == .won {
                Spacer(minLength: 0)
                winActivePlaceholder
                    .frame(width: cardW, height: cardH)
                Spacer(minLength: 0)
            } else if engine.phase == .failInterstitial {
                leftOptions
                    .frame(maxWidth: .infinity)
                Color.clear.frame(width: cardW, height: cardH)
                rightOptions
                    .frame(maxWidth: .infinity)
            } else {
                leftOptions
                    .frame(maxWidth: .infinity)

                activeCard
                    .frame(width: cardW, height: cardH)
                    .scaleEffect(activeScale)
                    .rotation3DEffect(
                        .degrees(activeFlipDegrees),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.65
                    )
                    .shadow(color: glowColor.opacity(glowPulse ? 0.95 : 0.35), radius: glowPulse ? 28 : 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(glowColor.opacity(glowPulse ? 0.9 : 0.35), lineWidth: glowPulse ? 3 : 1.5)
                    )
                    .offset(activeOffset)
                    .opacity(activeOpacity)
                    .offset(x: slotsShake)

                rightOptions
                    .frame(maxWidth: .infinity)
            }
        }
        .disabled(isBusy || (engine.phase != .awaitingGuess && engine.phase != .failInterstitial) || engine.screen == .won)
    }

    private var winActivePlaceholder: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(Color.green.opacity(0.45), lineWidth: 2)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.green.opacity(0.08))
            )
            .overlay(
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.green)
                    .shadow(color: .green.opacity(0.6), radius: 12)
            )
    }

    @ViewBuilder
    private var leftOptions: some View {
        // During fail interstitial, always show Red/Black (round 0).
        let displayRound = engine.phase == .failInterstitial ? 0 : engine.round
        switch displayRound {
        case 0:
            guessButton(
                title: "Red",
                subtitle: "♥ ♦",
                tint: .red,
                guess: .color(.red),
                enabled: canGuess
            ) {
                Task { await handleGuess(.color(.red)) }
            }
        case 1:
            guessButton(
                title: "Higher",
                subtitle: "↑",
                tint: Color(white: 0.22),
                guess: .compare(.higher),
                enabled: canGuess
            ) {
                Task { await handleGuess(.compare(.higher)) }
            }
        case 2:
            guessButton(
                title: "Inside",
                subtitle: "→ ←",
                tint: Color(white: 0.22),
                guess: .range(.inside),
                enabled: canGuess
            ) {
                Task { await handleGuess(.range(.inside)) }
            }
        case 3:
            VStack(spacing: 10) {
                suitButton(.hearts, enabled: canGuess)
                suitButton(.diamonds, enabled: canGuess)
            }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var rightOptions: some View {
        let displayRound = engine.phase == .failInterstitial ? 0 : engine.round
        switch displayRound {
        case 0:
            guessButton(
                title: "Black",
                subtitle: "♠ ♣",
                tint: Color(white: 0.18),
                guess: .color(.black),
                enabled: canGuess
            ) {
                Task { await handleGuess(.color(.black)) }
            }
        case 1:
            guessButton(
                title: "Lower",
                subtitle: "↓",
                tint: Color(white: 0.22),
                guess: .compare(.lower),
                enabled: canGuess
            ) {
                Task { await handleGuess(.compare(.lower)) }
            }
        case 2:
            guessButton(
                title: "Outside",
                subtitle: "← →",
                tint: Color(white: 0.22),
                guess: .range(.outside),
                enabled: canGuess
            ) {
                Task { await handleGuess(.range(.outside)) }
            }
        case 3:
            VStack(spacing: 10) {
                suitButton(.clubs, enabled: canGuess)
                suitButton(.spades, enabled: canGuess)
            }
        default:
            EmptyView()
        }
    }

    private var canGuess: Bool {
        !isBusy && engine.phase == .awaitingGuess && engine.screen == .playing && engine.current != nil
    }

    private var activeCard: some View {
        ZStack {
            if showActiveFace, let card = engine.current {
                RTBPlayingCardView(card: card)
            } else if engine.current != nil || dealFromDeck {
                RTBCardBackView(label: "Active Card", showCount: nil)
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )
            }
        }
    }

    // MARK: - Slots

    private var slotsRow: some View {
        HStack(spacing: 14) {
            ForEach(0..<3, id: \.self) { i in
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(red: 0.12, green: 0.18, blue: 0.35))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                        )
                    if let card = engine.slots[i] {
                        RTBPlayingCardView(card: card)
                            .padding(4)
                    } else {
                        Text("\(i + 1)")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }
                .frame(width: slotW, height: slotH)
            }
        }
        .offset(x: slotsShake)
        .offset(y: slotsFallOffset)
        .opacity(slotsOpacity)
    }

    // MARK: - Bottom piles

    private var bottomPiles: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(spacing: 8) {
                RTBCardBackView(label: nil, showCount: engine.deck.count)
                    .frame(width: pileW, height: pileH)
                    .shadow(color: .blue.opacity(0.35), radius: 8, y: 2)
                Text("Deck")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.55))
            }

            if engine.screen == .won {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        engine.newGameFromWin()
                    }
                    Task { await playDealIn() }
                } label: {
                    Text("New Game")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                Spacer(minLength: 0)
            }

            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                        )
                    // Face-up most recent discarded / incorrectly guessed card (no count).
                    if let top = engine.discard.last {
                        RTBPlayingCardView(card: top)
                            .padding(4)
                    } else {
                        Image(systemName: "trash")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }
                .frame(width: pileW, height: pileH)
                Text("Trash")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    // MARK: - Buttons (selection light-up / dim)

    private func optionOpacity(for guess: RTBGuess) -> Double {
        guard let selected = engine.selectedGuess else { return 1 }
        return selected == guess ? 1 : 0.35
    }

    private func optionScale(for guess: RTBGuess) -> CGFloat {
        guard let selected = engine.selectedGuess else { return 1 }
        return selected == guess ? 1.06 : 0.96
    }

    private func guessButton(
        title: String,
        subtitle: String,
        tint: Color,
        guess: RTBGuess,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let lit = engine.selectedGuess == guess
        return Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                Text(subtitle)
                    .font(.caption.weight(.semibold))
                    .opacity(0.9)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(tint)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(lit ? 0.85 : 0.15), lineWidth: lit ? 2.5 : 1)
            )
            .shadow(color: lit ? tint.opacity(0.7) : .clear, radius: lit ? 14 : 0)
            .opacity(enabled || engine.selectedGuess != nil ? optionOpacity(for: guess) : 0.45)
            .scaleEffect(optionScale(for: guess))
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: engine.selectedGuess)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func suitButton(_ suit: RTBSuit, enabled: Bool) -> some View {
        let tint: Color = suit.isRed ? .red : Color(white: 0.18)
        let guess = RTBGuess.suit(suit)
        let lit = engine.selectedGuess == guess
        return Button {
            Task { await handleGuess(guess) }
        } label: {
            VStack(spacing: 2) {
                Text(suit.symbol)
                    .font(.title2.weight(.bold))
                Text(suit.label)
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(tint)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(lit ? 0.85 : 0.15), lineWidth: lit ? 2.5 : 1)
            )
            .shadow(color: lit ? tint.opacity(0.7) : .clear, radius: lit ? 14 : 0)
            .opacity(enabled || engine.selectedGuess != nil ? optionOpacity(for: guess) : 0.45)
            .scaleEffect(optionScale(for: guess))
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: engine.selectedGuess)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    // MARK: - Flow / animation

    private func handleGuess(_ guess: RTBGuess) async {
        guard canGuess else { return }
        isBusy = true
        failMessageOpacity = 1
        engine.submitGuess(guess)

        await animateFlipReveal()
        try? await Task.sleep(nanoseconds: 350_000_000)
        engine.advanceAfterReveal()

        if engine.lastResultCorrect == true {
            await animateSuccessGlowAndPop()
            try? await Task.sleep(nanoseconds: 200_000_000)

            if engine.round == 3 {
                engine.resolveSuccess()
                withAnimation(.easeInOut(duration: 0.3)) {
                    resetActiveTransforms()
                }
                isBusy = false
                return
            }

            await animateSlideToSlot(slotIndex: engine.round)
            engine.resolveSuccess()
            resetActiveTransforms()
            try? await Task.sleep(nanoseconds: 100_000_000)
            await playDealIn()
        } else {
            // Picture 1: short “Engine Overheated!” while still on this round.
            await animateFailGlowAndShake()
            await animateFailFall()
            engine.enterFailInterstitial()
            resetActiveTransforms()
            // Picture 2: longer copy + Red/Black, hold ~2s to read.
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation(.easeOut(duration: 0.45)) {
                failMessageOpacity = 0
            }
            try? await Task.sleep(nanoseconds: 450_000_000)
            engine.finishFailInterstitialAndDeal()
            failMessageOpacity = 1
            await playDealIn()
        }
        isBusy = false
    }

    private func playDealIn() async {
        guard engine.current != nil else { return }
        isBusy = true
        showActiveFace = false
        dealFromDeck = true
        glowColor = .clear
        glowPulse = false
        activeOpacity = 0
        activeOffset = CGSize(width: -120, height: 180)
        activeScale = 0.65
        activeFlipDegrees = 0
        slotsFallOffset = 0
        slotsOpacity = 1

        withAnimation(.spring(response: 0.48, dampingFraction: 0.78)) {
            activeOpacity = 1
            activeOffset = .zero
            activeScale = 1
        }
        try? await Task.sleep(nanoseconds: 480_000_000)
        dealFromDeck = false
        isBusy = false
    }

    private func animateFlipReveal() async {
        withAnimation(.easeIn(duration: 0.16)) {
            activeFlipDegrees = 90
        }
        try? await Task.sleep(nanoseconds: 160_000_000)
        showActiveFace = true
        activeFlipDegrees = -90
        withAnimation(.easeOut(duration: 0.2)) {
            activeFlipDegrees = 0
        }
        try? await Task.sleep(nanoseconds: 200_000_000)
    }

    private func animateSuccessGlowAndPop() async {
        glowColor = .yellow
        withAnimation(.spring(response: 0.28, dampingFraction: 0.5)) {
            activeScale = 1.14
        }
        // Periodic yellow glow pulses (casino-style).
        for _ in 0..<3 {
            withAnimation(.easeInOut(duration: 0.18)) { glowPulse = true }
            try? await Task.sleep(nanoseconds: 180_000_000)
            withAnimation(.easeInOut(duration: 0.18)) { glowPulse = false }
            try? await Task.sleep(nanoseconds: 120_000_000)
        }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            activeScale = 1
        }
    }

    private func animateSlideToSlot(slotIndex: Int) async {
        let xOffsets: [CGFloat] = [-86, 0, 86]
        let x = xOffsets[min(max(slotIndex, 0), 2)]
        withAnimation(.easeInOut(duration: 0.42)) {
            activeOffset = CGSize(width: x, height: 150)
            activeScale = 0.58
            activeOpacity = 0.25
            glowPulse = false
            glowColor = .yellow.opacity(0.4)
        }
        try? await Task.sleep(nanoseconds: 420_000_000)
        glowColor = .clear
    }

    private func animateFailGlowAndShake() async {
        glowColor = .red
        for _ in 0..<3 {
            withAnimation(.easeInOut(duration: 0.16)) { glowPulse = true }
            try? await Task.sleep(nanoseconds: 160_000_000)
            withAnimation(.easeInOut(duration: 0.16)) { glowPulse = false }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        withAnimation(.easeInOut(duration: 0.05).repeatCount(8, autoreverses: true)) {
            slotsShake = 12
            activeOffset = CGSize(width: 8, height: 0)
        }
        try? await Task.sleep(nanoseconds: 400_000_000)
        slotsShake = 0
        activeOffset = .zero
    }

    private func animateFailFall() async {
        withAnimation(.easeIn(duration: 0.5)) {
            activeOffset = CGSize(width: 50, height: 560)
            activeOpacity = 0
            activeScale = 0.8
            slotsFallOffset = 520
            slotsOpacity = 0
            glowColor = .clear
            glowPulse = false
        }
        try? await Task.sleep(nanoseconds: 500_000_000)
    }

    private func resetActiveTransforms() {
        activeFlipDegrees = 0
        activeScale = 1
        activeOffset = .zero
        activeOpacity = 1
        showActiveFace = false
        glowColor = .clear
        glowPulse = false
        slotsShake = 0
        slotsFallOffset = 0
        slotsOpacity = 1
    }
}

// MARK: - Card views

private struct RTBPlayingCardView: View {
    let card: RTBCard

    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color(white: 0.9))
            .overlay(
                VStack(spacing: 2) {
                    Text(card.rank.rawValue)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text(card.suit.symbol)
                        .font(.system(size: 26, weight: .semibold))
                }
                .foregroundStyle(card.suit.isRed ? Color.red : Color.black)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
    }
}

private struct RTBCardBackView: View {
    let label: String?
    let showCount: Int?

    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.12, green: 0.22, blue: 0.48),
                        Color(red: 0.08, green: 0.14, blue: 0.32),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.25), lineWidth: 1.5)
            )
            .overlay(
                ZStack {
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white.opacity(0.18))
                        .offset(y: -10)
                    if let showCount {
                        Text("\(showCount)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.4), radius: 2)
                    } else if let label {
                        Text(label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 6)
                    }
                }
            )
    }
}
