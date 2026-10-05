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
//  ActiveLibrary.overrideForTesting is a `@TaskLocal` (= Apple
//  HIG canonical pattern for test seams). Tests wrap their body
//  in `ActiveLibrary.$overrideForTesting.withValue(...) { ... }`
//  via the `withLibraryRoot` helper (= per-task scope; = no
//  cross-suite pollution; = no init() reset needed).
//

import Testing
import Foundation
@testable import WenshuApp

@MainActor
@Suite("BookChapterTool (v2.0)", .serialized)
struct BookChapterToolTests {

    // MARK: - Helpers

    private static func makeBookDirectory() throws -> URL {
        let tmpRoot = URL(fileURLWithPath: "/tmp/wenshu-v2-chapter-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)
        return tmpRoot
    }

    /// Canonical library root for these tests (= /tmp, resolved
    /// through /private/tmp symlink so PathGuard's canonical-root
    /// comparison matches).
    private static let libraryRoot = URL(fileURLWithPath: "/tmp").resolvingSymlinksInPath().path

    private static func makeActor() throws -> BookChapterActor {
        let dir = try makeBookDirectory()
        return BookChapterActor(
            bookDirectoryProvider: { dir },
            currentChatBookIDProvider: { nil }
        )
    }

    /// Run `body` with `ActiveLibrary.overrideForTesting` bound to
    /// the canonical /tmp library root (= Apple HIG canonical
    /// TaskLocal pattern; = no cross-suite pollution).
    private func withLibraryRoot<R>(_ body: () async throws -> R) async rethrows -> R {
        try await ActiveLibrary.$overrideForTesting.withValue(Self.libraryRoot, operation: body)
    }

    // MARK: - Test 1: create

    @Test func testCreateChapter_persistsBody() async throws {
        try await withLibraryRoot {
            let actor = try Self.makeActor()
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
    }

    // MARK: - Test 2: read

    @Test func testReadChapter_returnsBodyAndMetadata() async throws {
        try await withLibraryRoot {
            let actor = try Self.makeActor()
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
    }

    // MARK: - Test 3: update

    @Test func testUpdateChapter_replacesBodyAndMetadata() async throws {
        try await withLibraryRoot {
            let actor = try Self.makeActor()
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
    }

    // MARK: - Test 4: delete

    @Test func testDeleteChapter_removesBodyAndIndex() async throws {
        try await withLibraryRoot {
            let actor = try Self.makeActor()
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
    }

    // MARK: - Test 5: list

    @Test func testListChapters_filtersByBookId() async throws {
        try await withLibraryRoot {
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
    }

    // MARK: - Test 6: find

    @Test func testFindChapter_resolvesByCaseInsensitiveTitle() async throws {
        try await withLibraryRoot {
            let actor = try Self.makeActor()
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
    }

    // MARK: - Test 7: LLM dispatcher

    @Test func testExecute_createAction_parsesAndCreates() async throws {
        try await withLibraryRoot {
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
    }

    @Test func testExecute_crossBookWrite_rejectedByScopeGuard() async throws {
        try await withLibraryRoot {
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
    }

    @Test func testExecute_noChatBook_rejectedByScopeGuard() async throws {
        try await withLibraryRoot {
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
    }

    // MARK: - Test 10 (v2.2 silent dedup): duplicate title falls back to update

    @Test func testCreate_duplicateTitle_fallsBackToUpdatePreservingId() async throws {
        try await withLibraryRoot {
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
    }

    // MARK: - Test 11 (v2.2 silent dedup): different title still creates

    @Test func testCreate_uniqueTitle_createsNewChapter() async throws {
        try await withLibraryRoot {
            let actor = try Self.makeActor()
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
}
