// Persistence/SignForDeafStorage.swift

import Foundation

/// String-keyed / string-valued storage seam (docs/14-persistence.md).
///
/// Two implementations: an in-memory one (default, and tests) and a
/// platform-backed one (`UserDefaults`) the integration installs in a real app.
/// Keeping this seam lets preference tests run with no platform underneath.
protocol SignForDeafStorage: AnyObject {
    func getItem(_ key: String) -> String?
    func setItem(_ key: String, _ value: String)
}

/// Keys the SDK stores. Nothing about the user's *content* is ever written.
enum StorageKey {
    static let hintShownCount = "hint_shown_count"
    static let playbackSpeed = "playback_speed"
    static let looping = "looping"
}

/// In-memory store — lives for the current session only. The default.
final class InMemoryStorage: SignForDeafStorage {
    private var values: [String: String] = [:]
    private let lock = NSLock()

    func getItem(_ key: String) -> String? {
        lock.lock(); defer { lock.unlock() }
        return values[key]
    }

    func setItem(_ key: String, _ value: String) {
        lock.lock(); defer { lock.unlock() }
        values[key] = value
    }
}

/// `UserDefaults`-backed store, surviving across launches.
///
/// Every key is prefixed with `weaccess_sl_` so the SDK cannot collide with the
/// host app's own preferences. Ports MUST keep the same prefix so a device
/// migrating between SDK versions keeps its settings.
final class UserDefaultsStorage: SignForDeafStorage {
    /// Key prefix — do not change; it is what makes settings migrate across versions.
    static let prefix = "weaccess_sl_"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func getItem(_ key: String) -> String? {
        defaults.string(forKey: Self.prefix + key)
    }

    func setItem(_ key: String, _ value: String) {
        defaults.set(value, forKey: Self.prefix + key)
    }
}
