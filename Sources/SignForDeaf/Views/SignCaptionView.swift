// Views/SignCaptionView.swift

import UIKit

/// The caption: the sentence being translated (docs/06 §"Caption behavior").
///
/// Two lines visible; a longer sentence auto-scrolls vertically (marquee) with a
/// hold at each end. The user may scroll it by hand — auto-scroll pauses and
/// resumes ~4 s later **from where they left off**, not from the top. A new
/// sentence jumps back to the top. Draws no background of its own.
final class SignCaptionView: UIView, UIScrollViewDelegate {

    private let scroll = UIScrollView()
    private let label = UILabel()
    private var displayLink: CADisplayLink?
    private var resumeTimer: Timer?

    private enum Phase { case holdTop, scrolling, holdBottom, rewinding, paused }
    private var phase: Phase = .holdTop
    private var phaseElapsed: CFTimeInterval = 0
    private var lastTimestamp: CFTimeInterval = 0
    private var offset: CGFloat = 0

    private let holdDuration: CFTimeInterval = 1.6
    private let scrollSpeed: CGFloat = 16          // pt/second
    private let rewindDuration: CFTimeInterval = 0.45
    private let resumeDelay: TimeInterval = 4.0    // after the user stops scrolling

    override init(frame: CGRect) {
        super.init(frame: frame)
        isSignForDeafInternalUI = true
        backgroundColor = .clear
        scroll.showsVerticalScrollIndicator = false
        scroll.isScrollEnabled = true
        scroll.alwaysBounceVertical = false
        scroll.backgroundColor = .clear
        scroll.delegate = self
        addSubview(scroll)
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: SignTokens.captionFontSize)
        label.textAlignment = .center
        scroll.addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    var textColor: UIColor = .white {
        didSet { label.textColor = textColor }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        scroll.frame = bounds
        let width = bounds.width - SignTokens.spaceMd * 2
        let size = label.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        label.frame = CGRect(x: SignTokens.spaceMd, y: 0, width: width, height: size.height)
        scroll.contentSize = CGSize(width: bounds.width, height: size.height)
        // Centre vertically when the text fits; otherwise scroll from the top.
        let top = overflow > 0 ? 0 : max(0, (bounds.height - size.height) / 2)
        scroll.contentInset = UIEdgeInsets(top: top, left: 0, bottom: 0, right: 0)
        updateScrollingState()
    }

    /// Set the caption; a new sentence jumps to the top and restarts the cycle.
    func setText(_ text: String?) {
        label.text = text
        resumeTimer?.invalidate()
        offset = 0
        scroll.contentOffset = CGPoint(x: 0, y: overflow > 0 ? 0 : -scroll.contentInset.top)
        phase = .holdTop
        phaseElapsed = 0
        setNeedsLayout()
        layoutIfNeeded()
        updateScrollingState()
    }

    private var overflow: CGFloat {
        max(0, scroll.contentSize.height - bounds.height)
    }

    private func updateScrollingState() {
        if overflow > 0.5, window != nil {
            startLink()
        } else {
            stopLink()
        }
    }

    private func startLink() {
        guard displayLink == nil else { return }
        lastTimestamp = 0
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        if lastTimestamp == 0 { lastTimestamp = link.timestamp; return }
        let dt = link.timestamp - lastTimestamp
        lastTimestamp = link.timestamp
        let travel = overflow
        guard travel > 0 else { return }
        phaseElapsed += dt

        switch phase {
        case .paused:
            return
        case .holdTop:
            if phaseElapsed >= holdDuration { advance(.scrolling) }
        case .scrolling:
            offset = min(travel, scroll.contentOffset.y + scrollSpeed * CGFloat(dt))
            scroll.contentOffset = CGPoint(x: 0, y: offset)
            if offset >= travel { advance(.holdBottom) }
        case .holdBottom:
            if phaseElapsed >= holdDuration { advance(.rewinding) }
        case .rewinding:
            let step = travel / CGFloat(rewindDuration) * CGFloat(dt)
            offset = max(0, scroll.contentOffset.y - step)
            scroll.contentOffset = CGPoint(x: 0, y: offset)
            if offset <= 0 { advance(.holdTop) }
        }
    }

    private func advance(_ next: Phase) {
        phase = next
        phaseElapsed = 0
    }

    // MARK: Manual interaction (pause, then resume from the current position)

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        phase = .paused
        resumeTimer?.invalidate()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { scheduleResume() }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        scheduleResume()
    }

    private func scheduleResume() {
        resumeTimer?.invalidate()
        resumeTimer = Timer.scheduledTimer(withTimeInterval: resumeDelay, repeats: false) { [weak self] _ in
            self?.resumeFromCurrentOffset()
        }
    }

    private func resumeFromCurrentOffset() {
        guard overflow > 0 else { return }
        offset = scroll.contentOffset.y
        // Continue downward from here; if already at the bottom, hold then rewind.
        phase = offset >= overflow - 1 ? .holdBottom : .scrolling
        phaseElapsed = 0
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateScrollingState()
    }

    deinit { stopLink(); resumeTimer?.invalidate() }
}
