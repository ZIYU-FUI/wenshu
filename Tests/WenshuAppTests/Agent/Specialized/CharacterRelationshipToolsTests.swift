//
//  CharacterRelationshipToolsTests.swift · Wenshu · P1 ticket #12 (PORT-SPECIALIZED-007, 2026-09-04)
//
//  6 round-trip tests for CharacterRelationshipTracker actor
//  (the Swift port of hermes's
//  `agent/specialized/character_relationships.py`):
//
//    1. testAddRelationship_persistsToBookSidecar
//    2. testUpdateRelationship_updatesKind
//    3. testRemoveRelationship_removesFromSidecar
//    4. testListRelationships_filtersByKind
//    5. testInconsistencies_detectsConflictingKinds
//    6. testGraph_buildsNodesAndEdges
//
//  Test isolation: each test creates a fresh /tmp root +
//  shelvesRoot + a per-book subdirectory that mirrors the
//  production walk (`<shelvesRoot>/<shelf>/books/<id>/`).
//  Caller-side teardown is not required (= the directory is
//  /tmp + unique uuid; macOS auto-cleans /tmp).
//
//  Test pattern mirrors LongFormGuardrailsTests (= uses the real
//  LibraryStores struct + FileSystemReferenceStore; no stubs).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("CharacterRelationshipTracker (PORT-SPECIALIZED-007)")
struct CharacterRelationshipToolsTests {

    // MARK: - Shared helpers

    /// Build a tiny BookStore rooted in a unique /tmp directory.
    private static func makeBookStore() throws -> (BookStore, LibraryStores) {
        let tmpRoot = URL(fileURLWithPath: "/tmp/wenshu-p1-12-\(UUID().uuidString)", isDirectory: true)
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

    @Test("add persists a relationship to the per-book sidecar")
    func testAddRelationship_persistsToBookSidecar() async throws {
        let bookId = Self.sampleBookId()
        let (store, dir) = try Self.makeBookStoreWithDir(for: bookId)
        let tracker = CharacterRelationshipTracker(bookStore: store)

        let a = UUID(); let b = UUID()
        let row = CharacterRelationship(
            bookId: bookId,
            fromCharacterId: a,
            toCharacterId: b,
            kind: .ally,
            description: "old comrades from the front"
        )
        try await tracker.add(row)

        // Reload via a fresh actor (= proves the write actually
        // hit disk + was re-read on cold cache).
        let reloaded = CharacterRelationshipTracker(bookStore: store)
        let listed = try await reloaded.list(bookId: bookId)
        #expect(listed.count == 1)
        let saved = listed.first
        #expect(saved?.id == row.id)
        #expect(saved?.kind == .ally)
        #expect(saved?.fromCharacterId == a)
        #expect(saved?.toCharacterId == b)

        // Sidecar file must exist on disk (= the actor wrote it).
        let sidecarURL = dir.appendingPathComponent("character-relationships.json")
        #expect(FileManager.default.fileExists(atPath: sidecarURL.path))
    }

    // MARK: - Test 2: update changes the kind

    @Test("update replaces an existing relationship's kind")
    func testUpdateRelationship_updatesKind() async throws {
        let bookId = Self.sampleBookId()
        let (store, _) = try Self.makeBookStoreWithDir(for: bookId)
        let tracker = CharacterRelationshipTracker(bookStore: store)

        let a = UUID(); let b = UUID()
        let original = CharacterRelationship(
            bookId: bookId,
            fromCharacterId: a,
            toCharacterId: b,
            kind: .ally,
            description: "started as comrades"
        )
        try await tracker.add(original)

        // Mutate the kind + description, keep the id stable.
        let updated = CharacterRelationship(
            id: original.id,
            bookId: bookId,
            fromCharacterId: a,
            toCharacterId: b,
            kind: .enemy,
            description: "betrayal in chapter 4"
        )
        try await tracker.update(updated)

        let listed = try await tracker.list(bookId: bookId)
        let saved = listed.first { $0.id == original.id }
        #expect(saved?.kind == .enemy)
        #expect(saved?.description == "betrayal in chapter 4")
    }

    // MARK: - Test 3: remove clears the sidecar entry

    @Test("remove deletes the relationship from the sidecar")
    func testRemoveRelationship_removesFromSidecar() async throws {
        let bookId = Self.sampleBookId()
        let (store, _) = try Self.makeBookStoreWithDir(for: bookId)
        let tracker = CharacterRelationshipTracker(bookStore: store)

        let row = CharacterRelationship(
            bookId: bookId,
            fromCharacterId: UUID(),
            toCharacterId: UUID(),
            kind: .rival
        )
        try await tracker.add(row)
        try await tracker.remove(id: row.id, from: bookId)

        let listed = try await tracker.list(bookId: bookId)
        #expect(listed.isEmpty)
    }

    // MARK: - Test 4: list filters by kind

    @Test("list filters relationships by kind")
    func testListRelationships_filtersByKind() async throws {
        let bookId = Self.sampleBookId()
        let (store, _) = try Self.makeBookStoreWithDir(for: bookId)
        let tracker = CharacterRelationshipTracker(bookStore: store)

        try await tracker.add(CharacterRelationship(
            bookId: bookId,
            fromCharacterId: UUID(),
            toCharacterId: UUID(),
            kind: .ally
        ))
        try await tracker.add(CharacterRelationship(
            bookId: bookId,
            fromCharacterId: UUID(),
            toCharacterId: UUID(),
            kind: .enemy
        ))
        try await tracker.add(CharacterRelationship(
            bookId: bookId,
            fromCharacterId: UUID(),
            toCharacterId: UUID(),
            kind: .mentor
        ))

        let alliesOnly = try await tracker.list(bookId: bookId, kind: .ally)
        #expect(alliesOnly.count == 1)
        #expect(alliesOnly.first?.kind == .ally)

        let mentorsOnly = try await tracker.list(bookId: bookId, kind: .mentor)
        #expect(mentorsOnly.count == 1)
        #expect(mentorsOnly.first?.kind == .mentor)

        let all = try await tracker.list(bookId: bookId)
        #expect(all.count == 3)

        // Filter by character (= matches either side of the edge).
        let targetId = UUID()
        try await tracker.add(CharacterRelationship(
            bookId: bookId,
            fromCharacterId: targetId,
            toCharacterId: UUID(),
            kind: .family
        ))
        let forCharacter = try await tracker.list(bookId: bookId, characterId: targetId)
        #expect(forCharacter.count == 1)
        #expect(forCharacter.first?.kind == .family)
    }

    // MARK: - Test 5: inconsistencies detects conflicting kinds

    @Test("inconsistencies returns one row per pair with conflicting kinds")
    func testInconsistencies_detectsConflictingKinds() async throws {
        let bookId = Self.sampleBookId()
        let (store, _) = try Self.makeBookStoreWithDir(for: bookId)
        let tracker = CharacterRelationshipTracker(bookStore: store)

        let a = UUID(); let b = UUID()

        // Two relationships between the same pair with
        // conflicting kinds (= the canonical inconsistency case).
        try await tracker.add(CharacterRelationship(
            bookId: bookId,
            fromCharacterId: a,
            toCharacterId: b,
            kind: .ally
        ))
        try await tracker.add(CharacterRelationship(
            bookId: bookId,
            fromCharacterId: a,
            toCharacterId: b,
            kind: .enemy
        ))

        // A consistent pair (one kind only) = NOT flagged.
        let c = UUID(); let d = UUID()
        try await tracker.add(CharacterRelationship(
            bookId: bookId,
            fromCharacterId: c,
            toCharacterId: d,
            kind: .family
        ))

        let issues = try await tracker.inconsistencies(bookId: bookId)
        #expect(issues.count == 1)
        let issue = issues.first
        #expect(issue != nil)
        #expect(issue?.conflictingKinds.contains(.ally) == true)
        #expect(issue?.conflictingKinds.contains(.enemy) == true)
        #expect(issue?.conflictingKinds.count == 2)
    }

    // MARK: - Test 6: graph builds nodes and edges

    @Test("graph builds nodes from characters and edges from relationships")
    func testGraph_buildsNodesAndEdges() async throws {
        let bookId = Self.sampleBookId()
        let (store, _) = try Self.makeBookStoreWithDir(for: bookId)
        let tracker = CharacterRelationshipTracker(bookStore: store)

        let a = UUID(); let b = UUID(); let c = UUID()
        try await tracker.add(CharacterRelationship(
            bookId: bookId,
            fromCharacterId: a,
            toCharacterId: b,
            kind: .ally
        ))
        try await tracker.add(CharacterRelationship(
            bookId: bookId,
            fromCharacterId: b,
            toCharacterId: c,
            kind: .mentor
        ))
        try await tracker.add(CharacterRelationship(
            bookId: bookId,
            fromCharacterId: a,
            toCharacterId: c,
            kind: .enemy
        ))

        let graph = try await tracker.graph(bookId: bookId)

        // Nodes = exactly the 3 characters that participate in
        // at least one edge.
        #expect(graph.characterIds.count == 3)
        #expect(graph.characterIds.contains(a))
        #expect(graph.characterIds.contains(b))
        #expect(graph.characterIds.contains(c))

        // Edges = exactly the 3 rows we added (= directed).
        #expect(graph.edges.count == 3)
        let edgeKinds = Set(graph.edges.map { $0.kind })
        #expect(edgeKinds.contains(.ally))
        #expect(edgeKinds.contains(.mentor))
        #expect(edgeKinds.contains(.enemy))

        // Weights are populated in 0..1 for every edge.
        for edge in graph.edges {
            #expect(edge.weight >= 0.0)
            #expect(edge.weight <= 1.0)
        }
    }
}