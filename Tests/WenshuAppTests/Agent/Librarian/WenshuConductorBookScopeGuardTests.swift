//
//  WenshuConductorBookScopeGuardTests.swift · Wenshu · v2.1 (2026-09-25)
//
//  Integration tests for the wireBookScopeGuard method on
//  WenshuConductor. Two halves:
//
//  1. The four book_X tools are replaced with provider-bound
//     instances (= world / character / chapter / outline get
//     replaced; reference_library + book_manager are NOT
//     touched).
//
//  2. Each replaced tool honors the chat-scope guard: a
//     cross-book write (provider returns book A, LLM passes
//     book B in the envelope) returns
//     {\"ok\":false, \"error_kind\":\"book_scope_violation\"}.
//
//  3. reference_library passes through unchanged (= no chat
//     scope guard; = library-public).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("WenshuConductor book scope guard (v2.1)")

struct WenshuConductorBookScopeGuardTests {

    // MARK: - Helpers

    /// Build a fresh actor stack for the conductor tests. The
    /// actors are wired with a shared bookDirectory + nil
    /// currentChatBookID (= the conductor wire will overwrite
    /// both). Marked @MainActor because
    /// `WenshuConductor.init` calls `MainActor.assumeIsolated { ... }`
    /// (= Swift 6 strict-concurrency requirement).
    @MainActor
    private static func makeConductor() -> WenshuConductor {
        let runtime = AgentRuntime()
        let verifier = WenshuVerifier()
        return WenshuConductor(
            runtime: runtime,
            verifier: verifier,
            tools: [:]
        )
    }

    private static func makeBookDirectory() throws -> URL {
        let tmpRoot = URL(
            fileURLWithPath: "/tmp/wenshu-v2.1-conductor-test-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)
        return tmpRoot
    }

    // MARK: - Test 1: wire replaces the four book_X tools

    @MainActor
    @Test func wire_replacesFourBookTools() async throws {
        let conductor = Self.makeConductor()
        let chatBook = UUID()
        let dir = try Self.makeBookDirectory()
        await conductor.wireBookScopeGuard(
            currentChatBookID: chatBook,
            bookDirectory: dir
        )
        let names = await conductor.registeredToolNames()
        #expect(names.contains("book_world"))
        #expect(names.contains("book_character"))
        #expect(names.contains("book_chapter"))
        #expect(names.contains("book_outline"))
    }

    // MARK: - Test 2: reference_library is NOT replaced (= public)

    @MainActor
    @Test func wire_doesNotTouchReferenceLibrary() async throws {
        let conductor = Self.makeConductor()
        // Register a fake reference_library tool (= so we can detect
        // whether wireBookScopeGuard overwrites it).
        struct DummyTool: Tool, Sendable {
            let name = "reference_library"
            func execute(input: String) async throws -> String { "dummy" }
        }
        let dummy = DummyTool()
        await conductor.setToolForTest("reference_library", dummy)
        let chatBook = UUID()
        let dir = try Self.makeBookDirectory()
        await conductor.wireBookScopeGuard(
            currentChatBookID: chatBook,
            bookDirectory: dir
        )
        let tools = await conductor.tools
        // The wire did not touch reference_library (= the dummy
        // we registered is still there).
        let ref = tools["reference_library"]
        #expect(ref != nil)
        // ... and a fresh read returns the dummy's output (= the
        // wire did not swap a real reference_library tool in).
        if let ref {
            let result = try await ref.execute(input: "{}")
            #expect(result == "dummy")
        }
    }

    // MARK: - Test 3: cross-book write is rejected by the wired tool

    @MainActor
    @Test func wire_crossBookWrite_rejectedByScopeGuard() async throws {
        let conductor = Self.makeConductor()
        let chatBook = UUID()
        let requestedBook = UUID()
        let dir = try Self.makeBookDirectory()
        await conductor.wireBookScopeGuard(
            currentChatBookID: chatBook,
            bookDirectory: dir
        )
        // Invoke book_world with a different book_id than the
        // chat-bound one (= scope guard must reject).
        let tools = await conductor.tools
        let world = tools["book_world"]
        #expect(world != nil)
        if let world {
            let input = """
            {"action":"create","book_id":"\(requestedBook.uuidString)","name":"Forbidden","markdown":"# F"}
            """
            let output = try await world.execute(input: input)
            #expect(output.contains("\"ok\":false"))
            #expect(output.contains("\"error_kind\":\"book_scope_violation\""))
            #expect(output.contains(chatBook.uuidString))
            #expect(output.contains(requestedBook.uuidString))
        }
    }

    // MARK: - Test 4: matching book_id is accepted

    @MainActor
    @Test func wire_matchingBookID_acceptedByScopeGuard() async throws {
        let conductor = Self.makeConductor()
        let chatBook = UUID()
        let dir = try Self.makeBookDirectory()
        await conductor.wireBookScopeGuard(
            currentChatBookID: chatBook,
            bookDirectory: dir
        )
        let tools = await conductor.tools
        let world = tools["book_world"]
        #expect(world != nil)
        if let world {
            let input = """
            {"action":"create","book_id":"\(chatBook.uuidString)","name":"Beijing","markdown":"# B"}
            """
            let output = try await world.execute(input: input)
            #expect(output.contains("\"ok\":true"))
            #expect(output.contains("\"action\":\"create\""))
            #expect(output.contains("\"name\":\"Beijing\""))
        }
    }

    // MARK: - Test 5: nil chat book + a write attempt = rejected

    @MainActor
    @Test func wire_nilChatBook_writeAttemptRejected() async throws {
        let conductor = Self.makeConductor()
        let requestedBook = UUID()
        let dir = try Self.makeBookDirectory()
        await conductor.wireBookScopeGuard(
            currentChatBookID: nil,  // = onboarding / no book selected
            bookDirectory: dir
        )
        let tools = await conductor.tools
        let world = tools["book_world"]
        #expect(world != nil)
        if let world {
            let input = """
            {"action":"create","book_id":"\(requestedBook.uuidString)","name":"Forbidden","markdown":"# F"}
            """
            let output = try await world.execute(input: input)
            #expect(output.contains("\"ok\":false"))
            #expect(output.contains("\"error_kind\":\"book_scope_violation\""))
            #expect(output.contains("not bound to any book"))
        }
    }
}

// MARK: - Test-only accessors (= see Q112 standing rule)

extension WenshuConductor {
    /// Insert a tool directly (= test helper). The test-only
    /// accessors below let us assert the wire replaces (= or
    /// leaves alone) specific keys in `self.tools`.
    func __setTestTool(_ name: String, _ tool: any Tool) {
        tools[name] = tool
    }

    /// Snapshot of the current tools dict (= test helper). Read
    /// access for assertions.
    func __testToolsSnapshot() -> [String: any Tool] {
        tools
    }
}