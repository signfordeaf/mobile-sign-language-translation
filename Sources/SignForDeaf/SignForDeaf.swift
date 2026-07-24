// SignForDeaf.swift

import UIKit

/// Entry point for the SignForDeaf sign language translation SDK.
///
/// Configure once at app startup. A floating, AssistiveTouch-style button then
/// appears on screen; tapping it turns on "tap-to-translate" mode, and a single
/// tap on any text plays its sign language translation in a bottom sheet.
///
/// ```swift
/// SignForDeaf.shared.configure(
///     SignForDeafConfig(
///         apiKey: "YOUR_API_KEY",
///         apiUrl: "https://kor01rp02.signfordeaf.com",
///         language: .turkish
///     )
/// )
/// ```
public final class SignForDeaf {

    /// Shared singleton. Use this to configure and control the SDK.
    public static let shared = SignForDeaf()

    private var config: SignForDeafConfig?
    private var apiService: SignLanguageAPIService?
    private var bottomSheet: SignBottomSheet?
    private var loadingOverlayVC: LoadingOverlayController?
    private let floatingButton = FloatingButtonController()
    private var isModuleEnabled = false

    private init() {}

    // MARK: - Public API

    /// Whether the SDK is currently configured and enabled.
    public var isEnabled: Bool { isModuleEnabled }

    /// Whether tap-to-translate mode is currently active.
    public private(set) var isTapToTranslateActive = false

    /// Called (on the main thread) when a translation is blocked because the
    /// text was detected as sensitive. The offending text is passed in. Use it
    /// to log or react; the SDK already shows the user a notice.
    public var onSensitiveBlocked: ((String) -> Void)?

    /// Configure the SDK once, at the root of the app. Shows the floating button
    /// (unless disabled in config). Safe to call again to update configuration.
    public func configure(_ config: SignForDeafConfig) {
        onMain { [weak self] in
            guard let self = self else { return }
            self.config = config
            self.apiService = SignLanguageAPIService(config: config)
            self.isModuleEnabled = true

            TextSelectionManager.shared.configure(delegate: self)
            TextGestureInstaller.start()

            self.floatingButton.onToggle = { [weak self] active in
                self?.setTapToTranslateActive(active)
            }

            if config.showFloatingButton {
                self.showFloatingButton()
            }
        }
    }

    /// Re-enable the SDK after `disable()`.
    public func enable() {
        onMain { [weak self] in
            guard let self = self, let config = self.config else { return }
            self.isModuleEnabled = true
            TextSelectionManager.shared.configure(delegate: self)
            TextGestureInstaller.start()
            if config.showFloatingButton {
                self.showFloatingButton()
            }
        }
    }

    /// Disable the SDK: hides the floating button and stops tap-to-translate.
    public func disable() {
        onMain { [weak self] in
            guard let self = self else { return }
            self.isModuleEnabled = false
            self.isTapToTranslateActive = false
            TextSelectionManager.shared.disable()
            TextGestureInstaller.stop()
            self.floatingButton.hide()
        }
    }

    /// Show the floating tap-to-translate button.
    public func showFloatingButton() {
        onMain { [weak self] in
            guard let self = self, let config = self.config else { return }
            self.floatingButton.show(
                appearance: config.floatingButton.resolved(
                    themePrimary: config.theme.primaryUIColor),
                hintText: config.language.strings.tapToTranslateHint)
            self.floatingButton.setActive(self.isTapToTranslateActive)
        }
    }

    /// Hide the floating button.
    public func hideFloatingButton() {
        onMain { [weak self] in
            self?.floatingButton.hide()
        }
    }

    /// Turn tap-to-translate mode on or off programmatically.
    public func setTapToTranslateActive(_ active: Bool) {
        onMain { [weak self] in
            guard let self = self else { return }
            self.isTapToTranslateActive = active
            TextSelectionManager.shared.setTapToTranslateEnabled(active)
            self.floatingButton.setActive(active)
            // Make sure freshly visible text views get the tap recognizer.
            TextGestureInstaller.scanAllWindows()
        }
    }

    /// Programmatically translate a piece of text and present the bottom sheet.
    public func translate(_ text: String) {
        onMain { [weak self] in
            self?.presentSheetAndTranslate(text: text)
        }
    }

    // MARK: - Translation Flow

    private func presentSheetAndTranslate(text: String) {
        guard let config = config,
            let viewController = UIApplication.topViewController()
        else { return }

        // Sensitive-data protection (runs first): if the text looks sensitive,
        // no request is ever sent — show the blocked notice instead.
        if config.sensitiveFilteringEnabled,
            SensitiveDataGuard.isSensitive(text, extraPatterns: config.compiledSensitivePatterns) {
            onSensitiveBlocked?(text)
            presentBlockedNotice(text: text, from: viewController, config: config)
            return
        }

        // Never stack a second sheet while one is already on screen.
        if let existing = bottomSheet,
            existing.presentingViewController != nil || existing.isBeingPresented {
            return
        }

        let strings = config.language.strings
        let title = strings.businessName

        let sheet = SignBottomSheet.present(
            from: viewController,
            videoURL: "",
            text: text,
            title: title,
            strings: strings,
            primaryColor: config.theme.primaryUIColor,
            textColor: config.theme.textUIColor,
            onDismiss: { [weak self] in
                self?.apiService?.cancelRequest()
                self?.loadingOverlayVC = nil
                self?.bottomSheet = nil
            },
            onRetry: { [weak self] in
                self?.presentLoadingOverlay()
                self?.startTranslation(text: text)
            },
            completion: { [weak self] in
                // Present the blurred waiting overlay over the sheet, then start
                // translating. The sheet loads behind the blur and is revealed
                // when the video is ready (via onLoadingFinished).
                self?.presentLoadingOverlay()
                self?.startTranslation(text: text)
            })

        // Dismiss the overlay the moment loading resolves (video ready OR error),
        // revealing the sheet behind it.
        sheet.onLoadingFinished = { [weak self] in
            self?.hideLoadingOverlay()
        }

        self.bottomSheet = sheet
    }

    /// Present the "sensitive content cannot be translated" notice. No network
    /// request is made.
    private func presentBlockedNotice(
        text: String, from viewController: UIViewController, config: SignForDeafConfig
    ) {
        // Never stack a second sheet while one is already on screen.
        if let existing = bottomSheet,
            existing.presentingViewController != nil || existing.isBeingPresented {
            return
        }

        let strings = config.language.strings
        let sheet = SignBottomSheet.presentBlocked(
            from: viewController,
            text: text,
            title: strings.businessName,
            message: strings.sensitiveBlocked,
            strings: strings,
            primaryColor: config.theme.primaryUIColor,
            textColor: config.theme.textUIColor,
            onDismiss: { [weak self] in
                self?.bottomSheet = nil
            })

        self.bottomSheet = sheet
    }

    /// Present the blurred loading overlay (spinner + logo + ✕ cancel) over the
    /// bottom sheet.
    private func presentLoadingOverlay() {
        guard let config = config, let sheet = bottomSheet else { return }
        // Don't stack two overlays.
        if loadingOverlayVC != nil { return }

        let strings = config.language.strings
        let overlay = LoadingOverlayController()
        overlay.configure(
            primaryColor: config.theme.primaryUIColor,
            loadingText: strings.loading,
            cancelA11y: strings.close)
        overlay.onCancel = { [weak self] in self?.cancelTranslation() }
        overlay.modalPresentationStyle = .overFullScreen
        overlay.modalTransitionStyle = .crossDissolve
        loadingOverlayVC = overlay
        // Hide the sheet while loading so the (light) blur reveals the clean app
        // behind, not the sheet's own loading UI.
        sheet.view.alpha = 0
        sheet.present(overlay, animated: true)
    }

    /// Dismiss the loading overlay, revealing the sheet with a bottom-to-top
    /// slide (it was hidden behind the overlay while loading).
    private func hideLoadingOverlay() {
        loadingOverlayVC?.dismiss(animated: true) { [weak self] in
            self?.bottomSheet?.revealWithSlideUp()
        }
        loadingOverlayVC = nil
    }

    /// Cancel from the overlay's ✕: abort the request and dismiss both the
    /// overlay and the sheet behind it.
    private func cancelTranslation() {
        apiService?.cancelRequest()
        loadingOverlayVC = nil
        // Dismissing the sheet also dismisses the overlay it presented.
        bottomSheet?.dismiss(animated: true)
        bottomSheet = nil
    }

    private func startTranslation(text: String) {
        guard let apiService = apiService else { return }

        apiService.getSignVideo(text: text) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self, let sheet = self.bottomSheet else { return }
                switch result {
                case .success(let model):
                    if let videoUrl = model.videoUrl {
                        sheet.updateVideoURL(videoUrl)
                    } else {
                        sheet.showTranslationError()
                    }
                case .failure(let error):
                    if error == .cancelled { return }
                    sheet.showTranslationError()
                }
            }
        }
    }

    private func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }
}

// MARK: - TextSelectionManagerDelegate

extension SignForDeaf: TextSelectionManagerDelegate {
    func didSelectText(_ text: String) {
        presentSheetAndTranslate(text: text)
    }
}
