// Core/SignForDeafManager.swift

import Foundation

/// The process-global configuration authority (docs/02-architecture.md
/// §"Configuration is process-global").
///
/// Holds the resolved settings and the *currently effective* ids. `tid`/`fdid`
/// can be overridden by the backend mid-session, and every later request must use
/// the corrected pair, wherever it originates — so this state is shared, not
/// per-player.
final class SignForDeafManager {

    /// Shared instance the integration layer installs (`configure`). Tests build
    /// their own instances directly.
    static var shared: SignForDeafManager?

    private(set) var config: SignForDeafConfig
    private(set) var currentTid: String
    private(set) var currentFdid: String
    /// Whether the backend has adopted a signer this session. Once it has, the
    /// backend is the top authority: the idle avatar follows the adopted ids and
    /// the configured pin (`placeholderAvatar`) can no longer override it.
    private(set) var didAdoptFromBackend = false
    let storage: SignForDeafStorage

    /// Fired when the resolved signer changes (an id was adopted), so the idle
    /// loop updates without waiting for the next state change.
    var onSignerChanged: (() -> Void)?

    init(config: SignForDeafConfig, storage: SignForDeafStorage) {
        self.config = config
        self.currentTid = config.effectiveTid
        self.currentFdid = config.effectiveFdid
        self.storage = storage
    }

    /// Re-apply configuration at runtime; resets the effective ids to the new
    /// config's pair.
    func update(config: SignForDeafConfig) {
        self.config = config
        self.currentTid = config.effectiveTid
        self.currentFdid = config.effectiveFdid
        // A deliberate reconfigure starts fresh — the pin applies again until the
        // backend adopts a signer.
        self.didAdoptFromBackend = false
    }

    /// Adopt backend-served ids. Absent, empty and unchanged values change
    /// nothing; either id may be present without the other. Returns whether
    /// anything changed, and notifies on change.
    @discardableResult
    func adopt(tid: String?, fdid: String?) -> Bool {
        var changed = false
        if let t = tid?.trimmingCharacters(in: .whitespaces), !t.isEmpty, t != currentTid {
            currentTid = t
            changed = true
        }
        if let f = fdid?.trimmingCharacters(in: .whitespaces), !f.isEmpty, f != currentFdid {
            currentFdid = f
            changed = true
        }
        if changed {
            didAdoptFromBackend = true
            onSignerChanged?()
        }
        return changed
    }

    /// The idle-loop signer for the ids currently in effect. The backend is the
    /// top authority: once it has adopted a signer, the configured pin is ignored
    /// so nothing overrides the API's choice.
    var resolvedSigner: Signer {
        PlaceholderAvatarResolver.resolve(
            pinned: didAdoptFromBackend ? nil : config.card.placeholderAvatar,
            tid: currentTid, fdid: currentFdid)
    }

    /// Whether a segment must be refused before any request (docs/11).
    func isSensitive(_ text: String) -> Bool {
        guard config.sensitiveFilteringEnabled else { return false }
        return SensitiveDataGuard.isSensitive(text, extraPatterns: config.compiledSensitivePatterns)
    }
}
