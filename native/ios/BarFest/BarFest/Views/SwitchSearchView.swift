import SwiftUI

/// Casual Switch Search — Easy/Hard word-search (web parity, no ranked).
/// Presented via fullScreenCover from Games (no nav swipe-back).
struct SwitchSearchView: View {
    @StateObject private var engine = SwitchSearchEngine()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            switch engine.screen {
            case .home:
                homeScreen
            case .playing:
                gameScreen
            case .ended:
                endScreen
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(screenBackground.ignoresSafeArea())
        // Presented as fullScreenCover — no NavigationStack pop / edge swipe-back.
        .interactiveDismissDisabled(true)
        .onAppear { engine.appear() }
    }

    private var screenBackground: Color { Color.black }

    // MARK: - Home

    private var homeScreen: some View {
        VStack(spacing: 28) {
            HStack {
                Button("Games") { dismiss() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(.horizontal)

            Spacer()
            Text("Switch Search")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
            Text("Find the hidden words before time runs out. Clear all words in a word search to swap to a new set and gain extra time.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Picker("Difficulty", selection: $engine.difficulty) {
                ForEach(SwitchSearchDifficulty.allCases) { d in
                    Text(d.label).tag(d)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 40)

            Text(engine.difficulty == .easy
                  ? "7×7 · 42s game · 12s per word-search · full word hints"
                  : "8×8 · 56s game · 16s per word-search · letter hints")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                engine.start()
            } label: {
                Text("Start")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
    }

    // MARK: - Game

    private var gameScreen: some View {
        VStack(spacing: 10) {
            Text("Found \(engine.totalFound)")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(.top, 4)

            progressBar(
                label: "Game Timer",
                value: engine.sessionLeft,
                total: Double(engine.difficulty.sessionSeconds),
                tint: engine.isFrozen ? .cyan : .accentColor,
                frozen: engine.isFrozen
            )
            .padding(.horizontal)

            letterGrid
                .padding(.horizontal, 8)

            progressBar(
                label: "Word-Search Timer",
                value: engine.puzzleLeft,
                total: Double(engine.difficulty.puzzleSeconds),
                tint: .orange,
                frozen: false
            )
            .padding(.horizontal)

            Text("Find These Words:")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.55))
                .frame(maxWidth: .infinity)

            HStack(alignment: .center, spacing: 8) {
                Button("Exit") { engine.exitToHome() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 52, alignment: .leading)

                Spacer(minLength: 4)

                HStack(spacing: 8) {
                    ForEach(Array(engine.hints.enumerated()), id: \.offset) { idx, hint in
                        let word = idx < engine.currentWords.count
                            ? engine.currentWords[idx].lowercased()
                            : ""
                        let isFound = engine.foundWords.contains(word)
                        Text(hint)
                            .font(.caption.weight(.semibold).monospaced())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(isFound ? Color.white : Color.white.opacity(0.12))
                            .foregroundStyle(isFound ? Color.black : Color.white)
                            .clipShape(Capsule())
                            .strikethrough(isFound, color: .black.opacity(0.5))
                    }
                }

                Spacer(minLength: 4)

                Button("Skip") { engine.skipPuzzle() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 52, alignment: .trailing)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .padding(.top, 4)
    }

    private var letterGrid: some View {
        let size = engine.difficulty.gridSize
        return GeometryReader { geo in
            let gap: CGFloat = 3
            let side = min(geo.size.width, geo.size.height)
            let cellSize = (side - gap * CGFloat(size - 1)) / CGFloat(size)
            let gridSide = cellSize * CGFloat(size) + gap * CGFloat(size - 1)

            ZStack {
                VStack(spacing: gap) {
                    ForEach(engine.grid.indices, id: \.self) { r in
                        HStack(spacing: gap) {
                            ForEach(engine.grid[r]) { cellModel in
                                SwitchSearchLetterCell(
                                    cell: cellModel,
                                    selected: engine.isSelected(row: cellModel.row, col: cellModel.col),
                                    size: cellSize
                                )
                            }
                        }
                    }
                }
                .allowsHitTesting(false)

                SwitchSearchTouchPad(
                    gridSize: size,
                    cell: cellSize,
                    gap: gap,
                    onMove: { r, c in engine.pointerMoved(toRow: r, col: c) },
                    onEnd: { r, c in engine.pointerEnded(atRow: r, col: c) }
                )
                .frame(width: gridSide, height: gridSide)
            }
            .frame(width: gridSide, height: gridSide)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func progressBar(
        label: String,
        value: Double,
        total: Double,
        tint: Color,
        frozen: Bool
    ) -> some View {
        let displaySeconds = Int(ceil(max(0, value)))
        let fraction = max(0, min(1, value / max(total, 0.0001)))
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(frozen ? Color.cyan : Color.white.opacity(0.55))
                Spacer()
                Text("\(displaySeconds)s")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(frozen ? Color.cyan : Color.white.opacity(0.55))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule()
                        .fill(tint)
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 6)
            .overlay(
                Capsule()
                    .strokeBorder(frozen ? Color.cyan.opacity(0.9) : Color.clear, lineWidth: 1.5)
                    .padding(-3)
            )
            .shadow(color: frozen ? Color.cyan.opacity(0.55) : .clear, radius: frozen ? 6 : 0)
        }
    }

    // MARK: - End

    private var endScreen: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Time is up!")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
            Text("You found \(engine.totalFound) word\(engine.totalFound == 1 ? "" : "s").")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.7))
            Button {
                engine.restart()
            } label: {
                Text("Play again")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 40)
            Button("Exit") { engine.exitToHome() }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Spacer()
        }
    }
}

/// Extracted so Swift can type-check the grid without timing out.
private struct SwitchSearchLetterCell: View {
    let cell: SwitchSearchCell
    let selected: Bool
    let size: CGFloat

    private var inverted: Bool { selected || cell.found }

    private var fill: Color {
        if cell.unfoundFlash { return .gray }
        if inverted { return .white }
        return Color.white.opacity(0.08)
    }

    private var border: Color {
        inverted ? .white : Color.white.opacity(0.25)
    }

    var body: some View {
        Text(cell.letter)
            .font(.system(size: max(12, size * 0.42), weight: .bold, design: .rounded))
            .foregroundStyle(inverted ? Color.black : Color.white)
            .frame(width: size, height: size)
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(border, lineWidth: 1)
            )
    }
}
