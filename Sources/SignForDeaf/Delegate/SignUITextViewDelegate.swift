import UIKit

public class SignUITextViewDelegate: NSObject, UITextViewDelegate {
    
    var window: UIWindow?
    private var loadingScreenManager: ScreenManager?

    public override init() {
        if let parentViewController = UIApplication.topViewController() {
            loadingScreenManager = ScreenManager(parentViewController: parentViewController)
        } else {
            print("UIViewController yok. LoadingScreenManager oluşturulamadı.")
        }
        super.init()
    }

    public func textView(_ textView: UITextView, editMenuForTextIn range: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
        // Create custom menu items
        let customAction = UIAction(title: "İşaret Dili", handler: { _ in
            self.customAction(for: textView)
        })
        
        let combinedActions = [customAction] + suggestedActions
        
        return UIMenu(title: "", children: combinedActions)
    }
    
    private func createFullURL(baseURL: String?, videoName: String?) -> String? {
        guard let base = baseURL, !base.isEmpty,
              let name = videoName, !name.isEmpty else { return nil }
        var videoUrl = "\(base)\(name)".replacingOccurrences(of: "http://", with: "https://")
        return videoUrl
    }
    
    private func loadingScreen(open: Bool = true) {
        if (open == true) {
            if let parentViewController = UIApplication.topViewController() {
                loadingScreenManager = ScreenManager(parentViewController: parentViewController)
                loadingScreenManager?.showLoadingScreen()
            } else {
                print("UIViewController yok. ScreenManager oluşturulamadı.")
            }
        } else {
            loadingScreenManager?.hideLoadingScreen()
        }
        
    }
    
    private func errorScreen(open: Bool = true) {
        if (open == true) {
            if let parentViewController = UIApplication.topViewController() {
                loadingScreenManager = ScreenManager(parentViewController: parentViewController)
                loadingScreenManager?.showErrorScreen()
            } else {
                print("UIViewController yok. ScreenManager oluşturulamadı.")
            }
        } else {
            loadingScreenManager?.hideLoadingScreen()
        }
        
    }
    
    private func customAction(for textView: UITextView) {
        loadingScreen()
        guard let selectedTextRange = textView.selectedTextRange else {
                print("Metin seçilmedi.")
                return
            }
        let selectedText = textView.text(in: selectedTextRange) ?? ""
        print("Çevirilecek text seçildi: \(selectedText)")
        URLApiService.shared.getSignVideo(s: selectedText) { result in
            switch result {
            case .success(let signModel):
                if let videoUrl = self.createFullURL(baseURL: signModel.baseURL, videoName: signModel.name) {
                    DispatchQueue.main.async { [self] in
                        loadingScreen(open: false)
                        presentPageSheet(text: selectedText, videoUrl: videoUrl)
                    }
                }
            case .failure(let error):
                if (error == .cancelled) { return }
                DispatchQueue.main.async { [self] in
                    loadingScreen(open: false)
                    errorScreen()
                }
                print("Hata: \(error)")
            }
        }
    }
    
    public func presentPageSheet(text: String, videoUrl: String) {
        let pageSheetVC = SignTranlatePageSheetView()
        pageSheetVC.textToShow = text
        pageSheetVC.videoURL = videoUrl
        if let viewController = UIApplication.topViewController() {
            viewController.present(pageSheetVC, animated: true, completion: nil)
        }
        
    }
    
}
