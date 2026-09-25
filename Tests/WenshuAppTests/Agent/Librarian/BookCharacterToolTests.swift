//
//  BookCharacterToolTests.swift · Wenshu · v2.0 (2026-09-25)
//
//  Round-trip tests for BookCharacterActor + BookCharacterTool:
//    1. testCreateCharacter_persistsBody
//    2. testReadCharacter_returnsBodyAndMetadata
//    3. testUpdateCharacter_replacesBodyAndMetadata
//    4. testDeleteCharacter_removesBodyAndIndex
//    5. testListCharacters_filtersByBookId
//    6. testFindCharacter_resolvesByCaseInsensitiveName
//    7. testExecute_createAction_parsesAndCreates
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("BookCharacterTool (v2.0)")
struct BookCharacterToolTests {

    // MARK: - Helpers

    private static func makeBookDirectory() throws -> URL {
        let tmpRoot = URL(fileURLWithPath: "/tmp/wenshu-v2-character-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)
        return tmpRoot
    }

    private static func makeActor() throws -> BookCharacterActor {
        let dir = try makeBookDirectory()
        return BookCharacterActor(
            bookDirectoryProvider: { dir },
            currentChatBookIDProvider: { nil }
        )
    }

    // MARK: - Test 1: create persists .md body

    @Test func testCreateCharacter_persistsBody() async throws {
        let actor = try Self.makeActor()
        let bookId = UUID()
        let descriptor = try await actor.createCharacter(
            bookId: bookId,
            name: "Wei Zhongxian",
            bodyMarkdown: "# Wei Zhongxian\n\nMing eunuch.",
            role: "antagonist",
            arc: "rises then falls"
        )
        #expect(descriptor.bookId == bookId)
        #expect(descriptor.name == "Wei Zhongxian")
        #expect(descriptor.role == "antagonist")
        #expect(descriptor.arc == "rises then falls")

        let body = await actor.readBodyForTest(id: descriptor.id)
        #expect(body == "# Wei Zhongxian\n\nMing eunuch.")
    }

    // MARK: - Test 2: read

    @Test func testReadCharacter_returnsBodyAndMetadata() async throws {
        let actor = try Self.makeActor()
        let created = try await actor.createCharacter(
            bookId: UUID(),
            name: "Yuan Chonghuan",
            bodyMarkdown: "# Yuan Chonghuan\n\nMing general."
        )
        let (character, body) = try await actor.readCharacter(id: created.id)
        #expect(character.id == created.id)
        #expect(character.name == "Yuan Chonghuan")
        #expect(body == "# Yuan Chonghuan\n\nMing general.")
    }

    // MARK: - Test 3: update

    @Test func testUpdateCharacter_replacesBodyAndMetadata() async throws {
        let actor = try Self.makeActor()
        let created = try await actor.createCharacter(
            bookId: UUID(),
            name: "Chen Su",
            bodyMarkdown: "# Chen Su\n\nInitial.",
            role: "supporting"
        )
        let updated = try await actor.updateCharacter(
            id: created.id,
            name: "Chen Su (revised)",
            bodyMarkdown: "# Chen Su (revised)\n\nRevised arc.",
            role: "protagonist",
            arc: "now main"
        )
        #expect(updated.name == "Chen Su (revised)")
        #expect(updated.role == "protagonist")
        #expect(updated.arc == "now main")

        let (_, body) = try await actor.readCharacter(id: created.id)
        #expect(body == "# Chen Su (revised)\n\nRevised arc.")
    }

    // MARK: - Test 4: delete

    @Test func testDeleteCharacter_removesBodyAndIndex() async throws {
        let actor = try Self.makeActor()
        let created = try await actor.createCharacter(
            bookId: UUID(),
            name: "Doomed",
            bodyMarkdown: "# Doomed"
        )
        try await actor.deleteCharacter(id: created.id)

        await #expect(throws: BookCharacterError.entryNotFound(id: created.id)) {
            try await actor.readCharacter(id: created.id)
        }
    }

    // MARK: - Test 5: list filters by bookId

    @Test func testListCharacters_filtersByBookId() async throws {
        let dir = try Self.makeBookDirectory()
        let actor = BookCharacterActor(
            bookDirectoryProvider: { dir },
            currentChatBookIDProvider: { nil }
        )
        let bookA = UUID()
        let bookB = UUID()
        _ = try await actor.createCharacter(bookId: bookA, name: "A1", bodyMarkdown: "a1")
        _ = try await actor.createCharacter(bookId: bookA, name: "A2", bodyMarkdown: "a2")
        _ = try await actor.createCharacter(bookId: bookB, name: "B1", bodyMarkdown: "b1")

        let aChars = try await actor.listCharacters(bookId: bookA)
        let bChars = try await actor.listCharacters(bookId: bookB)
        #expect(aChars.count == 2)
        #expect(bChars.count == 1)
        let aNames = Set(aChars.map(\.name))
        #expect(aNames == ["A1", "A2"])
    }

    // MARK: - Test 6: find

    @Test func testFindCharacter_resolvesByCaseInsensitiveName() async throws {
        let actor = try Self.makeActor()
        let bookId = UUID()
        let created = try await actor.createCharacter(
            bookId: bookId,
            name: "Sun Chongzhen",
            bodyMarkdown: "# Emperor"
        )
        let found = try await actor.findCharacter(bookId: bookId, name: "  sun chongzhen  ")
        #expect(found?.id == created.id)

        let missing = try await actor.findCharacter(bookId: bookId, name: "Nobody")
        #expect(missing == nil)
    }

    // MARK: - Test 7: LLM dispatcher

    @Test func testExecute_createAction_parsesAndCreates() async throws {
        let dir = try Self.makeBookDirectory()
        let bookId = UUID()
        let actor = BookCharacterActor(
            bookDirectoryProvider: { dir },
            currentChatBookIDProvider: { bookId }
        )
        let tool = BookCharacterTool(actor: actor)
        let input = """
        {"action":"create","book_id":"\(bookId.uuidString)","name":"Wei Zhongxian","role":"antagonist","markdown":"# Wei"}
        """
        let output = try await tool.execute(input: input)
        #expect(output.contains("\"ok\":true"))
        #expect(output.contains("\"action\":\"create\""))
        #expect(output.contains("\"name\":\"Wei Zhongxian\""))
        #expect(output.contains("\"role\":\"antagonist\""))
    }

    @Test func testExecute_crossBookWrite_rejectedByScopeGuard() async throws {
        let dir = try Self.makeBookDirectory()
        let chatBook = UUID()
        let requestedBook = UUID()
        let actor = BookCharacterActor(
            bookDirectoryProvider: { dir },
            currentChatBookIDProvider: { chatBook }
        )
        let tool = BookCharacterTool(actor: actor)
        let input = """
        {"action":"create","book_id":"\(requestedBook.uuidString)","name":"Forbidden","markdown":"# F"}
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
        let actor = BookCharacterActor(
            bookDirectoryProvider: { dir },
            currentChatBookIDProvider: { nil }
        )
        let tool = BookCharacterTool(actor: actor)
        let input = """
        {"action":"create","book_id":"\(requestedBook.uuidString)","name":"Forbidden","markdown":"# F"}
        """
        let output = try await tool.execute(input: input)
        #expect(output.contains("\"ok\":false"))
        #expect(output.contains("\"error_kind\":\"book_scope_violation\""))
        #expect(output.contains("not bound to any book"))
    }

    // MARK: - Test 10 (v2.2 silent dedup): duplicate name falls back to update

    @Test func testCreate_duplicateName_fallsBackToUpdatePreservingId() async throws {
        let dir = try Self.makeBookDirectory()
        let actor = BookCharacterActor(
            bookDirectoryProvider: { dir },
            currentChatBookIDProvider: { nil }
        )
        let bookId = UUID()
        let first = try await actor.createCharacter(
            bookId: bookId,
            name: "Lin Fan",
            bodyMarkdown: "# Lin Fan v1\n\nApprentice.",
            role: "antagonist",
            summary: "Original summary."
        )
        let body1 = await actor.readBodyForTest(id: first.id)
        #expect(body1 == "# Lin Fan v1\n\nApprentice.")

        // Re-create with the SAME name in the SAME book: silent
        // dedup reuses the existing id + body gets replaced.
        let second = try await actor.createCharacter(
            bookId: bookId,
            name: "Lin Fan",
            bodyMarkdown: "# Lin Fan v2\n\nConstable.",
            role: "protagonist",
            summary: "Updated summary."
        )
        #expect(second.id == first.id)
        let body2 = await actor.readBodyForTest(id: second.id)
        #expect(body2 == "# Lin Fan v2\n\nConstable.")
        let all = try await actor.listCharacters(bookId: bookId)
        #expect(all.count == 1)
        #expect(all.first?.id == first.id)
    }

    // MARK: - Test 11 (v2.2 silent dedup): different name still creates

    @Test func testCreate_uniqueName_createsNewCharacter() async throws {
        let actor = try Self.makeActor()
        let bookId = UUID()
        let first = try await actor.createCharacter(
            bookId: bookId,
            name: "Lin Fan",
            bodyMarkdown: "# Lin Fan"
        )
        let second = try await actor.createCharacter(
            bookId: bookId,
            name: "Wang Yuyan",
            bodyMarkdown: "# Wang Yuyan"
        )
        #expect(first.id != second.id)
        let all = try await actor.listCharacters(bookId: bookId)
        #expect(all.count == 2)
    }
}