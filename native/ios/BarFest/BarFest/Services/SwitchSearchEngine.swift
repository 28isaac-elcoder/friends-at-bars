import Foundation

enum SwitchSearchDifficulty: String, CaseIterable, Identifiable {
    case easy
    case hard
    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    var gridSize: Int { self == .easy ? 7 : 8 }
    var sessionSeconds: Int { self == .easy ? 42 : 56 }
    var puzzleSeconds: Int { self == .easy ? 12 : 16 }
    var bonusFreezeSeconds: Int { self == .easy ? 1 : 3 }
}

struct SwitchSearchCell: Identifiable, Hashable {
    let id: String
    let row: Int
    let col: Int
    var letter: String
    var highlighted: Bool = false
    var found: Bool = false
    var unfoundFlash: Bool = false
}

@MainActor
final class SwitchSearchEngine: ObservableObject {
    enum Screen { case home, playing, ended }

    @Published var screen: Screen = .home
    @Published var difficulty: SwitchSearchDifficulty = .easy
    @Published var grid: [[SwitchSearchCell]] = []
    @Published var currentWords: [String] = []
    @Published var foundWords: Set<String> = []
    @Published var totalFound = 0
    @Published var sessionLeft = 42
    @Published var puzzleLeft = 12
    @Published var hints: [String] = []
    @Published var isFrozen = false
    @Published var selectedPath: [(Int, Int)] = []
    /// True once CMS or bundled library has been resolved for this session.
    @Published var librarySource: String = "bundled"

    private var library = WordLibrary.loadBundled()
    private var usedWords: [String] = []
    private var wordCells: [String: [(Int, Int)]] = [:]
    private var sessionTimer: Timer?
    private var puzzleTimer: Timer?
    private var selectionStart: (Int, Int)?
    private var gameElapsed = 0

    func appear() {
        Task { await refreshLibraryFromCatalog() }
    }

    /// Prefer admin CMS `catalog_game_content`; fall back to bundled `wordLibrary.json`.
    func refreshLibraryFromCatalog() async {
        let cms = await CatalogStore.shared.switchSearchLibrary
        if let cms, !cms.isEmpty {
            library = cms
            librarySource = "cms"
            DiagnosticLog.shared.append(
                category: "system",
                message: "Switch Search words from CMS (\(cms.allWords.count) words)"
            )
        } else {
            library = WordLibrary.loadBundled()
            librarySource = "bundled"
            DiagnosticLog.shared.append(
                category: "system",
                message: "Switch Search words from bundled library (\(library.allWords.count) words)"
            )
        }
    }

    func start() {
        Task {
            await refreshLibraryFromCatalog()
            beginGame()
        }
    }

    private func beginGame() {
        stopTimers()
        usedWords = []
        totalFound = 0
        foundWords = []
        gameElapsed = 0
        sessionLeft = difficulty.sessionSeconds
        puzzleLeft = difficulty.puzzleSeconds
        isFrozen = false
        selectedPath = []
        selectionStart = nil
        screen = .playing
        generatePuzzle()
        startTimers()
    }

    func restart() {
        start()
    }

    func skipPuzzle() {
        guard screen == .playing else { return }
        generatePuzzle()
    }

    func exitToHome() {
        stopTimers()
        screen = .home
        grid = []
        selectedPath = []
        selectionStart = nil
    }

    // MARK: - Selection

    func beginSelect(row: Int, col: Int) {
        guard screen == .playing else { return }
        selectionStart = (row, col)
        selectedPath = [(row, col)]
        applyHighlight(path: selectedPath)
    }

    func updateSelect(row: Int, col: Int) {
        guard screen == .playing else { return }
        if selectionStart == nil {
            beginSelect(row: row, col: col)
            return
        }
        guard let start = selectionStart else { return }
        selectedPath = path(from: start, to: (row, col))
        applyHighlight(path: selectedPath)
    }

    func endSelect(row: Int, col: Int) {
        guard screen == .playing else { return }
        let start = selectionStart ?? (row, col)
        let path = path(from: start, to: (row, col))
        selectedPath = path
        checkSelection(path)
        selectionStart = nil
    }

    // MARK: - Timers

    private func startTimers() {
        stopTimers()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickSession() }
        }
        puzzleTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickPuzzle() }
        }
    }

    private func stopTimers() {
        sessionTimer?.invalidate()
        puzzleTimer?.invalidate()
        sessionTimer = nil
        puzzleTimer = nil
    }

    private func tickSession() {
        guard screen == .playing else { return }
        if !isFrozen {
            sessionLeft -= 1
            gameElapsed += 1
            if sessionLeft <= 0 {
                sessionLeft = 0
                stopTimers()
                screen = .ended
            }
        }
    }

    private func tickPuzzle() {
        guard screen == .playing else { return }
        guard puzzleLeft > 0 else { return }
        puzzleLeft -= 1
        if puzzleLeft <= 0 {
            puzzleLeft = 0
            flashUnfound()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self, self.screen == .playing else { return }
                self.generatePuzzle()
            }
        }
    }

    // MARK: - Puzzle

    private func generatePuzzle() {
        let words = selectWords()
        currentWords = words
        foundWords = []
        wordCells = [:]
        puzzleLeft = difficulty.puzzleSeconds
        selectedPath = []
        selectionStart = nil

        let size = difficulty.gridSize
        var raw: [[String?]] = Array(
            repeating: Array(repeating: nil, count: size),
            count: size
        )
        for word in words {
            let positions = placeWord(word, in: &raw)
            wordCells[word.lowercased()] = positions
        }
        for r in 0 ..< size {
            for c in 0 ..< size {
                if raw[r][c] == nil {
                    raw[r][c] = String(UnicodeScalar(UInt8(97 + Int.random(in: 0 ..< 26))))
                }
            }
        }
        grid = (0 ..< size).map { r in
            (0 ..< size).map { c in
                SwitchSearchCell(
                    id: "\(r)-\(c)",
                    row: r,
                    col: c,
                    letter: (raw[r][c] ?? "?").uppercased()
                )
            }
        }
        hints = makeHints(words: words)
    }

    private func selectWords() -> [String] {
        var picked: [String] = []
        if difficulty == .easy {
            picked.append(pick(from: library.fourLetter))
            let second = Bool.random() ? library.fiveLetter : library.sixLetter
            picked.append(pick(from: second))
        } else {
            picked.append(pick(from: library.fiveLetter))
            picked.append(pick(from: library.sixLetter))
            picked.append(pick(from: library.sevenLetter))
        }
        return picked
    }

    private func pick(from list: [String]) -> String {
        var attempts = 0
        while attempts < max(list.count * 2, 8) {
            let w = list.randomElement() ?? "bar"
            attempts += 1
            if !usedWords.contains(w) {
                usedWords.append(w)
                return w
            }
            if attempts > list.count {
                usedWords.removeAll { list.contains($0) }
            }
        }
        let w = list.randomElement() ?? "bar"
        usedWords.append(w)
        return w
    }

    private enum Direction { case horizontal, vertical, diagonal }

    private func placeWord(_ word: String, in grid: inout [[String?]]) -> [(Int, Int)] {
        let size = grid.count
        let letters = Array(word.lowercased())
        let dirs: [Direction] = [.horizontal, .vertical, .diagonal]
        for _ in 0 ..< 400 {
            let dir = dirs.randomElement()!
            let startR = Int.random(in: 0 ..< size)
            let startC = Int.random(in: 0 ..< size)
            if canPlace(letters, startR, startC, dir, grid) {
                var positions: [(Int, Int)] = []
                for i in 0 ..< letters.count {
                    let r = startR + ((dir == .vertical || dir == .diagonal) ? i : 0)
                    let c = startC + ((dir == .horizontal || dir == .diagonal) ? i : 0)
                    grid[r][c] = String(letters[i])
                    positions.append((r, c))
                }
                return positions
            }
        }
        // Fallback: place horizontally at 0,0 if possible
        var positions: [(Int, Int)] = []
        for i in 0 ..< min(letters.count, size) {
            grid[0][i] = String(letters[i])
            positions.append((0, i))
        }
        return positions
    }

    private func canPlace(
        _ letters: [Character],
        _ startR: Int,
        _ startC: Int,
        _ dir: Direction,
        _ grid: [[String?]]
    ) -> Bool {
        let size = grid.count
        for i in 0 ..< letters.count {
            let r = startR + ((dir == .vertical || dir == .diagonal) ? i : 0)
            let c = startC + ((dir == .horizontal || dir == .diagonal) ? i : 0)
            if r >= size || c >= size { return false }
            if let existing = grid[r][c], existing != String(letters[i]) { return false }
        }
        return true
    }

    private func makeHints(words: [String]) -> [String] {
        if difficulty == .easy {
            return words.map { $0.uppercased() }
        }
        return words.map { word in
            let chars = Array(word.uppercased())
            guard chars.count >= 2 else { return String(chars) }
            var reveal = Set<Int>()
            while reveal.count < 2 {
                reveal.insert(Int.random(in: 0 ..< chars.count))
            }
            return String(chars.enumerated().map { reveal.contains($0.offset) ? $0.element : "_" })
        }
    }

    private func checkSelection(_ path: [(Int, Int)]) {
        defer {
            clearHighlights()
            selectedPath = []
        }
        guard path.count >= 2 else { return }
        let formed = path.map { grid[$0.0][$0.1].letter }.joined().lowercased()
        guard currentWords.map({ $0.lowercased() }).contains(formed),
              !foundWords.contains(formed)
        else { return }

        foundWords.insert(formed)
        totalFound += 1
        let cells = wordCells[formed] ?? path
        for (r, c) in cells {
            grid[r][c].found = true
            grid[r][c].highlighted = false
        }
        if foundWords.count == currentWords.count {
            isFrozen = true
            let freeze = difficulty.bonusFreezeSeconds
            generatePuzzle()
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(freeze)) { [weak self] in
                self?.isFrozen = false
            }
        }
    }

    private func flashUnfound() {
        for word in currentWords where !foundWords.contains(word.lowercased()) {
            if let cells = wordCells[word.lowercased()] {
                for (r, c) in cells {
                    grid[r][c].unfoundFlash = true
                }
            }
        }
    }

    private func applyHighlight(path: [(Int, Int)]) {
        clearHighlights(keepFound: true)
        for (r, c) in path {
            if !grid[r][c].found {
                grid[r][c].highlighted = true
            }
        }
    }

    private func clearHighlights(keepFound: Bool = true) {
        for r in grid.indices {
            for c in grid[r].indices {
                grid[r][c].highlighted = false
                if !keepFound { grid[r][c].unfoundFlash = false }
                else { grid[r][c].unfoundFlash = false }
            }
        }
    }

    private func path(from start: (Int, Int), to end: (Int, Int)) -> [(Int, Int)] {
        let dr = end.0 - start.0
        let dc = end.1 - start.1
        let steps = max(abs(dr), abs(dc))
        guard steps > 0 else { return [start] }
        // Only allow straight lines (row, col, or diagonal)
        if !(dr == 0 || dc == 0 || abs(dr) == abs(dc)) {
            return [start]
        }
        var result: [(Int, Int)] = []
        for i in 0 ... steps {
            let r = start.0 + Int(round(Double(dr) * Double(i) / Double(steps)))
            let c = start.1 + Int(round(Double(dc) * Double(i) / Double(steps)))
            if grid.indices.contains(r), grid[r].indices.contains(c) {
                result.append((r, c))
            }
        }
        return result
    }
}
