import XCTest
@testable import SignForDeaf

final class SignForDeafTests: XCTestCase {

    // MARK: - Language

    func testLanguageAPICodeMapping() {
        XCTAssertEqual(SignForDeafLanguage.turkish.apiCode, "1")
        XCTAssertEqual(SignForDeafLanguage.english.apiCode, "2")
        XCTAssertEqual(SignForDeafLanguage.arabic.apiCode, "6")
    }

    func testOnlyThreeSupportedLanguages() {
        XCTAssertEqual(
            SignForDeafLanguage.allCases, [.turkish, .english, .arabic])
    }

    func testLanguageFromLooseString() {
        XCTAssertEqual(SignForDeafLanguage(from: "tr"), .turkish)
        XCTAssertEqual(SignForDeafLanguage(from: "English"), .english)
        XCTAssertEqual(SignForDeafLanguage(from: "AR"), .arabic)
        // Unknown falls back to Turkish.
        XCTAssertEqual(SignForDeafLanguage(from: "zz"), .turkish)
    }

    func testLocalizedMenuTitleAndBusinessName() {
        XCTAssertEqual(SignForDeafLanguage.turkish.strings.menuTitle, "İşaret Dili")
        XCTAssertEqual(SignForDeafLanguage.turkish.strings.businessName, "Engelsiz Çeviri")
        XCTAssertEqual(SignForDeafLanguage.english.strings.menuTitle, "Sign Language")
        XCTAssertEqual(SignForDeafLanguage.english.strings.businessName, "SignForDeaf")
    }

    // MARK: - Config defaults

    func testConfigDefaults() {
        let config = SignForDeafConfig(apiKey: "KEY", apiUrl: "https://example.com")
        XCTAssertEqual(config.language, .turkish)
        // v2: originUrl defaults to apiUrl when not given.
        XCTAssertEqual(config.originUrl, "https://example.com")
        // Default translator is Hesna; raw tid/fdid are nil overrides, and the
        // effective ids come from the translator.
        XCTAssertEqual(config.translator, .hesna)
        XCTAssertNil(config.fdid)
        XCTAssertNil(config.tid)
        XCTAssertEqual(config.effectiveTid, "43")
        XCTAssertEqual(config.effectiveFdid, "35")
        XCTAssertEqual(config.theme.primaryColor, "#6750A4")
        XCTAssertEqual(config.theme.textColor, "#1C1B1F")
        XCTAssertEqual(config.theme.onPrimaryColor, "#FFFFFF")
        XCTAssertEqual(config.theme.surfaceColor, "#FFFFFF")
        XCTAssertEqual(config.theme.cornerRadius, 16)
        XCTAssertTrue(config.showFloatingButton)
        // v2 defaults
        XCTAssertEqual(config.granularity, .sentence)
        XCTAssertEqual(config.maxSegmentChars, 900)
        XCTAssertFalse(config.longPressToTranslate)
        XCTAssertTrue(config.smartPassthrough)
        XCTAssertFalse(config.autoEnable)
        XCTAssertTrue(config.card.draggable)
        XCTAssertEqual(config.card.initialCorner, .bottomRight)
        XCTAssertEqual(config.card.avatarHeight, 240)
        XCTAssertEqual(config.card.avatarMaxWidth, 212)
        XCTAssertNil(config.card.placeholderAvatar)
        XCTAssertFalse(config.card.showFeedback)
        XCTAssertFalse(config.card.showContact)
        XCTAssertTrue(config.card.showSpeed)
        XCTAssertTrue(config.card.showLoop)
        XCTAssertEqual(config.card.speeds, [1.0, 1.2, 1.5, 2.0])
        XCTAssertEqual(config.card.defaultSpeed, 1.0)
        XCTAssertTrue(config.card.defaultLooping)
        XCTAssertTrue(config.accessibility.announceOnOpen)
        XCTAssertFalse(config.accessibility.announceOnClose)
    }

    func testOriginUrlOverrideWins() {
        let config = SignForDeafConfig(
            apiKey: "K", apiUrl: "https://api.example.com",
            originUrl: "https://origin.example.com")
        XCTAssertEqual(config.originUrl, "https://origin.example.com")
    }

    // MARK: - Floating button config

    func testFloatingButtonConfigDefaults() {
        let fb = SignForDeafFloatingButtonConfig()
        XCTAssertEqual(fb.size, 44)
        XCTAssertEqual(fb.backgroundColor, "#FFFFFF")
        XCTAssertNil(fb.activeBackgroundColor)
        XCTAssertNil(fb.iconColor)
        XCTAssertEqual(fb.activeIconColor, "#FFFFFF")
        XCTAssertNil(fb.borderColor)
        XCTAssertEqual(fb.idleBehavior, .peek)
        XCTAssertEqual(fb.idleDelay, 2.5, accuracy: 0.001)
        XCTAssertEqual(fb.hintMaxShows, 2)
        // Config exposes the button config with those defaults.
        let config = SignForDeafConfig(apiKey: "K", apiUrl: "https://x")
        XCTAssertEqual(config.floatingButton.idleBehavior, .peek)
    }

    func testFloatingButtonUnsetColorsResolveToThemePrimary() {
        let primary = UIColor.red
        let resolved = SignForDeafFloatingButtonConfig().resolved(themePrimary: primary)
        // nil colors fall back to the theme primary…
        XCTAssertEqual(resolved.activeBackgroundColor, primary)
        XCTAssertEqual(resolved.iconColor, primary)
        XCTAssertEqual(resolved.borderColor, primary)
        // …while explicit defaults stay fixed.
        XCTAssertEqual(resolved.backgroundColor, UIColor(hex: "#FFFFFF"))
        XCTAssertEqual(resolved.activeIconColor, UIColor(hex: "#FFFFFF"))
        XCTAssertEqual(resolved.size, 44)
    }

    func testFloatingButtonExplicitColorsOverrideTheme() {
        let resolved = SignForDeafFloatingButtonConfig(
            activeBackgroundColor: "#000000", iconColor: "#123456"
        ).resolved(themePrimary: .red)
        XCTAssertEqual(resolved.activeBackgroundColor, UIColor(hex: "#000000"))
        XCTAssertEqual(resolved.iconColor, UIColor(hex: "#123456"))
    }

    func testTapToTranslateHintLocalized() {
        XCTAssertEqual(
            SignForDeafLanguage.turkish.strings.tapToTranslateHint,
            "Cümlelere tıklayarak işaret dili çevirilerini başlatabilirsiniz.")
        XCTAssertEqual(
            SignForDeafLanguage.english.strings.tapToTranslateHint,
            "Tap a sentence to start its sign language translation.")
    }

    func testV2ControlLabelsLocalized() {
        XCTAssertEqual(SignForDeafLanguage.turkish.strings.playLabel, "Oynat")
        XCTAssertEqual(SignForDeafLanguage.turkish.strings.collapseLabel, "Küçült")
        XCTAssertEqual(SignForDeafLanguage.english.strings.translationModeLabel,
                       "Sign language translation mode")
        XCTAssertEqual(SignForDeafLanguage.arabic.strings.loopLabel, "تكرار")
        XCTAssertEqual(LocalizedStrings.sentenceCounter(index: 1, total: 5), "2 / 5")
    }

    // MARK: - SignModel

    func testVideoUrlUpgradesToHTTPS() {
        let model = SignModel(
            state: true, baseUrl: "http://cdn.example.com/", name: "video.mp4", cid: nil, st: nil)
        XCTAssertEqual(model.videoUrl, "https://cdn.example.com/video.mp4")
    }

    func testVideoUrlNilWhenMissingParts() {
        let noName = SignModel(state: true, baseUrl: "https://x/", name: nil, cid: nil, st: nil)
        XCTAssertNil(noName.videoUrl)
        let noBase = SignModel(state: true, baseUrl: nil, name: "v.mp4", cid: nil, st: nil)
        XCTAssertNil(noBase.videoUrl)
    }

    func testSignModelDecoding() throws {
        let json = """
        {"state": true, "baseUrl": "https://cdn/", "name": "a.mp4", "cid": "9", "st": false}
        """.data(using: .utf8)!
        let model = try JSONDecoder().decode(SignModel.self, from: json)
        XCTAssertEqual(model.state, true)
        XCTAssertEqual(model.baseUrl, "https://cdn/")
        XCTAssertEqual(model.name, "a.mp4")
        XCTAssertEqual(model.cid, "9")
        XCTAssertEqual(model.st, false)
    }

    // MARK: - Theme hex parsing

    func testThemeHexParsing() {
        let theme = SignForDeafTheme(primaryColor: "#FF0000", textColor: "#00FF00")
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        theme.primaryUIColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 1.0, accuracy: 0.01)
        XCTAssertEqual(g, 0.0, accuracy: 0.01)
    }

    func testThemeInvalidHexFallsBackToDefault() {
        let theme = SignForDeafTheme(primaryColor: "not-a-color")
        XCTAssertEqual(theme.primaryUIColor, SignForDeafTheme.defaultPrimary)
    }
}
