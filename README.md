# SignForDeaf

A native iOS SDK that adds **sign language translation** to any app. It shows a
floating, AssistiveTouch‑style button; tapping it opens a small **corner player**
and turns on “tap‑to‑translate” mode. A single tap on a sentence then plays its
sign language translation — **without taking the app away**: no scrim, the page
stays readable and tappable throughout.

> **v2.0** is a behavior change, not an API rewrite — see the
> [CHANGELOG](CHANGELOG.md). The SDK is now **off by default**: call
> `SignForDeaf.shared.enable()` after configuring. The full platform‑independent
> spec lives in [`docs/`](docs).

- 🎯 Floating, draggable, edge‑sticky button; the player opens on its docked side
- 👆 Tap a **sentence** while active → translation. Reads `UILabel`, `UITextView`, `UIButton` titles, and — with `accessibilityTextFallback` — **SwiftUI `Text` and buttons** too; or opt in explicitly with `signTranslatable` / `SignText`
- ✋ **Long‑press to activate**: with the menu open, tap a labelled control to translate it, long‑press to run it (`longPressToActivate`)
- 🧑‍🏫 Pick the signer with `translator` (Kadir / Hesna / Jason / Owais); the backend can override it mid‑session
- 🪟 Non‑modal **corner player** (AVFoundation): idle signer loop, control bar below the video, auto‑scrolling caption, collapse/close
- ⚡ 40‑entry cache + one‑sentence‑ahead prefetch; declines taps it shouldn't claim so buttons still work
- 🌍 3 languages: Turkish, English, Arabic
- 🎨 Themeable (`primaryColor`, `textColor`, `onPrimaryColor`, `surfaceColor`, `cornerRadius`) with WCAG contrast enforcement
- 🔒 Sensitive‑information filtering — never sends PII (email, TR IBAN/GSM/TCKN, cards) or app‑marked text, per sentence
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
        from: "2.0.0"
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

> ### ⚠️ Using SwiftUI? Turn on `accessibilityTextFallback: true`
>
> SwiftUI draws `Text` into its own layer instead of a `UILabel`, so the SDK
> can't see it by default and **SwiftUI text won't translate** without this flag.
> With it on, every on‑screen SwiftUI `Text` and button label translates on tap —
> no per‑view wrapping. It's **off by default** because it also makes SwiftUI
> **icon buttons** translate their accessibility label on tap (run them with a
> long press or by collapsing the player). Pure‑UIKit apps don't need it.

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
                apiUrl: "https://YOUR_API_HOST",
                language: .english,
                accessibilityTextFallback: true   // required for SwiftUI text to translate
            )
        )
        SignForDeaf.shared.enable()   // v2: the SDK is off until you enable it
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
            apiUrl: "https://YOUR_API_HOST",
            language: .english,
            theme: SignForDeafTheme(primaryColor: "#6750A4", textColor: "#1C1B1F")
        )
    )
    SignForDeaf.shared.enable()   // v2: the SDK is off until you enable it
    return true
}
```

## The floating button & tap‑to‑translate

After `configure` + `enable`, a floating logo button appears on the right edge.
It drags anywhere and sticks to the nearest edge, tucking partly off‑screen when
idle. Its resting place survives the player opening and closing.

- **Tap the button** → the corner player opens and tap‑to‑translate turns ON.
- **Tap a sentence** while active → its translation plays in the corner player,
  with the app underneath still usable. A labelled control is *read*; an
  unlabelled one still operates.
- **Long‑press a labelled control** (when `longPressToActivate` is on) → runs the
  control instead of translating, so you can operate the app without collapsing
  the player.
- **Collapse** (⌄) folds the player to a single bar and hands every tap back;
  **close** (✕) returns to the floating button.

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

SwiftUI draws `Text` into its own layer rather than backing it with a `UILabel`,
so global hit testing can't see it directly. Two ways to translate it:

**Automatic** — turn on `accessibilityTextFallback`. Any on‑screen SwiftUI `Text`
and button label is then reached through the accessibility layer and translates
on a single tap, just like UIKit text (images and sliders are excluded):

```swift
SignForDeaf.shared.configure(
    SignForDeafConfig(
        apiKey: "YOUR_API_KEY",
        apiUrl: "https://YOUR_API_HOST",
        accessibilityTextFallback: true
    )
)
```

**Explicit** — pass the source string with the modifier or the drop‑in view. Use
this where you want a guaranteed exact source, or where custom drawing makes the
accessibility label unreliable:

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
        apiUrl: "https://YOUR_API_HOST",
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
| `originUrl`          | `String?`              | `nil` → `apiUrl`       | Sent as the `url` query param and the `Origin` header. |
| `language`           | `SignForDeafLanguage`  | `.turkish`             | UI language & translation language code.      |
| `translator`         | `SignForDeafTranslator`| `.hesna`               | Signer whose `tid`/`fdid` are used and whose avatar shows first. |
| `fdid`               | `String?`              | `nil` → translator's   | Optional `fdid` override.                     |
| `tid`                | `String?`              | `nil` → translator's   | Optional `tid` override.                      |
| `theme`              | `SignForDeafTheme`     | `#6750A4` / `#1C1B1F`  | `primaryColor` and `textColor` (hex strings). |
| `showFloatingButton` | `Bool`                 | `true`                 | Show the floating button automatically.       |
| `floatingButton`     | `SignForDeafFloatingButtonConfig` | defaults    | Floating button appearance & behavior (below). |
| `longPressToActivate`| `Bool`                 | `false`                | Long‑press a labelled control to run it (tap still translates). |
| `accessibilityTextFallback` | `Bool`          | `false`                | Translate SwiftUI text/buttons via the accessibility layer. |
| `longPressToTranslate` | `Bool`               | `false`                | Long‑press to translate host‑made‑tappable text. |
| `smartPassthrough`   | `Bool`                 | `true`                 | Hand taps the SDK shouldn't claim back to the app. |
| `granularity`        | `SignForDeafGranularity` | `.sentence`          | Translate a sentence or the whole paragraph.  |
| `autoEnable`         | `Bool`                 | `false`                | Enable the SDK automatically after `configure`. |
| `sensitiveFilteringEnabled` | `Bool`          | `true`                 | Block sensitive text before it is sent (see [Sensitive‑information filtering](#sensitive-information-filtering)). |
| `sensitivePatterns`  | `[String]`             | `[]`                   | Extra regex patterns that mark text as sensitive. |

### Languages

`SignForDeafLanguage`: `.turkish`, `.english`, `.arabic`.

### Signer / translator

Pick who signs with `translator` — one of `.kadir`, `.hesna` (default), `.jason`,
`.owais`. The choice supplies the `tid`/`fdid` sent with every request and the
avatar shown on first launch; set `tid:`/`fdid:` only to override a specific id.
If the backend returns a different signer with a translation, that signer is
adopted mid‑session and shown from then on.

```swift
SignForDeafConfig(
    apiKey: "YOUR_API_KEY",
    apiUrl: "https://YOUR_API_HOST",
    translator: .jason
)
```

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
        apiUrl: "https://YOUR_API_HOST",
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
lets you enter an API key, pick a language, translator and theme color, then try
tap‑to‑translate on UIKit and SwiftUI text, exercise long‑press‑to‑activate on
UIKit and SwiftUI buttons, and drive every SDK control.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release notes.

## License

See the repository for license details.
