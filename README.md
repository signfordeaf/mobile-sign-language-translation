# SignForDeaf

A native iOS SDK that adds **sign language translation** to any app. It shows a
floating, AssistiveTouch‑style button on screen; tapping it turns on
“tap‑to‑translate” mode, and a single tap on any text then plays its sign
language translation video in a native bottom sheet.

- 🎯 Floating, draggable, edge‑sticky button that toggles tap‑to‑translate mode
- 👆 Tap any text while active → instant translation (`UILabel`, `UITextField`, `UITextView`, SwiftUI `Text`)
- 📱 Native bottom‑sheet video player (AVKit) with loading, error/retry and a marquee caption
- 🌍 3 languages: Turkish, English, Arabic
- 🎨 Themeable (`primaryColor`, `textColor`)
- 🔒 Sensitive‑information filtering — never sends PII (email, TR IBAN/GSM/TCKN, cards) or app‑marked text to the backend
- 🧩 Works with **UIKit** and **SwiftUI**
- ♿ VoiceOver / accessibility support
- 📦 Zero third‑party dependencies — Apple frameworks only

## Requirements

- iOS **15.0+**
- Swift 5.9+ / Xcode 15+

## Installation

SignForDeaf is distributed as a Swift Package.

### Xcode

1. **File → Add Package Dependencies…**
2. Enter the repository URL:

   ```
   https://github.com/signfordeaf/MobileSignLanguageTranslation.git
   ```

3. Add the **SignForDeaf** library product to your app target.

### Package.swift

```swift
dependencies: [
    .package(
        url: "https://github.com/signfordeaf/MobileSignLanguageTranslation.git",
        from: "1.1.0"
    )
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "SignForDeaf", package: "MobileSignLanguageTranslation")
        ]
    )
]
```

## Quick start

Configure the SDK **once**, at the root of your app. From then on the floating
button and tap‑to‑translate work everywhere — no per‑screen setup.

### SwiftUI

```swift
import SwiftUI
import SignForDeaf

@main
struct MyApp: App {
    init() {
        SignForDeaf.shared.configure(
            SignForDeafConfig(
                apiKey: "YOUR_API_KEY",
                apiUrl: "https://kor01rp02.signfordeaf.com",
                language: .english
            )
        )
    }

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
```

### UIKit

```swift
import UIKit
import SignForDeaf

func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {

    SignForDeaf.shared.configure(
        SignForDeafConfig(
            apiKey: "YOUR_API_KEY",
            apiUrl: "https://kor01rp02.signfordeaf.com",
            language: .english,
            theme: SignForDeafTheme(primaryColor: "#6750A4", textColor: "#1C1B1F")
        )
    )
    return true
}
```

## The floating button & tap‑to‑translate

After `configure`, a floating logo button appears on the right edge. It drags
anywhere and sticks to the nearest edge, tucking partly off‑screen when idle.

- **Tap the button** → tap‑to‑translate mode turns ON (the button fills with `primaryColor`).
- **Tap any text** while active → its translation plays in the bottom sheet.
- **Tap the button again** → mode turns OFF.

Control it from code:

```swift
SignForDeaf.shared.showFloatingButton()            // shown automatically by configure
SignForDeaf.shared.hideFloatingButton()
SignForDeaf.shared.setTapToTranslateActive(true)   // toggle the mode programmatically

SignForDeaf.shared.isTapToTranslateActive          // current mode (read‑only)
```

Set `showFloatingButton: false` in the config if you want to manage the button
yourself.

## SwiftUI text

SwiftUI draws `Text` rather than backing it with a `UILabel`, so pass the source
string explicitly with the modifier or the drop‑in view. Like UIKit text, it
translates on a **single tap while tap‑to‑translate mode is active**:

```swift
Text("Hello world").signTranslatable("Hello world")

// or the drop-in view:
SignText("Hello world")
```

## Programmatic translation

Present the bottom sheet for a piece of text yourself, without a tap:

```swift
SignForDeaf.shared.translate("Thank you")
```

## Sensitive‑information filtering

To protect privacy, text is checked **before** any translation request is made.
If it looks sensitive, **no request is sent** — the bottom sheet shows a “this
content cannot be translated” notice instead. Two layers of protection:

**1. Automatic detection** (on by default) blocks common personal data:

- Email addresses
- Turkish IBAN (`TR` + 24 digits)
- Turkish mobile numbers (`5xx xxx xx xx`)
- TCKN national IDs (checksum‑validated, so random 11‑digit numbers pass through)
- Credit cards (Luhn‑validated)

**2. Manual marking** — tell the SDK which of your own content is sensitive.

SwiftUI — mark a view with the modifier (pass the same string as the text):

```swift
Text("TCKN: 10000000146")
    .signSensitive("TCKN: 10000000146")
```

UIKit — set the flag on any view (applies to its whole subtree):

```swift
myLabel.isSignForDeafSensitive = true
```

Get notified whenever something is blocked:

```swift
SignForDeaf.shared.onSensitiveBlocked = { text in
    print("Blocked sensitive text: \(text)")
}
```

Tune it in the config — turn filtering off, or add your own patterns:

```swift
SignForDeaf.shared.configure(
    SignForDeafConfig(
        apiKey: "YOUR_API_KEY",
        apiUrl: "https://kor01rp02.signfordeaf.com",
        sensitiveFilteringEnabled: true,           // default; set false to disable
        sensitivePatterns: [#"\bEMP-\d{6}\b"#]      // extra regexes, e.g. employee IDs
    )
)
```

## Enable / disable at runtime

```swift
SignForDeaf.shared.disable()   // hides the button, stops tap-to-translate
SignForDeaf.shared.enable()    // restores it using the last configuration
SignForDeaf.shared.isEnabled   // current state (read-only)
```

## Configuration

`SignForDeafConfig`:

| Field                | Type                   | Default                | Description                                   |
| -------------------- | ---------------------- | ---------------------- | --------------------------------------------- |
| `apiKey`             | `String`               | — (required)           | API key, sent as `rk`.                        |
| `apiUrl`             | `String`               | — (required)           | Translation API base URL.                     |
| `originUrl`          | `String`               | `https://webplugin.signfordeaf.com` | Sent as the `url` query param and the `Origin` header. |
| `language`           | `SignForDeafLanguage`  | `.turkish`             | UI language & translation language code.      |
| `fdid`               | `String`               | `"16"`                 | Form / dictionary ID.                         |
| `tid`                | `String`               | `"23"`                 | Translator ID.                                |
| `theme`              | `SignForDeafTheme`     | `#6750A4` / `#1C1B1F`  | `primaryColor` and `textColor` (hex strings). |
| `showFloatingButton` | `Bool`                 | `true`                 | Show the floating button automatically.       |
| `floatingButton`     | `SignForDeafFloatingButtonConfig` | defaults    | Floating button appearance & behavior (below). |
| `sensitiveFilteringEnabled` | `Bool`          | `true`                 | Block sensitive text before it is sent (see [Sensitive‑information filtering](#sensitive-information-filtering)). |
| `sensitivePatterns`  | `[String]`             | `[]`                   | Extra regex patterns that mark text as sensitive. |

### Languages

`SignForDeafLanguage`: `.turkish`, `.english`, `.arabic`.

### Theme

```swift
SignForDeafTheme(primaryColor: "#6750A4", textColor: "#1C1B1F")
```

`primaryColor` tints the logo, title, close button, loading indicator and retry
button. `textColor` is used for the caption under the video.

### Floating button

Customize the floating button’s appearance and idle behavior with
`SignForDeafFloatingButtonConfig`. Any color left `nil` falls back to the
theme’s `primaryColor`.

```swift
SignForDeaf.shared.configure(
    SignForDeafConfig(
        apiKey: "YOUR_API_KEY",
        apiUrl: "https://kor01rp02.signfordeaf.com",
        floatingButton: SignForDeafFloatingButtonConfig(
            size: 52,
            activeBackgroundColor: "#6750A4",
            idleBehavior: .peek,          // .peek / .fade / .none
            hintMaxShows: 2
        )
    )
)
```

| Field                   | Type                       | Default     | Description                              |
| ----------------------- | -------------------------- | ----------- | ---------------------------------------- |
| `size`                  | `CGFloat`                  | `44`        | Button diameter (pt).                    |
| `backgroundColor`       | `String`                   | `#FFFFFF`   | Fill while inactive.                     |
| `activeBackgroundColor` | `String?`                  | `nil` → primary | Fill while active.                   |
| `iconColor`             | `String?`                  | `nil` → primary | Logo tint while inactive.            |
| `activeIconColor`       | `String`                   | `#FFFFFF`   | Logo tint while active.                  |
| `borderColor`           | `String?`                  | `nil` → primary | Border while inactive.               |
| `idleBehavior`          | `SignForDeafIdleBehavior`  | `.peek`     | `.peek` (slide off edge), `.fade`, `.none`. |
| `idleDelay`             | `TimeInterval`             | `2.5`       | Idle delay in seconds.                   |
| `hintMaxShows`          | `Int`                      | `2`         | Times the “tap to translate” hint shows. |

## Example app

A runnable demo lives in [`TestApp/`](TestApp). Open
`TestApp/TestApp.xcodeproj` in Xcode and run it on a simulator or device. It
lets you enter an API key, pick a language and theme color, then try
tap‑to‑translate on UIKit and SwiftUI text and drive every SDK control.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release notes.

## License

See the repository for license details.
