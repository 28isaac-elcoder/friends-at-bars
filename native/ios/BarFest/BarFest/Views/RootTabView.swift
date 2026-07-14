import SwiftUI

struct RootTabView: View {
    @ObservedObject private var testMode = TestModeStore.shared

    var body: some View {
        VStack(spacing: 0) {
            TestModeChrome()
            TabView {
                ActivitiesView()
                    .tabItem { Label("Activities", systemImage: "bolt.fill") }
                DealsView()
                    .tabItem { Label("Deals", systemImage: "tag.fill") }
                ChatView()
                    .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right.fill") }
                MapScreen()
                    .tabItem { Label("Map", systemImage: "map.fill") }
                GamesHubView()
                    .tabItem { Label("Games", systemImage: "gamecontroller.fill") }
                if testMode.uiEnabled {
                    LogView()
                        .tabItem { Label("Log", systemImage: "doc.text") }
                }
            }
        }
    }
}
