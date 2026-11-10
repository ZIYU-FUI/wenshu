//
//  LibraryContentFingerprint.swift · Wenshu
//
//  One cache for the reference library's content fingerprints.
//
//  WHY THIS EXISTS
//
//  The editor's engine asks its services for a fingerprint on every
//  `updateNSView` (= every keystroke, = every parent re-render), and a
//  changed fingerprint is what tells the engine to restyle the
//  wiki-links and refresh the embedded-image cache. The wenshu
//  implementations of those two fingerprints READ THE DISK: the wiki
//  resolver reads every entity JSON's full bytes and hashes them, and
//  the image provider lists its folders and stats every entry.
//  Measured on the real library: 71us and 169us, so 277us per editor
//  update, paid for a value that changes only when the library's
//  CONTENTS change.
//
//  A fingerprint is a CACHE KEY, and a cache key that touches the disk
//  turns every update into I/O. So the key is computed here, ONCE, and
//  reused until the library says it changed.
//
//  THE INVALIDATION
//
//  The library announces its own changes: `LibraryChangeNotifier` posts
//  `.wenshuLibraryDidChange` after every write that the app makes (the
//  agent's reference and book-doc writes, the import, the sidebar's
//  delete). That notification is the invalidation signal, and the
//  cached fingerprints are dropped when it arrives.
//
//  What the notification does NOT cover: a file changed outside the app
//  (= the user edited an entity JSON in Finder while the editor was
//  open). The engine's own comment on the fingerprint says a rename
//  refreshes the link display "without waiting for the next
//  keystroke", so the fingerprint exists for the app's OWN writes; an
//  external edit is picked up when the library is reloaded (= the
//  editor's file watcher and the sidebar's reload both fire on the
//  library's own signal), which is the same moment the rest of the app
//  learns about it.
//
//  THE CACHE IS PER FOLDER SET
//
//  The two fingerprints cover different folders (= the entity index,
//  = the image folders), so each is cached under the folders it
//  actually covers. Two libraries can be open over one session's life
//  (= the onboarding picker can switch), so the key carries the paths.
//

import Foundation

/// The cached fingerprints of the reference library's content.
enum LibraryContentFingerprint {
    /// The cached value for one set of folders.
    ///
    /// `nil` means "not computed yet" (= the next read computes it).
    private struct CacheEntry {
        let value: AnyHashable
    }

    /// The cache holder.
    ///
    /// A final class with a lock, not a static var: Swift 6's strict
    /// concurrency forbids a nonisolated global mutable static, and the
    /// repository's own pattern for a lock-guarded cache is this shape
    /// (= `CardCoverService`'s cache, = `StreamingAccumulator`'s
    /// accumulator).
    ///
    /// The lock guards the dictionary only (= the fingerprint computation
    /// itself runs OUTSIDE the lock, = so two readers computing the
    /// same fingerprint do not serialize on each other).
    private final class Cache: @unchecked Sendable {
        static let shared = Cache()

        private let lock = NSLock()
        private var entries: [String: CacheEntry] = [:]

        /// Whether the library-changed observer is registered.
        private var observerRegistered = false

        func value(forKey key: String) -> CacheEntry? {
            lock.lock()
            defer { lock.unlock() }
            return entries[key]
        }

        func setValue(_ value: CacheEntry, forKey key: String) {
            lock.lock()
            defer { lock.unlock() }
            entries[key] = value
        }

        func removeAll() {
            lock.lock()
            defer { lock.unlock() }
            entries.removeAll()
        }

        /// How many fingerprints were computed per key (= a cache miss
        /// each).
        private var computations: [String: Int] = [:]

        func computationCount(forKey key: String) -> Int {
            lock.lock()
            defer { lock.unlock() }
            return computations[key] ?? 0
        }

        func countComputation(forKey key: String) {
            lock.lock()
            defer { lock.unlock() }
            computations[key, default: 0] += 1
        }

        /// Register the observer once (= the first read), so a reader
        /// that arrives before any write still gets the invalidation.
        func registerObserverIfNeeded() {
            lock.lock()
            let alreadyRegistered = observerRegistered
            observerRegistered = true
            lock.unlock()
            guard !alreadyRegistered else { return }
            NotificationCenter.default.addObserver(
                forName: .wenshuLibraryDidChange,
                object: nil,
                queue: nil
            ) { _ in
                Cache.shared.removeAll()
            }
        }
    }

    // MARK: - The two fingerprints

    /// The wiki-link fingerprint for one entity index folder.
    ///
    /// The fingerprint covers the entity index's contents (= the ids and
    /// the names the links point at), so a rename or an added entity
    /// changes it.
    static func wikiFingerprint(forEntitiesDirectory entitiesDir: URL) -> AnyHashable {
        cached(
            key: wikiCacheKey(forEntitiesDirectory: entitiesDir),
            compute: {
                guard let entries = try? FileManager.default.contentsOfDirectory(
                    at: entitiesDir, includingPropertiesForKeys: nil
                ) else { return AnyHashable(Data()) }
                var hasher = Hasher()
                for entry in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
                    where entry.pathExtension == "json"
                {
                    hasher.combine(entry.lastPathComponent)
                    if let data = try? Data(contentsOf: entry) {
                        hasher.combine(data)
                    }
                }
                return AnyHashable(hasher.finalize())
            }
        )
    }

    /// The embedded-image fingerprint for a set of folders.
    ///
    /// The fingerprint covers the folders' listing and each entry's
    /// modification time, so a new or an edited image changes it.
    static func imageFingerprint(forFolders folders: [URL]) -> AnyHashable {
        let key = imageCacheKey(forFolders: folders)
        return cached(
            key: key,
            compute: {
                var hasher = Hasher()
                for dir in folders {
                    guard let entries = try? FileManager.default.contentsOfDirectory(
                        at: dir, includingPropertiesForKeys: [.contentModificationDateKey]
                    ) else { continue }
                    for entry in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                        hasher.combine(entry.lastPathComponent)
                        if let mtime = try? entry.resourceValues(forKeys: [.contentModificationDateKey])
                            .contentModificationDate
                        {
                            hasher.combine(mtime)
                        }
                    }
                }
                return AnyHashable(hasher.finalize())
            }
        )
    }

    // MARK: - The cache

    /// The cached value for one key (= computes it once, then reuses it).
    private static func cached(key: String, compute: () -> AnyHashable) -> AnyHashable {
        Cache.shared.registerObserverIfNeeded()
        if let cached = Cache.shared.value(forKey: key) {
            return cached.value
        }

        // The computation runs outside the lock (= the disk work is the
        // slow part, and holding the lock across it would serialize
        // every reader in the app).
        Cache.shared.countComputation(forKey: key)
        let computed = CacheEntry(value: compute())
        Cache.shared.setValue(computed, forKey: key)
        return computed.value
    }

    /// Drop the cached fingerprints (= the library's contents changed).
    ///
    /// Called when the library announces a change. The next read
    /// recomputes.
    static func invalidate() {
        Cache.shared.removeAll()
    }

    // MARK: - The observation hook

    /// How many times a fingerprint was COMPUTED for one key (= the
    /// cache misses for that key).
    ///
    /// The count is what makes "the value is cached" observable: a
    /// caller that reads the fingerprint twice must see ONE computation,
    /// and a test that asserts the count is the test that catches a
    /// cache that never stores. Without it, a cache that always
    /// recomputes passes every value-shaped test (= the value is right,
    /// = the disk read is still paid per read).
    ///
    /// The count is PER KEY (= not a process-wide total), so a test
    /// reads its own folder's count and no other test's activity can
    /// move it (= the suite runs in parallel, = and a process-wide
    /// total would be read by two tests at once).
    static func computationCount(forKey key: String) -> Int {
        Cache.shared.computationCount(forKey: key)
    }

    /// The wiki fingerprint's cache key for one entity index folder
    /// (= the key the wiki fingerprint is stored under).
    static func wikiCacheKey(forEntitiesDirectory entitiesDir: URL) -> String {
        "wiki:\(entitiesDir.path)"
    }

    /// The image fingerprint's cache key for a set of folders.
    static func imageCacheKey(forFolders folders: [URL]) -> String {
        "images:" + folders.map(\.path).joined(separator: "|")
    }
}
