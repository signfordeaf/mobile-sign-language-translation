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
        XCTAssertEqual(config.originUrl, "https://webplugin.signfordeaf.com")
        XCTAssertEqual(config.fdid, "16")
        XCTAssertEqual(config.tid, "23")
        XCTAssertEqual(config.theme.primaryColor, "#6750A4")
        XCTAssertEqual(config.theme.textColor, "#1C1B1F")
        XCTAssertTrue(config.showFloatingButton)
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
            "Çevirmek için bir yazıya dokunun")
        XCTAssertEqual(
            SignForDeafLanguage.english.strings.tapToTranslateHint,
            "Tap on any text to translate it")
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
