import UIKit

class ScreenManager {
    
    private var loadingView: UIView?
    private weak var parentViewController: UIViewController?
    
    init(parentViewController: UIViewController) {
        self.parentViewController = parentViewController
        print(self.parentViewController)
    }
    
    public func showLoadingScreen() {
            guard let parentViewController = parentViewController else { return }
        
            // Loading ekranını oluştur
            let loadingView = UIView(frame: parentViewController.view.bounds)
            loadingView.backgroundColor = UIColor.black.withAlphaComponent(0.6)
            loadingView.tag = 999 // Bu, yükleme ekranını tanımlamak için kullanılır
            
            // Activity Indicator (Yükleme Göstergesi) Oluştur
        let activityIndicator = UIActivityIndicatorView(style: .large)
            activityIndicator.center = loadingView.center
            activityIndicator.color = .white
            activityIndicator.startAnimating()
            loadingView.addSubview(activityIndicator)
            
        
            // Resim Ekleyin
            let imageView = UIImageView()
            if let image = UIImage(named: "logoHead", in: Bundle.module, compatibleWith: nil) {
                imageView.image = image
            } else {
                print("Resim bulunamadı")
                
            }
            imageView.contentMode = .scaleAspectFit
            imageView.translatesAutoresizingMaskIntoConstraints = false
            loadingView.addSubview(imageView)
            
            // Resmi Indicator'ın üstüne yerleştirin
            NSLayoutConstraint.activate([
                imageView.centerXAnchor.constraint(equalTo: activityIndicator.centerXAnchor),
                imageView.centerYAnchor.constraint(equalTo: activityIndicator.centerYAnchor,constant: -100),
                imageView.widthAnchor.constraint(equalToConstant: 80),
                imageView.heightAnchor.constraint(equalToConstant: 80)
            ])
            
            // Kapatma Butonu Ekleyin
        let closeButton = UIButton(type: .system)
                closeButton.setTitle("X", for: .normal)
                closeButton.setTitleColor(.white, for: .normal)
                closeButton.translatesAutoresizingMaskIntoConstraints = false
                closeButton.addTarget(self, action: #selector(dismissLoadingScreen), for: .touchUpInside)
                loadingView.addSubview(closeButton)
                
                // Butonun Konumunu Ayarla
                NSLayoutConstraint.activate([
                    closeButton.trailingAnchor.constraint(equalTo: loadingView.trailingAnchor, constant: -16),
                    closeButton.topAnchor.constraint(equalTo: loadingView.topAnchor, constant: 50),
                    closeButton.widthAnchor.constraint(equalToConstant: 60),
                    closeButton.heightAnchor.constraint(equalToConstant: 60)
                ])
            
            self.loadingView = loadingView
            parentViewController.view.addSubview(loadingView)
        }
    
        public func showErrorScreen() {
            guard let parentViewController = parentViewController else { return }
            // Loading ekranını oluştur
            let loadingView = UIView(frame: parentViewController.view.bounds)
            loadingView.backgroundColor = UIColor.black.withAlphaComponent(0.6)
            loadingView.tag = 999 // Bu, yükleme ekranını tanımlamak için kullanılır
            
            // Activity Indicator (Yükleme Göstergesi) Oluştur
            let errorLabel = UILabel()
            errorLabel.text = "Çeviri işlemi şu anda gerçekleştirilemiyor. Lütfen daha sonra tekrar deneyiniz."
            errorLabel.textColor = .white
            errorLabel.textAlignment = .center
            errorLabel.numberOfLines = 0
            errorLabel.translatesAutoresizingMaskIntoConstraints = false
            loadingView.addSubview(errorLabel)
            NSLayoutConstraint.activate([
                errorLabel.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),
                errorLabel.centerYAnchor.constraint(equalTo: loadingView.centerYAnchor),
                errorLabel.leadingAnchor.constraint(equalTo: loadingView.leadingAnchor, constant: 20),
                errorLabel.trailingAnchor.constraint(equalTo: loadingView.trailingAnchor, constant: -20)
            ])
        
            // Resim Ekleyin
            let imageView = UIImageView()
            if let image = UIImage(named: "logoHead", in: Bundle.module, compatibleWith: nil) {
                imageView.image = image
            } else {
                print("Resim bulunamadı")
                
            }
            imageView.contentMode = .scaleAspectFit
            imageView.translatesAutoresizingMaskIntoConstraints = false
            loadingView.addSubview(imageView)
            
            // Resmi Indicator'ın üstüne yerleştirin
            NSLayoutConstraint.activate([
                imageView.centerXAnchor.constraint(equalTo: errorLabel.centerXAnchor),
                imageView.centerYAnchor.constraint(equalTo: errorLabel.centerYAnchor,constant: -100),
                imageView.widthAnchor.constraint(equalToConstant: 80),
                imageView.heightAnchor.constraint(equalToConstant: 80)
            ])
            
            // Kapatma Butonu Ekleyin
        let closeButton = UIButton(type: .system)
                closeButton.setTitle("X", for: .normal)
                closeButton.setTitleColor(.white, for: .normal)
                closeButton.translatesAutoresizingMaskIntoConstraints = false
                closeButton.addTarget(self, action: #selector(dismissErrorScreen), for: .touchUpInside)
                loadingView.addSubview(closeButton)
                
                // Butonun Konumunu Ayarla
                NSLayoutConstraint.activate([
                    closeButton.trailingAnchor.constraint(equalTo: loadingView.trailingAnchor, constant: -16),
                    closeButton.topAnchor.constraint(equalTo: loadingView.topAnchor, constant: 50),
                    closeButton.widthAnchor.constraint(equalToConstant: 60),
                    closeButton.heightAnchor.constraint(equalToConstant: 60)
                ])
            
            self.loadingView = loadingView
            parentViewController.view.addSubview(loadingView)
        }
    
    
        
        @objc private func dismissLoadingScreen() {
            URLApiService.shared.cancelRequest()
            hideLoadingScreen()
        }
    
        @objc private func dismissErrorScreen() {
            hideLoadingScreen()
        }
    
    func hideLoadingScreen() {
        loadingView?.removeFromSuperview()
        loadingView = nil
    }
}
