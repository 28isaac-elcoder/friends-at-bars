import SwiftUI

struct GamesHubView: View {
    @State private var showSwitchSearch = false

    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Ride the Bus") {
                    RideTheBusView()
                }
                NavigationLink("Mega Toe") {
                    Text("Mega Toe — placeholder board. Port full rules from React in a follow-up.")
                        .padding()
                }
                Button {
                    showSwitchSearch = true
                } label: {
                    Text("Switch Search")
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
            }
            .navigationTitle("Games")
            .fullScreenCover(isPresented: $showSwitchSearch) {
                SwitchSearchView()
            }
        }
    }
}

struct RideTheBusView: View {
    private let ranks = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
    private let suits = ["♠", "♥", "♦", "♣"]
    @State private var card = "Tap draw"
    @State private var round = 0

    var body: some View {
        VStack(spacing: 24) {
            Text("Ride the Bus")
                .font(.largeTitle.bold())
            Text(card)
                .font(.system(size: 64, weight: .bold, design: .rounded))
            Text("Round \(round)")
                .foregroundStyle(.secondary)
            Button("Draw") {
                let r = ranks.randomElement()!
                let s = suits.randomElement()!
                card = "\(r)\(s)"
                round += 1
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding()
    }
}
