//
//  Features/Cover/Model/CoverImageCache.swift
//
//   : CoverImageCache.
//  The decoded cover pictures the app holds, keyed by path alone.
//
//  A lazy grid destroys a card's view when the card scrolls out of
//  sight and builds a new one when it scrolls back. The new view starts
//  with no picture, so without a cache every card that scrolls back
//  reads its file from the disk and decodes it again. The file is
//  small, but the decode is not, and a grid of dozens of cards
//  scrolling is exactly when the app must not do work it has already
//  done.
//
//  THE KEY IS THE PATH, AND NOTHING ELSE. It used to carry the file's
//  size and modification date too, and the cost of that was measured
//  (2026-11-21, `CoverDiskReadTests`): the key is computed on every
//  `image(for:)` and on every `store(_:for:)`, so a screenful of 24
//  cards stat'd the disk 24 times on the MAIN THREAD for each pass the
//  column made over it, and 48 on the pass that missed. A stat is
//  cheap once and is a hitch at 60 frames a second, and Apple's rule
//  for this zone is that prepared data is what a draw may read.
//
//  What replaced the stat is the ANNOUNCEMENT, which already exists:
//  the only writer of a cover picture in the app is
//  `CardCoverService.saveImage`, and it evicts the picture it
//  overwrites (= and `removeCover` evicts the one it deletes), so the
//  day the picture at a path is a different picture is the day this
//  cache is told about it. A cover written by hand outside the app is
//  the case the date used to catch, and `CoverIndex` catches it now:
//  the walk reads each cover folder's size and date OFF THE MAIN
//  THREAD and evicts the picture whose file it says is new.
//
//  The cache is BOUNDED (= `memoryBudget`), and the cost of exceeding
//  it is one decode on a background thread. That is the trade this
//  file makes on purpose: an unbounded cache of decoded banners is a
//  memory warning, and a bounded one is a scroll that re-decodes.
//

import AppKit
import Foundation

/// The decoded cover pictures the app holds.
///
/// `NSCache` is thread-safe, and the cache holds nothing but pictures
/// and a lock-guarded map of the reads already in flight, so the
/// unchecked conformance is the honest one.
final class CoverImageCache: @unchecked Sendable {

    /// The one cache the app reads cover pictures through.
    static let shared = CoverImageCache()

    /// The decoded pictures the cache may hold at once, in bytes.
    ///
    /// A stored banner is 768x320 (= `CardCoverImageEncoder`), so one
    /// decoded picture costs about 0.94 MB at 4 bytes a pixel and the
    /// budget is a little over a hundred of them: a screenful of
    /// tiles, the rows a scroll has just passed, and the rows it is
    /// about to reach. What falls out of it is read again off the main
    /// actor, so the budget costs a decode and never a frame.
    static let memoryBudget = 96 * 1024 * 1024

    private let cache = NSCache<NSString, NSImage>()

    private let lock = NSLock()

    /// The reads the cache has already started, by path.
    ///
    /// A screenful appearing at once asks for 24 pictures in the same
    /// tick. Without this, a picture that two cards share (= the same
    /// file, reached twice) is decoded twice, and a card that is
    /// rebuilt while its first read is still running starts a second
    /// read of the same file it is about to be handed anyway.
    private var inFlight: [String: Task<NSImage?, Never>] = [:]

    private init() {
        cache.totalCostLimit = Self.memoryBudget
    }

    /// The decoded picture for a file, or nil when it is not held.
    ///
    /// Memory only: no path in here opens the disk.
    func image(for url: URL) -> NSImage? {
        cache.object(forKey: key(for: url) as NSString)
    }

    /// Holds a decoded picture.
    func store(_ image: NSImage, for url: URL) {
        cache.setObject(image, forKey: key(for: url) as NSString, cost: Self.cost(of: image))
    }

    /// Drops the picture held for a file.
    func evict(for url: URL) {
        cache.removeObject(forKey: key(for: url) as NSString)
    }

    /// The picture for a file: the held one if there is one, and the
    /// disk read otherwise, always off the main actor.
    ///
    /// This is the door a card's cover slot opens. The caller never
    /// touches the disk itself, and it never waits alone: a read
    /// already running for that path is the read it joins.
    func decodedImage(for url: URL) async -> NSImage? {
        if let held = image(for: url) {
            return held
        }
        let path = url.path
        let started: Task<NSImage?, Never> = lock.withLock {
            if let running = inFlight[path] {
                return running
            }
            // A task local does not cross into a detached task, so the
            // tally that is counting here has to be handed over.
            let tally = CoverDiskCounting.currentTally
            let task = Task.detached(priority: .userInitiated) { () -> NSImage? in
                tally?.note(.bytes)
                // A file that went between the entry's answer and this
                // read is no picture: the card keeps its fallback.
                guard let picture = NSImage(contentsOfFile: path) else { return nil }
                CoverImageCache.shared.store(picture, for: url)
                return picture
            }
            inFlight[path] = task
            return task
        }
        let picture = await started.value
        lock.withLock {
            if inFlight[path] == started {
                inFlight[path] = nil
            }
        }
        return picture
    }

    /// The cache key for a file: where it lives.
    private func key(for url: URL) -> String {
        url.path
    }

    /// What holding one decoded picture costs, in bytes.
    ///
    /// From the picture itself, not from the file: the point of this
    /// cache is that nothing in it asks the disk.
    private static func cost(of image: NSImage) -> Int {
        let rep = image.representations.max { $0.pixelsWide * $0.pixelsHigh < $1.pixelsWide * $1.pixelsHigh }
        guard let rep, rep.pixelsWide > 0, rep.pixelsHigh > 0 else { return 1 }
        return rep.pixelsWide * rep.pixelsHigh * 4
    }
}
