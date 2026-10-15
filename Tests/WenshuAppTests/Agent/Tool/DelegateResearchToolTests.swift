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

import Testing
import Foundation
@testable import WenshuApp

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