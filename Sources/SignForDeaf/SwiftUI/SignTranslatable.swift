// SwiftUI/SignTranslatable.swift

#if canImport(SwiftUI)
import SwiftUI

@available(iOS 13.0, *)
extension View {

    /// Make any SwiftUI view translate `text` on a single tap **while
    /// tap-to-translate mode is active** (i.e. after the floating button has
    /// been turned on) — matching the UIKit behavior. When the mode is off, the
    /// tap does nothing. Because SwiftUI draws `Text` rather than backing it with
    /// a `UILabel`, the source string must be provided explicitly.
    ///
    /// ```swift
    /// Text("Merhaba dünya")
    ///     .signTranslatable("Merhaba dünya")
    /// ```
    public func signTranslatable(_ text: String) -> some View {
        onTapGesture {
            if SignForDeaf.shared.isTapToTranslateActive {
                SignForDeaf.shared.translate(text)
            }
        }
    }

    /// Mark this view's `text` as sensitive so it is never sent to the
    /// translation backend. While the view is on screen the string is
    /// registered; tapping it (or any selection overlapping it) shows the
    /// "sensitive content" notice instead of a translation.
    ///
    /// ```swift
    /// Text("TCKN: 10000000146")
    ///     .signSensitive("TCKN: 10000000146")
    /// ```
    public func signSensitive(_ text: String) -> some View {
        onAppear { SensitiveTextRegistry.shared.register(text) }
            .onDisappear { SensitiveTextRegistry.shared.unregister(text) }
    }
}

/// A drop-in SwiftUI text view that translates its own content to sign language
/// on a single tap while tap-to-translate mode is active.
///
/// ```swift
/// SignText("Merhaba dünya")
/// ```
@available(iOS 13.0, *)
public struct SignText: View {

    private let content: String

    public init(_ content: String) {
        self.content = content
    }

    public var body: some View {
        Text(content)
            .signTranslatable(content)
    }
}
#endif
