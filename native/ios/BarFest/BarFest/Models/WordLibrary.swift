import Foundation

/// Bucketed Switch Search word library (matches web `wordLibrary.json` / CMS `catalog_game_content.payload`).
struct WordLibrary: Codable, Equatable {
    var fourLetter: [String]
    var fiveLetter: [String]
    var sixLetter: [String]
    var sevenLetter: [String]

    var isEmpty: Bool {
        fourLetter.isEmpty && fiveLetter.isEmpty && sixLetter.isEmpty && sevenLetter.isEmpty
    }

    var allWords: [String] {
        fourLetter + fiveLetter + sixLetter + sevenLetter
    }

    static let empty = WordLibrary(
        fourLetter: [],
        fiveLetter: [],
        sixLetter: [],
        sevenLetter: []
    )

    /// Tiny offline fallback if CMS and the bundled resource are both unavailable.
    static let minimalFallback = WordLibrary(
        fourLetter: ["bar", "fest", "beer", "shot"],
        fiveLetter: ["drink", "party", "happy"],
        sixLetter: ["campus", "friday"],
        sevenLetter: ["weekend", "special"]
    )

    enum CodingKeys: String, CodingKey {
        case fourLetter, fiveLetter, sixLetter, sevenLetter
        case words
    }

    init(
        fourLetter: [String],
        fiveLetter: [String],
        sixLetter: [String],
        sevenLetter: [String]
    ) {
        self.fourLetter = fourLetter
        self.fiveLetter = fiveLetter
        self.sixLetter = sixLetter
        self.sevenLetter = sevenLetter
    }

    init(from decoder: Decoder) throws {
        // Bare JSON array → bucket by length.
        if var unkeyed = try? decoder.unkeyedContainer() {
            var words: [String] = []
            while !unkeyed.isAtEnd {
                words.append(try unkeyed.decode(String.self))
            }
            self = Self.bucketByLength(words)
            return
        }

        let c = try decoder.container(keyedBy: CodingKeys.self)
        let four = try c.decodeIfPresent([String].self, forKey: .fourLetter) ?? []
        let five = try c.decodeIfPresent([String].self, forKey: .fiveLetter) ?? []
        let six = try c.decodeIfPresent([String].self, forKey: .sixLetter) ?? []
        let seven = try c.decodeIfPresent([String].self, forKey: .sevenLetter) ?? []
        if !four.isEmpty || !five.isEmpty || !six.isEmpty || !seven.isEmpty {
            fourLetter = four
            fiveLetter = five
            sixLetter = six
            sevenLetter = seven
            return
        }
        // Legacy flat `{ "words": [...] }`
        if let words = try c.decodeIfPresent([String].self, forKey: .words), !words.isEmpty {
            self = Self.bucketByLength(words)
            return
        }
        fourLetter = []
        fiveLetter = []
        sixLetter = []
        sevenLetter = []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(fourLetter, forKey: .fourLetter)
        try c.encode(fiveLetter, forKey: .fiveLetter)
        try c.encode(sixLetter, forKey: .sixLetter)
        try c.encode(sevenLetter, forKey: .sevenLetter)
    }

    static func loadBundled() -> WordLibrary {
        if let url = Bundle.main.url(forResource: "wordLibrary", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let lib = try? JSONDecoder().decode(WordLibrary.self, from: data),
           !lib.isEmpty {
            return lib
        }
        return .minimalFallback
    }

    /// Build from raw CMS / file bytes.
    static func fromCMSPayload(_ data: Data) -> WordLibrary? {
        guard let lib = try? JSONDecoder().decode(WordLibrary.self, from: data), !lib.isEmpty else {
            return nil
        }
        return lib
    }

    private static func bucketByLength(_ words: [String]) -> WordLibrary {
        WordLibrary(
            fourLetter: words.filter { $0.count == 4 },
            fiveLetter: words.filter { $0.count == 5 },
            sixLetter: words.filter { $0.count == 6 },
            sevenLetter: words.filter { $0.count == 7 }
        )
    }
}
