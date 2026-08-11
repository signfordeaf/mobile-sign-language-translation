// Integration/SignForDeafPlacement.swift

import UIKit

/// The floating button's resting place (docs/07-floating-button.md §Placement).
///
/// Stored as an **edge plus a vertical fraction**, never absolute coordinates, so
/// a rotation or size change cannot strand the button off-screen. This lives
/// **outside** the button — the button is unmounted while the player is open, so a
/// position kept in the button's own state would die with it (the v1 bug). It
/// survives the player opening/closing and disable/enable, and resets to the
/// middle of the right edge on the next app launch (not persisted to disk).
final class SignForDeafPlacement {
    /// Which edge the button is docked to.
    var dockRight: Bool = true
    /// Position along the draggable band: 0 = top, 1 = bottom.
    var verticalFraction: CGFloat = 0.5
}
