// Views/SignStageView.swift

import UIKit

/// The avatar area of the player (docs/06 §Anatomy, §"Stage contents by state").
///
/// Shows the translation video, the idle loop (clean or veiled), or a centred
/// failure/blocked message — all inside the stage, so the layout never jumps and
/// the app stays usable. The mark badge sits top-left and is always visible.
///
/// A `content` view clips its children to the corner radius (so the video is
/// rounded), while `self` casts the floating shadow without clipping it — the two
/// cannot live on one layer, since `masksToBounds` would clip the shadow away.
final class SignStageView: UIView {

    let idleLoop = IdleLoopView()
    let video = TranslationVideoView()

    private let content = UIView()
    private let messageScroll = UIScrollView()
    private let messageLabel = UILabel()

    private let markBadge = UIView()
    private let mark = LogoView()

    private var cornerRadius: CGFloat = SignTokens.radiusLarge

    override init(frame: CGRect) {
        super.init(frame: frame)
        isSignForDeafInternalUI = true

        // Rounded, clipping content.
        content.clipsToBounds = true
        content.layer.cornerRadius = cornerRadius
        addSubview(content)

        content.addSubview(idleLoop)
        content.addSubview(video)

        messageScroll.showsVerticalScrollIndicator = false
        messageScroll.alwaysBounceVertical = false
        content.addSubview(messageScroll)
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.font = .systemFont(ofSize: 14)
        messageScroll.addSubview(messageLabel)

        // Mark badge — top-left, spaceXs from each edge (docs/06).
        markBadge.layer.cornerRadius = SignTokens.radiusSmall
        markBadge.clipsToBounds = true
        markBadge.isUserInteractionEnabled = false
        mark.isUserInteractionEnabled = false
        markBadge.addSubview(mark)
        content.addSubview(markBadge)

        // Shadow on the outer (non-clipping) layer.
        layer.shadowColor = SignTokens.floatingShadowColor.cgColor
        layer.shadowOpacity = SignTokens.floatingShadowOpacity
        layer.shadowOffset = SignTokens.floatingShadowOffset
        layer.shadowRadius = SignTokens.floatingShadowRadius
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Match the stage rounding to the theme's corner radius.
    func setCornerRadius(_ radius: CGFloat) {
        cornerRadius = radius
        content.layer.cornerRadius = radius
        idleLoop.layer.cornerRadius = radius
        video.layer.cornerRadius = radius
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        content.frame = bounds
        idleLoop.frame = content.bounds
        video.frame = content.bounds
        messageScroll.frame = content.bounds
        layoutMessage()

        let badgeSize: CGFloat = 28
        markBadge.frame = CGRect(
            x: SignTokens.spaceXs, y: SignTokens.spaceXs, width: badgeSize, height: badgeSize)
        let inset: CGFloat = 5
        mark.frame = markBadge.bounds.insetBy(dx: inset, dy: inset)
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath
    }

    private func layoutMessage() {
        let horizontal = SignTokens.spaceMd
        let maxWidth = content.bounds.width - horizontal * 2
        let size = messageLabel.sizeThatFits(CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
        messageLabel.frame = CGRect(x: horizontal, y: 0, width: maxWidth, height: size.height)
        messageScroll.contentSize = CGSize(width: content.bounds.width, height: size.height)
        // Vertically centre when it fits; otherwise let it scroll from the top.
        let topInset = max(0, (content.bounds.height - size.height) / 2)
        messageScroll.contentInset = UIEdgeInsets(top: topInset, left: 0, bottom: 0, right: 0)
    }

    // MARK: Rendering

    func applyTheme(surface: UIColor, onSurface: UIColor, primary: UIColor) {
        content.backgroundColor = surface
        messageLabel.textColor = onSurface
        // The mark reads as the logo directly on the video (no badge fill), matching
        // the reference. It stays visible over the light top of the signer clips.
        markBadge.backgroundColor = .clear
        mark.logoColor = primary
    }

    func render(state: SignForDeafState, message: String?) {
        // Only one video decoder runs at a time: the idle loop plays while it is
        // on screen (idle/loading) and pauses whenever the translation video (or a
        // message) takes over, so the two never contend and stutter.
        switch state {
        case .idle:
            idleLoop.isHidden = false
            idleLoop.setLoading(false)
            idleLoop.play()
            video.isHidden = true
            setMessage(nil)
        case .loading:
            idleLoop.isHidden = false
            idleLoop.setLoading(true)
            idleLoop.play()
            video.isHidden = true
            setMessage(nil)
        case .ready:
            idleLoop.isHidden = true
            idleLoop.setLoading(false)
            idleLoop.pause()
            video.isHidden = false
            setMessage(nil)
        case .error, .blocked:
            idleLoop.isHidden = true
            idleLoop.setLoading(false)
            idleLoop.pause()
            video.isHidden = true
            setMessage(message)
        }
    }

    private func setMessage(_ text: String?) {
        messageScroll.isHidden = (text == nil)
        messageLabel.text = text
        setNeedsLayout()
    }
}
