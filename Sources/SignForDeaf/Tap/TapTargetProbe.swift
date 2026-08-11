// Tap/TapTargetProbe.swift

import UIKit

/// The classification of a touch point (docs/08-tap-to-translate.md §Classification).
enum TapClassification: Equatable {
    /// Plain text, including the label of a control — the SDK claims and translates.
    case text(String)
    /// A control with no text of its own, or an editable field — handed to the app.
    case interactive
    /// Empty space, an image, a decoration — handed to the app.
    case none
}

/// Classifies a touch position against the host view hierarchy, so the SDK can
/// **decline during hit testing** rather than claim-then-ignore (docs/08).
///
/// The walk is deepest-first: the label inside a button is found before the
/// button, so a labelled control reads while an unlabelled one operates.
enum TapTargetProbe {

    /// Classify `point` (in `root`'s coordinate space). With `smartPassthrough`
    /// off, restores v1 capture mode: return the deepest text regardless of
    /// interactivity.
    ///
    /// The whole containing subtree is searched (not a single hit path), so a text
    /// node sitting *behind* a transparent overlay is still found — SwiftUI and
    /// many UIKit layouts place drawing/gesture views over their text.
    static func classify(point: CGPoint, in root: UIView, smartPassthrough: Bool,
                         allowAccessibility: Bool = false) -> TapClassification {
        let hit = probe(point: point, in: root, allowAccessibility: allowAccessibility)
        if hit.overInternalUI { return .none }

        if !smartPassthrough {
            return hit.text.map { .text($0.text) } ?? .none
        }
        if let text = hit.text, hit.interactiveDepth == nil || text.depth >= hit.interactiveDepth! {
            // A control's own label is deeper than the control → text wins.
            return .text(text.text)
        }
        if hit.interactiveDepth != nil { return .interactive }
        return .none
    }

    /// The text node that would be translated for a tap at `point`, with its text.
    static func textNode(at point: CGPoint, in root: UIView, smartPassthrough: Bool,
                         allowAccessibility: Bool = false)
        -> (view: UIView, text: String)? {
        guard case .text = classify(point: point, in: root, smartPassthrough: smartPassthrough,
                                    allowAccessibility: allowAccessibility) else {
            return nil
        }
        guard let text = probe(point: point, in: root, allowAccessibility: allowAccessibility).text
        else { return nil }
        return (text.view, text.text)
    }

    /// The interactive control under `point` when the point sits over a *labelled*
    /// control — one whose own text label wins classification (`.text`) yet which
    /// has an interactive node at or above the label's depth. `nil` for plain
    /// text, editable fields, icon/unlabelled controls, or empty space.
    ///
    /// Long-press-to-activate operates exactly this case: the label that a tap
    /// would translate, so the control can be run without collapsing the player.
    static func interactiveControl(at point: CGPoint, in root: UIView,
                                   allowAccessibility: Bool = false) -> UIView? {
        guard case .text = classify(point: point, in: root, smartPassthrough: true,
                                    allowAccessibility: allowAccessibility) else {
            return nil
        }
        let hit = probe(point: point, in: root, allowAccessibility: allowAccessibility)
        if let interactive = hit.interactive?.view { return interactive }
        // A SwiftUI-style control with no UIKit interactivity: the classified text
        // node is itself the control (accessibility button), so a long press can
        // release the claim over it.
        if allowAccessibility, let text = hit.text?.view, isAccessibilityControl(text) {
            return text
        }
        return nil
    }

    // MARK: Subtree probe

    private struct ProbeResult {
        var text: (view: UIView, text: String, depth: Int)?
        var interactive: (view: UIView, depth: Int)?
        var overInternalUI = false

        var interactiveDepth: Int? { interactive?.depth }
    }

    /// Walk the whole subtree, recording the deepest text node and the deepest
    /// non-ambient interactive control containing the point.
    private static func probe(point: CGPoint, in root: UIView,
                              allowAccessibility: Bool = false) -> ProbeResult {
        var result = ProbeResult()
        let rootArea = max(root.bounds.width * root.bounds.height, 1)
        walk(root, pointInView: point, depth: 0, rootArea: rootArea,
             allowAccessibility: allowAccessibility, into: &result)
        return result
    }

    private static func walk(
        _ view: UIView, pointInView: CGPoint, depth: Int, rootArea: CGFloat,
        allowAccessibility: Bool, into result: inout ProbeResult
    ) {
        if view.isHidden || view.alpha < 0.01 { return }
        guard view.bounds.contains(pointInView) else { return }

        if view.isSignForDeafInternalUI { result.overInternalUI = true }

        if let t = extractText(view, allowAccessibility: allowAccessibility), hasTranslatableContent(t) {
            if result.text == nil || depth > result.text!.depth {
                result.text = (view, t, depth)
            }
        }
        if isInteractiveOrEditable(view), !isAmbient(view, rootArea: rootArea) {
            if result.interactive == nil || depth > result.interactive!.depth {
                result.interactive = (view, depth)
            }
        }
        for sub in view.subviews {
            walk(sub, pointInView: view.convert(pointInView, to: sub),
                 depth: depth + 1, rootArea: rootArea,
                 allowAccessibility: allowAccessibility, into: &result)
        }
    }

    private static func isInteractiveOrEditable(_ view: UIView) -> Bool {
        if isEditable(view) { return true }
        return isInteractive(view)
    }

    /// Whether the point sits over an editable or selectable text field — where a
    /// long press must stay out of the competition so the selection toolbar works.
    static func isOverEditableOrSelectableText(at point: CGPoint, in root: UIView) -> Bool {
        var node: UIView? = deepestView(at: point, in: root)
        while let view = node {
            if view is UITextField { return true }
            if let tv = view as? UITextView, tv.isEditable || tv.isSelectable { return true }
            if view === root { break }
            node = view.superview
        }
        return false
    }

    // MARK: Hierarchy walk

    /// The deepest, front-most subview containing `point`, ignoring
    /// `isUserInteractionEnabled` (a plain `UILabel` has it off, so `hitTest`
    /// would skip exactly the text we want).
    static func deepestView(at point: CGPoint, in view: UIView) -> UIView {
        for sub in view.subviews.reversed() {
            if sub.isHidden || sub.alpha < 0.01 { continue }
            let p = view.convert(point, to: sub)
            if sub.bounds.contains(p) {
                return deepestView(at: p, in: sub)
            }
        }
        return view
    }

    // MARK: Classification helpers

    private static func isEditable(_ view: UIView) -> Bool {
        if view is UITextField { return true }
        if let tv = view as? UITextView { return tv.isEditable }
        return false
    }

    private static func isInteractive(_ view: UIView) -> Bool {
        if view is UIControl { return true }
        if let recognizers = view.gestureRecognizers {
            for gr in recognizers where gr.isEnabled {
                if gr is UITapGestureRecognizer || gr is UILongPressGestureRecognizer { return true }
            }
        }
        return false
    }

    /// A gesture handler covering ≥80% of the probed area is ambient (e.g. a
    /// whole-page "dismiss the keyboard" wrapper) and is skipped.
    private static func isAmbient(_ view: UIView, rootArea: CGFloat) -> Bool {
        let area = view.bounds.width * view.bounds.height
        return area >= 0.8 * rootArea
    }

    /// The displayed text of a text node.
    ///
    /// Reads on-screen text first — `UILabel`, read-only `UITextView`, and a
    /// `UIButton`'s title (including the iOS 15+ `configuration.title`, which
    /// does not surface as a `titleLabel`). A `UIButton` with no title is an icon
    /// button and yields `nil` so it keeps operating on tap.
    ///
    /// `allowAccessibility` adds a last-resort fallback for controls whose label
    /// UIKit hit testing cannot see — SwiftUI buttons render their text outside
    /// the `UILabel` world — by reading the control's accessibility label. It is
    /// off by default because an accessibility label can differ from the on-screen
    /// text (an icon button labelled "Close"); hosts opt in via
    /// `accessibilityTextFallback`.
    static func extractText(_ view: UIView, allowAccessibility: Bool = false) -> String? {
        if let label = view as? UILabel {
            return label.attributedText?.string ?? label.text
        }
        if let tv = view as? UITextView, !tv.isEditable {
            return tv.text
        }
        if let button = view as? UIButton {
            if let t = button.configuration?.title, !t.isEmpty { return t }
            if let t = button.titleLabel?.text, !t.isEmpty { return t }
            if let t = button.title(for: .normal), !t.isEmpty { return t }
            return nil // icon button — operate it, don't translate
        }
        if allowAccessibility, isAccessibilityControl(view),
           let label = view.accessibilityLabel, !label.isEmpty {
            return label
        }
        return nil
    }

    /// A control the accessibility layer describes even when it exposes no UIKit
    /// interactivity — a SwiftUI button hit-tests itself and carries no
    /// `UIGestureRecognizer`, but it is marked with the `.button` (or `.link`)
    /// accessibility trait. Plain text (`.staticText`) is deliberately excluded.
    static func isAccessibilityControl(_ view: UIView) -> Bool {
        if isInteractive(view) { return true }
        let traits = view.accessibilityTraits
        return traits.contains(.button) || traits.contains(.link)
    }

    /// A text candidate is accepted only if it contains at least one character
    /// that is neither whitespace nor in a private use area — icons draw glyphs
    /// from PUA codepoints and must not be mistaken for text.
    static func hasTranslatableContent(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            let v = scalar.value
            let isWhitespace = v == 0x20 || v == 0x09 || v == 0x0A || v == 0x0D
            let isPUA = (0xE000...0xF8FF).contains(v)
                || (0xF0000...0xFFFFD).contains(v)
                || (0x100000...0x10FFFD).contains(v)
            if !isWhitespace && !isPUA { return true }
        }
        return false
    }

    private static func isInternalUI(_ view: UIView) -> Bool {
        view.isSignForDeafInternalUI
    }
}
