//
//  BookSettingConstraintsToolsTests.swift · Wenshu · P1 ticket #16 (PORT-SPECIALIZED-011, 2026-09-04)
//  FINAL P1 specialized-ticket test file.
//
//  5 round-trip tests for BookSettingConstraints actor
//  (the Swift port of hermes's
//  `agent/specialized/book_setting_constraints.py`):
//
//    1. testAddConstraint_persistsToBookSidecar
//    2. testListConstraints_filtersBySeverity
//    3. testCheck_chapterWithForbiddenPhrase_returnsViolation
//    4. testCheck_chapterWithoutForbiddenPhrase_returnsNoViolations
//    5. testRemoveConstraint_removesFromSidecar
//
//  Test isolation: each test creates a fresh /tmp root +
//  shelvesRoot + a per-book subdirectory that mirrors the
//  production walk (`<shelvesRoot>/<shelf>/books/<id>/`).
//  Caller-side teardown is not required (= the directory is
//  /tmp + unique uuid; macOS auto-cleans /tmp).
//
//  Test pattern mirrors IdeaLibraryToolsTests /
//  CharacterLifecycleToolsTests (= uses the real
//  LibraryStores struct + FileSystemReferenceStore; no stubs).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("BookSettingConstraints (PORT-SPECIALIZED-011)")
struct BookSettingConstraintsToolsTests {

    // MARK: - Shared helpers

    /// Build a tiny BookStore rooted in a unique /tmp directory.
    private static func makeBookStore() throws -> (BookStore, LibraryStores) {
        let tmpRoot = URL(fileURLWithPath: "/tmp/wenshu-p1-16-\(UUID().uuidString)", isDirectory: true)
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

    // MARK: - Test 1: add persists to the sidecar

    @Test("add persists a constraint to the per-book sidecar")
    func testAddConstraint_persistsToBookSidecar() async throws {
        let bookId = Self.sampleBookId()
        let (store, dir) = try Self.makeBookStoreWithDir(for: bookId)
        let tracker = BookSettingConstraints(bookStore: store)

        let constraint = BookSettingConstraint(
            bookId: bookId,
            title: "Magic requires eye contact",
            description: "A mage must make eye contact with the target to cast.",
            severity: .hard,
            scope: .world,
            forbiddenPatterns: ["cast without looking", "cast from behind"]
        )
        try await tracker.add(constraint)

        // Reload via a fresh actor (= proves the write actually
        // hit disk + was re-read on cold cache).
        let reloaded = BookSettingConstraints(bookStore: store)
        let listed = try await reloaded.list(bookId: bookId)
        #expect(listed.count == 1)
        let saved = listed.first
        #expect(saved?.id == constraint.id)
        #expect(saved?.title == "Magic requires eye contact")
        #expect(saved?.description == "A mage must make eye contact with the target to cast.")
        #expect(saved?.severity == .hard)
        #expect(saved?.scope == .world)
        #expect(saved?.forbiddenPatterns == ["cast without looking", "cast from behind"])
        #expect(saved?.appliesToId == nil)

        // Sidecar file must exist on disk (= the actor wrote it).
        let sidecarURL = dir.appendingPathComponent("setting-constraints.json")
        #expect(FileManager.default.fileExists(atPath: sidecarURL.path))
    }

    // MARK: - Test 2: list filters by severity

    @Test("list filters constraints by severity")
    func testListConstraints_filtersBySeverity() async throws {
        let bookId = Self.sampleBookId()
        let (store, _) = try Self.makeBookStoreWithDir(for: bookId)
        let tracker = BookSettingConstraints(bookStore: store)

        // Two hard constraints, one soft, one preference.
        try await tracker.add(BookSettingConstraint(
            bookId: bookId,
            title: "No resurrection",
            severity: .hard,
            scope: .world
        ))
        try await tracker.add(BookSettingConstraint(
            bookId: bookId,
            title: "Magic has a cost",
            severity: .hard,
            scope: .world
        ))
        try await tracker.add(BookSettingConstraint(
            bookId: bookId,
            title: "First-person narration",
            severity: .soft,
            scope: .style
        ))
        try await tracker.add(BookSettingConstraint(
            bookId: bookId,
            title: "Avoid passive voice",
            severity: .preference,
            scope: .style
        ))

        let hardOnly = try await tracker.list(bookId: bookId, severity: .hard)
        #expect(hardOnly.count == 2)
        #expect(hardOnly.allSatisfy { $0.severity == .hard })

        let softOnly = try await tracker.list(bookId: bookId, severity: .soft)
        #expect(softOnly.count == 1)
        #expect(softOnly.first?.severity == .soft)

        let preferenceOnly = try await tracker.list(bookId: bookId, severity: .preference)
        #expect(preferenceOnly.count == 1)
        #expect(preferenceOnly.first?.severity == .preference)

        let all = try await tracker.list(bookId: bookId)
        #expect(all.count == 4)

        // Filter by scope too.
        let styleRules = try await tracker.list(bookId: bookId, scope: .style)
        #expect(styleRules.count == 2)
        #expect(styleRules.allSatisfy { $0.scope == .style })

        // Hard rules surface first in the unfiltered sort order.
        #expect(all.first?.severity == .hard)
    }

    // MARK: - Test 3: chapter with forbidden phrase returns a violation

    @Test("check returns a violation when chapter text contains a forbidden phrase")
    func testCheck_chapterWithForbiddenPhrase_returnsViolation() async throws {
        let bookId = Self.sampleBookId()
        let (store, _) = try Self.makeBookStoreWithDir(for: bookId)
        let tracker = BookSettingConstraints(bookStore: store)

        try await tracker.add(BookSettingConstraint(
            bookId: bookId,
            title: "Magic requires eye contact",
            description: "A mage must look at the target.",
            severity: .hard,
            scope: .world,
            forbiddenPatterns: ["cast from behind"]
        ))

        let chapter = """
        Mara stood at the edge of the battlefield.
        She chose to cast from behind the pillar, unseen.
        The spell detonated with a flash of white.
        """

        let violations = try await tracker.check(chapterText: chapter, bookId: bookId)
        #expect(violations.count == 1)
        let hit = violations.first
        #expect(hit?.title == "Magic requires eye contact")
        #expect(hit?.severity == .hard)
        #expect(hit?.scope == .world)
        #expect(hit?.matchedText.contains("cast from behind") == true)
        #expect(hit?.lineNumber == 2)
        #expect(hit?.suggestion.contains("Rewrite") == true)
    }

    // MARK: - Test 4: chapter without forbidden phrase returns no violations

    @Test("check returns no violations when chapter text is clean")
    func testCheck_chapterWithoutForbiddenPhrase_returnsNoViolations() async throws {
        let bookId = Self.sampleBookId()
        let (store, _) = try Self.makeBookStoreWithDir(for: bookId)
        let tracker = BookSettingConstraints(bookStore: store)

        try await tracker.add(BookSettingConstraint(
            bookId: bookId,
            title: "No resurrection",
            severity: .hard,
            scope: .world,
            forbiddenPatterns: ["came back from the dead", "resurrected by"]
        ))
        try await tracker.add(BookSettingConstraint(
            bookId: bookId,
            title: "Magic requires eye contact",
            severity: .hard,
            scope: .world,
            forbiddenPatterns: ["cast from behind"]
        ))

        let chapter = """
        Mara looked the marshal in the eye.
        She whispered the words of power and the spell took hold.
        The crowd gasped as the ward dissolved.
        """

        let violations = try await tracker.check(chapterText: chapter, bookId: bookId)
        #expect(violations.isEmpty)
    }

    // MARK: - Test 5: remove constraint removes from sidecar

    @Test("remove deletes a constraint from the per-book sidecar")
    func testRemoveConstraint_removesFromSidecar() async throws {
        let bookId = Self.sampleBookId()
        let (store, dir) = try Self.makeBookStoreWithDir(for: bookId)
        let tracker = BookSettingConstraints(bookStore: store)

        let keepMe = BookSettingConstraint(
            bookId: bookId,
            title: "Keep this one",
            severity: .soft,
            scope: .world
        )
        let dropMe = BookSettingConstraint(
            bookId: bookId,
            title: "Drop this one",
            severity: .hard,
            scope: .character,
            appliesToId: UUID()
        )
        try await tracker.add(keepMe)
        try await tracker.add(dropMe)
        // Sanity check: both rows landed.
        let beforeRemove = try await tracker.list(bookId: bookId)
        #expect(beforeRemove.count == 2)

        try await tracker.remove(id: dropMe.id)

        // Reload via a fresh actor to prove the deletion
        // persisted to disk + the list is now correct.
        let reloaded = BookSettingConstraints(bookStore: store)
        let afterRemove = try await reloaded.list(bookId: bookId)
        #expect(afterRemove.count == 1)
        #expect(afterRemove.first?.id == keepMe.id)
        #expect(afterRemove.first?.title == "Keep this one")

        // Sidecar file must still exist (= the actor re-wrote
        // it after the removal).
        let sidecarURL = dir.appendingPathComponent("setting-constraints.json")
        #expect(FileManager.default.fileExists(atPath: sidecarURL.path))

        // Removing an unknown id throws (.constraintNotFound).
        await #expect(throws: BookSettingConstraintsError.self) {
            try await tracker.remove(id: UUID())
        }
    }
}