//
//  CharacterLifecycleToolsTests.swift · Wenshu · P1 ticket #13 (PORT-SPECIALIZED-008, 2026-09-04)
//
//  5 round-trip tests for CharacterLifecycleTracker actor
//  (the Swift port of hermes's
//  `agent/specialized/character_lifecycle.py`):
//
//    1. testAddEvent_persistsToBookSidecar
//    2. testListEvents_filtersByCharacter
//    3. testTimeline_returnsSortedEvents
//    4. testContradictions_detectsDeadButActive
//    5. testRemoveEvent_removesFromSidecar
//
//  Test isolation: each test creates a fresh /tmp root +
//  shelvesRoot + a per-book subdirectory that mirrors the
//  production walk (`<shelvesRoot>/<shelf>/books/<id>/`).
//  Caller-side teardown is not required (= the directory is
//  /tmp + unique uuid; macOS auto-cleans /tmp).
//
//  Test pattern mirrors CharacterRelationshipToolsTests /
//  LongFormGuardrailsTests (= uses the real LibraryStores
//  struct + FileSystemReferenceStore; no stubs).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("CharacterLifecycleTracker (PORT-SPECIALIZED-008)")
struct CharacterLifecycleToolsTests {

    // MARK: - Shared helpers

    /// Build a tiny BookStore rooted in a unique /tmp directory.
    private static func makeBookStore() throws -> (BookStore, LibraryStores) {
        let tmpRoot = URL(fileURLWithPath: "/tmp/wenshu-p1-13-\(UUID().uuidString)", isDirectory: true)
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

    @Test("add persists a lifecycle event to the per-book sidecar")
    func testAddEvent_persistsToBookSidecar() async throws {
        let bookId = Self.sampleBookId()
        let (store, dir) = try Self.makeBookStoreWithDir(for: bookId)
        let tracker = CharacterLifecycleTracker(bookStore: store)

        let character = UUID()
        let chapter = UUID()
        let event = LifecycleEvent(
            bookId: bookId,
            characterId: character,
            stage: .introduced,
            chapterId: chapter,
            excerpt: "The stranger stepped into the courtyard."
        )
        try await tracker.add(event)

        // Reload via a fresh actor (= proves the write actually
        // hit disk + was re-read on cold cache).
        let reloaded = CharacterLifecycleTracker(bookStore: store)
        let listed = try await reloaded.list(bookId: bookId)
        #expect(listed.count == 1)
        let saved = listed.first
        #expect(saved?.id == event.id)
        #expect(saved?.stage == .introduced)
        #expect(saved?.characterId == character)
        #expect(saved?.chapterId == chapter)
        #expect(saved?.excerpt == "The stranger stepped into the courtyard.")

        // Sidecar file must exist on disk (= the actor wrote it).
        let sidecarURL = dir.appendingPathComponent("character-lifecycle.json")
        #expect(FileManager.default.fileExists(atPath: sidecarURL.path))
    }

    // MARK: - Test 2: list filters by character

    @Test("list filters events by character")
    func testListEvents_filtersByCharacter() async throws {
        let bookId = Self.sampleBookId()
        let (store, _) = try Self.makeBookStoreWithDir(for: bookId)
        let tracker = CharacterLifecycleTracker(bookStore: store)

        let alice = UUID()
        let bob = UUID()

        // Two events for Alice, one for Bob.
        try await tracker.add(LifecycleEvent(
            bookId: bookId,
            characterId: alice,
            stage: .introduced,
            excerpt: "Alice first appears in chapter 1."
        ))
        try await tracker.add(LifecycleEvent(
            bookId: bookId,
            characterId: alice,
            stage: .active,
            excerpt: "Alice runs through the forest."
        ))
        try await tracker.add(LifecycleEvent(
            bookId: bookId,
            characterId: bob,
            stage: .introduced,
            excerpt: "Bob is mentioned in passing."
        ))

        let aliceOnly = try await tracker.list(bookId: bookId, characterId: alice)
        #expect(aliceOnly.count == 2)
        #expect(aliceOnly.allSatisfy { $0.characterId == alice })

        let bobOnly = try await tracker.list(bookId: bookId, characterId: bob)
        #expect(bobOnly.count == 1)
        #expect(bobOnly.first?.characterId == bob)

        let all = try await tracker.list(bookId: bookId)
        #expect(all.count == 3)

        // Filter by stage.
        let introducedOnly = try await tracker.list(bookId: bookId, stage: .introduced)
        #expect(introducedOnly.count == 2)
        #expect(introducedOnly.allSatisfy { $0.stage == .introduced })
    }

    // MARK: - Test 3: timeline returns sorted events

    @Test("timeline returns events for a character sorted by chapter then createdAt")
    func testTimeline_returnsSortedEvents() async throws {
        let bookId = Self.sampleBookId()
        let (store, _) = try Self.makeBookStoreWithDir(for: bookId)
        let tracker = CharacterLifecycleTracker(bookStore: store)

        let character = UUID()
        let chapterA = UUID()
        let chapterB = UUID()
        let chapterC = UUID()

        // Add events out of order; the timeline must sort by
        // chapterId ascending.
        try await tracker.add(LifecycleEvent(
            bookId: bookId,
            characterId: character,
            stage: .active,
            chapterId: chapterC,
            excerpt: "Alice in chapter C."
        ))
        try await tracker.add(LifecycleEvent(
            bookId: bookId,
            characterId: character,
            stage: .introduced,
            chapterId: chapterA,
            excerpt: "Alice in chapter A."
        ))
        try await tracker.add(LifecycleEvent(
            bookId: bookId,
            characterId: character,
            stage: .wounded,
            chapterId: chapterB,
            excerpt: "Alice in chapter B."
        ))

        let timeline = try await tracker.timeline(bookId: bookId, characterId: character)
        #expect(timeline.count == 3)
        #expect(timeline[0].chapterId == chapterA)
        #expect(timeline[1].chapterId == chapterB)
        #expect(timeline[2].chapterId == chapterC)
        #expect(timeline[0].stage == .introduced)
        #expect(timeline[1].stage == .wounded)
        #expect(timeline[2].stage == .active)
    }

    // MARK: - Test 4: contradictions detect dead-but-active

    @Test("contradictions detects a character who is 'dead' then 'active' without resurrection")
    func testContradictions_detectsDeadButActive() async throws {
        let bookId = Self.sampleBookId()
        let (store, _) = try Self.makeBookStoreWithDir(for: bookId)
        let tracker = CharacterLifecycleTracker(bookStore: store)

        let character = UUID()
        let chapterA = UUID()
        let chapterB = UUID()

        // Death in chapter A, active in chapter B (= the canonical
        // contradiction).
        try await tracker.add(LifecycleEvent(
            bookId: bookId,
            characterId: character,
            stage: .dead,
            chapterId: chapterA,
            excerpt: "Alice fell in the final battle."
        ))
        try await tracker.add(LifecycleEvent(
            bookId: bookId,
            characterId: character,
            stage: .active,
            chapterId: chapterB,
            excerpt: "Alice charged the enemy line."
        ))

        // A second character with a consistent arc (no contradiction).
        let otherCharacter = UUID()
        let chapterC = UUID()
        try await tracker.add(LifecycleEvent(
            bookId: bookId,
            characterId: otherCharacter,
            stage: .dead,
            chapterId: chapterC,
            excerpt: "Bob stays dead."
        ))

        let issues = try await tracker.contradictions(bookId: bookId)
        #expect(issues.count == 1)
        let issue = issues.first
        #expect(issue != nil)
        #expect(issue?.characterId == character)
        #expect(issue?.conflictingEvents.count == 2)
        // The first conflicting event must be the `dead` one,
        // the second must be the `active` one (= the order is
        // stable).
        #expect(issue?.conflictingEvents[0].stage == .dead)
        #expect(issue?.conflictingEvents[1].stage == .active)
    }

    // MARK: - Test 5: remove clears the sidecar entry

    @Test("remove deletes the event from the sidecar")
    func testRemoveEvent_removesFromSidecar() async throws {
        let bookId = Self.sampleBookId()
        let (store, _) = try Self.makeBookStoreWithDir(for: bookId)
        let tracker = CharacterLifecycleTracker(bookStore: store)

        let event = LifecycleEvent(
            bookId: bookId,
            characterId: UUID(),
            stage: .wounded,
            excerpt: "The protagonist was hurt."
        )
        try await tracker.add(event)
        let listedBefore = try await tracker.list(bookId: bookId)
        #expect(listedBefore.count == 1)
        try await tracker.remove(id: event.id)
        let listedAfter = try await tracker.list(bookId: bookId)
        #expect(listedAfter.isEmpty)
    }
}