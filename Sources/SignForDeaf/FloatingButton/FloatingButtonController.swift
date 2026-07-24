// FloatingButton/FloatingButtonController.swift

import UIKit

/// A window that lets touches pass through to the app except when they land on
/// the floating button, so the overlay never blocks normal interaction.
final class PassthroughWindow: UIWindow {
    weak var interactiveView: UIView?

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hit = super.hitTest(point, with: event) else { return nil }
        if let interactive = interactiveView,
            hit == interactive || hit.isDescendant(of: interactive) {
            return hit
        }
        return nil
    }
}

/// The button view with an enlarged touch target, so taps just around it (and
/// while it's peeked off the edge) still register — making it feel responsive.
final class TouchPaddedView: UIView {
    var hitPadding: CGFloat = 14

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.insetBy(dx: -hitPadding, dy: -hitPadding).contains(point)
    }
}

/// AssistiveTouch-style draggable floating button that toggles tap-to-translate
/// mode. Lives in its own passthrough overlay window so it floats above every
/// screen. Native re-implementation of the RN `SignLanguageFloatingButton`.
final class FloatingButtonController {

    // MARK: - Config

    private let idleOpacity: CGFloat = 0.55
    private let peekHiddenFraction: CGFloat = 0.35
    private let tapMovementThreshold: CGFloat = 6

    /// The hint bubble is shown on the first `maxHintShows` activations, then
    /// hidden for good (persisted across launches).
    private let hintCountKey = "com.signfordeaf.tapToTranslateHintShownCount"

    /// Resolved appearance/behavior (colors, size, idle behavior, hint count),
    /// driven by `SignForDeafFloatingButtonConfig`.
    private var appearance = FloatingButtonAppearance(
        size: 44,
        backgroundColor: .white,
        activeBackgroundColor: SignForDeafTheme.defaultPrimary,
        iconColor: SignForDeafTheme.defaultPrimary,
        activeIconColor: .white,
        borderColor: SignForDeafTheme.defaultPrimary,
        idleBehavior: .peek,
        idleDelay: 2.5,
        hintMaxShows: 2)

    private var size: CGFloat { appearance.size }
    private var idleDelay: TimeInterval { appearance.idleDelay }
    private var maxHintShows: Int { appearance.hintMaxShows }
    private var hintText: String = "Çevirmek için bir yazıya dokunun"

    /// Called when the button is tapped (not dragged) with the new active state.
    var onToggle: ((Bool) -> Void)?

    // MARK: - State

    private var window: PassthroughWindow?
    private var button: UIView?
    private var logoView: LogoView?
    private var hintBubble: UIView?

    private enum Side { case left, right }
    private var restingSide: Side = .right
    private var isActive = false
    private var isPeeked = false
    private var hintEligibleThisActivation = false
    private var dragStartOrigin: CGPoint = .zero
    private var idleTimer: Timer?

    /// How many times the hint has been shown so far (persisted).
    private var hintShownCount: Int {
        get { UserDefaults.standard.integer(forKey: hintCountKey) }
        set { UserDefaults.standard.set(newValue, forKey: hintCountKey) }
    }

    // MARK: - Lifecycle

    func show(appearance: FloatingButtonAppearance, hintText: String) {
        self.appearance = appearance
        self.hintText = hintText

        if window != nil {
            applyAppearance()
            return
        }

        guard let scene = activeWindowScene() else { return }

        let window = PassthroughWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        window.windowLevel = .alert + 1
        window.backgroundColor = .clear
        let root = UIViewController()
        root.view.backgroundColor = .clear
        window.rootViewController = root
        window.isHidden = false
        self.window = window

        buildButton(in: root.view)
        buildHint(in: root.view)
        applyAppearance()

        // Start on the middle of the right edge after layout is known.
        DispatchQueue.main.async { [weak self] in
            self?.positionAtStart()
            self?.scheduleIdle()
        }
    }

    func hide() {
        cancelIdle()
        window?.isHidden = true
        window = nil
        button = nil
        logoView = nil
        hintBubble = nil
    }

    /// Reflect external state changes (e.g. mode toggled programmatically).
    /// The hint is counted/shown only on a genuine off→on transition, up to
    /// `maxHintShows` times ever.
    func setActive(_ active: Bool) {
        let wasActive = isActive
        isActive = active
        applyAppearance()

        if active && !wasActive {
            hintEligibleThisActivation = hintShownCount < maxHintShows
            if hintEligibleThisActivation {
                hintShownCount += 1
            }
        } else if !active {
            hintEligibleThisActivation = false
        }

        updateHintVisibility()
    }

    // MARK: - Build

    private func buildButton(in parent: UIView) {
        let button = TouchPaddedView(frame: CGRect(x: 0, y: 0, width: size, height: size))
        button.layer.cornerRadius = size / 2
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowOpacity = 0.25
        button.layer.shadowRadius = 4
        button.isAccessibilityElement = true
        button.accessibilityTraits = .button
        button.accessibilityLabel = "İşaret dili çeviri modu"

        let logo = LogoView()
        logo.backgroundColor = .clear
        logo.isUserInteractionEnabled = false  // let touches reach the button
        logo.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(logo)
        NSLayoutConstraint.activate([
            logo.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            logo.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            logo.widthAnchor.constraint(equalToConstant: size * 0.6),
            logo.heightAnchor.constraint(equalToConstant: size * 0.6),
        ])

        // Tap toggles the mode; pan drags. A plain UIPanGestureRecognizer only
        // enters .began after ~10pt of movement, so a stationary tap never fires
        // it — a dedicated tap recognizer is required for reliable toggling.
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        button.addGestureRecognizer(tap)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        button.addGestureRecognizer(pan)

        parent.addSubview(button)
        self.button = button
        self.logoView = logo
        window?.interactiveView = button
    }

    private func buildHint(in parent: UIView) {
        let bubble = UIView()
        bubble.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        bubble.layer.cornerRadius = 12
        bubble.isHidden = true
        bubble.isUserInteractionEnabled = false
        bubble.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = hintText
        label.textColor = .white
        label.font = .systemFont(ofSize: 13)
        label.textAlignment = .center
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        bubble.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -8),
            label.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -12),
            bubble.widthAnchor.constraint(equalToConstant: 180),
        ])

        parent.addSubview(bubble)
        self.hintBubble = bubble
    }

    // MARK: - Appearance

    private func applyAppearance() {
        guard let button = button else { return }
        if isActive {
            button.backgroundColor = appearance.activeBackgroundColor
            button.layer.borderWidth = 0
            logoView?.logoColor = appearance.activeIconColor
        } else {
            button.backgroundColor = appearance.backgroundColor
            button.layer.borderWidth = 2
            button.layer.borderColor = appearance.borderColor.cgColor
            logoView?.logoColor = appearance.iconColor
        }
    }

    private func applyCorners(dragging: Bool) {
        guard let button = button else { return }
        if dragging {
            button.layer.maskedCorners = [
                .layerMinXMinYCorner, .layerMaxXMinYCorner,
                .layerMinXMaxYCorner, .layerMaxXMaxYCorner,
            ]
        } else if restingSide == .left {
            button.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        } else {
            button.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        }
    }

    // MARK: - Geometry

    private func edgeBounds() -> (minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat) {
        guard let window = window else { return (0, 0, 0, 0) }
        let insets = window.safeAreaInsets
        let w = window.bounds.width
        let h = window.bounds.height
        return (
            minX: 0,
            maxX: max(0, w - size),
            minY: insets.top + 8,
            maxY: max(insets.top + 8, h - size - insets.bottom - 8)
        )
    }

    private func positionAtStart() {
        let b = edgeBounds()
        restingSide = .right
        button?.frame.origin = CGPoint(x: b.maxX, y: (b.minY + b.maxY) / 2)
        applyCorners(dragging: false)
    }

    // MARK: - Tap (toggle)

    @objc private func handleTap() {
        guard let button = button else { return }
        cancelIdle()
        isPeeked = false
        button.layer.removeAllAnimations()

        let newActive = !isActive
        setActive(newActive)     // single funnel: appearance + hint counting
        onToggle?(newActive)     // notify the SDK to flip tap-to-translate mode
        settle()                 // spring back flush to the edge, re-arm idle
    }

    // MARK: - Pan (drag)

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let button = button else { return }
        let translation = gesture.translation(in: button.superview)

        switch gesture.state {
        case .began:
            cancelIdle()
            isPeeked = false
            button.layer.removeAllAnimations()
            button.alpha = 1
            dragStartOrigin = button.frame.origin
            applyCorners(dragging: true)

        case .changed:
            let b = edgeBounds()
            let x = min(max(dragStartOrigin.x + translation.x, b.minX - size), b.maxX + size)
            let y = min(max(dragStartOrigin.y + translation.y, b.minY), b.maxY)
            button.frame.origin = CGPoint(x: x, y: y)

        case .ended, .cancelled:
            snapToNearestEdge()

        default:
            break
        }
    }

    private func snapToNearestEdge() {
        guard let button = button else { return }
        let b = edgeBounds()
        let centerX = button.frame.origin.x + size / 2
        let midX = (b.minX + b.maxX + size) / 2
        restingSide = centerX < midX ? .left : .right
        settle()
    }

    /// Spring the button to its resting edge, restore opacity, arm the idle timer.
    private func settle() {
        guard let button = button else { return }
        let b = edgeBounds()
        let targetX = restingSide == .left ? b.minX : b.maxX
        let targetY = min(max(button.frame.origin.y, b.minY), b.maxY)
        isPeeked = false

        applyCorners(dragging: false)
        UIView.animate(
            withDuration: 0.35, delay: 0,
            usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5,
            options: [.allowUserInteraction],
            animations: {
                button.frame.origin = CGPoint(x: targetX, y: targetY)
                button.alpha = 1
            },
            completion: { [weak self] _ in
                self?.updateHintVisibility()
                self?.scheduleIdle()
            })
    }

    // MARK: - Idle peek

    private func scheduleIdle() {
        cancelIdle()
        guard appearance.idleBehavior != .none else { return }
        idleTimer = Timer.scheduledTimer(withTimeInterval: idleDelay, repeats: false) {
            [weak self] _ in
            self?.runIdle()
        }
    }

    private func cancelIdle() {
        idleTimer?.invalidate()
        idleTimer = nil
    }

    private func runIdle() {
        guard let button = button else { return }
        isPeeked = true
        updateHintVisibility()
        let b = edgeBounds()
        // `.peek` slides partly off the edge; `.fade` just dims in place.
        let peekX: CGFloat
        if appearance.idleBehavior == .peek {
            let hidden = size * peekHiddenFraction
            peekX = restingSide == .left ? b.minX - hidden : b.maxX + hidden
        } else {
            peekX = button.frame.origin.x
        }
        UIView.animate(
            withDuration: 0.25, delay: 0,
            usingSpringWithDamping: 0.8, initialSpringVelocity: 0.3,
            options: [.allowUserInteraction],
            animations: {
                button.frame.origin.x = peekX
                button.alpha = self.idleOpacity
            })
    }

    // MARK: - Hint

    private func updateHintVisibility() {
        guard let bubble = hintBubble, let button = button else { return }
        let shouldShow = isActive && !isPeeked && hintEligibleThisActivation
        bubble.isHidden = !shouldShow
        guard shouldShow else { return }

        bubble.sizeToFit()
        bubble.layoutIfNeeded()
        let bubbleWidth: CGFloat = 180
        let bubbleHeight = bubble.systemLayoutSizeFitting(
            UIView.layoutFittingCompressedSize).height
        let y = button.frame.midY - bubbleHeight / 2
        let x: CGFloat
        if restingSide == .right {
            x = button.frame.minX - bubbleWidth - 8  // to the left of the button
        } else {
            x = button.frame.maxX + 8  // to the right of the button
        }
        bubble.frame = CGRect(x: x, y: y, width: bubbleWidth, height: bubbleHeight)
    }

    // MARK: - Helpers

    private func activeWindowScene() -> UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    }
}
