//
//  Tests/WenshuAppTests/Cover/Model/CoverDiskReadTests.swift
//
//   : CoverDiskReadTests.
//  Counts the disk asks one screenful of cards makes for its covers.
//
//  What this suite is FOR: the material column's claim is a NUMBER
//  (= how often a card asks the disk what its cover holds, and from
//  which thread), and a number is only evidence when the same number
//  comes out on every machine. So the fixture is a throwaway library
//  with N cards that each hold a cover, and the passes below are the
//  passes the column makes: the render of a screenful, the same
//  screenful rendered again, a DIFFERENT screenful scrolling into view
//  of an already-walked library, a cover arriving after the walk with
//  no announcement, the appearance of each card's picture slot (= the
//  first one, and the one after the lazy grid rebuilt the cell), and
//  the render that follows a cover being written.
//
//  THE MEASURED READINGS, a screenful of 24 cards whose covers are all
//  on disk (= `makeLibraryOnDisk`: the files arrive without the app's
//  writer, so the column has never heard of them; a fixture written
//  through `CardCoverService` would already be published into the cache
//  and would measure a warm column while claiming to measure a cold one).
//
//  BEFORE (= origin/main `65590f4800`, counted on the base itself by
//  porting this suite and this seam into the base tree, 2026-11-21):
//
//    render cold      72 asks, 72 of them on the MAIN thread
//    render refresh   0
//    scroll into view 72 asks, 72 on the MAIN thread (= on the base the
//                      library is FOREVER cold: there is no walk, so
//                      every card that scrolls in for the first time
//                      pays its own frame, screenful after screenful)
//    picture slot 1   72 asks, 48 on the MAIN thread
//    picture slot 2   24 asks, 24 on the MAIN thread
//    after a write     3 asks, all 3 on the MAIN thread
//
//  AFTER (this change):
//
//    render cold      48 asks on the MAIN thread, asserted (= 2 per
//                      card: one folder listing and that folder's
//                      record, where it was 3 asks per card). The pass
//                      PRINTS a total above that because the walk it
//                      started reads off-thread while the pass runs
//                      (= 49 asks for this fixture: one listing of the
//                      covers folder plus two asks per cover folder;
//                      how much of a background walk lands before the
//                      pass ends is the machine's business, which is
//                      why only the main-thread half is asserted).
//    walk-itself      49 asks, 0 on the MAIN thread (24-card library)
//    walk, then render 0 total and 0 on the MAIN thread
//    render refresh   0
//    scroll into view 0 total, 0 on the MAIN thread (= 24 cards the
//                      view has never drawn, their covers on disk, the
//                      index warm - the pass continuous scroll pays,
//                      and the one Apple's 5 ms ruler is about)
//    a cover arriving AFTER the walk with no announcement (the walk is
//      not a poll, by decision): 2 asks on the frame ONCE for that card
//      (= the base paid 3), and 0 on every frame after that one
//    picture slot 1   24 reads, NONE on the MAIN thread, 0 stats
//    picture slot 2   0
//    after a write     0
//
//  THE TRADE, in one honest sentence: the cold screenful asks the disk
//  MORE times in total than the base did (the printed 97 against 72),
//  because the walk re-lists the folders the frame just read and reads
//  every other folder in the library too - all of it off the main
//  thread, once per library - and it asks the MAIN THREAD fewer (48
//  against 72); the duplication is the price of one consistent
//  background snapshot per library, and skipping it would trade a
//  racy hole in the walk's moved-picture check for asks no frame
//  waits on.
//
//  The refresh reading is why the header says what it measures: the
//  entry cache already answered a WARM column from memory, so "every
//  render reads the disk" was only true of the first render and of the
//  frames an announcement wakes up. What was true on EVERY pass, warm
//  or cold, is the picture slot's stat (= the decoded-picture cache
//  keyed itself on the file's size and date, and computing the key
//  asked the file).
//
//  No run loop is pumped and no clock is waited on. The passes run
//  through the doors the column itself opens (= `PreviewPane`'s
//  `coverEntry(for:)` at PreviewPaneGrids.swift:87 and
//  `CardCoverView.load()` behind its `.task`), and every door is
//  synchronous or awaited to completion, so the count is the same on a
//  loaded machine and an idle one. A rendered `NSHostingView` could
//  not be used for a count: it decides WHEN a card's `.task` runs, and
//  the only way to wait for it is a wall-clock budget (= the pattern
//  `CoverRemovalRefreshTests` carries).
//
//  The main-thread half is the half Apple's rule is about: "Rely on
//  previously prepared data in draw(_:), don't perform I/O or complex
//  calculations in this method".
//

import AppKit
import Foundation
import SwiftUI
import Testing
import WenshuAgent
@testable import WenshuApp
import WenshuData

@Suite("Cover disk reads", .serialized)
@MainActor
struct CoverDiskReadTests {
    /// One screenful of cards (= the material column at its widest
    /// adaptive setting holds about twelve tiles, and a lazy grid keeps
    /// the rows a scroll has just passed alive too).
    private static let screenful = 24

    // MARK: - Fixture

    /// A throwaway library root, so no test can reach the developer's
    /// own library.
    private func makeLibraryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "wenshu-cover-disk-read-test-\(UUID().uuidString)",
                isDirectory: true
            )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    /// Real picture bytes: `NSImage` answers nil for a made-up payload,
    /// and a card whose picture fails to decode re-asks on every pass,
    /// which would count the wrong thing.
    private func pictureBytes() -> Data {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 32,
            pixelsHigh: 32,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        for x in 0 ..< 32 {
            for y in 0 ..< 32 {
                rep.setColor(
                    NSColor(red: CGFloat(x) / 32, green: CGFloat(y) / 32, blue: 0.5, alpha: 1),
                    atX: x,
                    y: y
                )
            }
        }
        return rep.representation(using: .png, properties: [:])!
    }

    /// A library whose first `count` reference cards each hold a cover
    /// picture and a record, written with the service the app writes
    /// with (= so the fixture is the state a real column renders).
    private func makeFixtureLibrary(count: Int) throws -> [CardCoverTarget] {
        let service = CardCoverService()
        let picture = pictureBytes()
        var targets: [CardCoverTarget] = []
        for _ in 0 ..< count {
            let target = CardCoverTarget.reference(Reference(title: "A card with a cover").id)
            try service.saveImage(picture, forKey: target.coverKey, kind: WSCardCoverKind.reference)
            targets.append(target)
        }
        return targets
    }

    /// The pane whose grid the column renders. `coverEntry(for:)` is the
    /// ONE door every card's cover goes through (PreviewPaneGrids.swift:78).
    private func makePane() -> PreviewPane {
        PreviewPane(
            scope: .referenceScope(nil),
            onDoubleClick: { _ in },
            previewSortOrder: .constant(.pinyinFirstLetter)
        )
    }

    // MARK: - The passes

    /// One pass of the column over a screenful of cards: the grid's body
    /// asks each card what its cover holds, once per card.
    private func renderPass(pane: PreviewPane, targets: [CardCoverTarget]) async -> CoverDiskCounting.Tally {
        let tally = CoverDiskCounting.Tally()
        await CoverDiskCounting.$tally.withValue(tally) {
            for target in targets {
                _ = pane.coverEntry(for: target)
            }
        }
        return tally
    }

    /// One pass of the picture slot over a screenful of cards: each
    /// card's view asks for its picture (= the first render of a cell,
    /// and every render of it after the lazy grid built the cell again).
    private func appearancePass(pictures: [URL]) async -> CoverDiskCounting.Tally {
        let tally = CoverDiskCounting.Tally()
        await CoverDiskCounting.$tally.withValue(tally) {
            for url in pictures {
                await CardCoverView(imageURL: url).load()
            }
        }
        return tally
    }

    /// The picture file of every target's cover.
    private func pictureURLs(for targets: [CardCoverTarget]) -> [URL] {
        targets.compactMap { CardCoverService.imageURL(forKey: $0.coverKey) }
    }

    /// A library whose covers are ON THE DISK and unknown to this
    /// process: the folders and files are written directly, with no call
    /// to the cover service.
    ///
    /// That is the whole point of the fixture. A cover written by
    /// `CardCoverService` is a cover the column already knows about (=
    /// the writer publishes what it wrote), so driving the fixture
    /// through the service would measure a warm column and call it cold.
    /// A library that arrived from a sync, or one the app opened for the
    /// first time, is the case the walk and the cold pass are for.
    private func makeLibraryOnDisk(count: Int) throws -> [CardCoverTarget] {
        let picture = pictureBytes()
        let record = CoverRecord(cardKind: WSCardCoverKind.reference)
        let recordData = try CardCoverService.encoder.encode(record)
        var targets: [CardCoverTarget] = []
        for _ in 0 ..< count {
            let target = CardCoverTarget.reference(Reference(title: "A card with a cover").id)
            guard let directory = CardCoverService.directory(forKey: target.coverKey),
                  let imageURL = CardCoverService.imageURL(forKey: target.coverKey),
                  let recordURL = CardCoverService.recordURL(forKey: target.coverKey)
            else {
                throw CardCoverError.noLibrary
            }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try picture.write(to: imageURL, options: .atomic)
            try recordData.write(to: recordURL, options: .atomic)
            targets.append(target)
        }
        return targets
    }

    private func report(_ label: String, _ tally: CoverDiskCounting.Tally) {
        print(
            "COVER-DISK-READ \(label) total=\(tally.total) main=\(tally.onMainThread) "
                + "metadata=\(tally.count(.metadata)) bytes=\(tally.count(.bytes))"
        )
    }

    // MARK: - The counts

    //
    // Every phase below builds its OWN library and its OWN cards, which is
    // how the phases stay cold WITHOUT touching the app's global caches: a
    // card key is a UUID, so a card this test never asked about has no
    // answer held, and a picture path this test never read has no decoded
    // copy. Clearing the shared caches would be the lazy way to arrive
    // cold, and it would reach into whatever other suite is running in the
    // same process at that moment (= measured 2026-11-21: `removeAll` here
    // made `CoverGenerationServiceTests.failedGenerationKeepsThePreviousPicture`
    // fail in a full binary and pass alone, twice on the tip and never on
    // the base).

    @Test("A screenful renders, refreshes, and is answered from memory")
    func theColumnRendersAndRefreshes() async throws {
        // 1. The cold pass, in a library the app has never read.
        let coldRoot = try makeLibraryRoot()
        let coldMain: (Int, Int) = try await PathGuard.$libraryRootOverride.withValue(coldRoot.path) {
            let targets = try makeLibraryOnDisk(count: Self.screenful)
            let tally = await renderPass(pane: makePane(), targets: targets)
            report("render-cold", tally)
            return (tally.count(.metadata, onMainThread: true), tally.count(.bytes, onMainThread: true))
        }
        try? FileManager.default.removeItem(at: coldRoot)

        // A cold render still answers synchronously, and it asks ONCE per
        // card (= one listing of one cover folder, plus that folder's
        // record), not once per file it might hold. Only the MAIN-THREAD
        // half is asserted: the walk this same pass started runs off-thread
        // and reports into the same tally, and how much of it lands before
        // the pass ends is the machine's business, not the code's.
        #expect(coldMain.0 == Self.screenful, "a cold screenful asked \(coldMain.0) listing(s) on the main thread, expected one per card")
        #expect(coldMain.1 == Self.screenful, "a cold screenful read \(coldMain.1) file(s) on the main thread, expected one record per card")

        // 2. The walk, off the frame, and 3. the refresh: a second library,
        // read the way the library open reads it, then rendered.
        let warmRoot = try makeLibraryRoot()
        try await PathGuard.$libraryRootOverride.withValue(warmRoot.path) {
            let targets = try makeLibraryOnDisk(count: Self.screenful)
            let pane = makePane()

            let walkTally = CoverDiskCounting.Tally()
            await CoverDiskCounting.$tally.withValue(walkTally) {
                await CoverIndex.shared.prefillAndWait()
            }
            report("walk-itself", walkTally)

            // 2b. The screenful the walk warmed.
            let warmed = await renderPass(pane: pane, targets: targets)
            report("walk-and-render", warmed)

            // 3. The refresh: the same screenful rendered again.
            let refresh = await renderPass(pane: pane, targets: targets)
            report("render-refresh", refresh)

            // THE CLAIM.
            // The walk really did the reading, and none of it on the frame.
            #expect(walkTally.total > 0, "the walk read nothing, so the warm pass is not its doing")
            #expect(
                walkTally.onMainThread == 0,
                "the walk asked the disk \(walkTally.onMainThread) time(s) on the MAIN thread"
            )
            // A column warmed by the walk asks the disk NOTHING, over the
            // whole screenful - and it says so in a full parallel binary
            // too, because an entry is kept under the library it was read
            // from (= CoverEntryCache): another suite switching or
            // sweeping ITS OWN library cannot empty this one.
            #expect(
                warmed.onMainThread == 0,
                "a warmed screenful asked the disk \(warmed.onMainThread) time(s) on the MAIN thread"
            )
            #expect(warmed.total == 0, "a warmed screenful asked the disk \(warmed.total) time(s)")
            // And a refresh asks nothing either.
            #expect(refresh.total == 0, "a warm refresh asked the disk \(refresh.total) time(s)")
        }
        try? FileManager.default.removeItem(at: warmRoot)
    }

    @Test("A card scrolling into a walked column asks the disk nothing")
    func scrollingIntoAWalkedColumnIsAnsweredFromMemory() async throws {
        // The pass continuous scroll actually pays, and the one the
        // 5 ms ruler is about: the column is open, the covers folder
        // has been walked, and cards the view has NEVER drawn arrive
        // with their covers already on disk. On the base every one of
        // those cards paid its first frame in full (= 3 asks on the
        // main thread); here the walk has answered the whole library,
        // so the frame pays nothing.
        let root = try makeLibraryRoot()
        try await PathGuard.$libraryRootOverride.withValue(root.path) {
            // Two screenfuls sit on disk before anything is asked, so
            // the walk sees cards the view has not drawn - what a walk
            // over a real library does.
            let firstScreenful = try makeLibraryOnDisk(count: Self.screenful)
            let scrolledIn = try makeLibraryOnDisk(count: Self.screenful)
            let pane = makePane()

            let walkTally = CoverDiskCounting.Tally()
            await CoverDiskCounting.$tally.withValue(walkTally) {
                await CoverIndex.shared.prefillAndWait()
            }
            report("walk-two-screenfuls", walkTally)

            // The screenful the open draws.
            let first = await renderPass(pane: pane, targets: firstScreenful)
            report("render-first-screenful", first)

            // THE PASS: 24 cards the view has never drawn, the index
            // warm. Zero asks, total and on the main thread.
            let intoView = await renderPass(pane: pane, targets: scrolledIn)
            report("scroll-into-view", intoView)

            // The disclosed edge, named in the test so the card cannot
            // claim zero everywhere: a cover that arrives on the disk
            // AFTER this library's walk, with no announcement (the
            // walk is not a poll, by decision), is answered by the
            // cold door ONCE for that card - one listing and one
            // record, on the frame, 2 asks per card instead of the
            // base's 3 - and from memory every frame after.
            let latecomers = try makeLibraryOnDisk(count: Self.screenful)
            let lateFirst = await renderPass(pane: pane, targets: latecomers)
            report("late-arrival-first-render", lateFirst)
            let lateAgain = await renderPass(pane: pane, targets: latecomers)
            report("late-arrival-second-render", lateAgain)

            // THE CLAIMS.
            // The walk read both screenfuls, and none of it on a frame:
            // one listing of the covers folder plus two asks (= the
            // folder's listing and its record) for every cover folder.
            #expect(
                walkTally.total == 1 + 2 * (2 * Self.screenful),
                "the walk of two screenfuls asked the disk \(walkTally.total) time(s), expected \(1 + 2 * (2 * Self.screenful))"
            )
            #expect(
                walkTally.onMainThread == 0,
                "the walk asked the disk \(walkTally.onMainThread) time(s) on the MAIN thread"
            )
            #expect(first.total == 0, "the screenful after the open asked the disk \(first.total) time(s)")
            // The claim this whole card stands on: a card scrolling
            // into a warm column asks the disk NOTHING.
            #expect(
                intoView.total == 0,
                "24 cards scrolling into a walked column asked the disk \(intoView.total) time(s)"
            )
            #expect(
                intoView.onMainThread == 0,
                "24 cards scrolling into a walked column asked the disk \(intoView.onMainThread) time(s) on the MAIN thread"
            )
            // The late edge, pinned to its real size: 2 asks per card,
            // all on the frame, once.
            #expect(
                lateFirst.total == 2 * Self.screenful && lateFirst.onMainThread == 2 * Self.screenful,
                "a screenful arriving after the walk cost \(lateFirst.total) ask(s), \(lateFirst.onMainThread) on the MAIN thread, expected 2 per card on the frame"
            )
            #expect(
                lateAgain.total == 0,
                "the second render of the late screenful asked the disk \(lateAgain.total) time(s)"
            )
        }
        try? FileManager.default.removeItem(at: root)
    }

    @Test("A card's picture slot asks the disk nothing, on any pass")
    func thePictureSlotStopsAskingTheDisk() async throws {
        let root = try makeLibraryRoot()
        try await PathGuard.$libraryRootOverride.withValue(root.path) {
            let targets = try makeFixtureLibrary(count: Self.screenful)
            let pictures = pictureURLs(for: targets)
            #expect(pictures.count == Self.screenful)

            // The slot, cold: 24 pictures the app has never decoded.
            let first = await appearancePass(pictures: pictures)
            report("slot-cold", first)

            // The slot, warm: the same files asked again, which is what
            // a lazy grid does to every card that scrolls back.
            let again = await appearancePass(pictures: pictures)
            report("slot-warm", again)

            // Every byte read was read OFF the main thread, and no metadata
            // question was asked at all (= the key does not consult the
            // file), on either pass.
            #expect(first.count(.bytes, onMainThread: true) == 0)
            #expect(first.count(.metadata) == 0, "a cold slot asked the disk \(first.count(.metadata)) metadata question(s)")
            #expect(first.count(.bytes) == Self.screenful)
            // And the pass a scroll makes costs NOTHING at all: not one
            // stat per card, which is what the picture cache used to pay
            // for a key that carried the file's size and date.
            #expect(again.total == 0, "a warm slot asked the disk \(again.total) time(s)")
        }
        try? FileManager.default.removeItem(at: root)
    }

    @Test("A cover write tells the column, instead of waiting for it to ask")
    func aWritePublishesAndTheRenderAsksNothing() async throws {
        let root = try makeLibraryRoot()
        try await PathGuard.$libraryRootOverride.withValue(root.path) {
            let targets = try makeFixtureLibrary(count: Self.screenful)
            let pane = makePane()
            _ = await renderPass(pane: pane, targets: targets)

            // The door b5f34f59e0 named: a cover changes on the disk,
            // the change is announced, and the render the announcement
            // wakes up used to go and read the folder back.
            let service = CardCoverService()
            let changed = targets[3]
            try service.saveImage(
                pictureBytes(),
                forKey: changed.coverKey,
                kind: WSCardCoverKind.reference
            )
            CoverChangeSignal.shared.noteCoverChanged()
            let after = await renderPass(pane: pane, targets: targets)
            report("render-after-write", after)

            #expect(after.total == 0, "the render after a cover write asked the disk \(after.total) time(s)")
            // The card is not showing yesterday's cover, either: the
            // write's own answer is what the column now holds.
            let entry = pane.coverEntry(for: changed)
            #expect(entry.imageURL != nil)
            #expect(entry.record?.status == WSCardCoverStatus.staticReady)
            #expect(entry.videoURL == nil)
        }
        try? FileManager.default.removeItem(at: root)
    }
}
