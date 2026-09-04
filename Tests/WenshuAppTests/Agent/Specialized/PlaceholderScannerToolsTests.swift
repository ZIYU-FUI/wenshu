//
//  PlaceholderScannerToolsTests.swift · Wenshu · P2 ticket #18 (PORT-SPECIALIZED-013, 2026-09-04)
//
//  5 round-trip tests for PlaceholderScanner actor (the Swift
//  port of hermes's
//  `agent/specialized/placeholder_scanner.py`):
//
//    1. testAddPlaceholder_persistsToBookSidecar
//    2. testUpdatePlaceholder_updatesStatus
//    3. testRemovePlaceholder_removesFromSidecar
//    4. testListPlaceholders_filtersByChapter
//    5. testScan_chapterWithTodoMarker_returnsMatch
//
//  Test isolation: each test creates a fresh /tmp root +
//  shelvesRoot + a per-book subdirectory that mirrors the
//  production walk (`<shelvesRoot>/<shelf>/books/<id>/`).
//  Caller-side teardown is not required (= the directory is
//  /tmp + unique uuid; macOS auto-cleans /tmp).
//
//  Test pattern mirrors ForeshadowingTrackerToolsTests /
//  IdeaLibraryToolsTests / BookSettingConstraintsToolsTests
//  (= uses the real LibraryStores struct +
//  FileSystemReferenceStore; no stubs).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("PlaceholderScanner (PORT-SPECIALIZED-013)")
struct PlaceholderScannerToolsTests {

    // MARK: - Shared helpers

    /// Build a tiny BookStore rooted in a unique /tmp directory.
    private static func makeBookStore() throws -> (BookStore, LibraryStores) {
        let tmpRoot = URL(fileURLWithPath: "/tmp/wenshu-p2-18-\(UUID().uuidString)", isDirectory: true)
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

    // MARK: - Test 1: add placeholder persists to the sidecar

    @Test("add persists a placeholder to the per-book sidecar")
    func testAddPlaceholder_persistsToBookSidecar() async throws {
        let bookId = Self.sampleBookId()
        let (store, dir) = try Self.makeBookStoreWithDir(for: bookId)
        let scanner = PlaceholderScanner(bookStore: store)

        let chapter = UUID()
        let row = Placeholder(
            bookId: bookId,
            chapterId: chapter,
            lineNumber: 42,
            context: "The detective paused. [TODO: explain motive here]",
            pattern: "[TODO: explain motive here]",
            status: .open
        )
        try await scanner.add(row)

        // Reload via a fresh actor (= proves the write actually
        // hit disk + was re-read on cold cache).
        let reloaded = PlaceholderScanner(bookStore: store)
        let listed = try await reloaded.list(bookId: bookId)
        #expect(listed.count == 1)
        let saved = listed.first
        #expect(saved?.id == row.id)
        #expect(saved?.bookId == bookId)
        #expect(saved?.chapterId == chapter)
        #expect(saved?.lineNumber == 42)
        #expect(saved?.context == "The detective paused. [TODO: explain motive here]")
        #expect(saved?.pattern == "[TODO: explain motive here]")
        #expect(saved?.status == .open)

        // Sidecar file must exist on disk (= the actor wrote it).
        let sidecarURL = dir.appendingPathComponent("placeholders.json")
        #expect(FileManager.default.fileExists(atPath: sidecarURL.path))
    }

    // MARK: - Test 2: update placeholder updates status

    @Test("update changes the placeholder's status")
    func testUpdatePlaceholder_updatesStatus() async throws {
        let bookId = Self.sampleBookId()
        let (store, _) = try Self.makeBookStoreWithDir(for: bookId)
        let scanner = PlaceholderScanner(bookStore: store)

        let chapter = UUID()
        let original = Placeholder(
            bookId: bookId,
            chapterId: chapter,
            lineNumber: 7,
            context: "Original context line.",
            pattern: "[TODO] original",
            status: .open
        )
        try await scanner.add(original)

        // Reload + verify the seed status.
        let reloaded = PlaceholderScanner(bookStore: store)
        let seeded = try await reloaded.get(id: original.id)
        #expect(seeded?.status == .open)

        // Update: status -> resolved (via `update`).
        let updated = Placeholder(
            id: original.id,
            bookId: original.bookId,
            chapterId: original.chapterId,
            lineNumber: original.lineNumber,
            context: original.context,
            pattern: original.pattern,
            status: .resolved
        )
        try await scanner.update(updated)

        // Reload again to verify the new status stuck on disk.
        let reloaded2 = PlaceholderScanner(bookStore: store)
        let final = try await reloaded2.get(id: original.id)
        #expect(final?.status == .resolved)

        // Also exercise the `abandon` convenience wrapper on a
        // fresh row (= round-trip through the helper path).
        let another = Placeholder(
            bookId: bookId,
            chapterId: chapter,
            lineNumber: 12,
            context: "Another context.",
            pattern: "[FIXME] check",
            status: .open
        )
        try await scanner.add(another)
        try await scanner.abandon(id: another.id)
        let reloaded3 = PlaceholderScanner(bookStore: store)
        let abandonedFinal = try await reloaded3.get(id: another.id)
        #expect(abandonedFinal?.status == .abandoned)
    }

    // MARK: - Test 3: remove placeholder removes from sidecar

    @Test("remove deletes a placeholder from the per-book sidecar")
    func testRemovePlaceholder_removesFromSidecar() async throws {
        let bookId = Self.sampleBookId()
        let (store, dir) = try Self.makeBookStoreWithDir(for: bookId)
        let scanner = PlaceholderScanner(bookStore: store)

        let chapter = UUID()
        let keepMe = Placeholder(
            bookId: bookId,
            chapterId: chapter,
            lineNumber: 1,
            context: "Keep.",
            pattern: "[TODO] keep",
            status: .open
        )
        let dropMe = Placeholder(
            bookId: bookId,
            chapterId: chapter,
            lineNumber: 2,
            context: "Drop.",
            pattern: "[FIXME] drop",
            status: .open
        )
        try await scanner.add(keepMe)
        try await scanner.add(dropMe)

        // Sanity check: both rows landed.
        let beforeRemove = try await scanner.list(bookId: bookId)
        #expect(beforeRemove.count == 2)

        try await scanner.remove(id: dropMe.id)

        // Reload via a fresh actor to prove the deletion
        // persisted to disk.
        let reloaded = PlaceholderScanner(bookStore: store)
        let afterRemove = try await reloaded.list(bookId: bookId)
        #expect(afterRemove.count == 1)
        #expect(afterRemove.first?.id == keepMe.id)
        #expect(afterRemove.first?.pattern == "[TODO] keep")

        // Sidecar file must still exist (= the actor re-wrote
        // it after the removal).
        let sidecarURL = dir.appendingPathComponent("placeholders.json")
        #expect(FileManager.default.fileExists(atPath: sidecarURL.path))

        // Removing an unknown id throws (.placeholderNotFound).
        await #expect(throws: PlaceholderScannerError.self) {
            try await scanner.remove(id: UUID())
        }
    }

    // MARK: - Test 4: list placeholders filters by chapter

    @Test("list filters placeholders by chapter")
    func testListPlaceholders_filtersByChapter() async throws {
        let bookId = Self.sampleBookId()
        let (store, _) = try Self.makeBookStoreWithDir(for: bookId)
        let scanner = PlaceholderScanner(bookStore: store)

        let chapterA = UUID()
        let chapterB = UUID()
        // 5 placeholders split across 2 chapters + 3 statuses.
        let row1 = Placeholder(
            bookId: bookId,
            chapterId: chapterA,
            lineNumber: 1,
            context: "Ch A, open.",
            pattern: "[TODO] A1",
            status: .open
        )
        let row2 = Placeholder(
            bookId: bookId,
            chapterId: chapterA,
            lineNumber: 2,
            context: "Ch A, resolved.",
            pattern: "[FIXME] A2",
            status: .resolved
        )
        let row3 = Placeholder(
            bookId: bookId,
            chapterId: chapterA,
            lineNumber: 3,
            context: "Ch A, abandoned.",
            pattern: "[XXX] A3",
            status: .abandoned
        )
        let row4 = Placeholder(
            bookId: bookId,
            chapterId: chapterB,
            lineNumber: 1,
            context: "Ch B, open.",
            pattern: "[INSERT] B1",
            status: .open
        )
        let row5 = Placeholder(
            bookId: bookId,
            chapterId: chapterB,
            lineNumber: 2,
            context: "Ch B, open.",
            pattern: "[TBD] B2",
            status: .open
        )
        try await scanner.add(row1)
        try await scanner.add(row2)
        try await scanner.add(row3)
        try await scanner.add(row4)
        try await scanner.add(row5)

        // Filter by chapterA only: 3 rows.
        let chapterAOnly = try await scanner.list(bookId: bookId, chapterId: chapterA)
        #expect(chapterAOnly.count == 3)
        #expect(chapterAOnly.allSatisfy { $0.chapterId == chapterA })

        // Filter by chapterB only: 2 rows.
        let chapterBOnly = try await scanner.list(bookId: bookId, chapterId: chapterB)
        #expect(chapterBOnly.count == 2)
        #expect(chapterBOnly.allSatisfy { $0.chapterId == chapterB })

        // Filter by chapterA + status=.open: 1 row (= row1).
        let chapterAOpen = try await scanner.list(
            bookId: bookId,
            status: .open,
            chapterId: chapterA
        )
        #expect(chapterAOpen.count == 1)
        #expect(chapterAOpen.first?.id == row1.id)

        // No chapter / no status filter: all 5 rows.
        let all = try await scanner.list(bookId: bookId)
        #expect(all.count == 5)

        // Filter by chapterA + status=.resolved: 1 row (= row2).
        let chapterAResolved = try await scanner.list(
            bookId: bookId,
            status: .resolved,
            chapterId: chapterA
        )
        #expect(chapterAResolved.count == 1)
        #expect(chapterAResolved.first?.id == row2.id)
    }

    // MARK: - Test 5: scan chapter with TODO marker returns a match

    @Test("scan returns a match for a chapter containing a TODO marker")
    func testScan_chapterWithTodoMarker_returnsMatch() async throws {
        let bookId = Self.sampleBookId()
        let (store, _) = try Self.makeBookStoreWithDir(for: bookId)
        let scanner = PlaceholderScanner(bookStore: store)

        let chapter = UUID()
        let text = """
        The wind howled outside the cabin.
        [TODO: describe the protagonist's childhood]
        She lit a candle and waited.
        """

        let matches = try await scanner.scan(
            chapterText: text,
            bookId: bookId,
            chapterId: chapter
        )

        #expect(matches.count == 1)
        let match = matches.first
        #expect(match?.bookId == bookId)
        #expect(match?.chapterId == chapter)
        #expect(match?.lineNumber == 2)
        #expect(match?.pattern == "[TODO: describe the protagonist's childhood]")
        #expect(match?.status == .open)
        #expect(match?.context.contains("[TODO") == true)

        // Scan must NOT persist anything on its own (= the
        // caller decides what to add).
        let stillEmpty = try await scanner.list(bookId: bookId)
        #expect(stillEmpty.isEmpty)

        // Now exercise scanAndAdd (= the one-shot
        // scan-and-persist helper) on a richer chapter text
        // with multiple placeholder families.
        let richerText = """
        Line one: clean.
        [FIXME: who locked the door?]
        Line three: also clean.
        [XXX: verify the timestamp]
        <HERE>
        {{character.name}}
        Line seven: trailing clean.
        """
        let richerChapter = UUID()
        let added = try await scanner.scanAndAdd(
            chapterText: richerText,
            bookId: bookId,
            chapterId: richerChapter
        )
        #expect(added.count == 4)

        // Reload via a fresh actor to prove all 4 stuck.
        let reloaded = PlaceholderScanner(bookStore: store)
        let persisted = try await reloaded.list(bookId: bookId, chapterId: richerChapter)
        #expect(persisted.count == 4)
        let patterns = Set(persisted.map(\.pattern))
        #expect(patterns.contains("[FIXME: who locked the door?]"))
        #expect(patterns.contains("[XXX: verify the timestamp]"))
        #expect(patterns.contains("<HERE>"))
        #expect(patterns.contains("{{character.name}}"))
    }
}
