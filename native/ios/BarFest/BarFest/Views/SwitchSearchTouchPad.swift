import SwiftUI
import UIKit

/// UIKit touch surface so selection drags aren't cancelled when SwiftUI re-renders highlights.
struct SwitchSearchTouchPad: UIViewRepresentable {
    var gridSize: Int
    var cell: CGFloat
    var gap: CGFloat
    var onMove: (Int, Int) -> Void
    var onEnd: (Int?, Int?) -> Void

    func makeUIView(context: Context) -> TouchPadView {
        let view = TouchPadView()
        view.backgroundColor = .clear
        view.isMultipleTouchEnabled = false
        view.coordinator = context.coordinator
        return view
    }

    func updateUIView(_ uiView: TouchPadView, context: Context) {
        context.coordinator.gridSize = gridSize
        context.coordinator.cell = cell
        context.coordinator.gap = gap
        context.coordinator.onMove = onMove
        context.coordinator.onEnd = onEnd
        uiView.coordinator = context.coordinator
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(gridSize: gridSize, cell: cell, gap: gap, onMove: onMove, onEnd: onEnd)
    }

    final class Coordinator {
        var gridSize: Int
        var cell: CGFloat
        var gap: CGFloat
        var onMove: (Int, Int) -> Void
        var onEnd: (Int?, Int?) -> Void

        init(
            gridSize: Int,
            cell: CGFloat,
            gap: CGFloat,
            onMove: @escaping (Int, Int) -> Void,
            onEnd: @escaping (Int?, Int?) -> Void
        ) {
            self.gridSize = gridSize
            self.cell = cell
            self.gap = gap
            self.onMove = onMove
            self.onEnd = onEnd
        }

        func cell(at point: CGPoint) -> (Int, Int)? {
            let stride = cell + gap
            guard stride > 0 else { return nil }
            let c = Int((point.x / stride).rounded(.down))
            let r = Int((point.y / stride).rounded(.down))
            guard r >= 0, c >= 0, r < gridSize, c < gridSize else { return nil }
            return (r, c)
        }
    }

    final class TouchPadView: UIView {
        weak var coordinator: Coordinator?

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let touch = touches.first, let coord = coordinator else { return }
            let point = touch.location(in: self)
            if let (r, c) = coord.cell(at: point) {
                coord.onMove(r, c)
            }
        }

        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let touch = touches.first, let coord = coordinator else { return }
            let point = touch.location(in: self)
            if let (r, c) = coord.cell(at: point) {
                coord.onMove(r, c)
            }
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let touch = touches.first, let coord = coordinator else { return }
            let point = touch.location(in: self)
            let cell = coord.cell(at: point)
            coord.onEnd(cell?.0, cell?.1)
        }

        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let coord = coordinator else { return }
            coord.onEnd(nil, nil)
        }
    }
}
