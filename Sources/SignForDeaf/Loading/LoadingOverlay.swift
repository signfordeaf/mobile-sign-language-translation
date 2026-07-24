// Loading/LoadingOverlay.swift

import UIKit

/// A full-screen, blurred "please wait" overlay shown while a translation is
/// loading: a theme-colored circular spinner with the corporate logo in its
/// center, a loading caption, and a top-right ✕ cancel button.
///
/// Presented `.overFullScreen` over the bottom sheet so its blur samples the
/// content behind it. When the video is ready (or an error occurs) it is
/// dismissed, revealing the sheet with the video already playing.
final class LoadingOverlayController: UIViewController {

    // MARK: - Config
    private let ringDiameter: CGFloat = 92
    private let logoSize: CGFloat = 42
    /// How strong the blur reads. Lower = lighter/subtler, background more
    /// visible (0…1).
    private let blurStrength: CGFloat = 0.55

    private var primaryColor: UIColor = SignForDeafTheme.defaultPrimary
    private var loadingText: String = ""
    private var cancelA11y: String = ""

    /// Called when the ✕ cancel button is tapped.
    var onCancel: (() -> Void)?

    private var spinner: SpinnerRingView?

    // MARK: - Setup

    func configure(primaryColor: UIColor, loadingText: String, cancelA11y: String) {
        self.primaryColor = primaryColor
        self.loadingText = loadingText
        self.cancelA11y = cancelA11y
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        buildContents()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        spinner?.startAnimating()
    }

    private func buildContents() {
        // Blur backdrop — samples the sheet/app behind this overlay. A reduced
        // alpha keeps it light so the background stays visible.
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialLight))
        blur.alpha = blurStrength
        blur.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(blur)
        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: view.topAnchor),
            blur.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // Spinner ring with the corporate logo in the center.
        let ring = SpinnerRingView(diameter: ringDiameter, color: primaryColor)
        ring.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(ring)

        let logo = LogoView()
        logo.backgroundColor = .clear
        logo.logoColor = primaryColor
        logo.isUserInteractionEnabled = false
        logo.translatesAutoresizingMaskIntoConstraints = false
        ring.addSubview(logo)

        // Loading caption.
        let label = UILabel()
        label.text = loadingText
        label.textColor = primaryColor
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        // Cancel (✕) top-right.
        let cancel = UIButton(type: .system)
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
        cancel.setImage(UIImage(systemName: "xmark", withConfiguration: symbolConfig), for: .normal)
        cancel.tintColor = primaryColor
        cancel.accessibilityLabel = cancelA11y
        cancel.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cancel)

        NSLayoutConstraint.activate([
            ring.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            ring.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            ring.widthAnchor.constraint(equalToConstant: ringDiameter),
            ring.heightAnchor.constraint(equalToConstant: ringDiameter),

            logo.centerXAnchor.constraint(equalTo: ring.centerXAnchor),
            logo.centerYAnchor.constraint(equalTo: ring.centerYAnchor),
            logo.widthAnchor.constraint(equalToConstant: logoSize),
            logo.heightAnchor.constraint(equalToConstant: logoSize),

            label.topAnchor.constraint(equalTo: ring.bottomAnchor, constant: 20),
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),

            cancel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            cancel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            cancel.widthAnchor.constraint(equalToConstant: 44),
            cancel.heightAnchor.constraint(equalToConstant: 44),
        ])

        self.spinner = ring
    }

    @objc private func cancelTapped() {
        onCancel?()
    }
}

/// A circular arc that spins continuously — the progress indicator behind the
/// logo. Drawn with a `CAShapeLayer` and rotated via a `CABasicAnimation`.
final class SpinnerRingView: UIView {

    private let shape = CAShapeLayer()
    private let lineWidth: CGFloat = 4

    init(diameter: CGFloat, color: UIColor) {
        super.init(frame: CGRect(x: 0, y: 0, width: diameter, height: diameter))
        backgroundColor = .clear
        shape.fillColor = UIColor.clear.cgColor
        shape.strokeColor = color.cgColor
        shape.lineWidth = lineWidth
        shape.lineCap = .round
        shape.strokeStart = 0
        shape.strokeEnd = 0.75  // three-quarter arc
        layer.addSublayer(shape)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let inset = lineWidth / 2
        let rect = bounds.insetBy(dx: inset, dy: inset)
        shape.frame = bounds
        shape.path = UIBezierPath(ovalIn: rect).cgPath
    }

    func startAnimating() {
        guard shape.animation(forKey: "spin") == nil else { return }
        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.fromValue = 0
        spin.toValue = 2 * Double.pi
        spin.duration = 0.9
        spin.repeatCount = .infinity
        spin.isRemovedOnCompletion = false
        shape.add(spin, forKey: "spin")
    }

    func stopAnimating() {
        shape.removeAnimation(forKey: "spin")
    }
}
