import Foundation

/// Fail banners: headline = text through first `!`; subtitle = remainder (shown after cards fall).
struct RTBFailCopy: Equatable {
    let headline: String
    let subtitle: String
    /// Used only to classify two-sip tie prompts (not stored as a drink counter).
    let isTwoSip: Bool

    static func parse(_ full: String) -> RTBFailCopy {
        let trimmed = full.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let bang = trimmed.firstIndex(of: "!") else {
            return RTBFailCopy(headline: trimmed, subtitle: "", isTwoSip: false)
        }
        let headline = String(trimmed[...bang])
        let subtitle = String(trimmed[trimmed.index(after: bang)...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = subtitle.lowercased()
        let isTwoSip = lower.contains("2 sip") || lower.contains("two sip")
        return RTBFailCopy(headline: headline, subtitle: subtitle, isTwoSip: isTwoSip)
    }
}

enum RTBFailMessages {
    /// Full rotation for normal wrong guesses.
    static let allRaw: [String] = [
        "Engine Overheated! Sit tight, take a drink, try again.",
        "Driver Hit A Pothole! Take a drink - Draw again.",
        "Sharp Turn! The Bus Rolled. Take 2 sips.",
        "Flat Tire! Pull over and take a drink while we swap it out.",
        "Brake Check! BOOM! Take a sip, you’re gonna need it.",
        "Missed Your Stop! Double back. Take a drink and redraw.",
        "Caught At a Red Light! Wait it out and take a drink.",
        "Ticket Inspector Onboard! Caught without a pass. Take 2 sips.",
        "The Bus is Full! Wait for the next one. Take a sip.",
        "Dead Battery! Need a jumpstart. Take a drink.",
        "Fell Asleep on The Back Row! Woke up at the depot. Take 2 sips.",
        "Speed Bump Surprise! Hit it too fast. Drink and redraw.",
    ]

    /// Used when Higher/Lower or Inside/Outside ties on rank (same number).
    static let twoSipRaw: [String] = allRaw.filter {
        $0.lowercased().contains("2 sip") || $0.lowercased().contains("two sip")
    }

    static let all: [RTBFailCopy] = allRaw.map(RTBFailCopy.parse)
    static let twoSip: [RTBFailCopy] = all.filter(\.isTwoSip)
}
