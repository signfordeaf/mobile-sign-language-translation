import XCTest
@testable import SignForDeaf

/// Player sizing (conformance G, incl. the ★ size budget on three phones).
final class PlayerLayoutTests: XCTestCase {

    private func compute(_ screenHeight: CGFloat, controls: Int = 3, scale: CGFloat = 1.0)
        -> PlayerLayout.Result {
        PlayerLayout.compute(
            screenHeight: screenHeight, aspect: PlayerLayout.defaultAspect,
            avatarHeight: 240, avatarMaxWidth: 212, controlCount: controls, textScale: scale)
    }

    func testWorkedResultForLargePhone() {
        // 393×852 → stage 212×195, player 212×331 (docs/06 worked results).
        let r = compute(852)
        XCTAssertEqual(r.stage.width, 212, accuracy: 1)
        XCTAssertEqual(r.stage.height, 195, accuracy: 1)
        XCTAssertEqual(r.player.width, 212, accuracy: 1)
        XCTAssertEqual(r.player.height, 331, accuracy: 1)
    }

    func testSizeBudgetHoldsOnThreePhones() {
        // Invariants: height ≤ 42% of the screen, width < 65% of the screen.
        let cases: [(w: CGFloat, h: CGFloat)] = [(393, 852), (375, 667), (360, 640)]
        for c in cases {
            let r = compute(c.h)
            XCTAssertLessThanOrEqual(r.player.height, c.h * 0.42 + 0.5,
                                     "height budget exceeded on \(c.w)×\(c.h)")
            XCTAssertLessThan(r.player.width, c.w * 0.65,
                              "width budget exceeded on \(c.w)×\(c.h)")
        }
    }

    func testStageNeverNarrowerThanMinWidth() {
        // A very short screen squeezes height; width must not fall below 3×44+8.
        let r = compute(400)
        XCTAssertGreaterThanOrEqual(r.stage.width, SignTokens.minStageWidth)
    }

    func testControlBarGrowsForExtraControlsNotClips() {
        // With contact added (4 controls) on a narrow stage, the bar grows.
        let narrow = PlayerLayout.compute(
            screenHeight: 500, aspect: PlayerLayout.defaultAspect,
            avatarHeight: 240, avatarMaxWidth: 212, controlCount: 4)
        XCTAssertGreaterThanOrEqual(narrow.controlBarWidthExpanded, 4 * 44)
    }

    func testCollapsedBarIsExactly132() {
        XCTAssertEqual(compute(852).controlBarWidthCollapsed, 132)
    }

    func testRaisedTextScaleGrowsPlayerNotClips() {
        let normal = compute(852, scale: 1.0)
        let large = compute(852, scale: 1.5)
        XCTAssertGreaterThan(large.player.height, normal.player.height)
    }
}
