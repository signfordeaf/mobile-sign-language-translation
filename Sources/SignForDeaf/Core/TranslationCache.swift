// Core/TranslationCache.swift

import Foundation

/// Bounded translation cache (docs/02-architecture.md §Cache).
///
/// Keyed by the exact segment text; value is the video URL and translation id.
/// Bounded at 40 entries, evicting the oldest insertion first. Re-inserting an
/// existing key moves it to the newest position. A cache hit MUST NOT re-request,
/// so stepping back and forth through a paragraph's sentences is free. The cache
/// does not survive an app launch.
final class TranslationCache {

    struct Entry: Equatable {
        let videoUrl: String
        let cid: String?
    }

    private let limit: Int
    private var order: [String] = [] // oldest first
    private var map: [String: Entry] = [:]
    private let lock = NSLock()

    init(limit: Int = 40) {
        self.limit = limit
    }

    /// Returns the cached entry without reordering (reads are not accesses for
    /// eviction purposes — only insertion order matters).
    func value(for key: String) -> Entry? {
        lock.lock(); defer { lock.unlock() }
        return map[key]
    }

    func contains(_ key: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return map[key] != nil
    }

    /// Inserts or updates, moving the key to the newest position and evicting the
    /// oldest entry when over the limit.
    func set(_ key: String, _ entry: Entry) {
        lock.lock(); defer { lock.unlock() }
        if map[key] != nil {
            order.removeAll { $0 == key }
        }
        map[key] = entry
        order.append(key)
        while order.count > limit {
            let oldest = order.removeFirst()
            map[oldest] = nil
        }
    }

    var count: Int {
        lock.lock(); defer { lock.unlock() }
        return map.count
    }

    func removeAll() {
        lock.lock(); defer { lock.unlock() }
        order.removeAll()
        map.removeAll()
    }
}
