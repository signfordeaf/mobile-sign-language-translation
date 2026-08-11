// Views/SignPlayerView.swift

import UIKit

/// The corner player (docs/06-player-layout.md). Two independent blocks — the
/// stage and the control block — plus the window pill hanging above the stage.
/// Non-modal: it covers only a corner and the app underneath stays operable.
///
/// Renders purely from controller state; holds no translation state of its own
/// beyond transient playback (play/pause) and layout.
final class SignPlayerView: UIView {

    private let controller: SignForDeafController
    private let manager: SignForDeafManager

    let stage = SignStageView()
    private let controlBlock = UIView()
    private let controlBar = SignControlBar()
    private let caption = SignCaptionView()
    private let windowPill = WindowPill()
    private let collapsedBar = CollapsedBar()

    private var isPlaying = true
    private var videoAspect: CGFloat = PlayerLayout.defaultAspect

    /// Called when the player is closed (facade brings the button back).
    var onClosed: (() -> Void)?
    /// Called when collapse state changes, so the facade can toggle tap mode.
    var onCollapseChanged: ((Bool) -> Void)?

    init(controller: SignForDeafController, manager: SignForDeafManager) {
        self.controller = controller
        self.manager = manager
        super.init(frame: .zero)
        isSignForDeafInternalUI = true
        setUp()
        installVideoHooks()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private var theme: SignForDeafTheme { manager.config.theme }
    private var strings: LocalizedStrings { manager.config.language.strings }
    private var card: SignForDeafCardConfig { manager.config.card }

    private func setUp() {
        addSubview(stage)

        controlBlock.layer.cornerRadius = SignTokens.radiusLarge
        controlBlock.clipsToBounds = false // let the floating shadow escape
        controlBlock.isSignForDeafInternalUI = true
        controlBlock.layer.shadowColor = SignTokens.floatingShadowColor.cgColor
        controlBlock.layer.shadowOpacity = SignTokens.floatingShadowOpacity
        controlBlock.layer.shadowOffset = SignTokens.floatingShadowOffset
        controlBlock.layer.shadowRadius = SignTokens.floatingShadowRadius
        controlBlock.addSubview(controlBar)
        controlBlock.addSubview(caption)
        addSubview(controlBlock)

        addSubview(windowPill)
        addSubview(collapsedBar)
        collapsedBar.isHidden = true

        controlBar.configure(showSpeed: card.showSpeed, showLoop: card.showLoop, showContact: card.showContact)
        wireActions()
        applyTheme()

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)
    }

    private func wireActions() {
        controlBar.onPlayPause = { [weak self] in self?.togglePlay() }
        controlBar.onSpeed = { [weak self] in self?.controller.cycleSpeed() }
        controlBar.onLoop = { [weak self] in self?.controller.toggleLoop() }
        controlBar.onContact = { [weak self] in self?.controller.requestContact() }
        windowPill.onCollapse = { [weak self] in self?.setCollapsed(true) }
        windowPill.onClose = { [weak self] in self?.close() }
        collapsedBar.onExpand = { [weak self] in self?.setCollapsed(false) }
        collapsedBar.onClose = { [weak self] in self?.close() }
    }

    private func installVideoHooks() {
        controller.videoInitializer = { [weak self] url, done in
            guard let self = self else { done(.success(())); return }
            self.stage.video.load(
                url: url, rate: Float(self.controller.speed), looping: self.controller.isLooping
            ) { result in done(result) }
        }
        stage.video.onEnded = { [weak self] in self?.controller.videoDidEnd() }
    }

    // MARK: Theme

    private func applyTheme() {
        let primary = theme.primaryUIColor
        let onPrimary = theme.resolvedOnPrimary
        stage.applyTheme(surface: theme.surfaceUIColor, onSurface: theme.resolvedOnSurface, primary: primary)
        controlBlock.backgroundColor = primary
        caption.textColor = onPrimary
        windowPill.applyTint(onPrimary, background: primary)
        collapsedBar.applyTint(onPrimary, background: primary)
        stage.setCornerRadius(theme.cornerRadius)
        controlBlock.layer.cornerRadius = theme.cornerRadius
    }

    // MARK: Idle loop configuration

    /// Point the idle loop at the current signer / host asset (called on open and
    /// when the signer changes via id adoption).
    func refreshIdleSigner() {
        let url = resolveIdleClipURL()
        stage.idleLoop.configure(url: url, primaryColor: theme.primaryUIColor)
    }

    private func resolveIdleClipURL() -> URL? {
        if let asset = card.placeholderAsset {
            if asset.isEmpty { return nil } // "" opts out of video entirely
            if let bundled = Bundle.main.url(forResource: asset, withExtension: nil) { return bundled }
            return URL(fileURLWithPath: asset)
        }
        return manager.resolvedSigner.bundledURL
    }

    // MARK: Render

    func render() {
        let state = controller.state
        let collapsed = controller.collapsed
        collapsedBar.isHidden = !collapsed
        stage.isHidden = collapsed
        controlBlock.isHidden = collapsed
        windowPill.isHidden = collapsed

        if !collapsed {
            let message: String? = {
                switch state {
                case .error: return strings.error
                case .blocked: return strings.sensitiveBlocked
                default: return nil
                }
            }()
            stage.render(state: state, message: message)
            caption.setText(captionText())
            controlBar.render(
                playbackAvailable: controller.playbackAvailable,
                isPlaying: isPlaying && controller.playbackAvailable,
                speedValue: controller.speed,
                isLooping: controller.isLooping,
                onPrimary: theme.resolvedOnPrimary)
            // Keep the live video in sync with the preferences.
            stage.video.setRate(Float(controller.speed))
            stage.video.setLooping(controller.isLooping)
        }
        // Animate the grow/shrink when the caption appears or goes away.
        UIView.animate(withDuration: SignTokens.collapseTransition, delay: 0,
                       options: [.beginFromCurrentState, .curveEaseInOut]) {
            self.updateSize()
            self.layoutIfNeeded()
        }
    }

    private func captionText() -> String? {
        switch controller.state {
        case .loading, .ready: return controller.currentText
        default: return nil
        }
    }

    /// A caption only exists while translating/translated — the control block is
    /// compact otherwise (docs deviation the user asked for: grow only with text).
    private var hasCaption: Bool { captionText() != nil }

    /// Visual height of the control row (matches the 44 pt tap target).
    private let controlRowHeight: CGFloat = 44

    /// Extra breathing room below the caption, before the bar's bottom edge.
    private let captionBottomPadding: CGFloat = SignTokens.spaceSm

    /// Two-line caption with tight padding.
    private func captionViewHeight(scale: CGFloat) -> CGFloat {
        SignTokens.captionFontSize * scale * SignTokens.captionLineHeight
            * CGFloat(SignTokens.captionMaxLines) + SignTokens.spaceXs * 2
    }

    private func controlBlockHeight(scale: CGFloat) -> CGFloat {
        hasCaption
            ? controlRowHeight + captionViewHeight(scale: scale) + captionBottomPadding
            : controlRowHeight + SignTokens.spaceSm * 2
    }

    // MARK: Sizing & layout

    private var controlCount: Int {
        1 + (card.showSpeed ? 1 : 0) + (card.showLoop ? 1 : 0) + (card.showContact ? 1 : 0)
    }

    private var textScale: CGFloat {
        traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? 1.3 : 1.0
    }

    /// The current player size (expanded or collapsed). The stage size is stable;
    /// only the control block grows when a caption appears.
    func currentSize() -> CGSize {
        if controller.collapsed {
            return CGSize(width: 3 * SignTokens.controlSize, height: SignTokens.controlSize)
        }
        let screenHeight = superview?.bounds.height ?? UIScreen.main.bounds.height
        let layout = PlayerLayout.compute(
            screenHeight: screenHeight, aspect: videoAspect,
            avatarHeight: card.avatarHeight, avatarMaxWidth: card.avatarMaxWidth,
            controlCount: controlCount, textScale: textScale)
        let width = max(layout.player.width, layout.controlBarWidthExpanded)
        let pillOverflow = SignTokens.controlSize * SignTokens.pillOverflowFraction
        let height = pillOverflow + layout.stage.height + SignTokens.spaceSm
            + controlBlockHeight(scale: textScale)
        return CGSize(width: width, height: height)
    }

    private func updateSize() {
        let size = currentSize()
        if bounds.size != size {
            bounds.size = size
            clampToSafeArea()
        }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if controller.collapsed {
            collapsedBar.frame = bounds
            return
        }
        let screenHeight = superview?.bounds.height ?? UIScreen.main.bounds.height
        let scale = textScale
        let layout = PlayerLayout.compute(
            screenHeight: screenHeight, aspect: videoAspect,
            avatarHeight: card.avatarHeight, avatarMaxWidth: card.avatarMaxWidth,
            controlCount: controlCount, textScale: scale)

        let pillOverflow = SignTokens.controlSize * SignTokens.pillOverflowFraction
        let stageSize = layout.stage
        stage.frame = CGRect(x: (bounds.width - stageSize.width) / 2, y: pillOverflow,
                             width: stageSize.width, height: stageSize.height)

        // Window pill: top-right of the stage, 80% above its top edge.
        let pillWidth = 2 * SignTokens.controlSize
        windowPill.frame = CGRect(
            x: stage.frame.maxX - pillWidth, y: 0,
            width: pillWidth, height: SignTokens.controlSize)

        let showCaption = hasCaption
        let captionH = captionViewHeight(scale: scale)
        let blockHeight = controlBlockHeight(scale: scale)
        let blockWidth = layout.controlBarWidthExpanded
        controlBlock.frame = CGRect(
            x: (bounds.width - blockWidth) / 2, y: stage.frame.maxY + SignTokens.spaceSm,
            width: blockWidth, height: blockHeight)
        controlBlock.layer.shadowPath = UIBezierPath(
            roundedRect: CGRect(origin: .zero, size: CGSize(width: blockWidth, height: blockHeight)),
            cornerRadius: controlBlock.layer.cornerRadius).cgPath
        // With a caption: control row on top, caption below. Without one: centre
        // the control row in the compact block.
        let controlRowY = showCaption ? 0 : (blockHeight - controlRowHeight) / 2
        controlBar.frame = CGRect(x: 0, y: controlRowY, width: blockWidth, height: controlRowHeight)
        caption.isHidden = !showCaption
        caption.frame = CGRect(x: 0, y: controlRowHeight, width: blockWidth, height: captionH)
    }

    // MARK: Playback

    private func togglePlay() {
        guard controller.playbackAvailable else { return }
        isPlaying.toggle()
        if isPlaying { stage.video.play() } else { stage.video.pause() }
        render()
    }

    // MARK: Collapse / close

    func setCollapsed(_ collapsed: Bool) {
        guard collapsed != controller.collapsed else { return }
        controller.setCollapsed(collapsed)
        if collapsed {
            // Collapsed = "get out of the way": stop both decoders.
            stage.video.pause()
            stage.idleLoop.pause()
        } else if isPlaying, controller.playbackAvailable {
            stage.video.play()
        }
        // Expanding: render() re-applies the right idle-loop play/pause for the state.
        onCollapseChanged?(collapsed)
        UIView.animate(withDuration: SignTokens.collapseTransition) {
            self.render()
            self.superview?.layoutIfNeeded()
        }
    }

    func close() {
        stage.video.release()
        stage.idleLoop.releasePlayer()
        controller.closePlayer()
        onClosed?()
    }

    // MARK: Entrance

    func animateIn() {
        refreshIdleSigner()
        render()
        alpha = 0
        transform = CGAffineTransform(translationX: 0, y: bounds.height * 0.15)
        UIView.animate(withDuration: SignTokens.cardTransition,
                       delay: 0, options: [.curveEaseOut]) {
            self.alpha = 1
            self.transform = .identity
        }
    }

    // MARK: Drag (docs/06 §"Position and dragging")

    private var dragStart: CGPoint = .zero

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard card.draggable, let superview = superview else { return }
        switch gesture.state {
        case .began:
            dragStart = center
        case .changed:
            let t = gesture.translation(in: superview)
            center = CGPoint(x: dragStart.x + t.x, y: dragStart.y + t.y)
            clampToSafeArea()
        default:
            clampToSafeArea()
        }
    }

    /// Clamp the player fully inside the superview's safe area — on every update,
    /// on release, and after layout (size changes with aspect and collapse).
    func clampToSafeArea() {
        guard let superview = superview else { return }
        let insets = superview.safeAreaInsets
        let minX = insets.left + bounds.width / 2
        let maxX = superview.bounds.width - insets.right - bounds.width / 2
        let minY = insets.top + bounds.height / 2
        let maxY = superview.bounds.height - insets.bottom - bounds.height / 2
        center = CGPoint(x: min(max(center.x, minX), max(minX, maxX)),
                         y: min(max(center.y, minY), max(minY, maxY)))
    }
}
