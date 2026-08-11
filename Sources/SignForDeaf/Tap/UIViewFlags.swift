// Tap/UIViewFlags.swift

import ObjectiveC
import UIKit

extension UIView {
    private static var sfdInternalKey: UInt8 = 0
    private static var sfdSensitiveKey: UInt8 = 0

    /// Marks a view (and its subtree) as SDK-owned UI, so the tap probe never
    /// claims it — otherwise tapping labels inside the player would start a new
    /// translation.
    var isSignForDeafInternalUI: Bool {
        get { objc_getAssociatedObject(self, &UIView.sfdInternalKey) as? Bool ?? false }
        set {
            objc_setAssociatedObject(
                self, &UIView.sfdInternalKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /// Marks a view (and its subtree) as containing sensitive information. Text
    /// tapped inside a marked subtree is never sent to the translation backend.
    public var isSignForDeafSensitive: Bool {
        get { objc_getAssociatedObject(self, &UIView.sfdSensitiveKey) as? Bool ?? false }
        set {
            objc_setAssociatedObject(
                self, &UIView.sfdSensitiveKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /// `true` if this view or any ancestor is marked sensitive.
    var isWithinSignForDeafSensitiveSubtree: Bool {
        var view: UIView? = self
        while let current = view {
            if current.isSignForDeafSensitive { return true }
            view = current.superview
        }
        return false
    }
}
