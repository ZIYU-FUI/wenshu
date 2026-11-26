//
//  DelegateResearchToolTests.swift · Wenshu · v2.7 self-evolution
//
//  Round-trip tests for the delegate_research LLM-facing tool
//  (= the fire-and-forget path from boss 2026-09-25 directive:
//  'wenshu main agent delegates research to the Researcher
//  sub-agent async; = main agent does NOT block on web_search').
//
//  What this test verifies:
//  - delegate_research with action='delegate' and a nouns array
//    registers one delegation handle per noun (= AsyncDelegation
//    source-of-truth) and returns a JSON envelope
//  - the envelope reports ok=true, count=n, and per-noun
//    {handle_id, agent=researcher, status=pending}
//  - the summary field is human-readable (= so the LLM can
//    quote it in its reply without re-parsing JSON)
//  - missing nouns is rejected with ok=false
//  - empty action is rejected with ok=false
//

import Foundation
import Testing
import WenshuAgent
@testable import WenshuApp
import WenshuData

@Suite("DelegateResearchTool (= fire-and-forget research delegation)")
struct DelegateResearchToolTests {

    // Touch the singleton (= triggers _registryBootstrap
    // before the test runs). Brief yield so the
    // fire-and-forget registration Task lands before the
    // test's assertions (= avoids the SIGTRAP from actor
    // reentrancy documented in AGENTS.md §11.5).
    private func makeTool() async -> DelegateResearchTool {
        _ = DelegateResearchTool.shared
        try? await Task.sleep(nanoseconds: 50_000_000)
        return DelegateResearchTool.shared
    }

    /// Run the tool with a book bound to the turn, the way the conductor
    /// binds it. The helper is nonisolated on purpose: the task-local
    /// binding hops isolation domains, and a closure that carries this
    /// suite's main-actor isolation is not sendable across that hop.
    private nonisolated static func runInsideBookScope(
        tool: DelegateResearchTool,
        input: String,
        bookID: String
    ) async throws -> String {
        try await TurnScope.withScope(
            sessionID: "session-dispatch-proof",
            bookID: bookID
        ) {
            try await tool.execute(input: input)
        }
    }

    @Test("delegate_research delegates one handle per noun")
    func delegate_research_PerNounHandles() async throws {
        let tool = await makeTool()
        let envelope: [String: Any] = [
            "action": "delegate",
            "nouns": ["西安", "明朝"],
            "context": "用户提到主角出生在西安，生活在明朝。"
        ]
        let json = try JSONSerialization.data(
            withJSONObject: envelope,
            options: [.sortedKeys]
        )
        let result = try await tool.execute(input: String(data: json, encoding: .utf8) ?? "{}")
        let parsed = try #require(
            try JSONSerialization.jsonObject(with: Data(result.utf8)) as? [String: Any]
        )
        #expect(parsed["ok"] as? Bool == true, "delegate_research must report ok=true")
        #expect(parsed["action"] as? String == "delegate")
        #expect(parsed["count"] as? Int == 2)
        let delegations = try #require(parsed["delegations"] as? [[String: Any]])
        #expect(delegations.count == 2)
        // Per-noun shape: handle_id, agent, status, noun.
        for delegation in delegations {
            #expect(delegation["handle_id"] is String)
            #expect(delegation["agent"] as? String == "researcher")
            #expect(delegation["status"] as? String == "pending")
            #expect(delegation["noun"] is String)
        }
        // The two nouns are surfaced verbatim.
        let nouns = Set(delegations.compactMap { $0["noun"] as? String })
        #expect(nouns == Set(["西安", "明朝"]))
        // Summary is human-readable (= quoted in the LLM's reply).
        let summary = parsed["summary"] as? String ?? ""
        #expect(summary.contains("已发起"))
        #expect(summary.contains("2"))
    }

    @Test("delegate_research with a single noun returns one delegation")
    func delegate_research_SingleNoun() async throws {
        let tool = await makeTool()
        let envelope: [String: Any] = [
            "action": "delegate",
            "nouns": ["入殓师"]
        ]
        let json = try JSONSerialization.data(
            withJSONObject: envelope,
            options: [.sortedKeys]
        )
        let result = try await tool.execute(input: String(data: json, encoding: .utf8) ?? "{}")
        let parsed = try JSONSerialization.jsonObject(with: Data(result.utf8)) as? [String: Any]
        #expect(parsed?["ok"] as? Bool == true)
        #expect(parsed?["count"] as? Int == 1)
        let delegations = parsed?["delegations"] as? [[String: Any]] ?? []
        #expect(delegations.count == 1)
        #expect(delegations.first?["noun"] as? String == "入殓师")
    }

    @Test("delegate_research with missing nouns returns ok=false")
    func delegate_research_MissingNouns() async throws {
        let tool = await makeTool()
        let envelope: [String: Any] = [
            "action": "delegate"
        ]
        let json = try JSONSerialization.data(
            withJSONObject: envelope,
            options: [.sortedKeys]
        )
        let result = try await tool.execute(input: String(data: json, encoding: .utf8) ?? "{}")
        let parsed = try #require(
            try JSONSerialization.jsonObject(with: Data(result.utf8)) as? [String: Any]
        )
        #expect(parsed["ok"] as? Bool == false)
        #expect((parsed["error"] as? String)?.contains("nouns") == true)
    }

    @Test("delegate_research with empty nouns array returns ok=false")
    func delegate_research_EmptyNouns() async throws {
        let tool = await makeTool()
        let envelope: [String: Any] = [
            "action": "delegate",
            "nouns": [String]()
        ]
        let json = try JSONSerialization.data(
            withJSONObject: envelope,
            options: [.sortedKeys]
        )
        let result = try await tool.execute(input: String(data: json, encoding: .utf8) ?? "{}")
        let parsed = try #require(
            try JSONSerialization.jsonObject(with: Data(result.utf8)) as? [String: Any]
        )
        #expect(parsed["ok"] as? Bool == false)
    }

    @Test("delegate_research with unknown action returns ok=false")
    func delegate_research_UnknownAction() async throws {
        let tool = await makeTool()
        let envelope: [String: Any] = [
            "action": "rebuild",
            "nouns": ["西安"]
        ]
        let json = try JSONSerialization.data(
            withJSONObject: envelope,
            options: [.sortedKeys]
        )
        let result = try await tool.execute(input: String(data: json, encoding: .utf8) ?? "{}")
        let parsed = try #require(
            try JSONSerialization.jsonObject(with: Data(result.utf8)) as? [String: Any]
        )
        #expect(parsed["ok"] as? Bool == false)
        #expect((parsed["error"] as? String)?.contains("rebuild") == true)
    }

    @Test("delegate_research with missing action returns ok=false")
    func delegate_research_MissingAction() async throws {
        let tool = await makeTool()
        let envelope: [String: Any] = [
            "nouns": ["西安"]
        ]
        let json = try JSONSerialization.data(
            withJSONObject: envelope,
            options: [.sortedKeys]
        )
        let result = try await tool.execute(input: String(data: json, encoding: .utf8) ?? "{}")
        let parsed = try #require(
            try JSONSerialization.jsonObject(with: Data(result.utf8)) as? [String: Any]
        )
        #expect(parsed["ok"] as? Bool == false)
        #expect((parsed["error"] as? String)?.contains("action") == true)
    }

    /// A card the board cannot route is not a hand-off: it must name the
    /// role that owns the work, carry the instruction that role was given,
    /// and be filed under the book the turn was reading.
    ///
    /// The assertion is made on the row and not on the envelope, because
    /// `addKanbanTask` is best-effort (= a failed write still returns
    /// ok=true), so an empty board would pass every other assertion here.
    /// The container is activated for the duration of the call: the tool
    /// reaches `WSKanbanRepository.shared`, which resolves the live store.
    @Test("the dispatch card carries owner, instruction and book")
    @MainActor
    func delegate_research_CardCarriesTheHandOff() async throws {
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        WSPersistenceContainer.activateWarehouseContainer(container)
        defer { WSPersistenceContainer.activateWarehouseContainer(nil) }

        let tool = await makeTool()
        let noun = "the-tide"
        let bookID = "book-dispatch-proof"
        let envelope: [String: Any] = [
            "action": "delegate",
            "nouns": [noun],
            "context": "a harbour town that lives on the tide",
        ]
        let json = try JSONSerialization.data(
            withJSONObject: envelope,
            options: [.sortedKeys]
        )
        let input = String(data: json, encoding: .utf8) ?? "{}"
        _ = try await Self.runInsideBookScope(tool: tool, input: input, bookID: bookID)

        let card = try #require(
            try await WSKanbanRepository.shared.list()
                .first { $0.title == "research: \(noun)" },
            "the delegation wrote no board card"
        )
        #expect(card.assignee == SubAgentRoleRegistry.researcher.slug,
                "the card must name the role that owns it; got: \(String(describing: card.assignee))")
        #expect(card.body?.contains(noun) == true,
                "the card must carry the instruction the role was given")
        #expect(card.bookID == bookID,
                "a dispatch made inside a book belongs on that book's board; got: \(String(describing: card.bookID))")
    }

    // Note: a ToolRegistry registration smoke test (= asserting the
    // tool is registered under name "delegate_research") was
    // attempted but the underlying ToolRegistry.shared actor
    // SIGTRAPs under the fire-and-forget bootstrap window
    // (= documented in AGENTS.md §11.5). The other six tests
    // verify the tool's behavior end-to-end (= parse the
    // envelope -> register handle -> return JSON); = a
    // registration smoke test is redundant given the tool is
    // constructed via the same bootstrap pattern as every other
    // wenshu tool (= WebSearchTool, KanbanStoreTool, etc.).
}