// TextSelection/TextGestureInstaller.swift

import ObjectiveC
import UIKit

extension UIView {
    private static var sfdInternalKey: UInt8 = 0
    private static var sfdSensitiveKey: UInt8 = 0

    /// Marks a view (and its subtree) as SDK-owned UI, so the tap-to-translate
    /// scanner skips it — otherwise tapping labels inside our own bottom sheet
    /// would trigger a new translation and stack a second sheet.
    var isSignForDeafInternalUI: Bool {
        get { objc_getAssociatedObject(self, &UIView.sfdInternalKey) as? Bool ?? false }
        set {
            objc_setAssociatedObject(
                self, &UIView.sfdInternalKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /// Marks a view (and its subtree) as containing sensitive information. Text
    /// tapped inside a marked subtree is never sent to the translation backend;
    /// the "sensitive content" notice is shown instead.
    public var isSignForDeafSensitive: Bool {
        get { objc_getAssociatedObject(self, &UIView.sfdSensitiveKey) as? Bool ?? false }
        set {
            objc_setAssociatedObject(
                self, &UIView.sfdSensitiveKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /// `true` if this view or any ancestor is marked sensitive.
    var isWithinSignForDeafSensitiveSubtree: Bool {
        var view: UIView? = self
        while let current = view {
            if current.isSignForDeafSensitive { return true }
            view = current.superview
        }
        return false
    }
}

/// Scans the view hierarchy app-wide and attaches a non-consuming single-tap
/// recognizer to every text view (`UITextView`, `UITextField`, `UILabel`, and
/// React Native text views in hybrid apps). The recognizer only acts while
/// tap-to-translate mode is on, so it never interferes with normal touches.
enum TextGestureInstaller {

    private static var started = false
    private static var scanTimer: Timer?
    private static let gestureName = "SignLanguageTapToTranslate"

    static func start() {
        guard !started else {
            scanAllWindows()
            return
        }
        started = true

        let center = NotificationCenter.default
        center.addObserver(
            forName: UIWindow.didBecomeKeyNotification, object: nil, queue: .main
        ) { _ in scanAllWindows() }

        if #available(iOS 13.0, *) {
            center.addObserver(
                forName: UIScene.didActivateNotification, object: nil, queue: .main
            ) { _ in scanAllWindows() }
        }

        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            scanAllWindows()
        }

        DispatchQueue.main.async { scanAllWindows() }
    }

    static func stop() {
        scanTimer?.invalidate()
        scanTimer = nil
    }

    private static func getWindows() -> [UIWindow] {
        let all: [UIWindow]
        if #available(iOS 15.0, *) {
            all = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
        } else {
            all = UIApplication.shared.windows
        }
        // Never scan the floating button's own overlay window.
        return all.filter { !($0 is PassthroughWindow) }
    }

    static func scanAllWindows() {
        guard TextSelectionManager.shared.isSelectionEnabled() else { return }
        for window in getWindows() {
            scan(window)
        }
    }

    private static func scan(_ view: UIView) {
        // Skip the SDK's own UI (e.g. the bottom sheet) so tapping inside it
        // never triggers a new translation.
        if view.isSignForDeafInternalUI { return }

        if isTextView(view) {
            attachTap(to: view)
        }
        for subview in view.subviews {
            scan(subview)
        }
    }

    private static func isTextView(_ view: UIView) -> Bool {
        if view is UITextView { return true }
        if view is UITextField { return true }
        if let label = view as? UILabel { return label.text?.isEmpty == false }
        // React Native text views (hybrid apps only).
        let className = String(describing: type(of: view))
        if className == "RCTTextView" || className.contains("ParagraphComponentView") {
            return true
        }
        return false
    }

    private static func attachTap(to view: UIView) {
        if let gestures = view.gestureRecognizers,
            gestures.contains(where: { $0.name == gestureName }) {
            return
        }
        view.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(
            target: TapToTranslateHandler.shared,
            action: #selector(TapToTranslateHandler.handleTap(_:)))
        tap.name = gestureName
        tap.numberOfTapsRequired = 1
        tap.cancelsTouchesInView = false
        tap.delaysTouchesBegan = false
        tap.delegate = SignLanguageTapGestureDelegate.shared
        view.addGestureRecognizer(tap)
    }
}

// MARK: - Tap Handler

/// Fires only while tap-to-translate mode is enabled; extracts the tapped view's
/// text and forwards it for translation.
final class TapToTranslateHandler: NSObject {

    static let shared = TapToTranslateHandler()

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended,
            TextSelectionManager.shared.isTapToTranslateEnabled(),
            let view = gesture.view,
            let text = Self.extractText(from: view), !text.isEmpty
        else { return }

        // Text tapped inside a subtree the host marked sensitive must never be
        // sent. Register it so the central guard blocks it and shows the notice.
        if view.isWithinSignForDeafSensitiveSubtree {
            SensitiveTextRegistry.shared.register(text)
        }

        TextSelectionManager.shared.handleSelectedText(text)
    }

    /// Best-effort text extraction across UIKit and RN text views.
    static func extractText(from view: UIView) -> String? {
        if let label = view as? UILabel { return label.text }
        if let textView = view as? UITextView { return textView.text }
        if let textField = view as? UITextField { return textField.text }

        // React Native paragraph views expose `attributedText`.
        let attributedSelector = NSSelectorFromString("attributedText")
        if view.responds(to: attributedSelector),
            let result = view.perform(attributedSelector),
            let attributed = result.takeUnretainedValue() as? NSAttributedString,
            !attributed.string.isEmpty {
            return attributed.string
        }
        if let label = view.accessibilityLabel, !label.isEmpty {
            return label
        }
        return findTextInSubviews(view)
    }

    private static func findTextInSubviews(_ view: UIView) -> String? {
        for subview in view.subviews {
            if let label = subview as? UILabel, let t = label.text, !t.isEmpty { return t }
            if let tv = subview as? UITextView, let t = tv.text, !t.isEmpty { return t }
            if let t = findTextInSubviews(subview) { return t }
        }
        return nil
    }
}

// MARK: - Gesture Delegate

/// Lets the tap-to-translate recognizer fire alongside the app's own gesture
/// recognizers (scroll views, buttons), so it never blocks normal interaction.
final class SignLanguageTapGestureDelegate: NSObject, UIGestureRecognizerDelegate {

    static let shared = SignLanguageTapGestureDelegate()

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return true
    }
}
