import XCTest
@testable import SignForDeaf

/// `ControlActivator` runs a UIKit control's action from the SDK overlay, the
/// single-gesture path of long-press-to-activate (docs/08).
///
/// Note: these tests wire handlers with `UIAction`, because the XCTest host has
/// no full `UIApplication` and classic `addTarget(_:action:for:)` dispatch routes
/// through `UIApplication.sendAction`, which is inert here. `.touchUpInside`
/// fires both wiring styles in a real app; the real-app classic path is covered
/// by the TestApp verification, not this unit host.
final class ControlActivatorTests: XCTestCase {

    func testFiresButtonExactlyOnce() {
        var fired = 0
        let button = UIButton(type: .system)
        button.frame = CGRect(x: 0, y: 0, width: 120, height: 44)
        button.addAction(UIAction { _ in fired += 1 }, for: .touchUpInside)

        XCTAssertTrue(ControlActivator.activate(button))
        XCTAssertEqual(fired, 1) // never doubled
    }

    func testFiresPrimaryActionExactlyOnce() {
        var fired = 0
        let button = UIButton(type: .system, primaryAction: UIAction { _ in fired += 1 })
        button.frame = CGRect(x: 0, y: 0, width: 120, height: 44)

        XCTAssertTrue(ControlActivator.activate(button))
        XCTAssertEqual(fired, 1)
    }

    func testFindsControlNestedUnderNode() {
        var fired = 0
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 120, height: 44))
        let button = UIButton(type: .system)
        button.frame = container.bounds
        button.addAction(UIAction { _ in fired += 1 }, for: .touchUpInside)
        container.addSubview(button)

        XCTAssertTrue(ControlActivator.activate(container))
        XCTAssertEqual(fired, 1)
    }

    func testReturnsFalseForNonControl() {
        let label = UILabel()
        label.text = "Kabul ediyorum"
        XCTAssertFalse(ControlActivator.activate(label))
    }

    func testSkipsDisabledControl() {
        var fired = 0
        let button = UIButton(type: .system)
        button.isEnabled = false
        button.addAction(UIAction { _ in fired += 1 }, for: .touchUpInside)
        XCTAssertFalse(ControlActivator.activate(button))
        XCTAssertEqual(fired, 0)
    }
}
