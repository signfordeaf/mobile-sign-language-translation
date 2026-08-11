// Core/TranslationState.swift

import Foundation

/// The translation state machine (docs/02-architecture.md §"Translation state
/// machine"). Exactly one state is active at any time.
public enum SignForDeafState: String, Equatable {
    /// Nothing in flight, nothing to play — idle signer loop, unblurred.
    case idle
    /// A translation is in flight — idle signer loop, blurred, spinner over it.
    case loading
    /// A video is playable — the translation video, controls live.
    case ready
    /// The request or the video failed — failure message inside the stage.
    case error
    /// The text was refused as sensitive — refusal message inside the stage.
    case blocked
}
