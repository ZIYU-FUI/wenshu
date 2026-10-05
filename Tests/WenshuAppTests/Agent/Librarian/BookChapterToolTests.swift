//
//  BookChapterToolTests.swift · Wenshu · v2.0 (2026-09-25)
//
//  Round-trip tests for BookChapterActor + BookChapterTool:
//    1. testCreateChapter_persistsBody
//    2. testReadChapter_returnsBodyAndMetadata
//    3. testUpdateChapter_replacesBodyAndMetadata
//    4. testDeleteChapter_removesBodyAndIndex
//    5. testListChapters_filtersByBookId
//    6. testFindChapter_resolvesByCaseInsensitiveTitle
//    7. testExecute_createAction_parsesAndCreates
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("BookChapterTool (v2.0)", .serialized)
struct BookChapterToolTests {


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
    // MARK: - Helpers

    private static func makeBookDirectory() throws -> URL {
        let tmpRoot = URL(fileURLWithPath: "/tmp/wenshu-v2-chapter-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)
        return tmpRoot
    }

    private static func makeActor() throws -> BookChapterActor {
        let dir = try makeBookDirectory()
        // wt/path-guard-v2-2026-09-25: set libraryPath to the
        // canonical /tmp (= resolves through /private/tmp symlink
        // so PathGuard's canonical-root comparison matches).
        ActiveLibrary.overrideForTesting = nil; ActiveLibrary.overrideForTesting = URL(fileURLWithPath: "/tmp").resolvingSymlinksInPath().path
        return BookChapterActor(
            bookDirectoryProvider: { dir },
            currentChatBookIDProvider: { nil }
        )
    }

    // MARK: - Test 1: create

    @Test func testCreateChapter_persistsBody() async throws {
        let actor = try Self.makeActor()
        defer { ActiveLibrary.overrideForTesting = nil }
        let bookId = UUID()
        let descriptor = try await actor.createChapter(
            bookId: bookId,
            title: "Chapter 1",
            bodyMarkdown: "# Chapter 1\n\nThe hero wakes.",
            summary: "Opening"
        )
        #expect(descriptor.bookId == bookId)
        #expect(descriptor.title == "Chapter 1")
        #expect(descriptor.summary == "Opening")

        let body = await actor.readBodyForTest(id: descriptor.id)
        #expect(body == "# Chapter 1\n\nThe hero wakes.")
    }

    // MARK: - Test 2: read

    @Test func testReadChapter_returnsBodyAndMetadata() async throws {
        let actor = try Self.makeActor()
        defer { ActiveLibrary.overrideForTesting = nil }
        let created = try await actor.createChapter(
            bookId: UUID(),
            title: "Chapter 2",
            bodyMarkdown: "# Chapter 2\n\nInciting incident."
        )
        let (chapter, body) = try await actor.readChapter(id: created.id)
        #expect(chapter.id == created.id)
        #expect(chapter.title == "Chapter 2")
        #expect(body == "# Chapter 2\n\nInciting incident.")
    }

    // MARK: - Test 3: update

    @Test func testUpdateChapter_replacesBodyAndMetadata() async throws {
        let actor = try Self.makeActor()
        defer { ActiveLibrary.overrideForTesting = nil }
        let created = try await actor.createChapter(
            bookId: UUID(),
            title: "Chapter 3",
            bodyMarkdown: "# Chapter 3\n\nFirst draft."
        )
        let updated = try await actor.updateChapter(
            id: created.id,
            title: "Chapter 3 (revised)",
            bodyMarkdown: "# Chapter 3 (revised)\n\nSecond draft.",
            summary: "Revised opener"
        )
        #expect(updated.title == "Chapter 3 (revised)")
        #expect(updated.summary == "Revised opener")

        let (_, body) = try await actor.readChapter(id: created.id)
        #expect(body == "# Chapter 3 (revised)\n\nSecond draft.")
    }

    // MARK: - Test 4: delete

    @Test func testDeleteChapter_removesBodyAndIndex() async throws {
        let actor = try Self.makeActor()
        defer { ActiveLibrary.overrideForTesting = nil }
        let created = try await actor.createChapter(
            bookId: UUID(),
            title: "Scrapped",
            bodyMarkdown: "# Scrapped"
        )
        try await actor.deleteChapter(id: created.id)

        await #expect(throws: BookChapterError.entryNotFound(id: created.id)) {
            try await actor.readChapter(id: created.id)
        }
    }

    // MARK: - Test 5: list

    @Test func testListChapters_filtersByBookId() async throws {
        let dir = try Self.makeBookDirectory()
        let actor = BookChapterActor(
            bookDirectoryProvider: { dir },
            currentChatBookIDProvider: { nil }
        )
        let bookA = UUID()
        let bookB = UUID()
        _ = try await actor.createChapter(bookId: bookA, title: "A1", bodyMarkdown: "a1")
        _ = try await actor.createChapter(bookId: bookA, title: "A2", bodyMarkdown: "a2")
        _ = try await actor.createChapter(bookId: bookB, title: "B1", bodyMarkdown: "b1")

        let aChapters = try await actor.listChapters(bookId: bookA)
        let bChapters = try await actor.listChapters(bookId: bookB)
        #expect(aChapters.count == 2)
        #expect(bChapters.count == 1)
        let aTitles = Set(aChapters.map(\.title))
        #expect(aTitles == ["A1", "A2"])
    }

    // MARK: - Test 6: find

    @Test func testFindChapter_resolvesByCaseInsensitiveTitle() async throws {
        let actor = try Self.makeActor()
        defer { ActiveLibrary.overrideForTesting = nil }
        let bookId = UUID()
        let created = try await actor.createChapter(
            bookId: bookId,
            title: "The Awakening",
            bodyMarkdown: "# The Awakening"
        )
        let found = try await actor.findChapter(bookId: bookId, title: "  the awakening  ")
        #expect(found?.id == created.id)

        let missing = try await actor.findChapter(bookId: bookId, title: "The Fall")
        #expect(missing == nil)
    }

    // MARK: - Test 7: LLM dispatcher

    @Test func testExecute_createAction_parsesAndCreates() async throws {
        let dir = try Self.makeBookDirectory()
        let bookId = UUID()
        let actor = BookChapterActor(
            bookDirectoryProvider: { dir },
            currentChatBookIDProvider: { bookId }
        )
        let tool = BookChapterTool(actor: actor)
        let input = """
        {"action":"create","book_id":"\(bookId.uuidString)","title":"Chapter 1","markdown":"# C1"}
        """
        let output = try await tool.execute(input: input)
        #expect(output.contains("\"ok\":true"))
        #expect(output.contains("\"action\":\"create\""))
        #expect(output.contains("\"title\":\"Chapter 1\""))
    }

    @Test func testExecute_crossBookWrite_rejectedByScopeGuard() async throws {
        let dir = try Self.makeBookDirectory()
        let chatBook = UUID()
        let requestedBook = UUID()
        let actor = BookChapterActor(
            bookDirectoryProvider: { dir },
            currentChatBookIDProvider: { chatBook }
        )
        let tool = BookChapterTool(actor: actor)
        let input = """
        {"action":"create","book_id":"\(requestedBook.uuidString)","title":"Forbidden","markdown":"# F"}
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
        let actor = BookChapterActor(
            bookDirectoryProvider: { dir },
            currentChatBookIDProvider: { nil }
        )
        let tool = BookChapterTool(actor: actor)
        let input = """
        {"action":"create","book_id":"\(requestedBook.uuidString)","title":"Forbidden","markdown":"# F"}
        """
        let output = try await tool.execute(input: input)
        #expect(output.contains("\"ok\":false"))
        #expect(output.contains("\"error_kind\":\"book_scope_violation\""))
        #expect(output.contains("not bound to any book"))
    }

    // MARK: - Test 10 (v2.2 silent dedup): duplicate title falls back to update

    @Test func testCreate_duplicateTitle_fallsBackToUpdatePreservingId() async throws {
        let dir = try Self.makeBookDirectory()
        let actor = BookChapterActor(
            bookDirectoryProvider: { dir },
            currentChatBookIDProvider: { nil }
        )
        let bookId = UUID()
        let first = try await actor.createChapter(
            bookId: bookId,
            title: "Chapter 1",
            bodyMarkdown: "# Chapter 1 v1\n\nOpening scene."
        )
        let body1 = await actor.readBodyForTest(id: first.id)
        #expect(body1 == "# Chapter 1 v1\n\nOpening scene.")

        // Re-create with the SAME title in the SAME book: silent
        // dedup reuses the existing id + body gets replaced.
        let second = try await actor.createChapter(
            bookId: bookId,
            title: "Chapter 1",
            bodyMarkdown: "# Chapter 1 v2\n\nOpening scene, rewritten."
        )
        #expect(second.id == first.id)
        let body2 = await actor.readBodyForTest(id: second.id)
        #expect(body2 == "# Chapter 1 v2\n\nOpening scene, rewritten.")
        let all = try await actor.listChapters(bookId: bookId)
        #expect(all.count == 1)
        #expect(all.first?.id == first.id)
    }

    // MARK: - Test 11 (v2.2 silent dedup): different title still creates

    @Test func testCreate_uniqueTitle_createsNewChapter() async throws {
        let actor = try Self.makeActor()
        defer { ActiveLibrary.overrideForTesting = nil }
        let bookId = UUID()
        let first = try await actor.createChapter(
            bookId: bookId,
            title: "Chapter 1",
            bodyMarkdown: "# Chapter 1"
        )
        let second = try await actor.createChapter(
            bookId: bookId,
            title: "Chapter 2",
            bodyMarkdown: "# Chapter 2"
        )
        #expect(first.id != second.id)
        let all = try await actor.listChapters(bookId: bookId)
        #expect(all.count == 2)
    }
}