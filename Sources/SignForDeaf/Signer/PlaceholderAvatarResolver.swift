// Signer/PlaceholderAvatarResolver.swift

import Foundation

/// Resolves which bundled signer the idle loop shows (docs/10-placeholder-avatars.md).
///
/// A fixed default avatar once looped one person while the translation came back
/// in another's hands — two different people signing the same sentence seconds
/// apart. The idle signer therefore follows the ids in use.
enum PlaceholderAvatarResolver {

    /// Resolution order: pinned > exact pair > `tid` alone > `fdid` alone >
    /// fallback. `tid` wins over `fdid` when the two disagree, because `tid` *is*
    /// the translator. Empty strings count as absent.
    static func resolve(pinned: PlaceholderAvatar?, tid: String, fdid: String) -> Signer {
        if let pinned = pinned { return Signer.with(avatar: pinned) }

        let t = tid.trimmingCharacters(in: .whitespaces)
        let f = fdid.trimmingCharacters(in: .whitespaces)

        if !t.isEmpty, !f.isEmpty,
           let exact = Signer.all.first(where: { $0.tid == t && $0.fdid == f }) {
            return exact
        }
        if !t.isEmpty, let byTid = Signer.all.first(where: { $0.tid == t }) {
            return byTid
        }
        if !f.isEmpty, let byFdid = Signer.all.first(where: { $0.fdid == f }) {
            return byFdid
        }
        return Signer.fallback
    }
}
