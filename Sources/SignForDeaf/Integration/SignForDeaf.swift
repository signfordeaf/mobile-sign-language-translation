// Integration/SignForDeaf.swift

import UIKit

/// The SDK entry point. Configure once at app startup; the SDK mounts itself
/// above the host app in its own overlay window (docs/02-architecture.md).
///
/// The SDK is **off by default** — call `enable()` (or set `autoEnable`). While
/// on, a floating button appears; tapping it opens the corner player and turns
/// tap-to-translate on. The host app stays fully usable throughout.
public final class SignForDeaf {

    public static let shared = SignForDeaf()
    private init() {}

    // MARK: Public state / callbacks

    public private(set) var isEnabled = false

    /// Whether tap-to-translate is currently claiming taps (player open & expanded).
    public var isTapToTranslateActive: Bool {
        isEnabled && player != nil && !(controller?.collapsed ?? true)
    }

    /// Invoked with the offending text whenever a translation is blocked as sensitive.
    public var onSensitiveBlocked: ((String) -> Void)?
    /// Optional host hook for the full lifecycle event stream (docs/12).
    public var onEvent: ((SignForDeafEvent) -> Void)?

    // MARK: Internals

    private var manager: SignForDeafManager?
    private var controller: SignForDeafController?
    private let storage: SignForDeafStorage = UserDefaultsStorage()
    private let placement = SignForDeafPlacement()

    private var overlayWindow: SignOverlayWindow?
    private var catcher: SignTapCatcherView?
    private var button: SignFloatingButton?
    private var player: SignPlayerView?
    private var longPress: LongPressToTranslate?

    private var config: SignForDeafConfig? { manager?.config }

    // MARK: - Configuration

    public func configure(_ config: SignForDeafConfig) {
        onMain {
            let manager = SignForDeafManager(config: config, storage: self.storage)
            SignForDeafManager.shared = manager
            self.manager = manager

            let service = SignLanguageAPIService(config: config)
            let controller = SignForDeafController(manager: manager, service: service)
            controller.onEvent = { [weak self] event in self?.handle(event) }
            controller.onChange = { [weak self] in self?.player?.render() }
            self.controller = controller

            manager.onSignerChanged = { [weak self] in self?.player?.refreshIdleSigner() }

            if config.autoEnable { self.enable() }
        }
    }

    // MARK: - Enable / disable

    public func enable() {
        onMain {
            guard let config = self.config, !self.isEnabled else { return }
            self.isEnabled = true
            self.buildOverlayIfNeeded()
            if config.showFloatingButton { self.showFloatingButton() }
            if config.longPressToTranslate { self.installLongPress() }
        }
    }

    public func disable() {
        onMain {
            guard self.isEnabled else { return }
            self.isEnabled = false
            self.dismissPlayer(bringBackButton: false)
            self.hideFloatingButton()
            self.longPress?.uninstall()
            self.longPress = nil
            // Keep placement and stored preferences — re-enabling restores the setup.
        }
    }

    // MARK: - Floating button

    public func showFloatingButton() {
        onMain {
            guard self.isEnabled, self.player == nil, let manager = self.manager,
                  let container = self.overlayWindow?.container else { return }
            if self.button != nil { return }
            let appearance = manager.config.floatingButton.resolved(themePrimary: manager.config.theme.primaryUIColor)
            let strings = manager.config.language.strings
            let button = SignFloatingButton(
                appearance: appearance, placement: self.placement, storage: self.storage,
                modeLabel: strings.translationModeLabel, hintText: strings.tapToTranslateHint)
            button.onTap = { [weak self] in self?.openPlayer() }
            container.addSubview(button)
            container.layoutIfNeeded()
            button.applyPlacement(in: container)
            self.button = button
        }
    }

    public func hideFloatingButton() {
        button?.removeHint()
        button?.removeFromSuperview()
        button = nil
    }

    // MARK: - Player lifecycle

    /// Open the player from a button tap (or `setTapToTranslateActive(true)`).
    public func openPlayer() {
        onMain { self.presentPlayer(programmatic: false) }
    }

    public func closePlayer() {
        onMain { self.dismissPlayer(bringBackButton: true) }
    }

    private func presentPlayer(programmatic: Bool) {
        guard isEnabled, let controller = controller, let manager = manager,
              let container = overlayWindow?.container else { return }
        hideFloatingButton()
        button?.consumeHintIfEligible()

        let player: SignPlayerView
        if let existing = self.player {
            player = existing
        } else {
            player = SignPlayerView(controller: controller, manager: manager)
            player.onClosed = { [weak self] in self?.dismissPlayer(bringBackButton: true) }
            player.onCollapseChanged = { [weak self] _ in self?.refreshTapMode() }
            container.addSubview(player)
            self.player = player
        }
        container.layoutIfNeeded()
        controller.openPlayer()
        positionPlayer(atCorner: programmatic ? manager.config.card.initialCorner : cornerFromButton())
        player.animateIn()
        refreshTapMode()
    }

    private func dismissPlayer(bringBackButton: Bool) {
        controller?.closePlayer()
        player?.removeFromSuperview()
        player = nil
        refreshTapMode()
        if bringBackButton, isEnabled, config?.showFloatingButton == true {
            showFloatingButton()
        }
    }

    private func cornerFromButton() -> SignForDeafCorner {
        // Open on the side the button is docked to; keep the configured top/bottom.
        let top = config?.card.initialCorner.isTop ?? false
        if placement.dockRight { return top ? .topRight : .bottomRight }
        return top ? .topLeft : .bottomLeft
    }

    private func positionPlayer(atCorner corner: SignForDeafCorner) {
        guard let player = player, let container = overlayWindow?.container else { return }
        let size = player.currentSize()
        player.bounds.size = size
        let insets = container.safeAreaInsets
        let inset = SignTokens.spaceMd
        let x = corner.isRight
            ? container.bounds.width - insets.right - inset - size.width / 2
            : insets.left + inset + size.width / 2
        let y = corner.isTop
            ? insets.top + inset + size.height / 2
            : container.bounds.height - insets.bottom - inset - size.height / 2
        player.center = CGPoint(x: x, y: y)
        player.clampToSafeArea()
    }

    // MARK: - Programmatic translate

    public func translate(_ text: String) {
        onMain {
            guard self.isEnabled, let controller = self.controller else { return }
            if self.player == nil { self.presentPlayer(programmatic: true) }
            controller.translate(text)
        }
    }

    // MARK: - v1-compatible controls

    public func setTapToTranslateActive(_ active: Bool) {
        active ? openPlayer() : closePlayer()
    }

    // MARK: - Tap mode / catcher

    private func refreshTapMode() {
        player?.render()
    }

    private func buildOverlayIfNeeded() {
        guard overlayWindow == nil, let scene = HostWindow.activeScene() else { return }
        let window = SignOverlayWindow(windowScene: scene)
        let catcher = SignTapCatcherView(frame: window.bounds)
        catcher.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        catcher.smartPassthrough = config?.smartPassthrough ?? true
        catcher.longPressToActivate = config?.longPressToActivate ?? false
        catcher.accessibilityFallback = config?.accessibilityTextFallback ?? false
        catcher.hostRoot = { HostWindow.keyWindow()?.rootViewController?.view }
        catcher.isTapModeActive = { [weak self] in self?.isTapToTranslateActive ?? false }
        catcher.onTranslateText = { [weak self] node, point in
            self?.translateFromTap(node: node, pointInNode: point)
        }
        catcher.onTranslateRawText = { [weak self] text in
            self?.translateRawText(text)
        }
        window.container.addSubview(catcher)
        self.catcher = catcher
        self.overlayWindow = window
    }

    private func installLongPress() {
        guard longPress == nil, let host = HostWindow.keyWindow() else { return }
        let lp = LongPressToTranslate(
            hostRoot: { HostWindow.keyWindow()?.rootViewController?.view },
            isAvailable: { [weak self] in self?.isTapToTranslateActive ?? false })
        lp.smartPassthrough = config?.smartPassthrough ?? true
        lp.onTranslateText = { [weak self] node, point in
            self?.translateFromTap(node: node, pointInNode: point)
        }
        lp.install(on: host)
        self.longPress = lp
    }

    // MARK: - Tap → segments → translate

    private func translateFromTap(node: UIView, pointInNode: CGPoint) {
        guard let manager = manager, let controller = controller else { return }
        guard let text = TapTargetProbe.extractText(
            node, allowAccessibility: manager.config.accessibilityTextFallback) else { return }

        // Text tapped inside a host-marked sensitive subtree must never be sent —
        // register it so the guard blocks it and the player shows the notice.
        if node.isWithinSignForDeafSensitiveSubtree {
            SensitiveTextRegistry.shared.register(text)
        }

        let offset = TextOffsetResolver.offset(at: pointInNode, in: node)
        let splitter = SentenceSplitter(maxChars: manager.config.maxSegmentChars)
        guard let result = SegmentBuilder.build(
            nodeText: text, tapOffset: offset,
            granularity: manager.config.granularity, splitter: splitter) else { return }
        controller.setSegments(result.segments, startAt: result.index)
    }

    /// Translate text resolved from the accessibility layer (SwiftUI controls),
    /// where there is no node to map a tap position onto — the whole label is
    /// segmented from the start.
    private func translateRawText(_ text: String) {
        guard let manager = manager, let controller = controller else { return }
        let splitter = SentenceSplitter(maxChars: manager.config.maxSegmentChars)
        guard let result = SegmentBuilder.build(
            nodeText: text, tapOffset: nil,
            granularity: manager.config.granularity, splitter: splitter) else { return }
        controller.setSegments(result.segments, startAt: result.index)
    }

    // MARK: - Events / announcements

    private func handle(_ event: SignForDeafEvent) {
        if event.type == .blockedSensitive, let text = event.text {
            onSensitiveBlocked?(text)
        }
        announce(for: event)
        onEvent?(event)
    }

    private func announce(for event: SignForDeafEvent) {
        guard let config = config else { return }
        let strings = config.language.strings
        switch event.type {
        case .translationComplete where config.accessibility.announceOnOpen:
            UIAccessibility.post(notification: .announcement, argument: strings.translationReady)
        case .panelClose where config.accessibility.announceOnClose:
            UIAccessibility.post(notification: .announcement, argument: strings.close)
        default:
            break
        }
    }

    // MARK: - Helpers

    private func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }
}
