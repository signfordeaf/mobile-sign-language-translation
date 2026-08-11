// Tap/TextOffsetResolver.swift

import UIKit

/// Maps a touch point inside a text node to a **Character** index in its text,
/// so the tapped sentence can be picked (docs/08 §"From tap to segments", step 3).
///
/// Best-effort: when the point cannot be placed the caller falls back to
/// translating the whole paragraph, which is never worse than v1.
enum TextOffsetResolver {

    /// Character offset (consistent with `Array(text).count`) under `point`
    /// (in `view`'s coordinates), or `nil` if it cannot be resolved.
    static func offset(at point: CGPoint, in view: UIView) -> Int? {
        if let tv = view as? UITextView {
            return textViewOffset(at: point, in: tv)
        }
        if let label = view as? UILabel {
            return labelOffset(at: point, in: label)
        }
        return nil
    }

    private static func textViewOffset(at point: CGPoint, in tv: UITextView) -> Int? {
        let text = tv.text ?? ""
        guard !text.isEmpty else { return nil }
        let p = CGPoint(x: point.x - tv.textContainerInset.left,
                        y: point.y - tv.textContainerInset.top)
        let utf16Index = tv.layoutManager.characterIndex(
            for: p, in: tv.textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
        return characterIndex(fromUTF16 : utf16Index, in: text)
    }

    private static func labelOffset(at point: CGPoint, in label: UILabel) -> Int? {
        let attributed: NSAttributedString
        if let a = label.attributedText, a.length > 0 {
            attributed = a
        } else if let t = label.text, !t.isEmpty {
            attributed = NSAttributedString(string: t, attributes: [.font: label.font as Any])
        } else {
            return nil
        }
        let text = attributed.string

        let storage = NSTextStorage(attributedString: attributed)
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)
        let container = NSTextContainer(size: label.bounds.size)
        container.lineFragmentPadding = 0
        container.maximumNumberOfLines = label.numberOfLines
        container.lineBreakMode = label.lineBreakMode
        layout.addTextContainer(container)
        layout.ensureLayout(for: container)

        // UILabel centers its text block vertically within its bounds.
        let used = layout.usedRect(for: container)
        let yOffset = max(0, (label.bounds.height - used.height) / 2)
        let p = CGPoint(x: point.x, y: point.y - yOffset)

        let glyphIndex = layout.glyphIndex(for: p, in: container)
        let utf16Index = layout.characterIndexForGlyph(at: glyphIndex)
        return characterIndex(fromUTF16: utf16Index, in: text)
    }

    /// Convert a UTF-16 offset (what TextKit returns) to a grapheme index.
    private static func characterIndex(fromUTF16 utf16Index: Int, in text: String) -> Int? {
        guard utf16Index >= 0 else { return nil }
        let utf16 = text.utf16
        guard let u = utf16.index(utf16.startIndex, offsetBy: utf16Index, limitedBy: utf16.endIndex),
              let strIdx = u.samePosition(in: text) else {
            return text.count
        }
        return text.distance(from: text.startIndex, to: strIdx)
    }
}
