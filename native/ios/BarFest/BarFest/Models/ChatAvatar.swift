import SwiftUI

/// Nightlife-themed anonymous chat avatars (Yik Yak–style emoji on colored discs).
enum ChatAvatarIcon: String, CaseIterable, Identifiable, Codable {
    case beerCan
    case shotGlass
    case beerBong
    case martini
    case beerPint
    case wineBottle
    case olive
    case lime

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .beerCan: return "🥫"
        case .shotGlass: return "🥃"
        case .beerBong: return "🍻"
        case .martini: return "🍸"
        case .beerPint: return "🍺"
        case .wineBottle: return "🍷"
        case .olive: return "🫒"
        case .lime: return "🍋"
        }
    }

    var label: String {
        switch self {
        case .beerCan: return "Beer can"
        case .shotGlass: return "Shot glass"
        case .beerBong: return "Beer bong"
        case .martini: return "Martini"
        case .beerPint: return "Beer pint"
        case .wineBottle: return "Wine bottle"
        case .olive: return "Olive"
        case .lime: return "Lime"
        }
    }
}

enum ChatAvatarColor: String, CaseIterable, Identifiable, Codable {
    case redMatte, redNeon
    case orangeMatte, orangeNeon
    case greenMatte, greenNeon
    case blueMatte, blueNeon
    case purpleMatte, purpleNeon

    var id: String { rawValue }

    var label: String {
        switch self {
        case .redMatte: return "Red (matte)"
        case .redNeon: return "Red (neon)"
        case .orangeMatte: return "Orange (matte)"
        case .orangeNeon: return "Orange (neon)"
        case .greenMatte: return "Green (matte)"
        case .greenNeon: return "Green (neon)"
        case .blueMatte: return "Blue (matte)"
        case .blueNeon: return "Blue (neon)"
        case .purpleMatte: return "Purple (matte)"
        case .purpleNeon: return "Purple (neon)"
        }
    }

    var swiftUIColor: Color {
        switch self {
        case .redMatte: return Color(red: 0.55, green: 0.18, blue: 0.18)
        case .redNeon: return Color(red: 1.0, green: 0.2, blue: 0.35)
        case .orangeMatte: return Color(red: 0.65, green: 0.35, blue: 0.12)
        case .orangeNeon: return Color(red: 1.0, green: 0.55, blue: 0.1)
        case .greenMatte: return Color(red: 0.2, green: 0.45, blue: 0.28)
        case .greenNeon: return Color(red: 0.2, green: 0.95, blue: 0.45)
        case .blueMatte: return Color(red: 0.18, green: 0.32, blue: 0.55)
        case .blueNeon: return Color(red: 0.25, green: 0.55, blue: 1.0)
        case .purpleMatte: return Color(red: 0.38, green: 0.22, blue: 0.5)
        case .purpleNeon: return Color(red: 0.75, green: 0.35, blue: 1.0)
        }
    }
}

struct ChatAvatarSelection: Equatable, Codable {
    var icon: ChatAvatarIcon
    var color: ChatAvatarColor

    static let `default` = ChatAvatarSelection(icon: .beerPint, color: .blueMatte)
}

enum ChatAvatarResolver {
    /// Own preference when `authorId` is this device; otherwise a stable hash so others stay consistent.
    static func selection(for authorId: String, preference: ChatAvatarSelection?) -> ChatAvatarSelection {
        if authorId == AnonymousIdentity.userId(), let preference {
            return preference
        }
        return derived(from: authorId)
    }

    static func derived(from authorId: String) -> ChatAvatarSelection {
        var hash: UInt64 = 5381
        for b in authorId.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(b)
        }
        let icons = ChatAvatarIcon.allCases
        let colors = ChatAvatarColor.allCases
        let icon = icons[Int(hash % UInt64(icons.count))]
        let color = colors[Int((hash / UInt64(icons.count)) % UInt64(colors.count))]
        return ChatAvatarSelection(icon: icon, color: color)
    }
}

struct ChatAvatarBadge: View {
    let selection: ChatAvatarSelection
    var size: CGFloat = 36

    var body: some View {
        Text(selection.icon.emoji)
            .font(.system(size: size * 0.48))
            .frame(width: size, height: size)
            .background(selection.color.swiftUIColor)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
    }
}
