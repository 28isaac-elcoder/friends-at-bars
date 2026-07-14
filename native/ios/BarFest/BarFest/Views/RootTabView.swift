import SwiftUI

struct RootTabView: View {
    var body: some View {
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
        }
    }
}
