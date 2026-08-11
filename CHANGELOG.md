# Changelog

All notable changes to **SignForDeaf** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-08-10

v2 is a change of premise: **sign language and the host app are used at the same
time.** No scrim, a corner player instead of a bottom sheet, taps classified as
they happen, and one sentence translated instead of a whole paragraph. See
[`docs/`](docs) for the full platform-independent behavior specification.

### Changed (breaking)

- **The SDK is now off by default.** `configure(_:)` no longer auto-enables it —
  call `SignForDeaf.shared.enable()` (or set `SignForDeafConfig.autoEnable = true`).
  An accessibility preference belongs in the host's own settings.
- **`originUrl` now defaults to `apiUrl`** when not given (was a fixed default
  host). Pass `originUrl:` explicitly to keep a different origin.
- The modal bottom sheet + full-screen scrim is replaced by a **non-modal corner
  player**: a stage (video / idle signer loop), a control bar *below* the stage,
  a caption, and a window pill. The host app stays readable and tappable
  throughout. Collapsing folds the player to a single bar and hands every tap back.
- Tap-to-translate now **declines during hit testing** instead of catching every
  tap: a labelled control is *read*, an unlabelled one still *operates*, and
  scrolling passes through. One sentence under the finger is translated, not the
  whole paragraph.
- **The signer is chosen by `translator`, not raw ids.** `tid`/`fdid` are now
  optional **overrides** (`String?`, default `nil`); pick a signer with
  `translator` (`.kadir` / `.hesna` / `.jason` / `.owais`) instead. The default
  signer is now **Hesna** (was Kadir). Existing calls that pass `tid:`/`fdid:`
  still compile and keep overriding.

### Added

- **Per-sentence translation** with a lossless sentence splitter tuned for Turkish
  (`T.C.`, `A.Ş.`, grouped numbers, numbered clauses), a 40-entry translation
  cache, and one-sentence-ahead prefetch.
- **Translate any on-screen text.** Besides `UILabel` / read-only `UITextView`,
  the SDK reads a `UIButton`'s title (including the iOS 15+
  `configuration.title`). With `accessibilityTextFallback` on, text that UIKit
  can't see — **SwiftUI `Text` and buttons**, which are drawn into SwiftUI's own
  layer — is reached through the accessibility layer, so tapping any label
  translates it (images and sliders excluded).
- **Long-press to activate** (`longPressToActivate`): while the player is open, a
  tap on a labelled control translates its label and a long press runs the
  control — no need to collapse the player. UIKit controls fire in place; other
  controls (SwiftUI) briefly release the claim so the next tap operates them.
- **Idle signer loop**: four bundled boomerang clips (Kadir, Hesna, Jason, Owais),
  chosen from the selected `translator` (or the id overrides in effect); blurred
  with a spinner while loading, clean while idle. A backend `tid`/`fdid` returned
  with a translation is adopted mid-session and becomes the **top authority** —
  once adopted, no configured pin overrides the API's signer.
- **Corner player controls**: play/pause, speed cycling, loop, optional contact,
  optional 👍/👎 feedback, an auto-scrolling caption, and a collapsed bar.
- **Lifecycle event stream** — `SignForDeaf.shared.onEvent` (docs/12).
- New `SignForDeafConfig` options: `translator` (signer selection),
  `card` (player layout & controls), `accessibility` (announcements & labels),
  `granularity`, `maxSegmentChars`, `longPressToTranslate`, `longPressToActivate`,
  `accessibilityTextFallback`, `smartPassthrough`, `autoEnable`; theme gains
  `onPrimaryColor`, `surfaceColor`, `cornerRadius`.
- WCAG 4.5:1 contrast enforcement for foregrounds over configured backgrounds.
- Floating-button placement (docked edge + vertical fraction) now survives the
  player opening/closing and disable/enable — fixing the v1 "button jumps back"
  bug — and the player opens on the button's docked side.

### Not yet implemented

- The selection-menu "Sign Language" item on already-selectable text (one of the
  secondary text-entry paths in docs/08). The tap, long-press and programmatic
  paths are complete.

## [1.1.0] - 2026-07-23

### Added

- `SignForDeafFloatingButtonConfig` — customize the floating button's `size`,
  `backgroundColor`, `activeBackgroundColor`, `iconColor`, `activeIconColor`,
  `borderColor`, `idleBehavior` (`.peek` / `.fade` / `.none`), `idleDelay` and
  `hintMaxShows`. Unset colors fall back to the theme `primaryColor`.
- `SignForDeafConfig.originUrl` — configurable Origin URL, sent as the `url`
  query parameter and the `Origin` request header.
- A runnable example app under [`TestApp/`](TestApp), now included in the repo.
- **Sensitive-information filtering** — text is checked before any translation
  request is sent; if it looks sensitive, no request leaves the device and the
  bottom sheet shows a "cannot be translated" notice instead. Two layers:
  - Automatic PII detection (`SensitiveDataGuard`): email, Turkish IBAN, Turkish
    GSM numbers, TCKN national ID (checksum-validated) and credit cards (Luhn).
  - Manual marking: the SwiftUI `.signSensitive(_:)` modifier and the UIKit
    `UIView.isSignForDeafSensitive` flag register content the app knows is
    sensitive.
- `SignForDeafConfig.sensitiveFilteringEnabled` (default `true`) to toggle the
  filter, and `SignForDeafConfig.sensitivePatterns` for extra custom regexes.
- `SignForDeaf.shared.onSensitiveBlocked` callback, invoked with the offending
  text whenever a translation is blocked.

### Changed

- Supported languages narrowed to **Turkish, English and Arabic**
  (`SignForDeafLanguage`).
- The `url` query parameter and the `Origin` request header now use `originUrl`
  instead of `apiUrl`.
- The bottom sheet now slides up from the bottom as it is revealed, and the
  translated text under the video uses the theme's primary color.
