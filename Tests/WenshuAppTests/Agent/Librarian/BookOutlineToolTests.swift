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

@Suite("BookOutlineTool (v2.0)")
struct BookOutlineToolTests {

    private static func makeOutlineStore() throws -> FileSystemOutlineStore {
        let tmpRoot = URL(fileURLWithPath: "/tmp/wenshu-v2-outline-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)
        return FileSystemOutlineStore(bookDirectory: tmpRoot)
    }

    private static func makeActor() throws -> BookOutlineActor {
        try BookOutlineActor(outlineStore: makeOutlineStore())
    }

    @Test func testCreateOutline_persistsBody() async throws {
        let actor = try Self.makeActor()
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
        let store = try Self.makeOutlineStore()
        let actor = BookOutlineActor(outlineStore: store)
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
        let store = try Self.makeOutlineStore()
        let bookId = UUID()
        let actor = BookOutlineActor(
            outlineStore: store,
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
        let store = try Self.makeOutlineStore()
        let chatBook = UUID()
        let requestedBook = UUID()
        let actor = BookOutlineActor(
            outlineStore: store,
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
        let store = try Self.makeOutlineStore()
        let requestedBook = UUID()
        let actor = BookOutlineActor(
            outlineStore: store,
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
}