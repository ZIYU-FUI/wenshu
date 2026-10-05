//
//  BookOutlineToolTests.swift · Wenshu · v2.0 (2026-09-25)
//
//  Round-trip tests for BookOutlineActor + BookOutlineTool:
//    1. testCreateOutline_persistsBody
//    2. testReadOutline_returnsBodyAndMetadata
//    3. testUpdateOutline_replacesBodyAndMetadata
//    4. testDeleteOutline_removesBodyAndIndex
//    5. testListOutlines_filtersByBookIdAndSortsByOrder
//    6. testFindOutline_resolvesByCaseInsensitiveTitle
//    7. testExecute_createAction_parsesAndCreates
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("BookOutlineTool (v2.0)", .serialized)
struct BookOutlineToolTests {


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
    private static func makeBookDirectory() throws -> URL {
        let tmpRoot = URL(fileURLWithPath: "/tmp/wenshu-v2-outline-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)
        return tmpRoot
    }

    private static func makeActor() throws -> BookOutlineActor {
        let dir = try makeBookDirectory()
        // wt/path-guard-v2-2026-09-25: set libraryPath to the
        // canonical /tmp (= resolves through /private/tmp symlink
        // so PathGuard's canonical-root comparison matches).
        ActiveLibrary.overrideForTesting = nil; ActiveLibrary.overrideForTesting = URL(fileURLWithPath: "/tmp").resolvingSymlinksInPath().path
        return BookOutlineActor(
            bookDirectoryProvider: { dir },
            currentChatBookIDProvider: { nil }
        )
    }

    @Test func testCreateOutline_persistsBody() async throws {
        let actor = try Self.makeActor()
        defer { ActiveLibrary.overrideForTesting = nil }
        let bookId = UUID()
        let descriptor = try await actor.createOutline(
            bookId: bookId,
            title: "Volume 1",
            bodyMarkdown: "# Volume 1\n\nSetup.",
            summary: "Setup"
        )
        #expect(descriptor.bookId == bookId)
        #expect(descriptor.title == "Volume 1")
        #expect(descriptor.summary == "Setup")
        #expect(descriptor.parent == nil)
        #expect(descriptor.order == 0)

        let body = await actor.readBodyForTest(id: descriptor.id)
        #expect(body == "# Volume 1\n\nSetup.")
    }

    @Test func testReadOutline_returnsBodyAndMetadata() async throws {
        let actor = try Self.makeActor()
        defer { ActiveLibrary.overrideForTesting = nil }
        let created = try await actor.createOutline(
            bookId: UUID(),
            title: "Chapter 1",
            bodyMarkdown: "# Chapter 1"
        )
        let (outline, body) = try await actor.readOutline(id: created.id)
        #expect(outline.id == created.id)
        #expect(outline.title == "Chapter 1")
        #expect(body == "# Chapter 1")
    }

    @Test func testUpdateOutline_replacesBodyAndMetadata() async throws {
        let actor = try Self.makeActor()
        defer { ActiveLibrary.overrideForTesting = nil }
        let created = try await actor.createOutline(
            bookId: UUID(),
            title: "Chapter 2",
            bodyMarkdown: "# Chapter 2\n\nFirst draft.",
            order: 1
        )
        let updated = try await actor.updateOutline(
            id: created.id,
            title: "Chapter 2 (revised)",
            bodyMarkdown: "# Chapter 2 (revised)\n\nSecond draft.",
            order: 2
        )
        #expect(updated.title == "Chapter 2 (revised)")
        #expect(updated.order == 2)

        let (_, body) = try await actor.readOutline(id: created.id)
        #expect(body == "# Chapter 2 (revised)\n\nSecond draft.")
    }

    @Test func testDeleteOutline_removesBodyAndIndex() async throws {
        let actor = try Self.makeActor()
        defer { ActiveLibrary.overrideForTesting = nil }
        let created = try await actor.createOutline(
            bookId: UUID(),
            title: "Scrapped",
            bodyMarkdown: "# Scrapped"
        )
        try await actor.deleteOutline(id: created.id)

        await #expect(throws: BookOutlineError.entryNotFound(id: created.id)) {
            try await actor.readOutline(id: created.id)
        }
    }

    @Test func testListOutlines_filtersByBookIdAndSortsByOrder() async throws {
        let dir = try Self.makeBookDirectory()
        let actor = BookOutlineActor(
            bookDirectoryProvider: { dir },
            currentChatBookIDProvider: { nil }
        )
        let bookA = UUID()
        let bookB = UUID()
        _ = try await actor.createOutline(bookId: bookA, title: "A-3", bodyMarkdown: "a3", order: 3)
        _ = try await actor.createOutline(bookId: bookA, title: "A-1", bodyMarkdown: "a1", order: 1)
        _ = try await actor.createOutline(bookId: bookA, title: "A-2", bodyMarkdown: "a2", order: 2)
        _ = try await actor.createOutline(bookId: bookB, title: "B-1", bodyMarkdown: "b1", order: 1)

        let aOutlines = try await actor.listOutlines(bookId: bookA)
        let bOutlines = try await actor.listOutlines(bookId: bookB)
        #expect(aOutlines.count == 3)
        #expect(bOutlines.count == 1)
        #expect(aOutlines.map(\.title) == ["A-1", "A-2", "A-3"])
    }

    @Test func testFindOutline_resolvesByCaseInsensitiveTitle() async throws {
        let actor = try Self.makeActor()
        defer { ActiveLibrary.overrideForTesting = nil }
        let bookId = UUID()
        let created = try await actor.createOutline(
            bookId: bookId,
            title: "First Arc",
            bodyMarkdown: "# Arc"
        )
        let found = try await actor.findOutline(bookId: bookId, title: "  first arc  ")
        #expect(found?.id == created.id)

        let missing = try await actor.findOutline(bookId: bookId, title: "Second Arc")
        #expect(missing == nil)
    }

    @Test func testExecute_createAction_parsesAndCreates() async throws {
        let dir = try Self.makeBookDirectory()
        let bookId = UUID()
        let actor = BookOutlineActor(
            bookDirectoryProvider: { dir },
            currentChatBookIDProvider: { bookId }
        )
        let tool = BookOutlineTool(actor: actor)
        let input = """
        {"action":"create","book_id":"\(bookId.uuidString)","title":"Volume 1","order":1,"markdown":"# V1"}
        """
        let output = try await tool.execute(input: input)
        #expect(output.contains("\"ok\":true"))
        #expect(output.contains("\"action\":\"create\""))
        #expect(output.contains("\"title\":\"Volume 1\""))
        #expect(output.contains("\"order\":1"))
    }

    @Test func testExecute_crossBookWrite_rejectedByScopeGuard() async throws {
        let dir = try Self.makeBookDirectory()
        let chatBook = UUID()
        let requestedBook = UUID()
        let actor = BookOutlineActor(
            bookDirectoryProvider: { dir },
            currentChatBookIDProvider: { chatBook }
        )
        let tool = BookOutlineTool(actor: actor)
        let input = """
        {"action":"create","book_id":"\(requestedBook.uuidString)","title":"Forbidden","order":1,"markdown":"# F"}
        """
        let output = try await tool.execute(input: input)
        #expect(output.contains("\"ok\":false"))
        #expect(output.contains("\"error_kind\":\"book_scope_violation\""))
        #expect(output.contains(chatBook.uuidString))
        #expect(output.contains(requestedBook.uuidString))
    }

    @Test func testExecute_noChatBook_rejectedByScopeGuard() async throws {
        let dir = try Self.makeBookDirectory()
        let requestedBook = UUID()
        let actor = BookOutlineActor(
            bookDirectoryProvider: { dir },
            currentChatBookIDProvider: { nil }
        )
        let tool = BookOutlineTool(actor: actor)
        let input = """
        {"action":"create","book_id":"\(requestedBook.uuidString)","title":"Forbidden","order":1,"markdown":"# F"}
        """
        let output = try await tool.execute(input: input)
        #expect(output.contains("\"ok\":false"))
        #expect(output.contains("\"error_kind\":\"book_scope_violation\""))
        #expect(output.contains("not bound to any book"))
    }

    // MARK: - Test 10 (v2.2 silent dedup): duplicate title falls back to update

    @Test func testCreate_duplicateTitle_fallsBackToUpdatePreservingId() async throws {
        let dir = try Self.makeBookDirectory()
        let actor = BookOutlineActor(
            bookDirectoryProvider: { dir },
            currentChatBookIDProvider: { nil }
        )
        let bookId = UUID()
        let first = try await actor.createOutline(
            bookId: bookId,
            title: "Volume 1",
            bodyMarkdown: "# Volume 1 v1\n\nOpens with the protagonist's exile."
        )
        let body1 = await actor.readBodyForTest(id: first.id)
        #expect(body1 == "# Volume 1 v1\n\nOpens with the protagonist's exile.")

        // Re-create with the SAME title in the SAME book: silent
        // dedup reuses the existing id + body gets replaced.
        let second = try await actor.createOutline(
            bookId: bookId,
            title: "Volume 1",
            bodyMarkdown: "# Volume 1 v2\n\nOpens with a dream sequence."
        )
        #expect(second.id == first.id)
        let body2 = await actor.readBodyForTest(id: second.id)
        #expect(body2 == "# Volume 1 v2\n\nOpens with a dream sequence.")
        let all = try await actor.listOutlines(bookId: bookId)
        #expect(all.count == 1)
        #expect(all.first?.id == first.id)
    }

    // MARK: - Test 11 (v2.2 silent dedup): different title still creates

    @Test func testCreate_uniqueTitle_createsNewOutline() async throws {
        let actor = try Self.makeActor()
        defer { ActiveLibrary.overrideForTesting = nil }
        let bookId = UUID()
        let first = try await actor.createOutline(
            bookId: bookId,
            title: "Volume 1",
            bodyMarkdown: "# Volume 1"
        )
        let second = try await actor.createOutline(
            bookId: bookId,
            title: "Volume 2",
            bodyMarkdown: "# Volume 2"
        )
        #expect(first.id != second.id)
        let all = try await actor.listOutlines(bookId: bookId)
        #expect(all.count == 2)
    }
}