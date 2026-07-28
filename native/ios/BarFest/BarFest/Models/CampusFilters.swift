import SwiftUI

enum CampusArea: String, CaseIterable, Identifiable, Hashable {
    case northCampus = "North Campus"
    case southCampus = "South Campus"
    case shortNorth = "Short North"
    case grandview = "Grandview / Breweries"

    var id: String { rawValue }

    /// Compact chip label.
    var shortLabel: String {
        switch self {
        case .northCampus: return "North Campus"
        case .southCampus: return "South Campus"
        case .shortNorth: return "Short North"
        case .grandview: return "Grand-Brew"
        }
    }

    /// Vibrant accent used for area chips and bar/deal area subtitles.
    var accentColor: Color {
        switch self {
        case .southCampus: return Color(red: 0.92, green: 0.22, blue: 0.28)
        case .northCampus: return Color(red: 0.22, green: 0.48, blue: 0.98)
        case .shortNorth: return Color(red: 0.18, green: 0.78, blue: 0.38)
        case .grandview: return Color(red: 0.72, green: 0.32, blue: 0.95)
        }
    }

    static func matching(areaRaw: String) -> CampusArea? {
        allCases.first { $0.rawValue == areaRaw }
    }
}

enum PopulationSort: String, CaseIterable, Identifiable {
    case mostPopulated = "Most Populated"
    case leastPopulated = "Least Populated"

    var id: String { rawValue }

    mutating func toggle() {
        self = self == .mostPopulated ? .leastPopulated : .mostPopulated
    }
}

enum DayFilter: Int, CaseIterable, Identifiable {
    case all = -1
    case sunday = 0
    case monday = 1
    case tuesday = 2
    case wednesday = 3
    case thursday = 4
    case friday = 5
    case saturday = 6

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .all: return "All"
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }

    /// Calendar weekday mapped to DayFilter (Sunday = 0 … Saturday = 6).
    static var today: DayFilter {
        let weekday = Calendar.current.component(.weekday, from: Date()) // 1=Sun … 7=Sat
        return DayFilter(rawValue: weekday - 1) ?? .all
    }
}
