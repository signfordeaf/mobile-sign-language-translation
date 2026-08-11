// FloatingButton/SignFloatingButton.swift

import UIKit

/// The floating tap-to-translate button (docs/07-floating-button.md).
///
/// Driven by raw pointer events (a tap and a drag start identically here): a
/// stationary press opens the player, a press that travels more than 6 pt drags.
/// One tap always acts — a peeked button wakes and opens in the same gesture.
/// Its resting place lives outside it, in `SignForDeafPlacement`.
final class SignFloatingButton: UIView {

    private let logo = LogoView()
    private let hintBubble = UILabel()
    private let hintContainer = UIView()

    private let appearance: FloatingButtonAppearance
    private let placement: SignForDeafPlacement
    private let storage: SignForDeafStorage
    private let modeLabel: String
    private let hintText: String

    /// Tapped (not dragged) — open the player / toggle mode on.
    var onTap: (() -> Void)?
    /// Report a new resting place after a settle.
    var onPlacementChanged: (() -> Void)?

    private var isActive = false
    private var isDragging = false
    private var isPeeked = false
    private var travel: CGFloat = 0
    private var downPoint: CGPoint = .zero
    private var startOrigin: CGPoint = .zero
    private var idleTimer: Timer?
    private var hintEligibleThisActivation = false

    private let dragThreshold: CGFloat = 6
    private let peekHiddenFraction: CGFloat = 0.35
    private let idleOpacity: CGFloat = 0.55

    init(appearance: FloatingButtonAppearance, placement: SignForDeafPlacement,
         storage: SignForDeafStorage, modeLabel: String, hintText: String) {
        self.appearance = appearance
        self.placement = placement
        self.storage = storage
        self.modeLabel = modeLabel
        self.hintText = hintText
        super.init(frame: CGRect(x: 0, y: 0, width: appearance.size, height: appearance.size))
        isSignForDeafInternalUI = true

        logo.isUserInteractionEnabled = false
        addSubview(logo)

        buildHint()
        applyShadow()
        applyAppearance()
        configureAccessibility()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        let logoSize = appearance.size * 0.6
        logo.frame = CGRect(
            x: (bounds.width - logoSize) / 2, y: (bounds.height - logoSize) / 2,
            width: logoSize, height: logoSize)
        applyCorners(dragging: isDragging)
    }

    /// Enlarge the touch target so a peeked button (partly off-edge) is still tappable.
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.insetBy(dx: -14, dy: -14).contains(point)
    }

    // MARK: Placement

    /// Position from the stored placement within `container`'s safe area.
    func applyPlacement(in container: UIView) {
        let insets = container.safeAreaInsets
        let size = appearance.size
        let x = placement.dockRight
            ? container.bounds.width - insets.right - size
            : insets.left
        let band = container.bounds.height - insets.top - insets.bottom - size
        let y = insets.top + band * placement.verticalFraction
        frame = CGRect(x: x, y: y, width: size, height: size)
        applyCorners(dragging: false)
        scheduleIdle()
    }

    // MARK: Active state

    func setActive(_ active: Bool) {
        let wasActive = isActive
        isActive = active
        applyAppearance()
        accessibilityTraits = active ? [.button, .selected] : [.button]
        if active && !wasActive { hintEligibleThisActivation = consumeHintIfEligible() }
        updateHintVisibility()
    }

    // MARK: Pointer handling (docs/07 §Gestures)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let superview = superview else { return }
        cancelIdle()
        unpeek()
        layer.removeAllAnimations()
        alpha = 1
        travel = 0
        isDragging = false
        downPoint = touch.location(in: superview)
        startOrigin = frame.origin
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let superview = superview else { return }
        let p = touch.location(in: superview)
        let dx = p.x - downPoint.x, dy = p.y - downPoint.y
        travel = max(travel, hypot(dx, dy))
        if travel > dragThreshold {
            if !isDragging { isDragging = true; applyCorners(dragging: true) }
            frame.origin = CGPoint(x: startOrigin.x + dx, y: startOrigin.y + dy)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if travel <= dragThreshold {
            // Tap — settle first, then act (acting unmounts the button).
            settle(thenAct: true)
        } else {
            settle(thenAct: false)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        settle(thenAct: false)
    }

    // MARK: Settle / snap

    private func settle(thenAct: Bool) {
        guard let superview = superview else { return }
        let insets = superview.safeAreaInsets
        let size = appearance.size
        // Nearest horizontal edge, keep vertical, clamp.
        let center = frame.midX
        placement.dockRight = center > superview.bounds.width / 2
        let x = placement.dockRight ? superview.bounds.width - insets.right - size : insets.left
        let band = superview.bounds.height - insets.top - insets.bottom - size
        let clampedY = min(max(frame.origin.y, insets.top), insets.top + band)
        placement.verticalFraction = band > 0 ? (clampedY - insets.top) / band : 0.5

        UIView.animate(withDuration: SignTokens.snapTransition, delay: 0,
                       usingSpringWithDamping: 0.7, initialSpringVelocity: 0,
                       options: [.curveEaseOut]) {
            self.frame.origin = CGPoint(x: x, y: clampedY)
            self.applyCorners(dragging: false)
        } completion: { _ in
            self.isDragging = false
            self.scheduleIdle()
        }
        onPlacementChanged?()
        if thenAct { onTap?() }
    }

    // MARK: Idle behavior (docs/07 §"Idle behavior")

    private func scheduleIdle() {
        cancelIdle()
        guard appearance.idleBehavior != .none else { return }
        idleTimer = Timer.scheduledTimer(withTimeInterval: appearance.idleDelay, repeats: false) {
            [weak self] _ in self?.runIdle()
        }
    }

    private func cancelIdle() { idleTimer?.invalidate(); idleTimer = nil }

    private func runIdle() {
        guard let superview = superview else { return }
        isPeeked = true
        updateHintVisibility()
        switch appearance.idleBehavior {
        case .peek:
            let dx = appearance.size * peekHiddenFraction * (placement.dockRight ? 1 : -1)
            UIView.animate(withDuration: 0.3) {
                self.transform = CGAffineTransform(translationX: dx, y: 0)
                self.alpha = self.idleOpacity
            }
        case .fade:
            UIView.animate(withDuration: 0.3) { self.alpha = self.idleOpacity }
        case .none:
            break
        }
        _ = superview
    }

    private func unpeek() {
        guard isPeeked else { return }
        isPeeked = false
        transform = .identity
        alpha = 1
        updateHintVisibility()
    }

    // MARK: Hint bubble (docs/07 §"Hint bubble")

    private func buildHint() {
        hintContainer.isSignForDeafInternalUI = true
        hintContainer.backgroundColor = SignTokens.hintBackground
        hintContainer.layer.cornerRadius = SignTokens.radiusSmall
        hintContainer.isUserInteractionEnabled = false
        hintContainer.isHidden = true
        hintBubble.text = hintText
        hintBubble.textColor = SignTokens.hintForeground
        hintBubble.font = .systemFont(ofSize: 13)
        hintBubble.numberOfLines = 3
        hintBubble.textAlignment = .center
        hintBubble.translatesAutoresizingMaskIntoConstraints = false
        hintContainer.addSubview(hintBubble)
        NSLayoutConstraint.activate([
            hintBubble.topAnchor.constraint(equalTo: hintContainer.topAnchor, constant: 8),
            hintBubble.bottomAnchor.constraint(equalTo: hintContainer.bottomAnchor, constant: -8),
            hintBubble.leadingAnchor.constraint(equalTo: hintContainer.leadingAnchor, constant: 10),
            hintBubble.trailingAnchor.constraint(equalTo: hintContainer.trailingAnchor, constant: -10),
            hintContainer.widthAnchor.constraint(equalToConstant: 200),
        ])
    }

    private var hintCount: Int {
        get { Int(storage.getItem(StorageKey.hintShownCount) ?? "") ?? 0 }
        set { storage.setItem(StorageKey.hintShownCount, String(newValue)) }
    }

    /// Consume one hint show if any budget remains. Returns whether it was consumed.
    @discardableResult
    func consumeHintIfEligible() -> Bool {
        guard hintCount < appearance.hintMaxShows else { return false }
        hintCount += 1
        return true
    }

    private func updateHintVisibility() {
        let show = isActive && !isPeeked && hintEligibleThisActivation
        guard show, let superview = superview else { hintContainer.isHidden = true; return }
        if hintContainer.superview == nil { superview.addSubview(hintContainer) }
        hintContainer.isHidden = false
        hintContainer.setNeedsLayout()
        hintContainer.layoutIfNeeded()
        let gap: CGFloat = 8
        let size = hintContainer.systemLayoutSizeFitting(
            CGSize(width: 200, height: UIView.layoutFittingCompressedSize.height))
        let below = frame.midY < superview.bounds.height / 2
        let y = below ? frame.maxY + gap : frame.minY - gap - size.height
        let x = placement.dockRight ? frame.maxX - size.width : frame.minX
        hintContainer.frame = CGRect(x: x, y: y, width: size.width, height: size.height)
    }

    // MARK: Appearance

    private func applyAppearance() {
        if isActive {
            backgroundColor = appearance.activeBackgroundColor
            layer.borderWidth = 0
            logo.logoColor = appearance.activeIconColor
        } else {
            backgroundColor = appearance.backgroundColor
            layer.borderWidth = 2
            layer.borderColor = appearance.borderColor.cgColor
            logo.logoColor = appearance.iconColor
        }
    }

    private func applyShadow() {
        layer.shadowColor = SignTokens.pillShadowColor.cgColor
        layer.shadowOpacity = SignTokens.pillShadowOpacity
        layer.shadowOffset = SignTokens.pillShadowOffset
        layer.shadowRadius = SignTokens.pillShadowRadius
    }

    /// Docked: a half-rounded tab (full radius on the corners facing away from the
    /// edge). Dragging: a full circle.
    private func applyCorners(dragging: Bool) {
        let r = appearance.size / 2
        layer.cornerRadius = r
        if dragging {
            layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner,
                                   .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        } else if placement.dockRight {
            layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        } else {
            layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        }
    }

    private func configureAccessibility() {
        isAccessibilityElement = true
        accessibilityTraits = [.button]
        accessibilityLabel = modeLabel
    }

    func removeHint() { hintContainer.removeFromSuperview() }
}
