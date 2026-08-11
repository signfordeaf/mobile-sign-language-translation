// Model/Signer.swift

import Foundation

/// A pinnable placeholder signer (docs/10-placeholder-avatars.md). `nil` in the
/// card config means *follow the ids*; a value here pins one signer regardless.
///
/// The same four people are also the selectable **translators** — picking one is
/// what sets the `tid`/`fdid` sent to the backend (see `SignForDeafTranslator`).
public enum PlaceholderAvatar: String, CaseIterable {
    case kadir
    case hesna
    case jason
    case owais

    /// The backend id pair this translator maps to (docs/10 §"Signer identity").
    public var ids: (tid: String, fdid: String) {
        let signer = Signer.with(avatar: self)
        return (signer.tid, signer.fdid)
    }
}

/// The selectable translator. An alias of `PlaceholderAvatar` — the same four
/// bundled people — named for its role in configuration: choosing one sets the
/// `tid`/`fdid` for every request.
public typealias SignForDeafTranslator = PlaceholderAvatar

/// A bundled idle-loop signer. Each is a specific person identified on the
/// backend by a `tid`/`fdid` pair, with a bundled boomerang clip.
struct Signer: Equatable {
    let avatar: PlaceholderAvatar
    let tid: String
    let fdid: String
    /// Resource name of the bundled clip (without extension).
    let asset: String

    /// The four bundled signers (docs/10 §"Signer identity").
    static let all: [Signer] = [
        Signer(avatar: .kadir, tid: "23", fdid: "16", asset: "placeholder-kadir"),
        Signer(avatar: .hesna, tid: "43", fdid: "35", asset: "placeholder-hesna"),
        Signer(avatar: .jason, tid: "44", fdid: "36", asset: "placeholder-jason"),
        Signer(avatar: .owais, tid: "37", fdid: "29", asset: "placeholder-owais"),
    ]

    /// The stand-in used when nothing else resolves — never a bare spinner.
    static let fallback = all[1] // Hesna

    static func with(avatar: PlaceholderAvatar) -> Signer {
        all.first { $0.avatar == avatar } ?? fallback
    }

    /// URL of the bundled boomerang clip, resolved against the package bundle.
    var bundledURL: URL? {
        Bundle.module.url(forResource: asset, withExtension: "mp4", subdirectory: "videos")
            ?? Bundle.module.url(forResource: asset, withExtension: "mp4")
    }
}
