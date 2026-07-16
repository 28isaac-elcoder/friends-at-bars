import Foundation

enum CampusArea: String, CaseIterable, Identifiable, Hashable {
    case northCampus = "North Campus"
    case southCampus = "South Campus"
    case shortNorth = "Short North"
    case grandview = "Grandview / Breweries"

    var id: String { rawValue }
}

enum PopulationSort: String, CaseIterable, Identifiable {
    case mostPopulated = "Most Populated"
    case leastPopulated = "Least Populated"

    var id: String { rawValue }
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
