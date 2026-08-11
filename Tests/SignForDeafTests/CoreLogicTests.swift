import XCTest
@testable import SignForDeaf

// MARK: - Placeholder avatar resolution (conformance F)

final class PlaceholderAvatarResolverTests: XCTestCase {

    func testMatchedPairResolvesToSigner() {
        XCTAssertEqual(PlaceholderAvatarResolver.resolve(pinned: nil, tid: "44", fdid: "36").avatar, .jason)
    }

    func testEitherIdAloneResolves() {
        XCTAssertEqual(PlaceholderAvatarResolver.resolve(pinned: nil, tid: "37", fdid: "").avatar, .owais)
        XCTAssertEqual(PlaceholderAvatarResolver.resolve(pinned: nil, tid: "", fdid: "35").avatar, .hesna)
    }

    func testTidWinsWhenIdsDisagree() {
        // tid → Jason (44), fdid → Kadir (16). tid is the translator, so Jason.
        XCTAssertEqual(PlaceholderAvatarResolver.resolve(pinned: nil, tid: "44", fdid: "16").avatar, .jason)
    }

    func testUnknownOrAbsentResolvesToFallbackNotSpinner() {
        XCTAssertEqual(PlaceholderAvatarResolver.resolve(pinned: nil, tid: "999", fdid: "999").avatar, .hesna)
        XCTAssertEqual(PlaceholderAvatarResolver.resolve(pinned: nil, tid: "", fdid: "").avatar, .hesna)
        XCTAssertEqual(PlaceholderAvatarResolver.resolve(pinned: nil, tid: "  ", fdid: "  ").avatar, .hesna)
    }

    func testPinnedOverridesIds() {
        XCTAssertEqual(PlaceholderAvatarResolver.resolve(pinned: .owais, tid: "23", fdid: "16").avatar, .owais)
    }

    func testDefaultsResolveToKadir() {
        XCTAssertEqual(PlaceholderAvatarResolver.resolve(pinned: nil, tid: "23", fdid: "16").avatar, .kadir)
    }
}

// MARK: - Translator selection → effective ids

final class TranslatorSelectionTests: XCTestCase {

    private func config(translator: SignForDeafTranslator = .hesna,
                        tid: String? = nil, fdid: String? = nil) -> SignForDeafConfig {
        SignForDeafConfig(apiKey: "K", apiUrl: "https://x",
                          translator: translator, fdid: fdid, tid: tid)
    }

    func testEachTranslatorMapsToItsIds() {
        XCTAssertEqual(SignForDeafTranslator.kadir.ids.tid, "23")
        XCTAssertEqual(SignForDeafTranslator.kadir.ids.fdid, "16")
        XCTAssertEqual(SignForDeafTranslator.hesna.ids.tid, "43")
        XCTAssertEqual(SignForDeafTranslator.hesna.ids.fdid, "35")
        XCTAssertEqual(SignForDeafTranslator.jason.ids.tid, "44")
        XCTAssertEqual(SignForDeafTranslator.owais.ids.fdid, "29")
    }

    func testDefaultTranslatorIsHesna() {
        let c = config()
        XCTAssertEqual(c.translator, .hesna)
        XCTAssertEqual(c.effectiveTid, "43")
        XCTAssertEqual(c.effectiveFdid, "35")
    }

    func testTranslatorDrivesEffectiveIds() {
        let c = config(translator: .owais)
        XCTAssertEqual(c.effectiveTid, "37")
        XCTAssertEqual(c.effectiveFdid, "29")
    }

    func testExplicitIdsOverrideTranslator() {
        let c = config(translator: .hesna, tid: "44", fdid: "36")
        XCTAssertEqual(c.effectiveTid, "44")   // override wins over Hesna
        XCTAssertEqual(c.effectiveFdid, "36")
    }

    func testPartialOverrideMixesWithTranslator() {
        let c = config(translator: .kadir, tid: "99", fdid: nil)
        XCTAssertEqual(c.effectiveTid, "99")   // overridden
        XCTAssertEqual(c.effectiveFdid, "16")  // Kadir's fdid
    }

    func testEmptyOverrideFallsBackToTranslator() {
        let c = config(translator: .jason, tid: "   ", fdid: "")
        XCTAssertEqual(c.effectiveTid, "44")
        XCTAssertEqual(c.effectiveFdid, "36")
    }

    func testManagerStartsFromEffectiveIdsAndAdoptStillOverrides() {
        let manager = SignForDeafManager(config: config(translator: .hesna),
                                         storage: InMemoryStorage())
        XCTAssertEqual(manager.currentTid, "43")
        XCTAssertEqual(manager.resolvedSigner.avatar, .hesna)
        // Backend adopts Jason mid-session → shown signer follows.
        XCTAssertTrue(manager.adopt(tid: "44", fdid: "36"))
        XCTAssertEqual(manager.resolvedSigner.avatar, .jason)
    }

    func testBackendAdoptionIsTopAuthorityOverPin() {
        // A pinned avatar holds before any API response…
        let cfg = SignForDeafConfig(apiKey: "K", apiUrl: "https://x",
                                    translator: .owais,
                                    card: SignForDeafCardConfig(placeholderAvatar: .kadir))
        let manager = SignForDeafManager(config: cfg, storage: InMemoryStorage())
        XCTAssertEqual(manager.resolvedSigner.avatar, .kadir)
        // …but once the backend adopts a signer, the pin can no longer override.
        XCTAssertTrue(manager.adopt(tid: "43", fdid: "35"))
        XCTAssertEqual(manager.resolvedSigner.avatar, .hesna)
    }
}

// MARK: - Translation cache

final class TranslationCacheTests: XCTestCase {

    func testStoresAndReads() {
        let cache = TranslationCache()
        XCTAssertNil(cache.value(for: "hello"))
        cache.set("hello", .init(videoUrl: "https://v/1.mp4", cid: "9"))
        XCTAssertEqual(cache.value(for: "hello")?.videoUrl, "https://v/1.mp4")
        XCTAssertEqual(cache.value(for: "hello")?.cid, "9")
    }

    func testEvictsOldestBeyondLimit() {
        let cache = TranslationCache(limit: 3)
        for i in 1...4 { cache.set("k\(i)", .init(videoUrl: "u\(i)", cid: nil)) }
        XCTAssertNil(cache.value(for: "k1"), "oldest should be evicted")
        XCTAssertNotNil(cache.value(for: "k4"))
        XCTAssertEqual(cache.count, 3)
    }

    func testReinsertMovesToNewest() {
        let cache = TranslationCache(limit: 3)
        cache.set("a", .init(videoUrl: "a1", cid: nil))
        cache.set("b", .init(videoUrl: "b1", cid: nil))
        cache.set("c", .init(videoUrl: "c1", cid: nil))
        cache.set("a", .init(videoUrl: "a2", cid: nil)) // a becomes newest
        cache.set("d", .init(videoUrl: "d1", cid: nil)) // evicts b (now oldest)
        XCTAssertNil(cache.value(for: "b"))
        XCTAssertEqual(cache.value(for: "a")?.videoUrl, "a2")
        XCTAssertNotNil(cache.value(for: "d"))
    }
}

// MARK: - Request token

final class RequestTokenTests: XCTestCase {

    func testMonotonicAndSupersede() {
        let token = RequestToken()
        let first = token.next()
        XCTAssertTrue(token.isCurrent(first))
        let second = token.next()
        XCTAssertTrue(token.isCurrent(second))
        XCTAssertFalse(token.isCurrent(first), "an older token is superseded")
    }
}

// MARK: - Segment normalization (conformance D, normalization)

final class SegmentNormalizerTests: XCTestCase {

    func testCollapsesWhitespaceAndStripsObjectReplacement() {
        let input = "Merhaba\u{FFFC}\n\t  dünya\u{00A0}nasılsın   "
        XCTAssertEqual(SegmentNormalizer.normalize(input), "Merhaba dünya nasılsın")
    }

    func testTrimsAndCollapsesSoftWraps() {
        XCTAssertEqual(SegmentNormalizer.normalize("  bir\niki   üç  "), "bir iki üç")
    }
}
