// Utils/UIApplication+TopViewController.swift

import UIKit

extension UIApplication {

    /// Walk the presentation/navigation/tab hierarchy to find the currently
    /// visible view controller, used as the presenter for the bottom sheet.
    class func topViewController(
        base: UIViewController? = nil
    ) -> UIViewController? {
        let baseVC: UIViewController?

        if let base = base {
            baseVC = base
        } else {
            if #available(iOS 15.0, *) {
                baseVC = UIApplication.shared.connectedScenes
                    .filter { $0.activationState == .foregroundActive }
                    .compactMap { ($0 as? UIWindowScene)?.keyWindow }
                    .first?.rootViewController
            } else {
                baseVC = UIApplication.shared.windows
                    .first { $0.isKeyWindow }?.rootViewController
            }
        }

        if let nav = baseVC as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }

        if let tab = baseVC as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(base: selected)
        }

        if let presented = baseVC?.presentedViewController {
            return topViewController(base: presented)
        }

        return baseVC
    }
}
