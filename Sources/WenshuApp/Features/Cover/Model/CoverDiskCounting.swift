//
//  Features/Cover/Model/CoverDiskCounting.swift
//
//   : CoverDiskCounting.
//  The seam that counts the disk touches a card's cover asks for.
//
//  Why this exists: the claim the cover's tests make is a COUNT (= how
//  often a card asks the disk what its cover holds, and from which
//  thread), and a count nobody can read is not a claim. So the disk
//  doors say so as they open, and one test holds the tally.
//
//  Production pays nothing for this. Production creates no tally, so
//  the task local below is nil and every `note` is a load and a branch.
//
//  The thread is half of what is counted, and the half that decides
//  whether the user sees it. A cover read on a background thread is a
//  cost; the same read on the main thread is a hitch in the material
//  column's frame. Apple's rule for `draw(_:)` is what the count is
//  measured against: the drawing path reads data that is already
//  prepared there and does no I/O and no complex calculation in it.
//
//  A tally is a class, not a value, because a detached read has to
//  report into the test that started it: a task local is NOT inherited
//  by `Task.detached`, so a background door is handed the tally it
//  reports to (= `currentTally`, captured on the thread that started
//  the work).
//
//  WHY THE LIBRARY LOOKUP IS COUNTED HERE, AND COUNTED SEPARATELY: the
//  door that answers a card's cover needs to know WHICH library the
//  card's folder lives in, and finding that out is not free (= the
//  active library is a security-scoped bookmark: a UserDefaults read
//  plus `URL(resolvingBookmarkData:)`). That cost lives outside
//  `Features/Cover/`, so a census of the disk doors under this folder
//  cannot see it, and under DEBUG it is answered by a task-local test
//  override BEFORE the bookmark is touched, so a counter placed behind
//  that override would record nothing in the test binary and everything
//  in production. So the count sits at the lookup's own entry point, in
//  front of both branches (= `ActiveLibrary.path`), where it fires
//  either way and the harness measures the shape production takes.
//
//  It is a separate list inside the same tally, not another kind of
//  disk ask: a lookup asks no file anything, so folding it into `total`
//  would silently restate every published disk count. It is counted per
//  VISIT because that is the only form in which a render pays it (= a
//  screenful hoisted to one lookup per pass costs one, a per-card lookup
//  costs twenty-four).
//

import Foundation

/// Counts the disk touches one cover lookup asks for.
enum CoverDiskCounting {
    /// The kinds of ask a cover read can make.
    enum Kind: Hashable, Sendable {
        /// A file's metadata (= does it exist, how big is it, when was
        /// it written). The cheap ask, unless it is asked a hundred
        /// times a second on the main thread.
        case metadata
        /// A file's bytes (= a read that ends in a decoded picture or
        /// a parsed record).
        case bytes
    }

    /// The tally one test holds.
    final class Tally: @unchecked Sendable {
        private let lock = NSLock()
        private var touches: [(kind: Kind, mainThread: Bool)] = []

        /// The times the frame asked which library it is drawing in, with
        /// the thread each ask happened on.
        ///
        /// Kept apart from `touches` on purpose: a library lookup asks no
        /// file anything, so it must not move a published disk count, and
        /// it is a cost of its own that a frame can pay per card.
        private var lookups: [Bool] = []

        /// Records one disk touch, on the thread that made it.
        func note(_ kind: Kind, onMainThread: Bool = Thread.isMainThread) {
            lock.withLock { touches.append((kind, mainThread: onMainThread)) }
        }

        /// Records one library lookup, on the thread that made it.
        func noteLibraryLookup(onMainThread: Bool = Thread.isMainThread) {
            lock.withLock { lookups.append(onMainThread) }
        }

        /// Every library lookup counted so far.
        var lookupsTotal: Int {
            lock.withLock { lookups.count }
        }

        /// The library lookups made on the main thread (= the ones a
        /// scroll frame pays for out of its own 5 ms, like the disk
        /// asks, and like them they belong in prepared data, not in the
        /// draw).
        var lookupsOnMainThread: Int {
            lock.withLock { lookups.filter { $0 }.count }
        }

        /// Every touch counted so far.
        var total: Int {
            lock.withLock { touches.count }
        }

        /// The touches made on the main thread (= the ones a scroll
        /// frame pays for out of its own 5 ms).
        var onMainThread: Int {
            lock.withLock { touches.filter { $0.mainThread }.count }
        }

        /// The touches of one kind.
        func count(_ kind: Kind) -> Int {
            lock.withLock { touches.filter { $0.kind == kind }.count }
        }

        /// The touches of one kind made on the main thread.
        func count(_ kind: Kind, onMainThread: Bool) -> Int {
            lock.withLock { touches.filter { $0.kind == kind && $0.mainThread == onMainThread }.count }
        }
    }

    /// The tally the current task reports into, when a test is counting.
    @TaskLocal static var tally: Tally?

    /// Notes a disk touch made on the calling thread.
    nonisolated static func note(_ kind: Kind) {
        tally?.note(kind)
    }

    /// Notes a library lookup made on the calling thread.
    ///
    /// The one door that reports it is `ActiveLibrary.path`, and it
    /// reports BEFORE its own branches, so the count is the same whether
    /// the answer came from the test override or from resolving the
    /// persisted bookmark (= which is the only way a harness that sets
    /// the override can learn what production pays).
    nonisolated static func noteLibraryLookup() {
        tally?.noteLibraryLookup()
    }

    /// The tally a detached task has to be handed so it can report
    /// into it. Nil in production, which is the whole point.
    nonisolated static var currentTally: Tally? {
        tally
    }
}
