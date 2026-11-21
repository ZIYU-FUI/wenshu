//
//  Features/Cover/Model/CoverEntryCache.swift
//
//   : CoverEntryCache.
//  The cover answers the app already has, in memory, kept apart by the
//  library they were read from.
//
//  Why this is its own file: the cache is what makes a card's cover
//  cost nothing to look up, and it is read from three places that are
//  not the service that owns the cover files (= the card's door in
//  `CardCoverService.entry`, the background read in `CoverIndex`, and
//  the cover sweep that drops what it deleted). A cache that lives
//  inside the service that writes it invites the next writer to reach
//  past it and re-read the folder instead.
//
//  Why an entry is scoped by LIBRARY: a cover belongs to the library it
//  was read from, and this cache used to enforce that by demolition - a
//  library switch dropped every answer it held. Demolition is expensive
//  and it is also leaky: switching back to a library re-read every cover
//  folder it had already read, and one library's business was visible to
//  another's, so any reader could be emptied by a switch that happened
//  somewhere else (= measured 2026-11-21 in a full parallel test binary:
//  43 cache clears landed inside one run of the cover counting suite,
//  each one sending the column back to the disk). Scoping the key by the
//  covers folder the entry was read from makes the rule structural: one
//  library's answer cannot answer another library's card, so a switch has
//  nothing to drop and a sweep drops only what it swept.
//
//  Why the ROOT ARRIVES AS A VALUE and is never looked up here: the
//  scope is the library's covers folder, and obtaining one means asking
//  which library is active (= a UserDefaults read plus a bookmark
//  decode). The cache is read once per card per render, so a lookup
//  inside `entry` would put that cost on every frame, for an answer the
//  caller already had. The CALLER resolves it once for the column it is
//  drawing and hands the same folder down (= `PreviewPane.coverEntries`
//  and the grid doors), and the absence of a root-free overload is the
//  rule: a door cannot silently decide to pay for one.
//

import Foundation

/// The cover entries the app already read.
///
/// The material zone renders a grid of cards, and every card asks
/// what its cover holds on every render. Holding the answer in memory
/// turns that from a disk read per card per render into a dictionary
/// lookup, which is what keeps a scroll smooth.
///
/// The lock is there so the cache can be read and dropped from
/// anywhere, not only from the main actor: the cover walk publishes
/// from a background task.
final class CoverEntryCache: @unchecked Sendable {
    /// The one cache the app reads covers through.
    static let shared = CoverEntryCache()

    /// How many entries the cache holds at most.
    ///
    /// An entry is two URLs and a small record, so this is a guard
    /// against a library that grows without end rather than a tune: at
    /// the cap the oldest half is dropped, and the column reads those
    /// folders back one at a time, off a walk, never off a frame.
    private static let cap = 20000

    private let lock = NSLock()

    /// The answers held, by covers folder and card key.
    private var entries: [String: CoverEntry] = [:]

    /// The held answers in the order they were filled, so the cap has
    /// something oldest to drop.
    private var order: [String] = []

    /// How many times each library's answers were dropped, by covers
    /// folder.
    ///
    /// The cover walk reads it to answer one question: has this library
    /// been swept since I last walked it (= `CoverIndex.prefill`). A
    /// cache that forgot a library is a cache that owes it a walk.
    private var generations: [String: Int] = [:]

    /// One library's answers as the walk sees them: how many times they
    /// were dropped. A library nobody dropped is generation 0.
    func generation(forRoot root: URL?) -> Int {
        lock.withLock { generations[scope(of: root)] ?? 0 }
    }

    /// The entry for a card key in one library, or nil when that key was
    /// never read there.
    func entry(forKey key: String, root: URL?) -> CoverEntry? {
        lock.withLock { entries[scoped(key, root)] }
    }

    /// The entries for a whole column of card keys, in the order asked,
    /// from ONE lookup of the covers folder.
    ///
    /// The batch is the shape, not an optimisation: a caller that loops
    /// over `entry(forKey:root:)` with a root it resolved per key is
    /// back to paying a library lookup per card, which is the cost this
    /// file exists to remove. A nil answer means that key has never been
    /// read in THAT library, which is the caller's cold door, not an
    /// error.
    func entries(forKeys keys: [String], root: URL?) -> [CoverEntry?] {
        lock.withLock {
            keys.map { entries[scoped($0, root)] }
        }
    }

    /// Holds an entry.
    func store(_ entry: CoverEntry, forKey key: String, root: URL?) {
        let composite = scoped(key, root)
        lock.withLock {
            if entries[composite] == nil {
                order.append(composite)
            }
            entries[composite] = entry
            trimToFit()
        }
    }

    /// Holds an entry only when nothing holds that key.
    ///
    /// - Returns: whether this call is the one that filled the hole.
    ///
    /// The cover walk publishes through here, because a card written
    /// while the walk was in flight already published its own newer
    /// answer, and a walk that overwrote it would put yesterday's
    /// folder back on the card.
    func storeIfAbsent(_ entry: CoverEntry, forKey key: String, root: URL?) -> Bool {
        let composite = scoped(key, root)
        return lock.withLock {
            guard entries[composite] == nil else { return false }
            entries[composite] = entry
            order.append(composite)
            trimToFit()
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
    func evict(forKey key: String, root: URL?) {
        let composite = scoped(key, root)
        lock.withLock {
            // The removed entry is not wanted (= the point of the
            // eviction), so the return value is dropped on purpose.
            _ = entries.removeValue(forKey: composite)
            order.removeAll { $0 == composite }
        }
    }

    /// Drops one library's answers, and asks for a walk of it.
    ///
    /// The cover sweep calls this: it deleted cover folders, so what the
    /// app remembers about THAT library is wrong. What it remembers
    /// about any other library is still exactly what is on that disk.
    func removeAll(forRoot root: URL?) {
        let scope = scope(of: root)
        lock.withLock {
            for composite in order where composite.hasPrefix(scope) {
                entries.removeValue(forKey: composite)
            }
            order.removeAll { $0.hasPrefix(scope) }
            generations[scope, default: 0] += 1
        }
    }

    // MARK: - The scope

    /// The covers folder a library's answers are kept under.
    ///
    /// A library that is not there yet (= onboarding) gets its own
    /// scope rather than sharing one, so an answer read with no library
    /// can never be handed to a card in a real one.
    private func scope(of root: URL?) -> String {
        (root?.path ?? "<no library>") + "\u{1}"
    }

    private func scoped(_ key: String, _ root: URL?) -> String {
        scope(of: root) + key
    }

    /// Keeps the cache inside its cap, dropping the oldest half.
    ///
    /// Called with the lock held.
    private func trimToFit() {
        guard order.count > Self.cap else { return }
        let dropped = order.prefix(order.count - Self.cap / 2)
        for composite in dropped {
            entries.removeValue(forKey: composite)
        }
        order.removeFirst(dropped.count)
    }
}
