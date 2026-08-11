import XCTest
@testable import SignForDeaf

/// Classification tests (conformance B). Builds synthetic UIKit hierarchies and
/// probes points inside them.
final class TapTargetProbeTests: XCTestCase {

    private let root = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 800))

    private func classify(_ point: CGPoint, smart: Bool = true) -> TapClassification {
        TapTargetProbe.classify(point: point, in: root, smartPassthrough: smart)
    }

    override func tearDown() {
        root.subviews.forEach { $0.removeFromSuperview() }
        super.tearDown()
    }

    // MARK: text vs interactive

    func testPlainLabelIsText() {
        let label = UILabel(frame: CGRect(x: 10, y: 10, width: 200, height: 40))
        label.text = "Merhaba dünya"
        root.addSubview(label)
        XCTAssertEqual(classify(CGPoint(x: 50, y: 30)), .text("Merhaba dünya"))
    }

    func testLabelledButtonIsReadNotPressed() {
        let button = UIButton(type: .system)
        button.frame = CGRect(x: 10, y: 100, width: 160, height: 44)
        button.setTitle("Kabul ediyorum", for: .normal)
        button.layoutIfNeeded() // realise titleLabel frame
        root.addSubview(button)
        // A point over the title reads the label rather than pressing the button.
        let p = button.titleLabel.map { button.convert($0.center, to: root) } ?? CGPoint(x: 60, y: 122)
        XCTAssertEqual(classify(p), .text("Kabul ediyorum"))
    }

    func testUnlabelledControlIsInteractive() {
        let sw = UISwitch(frame: CGRect(x: 10, y: 200, width: 60, height: 40))
        root.addSubview(sw)
        XCTAssertEqual(classify(CGPoint(x: 30, y: 220)), .interactive)
    }

    func testIconButtonIsInteractiveNotText() {
        let button = UIButton(type: .system)
        button.frame = CGRect(x: 10, y: 300, width: 44, height: 44)
        // An icon glyph drawn from a private-use codepoint must not read as text.
        let icon = UILabel(frame: button.bounds)
        icon.text = "\u{E001}"
        button.addSubview(icon)
        root.addSubview(button)
        XCTAssertEqual(classify(CGPoint(x: 32, y: 322)), .interactive)
    }

    func testEditableFieldIsInteractive() {
        let field = UITextField(frame: CGRect(x: 10, y: 400, width: 200, height: 40))
        field.text = "typed"
        root.addSubview(field)
        XCTAssertEqual(classify(CGPoint(x: 50, y: 420)), .interactive)
    }

    func testReadOnlySelectableTextViewIsText() {
        let tv = UITextView(frame: CGRect(x: 10, y: 450, width: 300, height: 80))
        tv.isEditable = false
        tv.isSelectable = true
        tv.text = "Salt okunur metin"
        root.addSubview(tv)
        XCTAssertEqual(classify(CGPoint(x: 40, y: 480)), .text("Salt okunur metin"))
    }

    // MARK: scroll views

    func testPlainTextInsideScrollViewIsStillText() {
        let scroll = UIScrollView(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
        let label = UILabel(frame: CGRect(x: 10, y: 10, width: 300, height: 40))
        label.text = "Kaydırılabilir metin"
        scroll.addSubview(label)
        root.addSubview(scroll)
        XCTAssertEqual(classify(CGPoint(x: 40, y: 30)), .text("Kaydırılabilir metin"))
    }

    func testLabelledButtonInsideScrollViewIsRead() {
        let scroll = UIScrollView(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
        let button = UIButton(type: .system)
        button.frame = CGRect(x: 10, y: 50, width: 160, height: 44)
        button.setTitle("Onayla", for: .normal)
        button.layoutIfNeeded()
        scroll.addSubview(button)
        root.addSubview(scroll)
        let p = button.titleLabel.map { button.convert($0.center, to: root) } ?? CGPoint(x: 60, y: 72)
        XCTAssertEqual(classify(p), .text("Onayla"))
    }

    // MARK: ambient wrapper

    func testAppWideDismissWrapperDoesNotMakePageInteractive() {
        // A whole-page tap handler (dismiss the keyboard) covers ≥80% of the area.
        let wrapper = UIView(frame: root.bounds)
        wrapper.addGestureRecognizer(UITapGestureRecognizer())
        let label = UILabel(frame: CGRect(x: 10, y: 10, width: 200, height: 40))
        label.text = "Sayfa metni"
        wrapper.addSubview(label)
        root.addSubview(wrapper)
        XCTAssertEqual(classify(CGPoint(x: 50, y: 30)), .text("Sayfa metni"))
        // And empty space under the ambient wrapper is not interactive either.
        XCTAssertEqual(classify(CGPoint(x: 300, y: 700)), .none)
    }

    // MARK: none

    func testEmptySpaceIsNone() {
        XCTAssertEqual(classify(CGPoint(x: 380, y: 780)), .none)
    }

    // MARK: legacy capture mode

    func testLegacyModeCapturesButtonLabel() {
        let button = UIButton(type: .system)
        button.frame = CGRect(x: 10, y: 100, width: 160, height: 44)
        button.setTitle("Buton", for: .normal)
        button.layoutIfNeeded()
        root.addSubview(button)
        let p = button.titleLabel.map { button.convert($0.center, to: root) } ?? CGPoint(x: 60, y: 122)
        // Same as smart mode here, but legacy also claims where smart would defer.
        XCTAssertEqual(classify(p, smart: false), .text("Buton"))
    }

    // MARK: internal UI never claimed

    func testInternalUIIsNeverClaimed() {
        let panel = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        panel.isSignForDeafInternalUI = true
        let label = UILabel(frame: CGRect(x: 10, y: 10, width: 100, height: 30))
        label.text = "SDK kendi metni"
        panel.addSubview(label)
        root.addSubview(panel)
        XCTAssertEqual(classify(CGPoint(x: 40, y: 20)), .none)
    }

    // MARK: interactive control resolution (long-press-to-activate)

    func testInteractiveControlForLabelledButton() {
        let button = UIButton(type: .system)
        button.frame = CGRect(x: 10, y: 100, width: 160, height: 44)
        button.setTitle("Kabul ediyorum", for: .normal)
        button.layoutIfNeeded()
        root.addSubview(button)
        let p = button.titleLabel.map { button.convert($0.center, to: root) } ?? CGPoint(x: 60, y: 122)
        // The labelled control — the one a tap would translate — is returned so a
        // long press can run it.
        XCTAssertTrue(TapTargetProbe.interactiveControl(at: p, in: root) === button)
    }

    func testInteractiveControlNilForPlainText() {
        let label = UILabel(frame: CGRect(x: 10, y: 10, width: 200, height: 40))
        label.text = "Merhaba dünya"
        root.addSubview(label)
        XCTAssertNil(TapTargetProbe.interactiveControl(at: CGPoint(x: 50, y: 30), in: root))
    }

    func testInteractiveControlNilForUnlabelledControl() {
        // An icon/unlabelled control is already operable by a normal tap
        // (classified `.interactive`), so there is nothing to long-press-activate.
        let sw = UISwitch(frame: CGRect(x: 10, y: 200, width: 60, height: 40))
        root.addSubview(sw)
        XCTAssertNil(TapTargetProbe.interactiveControl(at: CGPoint(x: 30, y: 220), in: root))
    }

    // MARK: button title extraction (iOS 15+ configured buttons)

    func testConfiguredButtonTitleIsText() {
        let button = UIButton(type: .system)
        button.frame = CGRect(x: 10, y: 100, width: 160, height: 44)
        var cfg = UIButton.Configuration.filled()
        cfg.title = "Kabul ediyorum"
        button.configuration = cfg
        root.addSubview(button)
        XCTAssertEqual(classify(CGPoint(x: 60, y: 122)), .text("Kabul ediyorum"))
    }

    func testIconOnlyButtonHasNoText() {
        let button = UIButton(type: .system)
        button.frame = CGRect(x: 10, y: 200, width: 44, height: 44)
        button.setImage(UIImage(systemName: "xmark"), for: .normal)
        button.accessibilityLabel = "Kapat"
        root.addSubview(button)
        // No visible title → operates (interactive), even though it has an a11y label.
        XCTAssertEqual(classify(CGPoint(x: 32, y: 222)), .interactive)
    }

    // MARK: accessibility-label fallback (SwiftUI-style controls)

    func testAccessibilityFallbackReadsControlLabelOnlyWhenEnabled() {
        // A gesture-driven view with no UILabel, carrying an accessibility label —
        // stands in for a SwiftUI button (its text is not a UILabel).
        let control = UIView(frame: CGRect(x: 10, y: 300, width: 160, height: 44))
        control.addGestureRecognizer(UITapGestureRecognizer())
        control.isAccessibilityElement = true
        control.accessibilityLabel = "Onayla"
        root.addSubview(control)
        let p = CGPoint(x: 60, y: 322)
        // Off (default): no visible text → interactive (runs on tap).
        XCTAssertEqual(TapTargetProbe.classify(point: p, in: root, smartPassthrough: true), .interactive)
        // On: the accessibility label is used as text → translates on tap.
        XCTAssertEqual(
            TapTargetProbe.classify(point: p, in: root, smartPassthrough: true, allowAccessibility: true),
            .text("Onayla"))
    }

    func testAccessibilityFallbackReadsButtonTraitWithoutGesture() {
        // A SwiftUI button exposes no UIGestureRecognizer — only the `.button`
        // accessibility trait and a label.
        let control = UIView(frame: CGRect(x: 10, y: 360, width: 160, height: 44))
        control.isAccessibilityElement = true
        control.accessibilityTraits = .button
        control.accessibilityLabel = "Kabul ediyorum"
        root.addSubview(control)
        let p = CGPoint(x: 60, y: 382)
        XCTAssertEqual(classify(p), .none) // invisible to UIKit without the fallback
        XCTAssertEqual(
            TapTargetProbe.classify(point: p, in: root, smartPassthrough: true, allowAccessibility: true),
            .text("Kabul ediyorum"))
        // And it is resolved as the control to operate on long-press.
        XCTAssertTrue(
            TapTargetProbe.interactiveControl(at: p, in: root, allowAccessibility: true) === control)
    }

    // MARK: content test

    func testTranslatableContentExcludesWhitespaceAndPUA() {
        XCTAssertTrue(TapTargetProbe.hasTranslatableContent("a"))
        XCTAssertTrue(TapTargetProbe.hasTranslatableContent("  x  "))
        XCTAssertFalse(TapTargetProbe.hasTranslatableContent("   "))
        XCTAssertFalse(TapTargetProbe.hasTranslatableContent("\u{E001}\u{F8FF}"))
    }
}
