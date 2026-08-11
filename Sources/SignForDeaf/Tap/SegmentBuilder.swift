// Tap/SegmentBuilder.swift

import Foundation

/// Turns a classified text node into the segments the controller translates
/// (docs/08-tap-to-translate.md §"From tap to segments").
///
/// The reported list is never empty and the index always points inside it. The
/// worst case is always the v1 behavior (translate the whole paragraph), never a
/// failure.
enum SegmentBuilder {

    struct Result: Equatable {
        /// Normalized, non-empty segments to translate.
        let segments: [String]
        /// Index of the tapped one.
        let index: Int
    }

    /// - Parameters:
    ///   - nodeText: the raw text of the tapped node.
    ///   - tapOffset: character index under the finger in `nodeText`, or `nil`
    ///     when the touch could not be mapped (→ whole-paragraph fallback).
    static func build(
        nodeText: String,
        tapOffset: Int?,
        granularity: SignForDeafGranularity,
        splitter: SentenceSplitter
    ) -> Result? {
        let whole = SegmentNormalizer.normalize(nodeText)
        guard !whole.isEmpty else { return nil }

        let chars = Array(nodeText)

        switch granularity {
        case .paragraph:
            let ranges = splitter.lengthChunks(nodeText)
            let segs = ranges
                .map { SegmentNormalizer.normalize(String(chars[$0])) }
                .filter { !$0.isEmpty }
            return Result(segments: segs.isEmpty ? [whole] : segs, index: 0)

        case .sentence:
            let ranges = splitter.split(nodeText)
            // A single sentence, or a tap we could not place, falls back to the
            // whole paragraph — exactly the v1 behavior.
            guard ranges.count > 1,
                  let offset = tapOffset,
                  let rawIndex = splitter.sentenceIndex(for: offset, in: ranges, count: chars.count)
            else {
                return Result(segments: [whole], index: 0)
            }

            // Drop segments that normalize to nothing, keeping their original index
            // so the reported target still points at the tapped sentence.
            var kept: [(orig: Int, text: String)] = []
            for (i, r) in ranges.enumerated() {
                let s = SegmentNormalizer.normalize(String(chars[r]))
                if !s.isEmpty { kept.append((i, s)) }
            }
            guard kept.count > 1 else {
                return Result(segments: [kept.first?.text ?? whole], index: 0)
            }
            let target = kept.firstIndex { $0.orig == rawIndex }
                ?? kept.lastIndex { $0.orig < rawIndex }
                ?? 0
            return Result(segments: kept.map { $0.text }, index: target)
        }
    }
}
