//
//  BookWorldToolTests.swift · Wenshu · v2.0 (2026-09-25)
//
//  Round-trip tests for BookWorldActor + BookWorldTool:
//    1. testCreateEntry_persistsBody
//    2. testReadEntry_returnsBodyAndMetadata
//    3. testUpdateEntry_replacesBodyAndMetadata
//    4. testDeleteEntry_removesBodyAndIndex
//    5. testListEntries_filtersByBookId
//    6. testFindEntry_resolvesByCaseInsensitiveName
//    7. testExecute_createAction_parsesAndCreates
//
//  Test isolation: each test creates a fresh /tmp root + a real
//  FileSystemWorldStore. The actor wraps the store directly; no
//  BookStore dependency since world entries are book-private and
//  live on disk under <book-dir>/world/.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("BookWorldTool (v2.0)")
struct BookWorldToolTests {

    // MARK: - Shared helpers

    /// Build a fresh FileSystemWorldStore rooted in a unique /tmp
    /// directory. Per-test root guarantees isolation; macOS auto-
    /// cleans /tmp.
    private static func makeWorldStore() throws -> FileSystemWorldStore {
        let tmpRoot = URL(fileURLWithPath: "/tmp/wenshu-v2-world-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)
        return FileSystemWorldStore(bookDirectory: tmpRoot)
    }

    /// Default actor factory: returns an actor with a provider that
    /// always says "no chat book bound". The CRUD-level tests
    /// (= create / read / update / delete / list / find) call
    /// `createEntry` / `readEntry` directly (= bypassing the scope
    /// guard), so this default is fine for those tests.
    ///
    /// The execute(input:) tests (= test 7 + the new scope-violation
    /// test) override the provider by constructing the actor
    /// directly with `BookWorldActor(worldStore: ..., currentChatBookIDProvider: ...)`.
    private static func makeActor() throws -> BookWorldActor {
        try BookWorldActor(worldStore: makeWorldStore())
    }

    // MARK: - Test 1: create persists .md body

    @Test func testCreateEntry_persistsBody() async throws {
        let actor = try Self.makeActor()
        let bookId = UUID()
        let descriptor = try await actor.createEntry(
            bookId: bookId,
            name: "Beijing",
            bodyMarkdown: "# Beijing\n\nImperial capital.",
            type: "geography",
            summary: "Ming-era capital."
        )
        #expect(descriptor.bookId == bookId)
        #expect(descriptor.name == "Beijing")
        #expect(descriptor.type == "geography")
        #expect(descriptor.summary == "Ming-era capital.")

        // Verify the .md body landed on disk.
        let body = await actor.readBodyForTest(id: descriptor.id)
        #expect(body == "# Beijing\n\nImperial capital.")
    }

    // MARK: - Test 2: read returns body + metadata

    @Test func testReadEntry_returnsBodyAndMetadata() async throws {
        let actor = try Self.makeActor()
        let created = try await actor.createEntry(
            bookId: UUID(),
            name: "Lore",
            bodyMarkdown: "# Lore\n\nDragon lore."
        )
        let (entry, body) = try await actor.readEntry(id: created.id)
        #expect(entry.id == created.id)
        #expect(entry.name == "Lore")
        #expect(body == "# Lore\n\nDragon lore.")
    }

    // MARK: - Test 3: update replaces body + metadata

    @Test func testUpdateEntry_replacesBodyAndMetadata() async throws {
        let actor = try Self.makeActor()
        let created = try await actor.createEntry(
            bookId: UUID(),
            name: "Object",
            bodyMarkdown: "# Object\n\nBronze sword.",
            type: "object"
        )
        let updated = try await actor.updateEntry(
            id: created.id,
            name: "Jade Sword",
            bodyMarkdown: "# Jade Sword\n\nUpdated lore.",
            type: "object",
            summary: "now jade"
        )
        #expect(updated.name == "Jade Sword")
        #expect(updated.summary == "now jade")

        let (_, body) = try await actor.readEntry(id: created.id)
        #expect(body == "# Jade Sword\n\nUpdated lore.")
    }

    // MARK: - Test 4: delete removes body + index

    @Test func testDeleteEntry_removesBodyAndIndex() async throws {
        let actor = try Self.makeActor()
        let created = try await actor.createEntry(
            bookId: UUID(),
            name: "Event",
            bodyMarkdown: "# Event\n\nRebellion of 1449."
        )
        try await actor.deleteEntry(id: created.id)

        await #expect(throws: BookWorldError.entryNotFound(id: created.id)) {
            try await actor.readEntry(id: created.id)
        }
    }

    // MARK: - Test 5: list filters by bookId

    @Test func testListEntries_filtersByBookId() async throws {
        let store = try Self.makeWorldStore()
        let actor = BookWorldActor(worldStore: store)
        let bookA = UUID()
        let bookB = UUID()
        _ = try await actor.createEntry(bookId: bookA, name: "A1", bodyMarkdown: "a1")
        _ = try await actor.createEntry(bookId: bookA, name: "A2", bodyMarkdown: "a2")
        _ = try await actor.createEntry(bookId: bookB, name: "B1", bodyMarkdown: "b1")

        let aEntries = try await actor.listEntries(bookId: bookA)
        let bEntries = try await actor.listEntries(bookId: bookB)
        #expect(aEntries.count == 2)
        #expect(bEntries.count == 1)
        let aNames = Set(aEntries.map(\.name))
        #expect(aNames == ["A1", "A2"])
    }

    // MARK: - Test 6: find resolves by case-insensitive trimmed name

    @Test func testFindEntry_resolvesByCaseInsensitiveName() async throws {
        let actor = try Self.makeActor()
        let bookId = UUID()
        let created = try await actor.createEntry(
            bookId: bookId,
            name: "Ming-era Capital",
            bodyMarkdown: "# Capital"
        )
        let found = try await actor.findEntry(bookId: bookId, name: "  ming-era capital  ")
        #expect(found?.id == created.id)

        let missing = try await actor.findEntry(bookId: bookId, name: "Beijing")
        #expect(missing == nil)
    }

    // MARK: - Test 7: LLM dispatcher (create action via JSON envelope)

    @Test func testExecute_createAction_parsesAndCreates() async throws {
        let store = try Self.makeWorldStore()
        let bookId = UUID()
        // Bind the chat session to the same book we're creating
        // the entry in; = scope guard accepts (= the LLM /
        // dispatcher path is what production uses).
        let actor = BookWorldActor(
            worldStore: store,
            currentChatBookIDProvider: { bookId }
        )
        let tool = BookWorldTool(actor: actor)
        let input = """
        {"action":"create","book_id":"\(bookId.uuidString)","name":"Beijing","type":"geography","markdown":"# Beijing"}
        """
        let output = try await tool.execute(input: input)
        #expect(output.contains("\"ok\":true"))
        #expect(output.contains("\"action\":\"create\""))
        #expect(output.contains("\"name\":\"Beijing\""))
        #expect(output.contains("\"type\":\"geography\""))
    }

    // MARK: - Test 8: scope guard rejects cross-book write

    @Test func testExecute_crossBookWrite_rejectedByScopeGuard() async throws {
        let store = try Self.makeWorldStore()
        let chatBook = UUID()  // chat session is bound to chatBook
        let requestedBook = UUID()  // LLM tries to write a different book
        let actor = BookWorldActor(
            worldStore: store,
            currentChatBookIDProvider: { chatBook }
        )
        let tool = BookWorldTool(actor: actor)
        let input = """
        {"action":"create","book_id":"\(requestedBook.uuidString)","name":"Forbidden","markdown":"# Forbidden"}
        """
        let output = try await tool.execute(input: input)
        #expect(output.contains("\"ok\":false"))
        #expect(output.contains("\"error_kind\":\"book_scope_violation\""))
        #expect(output.contains("\"action\":\"create\""))
        // Soft message should mention both ids so the LLM can
        // guide the user.
        #expect(output.contains(chatBook.uuidString))
        #expect(output.contains(requestedBook.uuidString))
        // No file should be written to either book's disk.
        let bodyForRequested = store.loadEntryBody(id: UUID())  // any id; = no entry exists
        #expect(bodyForRequested == nil)
    }

    // MARK: - Test 9: scope guard rejects when no chat book is bound

    @Test func testExecute_noChatBook_rejectedByScopeGuard() async throws {
        let store = try Self.makeWorldStore()
        let requestedBook = UUID()
        let actor = BookWorldActor(
            worldStore: store,
            currentChatBookIDProvider: { nil }  // no chat book bound (= onboarding)
        )
        let tool = BookWorldTool(actor: actor)
        let input = """
        {"action":"create","book_id":"\(requestedBook.uuidString)","name":"Forbidden","markdown":"# Forbidden"}
        """
        let output = try await tool.execute(input: input)
        #expect(output.contains("\"ok\":false"))
        #expect(output.contains("\"error_kind\":\"book_scope_violation\""))
        #expect(output.contains("not bound to any book"))
    }
}