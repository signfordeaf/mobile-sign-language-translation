// Events/SignForDeafEvent.swift

import Foundation

/// Error codes carried on `translationError` (docs/12-events-and-errors.md).
public enum SignForDeafErrorCode: String {
    /// The request threw — transport failure, timeout.
    case networkError
    /// The response arrived without a usable video, including after polling was exhausted.
    case apiError
    /// The video URL could not be initialised or played.
    case videoError
    /// Reserved; not currently raised.
    case configurationError
    /// The request was cancelled by the user or superseded.
    case cancelled
    /// Reserved; not currently raised.
    case unknown
}

/// A translation error. The message is for logs only — the player always shows
/// the localized generic failure string, never this message.
public struct SignForDeafError: Error {
    public let code: SignForDeafErrorCode
    public let message: String

    public init(code: SignForDeafErrorCode, message: String) {
        self.code = code
        self.message = message
    }
}

/// The lifecycle events the SDK exposes (docs/12-events-and-errors.md). Events
/// are observational — nothing in the SDK depends on a host consuming them.
public enum SignForDeafEventType: String {
    /// The segment was refused before any request (sensitive).
    case blockedSensitive
    /// A segment passed the sensitive check and is about to be translated —
    /// including on a cache hit.
    case textSelected
    /// A network request is actually being made. Not emitted on a cache hit.
    case translationStart
    /// The request was cancelled, failed, or the video could not be initialised.
    case translationError
    /// A video became playable.
    case panelOpen
    /// Playback started.
    case videoStart
    /// The translation is done and playing.
    case translationComplete
    /// Playback reached the end.
    case videoEnd
    /// The user moved to another sentence of the paragraph. `value` = new index.
    case segmentChanged
    /// The speed changed. `value` = new speed.
    case playbackSpeedChanged
    /// The player was collapsed or expanded. `value` = collapsed flag.
    case cardCollapsed
    /// A 👍/👎 was accepted. `value` = positive flag.
    case feedbackSent
    /// The contact button was pressed.
    case contactRequested
    /// The player was dismissed while a translation was playable.
    case panelClose
}

/// The free-form `value` payload carried by the v2 events.
public enum SignForDeafEventValue: Equatable {
    case int(Int)
    case double(Double)
    case bool(Bool)
}

/// One lifecycle event.
public struct SignForDeafEvent {
    public let type: SignForDeafEventType
    /// Text of the segment, on the text-related events.
    public let text: String?
    /// Present on `translationComplete` / `videoStart`.
    public let videoUrl: String?
    /// Present on `translationError`.
    public let error: SignForDeafError?
    /// The free-form value carried by the v2 events.
    public let value: SignForDeafEventValue?
    /// The translation id, whenever one is known.
    public let cid: String?
    /// Emission time.
    public let timestamp: Date

    public init(
        type: SignForDeafEventType,
        text: String? = nil,
        videoUrl: String? = nil,
        error: SignForDeafError? = nil,
        value: SignForDeafEventValue? = nil,
        cid: String? = nil,
        timestamp: Date = Date()
    ) {
        self.type = type
        self.text = text
        self.videoUrl = videoUrl
        self.error = error
        self.value = value
        self.cid = cid
        self.timestamp = timestamp
    }
}
