// Sensitive/SensitiveDataGuard.swift

import Foundation

/// Thread-safe registry of texts that the host app has explicitly marked as
/// sensitive (via the SwiftUI `.signSensitive(_:)` modifier or the UIKit
/// `UIView.isSignForDeafSensitive` flag). Ported from the Flutter library's
/// `SignForDeafManager` sensitive-text registry.
///
/// Matching is a **two-way `contains`** on trimmed strings, so both a subset
/// (e.g. selecting just "Gizli" out of "Gizli Not") and a superset (e.g.
/// "Çok Gizli Not içeriği") of a registered string still count as sensitive.
final class SensitiveTextRegistry {

    static let shared = SensitiveTextRegistry()

    private var texts = Set<String>()
    private let lock = NSLock()

    private init() {}

    /// Mark `text` as sensitive. Empty / whitespace-only strings are ignored.
    func register(_ text: String) {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        lock.lock(); defer { lock.unlock() }
        texts.insert(normalized)
    }

    /// Remove a previously registered sensitive text.
    func unregister(_ text: String) {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        lock.lock(); defer { lock.unlock() }
        texts.remove(normalized)
    }

    /// Remove every registered sensitive text (used by tests).
    func removeAll() {
        lock.lock(); defer { lock.unlock() }
        texts.removeAll()
    }

    /// `true` if `selected` overlaps any registered text in either direction.
    func isRegistered(_ selected: String) -> Bool {
        let normalized = selected.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return false }
        lock.lock(); defer { lock.unlock() }
        if texts.isEmpty { return false }
        for sensitive in texts {
            if normalized.contains(sensitive) || sensitive.contains(normalized) {
                return true
            }
        }
        return false
    }
}

/// UI-independent, pure Swift helper that decides whether a piece of text
/// contains sensitive data before it is sent to the server. Ported from the
/// Flutter library's `SensitiveDataGuard`.
///
/// Two-layer defense:
///   1. Overlap with texts manually marked via `SensitiveTextRegistry`.
///   2. Turkey-specific + general PII patterns (email, TR IBAN, TR GSM,
///      TCKN national ID with checksum, credit cards with Luhn).
///
/// If either matches, the text is treated as sensitive and no translation
/// request should be sent.
enum SensitiveDataGuard {

    /// Email address.
    private static let email = regex(#"[\w.+-]+@[\w-]+\.[\w.-]+"#)

    /// Turkish IBAN (TR + 24 digits, may contain spaces).
    private static let ibanTr = regex(
        #"\bTR\d{2}(?:[ ]?\d{4}){5}[ ]?\d{2}\b"#, caseInsensitive: true)

    /// Turkish mobile number: optional +90 / 0, followed by 5xx xxx xx xx.
    private static let gsm = regex(#"(?:\+90|0)?[ ]?5\d{2}[ ]?\d{3}[ ]?\d{2}[ ]?\d{2}"#)

    /// 11-digit candidate (Turkish national ID candidate), checksum-validated.
    private static let elevenDigits = regex(#"\b\d{11}\b"#)

    /// 13–19 digit candidate, possibly with spaces/dashes (credit card
    /// candidate), Luhn-validated.
    private static let cardCandidate = regex(#"\b(?:\d[ -]?){12,18}\d\b"#)

    /// Returns `true` if `text` contains sensitive data.
    ///
    /// - Parameters:
    ///   - text: the candidate text.
    ///   - extraPatterns: additional host-supplied patterns; a match on any of
    ///     them also marks the text sensitive.
    static func isSensitive(_ text: String, extraPatterns: [NSRegularExpression] = []) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return false }

        // 1) Overlap with manually marked (registered) texts.
        if SensitiveTextRegistry.shared.isRegistered(trimmed) { return true }

        // 2) Direct pattern matches.
        if hasMatch(email, in: trimmed) { return true }
        if hasMatch(ibanTr, in: trimmed) { return true }
        if hasMatch(gsm, in: trimmed) { return true }

        // 3) Patterns that require checksum validation.
        for candidate in matches(elevenDigits, in: trimmed) {
            if isValidTckn(candidate) { return true }
        }
        for candidate in matches(cardCandidate, in: trimmed) {
            let digits = candidate.filter { $0.isNumber }
            if digits.count >= 13, digits.count <= 19, passesLuhn(digits) {
                return true
            }
        }

        // 4) Host-supplied custom patterns.
        for pattern in extraPatterns {
            if hasMatch(pattern, in: trimmed) { return true }
        }

        return false
    }

    // MARK: - Checksums

    /// Turkish national ID (T.C. Kimlik No) checksum validation.
    ///
    /// Rules: 11 digits, first digit cannot be 0; the 10th digit is
    /// `((sum of odd-indexed) * 7 - (sum of even-indexed)) % 10`; the 11th
    /// digit is the sum of the first 10 digits mod 10.
    static func isValidTckn(_ value: String) -> Bool {
        guard value.count == 11 else { return false }
        let d = value.compactMap { $0.wholeNumberValue }
        guard d.count == 11 else { return false }
        if d[0] == 0 { return false }

        let oddSum = d[0] + d[2] + d[4] + d[6] + d[8]
        let evenSum = d[1] + d[3] + d[5] + d[7]
        // Swift `%` can be negative; Dart's `%` is always non-negative.
        let tenth = (((oddSum * 7) - evenSum) % 10 + 10) % 10
        if tenth != d[9] { return false }

        let firstTenSum = d.prefix(10).reduce(0, +)
        return firstTenSum % 10 == d[10]
    }

    /// Credit card number validation using the Luhn algorithm.
    static func passesLuhn(_ digits: String) -> Bool {
        var sum = 0
        var alternate = false
        for char in digits.reversed() {
            guard var n = char.wholeNumberValue else { return false }
            if alternate {
                n *= 2
                if n > 9 { n -= 9 }
            }
            sum += n
            alternate.toggle()
        }
        return sum % 10 == 0
    }

    // MARK: - Regex helpers

    private static func regex(_ pattern: String, caseInsensitive: Bool = false) -> NSRegularExpression {
        let options: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
        // These patterns are compile-time constants; a failure is a programmer error.
        return try! NSRegularExpression(pattern: pattern, options: options)
    }

    private static func hasMatch(_ regex: NSRegularExpression, in text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }

    private static func matches(_ regex: NSRegularExpression, in text: String) -> [String] {
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, options: [], range: range).compactMap { match in
            guard let r = Range(match.range, in: text) else { return nil }
            return String(text[r])
        }
    }
}
