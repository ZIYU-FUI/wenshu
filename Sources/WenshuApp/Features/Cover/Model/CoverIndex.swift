//
//  Features/Cover/Model/CoverIndex.swift
//
//   : CoverIndex.
//  Reads a library's covers ONCE, off the main thread, for the column.
//
//  Why this exists: the material column asks every card it draws what
//  its cover holds, and the answer lives in files
//  (= `assets/covers/<cardKey>/cover.heic` + `cover.mp4` +
//  `cover.json`). The app holds the answers in memory for exactly that
//  reason, and the measured cost of that memory being COLD was three
//  disk asks per card on the main thread, once per screenful
//  (measured 2026-11-21 in `CoverDiskReadTests`: 72 asks, all 72 on the
//  main thread, for 24 cards at their first render).
//
//  So the covers folder is read in one walk, on a background task, and
//  the column reads the result synchronously. The walk runs once per
//  library (= once per generation of the entry cache, which moves when
//  the app changes library or sweeps its covers), and it is kicked
//  where the app already knows the answer will be wanted: when a
//  library is opened at launch, and the first time a card asks about a
//  cover this process has never read.
//
//  The walk is not a poll and not a timer: nothing here runs again on
//  its own. What a cover does after the walk is ANNOUNCED — a write
//  publishes its own entry (see `CardCoverService.publish`), and a
//  cover this process had never read is published by the walk and
//  carried to the column by `CoverChangeSignal`, which the column
//  already reads at the one door every card's cover goes through.
//
//  A walk is a snapshot, and a snapshot ages. It therefore claims a
//  LIBRARY and a cache GENERATION before it reads, and refuses its own
//  results when either has moved by the time it lands (= a library
//  switched under it, or a cache somebody cleared while it read): a
//  listing taken before a cover was written is not an answer to a
//  question asked after it, and publishing one anyway is how a
//  background read puts a card back to yesterday's disk.
//
//  The walk also carries the decoded-picture cache's staleness check:
//  it notices a cover FILE whose size or date moved (= a picture
//  replaced outside the app) and drops the picture held for it. That
//  check costs nothing of its own, because the size and the date it
//  compares ride the folder listing the walk already took.
//  One walk therefore asks the disk twice per cover folder it holds (=
//  the folder's listing and that folder's record) plus one listing of
//  the covers folder, all of it off the main thread, once per library.
//  The alternative is a size-and-date key asked on every lookup: one
//  ask per card per render, on the main thread.
//

import Foundation

/// The one background read of the covers folder.
///
/// Main-actor-isolated, like `CoverChangeSignal`: everything it
/// publishes is published on the main actor, and the only work that
/// leaves it is the walk, which is handed what it needs and reports
/// back.
@MainActor
final class CoverIndex {
    /// The one index the app warms its covers through.
    static let shared = CoverIndex()

    /// The picture's identity as the last walk saw it: path to
    /// `size|modification-date`.
    private var seenPictures: [String: String] = [:]

    /// The walks this index has claimed: library path to the cache
    /// generation it was walked at.
    ///
    /// A claim is per LIBRARY, not one slot for the whole app: two
    /// libraries' walks must not fight over it, or the second claim
    /// silently invalidates the first walk's results (= measured
    /// 2026-11-21: a single-slot claim made this feature's own counting
    /// suite red in a full parallel run and green alone, because any
    /// other suite that touched the entry door under its own library
    /// stole the claim mid-walk).
    ///
    /// The generation is the other half. A cache that was cleared (= a
    /// library switch, or a cover sweep that deleted folders) moves it,
    /// and a walk that started before the clear must not answer a
    /// question asked after it.
    private var walked: [String: Int] = [:]

    private init() {}

    /// Warms the cover entries for the active library, once per library.
    ///
    /// Returns without waiting: the caller is a view body, and a frame
    /// may not spend itself on a folder walk. When the walk lands it
    /// publishes what it found and says so, and the column that asked is
    /// the column that re-renders.
    func prefill() {
        guard let claimed = claimWalk() else { return }
        let tally = CoverDiskCounting.currentTally
        Task.detached(priority: .userInitiated) {
            let found = CoverIndex.walk(claimed: claimed, tally: tally)
            await MainActor.run { CoverIndex.shared.apply(found) }
        }
    }

    /// The same walk, awaited.
    ///
    /// For the one caller that has nothing drawn yet and means it: the
    /// library has just been opened, and the point of reading a
    /// library's covers before it is asked about them is that the first
    /// screenful of cards is then answered from memory.
    func prefillAndWait() async {
        guard let claimed = claimWalk() else { return }
        let tally = CoverDiskCounting.currentTally
        let found = await Task.detached(priority: .userInitiated) {
            CoverIndex.walk(claimed: claimed, tally: tally)
        }.value
        apply(found)
    }

    /// One library at one cache generation: what the walk must read, and
    /// what it must still be true for when the walk lands.
    struct Claim: Sendable {
        let root: URL
        let generation: Int
    }

    /// Claims this library's walk, or returns nil when there is nothing
    /// to walk (= no library, or this one is already walked or walking).
    private func claimWalk() -> Claim? {
        guard let root = CardCoverService.coversRoot else { return nil }
        let generation = CoverEntryCache.shared.generation(forRoot: root)
        if walked[root.path] == generation {
            return nil
        }
        walked[root.path] = generation
        return Claim(root: root, generation: generation)
    }

    // MARK: - The walk

    /// What one walk read.
    struct Found: Sendable {
        /// The cover entries the folder holds, by card key.
        let entries: [String: CoverEntry]
        /// Each cover picture's identity, by path.
        let pictures: [String: String]
        /// The library the walk read, and the generation it read for.
        let claimed: Claim
    }

    /// Reads every cover folder.
    ///
    /// The ONLY place this file opens the disk, and it runs on the
    /// detached task `prefill` started. The root arrives as a value: a
    /// detached task does not inherit the caller's task locals, and the
    /// library a walk reads is exactly what the caller knows and the
    /// task does not (= a walk that recomputed the root would read some
    /// other library, or none).
    private nonisolated static func walk(claimed: Claim, tally: CoverDiskCounting.Tally?) -> Found {
        // One ask opens the walk: the listing of the covers folder.
        tally?.note(.metadata)
        guard let folders = try? FileManager.default.contentsOfDirectory(
            at: claimed.root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return Found(entries: [:], pictures: [:], claimed: claimed)
        }
        var entries: [String: CoverEntry] = [:]
        var pictures: [String: String] = [:]
        for folder in folders {
            // One listing of one cover folder answers presence, and it
            // carries the size and the date with it (= the values come
            // off the traversal, not from a second ask per file).
            let files = (try? FileManager.default.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )) ?? []
            guard !files.isEmpty else { continue }
            tally?.note(.metadata)
            var image: URL?
            var video: URL?
            var recordData: Data?
            for file in files {
                switch file.lastPathComponent {
                case CardCoverService.imageFileName: image = file
                case CardCoverService.clipFileName: video = file
                case CardCoverService.recordFileName:
                    // The record's bytes are a real read, and the walk
                    // counts it as one.
                    tally?.note(.bytes)
                    recordData = try? Data(contentsOf: file)
                default: break
                }
            }
            if let image {
                // NOT counted as an ask, and it is not one: the size and
                // the date this check reads came in on the folder
                // listing above (= it was taken with [.fileSizeKey,
                // .contentModificationDateKey]), so asking the URL for
                // those same values reaches no disk (= the documented
                // purpose of naming the keys to the enumeration).
                pictures[image.path] = CoverIndex.identity(of: image)
            }
            let record = CardCoverService.record(decodedFrom: recordData)
            if image != nil || video != nil || record != nil {
                entries[folder.lastPathComponent] = CoverEntry(
                    imageURL: image,
                    videoURL: video,
                    record: record
                )
            }
        }
        return Found(entries: entries, pictures: pictures, claimed: claimed)
    }

    /// `size|modification-date` for one file, or nil when it cannot be
    /// read (= the file went away mid-walk).
    private nonisolated static func identity(of url: URL) -> String? {
        guard let values = try? url.resourceValues(
            forKeys: [.fileSizeKey, .contentModificationDateKey]
        ) else { return nil }
        return "\(values.fileSize ?? 0)|\(values.contentModificationDate?.timeIntervalSince1970 ?? 0)"
    }

    // MARK: - Publishing

    /// Puts what the walk read where the column reads it, and says so
    /// when the column now holds a cover it did not hold before.
    ///
    /// The walk's answer is only ever worth publishing while the claim
    /// it was read for is still true (= the same library, and no cache
    /// clear since the listing): a snapshot taken before a cover was
    /// written is not an answer to a question asked after it, and the
    /// walk is a background task that cannot know what happened while it
    /// read. The writer publishes over anything it finds, so a live
    /// answer is never disturbed; what this guard refuses is a walk
    /// repopulating a hole that someone else just cleared.
    private func apply(_ found: Found) {
        guard walked[found.claimed.root.path] == found.claimed.generation,
              found.claimed.generation
              == CoverEntryCache.shared.generation(forRoot: found.claimed.root),
              CardCoverService.coversRoot?.path == found.claimed.root.path else { return }
        var learned = 0
        for (key, entry) in found.entries where CoverEntryCache.shared.storeIfAbsent(
            entry,
            forKey: key,
            root: found.claimed.root
        ) {
            learned += 1
        }
        let moved = picturePathsWhoseFileMoved(found.pictures)
        for path in moved {
            CoverImageCache.shared.evict(for: URL(fileURLWithPath: path))
        }
        // One announcement for one walk: the walk learned something the
        // column was drawn without, or a picture the column is holding
        // is no longer the file on the disk. Both mean the same thing
        // to a card, which is to ask again (= and asking now costs
        // memory, not the disk).
        if learned > 0 || !moved.isEmpty {
            CoverChangeSignal.shared.noteCoverChanged()
        }
    }

    /// The held pictures whose file the walk says is not the file it
    /// saw last time, and the record of what this walk saw.
    private func picturePathsWhoseFileMoved(_ pictures: [String: String]) -> [String] {
        var moved: [String] = []
        for (path, identity) in pictures {
            if let before = seenPictures[path], before != identity {
                moved.append(path)
            }
        }
        seenPictures = pictures
        return moved
    }
}
