//
//  FileSystemEntityStoreTests.swift · Wenshu · v2.3 (2026-09-25)
//
//  Round-trip tests for FileSystemEntityStore.
//
//  Verifies:
//  - saveEntity creates the .md body + appends to the index.
//  - replaceEntity overwrites the .md + updates the index row.
//  - deleteEntity removes both the .md and the index row.
//  - loadEntities returns [] when no index exists.
//  - loadEntities forgives corrupt JSON (returns [], no throw).
//  - loadEntityBody / entityExists match on-disk reality.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("FileSystemEntityStore (v2.3)")
@MainActor
struct FileSystemEntityStoreTests {

    /// Make a unique temp book directory for each test.
    static func makeBookDirectory() throws -> URL {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-test-\(UUID().uuidString)",
                                    isDirectory: true)
        try FileManager.default.createDirectory(
            at: tmp,
            withIntermediateDirectories: true
        )
        return tmp
    }

    static func makeDescriptor(
        bookID: BookID = BookID.newID(),
        kind: EntityKind = .person,
        name: String = "Lin Fan"
    ) -> EntityDescriptor {
        EntityDescriptor(
            id: EntityID.newID(),
            bookID: bookID,
            kind: kind,
            name: name
        )
    }

    @Test func loadEmptyReturnsEmpty() throws {
        let dir = try Self.makeBookDirectory()
        let store = FileSystemEntityStore(bookDirectory: dir)
        let entities = try store.loadEntities()
        #expect(entities.isEmpty)
    }

    @Test func saveEntity_persistsBodyAndIndex() throws {
        let dir = try Self.makeBookDirectory()
        let store = FileSystemEntityStore(bookDirectory: dir)
        let entity = Self.makeDescriptor(name: "Test Lin Fan")
        let body = "# Test Lin Fan\n\nBody content."

        try store.saveEntity(entity, bodyMarkdown: body)

        // Index has the entity.
        let loaded = try store.loadEntities()
        #expect(loaded.count == 1)
        #expect(loaded.first?.id == entity.id)
        #expect(loaded.first?.name == "Test Lin Fan")

        // Body is on disk.
        #expect(store.entityExists(id: entity.id))
        let loadedBody = store.loadEntityBody(id: entity.id)
        #expect(loadedBody == body)
    }

    @Test func saveEntity_throwsOnDuplicate() throws {
        let dir = try Self.makeBookDirectory()
        let store = FileSystemEntityStore(bookDirectory: dir)
        let entity = Self.makeDescriptor()
        try store.saveEntity(entity, bodyMarkdown: "v1")

        #expect(throws: EntityStoreError.self) {
            try store.saveEntity(entity, bodyMarkdown: "v2")
        }
    }

    @Test func replaceEntity_overwritesBodyAndIndex() throws {
        let dir = try Self.makeBookDirectory()
        let store = FileSystemEntityStore(bookDirectory: dir)
        let entity = Self.makeDescriptor(name: "Original")
        try store.saveEntity(entity, bodyMarkdown: "v1")

        let updated = EntityDescriptor(
            id: entity.id,
            bookID: entity.bookID,
            kind: entity.kind,
            name: "Renamed",
            aliases: entity.aliases,
            tags: entity.tags,
            description: entity.description,
            attributes: entity.attributes,
            kindSpecific: entity.kindSpecific,
            bodyExcerpt: entity.bodyExcerpt,
            createdAt: entity.createdAt,
            updatedAt: Date()
        )
        try store.replaceEntity(updated, bodyMarkdown: "v2")

        let loaded = try store.loadEntities()
        #expect(loaded.count == 1)
        #expect(loaded.first?.name == "Renamed")
        let body = store.loadEntityBody(id: entity.id)
        #expect(body == "v2")
    }

    @Test func replaceEntity_throwsWhenMissing() throws {
        let dir = try Self.makeBookDirectory()
        let store = FileSystemEntityStore(bookDirectory: dir)
        let entity = Self.makeDescriptor()
        #expect(throws: EntityStoreError.self) {
            try store.replaceEntity(entity, bodyMarkdown: "x")
        }
    }

    @Test func deleteEntity_removesBodyAndIndexRow() throws {
        let dir = try Self.makeBookDirectory()
        let store = FileSystemEntityStore(bookDirectory: dir)
        let entity = Self.makeDescriptor()
        try store.saveEntity(entity, bodyMarkdown: "v1")
        #expect(store.entityExists(id: entity.id))

        try store.deleteEntity(id: entity.id)
        #expect(!store.entityExists(id: entity.id))
        let loaded = try store.loadEntities()
        #expect(loaded.isEmpty)
    }

    @Test func deleteEntity_isIdempotent() throws {
        let dir = try Self.makeBookDirectory()
        let store = FileSystemEntityStore(bookDirectory: dir)
        let entity = Self.makeDescriptor()
        try store.saveEntity(entity, bodyMarkdown: "v1")
        try store.deleteEntity(id: entity.id)
        // Second delete = no-op, no throw.
        try store.deleteEntity(id: entity.id)
    }

    @Test func loadEntities_forgivesCorruptIndex() throws {
        let dir = try Self.makeBookDirectory()
        // Pre-create the entities dir + write garbage to entities.json.
        try FileManager.default.createDirectory(
            at: dir.appendingPathComponent("entities", isDirectory: true),
            withIntermediateDirectories: true
        )
        let indexURL = dir.appendingPathComponent("entities.json")
        try "{ this is not valid json".data(using: .utf8)!.write(to: indexURL)

        let store = FileSystemEntityStore(bookDirectory: dir)
        let loaded = try store.loadEntities()
        #expect(loaded.isEmpty)
    }

    @Test func loadEntityBody_returnsNilForMissing() throws {
        let dir = try Self.makeBookDirectory()
        let store = FileSystemEntityStore(bookDirectory: dir)
        let body = store.loadEntityBody(id: EntityID.newID())
        #expect(body == nil)
    }


}