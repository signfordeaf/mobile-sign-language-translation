import UIKit

public class SignForDeafSign {

    public var customDelegate = SignUITextViewDelegate()
    
    public init(customDelegate: SignUITextViewDelegate = SignUITextViewDelegate()) {
        self.customDelegate = customDelegate
    }
    
    public func activate(apiKey: String, requestUrl: String) {
        AuthService.shared.setApiKey(apiKey: apiKey)
        AuthService.shared.setRequestUrl(requestUrl: requestUrl)
    }

    public func signTranslateInMenu(in view: UIView?) {
        guard AuthService.shared.getApiKey() != "" else { return }
        
        guard let view = view else { return }
        
        for subview in view.subviews {
            if let textView = subview as? UITextView {
                // Customize the context menu for UITextView
                textView.delegate = customDelegate
            } else {
                signTranslateInMenu(in: subview)
            }
        }
    }
}
