import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var appModel: AppModel
    @ObservedObject private var testMode = TestModeStore.shared
    @State private var posts: [ChatPost] = []
    @State private var sort = "recent"
    @State private var draft = ""
    @State private var error: String?
    @FocusState private var composerFocused: Bool

    private var remaining: Int { AppConfig.maxChatChars - draft.count }

    /// Live venue from engine, unless Test Mode simulates location off.
    private var atVenue: Bool {
        if testMode.uiEnabled && !testMode.simulateLocationAllowed {
            return false
        }
        return appModel.lastVenueName != nil
    }

    private var effectiveVenueName: String? {
        if testMode.uiEnabled && !testMode.simulateLocationAllowed {
            return nil
        }
        return appModel.lastVenueName
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Picker("Sort", selection: $sort) {
                        Text("Recent").tag("recent")
                        Text("Popular").tag("popular")
                    }
                    .pickerStyle(.segmented)

                    if testMode.uiEnabled {
                        Button {
                            testMode.simulateLocationAllowed.toggle()
                            DiagnosticLog.shared.append(
                                category: "chat",
                                message: "Simulate location allowed=\(testMode.simulateLocationAllowed)"
                            )
                        } label: {
                            Image(systemName: testMode.simulateLocationAllowed
                                  ? "location.fill"
                                  : "location.slash")
                        }
                        .accessibilityLabel(
                            testMode.simulateLocationAllowed
                                ? "Simulate location on"
                                : "Simulate location off"
                        )
                    }
                }
                .padding()
                .onChange(of: sort) { _, _ in
                    Task { await load() }
                }

                List(posts) { post in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(post.body)
                            .font(.body)
                        HStack {
                            Text(post.venue_name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(post.score)")
                                .monospacedDigit()
                            Button("↑") {
                                Task { try? await ChatService.setVote(postId: post.id, direction: "up"); await load() }
                            }
                            .buttonStyle(.borderless)
                            Button("↓") {
                                Task { try? await ChatService.setVote(postId: post.id, direction: "down"); await load() }
                            }
                            .buttonStyle(.borderless)
                        }
                        if post.author_id == AnonymousIdentity.userId() {
                            Button("Delete", role: .destructive) {
                                Task { try? await ChatService.hideOwn(postId: post.id); await load() }
                            }
                            .font(.caption)
                        } else {
                            Button("Report") {
                                Task { try? await ChatService.report(postId: post.id, reason: nil); await load() }
                            }
                            .font(.caption)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)

                if let error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                HStack(alignment: .bottom, spacing: 8) {
                    TextField(
                        atVenue ? "Say something…" : "Must be at a bar to chat",
                        text: $draft,
                        axis: .vertical
                    )
                    .lineLimit(1 ... 4)
                    .font(.system(size: 17))
                    .focused($composerFocused)
                    .disabled(!atVenue)
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                    Button {
                        Task { await send() }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !atVenue || remaining < 0)
                }
                .padding()
                .overlay(alignment: .topTrailing) {
                    if remaining < 0 {
                        Text("150 Character Limit")
                            .font(.caption.bold())
                            .foregroundStyle(.red)
                            .padding(.trailing, 56)
                            .padding(.top, 4)
                    }
                }
            }
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(.inline)
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private func load() async {
        do {
            posts = try await ChatService.fetchFeed(sort: sort)
            error = nil
        } catch {
            self.error = error.localizedDescription
            DiagnosticLog.shared.append(
                category: "chat",
                message: error.localizedDescription,
                level: "error"
            )
        }
    }

    private func send() async {
        guard let venue = effectiveVenueName else {
            error = "Must be at a Bar to Chat"
            return
        }
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard trimmed.count <= AppConfig.maxChatChars else {
            error = "150 Character Limit"
            return
        }
        do {
            try await ChatService.createPost(body: trimmed, venueName: venue)
            draft = ""
            composerFocused = false
            DiagnosticLog.shared.append(category: "chat", message: "Posted at \(venue)")
            await load()
        } catch {
            self.error = error.localizedDescription
            DiagnosticLog.shared.append(
                category: "chat",
                message: error.localizedDescription,
                level: "error"
            )
        }
    }
}
