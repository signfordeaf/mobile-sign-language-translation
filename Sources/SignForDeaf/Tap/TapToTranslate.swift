// Tap/TapToTranslate.swift

import UIKit
import QuartzCore

/// The tap-to-translate catcher: an overlay view that **declines during hit
/// testing** (docs/08-tap-to-translate.md §"The core constraint").
///
/// Its `hitTest(_:with:)` probes the host hierarchy and returns `self` only when
/// the point is translatable text and tap mode is on; for everything else it
/// returns `nil`, so the app's own recognizer owns the pointer from the first
/// event and the control behaves exactly as it would without the SDK.
final class SignTapCatcherView: UIView {

    /// The host app's root view to probe (the app window's root, not this overlay).
    var hostRoot: (() -> UIView?)?
    /// Whether tap mode is currently on.
    var isTapModeActive: () -> Bool = { false }
    /// `false` restores v1 capture mode.
    var smartPassthrough: Bool = true
    /// Use a control's accessibility label as a text source when its on-screen
    /// label is invisible to UIKit (SwiftUI buttons). Off by default.
    var accessibilityFallback: Bool = false
    /// Whether a long press on a labelled control runs the control instead of
    /// translating its label (docs/08 §"Long press to activate"). Off by default.
    var longPressToActivate: Bool = false {
        didSet { activateLongPress.isEnabled = longPressToActivate }
    }
    /// Called with the tapped text node and the touch point (in that node's space).
    var onTranslateText: ((_ node: UIView, _ pointInNode: CGPoint) -> Void)?
    /// Called with raw text resolved from the accessibility layer, where no
    /// `UIView` node exists (SwiftUI controls).
    var onTranslateRawText: ((_ text: String) -> Void)?

    /// How long the claim stays released over a control the SDK could not run
    /// itself, so the host receives the user's next tap.
    private let suspendDuration: CFTimeInterval = 1.8
    /// The catcher-space rect currently handed back to the host, if any.
    private var suspendedRect: CGRect?
    /// Media-time deadline after which the suspension lapses.
    private var suspendUntil: CFTimeInterval?

    private lazy var feedback = UIImpactFeedbackGenerator(style: .medium)

    private lazy var tap: UITapGestureRecognizer = {
        let g = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        g.cancelsTouchesInView = true
        return g
    }()

    /// Fires on a hold over a claimed labelled control (see `handleActivate`).
    /// Disabled until `longPressToActivate` turns it on, so translate taps are
    /// never delayed by the fail-requirement when the feature is off.
    private lazy var activateLongPress: UILongPressGestureRecognizer = {
        let g = UILongPressGestureRecognizer(target: self, action: #selector(handleActivate(_:)))
        g.minimumPressDuration = 0.5
        g.cancelsTouchesInView = true
        g.isEnabled = false
        return g
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isSignForDeafInternalUI = true
        addGestureRecognizer(tap)
        addGestureRecognizer(activateLongPress)
        // A hold activates; a quick tap translates. The tap waits for the long
        // press to fail so a hold does not also translate on release.
        tap.require(toFail: activateLongPress)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // While a control's claim is released, hand its region back to the host.
        if let until = suspendUntil {
            if CACurrentMediaTime() < until {
                if let r = suspendedRect, r.contains(point) { return nil }
            } else {
                suspendUntil = nil
                suspendedRect = nil
            }
        }
        guard isTapModeActive(), let host = hostRoot?() else { return nil }
        let hostPoint = convert(point, to: host)
        let cls = TapTargetProbe.classify(point: hostPoint, in: host,
                                          smartPassthrough: smartPassthrough,
                                          allowAccessibility: accessibilityFallback)
        switch cls {
        case .text:
            return self // claim — the tap recognizer will translate
        case .interactive, .none:
            // SwiftUI text/controls have no UIView node; find them in the
            // accessibility layer so their text can still be translated.
            if accessibilityFallback, AccessibilityProbe.hit(at: hostPoint, in: host) != nil {
                return self
            }
            return nil  // decline — the app keeps the touch
        }
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended, let host = hostRoot?() else { return }
        let hostPoint = convert(gesture.location(in: self), to: host)
        if let (node, _) = TapTargetProbe.textNode(
            at: hostPoint, in: host, smartPassthrough: smartPassthrough,
            allowAccessibility: accessibilityFallback) {
            let pointInNode = host.convert(hostPoint, to: node)
            onTranslateText?(node, pointInNode)
        } else if accessibilityFallback,
                  let match = AccessibilityProbe.hit(at: hostPoint, in: host) {
            onTranslateRawText?(match.label)
        }
    }

    /// A hold over a labelled control: run the control instead of translating.
    /// Over plain text (no control) it does nothing — a tap already translates.
    @objc private func handleActivate(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, longPressToActivate,
              isTapModeActive(), let host = hostRoot?() else { return }
        let hostPoint = convert(gesture.location(in: self), to: host)
        if let control = TapTargetProbe.interactiveControl(
            at: hostPoint, in: host, allowAccessibility: accessibilityFallback) {
            if ControlActivator.activate(control) {
                feedback.impactOccurred() // ran a UIControl in place
            } else {
                // Gesture-driven control: release the claim so the host's own hit
                // testing runs it on the user's next tap.
                suspendClaim(rect: control.convert(control.bounds, to: self))
                feedback.impactOccurred()
            }
        } else if accessibilityFallback,
                  let match = AccessibilityProbe.hit(at: hostPoint, in: host), match.isControl {
            // SwiftUI control (no UIView): release the claim over its frame so the
            // next tap runs it. Plain text carries no action, so it is ignored.
            suspendClaim(rect: host.convert(match.frame, to: self))
            feedback.impactOccurred()
        }
    }

    /// Hand `rect` (in this view's coordinates) back to the host for
    /// `suspendDuration`, so the user's next tap reaches the control.
    private func suspendClaim(rect: CGRect) {
        suspendedRect = rect
        suspendUntil = CACurrentMediaTime() + suspendDuration
    }
}
