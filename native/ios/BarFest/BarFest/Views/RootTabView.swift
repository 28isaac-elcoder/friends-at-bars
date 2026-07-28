import SwiftUI

private enum AppTab: Hashable {
    case activities
    case deals
    case chat
    case map
    case games
    case log

    var title: String {
        switch self {
        case .activities: return "Activities"
        case .deals: return "Deals"
        case .chat: return "Chat"
        case .map: return "Map"
        case .games: return "Games"
        case .log: return "Log"
        }
    }

    var systemImage: String {
        switch self {
        case .activities: return "bolt.fill"
        case .deals: return "tag.fill"
        case .chat: return "bubble.left.and.bubble.right.fill"
        case .map: return "map.fill"
        case .games: return "gamecontroller.fill"
        case .log: return "doc.text"
        }
    }
}

struct RootTabView: View {
    @ObservedObject private var testMode = TestModeStore.shared
    @State private var selectedTab: AppTab = .activities
    @State private var shakeTriggers: [AppTab: Int] = [:]

    private var visibleTabs: [AppTab] {
        var tabs: [AppTab] = [.activities, .deals, .chat, .map]
        if testMode.uiEnabled {
            tabs.append(contentsOf: [.games, .log])
        }
        return tabs
    }

    var body: some View {
        VStack(spacing: 0) {
            TestModeChrome()
            TabView(selection: $selectedTab) {
                ActivitiesView()
                    .tag(AppTab.activities)
                DealsView()
                    .tag(AppTab.deals)
                ChatView()
                    .tag(AppTab.chat)
                MapScreen()
                    .tag(AppTab.map)
                if testMode.uiEnabled {
                    GamesHubView()
                        .tag(AppTab.games)
                    LogView()
                        .tag(AppTab.log)
                }
            }
            .toolbar(.hidden, for: .tabBar)
            customTabBar
        }
        .preferredColorScheme(.dark)
        .onChange(of: testMode.uiEnabled) { _, enabled in
            if !enabled, selectedTab == .games || selectedTab == .log {
                selectedTab = .activities
            }
        }
    }

    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(visibleTabs, id: \.self) { tab in
                Button {
                    select(tab)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 18, weight: .semibold))
                        Text(tab.title)
                            .font(.caption2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    .padding(.bottom, 6)
                    .modifier(TabShakeModifier(trigger: shakeTriggers[tab, default: 0]))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
            }
        }
        .background(
            Color(uiColor: .secondarySystemGroupedBackground)
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            Divider().opacity(0.5)
        }
    }

    private func select(_ tab: AppTab) {
        selectedTab = tab
        shakeTriggers[tab, default: 0] += 1
    }
}

/// Quick left-right rotation shake for tab icon + label.
private struct TabShakeModifier: ViewModifier {
    let trigger: Int
    @State private var angle: Double = 0

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(angle))
            .onChange(of: trigger) { _, _ in
                Task { @MainActor in
                    let kicks: [Double] = [12, -12, 9, -9, 5, -5, 0]
                    for kick in kicks {
                        withAnimation(.easeInOut(duration: 0.045)) {
                            angle = kick
                        }
                        try? await Task.sleep(nanoseconds: 45_000_000)
                    }
                }
            }
    }
}
