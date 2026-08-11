// Service/FeedbackContactService.swift

import Foundation

/// `/Feedback` and `/Contact` — not yet live (docs/03-api-contract.md).
///
/// The 👍/👎 and contact affordances are fully implemented in the UI and the
/// event flow, but the endpoints are stubbed: a build-time flag says whether they
/// point at a real backend. While it is off, the SDK skips the network call and
/// reports success, so the UI and events still behave correctly end to end.
///
/// Both calls MUST swallow every failure — feedback is a side channel and may
/// never disturb playback.
final class FeedbackContactService {

    /// Flip to `true` (and fill the request builders) when the endpoints go live.
    static let endpointsConfigured = false

    static let feedbackPath = "/Feedback"
    static let contactPath = "/Contact"
    static let positiveVote = "1"
    static let negativeVote = "0"

    private let config: SignForDeafConfig

    init(config: SignForDeafConfig) {
        self.config = config
    }

    /// Records a vote. Reports success optimistically while the endpoint is off.
    func sendFeedback(cid: String?, text: String, positive: Bool, completion: @escaping (Bool) -> Void) {
        guard Self.endpointsConfigured else { completion(true); return }
        // Real network wiring goes here when the endpoint is live; any failure
        // must be swallowed (completion(false)).
        completion(true)
    }

    /// Requests contact. Reports success optimistically while the endpoint is off.
    func sendContact(cid: String?, text: String, completion: @escaping (Bool) -> Void) {
        guard Self.endpointsConfigured else { completion(true); return }
        completion(true)
    }
}
