// Tap/AccessibilityProbe.swift

import UIKit

/// Hit-tests the **accessibility** layer, reaching on-screen text and controls
/// that expose no real `UIView` (docs/08 §"SwiftUI buttons and the accessibility
/// fallback").
///
/// SwiftUI draws its `Text` and `Button` into its own layer and surfaces them
/// only as virtual accessibility elements on the hosting view — walking
/// `subviews` never finds them. This probe searches those elements by their
/// screen-space `accessibilityFrame` so any SwiftUI text can be translated (and a
/// button additionally operated with a long press). Used only when
/// `accessibilityTextFallback` is on.
enum AccessibilityProbe {

    struct Match {
        let label: String
        /// Frame in `root`'s coordinate space.
        let frame: CGRect
        /// Whether the element is an actuatable control (button/link) rather than
        /// plain text — long-press-to-activate only operates controls.
        let isControl: Bool
    }

    /// The smallest text-bearing accessibility element containing `point` (in
    /// `root` coordinates), with its label and a `root`-space frame.
    static func hit(at point: CGPoint, in root: UIView) -> Match? {
        guard let window = root.window else { return nil }
        let inWindow = root.convert(point, to: nil)
        let inScreen = window.convert(inWindow, to: nil)

        var best: (label: String, screenFrame: CGRect, isControl: Bool)?
        search(root, pointInScreen: inScreen, into: &best)

        guard let found = best else { return nil }
        let frameInWindow = window.convert(found.screenFrame, from: nil)
        let frameInRoot = root.convert(frameInWindow, from: nil)
        return Match(label: found.label, frame: frameInRoot, isControl: found.isControl)
    }

    private static func search(
        _ view: UIView, pointInScreen point: CGPoint,
        into best: inout (label: String, screenFrame: CGRect, isControl: Bool)?
    ) {
        if view.isHidden || view.alpha < 0.01 { return }
        if view.isSignForDeafInternalUI { return }

        consider(view, pointInScreen: point, into: &best)
        if let elements = view.accessibilityElements {
            for element in elements { consider(element, pointInScreen: point, into: &best) }
        }
        for sub in view.subviews {
            search(sub, pointInScreen: point, into: &best)
        }
    }

    /// Traits that mark an element as something other than translatable text —
    /// its label describes an image or a value, not words on screen.
    private static let nonTextTraits: UIAccessibilityTraits = [
        .image, .keyboardKey, .adjustable,
    ]

    /// `accessibilityFrame`/`Label`/`Traits` are declared on `NSObject` via the
    /// UIAccessibility informal protocol, so both `UIView`s and the virtual
    /// `UIAccessibilityElement`s answer them.
    private static func consider(
        _ object: Any, pointInScreen point: CGPoint,
        into best: inout (label: String, screenFrame: CGRect, isControl: Bool)?
    ) {
        guard let element = object as? NSObject else { return }
        let traits = element.accessibilityTraits
        guard traits.isDisjoint(with: nonTextTraits) else { return }
        guard let label = element.accessibilityLabel, !label.isEmpty,
              TapTargetProbe.hasTranslatableContent(label) else { return }
        let frame = element.accessibilityFrame
        guard frame.contains(point) else { return }
        // Smallest matching frame wins — the tightest element around the point.
        if best == nil || frame.area < best!.screenFrame.area {
            let isControl = traits.contains(.button) || traits.contains(.link)
            best = (label, frame, isControl)
        }
    }
}

private extension CGRect {
    var area: CGFloat { width * height }
}
