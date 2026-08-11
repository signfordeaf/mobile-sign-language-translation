import SwiftUI
import UIKit
import SignForDeaf

/// A polished showcase for the SignForDeaf SDK.
///
/// 1. Enter your API key (or use the demo defaults) and tap **Configure**.
/// 2. A floating, AssistiveTouch-style button appears on the right edge.
/// 3. Tap it to turn ON tap-to-translate mode (the button fills with the theme color).
/// 4. Tap any text on screen — UIKit or SwiftUI — to play its sign-language translation.
struct ContentView: View {

    // MARK: - Configuration state
    // Prefilled from the Run scheme's Environment Variables (Xcode → Edit Scheme →
    // Run → Arguments)
    @State private var apiKey: String = Env.string("SIGNFORDEAF_API_KEY") ?? ""
    @State private var apiUrl: String =
        Env.string("SIGNFORDEAF_API_URL") ?? ""
    @State private var originUrl: String =
        Env.string("SIGNFORDEAF_ORIGIN_URL") ?? ""
    @State private var language: SignForDeafLanguage =
        Env.string("SIGNFORDEAF_LANGUAGE").map(SignForDeafLanguage.init(from:)) ?? .turkish
    @State private var translator: SignForDeafTranslator = .hesna
    @State private var themeHex: String = ThemePreset.presets[0].hex
    @State private var idleBehavior: SignForDeafIdleBehavior = .peek
    @State private var buttonSize: CGFloat = 44

    // MARK: - Live SDK state
    @State private var isConfigured = false
    @State private var isActive = false
    @State private var swiftUIActivations = 0
    @State private var uikitActivations = 0
    @StateObject private var blockLog = BlockLog()

    private let refresh = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    private let sampleShort = "Merhaba dünya, işaret dili çevirisine hoş geldiniz."
    private let sampleLong =
        "Bu daha uzun bir cümle; çeviri oynatılırken videonun altındaki altyazının nasıl kaydığını izleyebilirsiniz."

    // Sensitive-content samples (mirrors the Flutter example).
    private let sampleMarkedTCKN = "Marked: T.C. Kimlik No: 10000000146"
    private let sampleMarkedNote = "Gizli müşteri notu (UIKit ile işaretli)"
    private let sampleCard = "Unmarked but auto-detected: card 4242 4242 4242 4242"
    private let cardNumber = "4242 4242 4242 4242"

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header
                setupCard
                if isConfigured {
                    uikitCard
                    swiftUICard
                    activateCard
                    controlsCard
                    sensitiveCard
                    eventsCard
                }
                footer
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(Brand.background.ignoresSafeArea())
        .onReceive(refresh) { _ in
            // Keep the "Active" pill in sync when the floating button toggles it.
            isActive = SignForDeaf.shared.isTapToTranslateActive
        }
        .onAppear {
            handleLaunchArguments()
            autoConfigureIfNeeded()
        }
    }

    /// When the Run scheme sets `SIGNFORDEAF_AUTOCONFIGURE=1` and a real API key,
    /// configure + enable on launch — so pressing Run in Xcode just works, like
    /// the Flutter example's launch config.
    private func autoConfigureIfNeeded() {
        guard !isConfigured,
              Env.bool("SIGNFORDEAF_AUTOCONFIGURE"),
              !apiKey.isEmpty, apiKey != "xxx"
        else { return }
        configure()
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Brand.color)
                Image("BrandLogo")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(.white)
                    .scaledToFit()
                    .frame(width: 40, height: 40)
            }
            .frame(width: 68, height: 68)
            .shadow(color: Brand.color.opacity(0.35), radius: 10, y: 6)

            Text("SignForDeaf")
                .font(.system(size: 28, weight: .bold))
            Text("Sign language translation SDK — demo")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                StatusPill(title: isConfigured ? "Configured" : "Not configured",
                           on: isConfigured, systemImage: "checkmark.seal.fill")
                StatusPill(title: isActive ? "Tap-to-translate ON" : "Tap-to-translate OFF",
                           on: isActive, systemImage: "hand.tap.fill")
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Setup

    private var setupCard: some View {
        Card(number: "1", title: "Setup") {
            VStack(alignment: .leading, spacing: 14) {
                LabeledField(label: "API Key", placeholder: "your-api-key (rk)", text: $apiKey)
                LabeledField(label: "API URL", placeholder: "https://…", text: $apiUrl)
                LabeledField(label: "Origin URL", placeholder: "https://…", text: $originUrl)

                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("Language")
                    Picker("Language", selection: $language) {
                        ForEach(SignForDeafLanguage.allCases, id: \.self) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Brand.color)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("Translator")
                    Picker("Translator", selection: $translator) {
                        ForEach(SignForDeafTranslator.allCases, id: \.self) { t in
                            Text(t.rawValue.capitalized).tag(t)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Brand.color)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Theme color")
                    HStack(spacing: 12) {
                        ForEach(ThemePreset.presets) { preset in
                            Circle()
                                .fill(preset.color)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle().strokeBorder(.primary.opacity(0.9), lineWidth: themeHex == preset.hex ? 3 : 0)
                                )
                                .onTapGesture { themeHex = preset.hex }
                                .accessibilityLabel(preset.name)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Floating button — idle behavior")
                    Picker("Idle behavior", selection: $idleBehavior) {
                        ForEach(SignForDeafIdleBehavior.allCases, id: \.self) { b in
                            Text(b.rawValue.capitalized).tag(b)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        fieldLabel("Button size")
                        Spacer()
                        Text("\(Int(buttonSize)) pt")
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $buttonSize, in: 40...72, step: 2)
                        .tint(Brand.color)
                }

                Button(action: configure) {
                    Text(isConfigured ? "Reconfigure" : "Configure SDK")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Brand.color)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(.top, 2)

                if isConfigured {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("Tap the floating button on the right edge, then tap any text below.")
                    }
                    .font(.footnote)
                    .foregroundColor(.green)
                }
            }
        }
    }

    // MARK: - UIKit samples

    private var uikitCard: some View {
        Card(number: "2", title: "Try it — UIKit") {
            VStack(alignment: .leading, spacing: 12) {
                sampleCaption("UILabel")
                LabelRepresentable(text: sampleShort)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Divider()
                sampleCaption("UITextView")
                PlainTextViewRepresentable(text: sampleLong)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - SwiftUI samples

    private var swiftUICard: some View {
        Card(number: "3", title: "Try it — SwiftUI") {
            VStack(alignment: .leading, spacing: 12) {
                sampleCaption("SignText(_:)")
                SignText(sampleShort)
                    .font(.body)
                Divider()
                sampleCaption("Text(…).signTranslatable(_:)")
                Text(sampleShort)
                    .signTranslatable(sampleShort)
                    .font(.body)
                Divider()
                // Plain SwiftUI Text with NO wrapper — reached via the
                // accessibility fallback (accessibilityTextFallback).
                sampleCaption("Plain Text(…) — no wrapper")
                Text(sampleShort)
                    .font(.body)
            }
        }
    }

    // MARK: - Long-press to activate

    /// Demonstrates the `longPressToActivate` behavior: with the menu open, a
    /// **tap** on a labelled button translates its label, while a **long press**
    /// runs the button. The SwiftUI button uses the release-the-claim fallback;
    /// the UIKit button is fired directly (`UIControl.sendActions`).
    private var activateCard: some View {
        Card(number: "4", title: "Long-press to activate") {
            VStack(alignment: .leading, spacing: 12) {
                sampleCaption("Menu open → tap = translate, long press = run")
                Button {
                    swiftUIActivations += 1
                } label: {
                    Text("Kabul ediyorum (SwiftUI)")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Brand.color.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                Text("SwiftUI activations: \(swiftUIActivations)")
                    .font(.caption).foregroundStyle(.secondary)

                Divider()

                UIKitButton(title: "Onayla (UIKit)") { uikitActivations += 1 }
                    .frame(height: 44)
                Text("UIKit activations: \(uikitActivations)")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Controls

    private var controlsCard: some View {
        Card(number: "5", title: "Controls") {
            VStack(spacing: 10) {
                ControlButton(title: "Toggle tap-to-translate",
                              systemImage: "hand.tap.fill", tint: Brand.color) {
                    SignForDeaf.shared.setTapToTranslateActive(!isActive)
                    isActive = SignForDeaf.shared.isTapToTranslateActive
                }
                ControlButton(title: "translate(\u{201C}Teşekkürler\u{201D})",
                              systemImage: "play.rectangle.fill", tint: Brand.color) {
                    SignForDeaf.shared.translate("Teşekkürler")
                }
                HStack(spacing: 10) {
                    ControlButton(title: "Show button", systemImage: "eye.fill",
                                  tint: .secondary) {
                        SignForDeaf.shared.showFloatingButton()
                    }
                    ControlButton(title: "Hide button", systemImage: "eye.slash.fill",
                                  tint: .secondary) {
                        SignForDeaf.shared.hideFloatingButton()
                    }
                }
                ControlButton(title: "Disable SDK", systemImage: "power", tint: .red) {
                    SignForDeaf.shared.disable()
                    isConfigured = false
                    isActive = false
                }
            }
        }
    }

    // MARK: - Sensitive content

    private var sensitiveCard: some View {
        Card(number: "6", title: "Sensitive data protection") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Personal data is never sent to the server. Mark content with "
                    + ".signSensitive / isSignForDeafSensitive, and common PII "
                    + "(ID no, card, IBAN, e-mail, phone) is auto-detected and blocked.")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                Divider()
                sampleCaption(".signSensitive(_:)")
                Text(sampleMarkedTCKN)
                    .signSensitive(sampleMarkedTCKN)
                    .font(.body)

                Divider()
                sampleCaption("isSignForDeafSensitive")
                LabelRepresentable(text: sampleMarkedNote, sensitive: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Divider()
                sampleCaption("Auto-detected — UILabel")
                LabelRepresentable(text: sampleCard)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ControlButton(title: "Try to translate the card number",
                              systemImage: "nosign", tint: Brand.color) {
                    SignForDeaf.shared.translate(cardNumber)
                }
                .padding(.top, 2)
            }
        }
    }

    private var eventsCard: some View {
        Card(number: "7", title: "Blocked events") {
            VStack(alignment: .leading, spacing: 10) {
                Text("onSensitiveBlocked fires for every blocked translation — no request is sent.")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                if blockLog.entries.isEmpty {
                    Text("No blocks yet — try a translation.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(blockLog.entries, id: \.self) { entry in
                        HStack(spacing: 8) {
                            Image(systemName: "nosign")
                            Text(entry)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .font(.caption.monospaced())
                        .foregroundColor(Brand.color)
                    }
                }
            }
        }
    }

    private var footer: some View {
        Text("SignForDeaf • iOS 15+ • UIKit & SwiftUI")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.top, 4)
    }

    // MARK: - Small view helpers

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundColor(.secondary)
    }

    private func sampleCaption(_ text: String) -> some View {
        Text(text)
            .font(.caption.monospaced())
            .foregroundColor(Brand.color)
    }

    // MARK: - Actions

    private func configure() {
        SignForDeaf.shared.configure(
            SignForDeafConfig(
                apiKey: apiKey.isEmpty ? "demo" : apiKey,
                apiUrl: apiUrl,
                originUrl: originUrl.isEmpty ? nil : originUrl,
                language: language,
                // Picking a translator sets tid/fdid; the env vars stay as
                // optional overrides (nil unless set).
                translator: translator,
                fdid: Env.string("SIGNFORDEAF_FDID"),
                tid: Env.string("SIGNFORDEAF_TID"),
                theme: SignForDeafTheme(primaryColor: themeHex),
                floatingButton: SignForDeafFloatingButtonConfig(
                    size: buttonSize,
                    activeBackgroundColor: themeHex,
                    idleBehavior: idleBehavior
                ),
                // Menu open: a tap on a labelled control translates its label; a
                // long press runs the control instead of collapsing the player.
                longPressToActivate: true,
                // Let SwiftUI buttons (whose text isn't a UILabel) translate via
                // their accessibility label.
                accessibilityTextFallback: true
            )
        )
        // Mirror the Flutter example's event log: record every blocked translation.
        SignForDeaf.shared.onSensitiveBlocked = { [weak blockLog] text in
            DispatchQueue.main.async { blockLog?.add(text) }
        }
        // v2 is off by default — turn it on so the floating button appears.
        SignForDeaf.shared.enable()
        isConfigured = true
        isActive = SignForDeaf.shared.isTapToTranslateActive
    }

    private func handleLaunchArguments() {
        // Hidden auto-demos used only for screenshot verification.
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-autodemo") || args.contains("-activedemo")
            || args.contains("-sheetdemo") else { return }

        SignForDeaf.shared.configure(
            SignForDeafConfig(apiKey: "demo", apiUrl: apiUrl, originUrl: originUrl,
                              language: language,
                              theme: SignForDeafTheme(primaryColor: themeHex)))
        SignForDeaf.shared.enable()
        isConfigured = true

        if args.contains("-activedemo") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                SignForDeaf.shared.setTapToTranslateActive(true)
            }
        }
        if args.contains("-sheetdemo") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                SignForDeaf.shared.translate(sampleLong)
            }
        }
    }
}

// MARK: - Environment (Run scheme variables — the iOS analogue of --dart-define)

private enum Env {
    /// A non-empty environment variable value, or `nil`.
    static func string(_ key: String) -> String? {
        guard let value = ProcessInfo.processInfo.environment[key], !value.isEmpty else { return nil }
        return value
    }

    static func bool(_ key: String) -> Bool {
        guard let value = string(key)?.lowercased() else { return false }
        return value == "1" || value == "true" || value == "yes"
    }
}

// MARK: - Brand

private enum Brand {
    static let color = Color(red: 0x67 / 255, green: 0x50 / 255, blue: 0xA4 / 255)  // #6750A4
    static let background = Color(UIColor.systemGroupedBackground)
}

/// Live log of blocked translations, fed by `SignForDeaf.shared.onSensitiveBlocked`.
/// Mirrors the Flutter example's "Live events" list (newest first, capped at 6).
private final class BlockLog: ObservableObject {
    @Published var entries: [String] = []
    func add(_ text: String) {
        entries.insert("blockedSensitive — \"\(text)\"", at: 0)
        if entries.count > 6 { entries.removeLast() }
    }
}

private struct ThemePreset: Identifiable {
    let name: String
    let hex: String
    var id: String { hex }
    var color: Color { Color(hex: hex) }

    static let presets: [ThemePreset] = [
        ThemePreset(name: "Purple", hex: "#6750A4"),
        ThemePreset(name: "Blue", hex: "#2563EB"),
        ThemePreset(name: "Green", hex: "#16A34A"),
        ThemePreset(name: "Pink", hex: "#DB2777"),
        ThemePreset(name: "Orange", hex: "#EA580C"),
        ThemePreset(name: "Ink", hex: "#1C1B1F"),
    ]
}

// MARK: - Reusable components

private struct Card<Content: View>: View {
    let number: String
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Text(number)
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(Brand.color)
                    .clipShape(Circle())
                Text(title)
                    .font(.headline)
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
    }
}

private struct StatusPill: View {
    let title: String
    let on: Bool
    let systemImage: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
            Text(title)
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background((on ? Color.green : Color.secondary).opacity(0.15))
        .foregroundColor(on ? .green : .secondary)
        .clipShape(Capsule())
    }
}

private struct LabeledField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundColor(.secondary)
            TextField(placeholder, text: $text)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(10)
                .background(Color(UIColor.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

private struct ControlButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(tint.opacity(0.12))
            .foregroundColor(tint)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

// MARK: - UIKit bridges

/// A real UIKit `UIButton` so the long-press-to-activate demo can exercise the
/// direct `UIControl.sendActions` path (SwiftUI buttons take the fallback path).
private struct UIKitButton: UIViewRepresentable {
    let title: String
    let action: () -> Void

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16)
        button.backgroundColor = UIColor.tertiarySystemGroupedBackground
        button.layer.cornerRadius = 10
        button.addAction(UIAction { _ in context.coordinator.action() }, for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: UIButton, context: Context) {
        context.coordinator.action = action
        uiView.setTitle(title, for: .normal)
    }

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    final class Coordinator {
        var action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
    }
}

private struct PlainTextViewRepresentable: UIViewRepresentable {
    let text: String
    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.text = text
        tv.isEditable = false
        tv.isSelectable = false
        tv.isScrollEnabled = false // wrap and grow vertically instead of asserting a wide intrinsic width
        tv.font = .systemFont(ofSize: 16)
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return tv
    }
    func updateUIView(_ uiView: UITextView, context: Context) { uiView.text = text }
}

private struct LabelRepresentable: UIViewRepresentable {
    let text: String
    var sensitive: Bool = false
    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.text = text
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 16)
        label.isSignForDeafSensitive = sensitive
        // Don't let the label's single-line intrinsic width blow out the SwiftUI
        // layout — wrap within the available width instead (card = 16 outer + 16
        // inner padding per side).
        label.preferredMaxLayoutWidth = UIScreen.main.bounds.width - 64
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return label
    }
    func updateUIView(_ uiView: UILabel, context: Context) {
        uiView.text = text
        uiView.preferredMaxLayoutWidth = UIScreen.main.bounds.width - 64
        uiView.isSignForDeafSensitive = sensitive
    }
}

// MARK: - Helpers

private extension SignForDeafLanguage {
    var displayName: String {
        switch self {
        case .turkish: return "Türkçe (TR)"
        case .english: return "English (EN)"
        case .arabic: return "العربية (AR)"
        }
    }
}

private extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        let r = Double((value & 0xFF0000) >> 16) / 255
        let g = Double((value & 0x00FF00) >> 8) / 255
        let b = Double(value & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

#Preview {
    ContentView()
}
