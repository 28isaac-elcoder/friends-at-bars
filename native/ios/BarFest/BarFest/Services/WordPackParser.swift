import Foundation

/// Flatten Switch Search wordLibrary JSON into a single word list (legacy helpers).
enum WordPackParser {
    static func flatten(_ data: Data) -> [String] {
        if let lib = WordLibrary.fromCMSPayload(data) {
            return lib.allWords
        }
        return []
    }

    static func library(from data: Data) -> WordLibrary? {
        WordLibrary.fromCMSPayload(data)
    }
}
