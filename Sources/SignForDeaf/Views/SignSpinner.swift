// Views/SignSpinner.swift

import UIKit

/// A three-quarter-arc spinner in the theme's primary color (docs/10 §Playback of
/// the loop — 24 pt, 2.5 pt stroke, centred over the blur).
final class SignSpinner: UIView {

    private let ring = CAShapeLayer()

    var color: UIColor = .white {
        didSet { ring.strokeColor = color.cgColor }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        ring.fillColor = UIColor.clear.cgColor
        ring.strokeColor = color.cgColor
        ring.lineWidth = 2.5
        ring.lineCap = .round
        ring.strokeEnd = 0.75
        layer.addSublayer(ring)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let inset = ring.lineWidth / 2
        let rect = bounds.insetBy(dx: inset, dy: inset)
        ring.frame = bounds
        ring.path = UIBezierPath(ovalIn: rect).cgPath
    }

    func startAnimating() {
        guard ring.animation(forKey: "spin") == nil else { return }
        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.fromValue = 0
        spin.toValue = 2 * Double.pi
        spin.duration = 0.9
        spin.repeatCount = .infinity
        ring.add(spin, forKey: "spin")
    }

    func stopAnimating() {
        ring.removeAnimation(forKey: "spin")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { startAnimating() } else { stopAnimating() }
    }
}
