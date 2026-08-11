// Segmentation/SegmentNormalizer.swift

import Foundation

/// Normalization applied to a segment before it leaves the SDK
/// (docs/09-sentence-segmentation.md §Normalization).
///
/// The same sentence must always produce the same request string, because that
/// string is the cache key — so whitespace collapsing here is not cosmetic.
enum SegmentNormalizer {

    /// Whitespace for normalization: space, `\n`, `\t`, `\r`, non-breaking space.
    static let whitespace: Set<Character> = [" ", "\n", "\t", "\r", "\u{00A0}"]

    /// Object-replacement character, inserted where inline non-text content sits
    /// to keep indices aligned. It MUST NOT reach the API.
    static let objectReplacement: Character = "\u{FFFC}"

    static func normalize(_ text: String) -> String {
        var out = ""
        out.reserveCapacity(text.count)
        var inWhitespaceRun = false
        for ch in text {
            let c: Character = ch == objectReplacement ? " " : ch
            if whitespace.contains(c) {
                if !inWhitespaceRun {
                    out.append(" ")
                    inWhitespaceRun = true
                }
            } else {
                out.append(c)
                inWhitespaceRun = false
            }
        }
        return out.trimmingCharacters(in: .whitespaces)
    }
}
