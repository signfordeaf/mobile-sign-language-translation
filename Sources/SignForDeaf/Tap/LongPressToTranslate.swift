// Tap/LongPressToTranslate.swift

import UIKit

/// Long-press-to-translate (docs/08-tap-to-translate.md §"Long press").
///
/// Reaches the one thing passthrough cannot: text the host app made *tappable*,
/// where a tap always belongs to the app. Off by default. The 600 ms deadline is
/// deliberately longer than the framework's 500 ms so any long press the host
/// built fires first; this joins the competition without blocking it.
final class LongPressToTranslate: NSObject, UIGestureRecognizerDelegate {

    /// The host window the recognizer probes.
    var hostRoot: () -> UIView?
    /// Enabled AND player open AND expanded.
    var isAvailable: () -> Bool
    var smartPassthrough: Bool
    var onTranslateText: ((_ node: UIView, _ pointInNode: CGPoint) -> Void)?

    private weak var recognizer: UILongPressGestureRecognizer?

    init(hostRoot: @escaping () -> UIView?, isAvailable: @escaping () -> Bool) {
        self.hostRoot = hostRoot
        self.isAvailable = isAvailable
        self.smartPassthrough = true
    }

    /// Attach to a window (typically the host key window).
    func install(on window: UIWindow) {
        guard recognizer == nil else { return }
        let g = UILongPressGestureRecognizer(target: self, action: #selector(handle(_:)))
        g.minimumPressDuration = 0.6 // longer than the 500 ms framework default
        g.cancelsTouchesInView = false
        g.delegate = self
        window.addGestureRecognizer(g)
        recognizer = g
    }

    func uninstall() {
        if let g = recognizer { g.view?.removeGestureRecognizer(g) }
        recognizer = nil
    }

    @objc private func handle(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, isAvailable(), let host = hostRoot() else { return }
        let point = gesture.location(in: host)
        // Interactivity check is skipped — tappable text is exactly the target.
        // Use legacy capture so a tappable label (wrapped in a gesture handler)
        // still yields its text.
        guard let (node, _) = TapTargetProbe.textNode(
            at: point, in: host, smartPassthrough: false) else { return }
        let pointInNode = host.convert(point, to: node)
        onTranslateText?(node, pointInNode)
    }

    // MARK: UIGestureRecognizerDelegate

    func gestureRecognizer(_ gr: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard isAvailable(), let host = hostRoot() else { return false }
        let point = touch.location(in: host)
        // Over editable/selectable text, stay out entirely so the selection
        // toolbar (what long press means there) is left untouched.
        return !TapTargetProbe.isOverEditableOrSelectableText(at: point, in: host)
    }

    func gestureRecognizer(
        _ gr: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        true // never block the host's own gestures
    }
}
