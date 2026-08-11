import XCTest
@testable import SignForDeaf

final class SegmentBuilderTests: XCTestCase {

    private let splitter = SentenceSplitter()

    // MARK: Sentence granularity

    func testTappedSentenceIsSelectedWithAllReported() {
        let text = "Birinci cümle. İkinci cümle. Üçüncü cümle."
        // Offset inside the second sentence.
        let offset = Array(text).firstIndex(of: "İ")! + 2
        let result = SegmentBuilder.build(
            nodeText: text, tapOffset: offset, granularity: .sentence, splitter: splitter)
        XCTAssertEqual(result?.segments.count, 3)
        XCTAssertEqual(result?.segments[result!.index], "İkinci cümle.")
    }

    func testNoOffsetFallsBackToWholeParagraph() {
        let text = "Birinci cümle. İkinci cümle."
        let result = SegmentBuilder.build(
            nodeText: text, tapOffset: nil, granularity: .sentence, splitter: splitter)
        XCTAssertEqual(result?.segments, ["Birinci cümle. İkinci cümle."])
        XCTAssertEqual(result?.index, 0)
    }

    func testSingleSentenceIsOneSegment() {
        let result = SegmentBuilder.build(
            nodeText: "Sadece bir cümle var.", tapOffset: 3, granularity: .sentence, splitter: splitter)
        XCTAssertEqual(result?.segments.count, 1)
    }

    func testEmptyTextYieldsNil() {
        XCTAssertNil(SegmentBuilder.build(
            nodeText: "   ", tapOffset: 0, granularity: .sentence, splitter: splitter))
    }

    func testSegmentsAreNormalizedForSending() {
        // Whitespace runs and object-replacement chars collapse in the sent
        // segment (a `\n` is a hard boundary, so this stays within one sentence).
        let text = "Birinci\u{FFFC}   cümle çok   uzundur. İkinci cümle."
        let result = SegmentBuilder.build(
            nodeText: text, tapOffset: 0, granularity: .sentence, splitter: splitter)
        XCTAssertEqual(result?.segments.first, "Birinci cümle çok uzundur.")
    }

    // MARK: Paragraph granularity

    func testParagraphGranularityIsOneSegmentWhenShort() {
        let text = "Birinci cümle. İkinci cümle."
        let result = SegmentBuilder.build(
            nodeText: text, tapOffset: 3, granularity: .paragraph, splitter: splitter)
        XCTAssertEqual(result?.segments, ["Birinci cümle. İkinci cümle."])
        XCTAssertEqual(result?.index, 0)
    }
}

final class BundledClipTests: XCTestCase {

    func testAllFourSignersHaveALoadableClip() {
        for signer in Signer.all {
            XCTAssertNotNil(signer.bundledURL, "missing bundled clip for \(signer.avatar)")
        }
    }
}
