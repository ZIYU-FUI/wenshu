//
//  EntityMigrationTests.swift · Wenshu · v2.3 (2026-09-25)
//
//  Tests for the v2.0/v2.2 → v2.3 entity migration helper.
//
//  Verifies:
//  - migrateFromLegacyIfNeeded is idempotent (= second call =
//    no-op with wasAlreadyMigrated = true).
//  - Legacy character/ folder gets imported as kind = .person
//    entities under entities/.
//  - Legacy world/ folder gets imported as kind = .location
//    entities under entities/.
//  - Missing folders = no-op (= no error, no rows imported).
//  - Body markdown from .md files is preserved.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("EntityMigration (v2.3)")
@MainActor
struct EntityMigrationTests {

    static func makeBookDirectory() throws -> URL {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-mig-\(UUID().uuidString)",
                                    isDirectory: true)
        try FileManager.default.createDirectory(
            at: tmp,
            withIntermediateDirectories: true
        )
        return tmp
    }

    /// Write a legacy character row + body to the book's
    /// `characters/` folder (= the v2.0 layout).
    static func writeLegacyCharacter(
        in bookDir: URL,
        id: UUID,
        name: String,
        summary: String = "",
        role: String = "other"
    ) throws {
        let charsDir = bookDir.appendingPathComponent("characters", isDirectory: true)
        try FileManager.default.createDirectory(at: charsDir, withIntermediateDirectories: true)
        let bodyURL = charsDir.appendingPathComponent("\(id.uuidString).md")
        try "# \(name)\n\n\(summary)\n".write(to: bodyURL, atomically: true, encoding: .utf8)
        let entry: [[String: Any]] = [[
            "id": id.uuidString,
            "bookId": UUID().uuidString,
            "name": name,
            "role": role,
            "summary": summary,
            "age": NSNull(),
            "arc": NSNull(),
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "updatedAt": ISO8601DateFormatter().string(from: Date())
        ]]
        let data = try JSONSerialization.data(withJSONObject: entry, options: [.prettyPrinted])
        try data.write(to: charsDir.appendingPathComponent("_index.json"))
    }

    /// Write a legacy world row + body to the book's `world/`
    /// folder (= the v2.0 layout).
    static func writeLegacyWorldEntry(
        in bookDir: URL,
        id: UUID,
        name: String,
        type: String = "geography",
        summary: String = ""
    ) throws {
        let worldDir = bookDir.appendingPathComponent("world", isDirectory: true)
        try FileManager.default.createDirectory(at: worldDir, withIntermediateDirectories: true)
        let bodyURL = worldDir.appendingPathComponent("\(id.uuidString).md")
        try "# \(name)\n\n\(summary)\n".write(to: bodyURL, atomically: true, encoding: .utf8)
        let entry: [[String: Any]] = [[
            "id": id.uuidString,
            "bookId": UUID().uuidString,
            "type": type,
            "name": name,
            "summary": summary,
            "characterRefIds": [],
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "updatedAt": ISO8601DateFormatter().string(from: Date())
        ]]
        let data = try JSONSerialization.data(withJSONObject: entry, options: [.prettyPrinted])
        try data.write(to: worldDir.appendingPathComponent("_index.json"))
    }

    // MARK: - Tests

    @Test func migrate_importsLegacyCharactersAsKindPerson() throws {
        let bookDir = try Self.makeBookDirectory()
        let charID = UUID()
        try Self.writeLegacyCharacter(
            in: bookDir,
            id: charID,
            name: "Lin Fan",
            summary: "Main character",
            role: "protagonist"
        )
        let result = try EntityMigration.migrateFromLegacyIfNeeded(bookDirectory: bookDir)
        #expect(result.wasAlreadyMigrated == false)
        #expect(result.charactersImported == 1)
        #expect(result.worldEntriesImported == 0)
        #expect(result.totalEntitiesAfter == 1)
        let store = FileSystemEntityStore(bookDirectory: bookDir)
        let entities = try store.loadEntities()
        #expect(entities.count == 1)
        #expect(entities.first?.kind == .person)
        #expect(entities.first?.name == "Lin Fan")
        #expect(entities.first?.id.rawValue == charID.uuidString)
        #expect(entities.first?.tags.contains("protagonist") == true)
    }

    @Test func migrate_importsLegacyWorldEntriesAsKindLocation() throws {
        let bookDir = try Self.makeBookDirectory()
        let entryID = UUID()
        try Self.writeLegacyWorldEntry(
            in: bookDir,
            id: entryID,
            name: "Beijing",
            type: "geography",
            summary: "Capital"
        )
        let result = try EntityMigration.migrateFromLegacyIfNeeded(bookDirectory: bookDir)
        #expect(result.worldEntriesImported == 1)
        #expect(result.charactersImported == 0)
        let store = FileSystemEntityStore(bookDirectory: bookDir)
        let entities = try store.loadEntities()
        #expect(entities.count == 1)
        #expect(entities.first?.kind == .location)
        #expect(entities.first?.name == "Beijing")
    }

    @Test func migrate_importsBothCharactersAndWorld() throws {
        let bookDir = try Self.makeBookDirectory()
        try Self.writeLegacyCharacter(
            in: bookDir, id: UUID(), name: "Lin Fan"
        )
        try Self.writeLegacyWorldEntry(
            in: bookDir, id: UUID(), name: "Beijing"
        )
        let result = try EntityMigration.migrateFromLegacyIfNeeded(bookDirectory: bookDir)
        #expect(result.charactersImported == 1)
        #expect(result.worldEntriesImported == 1)
        #expect(result.totalEntitiesAfter == 2)
    }

    @Test func migrate_isIdempotent() throws {
        let bookDir = try Self.makeBookDirectory()
        try Self.writeLegacyCharacter(in: bookDir, id: UUID(), name: "Lin Fan")
        let first = try EntityMigration.migrateFromLegacyIfNeeded(bookDirectory: bookDir)
        #expect(first.wasAlreadyMigrated == false)
        #expect(first.charactersImported == 1)
        let second = try EntityMigration.migrateFromLegacyIfNeeded(bookDirectory: bookDir)
        #expect(second.wasAlreadyMigrated == true)
        #expect(second.charactersImported == 0)
        #expect(second.worldEntriesImported == 0)
        // Total entities is unchanged (= no double-import).
        let store = FileSystemEntityStore(bookDirectory: bookDir)
        #expect(try store.loadEntities().count == 1)
    }

    @Test func migrate_noopWhenLegacyFoldersMissing() throws {
        let bookDir = try Self.makeBookDirectory()
        let result = try EntityMigration.migrateFromLegacyIfNeeded(bookDirectory: bookDir)
        #expect(result.charactersImported == 0)
        #expect(result.worldEntriesImported == 0)
        #expect(result.totalEntitiesAfter == 0)
        #expect(result.wasAlreadyMigrated == false)
    }

    @Test func migrate_preservesBodyMarkdown() throws {
        let bookDir = try Self.makeBookDirectory()
        let charID = UUID()
        try Self.writeLegacyCharacter(
            in: bookDir,
            id: charID,
            name: "Lin Fan",
            summary: "Main character"
        )
        _ = try EntityMigration.migrateFromLegacyIfNeeded(bookDirectory: bookDir)
        let store = FileSystemEntityStore(bookDirectory: bookDir)
        let body = store.loadEntityBody(id: EntityID(rawValue: charID.uuidString))
        #expect(body != nil)
        #expect(body!.contains("# Lin Fan"))
        #expect(body!.contains("Main character"))
    }
}