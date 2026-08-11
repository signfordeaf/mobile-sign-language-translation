// Design/ColorContrast.swift

import UIKit

/// WCAG 2.1 contrast enforcement (docs/05-design-tokens.md §"Contrast enforcement").
///
/// The host chooses `primaryColor`/`surfaceColor` freely and pairs them with a
/// foreground guessed at configuration time. A white caption over a yellow brand
/// bar is unreadable, and unreadable is a defect here, not a styling opinion.
///
/// Before painting any foreground on a configured background, compute the
/// contrast ratio; if it is below 4.5:1 replace the foreground with black or
/// white — whichever scores higher against that background.
enum ColorContrast {

    /// Minimum acceptable WCAG contrast ratio for normal text.
    static let minimumRatio: CGFloat = 4.5

    /// WCAG relative luminance of a color (0 = black … 1 = white).
    static func relativeLuminance(_ color: UIColor) -> CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        // Resolve through the sRGB space so dynamic/pattern colors don't crash.
        let resolved = color.resolvedSRGB()
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        func lin(_ c: CGFloat) -> CGFloat {
            let c = max(0, min(1, c))
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    /// Contrast ratio between two colors. Runs from 1 (identical) to 21
    /// (black on white); symmetric in its arguments.
    static func ratio(_ a: UIColor, _ b: UIColor) -> CGFloat {
        let la = relativeLuminance(a)
        let lb = relativeLuminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    private static var cache: [String: UIColor] = [:]
    private static let lock = NSLock()

    /// Returns `foreground` if it already passes 4.5:1 against `background`,
    /// otherwise black or white — whichever reads better. Results are cached per
    /// `(background, foreground)` pair. Emits a one-line debug warning on a
    /// substitution (never in release).
    static func readable(
        _ foreground: UIColor,
        on background: UIColor,
        label: String = "foreground"
    ) -> UIColor {
        let key = cacheKey(foreground, background)
        lock.lock()
        if let hit = cache[key] { lock.unlock(); return hit }
        lock.unlock()

        let result: UIColor
        let r = ratio(foreground, background)
        if r >= minimumRatio {
            result = foreground
        } else {
            let whiteRatio = ratio(.white, background)
            let blackRatio = ratio(.black, background)
            let substitute: UIColor = whiteRatio >= blackRatio ? .white : .black
            #if DEBUG
            let sub = substitute == .white ? "white" : "black"
            print("[SignForDeaf] contrast: \(label) \(hexString(foreground)) on "
                + "\(hexString(background)) is \(String(format: "%.2f", r)):1 "
                + "(< 4.5:1) → substituting \(sub)")
            #endif
            result = substitute
        }

        lock.lock()
        cache[key] = result
        lock.unlock()
        return result
    }

    private static func cacheKey(_ fg: UIColor, _ bg: UIColor) -> String {
        "\(hexString(fg))|\(hexString(bg))"
    }

    private static func hexString(_ color: UIColor) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.resolvedSRGB().getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X",
                      Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255)))
    }
}

private extension UIColor {
    /// A best-effort sRGB representation so `getRed` always yields components.
    func resolvedSRGB() -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if getRed(&r, green: &g, blue: &b, alpha: &a) {
            return UIColor(red: r, green: g, blue: b, alpha: a)
        }
        // Grayscale or pattern colors: fall back through white/black component.
        var w: CGFloat = 0
        if getWhite(&w, alpha: &a) {
            return UIColor(red: w, green: w, blue: w, alpha: a)
        }
        return self
    }
}
