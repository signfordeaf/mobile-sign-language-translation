// Core/RequestToken.swift

import Foundation

/// A monotonic counter guarding against stale responses (docs/02-architecture.md
/// §"Translating a segment", step 1).
///
/// Each translation takes a token; every later step re-checks it and aborts
/// silently if it no longer matches. This is what stops a slow older response
/// from overwriting a newer translation. Rapid taps and fast segment navigation
/// make this routine, not exceptional.
final class RequestToken {
    private(set) var current = 0

    /// Advance and return the new token — the caller keeps this value.
    @discardableResult
    func next() -> Int {
        current += 1
        return current
    }

    /// Whether `token` is still the newest issued.
    func isCurrent(_ token: Int) -> Bool {
        token == current
    }
}
