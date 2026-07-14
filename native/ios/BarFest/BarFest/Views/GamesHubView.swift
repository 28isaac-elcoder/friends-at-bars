import SwiftUI

struct GamesHubView: View {
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
                NavigationLink("Switch Search") {
                    SwitchSearchView()
                }
            }
            .navigationTitle("Games")
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

/// Native Switch Search scaffold — word bank from Supabase `catalog_game_content`.
struct SwitchSearchView: View {
    @State private var words: [String] = []
    @State private var current = ""
    @State private var guess = ""
    @State private var status = "Load a pack, then guess anagrams."
    @State private var score = 0

    var body: some View {
        VStack(spacing: 16) {
            Text("Switch Search")
                .font(.title.bold())
            Text(scrambled(current.isEmpty ? "····" : current))
                .font(.system(size: 36, weight: .semibold, design: .monospaced))
            TextField("Your guess", text: $guess)
                .textInputAutocapitalization(.never)
                .font(.system(size: 17))
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Button("Submit") {
                if guess.lowercased() == current.lowercased() {
                    score += 1
                    status = "Correct! +\(score)"
                    nextWord()
                } else {
                    status = "Try again"
                }
                guess = ""
            }
            .buttonStyle(.borderedProminent)
            Text(status).foregroundStyle(.secondary)
            Text("Score: \(score)").monospacedDigit()
            Spacer()
        }
        .padding()
        .task {
            await CatalogStore.shared.loadCachedVenuesIfNeeded()
            try? await CatalogStore.shared.refresh()
            let pack = await CatalogStore.shared.wordPack
            // Flatten payload keys if stored as fourLetter/fiveLetter objects — CatalogStore exposes wordPack list when possible.
            words = pack.isEmpty ? ["test", "bar", "fest", "night"] : pack
            nextWord()
        }
    }

    private func nextWord() {
        current = words.randomElement() ?? "bar"
    }

    private func scrambled(_ word: String) -> String {
        String(word.shuffled())
    }
}
