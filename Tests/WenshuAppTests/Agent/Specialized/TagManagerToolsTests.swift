//
//  TagManagerToolsTests.swift · Wenshu · P1 ticket #14 (PORT-SPECIALIZED-009, 2026-09-04)
//
//  5 round-trip tests for TagManager actor (the Swift port of
//  hermes's `agent/specialized/tag_manager.py`):
//
//    1. testAddTag_persistsToBookSidecar
//    2. testApplyTag_recordsApplication
//    3. testUnapplyTag_removesApplication
//    4. testTagCloud_returnsCountPerTag
//    5. testFilterByTag_returnsMatchingEntityIds
//
//  Test isolation: each test creates a fresh /tmp root +
//  shelvesRoot + a per-book subdirectory that mirrors the
//  production walk (`<shelvesRoot>/<shelf>/books/<id>/`).
//  Caller-side teardown is not required (= the directory is
//  /tmp + unique uuid; macOS auto-cleans /tmp).
//
//  Test pattern mirrors CharacterLifecycleToolsTests /
//  CharacterRelationshipToolsTests (= uses the real
//  LibraryStores struct + FileSystemReferenceStore; no stubs).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("TagManager (PORT-SPECIALIZED-009)")
struct TagManagerToolsTests {

    // MARK: - Shared helpers

    /// Build a tiny BookStore rooted in a unique /tmp directory.
    private static func makeBookStore() throws -> (BookStore, LibraryStores) {
        let tmpRoot = URL(fileURLWithPath: "/tmp/wenshu-p1-14-\(UUID().uuidString)", isDirectory: true)
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

    // MARK: - Test 1: add tag persists to the sidecar

    @Test("add persists a tag to the per-book sidecar")
    func testAddTag_persistsToBookSidecar() async throws {
        let bookId = Self.sampleBookId()
        let (store, dir) = try Self.makeBookStoreWithDir(for: bookId)
        let manager = TagManager(bookStore: store)

        let tag = Tag(
            bookId: bookId,
            label: "redemption",
            category: .theme
        )
        try await manager.addTag(tag)

        // Reload via a fresh actor (= proves the write actually
        // hit disk + was re-read on cold cache).
        let reloaded = TagManager(bookStore: store)
        let listed = try await reloaded.listTags(bookId: bookId)
        #expect(listed.count == 1)
        let saved = listed.first
        #expect(saved?.id == tag.id)
        #expect(saved?.label == "redemption")
        #expect(saved?.category == .theme)

        // Sidecar file must exist on disk (= the actor wrote it).
        let sidecarURL = dir.appendingPathComponent("tags.json")
        #expect(FileManager.default.fileExists(atPath: sidecarURL.path))
    }

    // MARK: - Test 2: apply tag records an application

    @Test("apply records a tag application for the target entity")
    func testApplyTag_recordsApplication() async throws {
        let bookId = Self.sampleBookId()
        let (store, _) = try Self.makeBookStoreWithDir(for: bookId)
        let manager = TagManager(bookStore: store)

        let tag = Tag(bookId: bookId, label: "love-triangle", category: .trope)
        try await manager.addTag(tag)

        let chapterA = UUID()
        let chapterB = UUID()
        let application = TagApplication(
            bookId: bookId,
            tagId: tag.id,
            target: .chapter,
            targetId: chapterA
        )
        try await manager.apply(application)
        // Second application to a different chapter.
        try await manager.apply(TagApplication(
            bookId: bookId,
            tagId: tag.id,
            target: .chapter,
            targetId: chapterB
        ))

        let apps = try await manager.applications(bookId: bookId)
        #expect(apps.count == 2)
        #expect(apps.allSatisfy { $0.tagId == tag.id })
        #expect(apps.allSatisfy { $0.target == .chapter })

        // Filter by tag — both rows must be present.
        let onlyForTag = try await manager.applications(bookId: bookId, tagId: tag.id)
        #expect(onlyForTag.count == 2)

        // Filter by target — only the chapter rows.
        let onlyChapters = try await manager.applications(bookId: bookId, target: .chapter)
        #expect(onlyChapters.count == 2)
    }

    // MARK: - Test 3: unapply removes the application

    @Test("unapply deletes the application row")
    func testUnapplyTag_removesApplication() async throws {
        let bookId = Self.sampleBookId()
        let (store, _) = try Self.makeBookStoreWithDir(for: bookId)
        let manager = TagManager(bookStore: store)

        let tag = Tag(bookId: bookId, label: "the-withered-oak", category: .symbol)
        try await manager.addTag(tag)

        let application = TagApplication(
            bookId: bookId,
            tagId: tag.id,
            target: .character,
            targetId: UUID()
        )
        try await manager.apply(application)
        let before = try await manager.applications(bookId: bookId)
        #expect(before.count == 1)
        try await manager.unapply(id: application.id)
        let after = try await manager.applications(bookId: bookId)
        #expect(after.isEmpty)

        // Tag itself must still exist (= unapply does not touch
        // the tag table; only the application row).
        let tagsAfter = try await manager.listTags(bookId: bookId)
        #expect(tagsAfter.count == 1)
        #expect(tagsAfter.first?.id == tag.id)
    }

    // MARK: - Test 4: tag cloud returns one entry per tag with count

    @Test("tag cloud returns one entry per tag with a count of distinct applications")
    func testTagCloud_returnsCountPerTag() async throws {
        let bookId = Self.sampleBookId()
        let (store, _) = try Self.makeBookStoreWithDir(for: bookId)
        let manager = TagManager(bookStore: store)

        let redemption = Tag(bookId: bookId, label: "redemption", category: .theme)
        let oak = Tag(bookId: bookId, label: "the-withered-oak", category: .symbol)
        let midpoint = Tag(bookId: bookId, label: "midpoint", category: .pacingMarker)
        try await manager.addTag(redemption)
        try await manager.addTag(oak)
        try await manager.addTag(midpoint)

        // 3 chapter applications for `redemption`.
        for _ in 0..<3 {
            try await manager.apply(TagApplication(
                bookId: bookId,
                tagId: redemption.id,
                target: .chapter,
                targetId: UUID()
            ))
        }
        // 2 character applications for `oak`.
        for _ in 0..<2 {
            try await manager.apply(TagApplication(
                bookId: bookId,
                tagId: oak.id,
                target: .character,
                targetId: UUID()
            ))
        }
        // `midpoint` has zero applications (= must NOT appear in
        // the cloud per the spec — cloud = tags WITH
        // applications).

        let cloud = try await manager.tagCloud(bookId: bookId)
        #expect(cloud.count == 2)
        // Sorted by count descending: redemption first.
        #expect(cloud[0].tag.id == redemption.id)
        #expect(cloud[0].count == 3)
        #expect(cloud[1].tag.id == oak.id)
        #expect(cloud[1].count == 2)
        // `midpoint` has no applications — must be absent.
        #expect(cloud.allSatisfy { $0.tag.id != midpoint.id })
    }

    // MARK: - Test 5: filterByTag returns matching entity ids

    @Test("filterByTag returns the set of entity ids for the matching tag + target")
    func testFilterByTag_returnsMatchingEntityIds() async throws {
        let bookId = Self.sampleBookId()
        let (store, _) = try Self.makeBookStoreWithDir(for: bookId)
        let manager = TagManager(bookStore: store)

        let tag = Tag(bookId: bookId, label: "love-triangle", category: .trope)
        try await manager.addTag(tag)

        let chapterA = UUID()
        let chapterB = UUID()
        let characterC = UUID()

        // 2 chapter applications + 1 character application.
        try await manager.apply(TagApplication(
            bookId: bookId,
            tagId: tag.id,
            target: .chapter,
            targetId: chapterA
        ))
        try await manager.apply(TagApplication(
            bookId: bookId,
            tagId: tag.id,
            target: .chapter,
            targetId: chapterB
        ))
        try await manager.apply(TagApplication(
            bookId: bookId,
            tagId: tag.id,
            target: .character,
            targetId: characterC
        ))

        // Filter by tag + target = chapter: must return both
        // chapter ids, no character id, and de-duplicate when
        // the same id is applied twice.
        try await manager.apply(TagApplication(
            bookId: bookId,
            tagId: tag.id,
            target: .chapter,
            targetId: chapterA
        ))
        let chapterMatches = try await manager.filterByTag(
            bookId: bookId,
            tagId: tag.id,
            target: .chapter
        )
        #expect(chapterMatches.count == 2)
        #expect(chapterMatches.contains(chapterA))
        #expect(chapterMatches.contains(chapterB))
        #expect(!chapterMatches.contains(characterC))

        // Filter by tag + target = character: only the character
        // id.
        let characterMatches = try await manager.filterByTag(
            bookId: bookId,
            tagId: tag.id,
            target: .character
        )
        #expect(characterMatches == [characterC])

        // Filter by tag + a target with zero matches: empty.
        let sceneMatches = try await manager.filterByTag(
            bookId: bookId,
            tagId: tag.id,
            target: .scene
        )
        #expect(sceneMatches.isEmpty)
    }
}
