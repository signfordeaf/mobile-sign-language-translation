import UIKit
import AVKit

class VideoPlayerView: UIView {
    var playerController: AVPlayerLayer?

    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    func configurePlayer(with url: URL) {
        let player = AVPlayer(url: url)
        playerController = AVPlayerLayer(player: player)
        playerController?.frame = self.bounds
        playerController?.videoGravity = .resizeAspect
        if let playerLayer = playerController {
            self.layer.addSublayer(playerLayer)
        }
        
        // Videoyu başlat
        player.play()
        
        // Videoyu sürekli döngüye almak için dinleyici ekle
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(playerDidFinishPlaying),
                                               name: .AVPlayerItemDidPlayToEndTime,
                                               object: player.currentItem)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerController?.frame = self.bounds // Frame'i güncelle
    }

    @objc func playerDidFinishPlaying(_ notification: Notification) {
        if let playerItem = notification.object as? AVPlayerItem {
            playerItem.seek(to: CMTime.zero)
            playerItem.player?.play()
        }
    }
}

extension AVPlayerItem {
    var player: AVPlayer? {
        return self.value(forKey: "player") as? AVPlayer
    }
}
