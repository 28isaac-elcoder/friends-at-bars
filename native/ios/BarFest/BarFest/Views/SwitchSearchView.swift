import SwiftUI

/// Casual Switch Search — Easy/Hard word-search (web parity, no ranked).
/// Native dark styling with a subtle Easy/Hard tint difference.
struct SwitchSearchView: View {
    @StateObject private var engine = SwitchSearchEngine()

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
        .navigationBarBackButtonHidden(engine.screen != .home)
        .onAppear { engine.appear() }
    }

    /// Subtle Easy vs Hard: Hard gets a slightly cooler/darker chrome — not a full white↔black flip.
    private var screenBackground: Color {
        engine.difficulty == .easy
            ? Color(uiColor: .systemBackground)
            : Color(red: 0.07, green: 0.08, blue: 0.1)
    }

    private var cellFill: Color {
        engine.difficulty == .easy
            ? Color.white.opacity(0.12)
            : Color.white.opacity(0.07)
    }

    private var cellBorder: Color {
        engine.difficulty == .easy
            ? Color.white.opacity(0.22)
            : Color.cyan.opacity(0.22)
    }

    // MARK: - Home

    private var homeScreen: some View {
        VStack(spacing: 28) {
            Spacer()
            Text("Switch Search")
                .font(.largeTitle.bold())
            Text("Find the hidden words before time runs out. Clear a puzzle to swap in a new one.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
                .foregroundStyle(.secondary)
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
        VStack(spacing: 12) {
            HStack {
                Button("Exit") { engine.exitToHome() }
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("Found \(engine.totalFound)")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                Spacer()
                Button("Skip") { engine.skipPuzzle() }
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal)

            progressBar(
                label: "Session",
                value: Double(engine.sessionLeft),
                total: Double(engine.difficulty.sessionSeconds),
                tint: engine.isFrozen ? .cyan : .accentColor
            )
            .padding(.horizontal)

            progressBar(
                label: "Puzzle",
                value: Double(engine.puzzleLeft),
                total: Double(engine.difficulty.puzzleSeconds),
                tint: .orange
            )
            .padding(.horizontal)

            if engine.isFrozen {
                Text("Bonus freeze — session timer paused")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.cyan)
            }

            letterGrid
                .padding(.horizontal, 8)

            VStack(alignment: .leading, spacing: 6) {
                Text(engine.difficulty == .easy ? "Words" : "Hints")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 72), spacing: 8)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(Array(engine.hints.enumerated()), id: \.offset) { idx, hint in
                        let word = idx < engine.currentWords.count
                            ? engine.currentWords[idx].lowercased()
                            : ""
                        let isFound = engine.foundWords.contains(word)
                        Text(hint)
                            .font(.caption.weight(.semibold).monospaced())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(isFound ? Color.green.opacity(0.25) : Color.white.opacity(0.1))
                            .foregroundStyle(isFound ? Color.green : Color.primary)
                            .clipShape(Capsule())
                            .strikethrough(isFound)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)

            Button("Restart") { engine.restart() }
                .font(.subheadline)
                .padding(.bottom, 8)
        }
        .padding(.top, 8)
    }

    private var letterGrid: some View {
        let size = engine.difficulty.gridSize
        return GeometryReader { geo in
            let gap: CGFloat = 3
            let cell = (min(geo.size.width, geo.size.height) - gap * CGFloat(size - 1)) / CGFloat(size)
            let gridSide = cell * CGFloat(size) + gap * CGFloat(size - 1)

            ZStack(alignment: .topLeading) {
                VStack(spacing: gap) {
                    ForEach(engine.grid.indices, id: \.self) { r in
                        HStack(spacing: gap) {
                            ForEach(engine.grid[r]) { cellModel in
                                Text(cellModel.letter)
                                    .font(.system(size: max(12, cell * 0.42), weight: .bold, design: .rounded))
                                    .foregroundStyle(letterColor(cellModel))
                                    .frame(width: cell, height: cell)
                                    .background(cellBackground(cellModel))
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .strokeBorder(cellBorder, lineWidth: 1)
                                    )
                                    .allowsHitTesting(false)
                            }
                        }
                    }
                }
                .frame(width: gridSide, height: gridSide)
                .overlay {
                    if engine.isFrozen {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.cyan.opacity(0.5), lineWidth: 2)
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in
                            guard let (r, c) = cellAt(value.location, cell: cell, gap: gap, size: size) else { return }
                            engine.updateSelect(row: r, col: c)
                        }
                        .onEnded { value in
                            if let (r, c) = cellAt(value.location, cell: cell, gap: gap, size: size) {
                                engine.endSelect(row: r, col: c)
                            } else if let last = engine.selectedPath.last {
                                engine.endSelect(row: last.0, col: last.1)
                            }
                        }
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func cellAt(_ point: CGPoint, cell: CGFloat, gap: CGFloat, size: Int) -> (Int, Int)? {
        let stride = cell + gap
        guard stride > 0 else { return nil }
        let c = Int(point.x / stride)
        let r = Int(point.y / stride)
        guard r >= 0, c >= 0, r < size, c < size else { return nil }
        // Ignore taps that land in the gap strip between cells
        let localX = point.x - CGFloat(c) * stride
        let localY = point.y - CGFloat(r) * stride
        if localX > cell || localY > cell { return nil }
        return (r, c)
    }

    private func cellBackground(_ cell: SwitchSearchCell) -> Color {
        if cell.unfoundFlash { return Color.gray.opacity(0.55) }
        if cell.found { return Color.green.opacity(0.35) }
        if cell.highlighted { return Color.cyan.opacity(0.45) }
        return cellFill
    }

    private func letterColor(_ cell: SwitchSearchCell) -> Color {
        if cell.found { return .green }
        return .primary
    }

    private func progressBar(label: String, value: Double, total: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(max(0, value)))s")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1))
                    Capsule()
                        .fill(tint)
                        .frame(width: geo.size.width * max(0, min(1, value / max(total, 1))))
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
            Text("You found \(engine.totalFound) word\(engine.totalFound == 1 ? "" : "s").")
                .font(.title3)
                .foregroundStyle(.secondary)
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
            Spacer()
        }
    }
}
