import XCTest
@testable import SignForDeaf

final class SentenceSplitterTests: XCTestCase {

    private let splitter = SentenceSplitter()

    private func segments(_ text: String) -> [String] {
        let chars = Array(text)
        return splitter.split(text).map { String(chars[$0]) }
    }

    // MARK: - Losslessness invariant (★ conformance D)

    func testRangesPartitionInputExactly() {
        let inputs = [
            "",
            "   ",
            "Merhaba dünya.",
            "Merhaba! Nasılsın? İyiyim.",
            "İlk cümle.\nİkinci cümle.",
            "T.C. Kimlik No ile A.Ş. arasında 5.000.000 TL fark var.",
            "1. Madde geçerlidir. 2. Madde de geçerlidir.",
            "Bkz. sayfa 12. Diğer bilgiler için www.ziraatbank.com.tr adresine bakın.",
            "Bir e-posta: ali@example.com yazınız.",
            "Satır sonu\nyeni satır\n\nboş satırdan sonra.",
            "Sadece bir kelime",
            "•\nMadde bir. Madde iki.",
            "Prof. Dr. Ahmet Bey geldi. Sonra gitti.",
            "Fiyat 1.299,90 TL. Kargo ücretsiz.",
            "نص عربي بدون علامات ترقيم واضحة",
        ]
        for input in inputs {
            let chars = Array(input)
            let ranges = splitter.split(input)
            // Contiguous, ordered, covering [0, count).
            if input.isEmpty {
                XCTAssertTrue(ranges.isEmpty, "empty input should yield no ranges")
                continue
            }
            XCTAssertEqual(ranges.first?.lowerBound, 0, "first range must start at 0: \(input)")
            XCTAssertEqual(ranges.last?.upperBound, chars.count, "last range must end at count: \(input)")
            for i in 1..<max(ranges.count, 1) where ranges.count > 1 {
                XCTAssertEqual(ranges[i].lowerBound, ranges[i - 1].upperBound,
                               "ranges must be contiguous: \(input)")
            }
            // Concatenation reproduces the input character for character.
            let rebuilt = ranges.map { String(chars[$0]) }.joined()
            XCTAssertEqual(rebuilt, input, "losslessness failed for: \(input)")
        }
    }

    func testEmptyYieldsNoneBlankYieldsOne() {
        XCTAssertEqual(splitter.split("").count, 0)
        XCTAssertEqual(splitter.split("   ").count, 1)
    }

    // MARK: - No split inside protected constructs

    func testNoSplitInsideInitialismsNumbersDomainEmail() {
        XCTAssertEqual(segments("T.C. kimlik numarası budur").count, 1)
        XCTAssertEqual(segments("A.Ş. unvanlı şirket").count, 1)
        XCTAssertEqual(segments("Toplam 5.000.000 lira").count, 1)
        XCTAssertEqual(segments("Site www.ziraatbank.com.tr adresinde").count, 1)
        XCTAssertEqual(segments("Mail ali@example.com adresine").count, 1)
    }

    func testClauseNumberStaysWithItsSentence() {
        let segs = segments("1. Para yatırma işlemi yapılır. 2. Para çekme işlemi yapılır.")
        XCTAssertEqual(segs.count, 2)
        XCTAssertTrue(segs[0].contains("1."))
        XCTAssertTrue(segs[1].trimmingCharacters(in: .whitespaces).hasPrefix("2."))
    }

    func testNoSplitAfterAbbreviationOrLowercaseNext() {
        // Known abbreviation.
        XCTAssertEqual(segments("Elma, armut vb. meyveler tazedir").count, 1)
        // Lowercase after a period is not a sentence start.
        XCTAssertEqual(segments("Dosya adı rapor. pdf değil").count, 1)
    }

    func testTerminatorsAndLineBreaksSplit() {
        XCTAssertEqual(segments("Merhaba! Nasılsın?").count, 2)
        XCTAssertEqual(segments("İlk satır\nİkinci satır").count, 2)
    }

    func testShortFragmentMergedIntoNeighbour() {
        // A leading bullet is not its own sentence.
        let segs = segments("• Önemli madde burada yer alır.")
        XCTAssertEqual(segs.count, 1)
    }

    func testSingleSentenceYieldsOneRange() {
        XCTAssertEqual(splitter.split("Bu tek bir cümledir.").count, 1)
    }

    // MARK: - Offset mapping

    func testOffsetMapsToSentence() {
        let text = "Birinci cümle. İkinci cümle."
        let ranges = splitter.split(text)
        let count = Array(text).count
        XCTAssertEqual(splitter.sentenceIndex(for: 2, in: ranges, count: count), 0)
        XCTAssertEqual(splitter.sentenceIndex(for: 20, in: ranges, count: count), 1)
        // Past the end clamps to the last.
        XCTAssertEqual(splitter.sentenceIndex(for: count + 5, in: ranges, count: count), ranges.count - 1)
        // Negative is "not found".
        XCTAssertNil(splitter.sentenceIndex(for: -1, in: ranges, count: count))
    }

    // MARK: - Length chunking

    func testShortTextNeverChunked() {
        // A realistic contract clause (190–250 chars) is a single segment.
        let clause = "Hesap sahibi, gerçek kişi müşterilerin bankacılık işlemlerinde kimlik "
            + "doğrulaması yapılması ve işlemlerin güvenli biçimde tamamlanması amacıyla "
            + "gerekli tüm bilgilerin doğru ve eksiksiz sunulacağını kabul eder."
        XCTAssertLessThan(clause.count, 900)
        XCTAssertEqual(splitter.split(clause).count, 1)
    }

    func testOverLimitTextChunksLosslesslyUnderLimit() {
        let sentence = "Bu cümle uzun bir metnin parçasıdır ve tekrar eder. "
        let long = String(repeating: sentence, count: 40) // well over 900 chars
        let chars = Array(long)
        let ranges = splitter.split(long)
        XCTAssertGreaterThan(ranges.count, 1)
        for r in ranges { XCTAssertLessThanOrEqual(r.count, 900) }
        XCTAssertEqual(ranges.map { String(chars[$0]) }.joined(), long)
    }

    func testPathologicalNoWhitespaceIsHardCut() {
        let blob = String(repeating: "x", count: 2500)
        let ranges = splitter.split(blob)
        XCTAssertGreaterThan(ranges.count, 1)
        for r in ranges { XCTAssertLessThanOrEqual(r.count, 900) }
        XCTAssertEqual(ranges.map { String(Array(blob)[$0]) }.joined(), blob)
    }
}
