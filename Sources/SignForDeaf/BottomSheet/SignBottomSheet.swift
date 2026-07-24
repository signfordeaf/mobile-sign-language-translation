// BottomSheet/SignBottomSheet.swift

import AVKit
import UIKit

/// Half-screen sheet that plays the sign language video for a piece of text.
/// Ported from the RN library's `SignLanguageBottomSheet`, minus React.
final class SignBottomSheet: UIViewController {

    // MARK: - Layout Constants

    /// Corner radius shared by the card's top and the system sheet container so
    /// their rounded top corners line up exactly (no gray gap at the corners).
    static let cardCornerRadius: CGFloat = 20

    /// Side margin (left and right) of the floating card on notched devices.
    static let floatingSideMargin: CGFloat = 8

    /// Corner radius (all four corners) of the floating card on notched devices.
    static let floatingCornerRadius: CGFloat = 32

    /// Height of the card's content from its top down to the bottom of the text
    /// label (plus its 12pt padding), used to size the compact detent so the
    /// sheet fits its content instead of the taller system `.medium()`. The
    /// bottom safe-area inset is added on top at presentation time so the card
    /// reaches flush to the screen bottom while the text clears the home
    /// indicator. Sum of the vertical layout chain in `setupConstraints()`.
    static let contentHeight: CGFloat = 431

    // MARK: - Properties

    private var videoURL: String = ""
    private var displayText: String = ""
    private var displayTitle: String = "Engelsiz Çeviri"
    private var strings: LocalizedStrings = LocalizedStrings.turkish
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var isLoading: Bool = true

    /// When `true`, the sheet opens directly in the "sensitive content blocked"
    /// state: no loading, no video, no retry — just `blockedMessage`.
    private var isBlocked: Bool = false
    private var blockedMessage: String = ""

    /// `true` on notched devices → the card floats with small side/bottom
    /// margins and all corners rounded. `false` on home-button devices → the
    /// card is flush to the bottom edge with only its top corners rounded.
    private var isFloating: Bool = false

    /// Bottom safe-area inset of the presenter, added to the card height so its
    /// content clears the home indicator while the card stays flush.
    private var bottomSafeInset: CGFloat = 0

    var onDismiss: (() -> Void)?
    var onRetry: (() -> Void)?
    /// Fired once loading resolves — either the video is ready to play or an
    /// error occurred. Used to dismiss the external loading overlay.
    var onLoadingFinished: (() -> Void)?

    // MARK: - Theme Colors

    private var themePrimaryColor: UIColor = SignForDeafTheme.defaultPrimary
    private var themeTextColor: UIColor = SignForDeafTheme.defaultText

    // MARK: - UI Components

    /// Full-screen dimming backdrop behind the card (we present over the full
    /// screen ourselves rather than via `UISheetPresentationController`, whose
    /// opaque container can't be made transparent).
    private lazy var dimmingView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    /// The visible card that holds all content. It is pinned flush to the bottom
    /// and sized to its content, so it reads as a short bottom sheet.
    private lazy var cardView: UIView = {
        let v = UIView()
        v.backgroundColor = .white
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var headerView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var grabberView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.lightGray.withAlphaComponent(0.5)
        view.layer.cornerRadius = 2.5
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var logoImageView: LogoView = {
        let view = LogoView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        return view
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .bold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)
        button.setImage(UIImage(systemName: "xmark", withConfiguration: config), for: .normal)
        button.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var videoContainerView: UIView = {
        let view = UIView()
        // White (not black): the sign-language videos are shot on white, and
        // with aspect-fit the container's margins blend into the white sheet
        // instead of showing black letterbox bars.
        view.backgroundColor = .white
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
        return view
    }()

    private lazy var textLabel: MarqueeLabel = {
        let label = MarqueeLabel()
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    private lazy var errorView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var errorLabel: UILabel = {
        let label = UILabel()
        label.textColor = .darkGray  // readable on the white video container
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var retryButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        button.addTarget(self, action: #selector(retryButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - Lifecycle

    private var didAnimateIn = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.isSignForDeafInternalUI = true  // exclude from tap-to-translate scanning
        setupUI()
        applyThemeColors()
        setupAccessibility()
        // Start hidden; animated in on first appearance.
        dimmingView.alpha = 0
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !didAnimateIn {
            // Park the card just below the screen so it can slide up.
            cardView.transform = CGAffineTransform(
                translationX: 0, y: UIScreen.main.bounds.height)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didAnimateIn else { return }
        didAnimateIn = true
        UIView.animate(
            withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.9,
            initialSpringVelocity: 0, options: [.curveEaseOut]
        ) {
            self.dimmingView.alpha = 1
            self.cardView.transform = .identity
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = videoContainerView.bounds

        // Round the card: the floating card rounds all four corners; the flush
        // card rounds only its top corners.
        applyCardMask()
    }

    /// Reveal the card with a bottom-to-top slide. Used when the sheet was kept
    /// hidden behind the loading overlay: once loading resolves we want the user
    /// to actually see the sheet enter from the bottom rather than pop into
    /// place.
    func revealWithSlideUp() {
        view.alpha = 1
        // Park the card below the screen, then spring it up.
        cardView.transform = CGAffineTransform(
            translationX: 0,
            y: cardView.bounds.height + bottomSafeInset + SignBottomSheet.floatingSideMargin)
        UIView.animate(
            withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.9,
            initialSpringVelocity: 0, options: [.curveEaseOut]
        ) {
            self.cardView.transform = .identity
        }
    }

    /// Slide the card down and fade the backdrop out, then dismiss.
    private func animateOutAndDismiss() {
        UIView.animate(
            withDuration: 0.25, delay: 0, options: [.curveEaseIn]
        ) {
            self.dimmingView.alpha = 0
            // Slide the card fully below the screen (covers the floating
            // card's bottom gap too).
            self.cardView.transform = CGAffineTransform(
                translationX: 0,
                y: self.cardView.bounds.height + self.bottomSafeInset
                    + SignBottomSheet.floatingSideMargin)
        } completion: { _ in
            self.dismiss(animated: false)
        }
    }

    /// Masks the card with a rounded-rect path. The floating card uses
    /// `floatingCornerRadius` on all four corners; the flush card uses
    /// `cardCornerRadius` on top and square (0) on the bottom.
    private func applyCardMask() {
        let bounds = cardView.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }

        let topR =
            isFloating
            ? SignBottomSheet.floatingCornerRadius : SignBottomSheet.cardCornerRadius
        let bottomR = isFloating ? SignBottomSheet.floatingCornerRadius : 0

        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: topR))
        path.addArc(
            withCenter: CGPoint(x: topR, y: topR), radius: topR,
            startAngle: .pi, endAngle: .pi * 1.5, clockwise: true)
        path.addLine(to: CGPoint(x: bounds.width - topR, y: 0))
        path.addArc(
            withCenter: CGPoint(x: bounds.width - topR, y: topR), radius: topR,
            startAngle: .pi * 1.5, endAngle: 0, clockwise: true)
        path.addLine(to: CGPoint(x: bounds.width, y: bounds.height - bottomR))
        if bottomR > 0 {
            path.addArc(
                withCenter: CGPoint(x: bounds.width - bottomR, y: bounds.height - bottomR),
                radius: bottomR, startAngle: 0, endAngle: .pi * 0.5, clockwise: true)
        }
        path.addLine(to: CGPoint(x: bottomR, y: bounds.height))
        if bottomR > 0 {
            path.addArc(
                withCenter: CGPoint(x: bottomR, y: bounds.height - bottomR),
                radius: bottomR, startAngle: .pi * 0.5, endAngle: .pi, clockwise: true)
        }
        path.close()

        let mask = CAShapeLayer()
        mask.path = path.cgPath
        cardView.layer.mask = mask
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        player?.pause()

        if isBeingDismissed {
            onDismiss?()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        player?.currentItem?.removeObserver(self, forKeyPath: "status")
    }

    // MARK: - Configuration

    func configure(
        videoURL: String = "",
        text: String,
        title: String,
        strings: LocalizedStrings,
        primaryColor: UIColor,
        textColor: UIColor,
        isFloating: Bool,
        bottomSafeInset: CGFloat
    ) {
        self.videoURL = videoURL
        self.displayText = text
        self.displayTitle = title
        self.strings = strings
        self.isLoading = videoURL.isEmpty
        self.themePrimaryColor = primaryColor
        self.themeTextColor = textColor
        self.isFloating = isFloating
        self.bottomSafeInset = bottomSafeInset
    }

    /// Swap the loading state for a real video once the URL is ready.
    func updateVideoURL(_ url: String) {
        self.videoURL = url
        self.isLoading = false
        if isViewLoaded {
            setupVideoPlayer()
        }
    }

    /// Show the error/retry state (e.g. when translation failed).
    func showTranslationError() {
        self.isLoading = false
        if isViewLoaded {
            showError()
        }
    }

    // MARK: - Setup

    private func applyThemeColors() {
        logoImageView.logoColor = themePrimaryColor
        titleLabel.textColor = themePrimaryColor
        // The translated text under the video uses the theme's primary color.
        textLabel.textColor = themePrimaryColor
        closeButton.tintColor = themePrimaryColor
        loadingIndicator.color = themePrimaryColor
        retryButton.backgroundColor = themePrimaryColor
    }

    private func setupUI() {
        // We present over the full screen and draw our own dimming backdrop.
        view.backgroundColor = .clear

        let backdropTap = UITapGestureRecognizer(
            target: self, action: #selector(backdropTapped(_:)))
        backdropTap.cancelsTouchesInView = false  // don't swallow card button taps
        dimmingView.addGestureRecognizer(backdropTap)

        view.addSubview(dimmingView)
        view.addSubview(cardView)

        cardView.addSubview(grabberView)

        cardView.addSubview(headerView)
        headerView.addSubview(logoImageView)
        headerView.addSubview(titleLabel)
        headerView.addSubview(closeButton)

        cardView.addSubview(videoContainerView)
        videoContainerView.addSubview(loadingIndicator)

        videoContainerView.addSubview(errorView)
        errorView.addSubview(errorLabel)
        errorView.addSubview(retryButton)

        cardView.addSubview(textLabel)

        titleLabel.text = displayTitle
        textLabel.text = displayText
        errorLabel.text = strings.videoLoadError
        retryButton.setTitle(strings.retry, for: .normal)
        closeButton.accessibilityLabel = strings.close
        closeButton.accessibilityHint = strings.closeHint

        setupConstraints()

        if isBlocked {
            showBlocked()
        } else if isLoading {
            loadingIndicator.startAnimating()
        } else {
            setupVideoPlayer()
        }
    }

    private func setupConstraints() {
        // The sheet is presented full-height over the whole screen, but its
        // container is transparent — only this content-sized `cardView` is
        // opaque, so it reads as a short bottom sheet.
        //
        // - Notched (isFloating): the card floats with small side margins and
        //   its bottom pinned to the safe area — i.e. it ends just above the
        //   home indicator (which sits in the gap below). All corners are
        //   rounded, and because the card clears the device's rounded screen
        //   corners its bottom corners show their full radius (unclipped).
        // - Home-button: the card is flush to the bottom (full width), and the
        //   extra `bottomSafeInset` height lets its text clear the home area.
        let sideMargin = isFloating ? SignBottomSheet.floatingSideMargin : 0
        let cardHeight =
            isFloating
            ? SignBottomSheet.contentHeight
            : SignBottomSheet.contentHeight + bottomSafeInset
        let cardBottom =
            isFloating
            ? cardView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
            : cardView.bottomAnchor.constraint(equalTo: view.bottomAnchor)

        NSLayoutConstraint.activate([
            // Dimming backdrop — full screen
            dimmingView.topAnchor.constraint(equalTo: view.topAnchor),
            dimmingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimmingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Card
            cardView.heightAnchor.constraint(equalToConstant: cardHeight),
            cardView.leadingAnchor.constraint(
                equalTo: view.leadingAnchor, constant: sideMargin),
            cardView.trailingAnchor.constraint(
                equalTo: view.trailingAnchor, constant: -sideMargin),
            cardBottom,

            // Grabber
            grabberView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 8),
            grabberView.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            grabberView.widthAnchor.constraint(equalToConstant: 40),
            grabberView.heightAnchor.constraint(equalToConstant: 5),

            // Header
            headerView.topAnchor.constraint(equalTo: grabberView.bottomAnchor, constant: 8),
            headerView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 50),

            // Logo
            logoImageView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            logoImageView.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 30),
            logoImageView.heightAnchor.constraint(equalToConstant: 30),

            // Title
            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            // Close Button
            closeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            closeButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),

            // Video Container
            videoContainerView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 12),
            videoContainerView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            videoContainerView.trailingAnchor.constraint(
                equalTo: cardView.trailingAnchor, constant: -16),
            videoContainerView.bottomAnchor.constraint(equalTo: textLabel.topAnchor, constant: -12),

            // Loading Indicator
            loadingIndicator.centerXAnchor.constraint(equalTo: videoContainerView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: videoContainerView.centerYAnchor),

            // Error View
            errorView.centerXAnchor.constraint(equalTo: videoContainerView.centerXAnchor),
            errorView.centerYAnchor.constraint(equalTo: videoContainerView.centerYAnchor),
            errorView.widthAnchor.constraint(equalToConstant: 220),

            errorLabel.topAnchor.constraint(equalTo: errorView.topAnchor),
            errorLabel.leadingAnchor.constraint(equalTo: errorView.leadingAnchor),
            errorLabel.trailingAnchor.constraint(equalTo: errorView.trailingAnchor),

            retryButton.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 12),
            retryButton.centerXAnchor.constraint(equalTo: errorView.centerXAnchor),
            retryButton.widthAnchor.constraint(equalToConstant: 140),
            retryButton.heightAnchor.constraint(equalToConstant: 36),
            retryButton.bottomAnchor.constraint(equalTo: errorView.bottomAnchor),

            // Text Label — pinned to the safe area so it clears the home indicator.
            textLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            textLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            textLabel.bottomAnchor.constraint(
                equalTo: cardView.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            textLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 30),
        ])
    }

    private func setupVideoPlayer() {
        // Tear down any previous player (e.g. on retry).
        NotificationCenter.default.removeObserver(self)
        player?.currentItem?.removeObserver(self, forKeyPath: "status")
        playerLayer?.removeFromSuperlayer()

        guard let url = URL(string: videoURL) else {
            showError()
            return
        }

        loadingIndicator.startAnimating()
        errorView.isHidden = true

        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.videoGravity = .resizeAspect
        playerLayer?.frame = videoContainerView.bounds
        // Keep the video hidden (spinner over the white container) until the
        // player is actually ready to play, so no black/blank frame flashes.
        playerLayer?.isHidden = true

        if let playerLayer = playerLayer {
            videoContainerView.layer.insertSublayer(playerLayer, at: 0)
        }

        player?.currentItem?.addObserver(self, forKeyPath: "status", options: [.new], context: nil)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFailToPlay(_:)),
            name: .AVPlayerItemFailedToPlayToEndTime,
            object: player?.currentItem
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem
        )

        player?.play()

        // If the item is already ready (e.g. cached), the KVO `.new` change may
        // not fire — reveal it right away in that case.
        if playerItem.status == .readyToPlay {
            revealVideo()
        }
    }

    /// Reveal the video and stop the spinner — the "ready to play" moment.
    private func revealVideo() {
        loadingIndicator.stopAnimating()
        playerLayer?.isHidden = false
        onLoadingFinished?()
    }

    @objc private func playerDidFailToPlay(_ notification: Notification) {
        showError()
    }

    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        if keyPath == "status", let item = object as? AVPlayerItem {
            DispatchQueue.main.async { [weak self] in
                switch item.status {
                case .readyToPlay:
                    self?.revealVideo()
                case .failed:
                    self?.loadingIndicator.stopAnimating()
                    self?.showError()
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        }
    }

    private func setupAccessibility() {
        view.accessibilityViewIsModal = true
        videoContainerView.isAccessibilityElement = true
        videoContainerView.accessibilityLabel = strings.videoPlayerLabel
        videoContainerView.accessibilityTraits = .playsSound

        UIAccessibility.post(notification: .announcement, argument: strings.translationReady)
    }

    // MARK: - Actions

    @objc private func closeButtonTapped() {
        animateOutAndDismiss()
    }

    /// Dismiss when the dimmed backdrop (anywhere outside the card) is tapped.
    @objc private func backdropTapped(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: view)
        if !cardView.frame.contains(point) {
            animateOutAndDismiss()
        }
    }

    @objc private func playerDidFinishPlaying() {
        player?.seek(to: .zero)
        player?.play()
    }

    @objc private func retryButtonTapped() {
        errorView.isHidden = true
        loadingIndicator.startAnimating()
        if videoURL.isEmpty {
            // No URL yet — ask the owner to re-run the translation.
            onRetry?()
        } else {
            setupVideoPlayer()
        }
    }

    private func showError() {
        loadingIndicator.stopAnimating()
        errorView.isHidden = false
        onLoadingFinished?()
    }

    /// Show the "sensitive content cannot be translated" notice: reuses the
    /// error view but without the retry affordance (blocking is intentional).
    private func showBlocked() {
        loadingIndicator.stopAnimating()
        errorLabel.text = blockedMessage
        retryButton.isHidden = true
        errorView.isHidden = false
        onLoadingFinished?()
    }

    // MARK: - Presentation

    /// Present the sheet as a short card flush to the bottom of the screen.
    ///
    /// The sheet is presented full-height (a `.large()` detent, which is the
    /// only detent iOS renders truly flush to the screen bottom — smaller
    /// detents leave a few points of gap). Its container is transparent, so only
    /// the content-sized `cardView`, pinned to the bottom, is visible — giving a
    /// short bottom sheet with no gap on any device.
    static func present(
        from viewController: UIViewController,
        videoURL: String = "",
        text: String,
        title: String,
        strings: LocalizedStrings,
        primaryColor: UIColor,
        textColor: UIColor,
        onDismiss: (() -> Void)? = nil,
        onRetry: (() -> Void)? = nil,
        completion: (() -> Void)? = nil
    ) -> SignBottomSheet {
        // Bottom safe-area inset (home indicator height). Notched devices
        // (inset > 0) get the floating card (inset from the edges, above the
        // home indicator, all corners rounded); home-button devices get the
        // flush card (full width, top corners only).
        let bottomInset = viewController.view.window?.safeAreaInsets.bottom ?? 0
        let isFloating = bottomInset > 0

        let bottomSheet = SignBottomSheet()
        bottomSheet.configure(
            videoURL: videoURL,
            text: text,
            title: title,
            strings: strings,
            primaryColor: primaryColor,
            textColor: textColor,
            isFloating: isFloating,
            bottomSafeInset: bottomInset
        )
        bottomSheet.onDismiss = onDismiss
        bottomSheet.onRetry = onRetry

        // Present over the full screen (presenter stays visible behind the
        // dimming). We animate the card in ourselves, so present without the
        // system transition.
        bottomSheet.modalPresentationStyle = .overFullScreen
        bottomSheet.modalTransitionStyle = .crossDissolve

        viewController.present(bottomSheet, animated: false, completion: completion)
        return bottomSheet
    }

    /// Present the sheet directly in the "sensitive content blocked" state: it
    /// shows `message` with no loading, video, or retry, and never contacts the
    /// network.
    static func presentBlocked(
        from viewController: UIViewController,
        text: String,
        title: String,
        message: String,
        strings: LocalizedStrings,
        primaryColor: UIColor,
        textColor: UIColor,
        onDismiss: (() -> Void)? = nil
    ) -> SignBottomSheet {
        let bottomInset = viewController.view.window?.safeAreaInsets.bottom ?? 0
        let isFloating = bottomInset > 0

        let bottomSheet = SignBottomSheet()
        bottomSheet.configure(
            videoURL: "",
            text: text,
            title: title,
            strings: strings,
            primaryColor: primaryColor,
            textColor: textColor,
            isFloating: isFloating,
            bottomSafeInset: bottomInset
        )
        bottomSheet.isBlocked = true
        bottomSheet.isLoading = false
        bottomSheet.blockedMessage = message
        bottomSheet.onDismiss = onDismiss

        bottomSheet.modalPresentationStyle = .overFullScreen
        bottomSheet.modalTransitionStyle = .crossDissolve

        viewController.present(bottomSheet, animated: false, completion: nil)
        return bottomSheet
    }
}
