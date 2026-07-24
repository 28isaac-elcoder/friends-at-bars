import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var appModel: AppModel
    @ObservedObject private var testMode = TestModeStore.shared
    @ObservedObject private var localChat = TestChatStore.shared
    @ObservedObject private var locationAuth = LocationAuthorizationStore.shared
    @ObservedObject private var avatarStore = ChatAvatarStore.shared

    @State private var posts: [ChatPost] = []
    @State private var sort = "recent"
    @State private var draft = ""
    @State private var error: String?
    @State private var selectMode = false
    @State private var selectedIds: Set<UUID> = []
    @State private var showAvatarPicker = false
    @FocusState private var composerFocused: Bool

    private var useLocal: Bool { testMode.uiEnabled && testMode.useMockCheckIns }
    private var remaining: Int { AppConfig.maxChatChars - draft.count }
    private var overCharLimit: Bool { remaining < 0 }

    private var venueOptions: [CatalogVenue] {
        appModel.venues.sorted {
            if $0.area != $1.area { return $0.area < $1.area }
            return $0.name < $1.name
        }
    }

    /// Production: need OS location + at a bar. Test local: gated by simulateLocationAllowed.
    private var needLocationGate: Bool {
        if useLocal { return !testMode.simulateLocationAllowed }
        return !locationAuth.isAuthorized
    }

    private var atVenue: Bool {
        if useLocal {
            return testMode.simulateLocationAllowed
                && !localChat.simulatedVenueName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return locationAuth.isAuthorized && appModel.lastVenueName != nil
    }

    private var effectiveVenueName: String? {
        if useLocal {
            guard testMode.simulateLocationAllowed else { return nil }
            let v = localChat.simulatedVenueName.trimmingCharacters(in: .whitespacesAndNewlines)
            return v.isEmpty ? nil : v
        }
        return appModel.lastVenueName
    }

    private var displayedPosts: [ChatPost] {
        useLocal ? localChat.feed(sort: sort) : posts
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

                    if useLocal {
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

                        Button {
                            if selectMode {
                                exitSelectMode()
                            } else {
                                selectMode = true
                            }
                        } label: {
                            Image(systemName: selectMode ? "xmark" : "list.bullet")
                        }
                        .accessibilityLabel(selectMode ? "Exit select mode" : "Select messages")
                    }
                }
                .padding()
                .onChange(of: sort) { _, _ in
                    Task { await load() }
                }

                if selectMode && useLocal {
                    HStack {
                        Text("\(selectedIds.count) selected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            localChat.forceVote(postIds: Array(selectedIds), direction: "up")
                            exitSelectMode()
                        } label: {
                            Image(systemName: "chevron.up")
                        }
                        .disabled(selectedIds.isEmpty)
                        Button {
                            localChat.forceVote(postIds: Array(selectedIds), direction: "down")
                            exitSelectMode()
                        } label: {
                            Image(systemName: "chevron.down")
                        }
                        .disabled(selectedIds.isEmpty)
                        Button(role: .destructive) {
                            localChat.hide(postIds: Array(selectedIds))
                            exitSelectMode()
                        } label: {
                            Image(systemName: "trash")
                        }
                        .disabled(selectedIds.isEmpty)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }

                if useLocal && !selectMode {
                    Text("Local test feed")
                        .font(.caption2)
                        .foregroundStyle(.cyan)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                }

                List {
                    ForEach(displayedPosts) { post in
                        chatRow(post)
                    }
                }
                .listStyle(.plain)

                if let error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                composer
            }
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showAvatarPicker = true
                    } label: {
                        ChatAvatarBadge(selection: avatarStore.selection, size: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Change chat icon")
                }
                if useLocal {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear local") {
                            localChat.clearAll()
                            exitSelectMode()
                        }
                        .font(.caption)
                    }
                }
            }
            .sheet(isPresented: $showAvatarPicker) {
                ChatAvatarPickerSheet()
            }
            .task {
                await load()
                if useLocal, !venueOptions.isEmpty {
                    let names = Set(venueOptions.map(\.name))
                    if !names.contains(localChat.simulatedVenueName) {
                        localChat.simulatedVenueName =
                            venueOptions.first(where: { $0.name == "Test Location 1" })?.name
                            ?? venueOptions[0].name
                    }
                }
            }
            .refreshable { await load() }
            .onChange(of: testMode.useMockCheckIns) { _, _ in
                exitSelectMode()
                Task { await load() }
            }
            .onChange(of: localChat.posts.count) { _, _ in
                if useLocal { posts = localChat.feed(sort: sort) }
            }
        }
    }

    @ViewBuilder
    private func chatRow(_ post: ChatPost) -> some View {
        let isOwn = post.author_id == AnonymousIdentity.userId()
        let avatar = ChatAvatarResolver.selection(
            for: post.author_id,
            preference: avatarStore.selection
        )
        let bodyColor: Color = isOwn ? .black : .white
        let metaColor: Color = isOwn ? Color.black.opacity(0.45) : Color.secondary
        let rowBg: Color = isOwn ? .white : Color.clear

        HStack(alignment: .top, spacing: 10) {
            if selectMode && useLocal {
                Image(systemName: selectedIds.contains(post.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedIds.contains(post.id) ? Color.accentColor : .secondary)
                    .onTapGesture { toggleSelect(post.id) }
            }

            ChatAvatarBadge(selection: avatar, size: 36)

            VStack(alignment: .leading, spacing: 8) {
                Text(post.body)
                    .font(.body)
                    .foregroundStyle(bodyColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(alignment: .center, spacing: 8) {
                    HStack(spacing: 6) {
                        Text(post.venue_name)
                            .font(.caption)
                            .foregroundStyle(metaColor)
                        if post.author_id == TestChatStore.otherAuthorId {
                            Text("other")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                    Spacer(minLength: 8)
                    if !(selectMode && useLocal) {
                        RedditVotePill(
                            score: post.score,
                            myVote: post.my_vote,
                            disabled: isOwn,
                            onLightBackground: isOwn,
                            onUp: { Task { await vote(postId: post.id, direction: "up") } },
                            onDown: { Task { await vote(postId: post.id, direction: "down") } }
                        )
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if selectMode && useLocal { toggleSelect(post.id) }
            }
        }
        .padding(.horizontal, isOwn ? 10 : 0)
        .padding(.vertical, 8)
        .background(rowBg)
        .clipShape(RoundedRectangle(cornerRadius: isOwn ? 12 : 0, style: .continuous))
        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
        .listRowBackground(Color.clear)
        .swipeActions(edge: .trailing, allowsFullSwipe: !(selectMode && useLocal)) {
            if !(selectMode && useLocal) {
                if isOwn {
                    Button(role: .destructive) {
                        Task { await hideOwn(postId: post.id) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } else {
                    Button {
                        Task { await reportPost(postId: post.id) }
                    } label: {
                        Label("Report", systemImage: "flag")
                    }
                    .tint(.orange)
                }
            }
        }
    }

    @ViewBuilder
    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if useLocal && testMode.simulateLocationAllowed {
                HStack(spacing: 8) {
                    Text("Send as")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Picker("Sender", selection: $localChat.sender) {
                        ForEach(TestChatStore.Sender.allCases) { s in
                            Text(s.label).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 200)
                }

                HStack(alignment: .center, spacing: 8) {
                    Text("Bar")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Picker("Bar", selection: $localChat.simulatedVenueName) {
                        ForEach(venueOptions) { v in
                            Text("\(v.name)").tag(v.name)
                        }
                    }
                    .pickerStyle(.menu)
                    Spacer(minLength: 8)
                    if overCharLimit {
                        Text("150 Character Limit")
                            .font(.caption.bold())
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }

            if needLocationGate {
                Button {
                    if useLocal {
                        testMode.simulateLocationAllowed = true
                    } else {
                        locationAuth.requestAllowLocation()
                    }
                } label: {
                    Text(
                        useLocal
                            ? "Allow Location to Chat — tap to enable (simulate)"
                            : (locationAuth.needsAlwaysUpgrade
                               ? "Allow Location Always to Chat — upgrade from While Using"
                               : "Allow Location Always to Chat — tap to enable")
                    )
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            } else if !useLocal && !atVenue {
                Text("Must be at a Bar to Chat")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                if !useLocal {
                    HStack(alignment: .center, spacing: 8) {
                        if let venue = effectiveVenueName {
                            Text("Posting from \(venue)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        if overCharLimit {
                            Text("150 Character Limit")
                                .font(.caption.bold())
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }

                HStack(alignment: .bottom, spacing: 8) {
                    TextField(
                        placeholder,
                        text: $draft,
                        axis: .vertical
                    )
                    .lineLimit(1 ... 3)
                    .font(.system(size: 17))
                    .foregroundStyle(overCharLimit ? Color.red : Color.primary)
                    .focused($composerFocused)
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                    Button {
                        Task { await send() }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                    }
                    .disabled(
                        draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || !atVenue
                            || overCharLimit
                    )
                }
            }
        }
        .padding()
    }

    private var placeholder: String {
        if useLocal && localChat.sender == .other {
            return "Message as another user…"
        }
        if let venue = effectiveVenueName {
            return "What's happening at \(venue)?"
        }
        return "Say something…"
    }

    private func exitSelectMode() {
        selectMode = false
        selectedIds = []
    }

    private func toggleSelect(_ id: UUID) {
        if selectedIds.contains(id) { selectedIds.remove(id) }
        else { selectedIds.insert(id) }
    }

    private func load() async {
        if useLocal {
            posts = localChat.feed(sort: sort)
            error = nil
            return
        }
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

    private func vote(postId: UUID, direction: String) async {
        do {
            if useLocal {
                try localChat.setVote(postId: postId, direction: direction)
            } else {
                try await ChatService.setVote(postId: postId, direction: direction)
                await load()
            }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func hideOwn(postId: UUID) async {
        if useLocal {
            localChat.hide(postIds: [postId])
        } else {
            try? await ChatService.hideOwn(postId: postId)
            await load()
        }
    }

    private func reportPost(postId: UUID) async {
        if useLocal {
            // Local feed has no server report — soft-hide + log for Test Mode parity.
            localChat.hide(postIds: [postId])
            DiagnosticLog.shared.append(
                category: "chat",
                message: "Reported (local) post \(postId.uuidString.prefix(8))…"
            )
        } else {
            do {
                try await ChatService.report(postId: postId, reason: nil)
                DiagnosticLog.shared.append(category: "chat", message: "Reported post")
                await load()
            } catch {
                self.error = error.localizedDescription
                DiagnosticLog.shared.append(
                    category: "chat",
                    message: "Report failed: \(error.localizedDescription)",
                    level: "error"
                )
            }
        }
    }

    private func send() async {
        guard let venue = effectiveVenueName else {
            error = needLocationGate ? "Allow Location to Chat" : "Must be at a Bar to Chat"
            return
        }
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard trimmed.count <= AppConfig.maxChatChars else {
            error = "150 Character Limit"
            return
        }
        do {
            if useLocal {
                try localChat.createPost(body: trimmed)
                draft = ""
                composerFocused = false
                DiagnosticLog.shared.append(category: "chat", message: "Local post at \(venue)")
            } else {
                try await ChatService.createPost(body: trimmed, venueName: venue)
                draft = ""
                composerFocused = false
                DiagnosticLog.shared.append(category: "chat", message: "Posted at \(venue)")
                await load()
            }
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
}
