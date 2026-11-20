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
//  column's frame (= Apple: "Rely on previously prepared data in
//  draw(_:), don't perform I/O or complex calculations in this
//  method").
//
//  A tally is a class, not a value, because a detached read has to
//  report into the test that started it: a task local is NOT inherited
//  by `Task.detached`, so a background door is handed the tally it
//  reports to (= `currentTally`, captured on the thread that started
//  the work).
//

import Foundation

/// Counts the disk touches one cover lookup asks for.
enum CoverDiskCounting {
    /// What was asked of the disk.
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

        /// Records one disk touch, on the thread that made it.
        func note(_ kind: Kind, onMainThread: Bool = Thread.isMainThread) {
            lock.withLock { touches.append((kind, mainThread: onMainThread)) }
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

    /// The tally a detached task has to be handed so it can report
    /// into it. Nil in production, which is the whole point.
    nonisolated static var currentTally: Tally? {
        tally
    }
}
