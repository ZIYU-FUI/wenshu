//
//  ForeshadowingTrackerToolsTests.swift · Wenshu · P2 ticket #17 (PORT-SPECIALIZED-012, 2026-09-04)
//
//  5 round-trip tests for ForeshadowingTracker actor (the Swift
//  port of hermes's
//  `agent/specialized/foreshadowing_tracker.py`):
//
//    1. testAddForeshadowing_persistsToBookSidecar
//    2. testUpdateForeshadowing_updatesStatus
//    3. testRemoveForeshadowing_removesFromSidecar
//    4. testListForeshadowings_filtersByStatus
//    5. testStaleForeshadowings_returnsOpenOlderThanThreshold
//
//  Test isolation: each test creates a fresh /tmp root +
//  shelvesRoot + a per-book subdirectory that mirrors the
//  production walk (`<shelvesRoot>/<shelf>/books/<id>/`).
//  Caller-side teardown is not required (= the directory is
//  /tmp + unique uuid; macOS auto-cleans /tmp).
//
//  Test pattern mirrors IdeaLibraryToolsTests /
//  BookSettingConstraintsToolsTests (= uses the real
//  LibraryStores struct + FileSystemReferenceStore; no stubs).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ForeshadowingTracker (PORT-SPECIALIZED-012)")
struct ForeshadowingTrackerToolsTests {

    // MARK: - Shared helpers

    /// Build a tiny BookStore rooted in a unique /tmp directory.
    private static func makeBookStore() throws -> (BookStore, LibraryStores) {
        let tmpRoot = URL(fileURLWithPath: "/tmp/wenshu-p2-17-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)
        let shelvesRoot = tmpRoot.appendingPathComponent("shelves", isDirectory: true)
        let referenceLibraryRoot = tmpRoot.appendingPathComponent("reference-library", isDirectory: true)
        let referenceStore = FileSystemReferenceStore(referenceLibraryRoot: referenceLibraryRoot)
        let stores = LibraryStores(
            shelvesRoot: shelvesRoot,
            referenceLibraryRoot: referenceLibraryRoot,
            referenceStore: referenceStore
        )
        return (BookStore(stores: stores), stores)
    }

    /// Build a per-test book directory under `stores.shelvesRoot`.
    private static func makeBookDir(under stores: LibraryStores, bookId: UUID) throws -> URL {
        let shelfUUID = UUID().uuidString
        let bookDir = stores.shelvesRoot
            .appendingPathComponent(shelfUUID, isDirectory: true)
            .appendingPathComponent("books", isDirectory: true)
            .appendingPathComponent(bookId.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: bookDir, withIntermediateDirectories: true)
        return bookDir
    }

    /// Convenience composition of `makeBookStore` + `makeBookDir`.
    private static func makeBookStoreWithDir(for bookId: UUID) throws -> (BookStore, URL) {
        let (store, stores) = try makeBookStore()
        let dir = try makeBookDir(under: stores, bookId: bookId)
        return (store, dir)
    }

    private static func sampleBookId() -> UUID { UUID() }

    // MARK: - Test 1: add foreshadowing persists to the sidecar

    @Test("add persists a foreshadowing to the per-book sidecar")
    func testAddForeshadowing_persistsToBookSidecar() async throws {
        let bookId = Self.sampleBookId()
        let (store, dir) = try Self.makeBookStoreWithDir(for: bookId)
        let tracker = ForeshadowingTracker(bookStore: store)

        let setupChapter = UUID()
        let row = Foreshadowing(
            bookId: bookId,
            title: "The silver dagger",
            setupChapterId: setupChapter,
            setupExcerpt: "The blade gleamed in the moonlight.",
            status: .setup
        )
        try await tracker.add(row)

        // Reload via a fresh actor (= proves the write actually
        // hit disk + was re-read on cold cache).
        let reloaded = ForeshadowingTracker(bookStore: store)
        let listed = try await reloaded.list(bookId: bookId)
        #expect(listed.count == 1)
        let saved = listed.first
        #expect(saved?.id == row.id)
        #expect(saved?.title == "The silver dagger")
        #expect(saved?.setupChapterId == setupChapter)
        #expect(saved?.setupExcerpt == "The blade gleamed in the moonlight.")
        #expect(saved?.payoffChapterId == nil)
        #expect(saved?.payoffExcerpt == nil)
        #expect(saved?.status == .setup)
        #expect(saved?.bookId == bookId)

        // Sidecar file must exist on disk (= the actor wrote it).
        let sidecarURL = dir.appendingPathComponent("foreshadowings.json")
        #expect(FileManager.default.fileExists(atPath: sidecarURL.path))
    }

    // MARK: - Test 2: update foreshadowing updates status

    @Test("update changes the foreshadowing's status")
    func testUpdateForeshadowing_updatesStatus() async throws {
        let bookId = Self.sampleBookId()
        let (store, _) = try Self.makeBookStoreWithDir(for: bookId)
        let tracker = ForeshadowingTracker(bookStore: store)

        let setupChapter = UUID()
        let payoffChapter = UUID()
        let original = Foreshadowing(
            bookId: bookId,
            title: "The silver dagger",
            setupChapterId: setupChapter,
            setupExcerpt: "The blade gleamed in the moonlight.",
            payoffChapterId: nil,
            payoffExcerpt: nil,
            status: .setup
        )
        try await tracker.add(original)

        // Reload + verify the seed status.
        let reloaded = ForeshadowingTracker(bookStore: store)
        let seeded = try await reloaded.get(id: original.id)
        #expect(seeded?.status == .setup)
        #expect(seeded?.payoffChapterId == nil)

        // Update: status -> nearlyPaidOff, attach the payoff
        // chapter + excerpt.
        let updated = Foreshadowing(
            id: original.id,
            bookId: original.bookId,
            title: original.title,
            setupChapterId: original.setupChapterId,
            setupExcerpt: original.setupExcerpt,
            payoffChapterId: payoffChapter,
            payoffExcerpt: "She finally drew the dagger at the duel.",
            status: .nearlyPaidOff
        )
        try await tracker.update(updated)

        // Reload again to verify the new status + payoff stuck
        // on disk.
        let reloaded2 = ForeshadowingTracker(bookStore: store)
        let final = try await reloaded2.get(id: original.id)
        #expect(final?.status == .nearlyPaidOff)
        #expect(final?.payoffChapterId == payoffChapter)
        #expect(final?.payoffExcerpt == "She finally drew the dagger at the duel.")
    }

    // MARK: - Test 3: remove foreshadowing removes from sidecar

    @Test("remove deletes a foreshadowing from the per-book sidecar")
    func testRemoveForeshadowing_removesFromSidecar() async throws {
        let bookId = Self.sampleBookId()
        let (store, dir) = try Self.makeBookStoreWithDir(for: bookId)
        let tracker = ForeshadowingTracker(bookStore: store)

        let keepMe = Foreshadowing(
            bookId: bookId,
            title: "Keep this foreshadowing",
            setupChapterId: UUID(),
            status: .setup
        )
        let dropMe = Foreshadowing(
            bookId: bookId,
            title: "Drop this foreshadowing",
            setupChapterId: UUID(),
            status: .hinting
        )
        try await tracker.add(keepMe)
        try await tracker.add(dropMe)

        // Sanity check: both rows landed.
        let beforeRemove = try await tracker.list(bookId: bookId)
        #expect(beforeRemove.count == 2)

        try await tracker.remove(id: dropMe.id)

        // Reload via a fresh actor to prove the deletion
        // persisted to disk.
        let reloaded = ForeshadowingTracker(bookStore: store)
        let afterRemove = try await reloaded.list(bookId: bookId)
        #expect(afterRemove.count == 1)
        #expect(afterRemove.first?.id == keepMe.id)
        #expect(afterRemove.first?.title == "Keep this foreshadowing")

        // Sidecar file must still exist (= the actor re-wrote
        // it after the removal).
        let sidecarURL = dir.appendingPathComponent("foreshadowings.json")
        #expect(FileManager.default.fileExists(atPath: sidecarURL.path))

        // Removing an unknown id throws (.foreshadowingNotFound).
        await #expect(throws: ForeshadowingTrackerError.self) {
            try await tracker.remove(id: UUID())
        }
    }

    // MARK: - Test 4: list foreshadowings filters by status

    @Test("list filters foreshadowings by status")
    func testListForeshadowings_filtersByStatus() async throws {
        let bookId = Self.sampleBookId()
        let (store, _) = try Self.makeBookStoreWithDir(for: bookId)
        let tracker = ForeshadowingTracker(bookStore: store)

        // 5 foreshadowings across 5 statuses.
        let openRow = Foreshadowing(
            bookId: bookId,
            title: "Open foreshadowing",
            setupExcerpt: "Just set up.",
            status: .open
        )
        let setupRow = Foreshadowing(
            bookId: bookId,
            title: "Setup foreshadowing",
            setupChapterId: UUID(),
            setupExcerpt: "Tagged.",
            status: .setup
        )
        let hintingRow = Foreshadowing(
            bookId: bookId,
            title: "Hinting foreshadowing",
            setupChapterId: UUID(),
            setupExcerpt: "Referenced.",
            status: .hinting
        )
        let paidOffRow = Foreshadowing(
            bookId: bookId,
            title: "Paid off foreshadowing",
            setupChapterId: UUID(),
            payoffChapterId: UUID(),
            status: .paidOff
        )
        let abandonedRow = Foreshadowing(
            bookId: bookId,
            title: "Abandoned foreshadowing",
            setupExcerpt: "Abandoned.",
            status: .abandoned
        )
        try await tracker.add(openRow)
        try await tracker.add(setupRow)
        try await tracker.add(hintingRow)
        try await tracker.add(paidOffRow)
        try await tracker.add(abandonedRow)

        // Filter by .open: only the open row.
        let openOnly = try await tracker.list(bookId: bookId, status: .open)
        #expect(openOnly.count == 1)
        #expect(openOnly.first?.id == openRow.id)

        // Filter by .hinting: only the hinting row.
        let hintingOnly = try await tracker.list(bookId: bookId, status: .hinting)
        #expect(hintingOnly.count == 1)
        #expect(hintingOnly.first?.id == hintingRow.id)

        // Filter by .paidOff: only the paid off row.
        let paidOffOnly = try await tracker.list(bookId: bookId, status: .paidOff)
        #expect(paidOffOnly.count == 1)
        #expect(paidOffOnly.first?.id == paidOffRow.id)

        // Filter by .nearlyPaidOff: empty (we never set any).
        let nearlyPaidOffOnly = try await tracker.list(bookId: bookId, status: .nearlyPaidOff)
        #expect(nearlyPaidOffOnly.isEmpty)

        // No filter (= all 5).
        let all = try await tracker.list(bookId: bookId)
        #expect(all.count == 5)
    }

    // MARK: - Test 5: stale foreshadowings returns open older than threshold

    @Test("staleForeshadowings returns in-flight rows older than the threshold")
    func testStaleForeshadowings_returnsOpenOlderThanThreshold() async throws {
        let bookId = Self.sampleBookId()
        let (store, _) = try Self.makeBookStoreWithDir(for: bookId)
        let tracker = ForeshadowingTracker(bookStore: store)

        // Row 1: open status, old createdAt (= stale). Should be
        // returned by `staleForeshadowings`.
        let staleOpen = Foreshadowing(
            bookId: bookId,
            title: "Stale open foreshadowing",
            setupExcerpt: "Old.",
            status: .open,
            // 30 days ago (= older than the default 10-day
            // threshold).
            createdAt: Date().addingTimeInterval(-30 * 24 * 60 * 60)
        )

        // Row 2: open status, recent createdAt (= fresh). Should
        // NOT be returned.
        let freshOpen = Foreshadowing(
            bookId: bookId,
            title: "Fresh open foreshadowing",
            setupExcerpt: "Recent.",
            status: .open,
            // 1 day ago (= well within the 10-day threshold).
            createdAt: Date().addingTimeInterval(-1 * 24 * 60 * 60)
        )

        // Row 3: open status, old, but with a payoff chapter id
        // (= no longer "open without payoff" = NOT stale).
        let oldButPaidOff = Foreshadowing(
            bookId: bookId,
            title: "Old but with payoff",
            setupChapterId: UUID(),
            payoffChapterId: UUID(),
            status: .open,
            createdAt: Date().addingTimeInterval(-30 * 24 * 60 * 60)
        )

        // Row 4: abandoned (= terminal status) + old. Should NOT
        // be returned (= terminal statuses are never "stale").
        let oldAbandoned = Foreshadowing(
            bookId: bookId,
            title: "Old abandoned foreshadowing",
            setupExcerpt: "Abandoned long ago.",
            status: .abandoned,
            createdAt: Date().addingTimeInterval(-30 * 24 * 60 * 60)
        )

        // Row 5: paidOff (= terminal status) + old. Should NOT
        // be returned.
        let oldPaidOff = Foreshadowing(
            bookId: bookId,
            title: "Old paid off foreshadowing",
            setupChapterId: UUID(),
            payoffChapterId: UUID(),
            status: .paidOff,
            createdAt: Date().addingTimeInterval(-30 * 24 * 60 * 60)
        )

        try await tracker.add(staleOpen)
        try await tracker.add(freshOpen)
        try await tracker.add(oldButPaidOff)
        try await tracker.add(oldAbandoned)
        try await tracker.add(oldPaidOff)

        // Default threshold = 10 days. Only `staleOpen` matches
        // all 3 conditions (= in-flight status, no payoff, older
        // than 10 days).
        let stale = try await tracker.staleForeshadowings(bookId: bookId)
        #expect(stale.count == 1)
        #expect(stale.first?.id == staleOpen.id)

        // Custom threshold: 60 days. None of the rows match (the
        // only stale candidate is 30 days old, not 60).
        let noneStale = try await tracker.staleForeshadowings(
            bookId: bookId,
            maxChaptersWithoutPayoff: 60
        )
        #expect(noneStale.isEmpty)

        // Very lax threshold: 0 days. cutoff = now. Every row
        // constructed before `now` (= all 5) is strictly older
        // than the cutoff. Filter narrows by status + payoff:
        // only `staleOpen` (status=open, no payoff, 30d old) +
        // `freshOpen` (status=open, no payoff, 1d old, but
        // still < now) survive.
        let laxStale = try await tracker.staleForeshadowings(
            bookId: bookId,
            maxChaptersWithoutPayoff: 0
        )
        #expect(laxStale.count == 2)
        #expect(laxStale.contains { $0.id == staleOpen.id })
        #expect(laxStale.contains { $0.id == freshOpen.id })
    }
}