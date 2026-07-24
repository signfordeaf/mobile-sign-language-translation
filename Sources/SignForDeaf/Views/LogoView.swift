// Views/LogoView.swift

import UIKit

class LogoView: UIView {

    private static let defaultColor = UIColor(red: 80 / 255, green: 26 / 255, blue: 137 / 255, alpha: 1.0)  // #501A89
    
    var logoColor: UIColor = LogoView.defaultColor {
        didSet {
            setNeedsDisplay()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        // Original SVG is 128x128, scale to fit the view
        let scale = min(rect.width, rect.height) / 128.0
        context.scaleBy(x: scale, y: scale)

        // Center the drawing if the view is not square
        let offsetX = (rect.width / scale - 128) / 2
        let offsetY = (rect.height / scale - 128) / 2
        context.translateBy(x: offsetX, y: offsetY)

        context.setFillColor(logoColor.cgColor)

        // Path 1 - Main hand shape (left part)
        let path1 = UIBezierPath()
        path1.move(to: CGPoint(x: 89.0548, y: 105.885))
        path1.addLine(to: CGPoint(x: 80.9026, y: 114.053))
        path1.addCurve(
            to: CGPoint(x: 14.3761, y: 114.729),
            controlPoint1: CGPoint(x: 62.5805, y: 132.422),
            controlPoint2: CGPoint(x: 32.9816, y: 132.645))
        path1.addCurve(
            to: CGPoint(x: 14.3018, y: 46.091),
            controlPoint1: CGPoint(x: -4.93132, y: 96.1359),
            controlPoint2: CGPoint(x: -4.62764, y: 65.0488))
        path1.addCurve(
            to: CGPoint(x: 45.8375, y: 14.5848),
            controlPoint1: CGPoint(x: 14.3018, y: 46.091),
            controlPoint2: CGPoint(x: 39.4872, y: 20.9266))
        path1.addCurve(
            to: CGPoint(x: 48.0847, y: 14.5848),
            controlPoint1: CGPoint(x: 46.4516, y: 13.9695),
            controlPoint2: CGPoint(x: 47.4639, y: 13.9628))
        path1.addLine(to: CGPoint(x: 48.6786, y: 15.1797))
        path1.addCurve(
            to: CGPoint(x: 48.6921, y: 33.7589),
            controlPoint1: CGPoint(x: 53.794, y: 20.3046),
            controlPoint2: CGPoint(x: 53.794, y: 28.6341))
        path1.addLine(to: CGPoint(x: 25.2614, y: 57.2872))
        path1.addCurve(
            to: CGPoint(x: 24.1749, y: 102.363),
            controlPoint1: CGPoint(x: 12.9589, y: 69.6125),
            controlPoint2: CGPoint(x: 12.1896, y: 89.7265))
        path1.addCurve(
            to: CGPoint(x: 69.8486, y: 102.964),
            controlPoint1: CGPoint(x: 36.5718, y: 115.425),
            controlPoint2: CGPoint(x: 57.2087, y: 115.641))
        path1.addLine(to: CGPoint(x: 77.7308, y: 95.0676))
        path1.addCurve(
            to: CGPoint(x: 80.7271, y: 102.931),
            controlPoint1: CGPoint(x: 77.5756, y: 97.887),
            controlPoint2: CGPoint(x: 78.5744, y: 100.774))
        path1.addCurve(
            to: CGPoint(x: 89.0548, y: 105.885),
            controlPoint1: CGPoint(x: 82.9879, y: 105.229),
            controlPoint2: CGPoint(x: 86.0787, y: 106.21))
        path1.close()
        path1.fill()

        // Path 2 - Top right finger
        let path2 = UIBezierPath()
        path2.move(to: CGPoint(x: 125.712, y: 58.0791))
        path2.addCurve(
            to: CGPoint(x: 128, y: 63.6231),
            controlPoint1: CGPoint(x: 127.237, y: 59.6071),
            controlPoint2: CGPoint(x: 128, y: 61.6219))
        path2.addCurve(
            to: CGPoint(x: 125.712, y: 69.1672),
            controlPoint1: CGPoint(x: 128, y: 65.6244),
            controlPoint2: CGPoint(x: 127.237, y: 67.6392))
        path2.addLine(to: CGPoint(x: 98.1717, y: 96.7588))
        path2.addCurve(
            to: CGPoint(x: 95.2294, y: 88.4022),
            controlPoint1: CGPoint(x: 98.4956, y: 93.7704),
            controlPoint2: CGPoint(x: 97.5104, y: 90.6874))
        path2.addCurve(
            to: CGPoint(x: 87.3741, y: 85.4003),
            controlPoint1: CGPoint(x: 93.0699, y: 86.2387),
            controlPoint2: CGPoint(x: 90.195, y: 85.238))
        path2.addLine(to: CGPoint(x: 114.645, y: 58.0791))
        path2.addCurve(
            to: CGPoint(x: 125.712, y: 58.0791),
            controlPoint1: CGPoint(x: 117.695, y: 55.0164),
            controlPoint2: CGPoint(x: 122.648, y: 55.0096))
        path2.close()
        path2.fill()

        // Path 3 - Main fingers crossing
        let path3 = UIBezierPath()
        path3.move(to: CGPoint(x: 67.2438, y: 71.5263))
        path3.addLine(to: CGPoint(x: 70.3684, y: 74.6566))
        path3.addLine(to: CGPoint(x: 114.092, y: 30.8521))
        path3.addCurve(
            to: CGPoint(x: 125.2, y: 30.8521),
            controlPoint1: CGPoint(x: 117.162, y: 27.7759),
            controlPoint2: CGPoint(x: 122.136, y: 27.7759))
        path3.addCurve(
            to: CGPoint(x: 125.2, y: 41.9807),
            controlPoint1: CGPoint(x: 128.27, y: 33.9284),
            controlPoint2: CGPoint(x: 128.27, y: 38.9112))
        path3.addLine(to: CGPoint(x: 88.5083, y: 78.7402))
        path3.addCurve(
            to: CGPoint(x: 65.4555, y: 86.7588),
            controlPoint1: CGPoint(x: 82.2119, y: 85.0482),
            controlPoint2: CGPoint(x: 73.6684, y: 87.7256))
        path3.addCurve(
            to: CGPoint(x: 59.6045, y: 85.4269),
            controlPoint1: CGPoint(x: 63.4714, y: 86.5221),
            controlPoint2: CGPoint(x: 61.5076, y: 86.0827))
        path3.addCurve(
            to: CGPoint(x: 55.2652, y: 83.5067),
            controlPoint1: CGPoint(x: 58.1131, y: 84.9198),
            controlPoint2: CGPoint(x: 56.6689, y: 84.2775))
        path3.addCurve(
            to: CGPoint(x: 48.9149, y: 78.7335),
            controlPoint1: CGPoint(x: 52.991, y: 82.256),
            controlPoint2: CGPoint(x: 50.845, y: 80.6671))
        path3.addCurve(
            to: CGPoint(x: 44.1505, y: 72.3714),
            controlPoint1: CGPoint(x: 46.9849, y: 76.7998),
            controlPoint2: CGPoint(x: 45.399, y: 74.6498))
        path3.addCurve(
            to: CGPoint(x: 42.2339, y: 68.0241),
            controlPoint1: CGPoint(x: 43.3812, y: 70.9651),
            controlPoint2: CGPoint(x: 42.7401, y: 69.5182))
        path3.addCurve(
            to: CGPoint(x: 40.729, y: 59.708),
            controlPoint1: CGPoint(x: 41.3094, y: 65.3332),
            controlPoint2: CGPoint(x: 40.81, y: 62.5274))
        path3.addCurve(
            to: CGPoint(x: 48.9149, y: 39.0667),
            controlPoint1: CGPoint(x: 40.5063, y: 52.2642),
            controlPoint2: CGPoint(x: 43.2394, y: 44.7527))
        path3.addLine(to: CGPoint(x: 85.6064, y: 2.30719))
        path3.addCurve(
            to: CGPoint(x: 96.7144, y: 2.30719),
            controlPoint1: CGPoint(x: 88.677, y: -0.769063),
            controlPoint2: CGPoint(x: 93.6506, y: -0.769063))
        path3.addCurve(
            to: CGPoint(x: 96.7144, y: 13.4358),
            controlPoint1: CGPoint(x: 99.785, y: 5.38344),
            controlPoint2: CGPoint(x: 99.785, y: 10.3663))
        path3.addLine(to: CGPoint(x: 52.991, y: 57.2403))
        path3.addLine(to: CGPoint(x: 56.1156, y: 60.3706))
        path3.addLine(to: CGPoint(x: 110.893, y: 5.49162))
        path3.addCurve(
            to: CGPoint(x: 122.001, y: 5.49162),
            controlPoint1: CGPoint(x: 113.964, y: 2.41536),
            controlPoint2: CGPoint(x: 118.937, y: 2.41536))
        path3.addCurve(
            to: CGPoint(x: 122.001, y: 16.6202),
            controlPoint1: CGPoint(x: 125.072, y: 8.56787),
            controlPoint2: CGPoint(x: 125.072, y: 13.5507))
        path3.addLine(to: CGPoint(x: 67.2438, y: 71.5263))
        path3.close()
        path3.fill()

        // Path 4 - Small circle/dot
        let path4 = UIBezierPath()
        path4.move(to: CGPoint(x: 91.9028, y: 91.7284))
        path4.addCurve(
            to: CGPoint(x: 91.4101, y: 100.051),
            controlPoint1: CGPoint(x: 94.231, y: 94.061),
            controlPoint2: CGPoint(x: 94.0623, y: 97.9418))
        path4.addCurve(
            to: CGPoint(x: 84.4862, y: 100.011),
            controlPoint1: CGPoint(x: 89.4058, y: 101.64),
            controlPoint2: CGPoint(x: 86.4702, y: 101.627))
        path4.addCurve(
            to: CGPoint(x: 84.034, y: 91.7149),
            controlPoint1: CGPoint(x: 81.8678, y: 97.8809),
            controlPoint2: CGPoint(x: 81.7193, y: 94.0339))
        path4.addCurve(
            to: CGPoint(x: 91.9028, y: 91.7284),
            controlPoint1: CGPoint(x: 86.2003, y: 89.5446),
            controlPoint2: CGPoint(x: 89.723, y: 89.5446))
        path4.close()
        path4.fill()
    }
}
