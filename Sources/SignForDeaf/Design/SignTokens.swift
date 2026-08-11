// Design/SignTokens.swift

import UIKit

/// Fixed design tokens for the SDK's own surfaces (docs/05-design-tokens.md).
///
/// Brand colors are **not** tokens — they come from the integration's theme so
/// each app keeps its palette. Everything here is fixed so the player, control
/// bar, pills and hint bubble read as one system across platforms. All sizes are
/// in points.
enum SignTokens {

    // MARK: Radii

    /// Stage and control-bar outer radius (overridable via theme `cornerRadius`).
    static let radiusLarge: CGFloat = 16
    /// Action pills — feedback, collapse/close.
    static let radiusMedium: CGFloat = 12
    /// Speed button, hint bubble, logo badge.
    static let radiusSmall: CGFloat = 8

    // MARK: Spacing

    static let spaceXs: CGFloat = 4
    static let spaceSm: CGFloat = 8
    static let spaceMd: CGFloat = 12
    static let spaceLg: CGFloat = 16
    static let spaceXl: CGFloat = 24

    // MARK: Sizes

    /// Tap target of every control and pill button (also the a11y minimum).
    static let controlSize: CGFloat = 44
    /// Icon inside a control.
    static let iconSize: CGFloat = 20
    /// Play/pause glyph, and the mark in the collapsed bar.
    static let primaryIconSize: CGFloat = 24
    /// How much of the window pill hangs above the stage.
    static let pillOverflowFraction: CGFloat = 0.8
    /// Narrowest the stage may get: 3×44 + 8 = 140.
    static let minStageWidth: CGFloat = 3 * 44 + 8
    /// Share of screen height the whole player may occupy.
    static let maxPlayerScreenFraction: CGFloat = 0.42

    // MARK: Loading

    /// Gaussian blur over the idle avatar while a translation is in flight.
    static let loadingBlurSigma: CGFloat = 2.5
    /// Spinner diameter over the blurred avatar.
    static let loadingIndicatorSize: CGFloat = 24

    // MARK: Caption

    static let captionFontSize: CGFloat = 12
    static let captionLineHeight: CGFloat = 1.35
    static let captionMaxLines: Int = 2

    // MARK: Motion (seconds)

    static let cardTransition: TimeInterval = 0.320
    static let collapseTransition: TimeInterval = 0.260
    static let snapTransition: TimeInterval = 0.300

    // MARK: Elevation

    /// Under the stage and control bar: #000 @ 12%, offset (0,2), blur 12.
    static let floatingShadowColor = UIColor.black
    static let floatingShadowOpacity: Float = 0.12
    static let floatingShadowOffset = CGSize(width: 0, height: 2)
    static let floatingShadowRadius: CGFloat = 12

    /// Under pills laid on top, and under the floating button: #000 @ 15%, offset (0,2), blur 6.
    static let pillShadowColor = UIColor.black
    static let pillShadowOpacity: Float = 0.15
    static let pillShadowOffset = CGSize(width: 0, height: 2)
    static let pillShadowRadius: CGFloat = 6

    // MARK: Neutral overlays (intentionally not themeable)

    /// Tap-to-translate hint bubble background: #000 @ 80%.
    static let hintBackground = UIColor.black.withAlphaComponent(0.8)
    /// Hint bubble text.
    static let hintForeground = UIColor.white
    /// Fill behind the speed button, over the primary bar: #FFF @ 12%.
    static let controlFill = UIColor.white.withAlphaComponent(0.12)
    /// Speed button border: #FFF @ 35%.
    static let controlBorder = UIColor.white.withAlphaComponent(0.35)
    /// Any control that is currently unavailable.
    static let disabledOpacity: CGFloat = 0.4
}
