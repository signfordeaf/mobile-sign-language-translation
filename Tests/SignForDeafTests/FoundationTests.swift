import XCTest
@testable import SignForDeaf

// MARK: - Contrast (conformance K)

final class ColorContrastTests: XCTestCase {

    func testBlackOnWhiteIsMaximum() {
        XCTAssertEqual(ColorContrast.ratio(.black, .white), 21, accuracy: 0.1)
    }

    func testColorAgainstItselfIsMinimum() {
        XCTAssertEqual(ColorContrast.ratio(.purple, .purple), 1, accuracy: 0.001)
    }

    func testRatioIsSymmetric() {
        let a = UIColor(hex: "#6750A4")!
        let b = UIColor.white
        XCTAssertEqual(ColorContrast.ratio(a, b), ColorContrast.ratio(b, a), accuracy: 0.0001)
    }

    /// Luminance-based equality, robust to the color-space of the instance the
    /// per-pair cache happens to return.
    private func assertIsWhite(_ c: UIColor, _ msg: String = "", line: UInt = #line) {
        XCTAssertEqual(ColorContrast.relativeLuminance(c), 1, accuracy: 0.001, msg, line: line)
    }
    private func assertIsBlack(_ c: UIColor, _ msg: String = "", line: UInt = #line) {
        XCTAssertEqual(ColorContrast.relativeLuminance(c), 0, accuracy: 0.001, msg, line: line)
    }

    func testPassingForegroundIsKept() {
        // White on a dark purple already passes 4.5:1 — keep it (not substituted).
        let bg = UIColor(hex: "#6750A4")!
        assertIsWhite(ColorContrast.readable(.white, on: bg))
    }

    func testFailingForegroundIsReplacedWithBetterOfBlackOrWhite() {
        // White on yellow fails; black reads better → substitute black.
        let yellow = UIColor(hex: "#FFEB3B")!
        assertIsBlack(ColorContrast.readable(.white, on: yellow))
        // Black on near-black fails; white reads better → substitute white.
        let nearBlack = UIColor(hex: "#111111")!
        assertIsWhite(ColorContrast.readable(.black, on: nearBlack))
    }

    func testDefaultThemeIsLegibleOutOfTheBox() {
        let theme = SignForDeafTheme()
        // onPrimary over primary, and text over surface, both resolve to a
        // color that passes against their background.
        XCTAssertGreaterThanOrEqual(
            ColorContrast.ratio(theme.resolvedOnPrimary, theme.primaryUIColor),
            ColorContrast.minimumRatio - 0.001)
        XCTAssertGreaterThanOrEqual(
            ColorContrast.ratio(theme.resolvedOnSurface, theme.surfaceUIColor),
            ColorContrast.minimumRatio - 0.001)
    }
}

// MARK: - Storage (docs/14)

final class StorageTests: XCTestCase {

    func testInMemoryRoundTrips() {
        let store = InMemoryStorage()
        XCTAssertNil(store.getItem(StorageKey.looping))
        store.setItem(StorageKey.looping, "true")
        XCTAssertEqual(store.getItem(StorageKey.looping), "true")
    }

    func testUserDefaultsUsesPrefix() {
        let suite = UserDefaults(suiteName: "sfd.test.\(UUID().uuidString)")!
        let store = UserDefaultsStorage(defaults: suite)
        store.setItem(StorageKey.playbackSpeed, "1.5")
        XCTAssertEqual(store.getItem(StorageKey.playbackSpeed), "1.5")
        // The raw key on disk carries the migration-safe prefix.
        XCTAssertEqual(suite.string(forKey: "weaccess_sl_playback_speed"), "1.5")
        XCTAssertNil(suite.string(forKey: "playback_speed"))
    }
}

// MARK: - SignModel lenient ids + video URL

final class SignModelV2Tests: XCTestCase {

    func testIdsParseQuotedAndUnquoted() throws {
        let quoted = """
        {"state": true, "baseUrl": "https://x/", "name": "a.mp4", "tid": "44", "fdid": "36"}
        """.data(using: .utf8)!
        let m1 = try JSONDecoder().decode(SignModel.self, from: quoted)
        XCTAssertEqual(m1.tid, "44")
        XCTAssertEqual(m1.fdid, "36")

        let unquoted = """
        {"state": true, "baseUrl": "https://x/", "name": "a.mp4", "tid": 44, "fdid": 36}
        """.data(using: .utf8)!
        let m2 = try JSONDecoder().decode(SignModel.self, from: unquoted)
        XCTAssertEqual(m2.tid, "44")
        XCTAssertEqual(m2.fdid, "36")
    }

    func testAbsentIdsAreNil() throws {
        let json = """
        {"state": true, "baseUrl": "https://x/", "name": "a.mp4"}
        """.data(using: .utf8)!
        let m = try JSONDecoder().decode(SignModel.self, from: json)
        XCTAssertNil(m.tid)
        XCTAssertNil(m.fdid)
    }

    func testVideoUrlRewritesOnlyFirstHttpScheme() {
        // Only the leading scheme is rewritten, and only once.
        let m = SignModel(
            state: true, baseUrl: "http://cdn/", name: "path/http:keep.mp4", cid: nil, st: nil)
        XCTAssertEqual(m.videoUrl, "https://cdn/path/http:keep.mp4")
    }
}

// MARK: - Signer table (conformance F, partial)

final class SignerTableTests: XCTestCase {

    func testEverySignerHasUniquePairAndAsset() {
        let pairs = Signer.all.map { "\($0.tid)/\($0.fdid)" }
        XCTAssertEqual(Set(pairs).count, Signer.all.count)
        XCTAssertTrue(Signer.all.allSatisfy { !$0.asset.isEmpty })
    }

    func testDefaultsResolveToKadir() {
        // The SDK defaults (tid 23 / fdid 16) are Kadir.
        let kadir = Signer.all.first { $0.avatar == .kadir }
        XCTAssertEqual(kadir?.tid, "23")
        XCTAssertEqual(kadir?.fdid, "16")
    }

    func testFallbackIsHesna() {
        XCTAssertEqual(Signer.fallback.avatar, .hesna)
    }
}
