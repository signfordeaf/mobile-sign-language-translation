import XCTest
@testable import SignForDeaf

/// The accessibility fallback reaches text/controls that expose no `UIView`
/// (SwiftUI). Tests build virtual `UIAccessibilityElement`s in a real window so
/// the screen-space frame conversion runs for real.
final class AccessibilityProbeTests: XCTestCase {

    private var window: UIWindow!
    private var root: UIView!

    override func setUp() {
        super.setUp()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        root = UIView(frame: window.bounds)
        window.addSubview(root)
        window.makeKeyAndVisible()
    }

    override func tearDown() {
        window.isHidden = true
        window = nil
        root = nil
        super.tearDown()
    }

    private func element(_ label: String, _ traits: UIAccessibilityTraits, _ frame: CGRect)
        -> UIAccessibilityElement {
        let element = UIAccessibilityElement(accessibilityContainer: root!)
        element.accessibilityLabel = label
        element.accessibilityTraits = traits
        // Screen coordinates directly — the window sits at the screen origin, so a
        // root-space point and a screen-space point coincide in these tests.
        element.accessibilityFrame = frame
        return element
    }

    func testPlainTextIsMatchedAsNonControl() {
        root.accessibilityElements = [
            element("Merhaba dünya", .staticText, CGRect(x: 10, y: 10, width: 200, height: 40))
        ]
        let match = AccessibilityProbe.hit(at: CGPoint(x: 50, y: 30), in: root)
        XCTAssertEqual(match?.label, "Merhaba dünya")
        XCTAssertEqual(match?.isControl, false)
    }

    func testButtonIsMatchedAsControl() {
        root.accessibilityElements = [
            element("Kabul ediyorum", .button, CGRect(x: 10, y: 100, width: 200, height: 44))
        ]
        let match = AccessibilityProbe.hit(at: CGPoint(x: 50, y: 120), in: root)
        XCTAssertEqual(match?.label, "Kabul ediyorum")
        XCTAssertEqual(match?.isControl, true)
    }

    func testImageIsExcluded() {
        root.accessibilityElements = [
            element("Profil fotoğrafı", .image, CGRect(x: 10, y: 200, width: 60, height: 60))
        ]
        XCTAssertNil(AccessibilityProbe.hit(at: CGPoint(x: 30, y: 220), in: root))
    }

    func testSliderIsExcluded() {
        root.accessibilityElements = [
            element("Ses düzeyi", .adjustable, CGRect(x: 10, y: 300, width: 200, height: 40))
        ]
        XCTAssertNil(AccessibilityProbe.hit(at: CGPoint(x: 50, y: 320), in: root))
    }

    func testSmallestFrameWins() {
        root.accessibilityElements = [
            element("Kapsayıcı", .staticText, CGRect(x: 0, y: 0, width: 400, height: 400)),
            element("İç metin", .staticText, CGRect(x: 10, y: 10, width: 120, height: 40)),
        ]
        let match = AccessibilityProbe.hit(at: CGPoint(x: 40, y: 25), in: root)
        XCTAssertEqual(match?.label, "İç metin")
    }

    func testIconGlyphLabelIsRejected() {
        // A private-use glyph is not translatable content.
        root.accessibilityElements = [
            element("\u{E001}", .staticText, CGRect(x: 10, y: 400, width: 40, height: 40))
        ]
        XCTAssertNil(AccessibilityProbe.hit(at: CGPoint(x: 25, y: 415), in: root))
    }
}
