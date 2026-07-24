import XCTest
@testable import SignForDeaf

final class SensitiveDataGuardTests: XCTestCase {

    override func tearDown() {
        // The registry is a process-wide singleton; keep tests isolated.
        SensitiveTextRegistry.shared.removeAll()
        super.tearDown()
    }

    // MARK: - TCKN (Turkish national ID)

    func testValidTcknIsBlocked() {
        XCTAssertTrue(SensitiveDataGuard.isSensitive("10000000146"))
        XCTAssertTrue(SensitiveDataGuard.isSensitive("TCKN: 10000000146"))
    }

    func testInvalidElevenDigitsNotBlocked() {
        // Checksum does not hold — must not be a false positive.
        XCTAssertFalse(SensitiveDataGuard.isSensitive("12345678901"))
        XCTAssertFalse(SensitiveDataGuard.isSensitive("Bu butona 12345678901 kez bastınız"))
    }

    // MARK: - Credit card (Luhn)

    func testLuhnValidCardIsBlocked() {
        XCTAssertTrue(SensitiveDataGuard.isSensitive("4242 4242 4242 4242"))
        XCTAssertTrue(SensitiveDataGuard.isSensitive("Kart: 4111-1111-1111-1111"))
    }

    func testLuhnInvalidCardNotBlocked() {
        XCTAssertFalse(SensitiveDataGuard.isSensitive("1234 5678 9012 3456"))
    }

    // MARK: - IBAN / email / GSM

    func testTurkishIbanIsBlocked() {
        XCTAssertTrue(SensitiveDataGuard.isSensitive("TR33 0006 1005 1978 6457 8413 26"))
    }

    func testEmailIsBlocked() {
        XCTAssertTrue(SensitiveDataGuard.isSensitive("iletisim: ali@example.com"))
    }

    func testGsmIsBlocked() {
        XCTAssertTrue(SensitiveDataGuard.isSensitive("0532 123 45 67"))
        XCTAssertTrue(SensitiveDataGuard.isSensitive("+90 532 123 45 67"))
    }

    // MARK: - Plain / empty text

    func testPlainTextNotBlocked() {
        XCTAssertFalse(SensitiveDataGuard.isSensitive("Merhaba dünya"))
        XCTAssertFalse(SensitiveDataGuard.isSensitive("You have pushed the button this many times"))
    }

    func testEmptyTextNotBlocked() {
        XCTAssertFalse(SensitiveDataGuard.isSensitive(""))
        XCTAssertFalse(SensitiveDataGuard.isSensitive("   "))
    }

    // MARK: - Registry (manual marking)

    func testRegisteredTextIsBlockedTwoWay() {
        SensitiveTextRegistry.shared.register("Gizli Not")

        // Exact, subset, and superset overlaps all match.
        XCTAssertTrue(SensitiveDataGuard.isSensitive("Gizli Not"))
        XCTAssertTrue(SensitiveDataGuard.isSensitive("Gizli"))
        XCTAssertTrue(SensitiveDataGuard.isSensitive("Çok Gizli Not içeriği"))

        SensitiveTextRegistry.shared.unregister("Gizli Not")
        XCTAssertFalse(SensitiveDataGuard.isSensitive("Gizli Not"))
    }

    func testRegistryIgnoresEmpty() {
        SensitiveTextRegistry.shared.register("   ")
        XCTAssertFalse(SensitiveDataGuard.isSensitive("anything"))
    }

    // MARK: - Custom patterns

    func testCustomPatternIsBlocked() {
        let pattern = try! NSRegularExpression(pattern: #"SECRET-\d+"#)
        XCTAssertTrue(
            SensitiveDataGuard.isSensitive("code SECRET-4821 here", extraPatterns: [pattern]))
        // Without the custom pattern the same text is clean.
        XCTAssertFalse(SensitiveDataGuard.isSensitive("code SECRET-4821 here"))
    }

    // MARK: - Checksum helpers directly

    func testTcknChecksumHelper() {
        XCTAssertTrue(SensitiveDataGuard.isValidTckn("10000000146"))
        XCTAssertFalse(SensitiveDataGuard.isValidTckn("12345678901"))
        XCTAssertFalse(SensitiveDataGuard.isValidTckn("00000000000"))  // first digit 0
        XCTAssertFalse(SensitiveDataGuard.isValidTckn("123"))          // wrong length
    }

    func testLuhnHelper() {
        XCTAssertTrue(SensitiveDataGuard.passesLuhn("4242424242424242"))
        XCTAssertFalse(SensitiveDataGuard.passesLuhn("1234567890123456"))
    }
}

final class SignForDeafConfigSensitiveTests: XCTestCase {

    func testSensitiveDefaults() {
        let config = SignForDeafConfig(apiKey: "KEY", apiUrl: "https://example.com")
        XCTAssertTrue(config.sensitiveFilteringEnabled)
        XCTAssertTrue(config.sensitivePatterns.isEmpty)
        XCTAssertTrue(config.compiledSensitivePatterns.isEmpty)
    }

    func testCompiledPatternsSkipInvalid() {
        let config = SignForDeafConfig(
            apiKey: "KEY", apiUrl: "https://example.com",
            sensitivePatterns: [#"\d+"#, "([invalid"])
        // Only the valid pattern compiles.
        XCTAssertEqual(config.compiledSensitivePatterns.count, 1)
    }

    func testSensitiveBlockedStringLocalized() {
        XCTAssertFalse(SignForDeafLanguage.turkish.strings.sensitiveBlocked.isEmpty)
        XCTAssertEqual(
            SignForDeafLanguage.english.strings.sensitiveBlocked,
            "This content contains sensitive data and cannot be translated.")
    }
}
