// Core/SignForDeafController.swift

import Foundation

/// All translation state and every action — the single source of truth
/// (docs/02-architecture.md). Views call actions here, this mutates state and
/// notifies, views re-render from that state. Views MUST NOT hold translation
/// state of their own.
///
/// UI-agnostic: video initialisation is delegated to `videoInitializer`, which
/// the player installs (and tests stub), so the whole state machine is testable
/// without AVFoundation.
final class SignForDeafController {

    // MARK: Collaborators

    private let manager: SignForDeafManager
    private let service: TranslateService
    private let feedback: FeedbackContactService
    private let splitter: SentenceSplitter
    private let cache = TranslationCache()
    private let requestToken = RequestToken()

    /// Installed by the player: initialise (and start) the video at `url`, then
    /// call back with success/failure. Absent → treated as an immediate success
    /// (headless/tests without a real player configure their own stub).
    var videoInitializer: ((_ url: String, _ completion: @escaping (Result<Void, Error>) -> Void) -> Void)?

    /// Observers.
    var onEvent: ((SignForDeafEvent) -> Void)?
    var onChange: (() -> Void)?

    // MARK: Observable state

    private(set) var state: SignForDeafState = .idle
    private(set) var segments: [String] = []
    private(set) var currentIndex: Int = 0
    /// The sentence being translated (the caption).
    private(set) var currentText: String?
    private(set) var videoUrl: String?
    private(set) var cid: String?

    private(set) var speed: Double
    private(set) var isLooping: Bool
    private(set) var collapsed = false

    private(set) var feedbackVote: Bool?
    private(set) var feedbackAcknowledged = false

    /// Whether the user explicitly opened the player (drives `playerVisible`).
    private(set) var isOpened = false

    // MARK: Derived flags (computed, never stored)

    /// The player was opened by the user OR the state is not idle — the second
    /// clause makes a purely programmatic `translate(...)` visible.
    var playerVisible: Bool { isOpened || state != .idle }
    var playbackAvailable: Bool { state == .ready }

    // MARK: Private

    private var foregroundRequest: TranslateCancellable?
    private var prefetching: Set<String> = []
    private var preferencesRestored = false
    private var speedChangedThisSession = false
    private var loopChangedThisSession = false

    init(
        manager: SignForDeafManager,
        service: TranslateService,
        feedback: FeedbackContactService? = nil,
        splitter: SentenceSplitter? = nil
    ) {
        self.manager = manager
        self.service = service
        self.feedback = feedback ?? FeedbackContactService(config: manager.config)
        self.splitter = splitter ?? SentenceSplitter(maxChars: manager.config.maxSegmentChars)
        self.speed = manager.config.card.defaultSpeed
        self.isLooping = manager.config.card.defaultLooping
    }

    // MARK: - Public actions

    /// Open the player (user gesture). Does not translate anything on its own.
    func openPlayer() {
        isOpened = true
        restorePreferencesIfNeeded()
        notify()
    }

    /// Translate an explicit string (programmatic path). The player becomes
    /// visible even if the host never called `openPlayer`.
    func translate(_ text: String) {
        let normalized = SegmentNormalizer.normalize(text)
        guard !normalized.isEmpty else { return }
        setSegments([normalized], startAt: 0)
    }

    /// Feed the tap layer's result: the normalized, non-empty segments of a
    /// paragraph and which one was tapped. Translates the tapped segment.
    func setSegments(_ segments: [String], startAt index: Int) {
        guard !segments.isEmpty else { return }
        self.segments = segments
        performTranslate(at: max(0, min(index, segments.count - 1)))
    }

    /// Step to the next sentence of the current paragraph, if any.
    func nextSegment() {
        guard currentIndex + 1 < segments.count else { return }
        emit(.init(type: .segmentChanged, text: segments[currentIndex + 1],
                   value: .int(currentIndex + 1)))
        performTranslate(at: currentIndex + 1)
    }

    /// Step to the previous sentence, if any.
    func previousSegment() {
        guard currentIndex - 1 >= 0 else { return }
        emit(.init(type: .segmentChanged, text: segments[currentIndex - 1],
                   value: .int(currentIndex - 1)))
        performTranslate(at: currentIndex - 1)
    }

    /// Dismiss the player. Cancels an in-flight request, releases the video, and
    /// clears segments, translation id and feedback state.
    func closePlayer() {
        let wasPlayable = playbackAvailable
        requestToken.next() // supersede anything in flight
        foregroundRequest?.cancel()
        foregroundRequest = nil
        segments = []
        currentIndex = 0
        currentText = nil
        videoUrl = nil
        cid = nil
        feedbackVote = nil
        feedbackAcknowledged = false
        isOpened = false
        collapsed = false
        state = .idle
        if wasPlayable { emit(.init(type: .panelClose)) }
        notify()
    }

    /// Clear an error/blocked state back to idle without closing the player.
    func clearError() {
        guard state == .error || state == .blocked else { return }
        state = .idle
        currentText = nil
        notify()
    }

    func setCollapsed(_ collapsed: Bool) {
        guard collapsed != self.collapsed else { return }
        self.collapsed = collapsed
        emit(.init(type: .cardCollapsed, text: currentText, value: .bool(collapsed)))
        notify()
    }

    // MARK: Playback preferences

    /// Advance the speed button through the configured cycle.
    func cycleSpeed() {
        let speeds = manager.config.card.speeds
        guard !speeds.isEmpty else { return }
        let index = speeds.firstIndex(of: speed).map { ($0 + 1) % speeds.count } ?? 0
        setSpeed(speeds[index])
    }

    func setSpeed(_ value: Double) {
        guard value > 0 else { return }
        speed = value
        speedChangedThisSession = true
        manager.storage.setItem(StorageKey.playbackSpeed, String(value))
        emit(.init(type: .playbackSpeedChanged, text: currentText, value: .double(value)))
        notify()
    }

    func toggleLoop() {
        isLooping.toggle()
        loopChangedThisSession = true
        manager.storage.setItem(StorageKey.looping, isLooping ? "true" : "false")
        notify()
    }

    // MARK: Feedback / contact

    func sendFeedback(positive: Bool) {
        guard feedbackVote == nil else { return } // one vote at a time
        feedbackVote = positive
        notify()
        feedback.sendFeedback(cid: cid, text: currentText ?? "", positive: positive) { [weak self] ok in
            self?.onMain {
                guard let self = self else { return }
                if ok {
                    self.feedbackAcknowledged = true
                    self.emit(.init(type: .feedbackSent, text: self.currentText,
                                    value: .bool(positive), cid: self.cid))
                } else {
                    self.feedbackVote = nil // roll back, emit nothing
                }
                self.notify()
            }
        }
    }

    func requestContact() {
        // Emit intent before the call, so the host learns even if it fails.
        emit(.init(type: .contactRequested, text: currentText, cid: cid))
        feedback.sendContact(cid: cid, text: currentText ?? "") { _ in }
    }

    /// Called by the player when playback reaches the end (once per run).
    func videoDidEnd() {
        emit(.init(type: .videoEnd, text: currentText, cid: cid))
    }

    // MARK: - Translation sequence (docs/02 §"Translating a segment")

    private func performTranslate(at index: Int) {
        // 1. Take a request token.
        let token = requestToken.next()
        foregroundRequest?.cancel()
        foregroundRequest = nil

        // 2. Reset per-translation state.
        cid = nil
        feedbackVote = nil
        feedbackAcknowledged = false

        // 3. Restore playback preferences (before the request).
        restorePreferencesIfNeeded()

        currentIndex = index
        let text = segments[index]
        currentText = text

        // 4. Sensitive check → blocked, nothing sent.
        if manager.isSensitive(text) {
            state = .blocked
            emit(.init(type: .blockedSensitive, text: text))
            notify()
            return
        }

        // 5. textSelected — including on a cache hit.
        emit(.init(type: .textSelected, text: text))

        // 6. Cache lookup.
        if let hit = cache.value(for: text) {
            cid = hit.cid
            state = .loading
            notify()
            startPrefetch(after: index)
            initializeVideo(hit.videoUrl, text: text, token: token) // step 9
            return
        }

        // 7. Loading + request.
        state = .loading
        emit(.init(type: .translationStart, text: text))
        notify()

        foregroundRequest = service.translate(
            text: text, tid: manager.currentTid, fdid: manager.currentFdid
        ) { [weak self] outcome in
            self?.onMain { self?.handleResponse(outcome, text: text, index: index, token: token) }
        }
    }

    // 8. Handle the response.
    private func handleResponse(
        _ outcome: TranslateOutcome, text: String, index: Int, token: Int
    ) {
        guard requestToken.isCurrent(token) else { return } // superseded → silent
        foregroundRequest = nil

        switch outcome {
        case .cancelled:
            state = .idle
            emit(.init(type: .translationError,
                       error: SignForDeafError(code: .cancelled, message: "cancelled")))
            notify()

        case .success(let model):
            // Adopt served ids before the failure check (foreground only).
            manager.adopt(tid: model.tid, fdid: model.fdid)
            guard let url = model.videoUrl else {
                state = .error
                emit(.init(type: .translationError,
                           error: SignForDeafError(code: .apiError, message: "No video in response")))
                notify()
                return
            }
            cid = model.cid
            cache.set(text, .init(videoUrl: url, cid: model.cid))
            startPrefetch(after: index)
            initializeVideo(url, text: text, token: token) // step 9

        case .failure(let error):
            state = .error
            emit(.init(type: .translationError, error: error))
            notify()
        }
    }

    // 9. Initialise the video.
    private func initializeVideo(_ url: String, text: String, token: Int) {
        let initializer = videoInitializer ?? { _, done in done(.success(())) }
        initializer(url) { [weak self] result in
            self?.onMain {
                guard let self = self, self.requestToken.isCurrent(token) else { return }
                switch result {
                case .success:
                    self.videoUrl = url
                    self.state = .ready
                    self.emit(.init(type: .panelOpen, text: text))
                    self.emit(.init(type: .videoStart, text: text, videoUrl: url, cid: self.cid))
                    self.emit(.init(type: .translationComplete, text: text, videoUrl: url, cid: self.cid))
                    self.notify()
                case .failure:
                    self.state = .error
                    self.emit(.init(type: .translationError,
                                    error: SignForDeafError(code: .videoError, message: "Video failed")))
                    self.notify()
                }
            }
        }
    }

    // MARK: Prefetch (docs/02 §Prefetch)

    /// Exactly one sentence ahead — silent: no state, token, UI, events, or id
    /// adoption. Skips cached, in-flight, sensitive, and the last sentence.
    private func startPrefetch(after index: Int) {
        let next = index + 1
        guard next < segments.count else { return }
        let text = segments[next]
        guard !cache.contains(text), !prefetching.contains(text), !manager.isSensitive(text) else { return }
        prefetching.insert(text)
        service.translate(text: text, tid: manager.currentTid, fdid: manager.currentFdid) { [weak self] outcome in
            self?.onMain {
                guard let self = self else { return }
                self.prefetching.remove(text)
                if case .success(let model) = outcome, let url = model.videoUrl {
                    self.cache.set(text, .init(videoUrl: url, cid: model.cid))
                }
            }
        }
    }

    // MARK: Preferences

    /// Restore speed/loop once per session, without overriding a preference the
    /// user already changed this session (docs/14 §Restore rules).
    private func restorePreferencesIfNeeded() {
        guard !preferencesRestored else { return }
        preferencesRestored = true
        if !speedChangedThisSession,
           let raw = manager.storage.getItem(StorageKey.playbackSpeed),
           let stored = Double(raw), stored > 0 {
            speed = stored
        }
        if !loopChangedThisSession,
           let raw = manager.storage.getItem(StorageKey.looping) {
            isLooping = (raw == "true")
        }
    }

    // MARK: Helpers

    func testing_isPrefetching(_ text: String) -> Bool { prefetching.contains(text) }
    func testing_cachedURL(_ text: String) -> String? { cache.value(for: text)?.videoUrl }

    private func emit(_ event: SignForDeafEvent) { onEvent?(event) }
    private func notify() { onChange?() }

    private func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }
}
