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

/// UI strings localized per language (docs/13-localization-and-accessibility.md).
/// Every user-visible string, including every screen-reader label, is localized.
struct LocalizedStrings {
    let menuTitle: String
    let businessName: String
    let loading: String
    let error: String
    let close: String
    let videoPlayerLabel: String
    let translationReady: String
    let tapToTranslateHint: String
    let sensitiveBlocked: String
    let translationModeLabel: String
    let playLabel: String
    let pauseLabel: String
    let loopLabel: String
    let speedLabel: String
    let contactLabel: String
    let collapseLabel: String
    let expandLabel: String
    let previousSentenceLabel: String
    let nextSentenceLabel: String
    let feedbackPositiveLabel: String
    let feedbackNegativeLabel: String
    let feedbackThanks: String
    // Legacy v1 strings still referenced by the old bottom sheet (removed in Phase 3).
    let closeHint: String
    let retry: String
    let videoLoadError: String

    /// Formatted sentence counter, e.g. "2 / 5" for index 1 of 5.
    static func sentenceCounter(index: Int, total: Int) -> String { "\(index + 1) / \(total)" }

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
        videoPlayerLabel: "İşaret dili videosu oynatılıyor",
        translationReady: "İşaret dili çevirisi hazır",
        tapToTranslateHint: "Cümlelere tıklayarak işaret dili çevirilerini başlatabilirsiniz.",
        sensitiveBlocked: "Bu içerik hassas veri içerdiği için işaret diline çevrilemez.",
        translationModeLabel: "İşaret dili çeviri modu",
        playLabel: "Oynat",
        pauseLabel: "Duraklat",
        loopLabel: "Tekrarla",
        speedLabel: "Oynatma hızı",
        contactLabel: "İletişime geçin",
        collapseLabel: "Küçült",
        expandLabel: "Genişlet",
        previousSentenceLabel: "Önceki cümle",
        nextSentenceLabel: "Sonraki cümle",
        feedbackPositiveLabel: "Çeviri anlaşılır",
        feedbackNegativeLabel: "Çeviri anlaşılır değil",
        feedbackThanks: "Geri bildiriminiz için teşekkürler",
        closeHint: "İşaret dili çevirisini kapatmak için çift dokunun",
        retry: "Tekrar Dene",
        videoLoadError: "Video yüklenemedi"
    )

    static let english = LocalizedStrings(
        menuTitle: "Sign Language",
        businessName: "SignForDeaf",
        loading: "Translating...",
        error: "Translation is not available at the moment. Please try again later.",
        close: "Close",
        videoPlayerLabel: "Sign language video is playing",
        translationReady: "Sign language translation is ready",
        tapToTranslateHint: "Tap a sentence to start its sign language translation.",
        sensitiveBlocked: "This content contains sensitive data and cannot be translated.",
        translationModeLabel: "Sign language translation mode",
        playLabel: "Play",
        pauseLabel: "Pause",
        loopLabel: "Repeat",
        speedLabel: "Playback speed",
        contactLabel: "Contact us",
        collapseLabel: "Collapse",
        expandLabel: "Expand",
        previousSentenceLabel: "Previous sentence",
        nextSentenceLabel: "Next sentence",
        feedbackPositiveLabel: "Translation is clear",
        feedbackNegativeLabel: "Translation is unclear",
        feedbackThanks: "Thanks for your feedback",
        closeHint: "Double tap to close the sign language translation",
        retry: "Try Again",
        videoLoadError: "Video could not be loaded"
    )

    static let arabic = LocalizedStrings(
        menuTitle: "لغة الإشارة",
        businessName: "SignForDeaf",
        loading: "جارٍ الترجمة...",
        error: "لا يمكن إجراء عملية الترجمة في الوقت الحالي. يرجى المحاولة مرة أخرى في وقت لاحق.",
        close: "إغلاق",
        videoPlayerLabel: "يتم تشغيل فيديو لغة الإشارة",
        translationReady: "ترجمة لغة الإشارة جاهزة",
        tapToTranslateHint: "انقر على جملة لبدء ترجمتها إلى لغة الإشارة.",
        sensitiveBlocked: "يحتوي هذا المحتوى على بيانات حساسة ولا يمكن ترجمته.",
        translationModeLabel: "وضع الترجمة بلغة الإشارة",
        playLabel: "تشغيل",
        pauseLabel: "إيقاف مؤقت",
        loopLabel: "تكرار",
        speedLabel: "سرعة التشغيل",
        contactLabel: "تواصل معنا",
        collapseLabel: "تصغير",
        expandLabel: "توسيع",
        previousSentenceLabel: "الجملة السابقة",
        nextSentenceLabel: "الجملة التالية",
        feedbackPositiveLabel: "الترجمة واضحة",
        feedbackNegativeLabel: "الترجمة غير واضحة",
        feedbackThanks: "شكرًا على ملاحظاتك",
        closeHint: "انقر نقرًا مزدوجًا لإغلاق ترجمة لغة الإشارة",
        retry: "حاول مرة أخرى",
        videoLoadError: "تعذّر تحميل الفيديو"
    )
}

// MARK: - Theme

/// Theme colors and radius for the player (docs/04-configuration.md §Theme).
///
/// `onPrimaryColor` and `textColor` MUST NOT be painted directly — read them
/// through `ColorContrast.readable(_:on:)`, which substitutes black or white when
/// the configured color fails WCAG 4.5:1 against the color behind it.
public struct SignForDeafTheme {
    /// Control bar fill, logo tint, active button fill, spinner. Default `#6750A4`.
    public var primaryColor: String
    /// Caption and in-stage messages, over the surface. Default `#1C1B1F`.
    public var textColor: String
    /// Anything drawn on the primary color — control icons, caption glyphs. Default `#FFFFFF`.
    public var onPrimaryColor: String
    /// Background behind the avatar video. Default `#FFFFFF`.
    public var surfaceColor: String
    /// Outer radius of the stage and the control bar. Default `16`.
    public var cornerRadius: CGFloat

    public init(
        primaryColor: String = "#6750A4",
        textColor: String = "#1C1B1F",
        onPrimaryColor: String = "#FFFFFF",
        surfaceColor: String = "#FFFFFF",
        cornerRadius: CGFloat = 16
    ) {
        self.primaryColor = primaryColor
        self.textColor = textColor
        self.onPrimaryColor = onPrimaryColor
        self.surfaceColor = surfaceColor
        self.cornerRadius = cornerRadius
    }

    /// Default fallback color for `primaryColor` (#6750A4).
    static let defaultPrimary = UIColor(red: 0.4, green: 0.31, blue: 0.64, alpha: 1.0)
    /// Default fallback color for `textColor` (#1C1B1F).
    static let defaultText = UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)

    var primaryUIColor: UIColor { UIColor(hex: primaryColor) ?? SignForDeafTheme.defaultPrimary }
    var textUIColor: UIColor { UIColor(hex: textColor) ?? SignForDeafTheme.defaultText }
    var onPrimaryUIColor: UIColor { UIColor(hex: onPrimaryColor) ?? .white }
    var surfaceUIColor: UIColor { UIColor(hex: surfaceColor) ?? .white }

    /// Control-icon / caption color, contrast-guarded against the primary bar.
    var resolvedOnPrimary: UIColor {
        ColorContrast.readable(onPrimaryUIColor, on: primaryUIColor, label: "onPrimaryColor")
    }
    /// In-stage message color, contrast-guarded against the surface.
    var resolvedOnSurface: UIColor {
        ColorContrast.readable(textUIColor, on: surfaceUIColor, label: "textColor")
    }
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

// MARK: - Granularity

/// Whether a tap translates the sentence under the finger or the whole paragraph.
public enum SignForDeafGranularity: String, CaseIterable {
    /// Translate the tapped sentence; report all sentences of the paragraph (default).
    case sentence
    /// Translate the whole paragraph as one segment (still length-chunked).
    case paragraph
}

/// A screen corner the player can animate in from.
public enum SignForDeafCorner: String, CaseIterable {
    case topLeft, topRight, bottomLeft, bottomRight

    var isTop: Bool { self == .topLeft || self == .topRight }
    var isRight: Bool { self == .topRight || self == .bottomRight }
}

// MARK: - Player (card) config

/// Appearance and controls of the corner player (docs/04-configuration.md §Player).
public struct SignForDeafCardConfig {
    /// Whether the user can drag the player around. Default `true`.
    public var draggable: Bool
    /// Corner the player animates in from. Default `.bottomRight`.
    public var initialCorner: SignForDeafCorner
    /// Requested stage height; width follows from the video aspect ratio. Default `240`.
    public var avatarHeight: CGFloat
    /// Width ceiling, used when a video turns out landscape. Default `212`.
    public var avatarMaxWidth: CGFloat
    /// Pins the idle signer. `nil` means *follow the ids*.
    public var placeholderAvatar: PlaceholderAvatar?
    /// Host-supplied idle clip overriding the bundled one. `""` opts out of video entirely.
    public var placeholderAsset: String?
    /// 👍/👎 pill over the avatar. Default `false`.
    public var showFeedback: Bool
    /// Contact button in the control bar. Default `false`.
    public var showContact: Bool
    /// Speed cycling button. Default `true`.
    public var showSpeed: Bool
    /// Loop toggle. Default `true`.
    public var showLoop: Bool
    /// Cycle order of the speed button. Default `[1.0, 1.2, 1.5, 2.0]`.
    public var speeds: [Double]
    /// Speed for a user with no stored preference. Default `1.0`.
    public var defaultSpeed: Double
    /// Loop setting for a user with no stored preference. Default `true`.
    public var defaultLooping: Bool

    public init(
        draggable: Bool = true,
        initialCorner: SignForDeafCorner = .bottomRight,
        avatarHeight: CGFloat = 240,
        avatarMaxWidth: CGFloat = 212,
        placeholderAvatar: PlaceholderAvatar? = nil,
        placeholderAsset: String? = nil,
        showFeedback: Bool = false,
        showContact: Bool = false,
        showSpeed: Bool = true,
        showLoop: Bool = true,
        speeds: [Double] = [1.0, 1.2, 1.5, 2.0],
        defaultSpeed: Double = 1.0,
        defaultLooping: Bool = true
    ) {
        self.draggable = draggable
        self.initialCorner = initialCorner
        self.avatarHeight = avatarHeight
        self.avatarMaxWidth = avatarMaxWidth
        self.placeholderAvatar = placeholderAvatar
        self.placeholderAsset = placeholderAsset
        self.showFeedback = showFeedback
        self.showContact = showContact
        self.showSpeed = showSpeed
        self.showLoop = showLoop
        self.speeds = speeds
        self.defaultSpeed = defaultSpeed
        self.defaultLooping = defaultLooping
    }
}

// MARK: - Accessibility config

/// Announcements and custom screen-reader labels (docs/04-configuration.md §Accessibility).
public struct SignForDeafAccessibilityConfig {
    /// Screen-reader announcement when a translation becomes playable. Default `true`.
    public var announceOnOpen: Bool
    /// Announcement when it goes away. Default `false`.
    public var announceOnClose: Bool
    /// Accessibility label of the video. `nil` → localized default.
    public var videoPlayerLabel: String?
    /// Accessibility label of ✕. `nil` → localized default.
    public var closeButtonLabel: String?
    /// Accessibility hint for the player surface. `nil` → localized default.
    public var bottomSheetHint: String?

    public init(
        announceOnOpen: Bool = true,
        announceOnClose: Bool = false,
        videoPlayerLabel: String? = nil,
        closeButtonLabel: String? = nil,
        bottomSheetHint: String? = nil
    ) {
        self.announceOnOpen = announceOnOpen
        self.announceOnClose = announceOnClose
        self.videoPlayerLabel = videoPlayerLabel
        self.closeButtonLabel = closeButtonLabel
        self.bottomSheetHint = bottomSheetHint
    }
}

// MARK: - Config

/// Configuration for the SignForDeaf SDK. Pass this once to
/// `SignForDeaf.shared.configure(_:)` at app startup.
public struct SignForDeafConfig {
    /// API key provided by SignForDeaf (sent as the `rk` query param).
    public let apiKey: String
    /// Base URL of the translation API (provided to you by SignForDeaf).
    public let apiUrl: String
    /// Origin URL sent as the `url` query param and the `Origin` request header.
    /// Defaults to `apiUrl` when not given (docs/04-configuration.md).
    public let originUrl: String
    /// Language used for menu titles, UI strings and the API `language` code.
    public let language: SignForDeafLanguage
    /// The translator whose bundled `tid`/`fdid` are used, and whose avatar is
    /// shown on first launch. Defaults to `.hesna`. The backend may still adopt a
    /// different signer mid-session (docs/10).
    public let translator: SignForDeafTranslator
    /// Optional `fdid` override. `nil` (default) uses the `translator`'s fdid;
    /// set it only to override that pair.
    public let fdid: String?
    /// Optional `tid` override. `nil` (default) uses the `translator`'s tid; set
    /// it only to override that pair.
    public let tid: String?

    /// The `tid` actually sent: the override if present and non-empty, else the
    /// selected translator's.
    public var effectiveTid: String {
        let override = tid?.trimmingCharacters(in: .whitespaces)
        if let override = override, !override.isEmpty { return override }
        return translator.ids.tid
    }
    /// The `fdid` actually sent: the override if present and non-empty, else the
    /// selected translator's.
    public var effectiveFdid: String {
        let override = fdid?.trimmingCharacters(in: .whitespaces)
        if let override = override, !override.isEmpty { return override }
        return translator.ids.fdid
    }
    /// Theme colors and radius for the player.
    public let theme: SignForDeafTheme
    /// Whether the floating tap-to-translate button appears automatically once
    /// the SDK is configured. Defaults to `true`.
    public let showFloatingButton: Bool
    /// Appearance and behavior of the floating button.
    public let floatingButton: SignForDeafFloatingButtonConfig
    /// Appearance and controls of the corner player.
    public let card: SignForDeafCardConfig
    /// Announcements and custom screen-reader labels.
    public let accessibility: SignForDeafAccessibilityConfig
    /// Whether a tap translates the sentence or the whole paragraph. Default `.sentence`.
    public let granularity: SignForDeafGranularity
    /// Longest text sent in one request. Default `900` (docs/09).
    public let maxSegmentChars: Int
    /// Long press translates text the host made tappable. Default `false`.
    public let longPressToTranslate: Bool
    /// While the player is open, a long press on a labelled control performs the
    /// control's action instead of translating its label — the single-gesture
    /// alternative to collapsing the player (docs/08 §"Long press to activate").
    /// Default `false`.
    public let longPressToActivate: Bool
    /// Hand taps the SDK should not claim to the host app. Default `true`.
    public let smartPassthrough: Bool
    /// Whether a control's **accessibility label** is used as a last-resort text
    /// source when its on-screen label is invisible to UIKit hit testing —
    /// notably SwiftUI buttons, whose text is not a `UILabel`. Default `false`.
    ///
    /// Trade-off: an icon-only control with an accessibility label (e.g. "Close")
    /// then reads as text and translates on tap; run it with a long press
    /// (`longPressToActivate`) or by collapsing the player.
    public let accessibilityTextFallback: Bool
    /// Whether the SDK turns itself on at start. Default `false`.
    public let autoEnable: Bool
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
        originUrl: String? = nil,
        language: SignForDeafLanguage = .turkish,
        translator: SignForDeafTranslator = .hesna,
        fdid: String? = nil,
        tid: String? = nil,
        theme: SignForDeafTheme = SignForDeafTheme(),
        showFloatingButton: Bool = true,
        floatingButton: SignForDeafFloatingButtonConfig = SignForDeafFloatingButtonConfig(),
        card: SignForDeafCardConfig = SignForDeafCardConfig(),
        accessibility: SignForDeafAccessibilityConfig = SignForDeafAccessibilityConfig(),
        granularity: SignForDeafGranularity = .sentence,
        maxSegmentChars: Int = 900,
        longPressToTranslate: Bool = false,
        longPressToActivate: Bool = false,
        smartPassthrough: Bool = true,
        accessibilityTextFallback: Bool = false,
        autoEnable: Bool = false,
        sensitiveFilteringEnabled: Bool = true,
        sensitivePatterns: [String] = []
    ) {
        self.apiKey = apiKey
        self.apiUrl = apiUrl
        // Origin defaults to the API URL — it identifies the calling app to the backend.
        self.originUrl = originUrl ?? apiUrl
        self.language = language
        self.translator = translator
        self.fdid = fdid
        self.tid = tid
        self.theme = theme
        self.showFloatingButton = showFloatingButton
        self.floatingButton = floatingButton
        self.card = card
        self.accessibility = accessibility
        self.granularity = granularity
        self.maxSegmentChars = maxSegmentChars
        self.longPressToTranslate = longPressToTranslate
        self.longPressToActivate = longPressToActivate
        self.smartPassthrough = smartPassthrough
        self.accessibilityTextFallback = accessibilityTextFallback
        self.autoEnable = autoEnable
        self.sensitiveFilteringEnabled = sensitiveFilteringEnabled
        self.sensitivePatterns = sensitivePatterns
    }

    /// `sensitivePatterns` compiled to `NSRegularExpression`, skipping any that
    /// fail to compile.
    var compiledSensitivePatterns: [NSRegularExpression] {
        sensitivePatterns.compactMap { try? NSRegularExpression(pattern: $0) }
    }
}
