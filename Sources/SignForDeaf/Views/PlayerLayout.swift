// Views/PlayerLayout.swift

import UIKit

/// The player sizing algorithm (docs/06-player-layout.md §"Sizing algorithm").
///
/// Normative: reproduce exactly, or the player will be proportionate on one phone
/// and oversized on another. The budget is the *whole player*, not the avatar —
/// the fixed chrome is what decides whether the player looks proportionate.
enum PlayerLayout {

    /// Aspect assumed before a video reports one — matches the bundled idle clips
    /// (900×828), so the stage keeps its size from the first idle frame through to
    /// playback.
    static let defaultAspect: CGFloat = 900.0 / 828.0

    struct Result: Equatable {
        let stage: CGSize
        /// The whole player (stage + chrome).
        let player: CGSize
        let controlBarWidthExpanded: CGFloat
        let controlBarWidthCollapsed: CGFloat
    }

    /// - Parameters:
    ///   - aspect: the video's aspect ratio (width / height), or `defaultAspect`.
    ///   - controlCount: play/pause plus each enabled optional control.
    ///   - textScale: system text scale (1.0 = default).
    static func compute(
        screenHeight: CGFloat,
        aspect: CGFloat,
        avatarHeight: CGFloat,
        avatarMaxWidth: CGFloat,
        controlCount: Int,
        textScale: CGFloat = 1.0
    ) -> Result {
        let aspect = aspect > 0 ? aspect : defaultAspect

        let pillOverflow = SignTokens.controlSize * SignTokens.pillOverflowFraction
        let captionBlockHeight = captionBlock(textScale: textScale)
        let chromeHeight = pillOverflow + SignTokens.spaceSm + SignTokens.controlSize + captionBlockHeight

        let available = screenHeight * SignTokens.maxPlayerScreenFraction - chromeHeight

        let stageHeight = min(avatarHeight, avatarMaxWidth / aspect, max(0, available))
        let stageWidth = max(stageHeight * aspect, SignTokens.minStageWidth)

        let playerHeight = pillOverflow + stageHeight + SignTokens.spaceSm
            + SignTokens.controlSize + captionBlockHeight
        // The window pill hangs above the stage's top-right corner; the player's
        // footprint width is the stage width (the pill sits within it horizontally).
        let playerWidth = stageWidth

        let barExpanded = max(stageWidth, CGFloat(max(controlCount, 1)) * SignTokens.controlSize)
        let barCollapsed = 3 * SignTokens.controlSize

        return Result(
            stage: CGSize(width: stageWidth, height: stageHeight),
            player: CGSize(width: playerWidth, height: playerHeight),
            controlBarWidthExpanded: barExpanded,
            controlBarWidthCollapsed: barCollapsed)
    }

    /// Caption block reserves two lines even before there is a caption, and grows
    /// with the *scaled* font size so raising text size grows the block instead of
    /// clipping the words.
    static func captionBlock(textScale: CGFloat) -> CGFloat {
        let scaledFont = SignTokens.captionFontSize * textScale
        return scaledFont * SignTokens.captionLineHeight * CGFloat(SignTokens.captionMaxLines)
            + SignTokens.spaceSm * 2
    }
}
