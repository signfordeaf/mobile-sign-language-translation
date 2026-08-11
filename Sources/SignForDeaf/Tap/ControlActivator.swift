// Tap/ControlActivator.swift

import UIKit

/// Runs a control's action from the SDK's overlay (docs/08 §"Long press to
/// activate").
///
/// Once the catcher has claimed a touch it cannot hand it back, so a control the
/// SDK intercepted cannot receive the original press. For a UIKit `UIControl`
/// the effect is instead **synthesised** — its target/actions are fired
/// directly. Controls that are not `UIControl` (SwiftUI, gesture-driven views)
/// cannot be triggered this way; `activate` reports that by returning `false`,
/// and the caller falls back to briefly releasing the claim so the host runs the
/// control itself.
enum ControlActivator {

    /// Fire the deepest `UIControl` at or under `node`. Returns whether a control
    /// was found and triggered.
    @discardableResult
    static func activate(_ node: UIView) -> Bool {
        guard let control = deepestControl(in: node) else { return false }
        // `.touchUpInside` is the single event that fires both wiring styles:
        // classic `addTarget(_:action:for:)` and `UIAction`/`primaryAction`
        // handlers. Sending `.primaryActionTriggered` as well would double-fire a
        // `UIAction` button, so we deliberately send only this one.
        control.sendActions(for: .touchUpInside)
        return true
    }

    /// The node itself if it is an enabled control, else the deepest enabled
    /// `UIControl` in its subtree (front-most first).
    private static func deepestControl(in view: UIView) -> UIControl? {
        if let control = view as? UIControl, control.isEnabled, control.isUserInteractionEnabled {
            return control
        }
        for sub in view.subviews.reversed() {
            if sub.isHidden || sub.alpha < 0.01 { continue }
            if let control = deepestControl(in: sub) { return control }
        }
        return nil
    }
}
