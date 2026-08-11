// Integration/SignOverlayWindow.swift

import UIKit

/// The SDK's overlay window (docs/02 §"What the integration layer must provide").
///
/// Hosts three independent layers — the tap catcher (bottom), the floating button,
/// and the player (top) — above the host app. Touches that land on none of them
/// pass straight through to the app, so the SDK never steals a tap it does not own.
final class SignOverlayWindow: UIWindow {

    override init(windowScene: UIWindowScene) {
        super.init(windowScene: windowScene)
        commonInit()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func commonInit() {
        backgroundColor = .clear
        windowLevel = .alert + 1
        let root = UIViewController()
        root.view.backgroundColor = .clear
        rootViewController = root
        isHidden = false
    }

    /// The container the SDK adds its layers to.
    var container: UIView { rootViewController!.view }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        // The bare root view (background) means nothing here wants the touch —
        // pass it through to the host app.
        if hit === self || hit === rootViewController?.view { return nil }
        return hit
    }
}

/// Finds the host app's key window, never the SDK's own overlay.
enum HostWindow {
    static func keyWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap { $0.windows }.filter { !($0 is SignOverlayWindow) }
        return windows.first { $0.isKeyWindow } ?? windows.first
    }

    static func activeScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }
}
