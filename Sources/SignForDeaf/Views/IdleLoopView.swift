// Views/IdleLoopView.swift

import UIKit
import AVFoundation

/// The idle signer loop with its loading veil (docs/10-placeholder-avatars.md).
///
/// Plays a looping, muted clip. While a translation is in flight the loop is
/// blurred with a spinner over it (the veil); idle it plays clean, so it never
/// promises a video that is not coming. If the clip cannot be played it falls
/// back silently — spinner alone while loading, the SDK mark while idle.
final class IdleLoopView: UIView {

    private var queuePlayer: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private let playerLayer = AVPlayerLayer()

    private let veil = UIVisualEffectView(effect: nil)
    private let spinner = SignSpinner()
    private let markView = LogoView()

    private var hasVideo = false
    private var isLoading = false
    private var primaryColor: UIColor = SignForDeafTheme.defaultPrimary

    override init(frame: CGRect) {
        super.init(frame: frame)
        isSignForDeafInternalUI = true
        clipsToBounds = true

        playerLayer.videoGravity = .resizeAspect
        layer.addSublayer(playerLayer)

        veil.isHidden = true
        veil.isUserInteractionEnabled = false
        addSubview(veil)

        spinner.isHidden = true
        addSubview(spinner)

        markView.isHidden = true
        markView.isUserInteractionEnabled = false
        addSubview(markView)

        updateVeil()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
        veil.frame = bounds
        let s = SignTokens.loadingIndicatorSize
        spinner.frame = CGRect(x: (bounds.width - s) / 2, y: (bounds.height - s) / 2, width: s, height: s)
        let m: CGFloat = 32
        markView.frame = CGRect(x: (bounds.width - m) / 2, y: (bounds.height - m) / 2, width: m, height: m)
    }

    /// Point the loop at a signer's clip (or a host-supplied asset). `nil` URL —
    /// e.g. `placeholderAsset == ""` — means no video: plain spinner / mark.
    func configure(url: URL?, primaryColor: UIColor) {
        self.primaryColor = primaryColor
        spinner.color = primaryColor
        markView.logoColor = primaryColor.withAlphaComponent(0.35)

        releasePlayer()
        guard let url = url else {
            hasVideo = false
            updateVeil()
            return
        }
        let item = AVPlayerItem(url: url)
        let player = AVQueuePlayer()
        player.isMuted = true
        player.actionAtItemEnd = .advance
        looper = AVPlayerLooper(player: player, templateItem: item)
        playerLayer.player = player
        queuePlayer = player
        hasVideo = true
        player.play()
        updateVeil()
    }

    /// Blur + spinner on, only while loading (never for a blocked/idle stage).
    func setLoading(_ loading: Bool) {
        isLoading = loading
        updateVeil()
    }

    func play() { queuePlayer?.play() }
    func pause() { queuePlayer?.pause() }

    func releasePlayer() {
        queuePlayer?.pause()
        looper?.disableLooping()
        looper = nil
        queuePlayer = nil
        playerLayer.player = nil
    }

    private func updateVeil() {
        if hasVideo {
            markView.isHidden = true
            // A light blur: the clean `.regular` blur at half alpha, so the sharp
            // signer still reads through it (a soft focus, not a heavy blur or a
            // flat dim).
            veil.isHidden = !isLoading
            veil.effect = isLoading ? UIBlurEffect(style: .regular) : nil
            veil.alpha = 0.5
            spinner.isHidden = !isLoading
        } else {
            // Fallback: spinner alone while loading, the SDK mark while idle.
            veil.isHidden = true
            spinner.isHidden = !isLoading
            markView.isHidden = isLoading
        }
        if !spinner.isHidden { spinner.startAnimating() }
        bringSubviewToFront(veil)
        bringSubviewToFront(spinner)
    }

    deinit { releasePlayer() }
}
