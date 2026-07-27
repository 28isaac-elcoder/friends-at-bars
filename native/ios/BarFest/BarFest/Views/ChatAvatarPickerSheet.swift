import SwiftUI

enum ChatAvatarPickerTarget: String, Identifiable {
    case own
    case otherUser

    var id: String { rawValue }

    var title: String {
        switch self {
        case .own: return "Your icon"
        case .otherUser: return "Other user icon"
        }
    }
}

struct ChatAvatarPickerSheet: View {
    let target: ChatAvatarPickerTarget

    @ObservedObject private var store = ChatAvatarStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var icon: ChatAvatarIcon
    @State private var color: ChatAvatarColor
    @State private var message: String?

    init(target: ChatAvatarPickerTarget = .own) {
        self.target = target
        let current: ChatAvatarSelection = {
            switch target {
            case .own: return ChatAvatarStore.shared.selection
            case .otherUser: return ChatAvatarStore.shared.otherSelection
            }
        }()
        _icon = State(initialValue: current.icon)
        _color = State(initialValue: current.color)
    }

    private var enforceCooldown: Bool { target == .own }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Spacer()
                        ChatAvatarBadge(selection: ChatAvatarSelection(icon: icon, color: color), size: 72)
                        Spacer()
                    }
                    .padding(.top, 8)

                    Text("Icon")
                        .font(.headline)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 10)], spacing: 10) {
                        ForEach(ChatAvatarIcon.allCases) { item in
                            Button {
                                icon = item
                                message = nil
                            } label: {
                                Text(item.emoji)
                                    .font(.system(size: 28))
                                    .frame(width: 64, height: 64)
                                    .background(Color.white.opacity(icon == item ? 0.2 : 0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(icon == item ? Color.accentColor : Color.clear, lineWidth: 2)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(item.label)
                        }
                    }

                    Text("Background")
                        .font(.headline)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 10)], spacing: 10) {
                        ForEach(ChatAvatarColor.allCases) { item in
                            Button {
                                color = item
                                message = nil
                            } label: {
                                Circle()
                                    .fill(item.swiftUIColor)
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(color == item ? Color.white : Color.clear, lineWidth: 3)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(item.label)
                        }
                    }

                    if let message {
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if enforceCooldown {
                        if !store.canChange {
                            Text(store.cooldownMessage)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("You can change your icon once every 3 days.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Test Mode — change this icon anytime.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(target.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        switch target {
                        case .own:
                            if let wait = store.tryUpdate(icon: icon, color: color) {
                                message = wait
                            } else {
                                dismiss()
                            }
                        case .otherUser:
                            store.updateOther(icon: icon, color: color)
                            dismiss()
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
