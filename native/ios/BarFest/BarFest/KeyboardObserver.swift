import Combine
import SwiftUI
import UIKit

/// Tracks software-keyboard visibility for hiding chrome (e.g. custom tab bar).
@MainActor
final class KeyboardObserver: ObservableObject {
    static let shared = KeyboardObserver()

    @Published private(set) var isVisible = false

    private var cancellables = Set<AnyCancellable>()

    private init() {
        let show = NotificationCenter.default.publisher(
            for: UIResponder.keyboardWillShowNotification
        )
        .map { _ in true }

        let hide = NotificationCenter.default.publisher(
            for: UIResponder.keyboardWillHideNotification
        )
        .map { _ in false }

        Publishers.Merge(show, hide)
            .receive(on: DispatchQueue.main)
            .assign(to: &$isVisible)
    }

    static func dismiss() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

extension View {
    /// Resigns first responder when the user taps this view (use on scroll content, not text fields).
    func dismissKeyboardOnTap() -> some View {
        simultaneousGesture(
            TapGesture().onEnded { _ in
                KeyboardObserver.dismiss()
            }
        )
    }
}
