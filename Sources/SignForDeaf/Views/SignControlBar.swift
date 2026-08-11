// Views/SignControlBar.swift

import UIKit

/// A 44 pt control button — the one tap-target size for every control (docs/05).
final class SignControlButton: UIButton {
    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: SignTokens.controlSize),
            heightAnchor.constraint(equalToConstant: SignTokens.controlSize),
        ])
        adjustsImageWhenHighlighted = false
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setSymbol(_ name: String, pointSize: CGFloat = SignTokens.iconSize) {
        let cfg = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
        setImage(UIImage(systemName: name, withConfiguration: cfg), for: .normal)
    }
}

/// A gentler play/pause glyph size for the control bar.
private let playGlyphSize: CGFloat = 20

/// The control row: play/pause plus the enabled optional controls (docs/06).
/// Transparent — it sits on the primary-colored control block.
final class SignControlBar: UIView {

    let playPause = SignControlButton()
    let speed = UIButton(type: .system)
    let loop = SignControlButton()
    let contact = SignControlButton()

    var onPlayPause: (() -> Void)?
    var onSpeed: (() -> Void)?
    var onLoop: (() -> Void)?
    var onContact: (() -> Void)?

    private let stack = UIStackView()
    private var onPrimary: UIColor = .white

    override init(frame: CGRect) {
        super.init(frame: frame)
        isSignForDeafInternalUI = true

        // Speed pill — a rounded rectangle with a subtle outline (reference look).
        speed.translatesAutoresizingMaskIntoConstraints = false
        speed.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        speed.contentEdgeInsets = UIEdgeInsets(top: 0, left: SignTokens.spaceMd, bottom: 0, right: SignTokens.spaceMd)
        speed.layer.cornerRadius = 14
        speed.layer.borderWidth = 1
        NSLayoutConstraint.activate([
            speed.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            speed.heightAnchor.constraint(equalToConstant: 32),
        ])

        playPause.setSymbol("play.fill", pointSize: playGlyphSize)
        loop.setSymbol("repeat", pointSize: 20)
        contact.setSymbol("envelope", pointSize: 20)

        // Controls spread across the bar with the speed pill centred (equal centres).
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .equalCentering
        stack.spacing = SignTokens.spaceSm
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: SignTokens.spaceLg),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -SignTokens.spaceLg),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        playPause.addTarget(self, action: #selector(tapPlay), for: .touchUpInside)
        speed.addTarget(self, action: #selector(tapSpeed), for: .touchUpInside)
        loop.addTarget(self, action: #selector(tapLoop), for: .touchUpInside)
        contact.addTarget(self, action: #selector(tapContact), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(showSpeed: Bool, showLoop: Bool, showContact: Bool) {
        stack.arrangedSubviews.forEach { stack.removeArrangedSubview($0); $0.removeFromSuperview() }
        stack.addArrangedSubview(playPause)
        if showSpeed { stack.addArrangedSubview(speed) }
        if showLoop { stack.addArrangedSubview(loop) }
        if showContact { stack.addArrangedSubview(contact) }
    }

    func render(playbackAvailable: Bool, isPlaying: Bool, speedValue: Double, isLooping: Bool, onPrimary: UIColor) {
        self.onPrimary = onPrimary
        playPause.tintColor = onPrimary
        playPause.setSymbol(isPlaying ? "pause.fill" : "play.fill", pointSize: playGlyphSize)
        // Play is disabled until the video is ready; speed and loop are not.
        playPause.isEnabled = playbackAvailable
        playPause.alpha = playbackAvailable ? 1 : SignTokens.disabledOpacity

        speed.setTitleColor(onPrimary, for: .normal)
        speed.backgroundColor = onPrimary.withAlphaComponent(0.08)
        speed.layer.borderColor = onPrimary.withAlphaComponent(0.35).cgColor
        speed.setTitle(formatSpeed(speedValue), for: .normal)

        loop.tintColor = onPrimary
        loop.alpha = isLooping ? 1 : SignTokens.disabledOpacity

        contact.tintColor = onPrimary
    }

    private func formatSpeed(_ value: Double) -> String {
        // Always one decimal to match the reference ("1.0x", "1.2x", "1.5x", "2.0x").
        String(format: "%.1fx", value)
    }

    @objc private func tapPlay() { onPlayPause?() }
    @objc private func tapSpeed() { onSpeed?() }
    @objc private func tapLoop() { onLoop?() }
    @objc private func tapContact() { onContact?() }
}

/// The window pill hanging above the stage's top-right corner (docs/06 §Anatomy).
final class WindowPill: UIView {
    let collapse = SignControlButton()
    let close = SignControlButton()
    private let divider = UIView()
    var onCollapse: (() -> Void)?
    var onClose: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isSignForDeafInternalUI = true
        layer.cornerRadius = SignTokens.radiusLarge // rounded square (not a capsule)
        clipsToBounds = false
        applyPillShadow(self)

        collapse.setSymbol("chevron.down")
        close.setSymbol("xmark")
        let stack = UIStackView(arrangedSubviews: [collapse, close])
        stack.axis = .horizontal
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        divider.isUserInteractionEnabled = false
        addSubview(divider)
        collapse.addTarget(self, action: #selector(tapCollapse), for: .touchUpInside)
        close.addTarget(self, action: #selector(tapClose), for: .touchUpInside)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutDivider(divider, at: close.frame.minX, height: bounds.height)
    }

    func applyTint(_ color: UIColor, background: UIColor) {
        collapse.tintColor = color
        close.tintColor = color
        divider.backgroundColor = color.withAlphaComponent(0.18)
        backgroundColor = background
    }

    @objc private func tapCollapse() { onCollapse?() }
    @objc private func tapClose() { onClose?() }
}

/// Positions a 1 pt vertical divider centred on `x`, inset from top and bottom.
private func layoutDivider(_ divider: UIView, at x: CGFloat, height: CGFloat) {
    let inset: CGFloat = 12
    divider.frame = CGRect(x: x - 0.5, y: inset, width: 1, height: max(0, height - inset * 2))
}

/// The collapsed player: a single 132×44 bar with the mark, expand and close
/// (docs/06 §"Collapsed state").
final class CollapsedBar: UIView {
    private let mark = LogoView()
    let expand = SignControlButton()
    let close = SignControlButton()
    private let divider = UIView()
    var onExpand: (() -> Void)?
    var onClose: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isSignForDeafInternalUI = true
        layer.cornerRadius = SignTokens.radiusLarge // rounded square (not a capsule)
        clipsToBounds = false
        applyPillShadow(self)

        mark.isUserInteractionEnabled = false
        expand.setSymbol("chevron.up")
        close.setSymbol("xmark")

        let markContainer = UIView()
        markContainer.translatesAutoresizingMaskIntoConstraints = false
        markContainer.addSubview(mark)
        NSLayoutConstraint.activate([
            markContainer.widthAnchor.constraint(equalToConstant: SignTokens.controlSize),
            markContainer.heightAnchor.constraint(equalToConstant: SignTokens.controlSize),
        ])

        let stack = UIStackView(arrangedSubviews: [markContainer, expand, close])
        stack.axis = .horizontal
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        divider.isUserInteractionEnabled = false
        addSubview(divider)
        expand.addTarget(self, action: #selector(tapExpand), for: .touchUpInside)
        close.addTarget(self, action: #selector(tapClose), for: .touchUpInside)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let inset: CGFloat = 11
        mark.frame = CGRect(x: inset, y: inset,
                            width: SignTokens.controlSize - inset * 2,
                            height: SignTokens.controlSize - inset * 2)
        layoutDivider(divider, at: close.frame.minX, height: bounds.height)
    }

    func applyTint(_ color: UIColor, background: UIColor) {
        mark.logoColor = color
        expand.tintColor = color
        close.tintColor = color
        divider.backgroundColor = color.withAlphaComponent(0.18)
        backgroundColor = background
    }

    @objc private func tapExpand() { onExpand?() }
    @objc private func tapClose() { onClose?() }
}

private func applyPillShadow(_ view: UIView) {
    view.layer.shadowColor = SignTokens.pillShadowColor.cgColor
    view.layer.shadowOpacity = SignTokens.pillShadowOpacity
    view.layer.shadowOffset = SignTokens.pillShadowOffset
    view.layer.shadowRadius = SignTokens.pillShadowRadius
}
