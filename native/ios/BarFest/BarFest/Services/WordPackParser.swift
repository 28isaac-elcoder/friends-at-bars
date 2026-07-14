import Foundation

/// Flatten Switch Search wordLibrary JSON into a single word list.
enum WordPackParser {
    static func flatten(_ data: Data) -> [String] {
        if let arr = try? JSONDecoder().decode([String].self, from: data) {
            return arr
        }
        if let obj = try? JSONDecoder().decode([String: [String]].self, from: data) {
            return obj.values.flatMap { $0 }
        }
        return []
    }
}
