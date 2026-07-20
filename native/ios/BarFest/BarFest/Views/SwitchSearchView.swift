import SwiftUI
import UIKit

/// Casual Switch Search — Easy/Hard word-search (web parity, no ranked).
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
        // No system back chevron — Exit / Games handle leaving.
        .navigationBarBackButtonHidden(true)
        .toolbar(engine.screen == .home ? .visible : .hidden, for: .navigationBar)
        .background(
            InteractivePopGestureDisabler(disabled: engine.screen != .home)
                .frame(width: 0, height: 0)
        )
        .onAppear { engine.appear() }
    }

    private var screenBackground: Color { Color.black }

    // MARK: - Home

    private var homeScreen: some View {
        VStack(spacing: 28) {
            Spacer()
            Text("Switch Search")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
            Text("Find the hidden words before time runs out. Clear a puzzle to swap in a new one.")
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
                  ? "7×7 · 42s session · 12s per puzzle · full word hints"
                  : "8×8 · 56s session · 16s per puzzle · letter hints")
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
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Games") { dismiss() }
                    .foregroundStyle(.white)
            }
        }
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
                label: "Session",
                value: engine.sessionLeft,
                total: Double(engine.difficulty.sessionSeconds),
                tint: engine.isFrozen ? .cyan : .accentColor
            )
            .padding(.horizontal)

            if engine.isFrozen {
                Text("Bonus freeze — session timer paused")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.cyan)
            }

            if engine.selectionMode == .awaitingEnd {
                Text("Tap the last letter")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.65))
            }

            letterGrid
                .padding(.horizontal, 8)

            progressBar(
                label: "Puzzle",
                value: engine.puzzleLeft,
                total: Double(engine.difficulty.puzzleSeconds),
                tint: .orange
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
            let cell = (side - gap * CGFloat(size - 1)) / CGFloat(size)
            let gridSide = cell * CGFloat(size) + gap * CGFloat(size - 1)

            ZStack {
                VStack(spacing: gap) {
                    ForEach(engine.grid.indices, id: \.self) { r in
                        HStack(spacing: gap) {
                            ForEach(engine.grid[r]) { cellModel in
                                let selected = engine.isSelected(row: cellModel.row, col: cellModel.col)
                                let inverted = selected || cellModel.found
                                Text(cellModel.letter)
                                    .font(.system(size: max(12, cell * 0.42), weight: .bold, design: .rounded))
                                    .foregroundStyle(inverted ? Color.black : Color.white)
                                    .frame(width: cell, height: cell)
                                    .background(
                                        cellModel.unfoundFlash
                                            ? Color.gray
                                            : (inverted ? Color.white : Color.white.opacity(0.08))
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .strokeBorder(
                                                inverted ? Color.white : Color.white.opacity(0.25),
                                                lineWidth: 1
                                            )
                                    )
                            }
                        }
                    }
                }
                .allowsHitTesting(false)

                SwitchSearchTouchPad(
                    gridSize: size,
                    cell: cell,
                    gap: gap,
                    onMove: { r, c in engine.pointerMoved(toRow: r, col: c) },
                    onEnd: { r, c in engine.pointerEnded(atRow: r, col: c) }
                )
                .frame(width: gridSide, height: gridSide)

                if engine.isFrozen {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.cyan.opacity(0.5), lineWidth: 2)
                        .frame(width: gridSide, height: gridSide)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: gridSide, height: gridSide)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func progressBar(label: String, value: Double, total: Double, tint: Color) -> some View {
        let displaySeconds = Int(ceil(max(0, value)))
        let fraction = max(0, min(1, value / max(total, 0.0001)))
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                Text("\(displaySeconds)s")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.55))
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

// MARK: - Block NavigationStack swipe-back while playing

private struct InteractivePopGestureDisabler: UIViewControllerRepresentable {
    var disabled: Bool

    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ uiViewController: Controller, context: Context) {
        uiViewController.disabled = disabled
        uiViewController.apply()
    }

    final class Controller: UIViewController {
        var disabled = false

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            apply()
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        }

        func apply() {
            navigationController?.interactivePopGestureRecognizer?.isEnabled = !disabled
        }
    }
}
