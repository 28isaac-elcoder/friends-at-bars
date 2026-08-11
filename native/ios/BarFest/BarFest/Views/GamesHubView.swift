import SwiftUI

struct GamesHubView: View {
    @ObservedObject private var testMode = TestModeStore.shared
    @State private var showSwitchSearch = false
    @State private var showRideTheBus = false

    var body: some View {
        NavigationStack {
            List {
                Button {
                    showSwitchSearch = true
                } label: {
                    Text("Switch Search")
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }

                if testMode.uiEnabled {
                    Button {
                        showRideTheBus = true
                    } label: {
                        Text("Ride the Bus")
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }

                    NavigationLink("Mega Toe") {
                        Text("Mega Toe — placeholder board. Port full rules from React in a follow-up.")
                            .padding()
                    }
                }
            }
            .navigationTitle("Games")
            .fullScreenCover(isPresented: $showSwitchSearch) {
                SwitchSearchView()
            }
            .fullScreenCover(isPresented: $showRideTheBus) {
                RideTheBusView()
            }
        }
    }
}
