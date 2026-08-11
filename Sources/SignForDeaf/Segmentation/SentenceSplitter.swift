// Segmentation/SentenceSplitter.swift

import Foundation

/// Splits text into sentence ranges (docs/09-sentence-segmentation.md).
///
/// The rules are explicit rather than delegated to an ICU/`NSLinguisticTagger`
/// sentence breaker: platform breakers disagree on exactly the constructs these
/// rules were tuned for (`T.C.`, `A.Ş.`, `5.000.000 TL`, numbered clauses), and a
/// different split changes what is sent to the backend and what the cache keys on.
///
/// Ranges are expressed over **Character indices** and partition `[0, count)`
/// exactly: concatenating `String(chars[range])` for every range reproduces the
/// input character for character (the losslessness invariant).
struct SentenceSplitter {

    let maxChars: Int

    init(maxChars: Int = 900) {
        self.maxChars = maxChars
    }

    // MARK: Character classes

    private static let terminators: Set<Character> = [".", "!", "?", "…"]
    private static let closers: Set<Character> = [")", "]", "}", "\"", "'", "»", "”", "’"]
    private static let openers: Set<Character> = ["(", "[", "{", "\"", "'", "«", "“", "‘", "-", "–", "—"]
    private static let whitespace = SegmentNormalizer.whitespace

    /// Multi-letter Turkish abbreviations (single-letter initialisms are handled
    /// structurally). Matched case-insensitively against the letter run before a period.
    private static let abbreviations: Set<String> = [
        "vb", "vs", "vd", "bkz", "örn", "age", "çev", "haz", "ed", "dr", "doç",
        "prof", "av", "sn", "bay", "bayan", "öğr", "gör", "arş", "ltd", "şti",
        "tic", "san", "md", "gen", "alb", "yzb", "ütğm", "mah", "cad", "sok",
        "apt", "blv", "no", "tel", "faks", "kat", "üniv", "fak", "böl", "ans",
        "yy", "mö", "ms",
    ]

    /// Coordinating conjunctions a length-chunk prefers to break **before**.
    private static let conjunctions: [[Character]] = [
        Array("ancak"), Array("fakat"), Array("çünkü"), Array("veya"),
        Array("ya da"), Array("ve"), Array("ise"), Array("ki"),
    ]

    // MARK: Letter helpers (docs/09 §Character helpers)

    /// A character whose lowercase and uppercase forms differ. Keeps Turkish
    /// `ı/İ`, `ş/Ş` working; uncased scripts (Arabic) contain no "letters".
    static func isLetter(_ c: Character) -> Bool {
        c.lowercased() != c.uppercased()
    }

    /// A letter equal to its own uppercase form.
    static func isUppercaseLetter(_ c: Character) -> Bool {
        isLetter(c) && String(c) == c.uppercased()
    }

    private static func isDigit(_ c: Character) -> Bool {
        c >= "0" && c <= "9"
    }

    private static func isWhitespace(_ c: Character) -> Bool {
        whitespace.contains(c)
    }

    private static func looksLikeSentenceStart(_ c: Character) -> Bool {
        isDigit(c) || openers.contains(c) || isUppercaseLetter(c)
    }

    // MARK: Public API

    /// Split into sentence ranges. Empty input → no ranges; blank input → one.
    func split(_ text: String) -> [Range<Int>] {
        let chars = Array(text)
        guard !chars.isEmpty else { return [] }
        let boundaries = detectBoundaries(chars)
        let ranges = ranges(from: boundaries, count: chars.count)
        let merged = mergeShortFragments(ranges, chars)
        return chunkAll(merged, chars)
    }

    /// Paragraph granularity: the whole text as one segment, only length-chunked
    /// (sentence boundaries ignored, the limit still respected).
    func lengthChunks(_ text: String) -> [Range<Int>] {
        let chars = Array(text)
        guard !chars.isEmpty else { return [] }
        return chunk(0..<chars.count, chars)
    }

    /// Index of the range containing `offset` (`start ≤ offset < end`). A tap
    /// past the last character belongs to the last sentence; a negative offset
    /// (or an empty range list) is "not found".
    func sentenceIndex(for offset: Int, in ranges: [Range<Int>], count: Int) -> Int? {
        guard offset >= 0, !ranges.isEmpty else { return nil }
        if offset >= count { return ranges.count - 1 }
        for (i, r) in ranges.enumerated() where r.contains(offset) { return i }
        return nil
    }

    // MARK: Boundary detection

    /// Start indices of each new segment (excluding 0), in order.
    private func detectBoundaries(_ chars: [Character]) -> [Int] {
        let n = chars.count
        var cuts: [Int] = []
        var segStart = 0
        var i = 0
        while i < n {
            let c = chars[i]
            if c == "\n" {
                // Hard line break: always a boundary. The `\n` is trailing
                // whitespace of the preceding segment; the next starts after it.
                if i + 1 < n {
                    cuts.append(i + 1)
                    segStart = i + 1
                }
                i += 1
                continue
            }
            if Self.terminators.contains(c), genuinelyEndsSentence(chars, i, segStart: segStart) {
                // Skip a run of closing punctuation.
                var j = i + 1
                while j < n, Self.closers.contains(chars[j]) { j += 1 }
                // What follows the closers must be whitespace (and there must be more text).
                if j < n, Self.isWhitespace(chars[j]) {
                    var k = j
                    while k < n, Self.isWhitespace(chars[k]) { k += 1 }
                    if k < n, Self.looksLikeSentenceStart(chars[k]) {
                        cuts.append(k)
                        segStart = k
                        i = k
                        continue
                    }
                }
            }
            i += 1
        }
        return cuts
    }

    /// Whether a `.` (or other terminator) at `i` genuinely ends a sentence.
    private func genuinelyEndsSentence(_ chars: [Character], _ i: Int, segStart: Int) -> Bool {
        let c = chars[i]
        // `!`, `?`, `…` are unambiguous.
        if c != "." { return true }
        let n = chars.count

        // 1. Decimal / thousands separator: a digit on both sides.
        if i > 0, i + 1 < n, Self.isDigit(chars[i - 1]), Self.isDigit(chars[i + 1]) {
            return false
        }

        // Collect the contiguous letter run immediately before the period.
        var p = i - 1
        while p >= 0, Self.isLetter(chars[p]) { p -= 1 }
        let letterRun = Array(chars[(p + 1)..<i]) // may be empty

        // 2. Initialism: a lone uppercase letter, with a non-letter before it.
        if letterRun.count == 1, Self.isUppercaseLetter(letterRun[0]) {
            let before = i - 2
            if before < 0 || !Self.isLetter(chars[before]) { return false }
        }

        // 3. Known abbreviation.
        if !letterRun.isEmpty {
            let word = String(letterRun).lowercased()
            if Self.abbreviations.contains(word) { return false }
        }

        // 4. List marker: only digits/periods precede it, and everything from the
        //    start of the current segment up to that number is whitespace.
        var q = i - 1
        var sawDigit = false
        while q >= segStart, Self.isDigit(chars[q]) || chars[q] == "." {
            if Self.isDigit(chars[q]) { sawDigit = true }
            q -= 1
        }
        if sawDigit, q < i - 1 {
            var allWhitespace = true
            var r = segStart
            while r <= q { if !Self.isWhitespace(chars[r]) { allWhitespace = false; break }; r += 1 }
            if allWhitespace { return false }
        }

        return true
    }

    private func ranges(from cuts: [Int], count: Int) -> [Range<Int>] {
        var result: [Range<Int>] = []
        var start = 0
        for cut in cuts {
            result.append(start..<cut)
            start = cut
        }
        result.append(start..<count)
        return result
    }

    // MARK: Merge short fragments

    private func casedLetterCount(_ chars: ArraySlice<Character>) -> Int {
        chars.reduce(0) { $0 + (Self.isLetter($1) ? 1 : 0) }
    }

    /// A segment with fewer than 2 cased letters is merged into a neighbour
    /// (forward first; a too-short final tail is appended to the previous one).
    private func mergeShortFragments(_ ranges: [Range<Int>], _ chars: [Character]) -> [Range<Int>] {
        guard ranges.count > 1 else { return ranges }
        var merged: [Range<Int>] = []
        var i = 0
        while i < ranges.count {
            var r = ranges[i]
            while casedLetterCount(chars[r]) < 2, i + 1 < ranges.count {
                i += 1
                r = r.lowerBound..<ranges[i].upperBound
            }
            if casedLetterCount(chars[r]) < 2, let last = merged.last {
                merged.removeLast()
                r = last.lowerBound..<r.upperBound
            }
            merged.append(r)
            i += 1
        }
        return merged
    }

    // MARK: Length chunking

    private func chunkAll(_ ranges: [Range<Int>], _ chars: [Character]) -> [Range<Int>] {
        var out: [Range<Int>] = []
        for r in ranges { out.append(contentsOf: chunk(r, chars)) }
        return out
    }

    private func chunk(_ range: Range<Int>, _ chars: [Character]) -> [Range<Int>] {
        if range.count <= maxChars { return [range] }
        let cut = chunkCut(range, chars)
        return chunk(range.lowerBound..<cut, chars) + chunk(cut..<range.upperBound, chars)
    }

    /// The cut index for an over-long range: the boundary closest to the middle,
    /// taking the first kind that has any candidates.
    private func chunkCut(_ range: Range<Int>, _ chars: [Character]) -> Int {
        let start = range.lowerBound, end = range.upperBound
        let mid = (start + end) / 2

        func closest(_ candidates: [Int]) -> Int? {
            candidates.min(by: { abs($0 - mid) < abs($1 - mid) })
        }

        // 1. Punctuation: after , ; : — – (or a `-` preceded by whitespace) when
        //    whitespace follows; the cut lands after that whitespace.
        var punctuation: [Int] = []
        // 3. Word boundary: after any whitespace run.
        var wordBoundaries: [Int] = []
        var t = start
        while t < end - 1 {
            let c = chars[t]
            let punct = c == "," || c == ";" || c == ":" || c == "—" || c == "–"
                || (c == "-" && t > start && Self.isWhitespace(chars[t - 1]))
            if punct, t + 1 < end, Self.isWhitespace(chars[t + 1]) {
                var k = t + 1
                while k < end, Self.isWhitespace(chars[k]) { k += 1 }
                if k > start, k < end { punctuation.append(k) }
            }
            if Self.isWhitespace(c) {
                var k = t
                while k < end, Self.isWhitespace(chars[k]) { k += 1 }
                if k > start, k < end { wordBoundaries.append(k) }
                t = k
                continue
            }
            t += 1
        }
        if let c = closest(punctuation) { return c }

        // 2. Coordinating conjunction: immediately before one, as a whole word.
        var conjunctionCuts: [Int] = []
        for pos in start..<end {
            let atWordStart = pos == start || Self.isWhitespace(chars[pos - 1])
            guard atWordStart, pos > start else { continue }
            for conj in Self.conjunctions where matchesWord(conj, at: pos, in: chars, end: end) {
                conjunctionCuts.append(pos)
                break
            }
        }
        if let c = closest(conjunctionCuts) { return c }

        if let c = closest(wordBoundaries) { return c }

        // 4. Hard cut — no usable boundary at all.
        return start + maxChars
    }

    private func matchesWord(_ word: [Character], at pos: Int, in chars: [Character], end: Int) -> Bool {
        guard pos + word.count <= end else { return false }
        for (offset, wc) in word.enumerated() where chars[pos + offset].lowercased() != wc.lowercased() {
            return false
        }
        // Must be a whole word: end at whitespace or range end.
        let after = pos + word.count
        return after == end || Self.isWhitespace(chars[after])
    }
}
