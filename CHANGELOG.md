# Changelog

All notable changes to **SignForDeaf** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
