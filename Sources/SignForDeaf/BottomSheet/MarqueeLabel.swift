// BottomSheet/MarqueeLabel.swift

import UIKit

/// A label that smoothly auto-scrolls its text horizontally (with pauses at each
/// end) when the text is wider than the view, otherwise centers it.
/// Ported from the RN library's `MarqueeLabel`.
final class MarqueeLabel: UIView {

    private let textLabel = UILabel()
    private var displayLink: CADisplayLink?
    private var scrollOffset: CGFloat = 0
    private var textWidth: CGFloat = 0
    private var containerWidth: CGFloat = 0
    private var isAnimating = false
    private let scrollSpeed: CGFloat = 30  // points per second
    private let pauseDuration: TimeInterval = 2.0
    private var pauseTimer: Timer?
    private var shouldAnimate = false

    var text: String? {
        didSet {
            textLabel.text = text
            setNeedsLayout()
        }
    }

    var font: UIFont = .systemFont(ofSize: 15, weight: .medium) {
        didSet {
            textLabel.font = font
            setNeedsLayout()
        }
    }

    var textColor: UIColor = .black {
        didSet {
            textLabel.textColor = textColor
        }
    }

    var textAlignment: NSTextAlignment = .center {
        didSet {
            textLabel.textAlignment = textAlignment
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLabel()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLabel()
    }

    private func setupLabel() {
        clipsToBounds = true
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textLabel)

        NSLayoutConstraint.activate([
            textLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            textLabel.heightAnchor.constraint(equalTo: heightAnchor),
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        containerWidth = bounds.width
        textWidth = textLabel.intrinsicContentSize.width

        if textWidth > containerWidth {
            // Text is longer than the container — enable scrolling.
            shouldAnimate = true
            textLabel.frame = CGRect(x: 0, y: 0, width: textWidth, height: bounds.height)
            startAnimating()
        } else {
            // Text fits — center it.
            shouldAnimate = false
            stopAnimating()
            textLabel.frame = CGRect(
                x: (containerWidth - textWidth) / 2, y: 0, width: textWidth, height: bounds.height)
        }
    }

    private func startAnimating() {
        guard shouldAnimate, !isAnimating else { return }
        isAnimating = true
        scrollOffset = 0

        pauseTimer = Timer.scheduledTimer(withTimeInterval: pauseDuration, repeats: false) {
            [weak self] _ in
            self?.startScrolling()
        }
    }

    private func startScrolling() {
        displayLink?.invalidate()
        displayLink = CADisplayLink(target: self, selector: #selector(updateScroll))
        displayLink?.add(to: .main, forMode: .common)
    }

    @objc private func updateScroll() {
        guard shouldAnimate else { return }

        let delta = scrollSpeed / 60.0
        scrollOffset += delta

        let maxOffset = textWidth - containerWidth + 20

        if scrollOffset >= maxOffset {
            displayLink?.invalidate()
            displayLink = nil

            pauseTimer = Timer.scheduledTimer(withTimeInterval: pauseDuration, repeats: false) {
                [weak self] _ in
                self?.resetAndRestart()
            }
        } else {
            textLabel.frame.origin.x = -scrollOffset
        }
    }

    private func resetAndRestart() {
        scrollOffset = 0
        textLabel.frame.origin.x = 0

        pauseTimer = Timer.scheduledTimer(withTimeInterval: pauseDuration, repeats: false) {
            [weak self] _ in
            self?.startScrolling()
        }
    }

    private func stopAnimating() {
        isAnimating = false
        displayLink?.invalidate()
        displayLink = nil
        pauseTimer?.invalidate()
        pauseTimer = nil
        scrollOffset = 0
    }

    deinit {
        stopAnimating()
    }
}
