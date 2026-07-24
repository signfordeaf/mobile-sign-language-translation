// Config/SignForDeafConfig.swift

import UIKit

// MARK: - Language

/// Languages supported by the SignForDeaf translation service.
public enum SignForDeafLanguage: String, CaseIterable {
    case turkish = "tr"
    case english = "en"
    case arabic = "ar"

    /// Create a language from a loose string (e.g. "tr", "turkish").
    /// Falls back to `.turkish` for unknown values.
    public init(from string: String) {
        switch string.lowercased() {
        case "tr", "turkish": self = .turkish
        case "en", "english": self = .english
        case "ar", "arabic": self = .arabic
        default: self = .turkish
        }
    }

    /// Numeric code expected by the translation API (`language` query param).
    /// tr→1, en→2, ar→6 (server-fixed codes).
    var apiCode: String {
        switch self {
        case .turkish: return "1"
        case .english: return "2"
        case .arabic: return "6"
        }
    }

    /// Localized strings used throughout the UI for this language.
    var strings: LocalizedStrings { LocalizedStrings.table[self] ?? LocalizedStrings.turkish }
}

// MARK: - Localized Strings

/// UI strings localized per language. Ported from the RN library's
/// `src/constants.ts` `LOCALIZED_STRINGS`.
struct LocalizedStrings {
    let menuTitle: String
    let businessName: String
    let loading: String
    let error: String
    let close: String
    let closeHint: String
    let videoPlayerLabel: String
    let translationReady: String
    let retry: String
    let videoLoadError: String
    let tapToTranslateHint: String
    let sensitiveBlocked: String

    static let table: [SignForDeafLanguage: LocalizedStrings] = [
        .turkish: turkish,
        .english: english,
        .arabic: arabic,
    ]

    static let turkish = LocalizedStrings(
        menuTitle: "İşaret Dili",
        businessName: "Engelsiz Çeviri",
        loading: "Çeviriliyor...",
        error: "Çeviri işlemi şu anda gerçekleştirilemiyor. Lütfen daha sonra tekrar deneyiniz.",
        close: "Kapat",
        closeHint: "İşaret dili çevirisini kapatmak için çift dokunun",
        videoPlayerLabel: "İşaret dili videosu oynatılıyor",
        translationReady: "İşaret dili çevirisi hazır",
        retry: "Tekrar Dene",
        videoLoadError: "Video yüklenemedi",
        tapToTranslateHint: "Çevirmek için bir yazıya dokunun",
        sensitiveBlocked: "Bu içerik hassas veri içerdiği için çevrilemiyor."
    )

    static let english = LocalizedStrings(
        menuTitle: "Sign Language",
        businessName: "SignForDeaf",
        loading: "Translating...",
        error: "Translation is not available at the moment. Please try again later.",
        close: "Close",
        closeHint: "Double tap to close the sign language translation",
        videoPlayerLabel: "Sign language video is playing",
        translationReady: "Sign language translation is ready",
        retry: "Try Again",
        videoLoadError: "Video could not be loaded",
        tapToTranslateHint: "Tap on any text to translate it",
        sensitiveBlocked: "This content contains sensitive data and cannot be translated."
    )

    static let arabic = LocalizedStrings(
        menuTitle: "لغة الإشارة",
        businessName: "لغة الإشارة",
        loading: "جارٍ الترجمة...",
        error: "لا يمكن إجراء عملية الترجمة في الوقت الحالي. يرجى المحاولة مرة أخرى في وقت لاحق.",
        close: "إغلاق",
        closeHint: "انقر نقرًا مزدوجًا لإغلاق ترجمة لغة الإشارة",
        videoPlayerLabel: "يتم تشغيل فيديو لغة الإشارة",
        translationReady: "ترجمة لغة الإشارة جاهزة",
        retry: "حاول مرة أخرى",
        videoLoadError: "تعذّر تحميل الفيديو",
        tapToTranslateHint: "انقر على أي نص لترجمته",
        sensitiveBlocked: "يحتوي هذا المحتوى على بيانات حساسة ولا يمكن ترجمته."
    )
}

// MARK: - Theme

/// Theme colors for the sign language bottom sheet. Mirrors the simplified
/// theme model from the RN library (only `primaryColor` + `textColor`).
public struct SignForDeafTheme {
    /// Applied to logo, title, close button, loading indicator and retry button.
    public var primaryColor: String
    /// Applied to the display text shown under the video.
    public var textColor: String

    public init(primaryColor: String = "#6750A4", textColor: String = "#1C1B1F") {
        self.primaryColor = primaryColor
        self.textColor = textColor
    }

    /// Default fallback color for `primaryColor` (#6750A4).
    static let defaultPrimary = UIColor(red: 0.4, green: 0.31, blue: 0.64, alpha: 1.0)
    /// Default fallback color for `textColor` (#1C1B1F).
    static let defaultText = UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)

    var primaryUIColor: UIColor { UIColor(hex: primaryColor) ?? SignForDeafTheme.defaultPrimary }
    var textUIColor: UIColor { UIColor(hex: textColor) ?? SignForDeafTheme.defaultText }
}

// MARK: - Floating button

/// What the floating button does after a period of inactivity.
public enum SignForDeafIdleBehavior: String, CaseIterable {
    /// Slide partly off the nearest edge and dim (default).
    case peek
    /// Dim in place without moving.
    case fade
    /// Stay fully visible.
    case none
}

/// Appearance and behavior of the floating tap-to-translate button. Mirrors the
/// RN library's `FloatingButtonConfig`. Colors are hex strings; the ones that
/// default to `nil` fall back to the theme's `primaryColor`.
public struct SignForDeafFloatingButtonConfig {
    /// Button diameter in points. Default `44`.
    public var size: CGFloat
    /// Fill color while inactive. Default `#FFFFFF`.
    public var backgroundColor: String
    /// Fill color while active. `nil` → theme `primaryColor`.
    public var activeBackgroundColor: String?
    /// Logo tint while inactive. `nil` → theme `primaryColor`.
    public var iconColor: String?
    /// Logo tint while active. Default `#FFFFFF`.
    public var activeIconColor: String
    /// Border color while inactive. `nil` → theme `primaryColor`.
    public var borderColor: String?
    /// What happens when the button goes idle. Default `.peek`.
    public var idleBehavior: SignForDeafIdleBehavior
    /// Seconds of inactivity before the idle behavior runs. Default `2.5`.
    public var idleDelay: TimeInterval
    /// How many times the "tap to translate" hint is shown, ever. Default `2`.
    public var hintMaxShows: Int

    public init(
        size: CGFloat = 44,
        backgroundColor: String = "#FFFFFF",
        activeBackgroundColor: String? = nil,
        iconColor: String? = nil,
        activeIconColor: String = "#FFFFFF",
        borderColor: String? = nil,
        idleBehavior: SignForDeafIdleBehavior = .peek,
        idleDelay: TimeInterval = 2.5,
        hintMaxShows: Int = 2
    ) {
        self.size = size
        self.backgroundColor = backgroundColor
        self.activeBackgroundColor = activeBackgroundColor
        self.iconColor = iconColor
        self.activeIconColor = activeIconColor
        self.borderColor = borderColor
        self.idleBehavior = idleBehavior
        self.idleDelay = idleDelay
        self.hintMaxShows = hintMaxShows
    }

    /// Resolves the button's concrete colors, using `themePrimary` for any
    /// unset (`nil`) color.
    func resolved(themePrimary: UIColor) -> FloatingButtonAppearance {
        func color(_ hex: String?, _ fallback: UIColor) -> UIColor {
            guard let hex = hex else { return fallback }
            return UIColor(hex: hex) ?? fallback
        }
        return FloatingButtonAppearance(
            size: size,
            backgroundColor: UIColor(hex: backgroundColor) ?? .white,
            activeBackgroundColor: color(activeBackgroundColor, themePrimary),
            iconColor: color(iconColor, themePrimary),
            activeIconColor: UIColor(hex: activeIconColor) ?? .white,
            borderColor: color(borderColor, themePrimary),
            idleBehavior: idleBehavior,
            idleDelay: idleDelay,
            hintMaxShows: hintMaxShows)
    }
}

/// Concrete, resolved floating-button appearance handed to the controller.
struct FloatingButtonAppearance {
    var size: CGFloat
    var backgroundColor: UIColor
    var activeBackgroundColor: UIColor
    var iconColor: UIColor
    var activeIconColor: UIColor
    var borderColor: UIColor
    var idleBehavior: SignForDeafIdleBehavior
    var idleDelay: TimeInterval
    var hintMaxShows: Int
}

// MARK: - Config

/// Configuration for the SignForDeaf SDK. Pass this once to
/// `SignForDeaf.shared.configure(_:)` at app startup.
public struct SignForDeafConfig {
    /// API key provided by SignForDeaf (sent as the `rk` query param).
    public let apiKey: String
    /// Base URL of the translation API, e.g. `https://kor01rp02.signfordeaf.com`.
    public let apiUrl: String
    /// Origin URL sent as the `url` query param and the `Origin` request header.
    /// Defaults to `https://webplugin.signfordeaf.com`.
    public let originUrl: String
    /// Language used for menu titles, UI strings and the API `language` code.
    public let language: SignForDeafLanguage
    /// Form/Dictionary ID (`fdid` query param). Defaults to "16".
    public let fdid: String
    /// Translator ID (`tid` query param). Defaults to "23".
    public let tid: String
    /// Theme colors for the bottom sheet.
    public let theme: SignForDeafTheme
    /// Whether the floating tap-to-translate button appears automatically once
    /// the SDK is configured. Defaults to `true`.
    public let showFloatingButton: Bool
    /// Appearance and behavior of the floating button.
    public let floatingButton: SignForDeafFloatingButtonConfig
    /// Whether sensitive-information filtering is active. When `true` (default),
    /// text that looks like personal/sensitive data (email, TR IBAN/GSM/TCKN,
    /// credit cards) or that was marked sensitive is blocked before any
    /// translation request is sent.
    public let sensitiveFilteringEnabled: Bool
    /// Additional regular-expression patterns (beyond the built-in set) that
    /// should mark text as sensitive. Invalid patterns are silently ignored.
    public let sensitivePatterns: [String]

    public init(
        apiKey: String,
        apiUrl: String,
        originUrl: String = "https://webplugin.signfordeaf.com",
        language: SignForDeafLanguage = .turkish,
        fdid: String = "16",
        tid: String = "23",
        theme: SignForDeafTheme = SignForDeafTheme(),
        showFloatingButton: Bool = true,
        floatingButton: SignForDeafFloatingButtonConfig = SignForDeafFloatingButtonConfig(),
        sensitiveFilteringEnabled: Bool = true,
        sensitivePatterns: [String] = []
    ) {
        self.apiKey = apiKey
        self.apiUrl = apiUrl
        self.originUrl = originUrl
        self.language = language
        self.fdid = fdid
        self.tid = tid
        self.theme = theme
        self.showFloatingButton = showFloatingButton
        self.floatingButton = floatingButton
        self.sensitiveFilteringEnabled = sensitiveFilteringEnabled
        self.sensitivePatterns = sensitivePatterns
    }

    /// `sensitivePatterns` compiled to `NSRegularExpression`, skipping any that
    /// fail to compile.
    var compiledSensitivePatterns: [NSRegularExpression] {
        sensitivePatterns.compactMap { try? NSRegularExpression(pattern: $0) }
    }
}
