//
//  Features/Cover/Model/CoverEntryCache.swift
//
//   : CoverEntryCache.
//  The cover answers the app already has, in memory.
//
//  Why this is its own file: the cache is what makes a card's cover
//  cost nothing to look up, and it is read from three places that are
//  not the service that owns the cover files (= the card's door in
//  `CardCoverService.entry`, the background read in `CoverIndex`, and
//  the library switch that empties it). A cache that lives inside the
//  service that writes it invites the next writer to reach past it and
//  re-read the folder instead.
//

import Foundation

/// The cover entries the app already read.
///
/// The material zone renders a grid of cards, and every card asks
/// what its cover holds on every render. Holding the answer in memory
/// turns that from a disk read per card per render into a dictionary
/// lookup, which is what keeps a scroll smooth.
///
/// The lock is there so the cache can be dropped from anywhere (= a
/// library change), not only from the main actor.
final class CoverEntryCache: @unchecked Sendable {
    /// The one cache the app reads covers through.
    static let shared = CoverEntryCache()

    private let lock = NSLock()
    private var entries: [String: CoverEntry] = [:]

    /// How many times everything was dropped.
    ///
    /// The cover walk reads it to answer one question: has a library
    /// come and gone since I last walked (= `CoverIndex.prefill`). A
    /// cache that forgets everything is a cache that owes a walk.
    private var generationCount = 0

    /// The cache's generation, current at the moment of the read.
    var generation: Int {
        lock.withLock { generationCount }
    }

    /// The entry for a key, or nil when the key was never read.
    func entry(forKey key: String) -> CoverEntry? {
        lock.withLock { entries[key] }
    }

    /// Holds an entry.
    func store(_ entry: CoverEntry, forKey key: String) {
        lock.withLock { entries[key] = entry }
    }

    /// Holds an entry only when nothing holds that key.
    ///
    /// - Returns: whether this call is the one that filled the hole.
    ///
    /// The cover walk publishes through here, because a card written
    /// while the walk was in flight already published its own newer
    /// answer, and a walk that overwrote it would put yesterday's
    /// folder back on the card.
    func storeIfAbsent(_ entry: CoverEntry, forKey key: String) -> Bool {
        lock.withLock {
            guard entries[key] == nil else { return false }
            entries[key] = entry
            return true
        }
    }

    /// Drops an entry, so the next read goes to the disk.
    ///
    /// A WRITE does not call this: a writer knows what it left on the
    /// disk and publishes it (= `CardCoverService.publish`). Dropping
    /// the answer instead sent the next render to the folder, on the
    /// main thread, inside the body of the card the cover's own
    /// announcement had just woken up.
    func evict(forKey key: String) {
        // The removed entry is not wanted (= the point of the eviction),
        // so the return value is dropped on purpose.
        _ = lock.withLock { entries.removeValue(forKey: key) }
    }

    /// Drops every entry, and asks for a walk of the new library.
    ///
    /// The app calls this when the library changes: a cover belongs to
    /// the library it was read from, so what the app remembers about
    /// the old library's covers is of no use to the new one.
    func removeAll() {
        lock.withLock {
            entries.removeAll()
            generationCount += 1
        }
    }
}
