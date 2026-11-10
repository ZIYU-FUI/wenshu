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
//  delete), = and `SidebarServiceMutation` posts it after every rename
//  (= the shelf, = the book, = the reference, = and the book document).
//  That notification is the invalidation signal, and the cached
//  fingerprints are dropped when it arrives.
//
//  ⇒ ⇒ AND the announcement is PART OF THIS CACHE'S MEANING: = the
//  editor's engine compares the fingerprint against its last one and
//  only restyles the wiki-links when it changed, = so a value that is
//  stale after a write the app made is a stale link label. = ⇒ A write
//  path that does not announce is a defect HERE, = not a missing
//  optimisation elsewhere.
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
    struct CacheEntry {
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
    ///
    /// ⇒ ⇒ AND it is a TYPE, = not only a singleton, = so a reader that
    /// needs to measure the cache's behaviour can OWN one: = the
    /// production code uses `Cache.shared`, = and a test that measures
    /// "how many times did this key miss" uses its own instance, = which
    /// observes no announcement (= so no sibling's write can evict its
    /// key and move its count). = ⇒ A count read from a shared cache is
    /// not a measurement: = the announcement that drops the cache is
    /// global, = so ANY writer in the app moves it.
    final class Cache: @unchecked Sendable {
        static let shared = Cache()

        private let lock = NSLock()
        private var entries: [String: CacheEntry] = [:]

        /// Whether the library-changed observer is registered.
        private var observerRegistered = false

        /// Whether this cache observes the library's announcement.
        ///
        /// `true` for the shared cache (= the production shape: = the
        /// library announced a change, = so the cached values are
        /// dropped). = `false` for a cache a test owns, = so the test's
        /// measurement is not moved by another writer.
        private let observesAnnouncements: Bool

        init(observesAnnouncements: Bool = true) {
            self.observesAnnouncements = observesAnnouncements
        }

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

        /// Drop the cached fingerprints (= the library's contents changed).
        ///
        /// The counts go with the entries (= the count is the number of
        /// computations SINCE the last eviction, = so it answers "how
        /// many times did this key miss since the value was last
        /// dropped"). = ⇒ So an eviction RESETS the count: = a value
        /// that was dropped and recomputed counts one, = and a value
        /// that was dropped and recomputed twice counts two, = and a
        /// reader that never missed counts zero.
        ///
        /// ⇒ ⇒ AND that is what makes the count immune to a FOREIGN
        /// eviction: = the notification that drops the cache is global
        /// (= any writer in the app drops every key), = so a test that
        /// reads one key can have that key dropped by a sibling test's
        /// notification. = ⇒ With the count reset on eviction, = the
        /// count after N reads of a warm value is 1 whichever eviction
        /// happened in between (= the last eviction is the one that
        /// counts).
        func removeAll() {
            lock.lock()
            defer { lock.unlock() }
            entries.removeAll()
            computations.removeAll()
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
        ///
        /// A cache that does not observe announcements never registers:
        /// = that is the shape a measurement uses, = so the count it
        /// reports is the count of ITS OWN reads.
        func registerObserverIfNeeded() {
            guard observesAnnouncements else { return }
            lock.lock()
            let alreadyRegistered = observerRegistered
            observerRegistered = true
            lock.unlock()
            guard !alreadyRegistered else { return }
            // ⇒ ⇒ The observer clears THE INSTANCE it belongs to, = not
            // the singleton. = ⇒ WHY: a cache that observes the
            // announcement and does not drop its own value on it is a
            // cache that lies about what it observes. = ⇒ MEASURED: the
            // review's probe read "a cache that observes announcements
            // does NOT drop its own value", = and a test that owns an
            // observing cache could not see the announcement at all.
            NotificationCenter.default.addObserver(
                forName: .wenshuLibraryDidChange,
                object: nil,
                queue: nil
            ) { [weak self] _ in
                self?.removeAll()
            }
        }

        /// The wiki-link fingerprint, read through ONE cache.
        ///
        /// The instance is the seam: = the shared cache is the production
        /// one (= it observes the library's announcement), = and a cache a
        /// caller owns is the measurement one (= no announcement moves it).
        func wikiFingerprint(forEntitiesDirectory entitiesDir: URL) -> AnyHashable {
            cached(
                key: LibraryContentFingerprint.wikiCacheKey(forEntitiesDirectory: entitiesDir),
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

        /// The embedded-image fingerprint, read through ONE cache.
        func imageFingerprint(forFolders folders: [URL]) -> AnyHashable {
            let key = LibraryContentFingerprint.imageCacheKey(forFolders: folders)
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

        /// The cached value for one key (= computes it once, then reuses it).
        func cached(key: String, compute: () -> AnyHashable) -> AnyHashable {
            registerObserverIfNeeded()
            if let cached = value(forKey: key) {
                return cached.value
            }

            // The computation runs outside the lock (= the disk work is the
            // slow part, and holding the lock across it would serialize
            // every reader in the app).
            countComputation(forKey: key)
            let computed = CacheEntry(value: compute())
            setValue(computed, forKey: key)
            return computed.value
        }
    }

    // MARK: - The two fingerprints

    /// The wiki-link fingerprint for one entity index folder.
    ///
    /// The fingerprint covers the entity index's contents (= the ids and
    /// the names the links point at), so a rename or an added entity
    /// changes it.
    static func wikiFingerprint(forEntitiesDirectory entitiesDir: URL) -> AnyHashable {
        Cache.shared.wikiFingerprint(forEntitiesDirectory: entitiesDir)
    }

    /// The embedded-image fingerprint for a set of folders.
    ///
    /// The fingerprint covers the folders' listing and each entry's
    /// modification time, so a new or an edited image changes it.
    static func imageFingerprint(forFolders folders: [URL]) -> AnyHashable {
        Cache.shared.imageFingerprint(forFolders: folders)
    }

    // MARK: - The cache

    /// Drop the cached fingerprints (= the library's contents changed).
    ///
    /// Called when the library announces a change. The next read
    /// recomputes.
    static func invalidate() {
        Cache.shared.removeAll()
    }

    // MARK: - The observation hook

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
