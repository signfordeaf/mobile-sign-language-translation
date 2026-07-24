// TextSelection/TextSelectionManager.swift

import UIKit

protocol TextSelectionManagerDelegate: AnyObject {
    func didSelectText(_ text: String)
}

/// Holds the tap-to-translate state and routes tapped text to the delegate.
/// (The React library also exposed a selection menu; this SDK uses only the
/// floating button + tap-to-translate mode.)
final class TextSelectionManager: NSObject {

    static let shared = TextSelectionManager()

    weak var delegate: TextSelectionManagerDelegate?
    private var isEnabled: Bool = false
    private var tapToTranslateEnabled: Bool = false

    private override init() {
        super.init()
    }

    func configure(delegate: TextSelectionManagerDelegate) {
        self.delegate = delegate
        self.isEnabled = true
    }

    func disable() {
        self.isEnabled = false
        self.tapToTranslateEnabled = false
    }

    func isSelectionEnabled() -> Bool { isEnabled }

    /// When enabled, a single tap on any text view translates it immediately.
    func setTapToTranslateEnabled(_ enabled: Bool) {
        tapToTranslateEnabled = enabled
    }

    func isTapToTranslateEnabled() -> Bool { tapToTranslateEnabled }

    /// Route a piece of text to the delegate for translation.
    func handleSelectedText(_ text: String) {
        guard !text.isEmpty, isEnabled else { return }
        delegate?.didSelectText(text)
    }
}
