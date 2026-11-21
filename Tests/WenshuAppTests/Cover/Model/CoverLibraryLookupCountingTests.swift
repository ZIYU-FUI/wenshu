//
//  Tests/WenshuAppTests/Cover/Model/CoverLibraryLookupCountingTests.swift
//
//  : CoverLibraryLookupCountingTests.
//  Counts how often a screenful of cards asks WHICH LIBRARY it is
//  drawing in, and from which thread.
//
//  Why this suite exists, in one sentence: the cover's disk counting
//  (`CoverDiskReadTests`) can prove a warm column asks the DISK nothing,
//  and a warm column can still ask the LIBRARY something per card -
//  `ActiveLibrary.path` is a UserDefaults read plus
//  `URL(resolvingBookmarkData:)` (see `LibraryBookmark.resolve`), it
//  lives outside `Features/Cover/` so a census of that folder cannot
//  see it, and under DEBUG it answers from `PathGuard.libraryRootOverride`
//  BEFORE the bookmark is touched, so a counter placed behind that
//  override would have recorded nothing here and everything in
//  production. The count therefore sits at the lookup's own entry point,
//  in front of both branches (= `CoverDiskCounting.noteLibraryLookup`),
//  and the last case below runs WITHOUT the override to show the door
//  fires on the shape production takes.
//
//  WHAT IS MEASURED, and the ruler it is measured against. Apple's rule
//  for this zone is that the drawing path reads data already prepared
//  for it and performs no I/O and no complex calculation, and resolving a
//  security-scoped bookmark IS preparation. So the claim is a COUNT, per
//  PASS and not per CARD: one grid pass over 24 warm cards costs ONE
//  library lookup, and a library lookup never rides a warm pass at all
//  unless a card asked for it. No milliseconds are claimed - there is no
//  Instruments in this lane, and a count is the number that reproduces
//  on every machine.
//
//  THE SHAPE THAT BUYS IT: a column resolves the covers folder ONCE and
//  hands the same value to every card (= `PreviewPane.coverEntries(for:)`
//  for a whole column, `coverEntry(for:root:)` for the grid bodies that
//  build one card at a time, and `LinkedDocumentCardBoard.coverURL(for:root:)`
//  for the board that B1 was found behind - the SECOND grid door, bounded
//  by a row below), and the cache scope stays the covers
//  FOLDER plus the card key (= `CoverEntryCache`), which is what keeps
//  one library's answer from ever answering another library's card. The
//  scoping is proven here, not assumed: two libraries in one process are
//  measured side by side, and each is answered from its own folders.
//
//  The passes are driven through the doors the column and the board
//  themselves open, all of them synchronous or awaited to completion,
//  and no run loop is pumped and no clock is waited on. Every phase
//  builds its OWN library
//  and its OWN card keys, so no phase clears a process-global cache and
//  reaches into whatever other suite is in flight.
//

import AppKit
import Foundation
import SwiftUI
import Testing
import WenshuAgent
@testable import WenshuApp
import WenshuData

@Suite("Cover library lookups counted per pass", .serialized)
@MainActor
struct CoverLibraryLookupCountingTests {
    /// One screenful of cards (= the same fixture size the disk counting
    /// suite publishes, so the two tables read together).
    private static let screenful = 24

    // MARK: - Fixture

    /// A throwaway library root, so no test can reach the developer's
    /// own library.
    private func makeLibraryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "wenshu-cover-lookup-test-\(UUID().uuidString)",
                isDirectory: true
            )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    /// Real picture bytes: a card whose picture fails to decode re-asks
    /// on every pass, which would count the wrong thing.
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
        rep.setColor(NSColor(red: 0.4, green: 0.5, blue: 0.6, alpha: 1), atX: 4, y: 4)
        return rep.representation(using: .png, properties: [:])!
    }

    /// A library whose covers are ON THE DISK and unknown to this
    /// process: folders and files written directly, with no call to the
    /// cover service, because a cover written through the service is
    /// already published and would measure a warm column as a cold one.
    private func makeLibraryOnDisk(count: Int) throws -> [CardCoverTarget] {
        let picture = pictureBytes()
        let recordData = try CardCoverService.encoder.encode(
            CoverRecord(cardKind: WSCardCoverKind.reference)
        )
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

    /// Book cards whose covers are ON THE DISK and unknown to this
    /// process, written like `makeLibraryOnDisk` writes the column's:
    /// straight to disk, through no service, so the pass is warm. The
    /// board draws `BookDoc`s: the OTHER cover-key kind.
    private func makeBookDocsOnDisk(count: Int) throws -> [BookDoc] {
        let picture = pictureBytes()
        let recordData = try CardCoverService.encoder.encode(
            CoverRecord(cardKind: WSCardCoverKind.bookDoc)
        )
        var documents: [BookDoc] = []
        for index in 0 ..< count {
            let document = BookDoc(
                id: UUID(),
                bookId: UUID(),
                folderName: "board",
                fileName: "card-\(index).md",
                modifiedAt: .now,
                createdAt: .now,
                tags: [],
                body: ""
            )
            let key = CardCoverService.key(forBookDoc: document.id)
            guard let directory = CardCoverService.directory(forKey: key),
                  let imageURL = CardCoverService.imageURL(forKey: key),
                  let recordURL = CardCoverService.recordURL(forKey: key)
            else {
                throw CardCoverError.noLibrary
            }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try picture.write(to: imageURL, options: .atomic)
            try recordData.write(to: recordURL, options: .atomic)
            documents.append(document)
        }
        return documents
    }

    /// The pane whose grid the column renders.
    private func makePane() -> PreviewPane {
        PreviewPane(
            scope: .referenceScope(nil),
            onDoubleClick: { _ in },
            previewSortOrder: .constant(.pinyinFirstLetter)
        )
    }

    // MARK: - The passes

    /// One grid pass drawn the way a grid body draws it: ONE covers
    /// folder hoisted for the pass, then a card at a time
    /// (= `categoryGridContent` / `overviewGrid` / `bookDocsGrid`).
    private func hoistedGridPass(
        pane: PreviewPane,
        targets: [CardCoverTarget]
    ) async -> CoverDiskCounting.Tally {
        let tally = CoverDiskCounting.Tally()
        await CoverDiskCounting.$tally.withValue(tally) {
            let coversRoot = CardCoverService.coversRoot
            for target in targets {
                _ = pane.coverEntry(for: target, root: coversRoot)
            }
        }
        return tally
    }

    /// One column pass through the pass-shaped door
    /// (= `PreviewPane.coverEntries(for:)`), the whole screenful per ask.
    private func batchPass(pane: PreviewPane, targets: [CardCoverTarget]) async -> CoverDiskCounting.Tally {
        let tally = CoverDiskCounting.Tally()
        await CoverDiskCounting.$tally.withValue(tally) {
            _ = pane.coverEntries(for: targets)
        }
        return tally
    }

    /// One grid pass drawn the WRONG way on purpose, as an arm: a card
    /// at a time through the door that resolves the library itself
    /// (= the shape a per-card door pays once per card, and the shape
    /// this arm exists to measure against the grid's own door).
    private func perCardDoorPass(
        pane: PreviewPane,
        targets: [CardCoverTarget]
    ) async -> CoverDiskCounting.Tally {
        let tally = CoverDiskCounting.Tally()
        await CoverDiskCounting.$tally.withValue(tally) {
            for target in targets {
                _ = pane.coverEntry(for: target)
            }
        }
        return tally
    }

    /// One board pass drawn the way `LinkedDocumentCardBoard.body`
    /// draws it: ONE covers folder hoisted for the pass, then the
    /// board's own per-card door (the second grid door B1 found).
    private func hoistedBoardPass(
        board: LinkedDocumentCardBoard,
        documents: [BookDoc]
    ) async -> CoverDiskCounting.Tally {
        let tally = CoverDiskCounting.Tally()
        await CoverDiskCounting.$tally.withValue(tally) {
            let coversRoot = CardCoverService.coversRoot
            for document in documents {
                _ = board.coverURL(for: document, root: coversRoot)
            }
        }
        return tally
    }

    /// The SAME board pass with the hoist removed at the call site:
    /// the folder re-derived per card, the shape the bound forbids.
    private func perCardRootBoardPass(
        board: LinkedDocumentCardBoard,
        documents: [BookDoc]
    ) async -> CoverDiskCounting.Tally {
        let tally = CoverDiskCounting.Tally()
        await CoverDiskCounting.$tally.withValue(tally) {
            for document in documents {
                _ = board.coverURL(for: document, root: CardCoverService.coversRoot)
            }
        }
        return tally
    }

    /// A library folder's path in ONE spelling.
    ///
    /// The temporary directory is written three ways in this harness and
    /// all three name the same folder: `/var/...` (what
    /// `FileManager.temporaryDirectory` hands back, and what the DEBUG
    /// override echoes), `/private/var/...` (what a security-scoped
    /// bookmark resolves to), and the `resolvingSymlinksInPath` form
    /// that collapses the first two. Comparing raw strings across them
    /// would call a correctly scoped answer a leak, so the comparison is
    /// made after collapsing the `/private` prefix.
    private func canonical(_ path: String) -> String {
        path.hasPrefix("/private/") ? String(path.dropFirst(8)) : path
    }

    /// Whether a picture's file is under a library's folder.
    ///
    /// The library folder is four levels above a cover file
    /// (= `<library>/assets/covers/<cardKey>/cover.heic`), and the
    /// comparison is on canonical paths (= `canonical(_:)`).
    private func isUnder(_ picture: URL, _ libraryRoot: URL) -> Bool {
        let ancestor = picture.deletingLastPathComponent()
            .deletingLastPathComponent() // out of the card's cover folder
            .deletingLastPathComponent() // out of `covers`
            .deletingLastPathComponent() // out of `assets`
        return canonical(ancestor.path) == canonical(libraryRoot.path)
    }

    private func report(_ label: String, _ tally: CoverDiskCounting.Tally) {
        print(
            "COVER-LIBRARY-LOOKUP \(label) total=\(tally.lookupsTotal) "
                + "main=\(tally.lookupsOnMainThread) disk=\(tally.total)"
        )
    }

    // MARK: - The counts

    @Test("A screenful scrolling into a walked column asks the LIBRARY once, not per card")
    func aWarmPassResolvesTheLibraryOnceForTheWholeColumn() async throws {
        let root = try makeLibraryRoot()
        try await PathGuard.$libraryRootOverride.withValue(root.path) {
            let firstScreenful = try makeLibraryOnDisk(count: Self.screenful)
            let scrolledIn = try makeLibraryOnDisk(count: Self.screenful)
            let pane = makePane()

            // The walk, awaited, exactly as the library open awaits it:
            // after this the column holds every cover folder in memory.
            await CoverIndex.shared.prefillAndWait()

            // THE PASS: 24 cards the view has never drawn, the index
            // warm, drawn the way the grid body draws them.
            let hoisted = await hoistedGridPass(pane: pane, targets: scrolledIn)
            report("grid-pass-of-24-warm-cards", hoisted)

            // THE CLAIM, as a count: the disk asks nothing (the claim
            // `CoverDiskReadTests` already publishes, re-proven through
            // this door), and the LIBRARY is asked once for the whole
            // pass - one grid body, one covers folder.
            #expect(
                hoisted.total == 0,
                "a warmed screenful asked the disk \(hoisted.total) time(s) through the hoisted grid door"
            )
            #expect(
                hoisted.lookupsTotal == 1,
                "one grid pass over \(Self.screenful) warm cards asked which library it is in \(hoisted.lookupsTotal) time(s), expected exactly one for the pass"
            )
            #expect(
                hoisted.lookupsOnMainThread == 1,
                "one grid pass asked which library it is in \(hoisted.lookupsOnMainThread) time(s) on the MAIN thread, expected the pass's single one"
            )

            // THE ARM that says this is a bound and not an accident: the
            // same 24 cards, warm, asked through the door that resolves
            // the library itself - one lookup PER CARD, which is the
            // cost the grid must not pay, and the number the fix moved.
            let perCard = await perCardDoorPass(pane: pane, targets: scrolledIn)
            report("per-card-door-of-24-warm-cards", perCard)
            #expect(
                perCard.lookupsTotal == Self.screenful,
                "the per-card door asked which library it is in \(perCard.lookupsTotal) time(s) for \(Self.screenful) cards; the grid's door costs 1 - if these agree, the hoist is gone"
            )
            #expect(
                perCard.total == 0,
                "the per-card pass asked the disk \(perCard.total) time(s), so this arm is measuring lookups and not reads"
            )

            // And the column-shaped door, the same screenful: ONE ask
            // for twenty-four cards, warm, and no disk at all.
            let batch = await batchPass(pane: pane, targets: scrolledIn)
            report("batch-door-of-24-warm-cards", batch)
            #expect(
                batch.lookupsTotal == 1,
                "the batch door asked which library it is in \(batch.lookupsTotal) time(s) for one column, expected one"
            )
            #expect(batch.total == 0, "the batch door asked the disk \(batch.total) time(s) on a warm column")

            // The first screenful of the open is answered too, and by
            // the same bound, so no pass quietly kept the old shape.
            let drawn = await hoistedGridPass(pane: pane, targets: firstScreenful)
            report("grid-pass-of-first-screenful", drawn)
            #expect(drawn.lookupsTotal == 1, "the open's first screenful asked the library \(drawn.lookupsTotal) time(s), expected one for the pass")
            #expect(drawn.total == 0, "the open's first screenful asked the disk \(drawn.total) time(s)")
        }
        try? FileManager.default.removeItem(at: root)
    }

    @Test("The linked-document board draws a warm screenful asking the LIBRARY once for the pass")
    func theLinkedBoardPassResolvesTheLibraryOnceForTheWholeBoard() async throws {
        let root = try makeLibraryRoot()
        try await PathGuard.$libraryRootOverride.withValue(root.path) {
            let documents = try makeBookDocsOnDisk(count: Self.screenful)

            // The walk awaited: after this every board card's folder
            // is in memory, so the measured window is a warm column.
            await CoverIndex.shared.prefillAndWait()
            let board = LinkedDocumentCardBoard(documents: documents, onOpen: { _ in })

            // THE PASS: 24 book cards, warm, drawn the way THIS board's
            // body draws it - one hoisted folder, the board's own door
            // per card (the door B1 was found behind).
            let hoisted = await hoistedBoardPass(board: board, documents: documents)
            report("linked-board-pass-of-24-warm-cards", hoisted)
            #expect(
                hoisted.total == 0,
                "a warmed board of \(Self.screenful) cards asked the disk \(hoisted.total) time(s) through the board's own door"
            )
            #expect(
                hoisted.lookupsTotal == 1,
                "one board pass over \(Self.screenful) warm cards asked which library it is in \(hoisted.lookupsTotal) time(s), expected exactly one for the pass (= the covers folder must be hoisted ONCE in `body` and handed to `coverURL(for:root:)`; re-deriving it inside the door puts a bookmark decode per card back into the draw)"
            )
            #expect(
                hoisted.lookupsOnMainThread == 1,
                "one board pass asked which library it is in \(hoisted.lookupsOnMainThread) time(s) on the MAIN thread, expected the pass's single one"
            )

            // THE ARM THAT SAYS THIS IS A BOUND AND NOT AN ACCIDENT:
            // the same door and cards, the folder re-derived per call.
            let perCard = await perCardRootBoardPass(board: board, documents: documents)
            report("linked-board-per-card-root-of-24-warm-cards", perCard)
            #expect(
                perCard.lookupsTotal == Self.screenful,
                "the board door with the folder re-derived per card recorded \(perCard.lookupsTotal) visit(s) for \(Self.screenful) cards; the hoisted pass costs 1 - if these agree, the pass stopped measuring the hoist"
            )
            #expect(
                perCard.total == 0,
                "the per-card-root board pass asked the disk \(perCard.total) time(s), so this arm measures lookups and not reads"
            )
        }
        try? FileManager.default.removeItem(at: root)
    }

    @Test("A cold column pays the lookup with the folder it is already paying")
    func theColdPassIsNotWorseThanTheWarmOneSays() async throws {
        let root = try makeLibraryRoot()
        try await PathGuard.$libraryRootOverride.withValue(root.path) {
            let targets = try makeLibraryOnDisk(count: Self.screenful)
            let pane = makePane()

            // The genuinely cold pass, printed and not asserted to a
            // number: every card here reads its folder (= 2 disk asks
            // per card, `CoverDiskReadTests` publishes that), kicks the
            // walk once, and is then answered from memory forever.
            let cold = await hoistedGridPass(pane: pane, targets: targets)
            report("grid-pass-cold", cold)
            #expect(
                cold.count(.metadata, onMainThread: true) == Self.screenful,
                "a cold screenful asked \(cold.count(.metadata, onMainThread: true)) folder listing(s) on the MAIN thread, expected one per card"
            )
            // The cold pass still cannot ask the LIBRARY per CARD on the
            // warm half of its own work: after the walk lands the same
            // pass-shaped door costs one, and every pass after it does.
            let afterWalk = await hoistedGridPass(pane: pane, targets: targets)
            report("grid-pass-cold-then-warm", afterWalk)
            #expect(afterWalk.lookupsTotal == 1, "the pass after the cold one asked the library \(afterWalk.lookupsTotal) time(s), expected one")
            #expect(afterWalk.total == 0, "the pass after the cold one asked the disk \(afterWalk.total) time(s)")
        }
        try? FileManager.default.removeItem(at: root)
    }

    @Test("Two libraries in one process answer their own cards, from their own folders")
    func oneLibrarysAnswerNeverAnswersAnotherLibrarysCard() async throws {
        let rootA = try makeLibraryRoot()
        let rootB = try makeLibraryRoot()
        defer { try? FileManager.default.removeItem(at: rootA) }
        defer { try? FileManager.default.removeItem(at: rootB) }

        // Library A, walked and drawn warm.
        let targetsA = try await PathGuard.$libraryRootOverride.withValue(rootA.path) {
            let targets = try makeLibraryOnDisk(count: Self.screenful)
            await CoverIndex.shared.prefillAndWait()
            let pane = makePane()
            let pass = await hoistedGridPass(pane: pane, targets: targets)
            report("library-a-warm", pass)
            #expect(pass.total == 0, "library A asked the disk \(pass.total) time(s) on a warm pass")
            #expect(pass.lookupsTotal == 1, "library A asked the library door \(pass.lookupsTotal) time(s) for one pass")
            return targets
        }

        // Library B, a DIFFERENT folder in the same process, whose cards
        // have never been read: the scope is B's covers folder, so B must
        // go to B's disk and may not be answered from A's memory.
        let answersB: [CoverEntry] = try await PathGuard.$libraryRootOverride.withValue(rootB.path) {
            let targets = try makeLibraryOnDisk(count: Self.screenful)
            let pane = makePane()
            // B's own walk, awaited BEFORE the measured window, so what
            // the pass below measures is B warm and not B cold.
            await CoverIndex.shared.prefillAndWait()
            let pass = await batchPass(pane: pane, targets: targets)
            report("library-b-after-a", pass)
            #expect(
                pass.total == 0,
                "library B asked the disk \(pass.total) time(s) on a warm pass, so this is not measuring the scoping"
            )
            // If B had been answered from A's memory the pass would
            // print 0 asks too, which is why the answer's PATHS are the
            // assertion, and why A's and B's cards are different keys.
            #expect(
                pass.lookupsTotal == 1,
                "library B asked the library door \(pass.lookupsTotal) time(s) for one pass, expected one"
            )
            let entries = pane.coverEntries(for: targets)
            #expect(entries.count == Self.screenful)
            for entry in entries {
                if let picture = entry.imageURL {
                    #expect(
                        isUnder(picture, rootB),
                        "a card in library B was answered with \(picture.path), which is not under B's root"
                    )
                }
            }
            return entries
        }
        #expect(answersB.count == Self.screenful)

        // Back to A: its answers survived B's business (= a switch drops
        // nothing, and a scope is a folder), one lookup for the pass and
        // no disk at all, and every picture still under A's root.
        try await PathGuard.$libraryRootOverride.withValue(rootA.path) {
            let pane = makePane()
            let pass = await hoistedGridPass(pane: pane, targets: targetsA)
            report("library-a-again", pass)
            #expect(pass.total == 0, "library A asked the disk \(pass.total) time(s) after another library was drawn")
            #expect(pass.lookupsTotal == 1, "library A asked the library door \(pass.lookupsTotal) time(s) after another library was drawn")
            for target in targetsA {
                let picture = pane.coverEntry(for: target, root: CardCoverService.coversRoot).imageURL
                #expect(
                    picture != nil,
                    "library A's card lost its cover after another library was drawn"
                )
                if let picture {
                    #expect(
                        isUnder(picture, rootA),
                        "a card in library A was answered with \(picture.path), which is not under A's root"
                    )
                }
            }
        }
    }

    @Test("The counter fires on BOTH branches: a persisted bookmark, and none")
    func theInstrumentIsNotHiddenBehindTheDebugOverride() async throws {
        // The trap this suite was written against: `ActiveLibrary.path`
        // answers from `PathGuard.libraryRootOverride` BEFORE it would
        // touch the persisted bookmark, so a counter placed at
        // `LibraryBookmark.resolve()` records NOTHING in this harness
        // and EVERYTHING in production, and a zero read through it is
        // vacuous. The counter sits in front of both branches, so the
        // two arms below must both come up non-zero: if the instrument
        // were behind the override, ARM 1 would print 0 and the case
        // would pass on an accident.
        let root = try makeLibraryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let defaultsKey = LibraryBookmark.defaultsKey
        let savedBookmark = UserDefaults.standard.data(forKey: defaultsKey)
        defer {
            if let savedBookmark {
                UserDefaults.standard.set(savedBookmark, forKey: defaultsKey)
            } else {
                UserDefaults.standard.removeObject(forKey: defaultsKey)
            }
        }
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("assets/covers", isDirectory: true),
            withIntermediateDirectories: true
        )

        // ARM 1 - PRODUCTION'S BRANCH: no override at all, and the
        // library persisted as a security-scoped bookmark, which is what
        // the shipped app does. The answer must come from the bookmark.
        try ActiveLibrary.setActiveLibrary(at: root)
        let bookmarkPath = ActiveLibrary.path
        #expect(
            bookmarkPath.map(canonical) == root.path,
            "the bookmark did not answer the library door: \(String(describing: bookmarkPath)) vs \(root.path)"
        )
        let targets = try await PathGuard.$libraryRootOverride.withValue(root.path) {
            try makeLibraryOnDisk(count: Self.screenful)
        }
        await PathGuard.$libraryRootOverride.withValue(nil) {
            await CoverIndex.shared.prefillAndWait()
            let pane = makePane()
            let warm = await batchPass(pane: pane, targets: targets)
            report("no-override-warm-column-via-persisted-bookmark", warm)
            // A WARM column through the production branch costs the
            // library door ONE visit for the pass, not one per card, and
            // the disk nothing - the same claim as the override arm, now
            // measured on the path that resolves the bookmark.
            #expect(
                warm.lookupsTotal == 1,
                "24 warm cards read through a persisted bookmark asked the library door \(warm.lookupsTotal) time(s), expected one for the pass (= a bookmark decode per card is back)"
            )
            #expect(warm.total == 0, "the bookmark pass asked the disk \(warm.total) time(s)")

            // And the per-card shape on the SAME branch, so the bound is
            // shown to be a property of the door and not of the harness:
            // twenty-four cards, twenty-four bookmark decodes.
            let perCard = await perCardDoorPass(pane: pane, targets: targets)
            report("no-override-per-card-door-via-persisted-bookmark", perCard)
            #expect(
                perCard.lookupsTotal == Self.screenful,
                "the per-card door through the bookmark recorded \(perCard.lookupsTotal) visit(s) for \(Self.screenful) cards; a counter behind the DEBUG override would have recorded 0 here"
            )
        }

        // ARM 2 - NOTHING TO ANSWER: no override and no bookmark at all.
        // The door is still visited and still counted, and it asks no
        // file, which is what makes ARM 1's zeros a measurement rather
        // than a stub.
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        let nothingPath = ActiveLibrary.path
        let tally = CoverDiskCounting.Tally()
        await CoverDiskCounting.$tally.withValue(tally) {
            await PathGuard.$libraryRootOverride.withValue(nil) {
                let service = CardCoverService()
                for _ in 0 ..< 4 {
                    let key = CardCoverService.key(forReference: UUID())
                    _ = service.entry(forKey: key, root: CardCoverService.coversRoot)
                }
            }
        }
        report("four-cards-with-no-override-and-no-bookmark", tally)
        #expect(nothingPath == nil, "the arm is not testing what it claims: a library answered it after all")
        #expect(
            tally.lookupsTotal >= 4,
            "four cards visited the library door and the instrument recorded \(tally.lookupsTotal): at least one visit per card must be visible with NO override in play, or every zero in this suite is a stub"
        )
        #expect(
            tally.lookupsOnMainThread == tally.lookupsTotal,
            "the visits were recorded on \(tally.lookupsOnMainThread) of \(tally.lookupsTotal) on the MAIN thread: a card's door runs on the frame's thread"
        )
        #expect(tally.total == 0, "with no library the door asked the disk \(tally.total) time(s), expected nothing")
    }
}
