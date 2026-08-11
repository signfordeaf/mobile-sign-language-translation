// Views/TranslationVideoView.swift

import UIKit
import AVFoundation

/// Plays the translation video (docs/02 step 9; docs/06 §"Stage contents").
///
/// Loops **seamlessly** via `AVQueuePlayer` + `AVPlayerLooper` (the same mechanism
/// as the idle loop) so there is no freeze at the loop boundary. Exposes rate
/// (speed) and loop, reports ready/failed for the controller's video-init step,
/// and fires `onEnded` once per playback run via a boundary observer.
///
/// The asset is pre-loaded before the looper is attached: `AVPlayerLooper` plays
/// *copies* of its template item, so the template's own `status` never reaches
/// `readyToPlay` — gating readiness on it would hang the player in "loading".
final class TranslationVideoView: UIView {

    private let playerLayer = AVPlayerLayer()
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var item: AVPlayerItem?
    private var pendingAsset: AVURLAsset?
    private var endObserver: Any?
    private var loadCompletion: ((Result<Void, Error>) -> Void)?

    /// Fires once when playback reaches the end (re-armed each loop).
    var onEnded: (() -> Void)?

    private(set) var isLooping = true
    private(set) var desiredRate: Float = 1.0
    private var isPlaying = false
    private var currentURL: URL?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isSignForDeafInternalUI = true
        clipsToBounds = true
        playerLayer.videoGravity = .resizeAspect
        layer.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }

    // MARK: Load

    func load(url: String, rate: Float, looping: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        release()
        guard let parsed = URL(string: url) else {
            completion(.failure(SignForDeafError(code: .videoError, message: "Bad video URL")))
            return
        }
        desiredRate = rate
        isLooping = looping
        currentURL = parsed
        loadCompletion = completion
        prepareAsset(parsed, seekTo: .zero, autoplay: true)
    }

    /// Load the asset's `playable`/`duration` off the main thread, then attach a
    /// player once it is confirmed playable.
    private func prepareAsset(_ url: URL, seekTo time: CMTime, autoplay: Bool) {
        let asset = AVURLAsset(url: url)
        pendingAsset = asset
        asset.loadValuesAsynchronously(forKeys: ["playable", "duration"]) { [weak self] in
            DispatchQueue.main.async {
                guard let self = self, self.pendingAsset === asset else { return } // superseded
                var error: NSError?
                let playable = asset.statusOfValue(forKey: "playable", error: &error) == .loaded && asset.isPlayable
                guard playable else {
                    self.finishLoad(.failure(SignForDeafError(
                        code: .videoError, message: error?.localizedDescription ?? "not playable")))
                    return
                }
                self.attachPlayer(asset: asset, seekTo: time, autoplay: autoplay)
            }
        }
    }

    private func attachPlayer(asset: AVURLAsset, seekTo time: CMTime, autoplay: Bool) {
        let item = AVPlayerItem(asset: asset)
        self.item = item

        let player: AVQueuePlayer
        if isLooping {
            player = AVQueuePlayer()
            looper = AVPlayerLooper(player: player, templateItem: item)
        } else {
            player = AVQueuePlayer(playerItem: item)
            player.actionAtItemEnd = .pause
        }
        player.automaticallyWaitsToMinimizeStalling = true
        self.player = player
        playerLayer.player = player

        addEndBoundaryObserver()
        if time.isValid, time > .zero { player.seek(to: time) }
        finishLoad(.success(()))
        if autoplay { play() }
    }

    private func finishLoad(_ result: Result<Void, Error>) {
        guard let completion = loadCompletion else { return }
        loadCompletion = nil
        completion(result)
    }

    /// Fire `onEnded` a hair before the end of each loop.
    private func addEndBoundaryObserver() {
        guard let player = player, let item = item else { return }
        let duration = item.asset.duration
        guard duration.isValid, !duration.isIndefinite, duration.seconds > 0.1 else { return }
        let boundary = CMTimeSubtract(duration, CMTime(seconds: 0.05, preferredTimescale: 600))
        removeEndObserver()
        endObserver = player.addBoundaryTimeObserver(
            forTimes: [NSValue(time: boundary)], queue: .main
        ) { [weak self] in self?.onEnded?() }
    }

    // MARK: Playback

    func play() {
        isPlaying = true
        player?.play()
        player?.rate = desiredRate
    }

    func pause() {
        isPlaying = false
        player?.pause()
    }

    func setRate(_ rate: Float) {
        desiredRate = rate
        if isPlaying { player?.rate = rate }
    }

    /// Toggle looping — rebuilds the pipeline at the current time (rare, user action).
    func setLooping(_ looping: Bool) {
        guard looping != isLooping else { return }
        isLooping = looping
        let time = player?.currentTime() ?? .zero
        let resume = isPlaying
        guard let asset = pendingAsset else { return }
        teardownPlayer()
        attachPlayer(asset: asset, seekTo: time, autoplay: resume)
    }

    // MARK: Teardown

    private func removeEndObserver() {
        if let token = endObserver { player?.removeTimeObserver(token); endObserver = nil }
    }

    private func teardownPlayer() {
        removeEndObserver()
        looper?.disableLooping()
        looper = nil
        player?.pause()
        playerLayer.player = nil
        player = nil
        item = nil
    }

    func release() {
        teardownPlayer()
        pendingAsset = nil
        currentURL = nil
        loadCompletion = nil
        isPlaying = false
    }

    deinit { release() }
}
