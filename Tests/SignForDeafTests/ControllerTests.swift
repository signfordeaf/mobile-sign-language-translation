import XCTest
@testable import SignForDeaf

// MARK: - Test doubles

private final class MockTranslateService: TranslateService {
    final class Handle: TranslateCancellable {
        private(set) var isCancelled = false
        func cancel() { isCancelled = true }
    }

    /// Per-text override; falls back to a ready video with a `cid`.
    var responses: [String: TranslateOutcome] = [:]
    var defaultOutcome: TranslateOutcome = .success(
        SignModel(state: true, baseUrl: "https://v/", name: "default.mp4", cid: "c", st: nil))

    /// When true, completions are stored instead of fired, for manual control.
    var deferred = false

    private(set) var requestedTexts: [String] = []
    private(set) var handles: [Handle] = []
    private var pending: [(String, (TranslateOutcome) -> Void)] = []

    func translate(
        text: String, tid: String, fdid: String,
        completion: @escaping (TranslateOutcome) -> Void
    ) -> TranslateCancellable {
        requestedTexts.append(text)
        let handle = Handle()
        handles.append(handle)
        if deferred {
            pending.append((text, completion))
        } else {
            completion(responses[text] ?? defaultOutcome)
        }
        return handle
    }

    func fireAll() {
        let toFire = pending
        pending = []
        for (text, completion) in toFire { completion(responses[text] ?? defaultOutcome) }
    }

    func requestCount(_ text: String) -> Int { requestedTexts.filter { $0 == text }.count }
}

private func makeController(
    config: SignForDeafConfig = SignForDeafConfig(apiKey: "K", apiUrl: "https://api"),
    service: MockTranslateService
) -> (SignForDeafController, [SignForDeafEvent], SignForDeafManager, () -> [SignForDeafEvent]) {
    let manager = SignForDeafManager(config: config, storage: InMemoryStorage())
    let controller = SignForDeafController(manager: manager, service: service)
    var events: [SignForDeafEvent] = []
    controller.onEvent = { events.append($0) }
    return (controller, events, manager, { events })
}

// A valid TCKN so the sensitive guard blocks it (docs/11).
private let sensitiveText = "TC 10000000146"

// MARK: - Translation flow (conformance E)

final class ControllerFlowTests: XCTestCase {

    func testSensitiveTextBlocksAndNoRequestIsMade() {
        let service = MockTranslateService()
        let (controller, _, _, events) = makeController(service: service)
        controller.translate(sensitiveText)
        XCTAssertEqual(controller.state, .blocked)
        XCTAssertEqual(service.requestedTexts.count, 0, "no request may be made for sensitive text")
        XCTAssertEqual(events().filter { $0.type == .blockedSensitive }.count, 1)
        XCTAssertTrue(events().allSatisfy { $0.type != .translationStart })
    }

    func testEmptyTextDoesNothing() {
        let service = MockTranslateService()
        let (controller, _, _, events) = makeController(service: service)
        controller.translate("   ")
        XCTAssertEqual(controller.state, .idle)
        XCTAssertEqual(service.requestedTexts.count, 0)
        XCTAssertTrue(events().isEmpty)
    }

    func testTappedSentenceIsSelected() {
        let service = MockTranslateService()
        let (controller, _, _, _) = makeController(service: service)
        controller.setSegments(["Bir.", "İki.", "Üç."], startAt: 1)
        XCTAssertEqual(controller.currentIndex, 1)
        XCTAssertEqual(controller.currentText, "İki.")
        XCTAssertEqual(controller.state, .ready)
    }

    func testSensitiveBlocksOnlyItsOwnSentence() {
        let service = MockTranslateService()
        let (controller, _, _, _) = makeController(service: service)
        // Translating a clean sentence works even though a sibling is sensitive.
        controller.setSegments(["Merhaba dünya.", sensitiveText], startAt: 0)
        XCTAssertEqual(controller.state, .ready)
        // Moving to the sensitive one blocks only it.
        controller.nextSegment()
        XCTAssertEqual(controller.state, .blocked)
    }

    func testSameSentenceTwiceHitsApiOnce() {
        let service = MockTranslateService()
        let (controller, _, _, _) = makeController(service: service)
        controller.translate("Aynı cümle.")
        controller.translate("Aynı cümle.")
        XCTAssertEqual(service.requestCount("Aynı cümle."), 1, "a cache hit must not re-request")
    }

    func testNextSentencePrefetchedWhenCurrentResolves() {
        let service = MockTranslateService()
        let (controller, _, _, _) = makeController(service: service)
        controller.setSegments(["Birinci.", "İkinci."], startAt: 0)
        // The second sentence was prefetched and cached without being displayed.
        XCTAssertEqual(service.requestCount("İkinci."), 1)
        XCTAssertNotNil(controller.testing_cachedURL("İkinci."))
    }

    func testNoPrefetchOnLastSentence() {
        let service = MockTranslateService()
        let (controller, _, _, _) = makeController(service: service)
        controller.setSegments(["Tek cümle."], startAt: 0)
        XCTAssertEqual(service.requestedTexts, ["Tek cümle."], "no prefetch beyond the last")
    }

    func testNoPrefetchForSensitiveNext() {
        let service = MockTranslateService()
        let (controller, _, _, _) = makeController(service: service)
        controller.setSegments(["Temiz cümle.", sensitiveText], startAt: 0)
        XCTAssertEqual(service.requestCount(sensitiveText), 0, "sensitive text never reaches the network")
    }

    func testNoPrefetchForAlreadyCached() {
        let service = MockTranslateService()
        let (controller, _, _, _) = makeController(service: service)
        controller.setSegments(["A cümlesi.", "B cümlesi."], startAt: 0) // caches A, prefetches B
        controller.setSegments(["A cümlesi.", "B cümlesi."], startAt: 0) // A cache hit; B already cached
        XCTAssertEqual(service.requestCount("B cümlesi."), 1)
    }

    func testDismissClearsSegments() {
        let service = MockTranslateService()
        let (controller, _, _, _) = makeController(service: service)
        controller.setSegments(["Bir.", "İki."], startAt: 0)
        controller.closePlayer()
        XCTAssertTrue(controller.segments.isEmpty)
        XCTAssertEqual(controller.state, .idle)
    }

    func testClosingCancelsInFlightRequest() {
        let service = MockTranslateService()
        service.deferred = true
        let (controller, _, _, _) = makeController(service: service)
        controller.translate("Yükleniyor cümlesi.")
        XCTAssertEqual(controller.state, .loading)
        controller.closePlayer()
        XCTAssertTrue(service.handles.first?.isCancelled ?? false, "the in-flight request must be cancelled")
    }
}

// MARK: - Events & ids (docs/12, docs/10)

final class ControllerEventsTests: XCTestCase {

    func testExactlyOneTerminalEventPerTranslation() {
        let service = MockTranslateService()
        let (controller, _, _, events) = makeController(service: service)
        controller.translate("Bir cümle.")
        let terminals = events().filter {
            [.translationComplete, .translationError, .blockedSensitive].contains($0.type)
        }
        XCTAssertEqual(terminals.count, 1)
        XCTAssertEqual(terminals.first?.type, .translationComplete)
    }

    func testReadyEmitsPanelOpenThenVideoStartThenComplete() {
        let service = MockTranslateService()
        let (controller, _, _, events) = makeController(service: service)
        controller.translate("Bir cümle.")
        let order = events().map { $0.type }.filter {
            [.panelOpen, .videoStart, .translationComplete].contains($0)
        }
        XCTAssertEqual(order, [.panelOpen, .videoStart, .translationComplete])
    }

    func testCacheHitEmitsTextSelectedButNotTranslationStart() {
        let service = MockTranslateService()
        let (controller, _, _, events) = makeController(service: service)
        controller.translate("Tekrar cümle.") // first: real request
        let before = events().count
        controller.translate("Tekrar cümle.") // second: cache hit
        let newEvents = Array(events().dropFirst(before)).map { $0.type }
        XCTAssertTrue(newEvents.contains(.textSelected))
        XCTAssertFalse(newEvents.contains(.translationStart), "no translationStart on a cache hit")
    }

    func testCancelledEmitsTranslationErrorAndReturnsToIdle() {
        let service = MockTranslateService()
        service.responses["İptal cümle."] = .cancelled
        let (controller, _, _, events) = makeController(service: service)
        controller.translate("İptal cümle.")
        XCTAssertEqual(controller.state, .idle)
        let errors = events().filter { $0.type == .translationError }
        XCTAssertEqual(errors.first?.error?.code, .cancelled)
    }

    func testSupersededTranslationEmitsNothingFurther() {
        let service = MockTranslateService()
        service.deferred = true
        let (controller, _, _, events) = makeController(service: service)
        controller.translate("Eski cümle.")
        controller.translate("Yeni cümle.") // supersedes the first (new token)
        service.fireAll() // fires both stored completions; the stale one is ignored
        let completes = events().filter { $0.type == .translationComplete }
        XCTAssertEqual(completes.count, 1, "only the newest translation completes")
        XCTAssertEqual(completes.first?.text, "Yeni cümle.")
    }

    func testPrefetchEmitsNothing() {
        let service = MockTranslateService()
        let (controller, _, _, events) = makeController(service: service)
        controller.setSegments(["Görünen.", "Gizli prefetch."], startAt: 0)
        // No event mentions the prefetched sentence.
        XCTAssertFalse(events().contains { $0.text == "Gizli prefetch." })
    }

    func testResponseIdsAreAdoptedButPrefetchIdsAreNot() {
        let service = MockTranslateService()
        service.responses["Ana cümle."] = .success(
            SignModel(state: true, baseUrl: "https://v/", name: "a.mp4", cid: "1", st: nil,
                      tid: "44", fdid: "36"))
        service.responses["Sonraki cümle."] = .success(
            SignModel(state: true, baseUrl: "https://v/", name: "b.mp4", cid: "2", st: nil,
                      tid: "37", fdid: "29"))
        let (controller, _, manager, _) = makeController(service: service)
        controller.setSegments(["Ana cümle.", "Sonraki cümle."], startAt: 0)
        // Foreground adopted Jason's ids…
        XCTAssertEqual(manager.currentTid, "44")
        XCTAssertEqual(manager.resolvedSigner.avatar, .jason)
        // …but the prefetch's ids (Owais) were NOT adopted.
        XCTAssertNotEqual(manager.currentTid, "37")
    }

    func testVideoInitFailureBecomesError() {
        let service = MockTranslateService()
        let (controller, _, _, events) = makeController(service: service)
        controller.videoInitializer = { _, done in done(.failure(SignForDeafError(code: .videoError, message: "x"))) }
        controller.translate("Bozuk video.")
        XCTAssertEqual(controller.state, .error)
        XCTAssertEqual(events().last?.error?.code, .videoError)
    }
}

// MARK: - Preferences (conformance J, docs/14)

final class ControllerPreferencesTests: XCTestCase {

    func testStoredPreferencesRestoredBeforeRequest() {
        let storage = InMemoryStorage()
        storage.setItem(StorageKey.playbackSpeed, "1.5")
        storage.setItem(StorageKey.looping, "false")
        let manager = SignForDeafManager(
            config: SignForDeafConfig(apiKey: "K", apiUrl: "https://api"), storage: storage)
        let service = MockTranslateService()
        let controller = SignForDeafController(manager: manager, service: service)
        controller.translate("Cümle.")
        XCTAssertEqual(controller.speed, 1.5)
        XCTAssertFalse(controller.isLooping)
    }

    func testRestoreDoesNotOverrideSessionChange() {
        let storage = InMemoryStorage()
        storage.setItem(StorageKey.playbackSpeed, "2.0")
        let manager = SignForDeafManager(
            config: SignForDeafConfig(apiKey: "K", apiUrl: "https://api"), storage: storage)
        let controller = SignForDeafController(manager: manager, service: MockTranslateService())
        controller.setSpeed(1.2) // user changes speed this session
        controller.translate("Cümle.") // restore must not clobber it
        XCTAssertEqual(controller.speed, 1.2)
    }

    func testSpeedCyclesThroughConfiguredSpeeds() {
        let controller = SignForDeafController(
            manager: SignForDeafManager(
                config: SignForDeafConfig(apiKey: "K", apiUrl: "https://api"),
                storage: InMemoryStorage()),
            service: MockTranslateService())
        XCTAssertEqual(controller.speed, 1.0)
        controller.cycleSpeed(); XCTAssertEqual(controller.speed, 1.2)
        controller.cycleSpeed(); XCTAssertEqual(controller.speed, 1.5)
        controller.cycleSpeed(); XCTAssertEqual(controller.speed, 2.0)
        controller.cycleSpeed(); XCTAssertEqual(controller.speed, 1.0) // wraps
    }
}
