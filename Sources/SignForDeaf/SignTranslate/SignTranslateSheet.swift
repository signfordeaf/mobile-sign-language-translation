import UIKit
import AVKit

class SignTranlatePageSheetView: UIViewController {
    var textToShow: String = ""
    var videoURL: String = ""
    var videoPlayerView = VideoPlayerView()
    private var appBarView: UIView!
    private var closeButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        
        // App Bar'ı ekleyelim
        setupAppBar()
        
        // VideoPlayerView'i ekleyelim
        setupVideoPlayerView()
        
        // Metin etiketini ekleyelim
        addViewSignTextLabel()
    }
    
    func setupAppBar() {
        // App Bar'ı oluştur
        appBarView = UIView()
        appBarView.backgroundColor = .white
        appBarView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(appBarView)
        
        // Resim ekleyelim
        let imageView = UIImageView()
        
        if let image = UIImage(named: "logoHead", in: Bundle.module, compatibleWith: nil) {
            imageView.image = image
            }
            imageView.contentMode = .scaleAspectFit
            imageView.translatesAutoresizingMaskIntoConstraints = false
            appBarView.addSubview(imageView)
        
        // Başlık ekleyelim
        let titleLabel = UILabel()
        titleLabel.text = "Engelsiz Çeviri"
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textColor = .purple
        appBarView.addSubview(titleLabel)
        
        // Kapama butonunu ekleyelim
        closeButton = UIButton(type: .system)
        closeButton.setTitle("X", for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        closeButton.tintColor = .purple
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeSheet), for: .touchUpInside)
        appBarView.addSubview(closeButton)
        
        // App Bar için kısıtlamaları ekleyelim
        NSLayoutConstraint.activate([
            appBarView.topAnchor.constraint(equalTo: view.topAnchor),
            appBarView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            appBarView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            appBarView.heightAnchor.constraint(equalToConstant: 60),

            imageView.leadingAnchor.constraint(equalTo: appBarView.leadingAnchor, constant: 24),
            imageView.centerYAnchor.constraint(equalTo: appBarView.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 30),
            imageView.heightAnchor.constraint(equalToConstant: 30),
            
            titleLabel.centerXAnchor.constraint(equalTo: appBarView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: appBarView.centerYAnchor),
            
            closeButton.trailingAnchor.constraint(equalTo: appBarView.trailingAnchor, constant: -16),
            closeButton.centerYAnchor.constraint(equalTo: appBarView.centerYAnchor)
        ])
    }
    
    func setupVideoPlayerView() {
        // VideoPlayerView oluştur
        videoPlayerView = VideoPlayerView()
        videoPlayerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(videoPlayerView)
        
        // VideoPlayerView için kısıtlamaları ekleyelim
        NSLayoutConstraint.activate([
            videoPlayerView.topAnchor.constraint(equalTo: appBarView.bottomAnchor),
            videoPlayerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            videoPlayerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            videoPlayerView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -80)
        ])
        
        // Videoyu başlatmak için URL sağla
        if let videoURL = URL(string: videoURL) {
            videoPlayerView.configurePlayer(with: videoURL)
        } else {
            print("Video URL geçersiz.")
        }
    }
    
    func addViewSignTextLabel() {
        let label = UILabel()
        label.text = textToShow
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = .zero
        
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -30),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            label.heightAnchor.constraint(equalToConstant: 30)
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Yarım ekran olacak şekilde boyutu ayarlama
        if #available(iOS 15.0, *) {
            if let sheet = sheetPresentationController {
                sheet.detents = [.medium()]
            }
        }
    }

    @objc func closeSheet() {
        dismiss(animated: true, completion: nil)
    }
}
