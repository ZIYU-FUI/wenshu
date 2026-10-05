//
//  BookEntityToolTests.swift · Wenshu · v2.3 (2026-09-25)
//
//  Tests for the v2.3 BookEntityActor + its CRUD surface.
//
//  Covers:
//  - createEntity creates the .md body + appends to the index.
//  - createEntity falls back to update when the same name already
//    exists in the same book (v2.2 silent dedup).
//  - readEntity returns descriptor + body for a known id;
//    throws .entryNotFound for an unknown id.
//  - updateEntity merges fields, preserves createdAt, replaces
//    body markdown.
//  - deleteEntity removes the body + index row; = idempotent.
//  - listEntities filters by bookId + optional kind.
//  - findEntity matches by case-insensitive name within a book
//    + kind.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("BookEntityActor (v2.3)", .serialized)
struct BookEntityActorTests {


    // Reset the global library override to nil at suite entry. Suite
    // bodies then re-set it to the canonical test root (e.g. `/tmp`
    // or the makeBookDirectory) inside individual test functions. The
    // nil reset prevents prior-suite leakage across the
    // .nonisolated(unsafe) override seam (= tests are .serialized but
    // the static var is process-wide; = without this reset a prior
    // suite's /Users/.../test.ws would still be bound when this suite
    // starts and PathGuard would reject paths from the new
    // makeBookDirectory).
    init() {
        ActiveLibrary.overrideForTesting = nil
    }
    /// Make a unique temp book directory for each test (= per
    /// the FileSystemEntityStoreTest pattern).
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

    /// Standard actor factory for the round-trip tests.
    static func makeActor(
        bookID: UUID? = nil,
        bookDirectory: URL? = nil
    ) -> BookEntityActor {
        let directory = bookDirectory
        let chatBookID = bookID
        // wt/path-guard-v2-2026-09-25: set libraryPath to the test's
        // tmp root (= FileManager.default.temporaryDirectory, which
        // = $TMPDIR on macOS) so the actor's resolveStore() PathGuard
        // assertion accepts the test's book directory. The tmp root
        // path is canonicalized via resolvingSymlinksInPath so
        // PathGuard's canonical-root comparison matches.
        let canonicalTmp = FileManager.default.temporaryDirectory
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .path
        ActiveLibrary.overrideForTesting = nil; ActiveLibrary.overrideForTesting = canonicalTmp
        return BookEntityActor(
            bookDirectoryProvider: { directory },
            currentChatBookIDProvider: { chatBookID }
        )
    }

    // MARK: - Create

    @Test func createEntity_persistsBodyAndIndex() async throws {
        let dir = try Self.makeBookDirectory()
        let actor = Self.makeActor(
            bookID: UUID(),
            bookDirectory: dir
        )
        let bookId = UUID()
        let desc = try await actor.createEntity(
            bookId: bookId,
            kind: "person",
            name: "Lin Fan",
            aliases: ["凡人"],
            tags: ["主角"],
            description: "Main character."
        )
        #expect(desc.name == "Lin Fan")
        #expect(desc.kind == .person)
        #expect(desc.aliases == ["凡人"])
        #expect(desc.tags == ["主角"])
        // Index has the entity.
        let listed = try await actor.listEntities(bookId: bookId)
        #expect(listed.count == 1)
        #expect(listed.first?.id == desc.id)
        // Body is on disk.
        let body = await actor.readBodyForTest(id: desc.id)
        #expect(body != nil)
        #expect(body!.contains("# Lin Fan"))
    }

    @Test func createEntity_emptyNameThrows() async throws {
        let actor = Self.makeActor()
        defer { ActiveLibrary.overrideForTesting = nil }
        await #expect(throws: BookEntityError.self) {
            try await actor.createEntity(
                bookId: UUID(),
                kind: "person",
                name: "   "
            )
        }
    }

    @Test func createEntity_unknownKindThrows() async throws {
        let actor = Self.makeActor()
        defer { ActiveLibrary.overrideForTesting = nil }
        await #expect(throws: BookEntityError.self) {
            try await actor.createEntity(
                bookId: UUID(),
                kind: "wizard",
                name: "Lin Fan"
            )
        }
    }

    @Test func createEntity_silentDedupByName() async throws {
        let dir = try Self.makeBookDirectory()
        let actor = Self.makeActor(bookDirectory: dir)
        defer { ActiveLibrary.overrideForTesting = nil }
        let bookId = UUID()

        // First create.
        let first = try await actor.createEntity(
            bookId: bookId,
            kind: "person",
            name: "Lin Fan",
            tags: ["main"],
            description: "Original description."
        )
        // Second create with same name (= silent dedup):
        // should fall back to update.
        let second = try await actor.createEntity(
            bookId: bookId,
            kind: "person",
            name: "Lin Fan",
            tags: ["main", "updated"],
            description: "Updated description."
        )
        #expect(second.id == first.id)
        // Same id, different content.
        let (readDesc, body) = try await actor.readEntity(id: first.id)
        #expect(readDesc.id == first.id)
        #expect(readDesc.description == "Updated description.")
        #expect(readDesc.tags.contains("updated"))
        #expect(body!.contains("Updated description"))
        // List shows exactly 1 entity.
        let listed = try await actor.listEntities(bookId: bookId)
        #expect(listed.count == 1)
    }

    // MARK: - Read

    @Test func readEntity_returnsDescriptorAndBody() async throws {
        let dir = try Self.makeBookDirectory()
        let actor = Self.makeActor(bookDirectory: dir)
        defer { ActiveLibrary.overrideForTesting = nil }
        let bookId = UUID()
        let desc = try await actor.createEntity(
            bookId: bookId, kind: "location", name: "Beijing",
            description: "Ming capital."
        )
        let (readDesc, body) = try await actor.readEntity(id: desc.id)
        #expect(readDesc.name == "Beijing")
        #expect(readDesc.description == "Ming capital.")
        #expect(body != nil)
        #expect(body!.contains("# Beijing"))
    }

    @Test func readEntity_throwsForUnknownId() async throws {
        let dir = try Self.makeBookDirectory()
        let actor = Self.makeActor(bookDirectory: dir)
        defer { ActiveLibrary.overrideForTesting = nil }
        await #expect(throws: BookEntityError.self) {
            _ = try await actor.readEntity(id: EntityID.newID())
        }
    }

    // MARK: - Update

    @Test func updateEntity_replacesBodyAndMergesFields() async throws {
        let dir = try Self.makeBookDirectory()
        let actor = Self.makeActor(bookDirectory: dir)
        defer { ActiveLibrary.overrideForTesting = nil }
        let bookId = UUID()
        let first = try await actor.createEntity(
            bookId: bookId, kind: "object", name: "Sword",
            description: "Old desc."
        )
        let updated = try await actor.updateEntity(
            id: first.id,
            bookId: bookId,
            kind: "object",
            name: "Sword",
            bodyMarkdown: "# Sword\n\nRewritten body.",
            description: "New desc."
        )
        #expect(updated.id == first.id)
        #expect(updated.description == "New desc.")
        // createdAt preserved (= exact equality modulo JSON round-trip
        // precision: ISO8601 with fractionalSeconds gives millisecond
        // precision, so the source Date's microsecond component is
        // truncated on round-trip; = compare at second precision).
        let createdAtSec = floor(updated.createdAt.timeIntervalSinceReferenceDate)
        let firstCreatedAtSec = floor(first.createdAt.timeIntervalSinceReferenceDate)
        #expect(createdAtSec == firstCreatedAtSec)
        // updatedAt bumped.
        #expect(updated.updatedAt > first.updatedAt)
        let (_, body) = try await actor.readEntity(id: first.id)
        #expect(body!.contains("Rewritten body."))
    }

    @Test func updateEntity_throwsForUnknownId() async throws {
        let dir = try Self.makeBookDirectory()
        let actor = Self.makeActor(bookDirectory: dir)
        defer { ActiveLibrary.overrideForTesting = nil }
        await #expect(throws: BookEntityError.self) {
            try await actor.updateEntity(
                id: EntityID.newID(),
                bookId: UUID(),
                kind: "person",
                name: "x"
            )
        }
    }

    // MARK: - Delete

    @Test func deleteEntity_removesBodyAndIndexRow() async throws {
        let dir = try Self.makeBookDirectory()
        let actor = Self.makeActor(bookDirectory: dir)
        defer { ActiveLibrary.overrideForTesting = nil }
        let bookId = UUID()
        let desc = try await actor.createEntity(
            bookId: bookId, kind: "ability", name: "Sword Technique"
        )
        try await actor.deleteEntity(id: desc.id)
        let listed = try await actor.listEntities(bookId: bookId)
        #expect(listed.isEmpty)
    }

    @Test func deleteEntity_isIdempotent() async throws {
        let dir = try Self.makeBookDirectory()
        let actor = Self.makeActor(bookDirectory: dir)
        defer { ActiveLibrary.overrideForTesting = nil }
        let bookId = UUID()
        let desc = try await actor.createEntity(
            bookId: bookId, kind: "ability", name: "X"
        )
        try await actor.deleteEntity(id: desc.id)
        // Second delete = no error.
        try await actor.deleteEntity(id: desc.id)
    }

    // MARK: - List

    @Test func listEntities_filtersByBookId() async throws {
        let dir = try Self.makeBookDirectory()
        let actor = Self.makeActor(bookDirectory: dir)
        defer { ActiveLibrary.overrideForTesting = nil }
        let bookA = UUID()
        let bookB = UUID()
        _ = try await actor.createEntity(bookId: bookA, kind: "person", name: "A1")
        _ = try await actor.createEntity(bookId: bookA, kind: "person", name: "A2")
        _ = try await actor.createEntity(bookId: bookB, kind: "person", name: "B1")

        let aListed = try await actor.listEntities(bookId: bookA)
        let bListed = try await actor.listEntities(bookId: bookB)
        #expect(aListed.count == 2)
        #expect(bListed.count == 1)
    }

    @Test func listEntities_filtersByKind() async throws {
        let dir = try Self.makeBookDirectory()
        let actor = Self.makeActor(bookDirectory: dir)
        defer { ActiveLibrary.overrideForTesting = nil }
        let bookId = UUID()
        _ = try await actor.createEntity(bookId: bookId, kind: "person", name: "Lin Fan")
        _ = try await actor.createEntity(bookId: bookId, kind: "location", name: "Beijing")
        _ = try await actor.createEntity(bookId: bookId, kind: "object", name: "Sword")

        let people = try await actor.listEntities(bookId: bookId, kind: .person)
        let locations = try await actor.listEntities(bookId: bookId, kind: .location)
        #expect(people.count == 1)
        #expect(people.first?.name == "Lin Fan")
        #expect(locations.count == 1)
        #expect(locations.first?.name == "Beijing")
    }

    // MARK: - Find

    @Test func findEntity_matchesByCaseInsensitiveName() async throws {
        let dir = try Self.makeBookDirectory()
        let actor = Self.makeActor(bookDirectory: dir)
        defer { ActiveLibrary.overrideForTesting = nil }
        let bookId = UUID()
        let desc = try await actor.createEntity(
            bookId: bookId, kind: "person", name: "Lin Fan"
        )
        let found = try await actor.findEntity(
            bookId: bookId, kind: .person, name: "lin fan"
        )
        #expect(found?.id == desc.id)
    }

    @Test func findEntity_returnsNilForDifferentKind() async throws {
        let dir = try Self.makeBookDirectory()
        let actor = Self.makeActor(bookDirectory: dir)
        defer { ActiveLibrary.overrideForTesting = nil }
        let bookId = UUID()
        _ = try await actor.createEntity(
            bookId: bookId, kind: "person", name: "Lin Fan"
        )
        // Same name but wrong kind.
        let found = try await actor.findEntity(
            bookId: bookId, kind: .location, name: "Lin Fan"
        )
        #expect(found == nil)
    }

    @Test func findEntity_returnsNilForDifferentBook() async throws {
        let dir = try Self.makeBookDirectory()
        let actor = Self.makeActor(bookDirectory: dir)
        defer { ActiveLibrary.overrideForTesting = nil }
        let bookA = UUID()
        let bookB = UUID()
        _ = try await actor.createEntity(bookId: bookA, kind: "person", name: "Lin Fan")
        let found = try await actor.findEntity(
            bookId: bookB, kind: .person, name: "Lin Fan"
        )
        #expect(found == nil)
    }
}