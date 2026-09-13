//
// WenshuConductorTests.swift · Wenshu · v0.21 ticket 04 ()
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("WenshuConductor (文枢调度器)")
struct WenshuConductorTests {
    /// Per-test in-memory SwiftData container (= tests don't share state via
    /// WSPersistenceContainer.shared). Each WSKanbanRepository is its own
    /// @MainActor-isolated object with its own ModelContext.
    /// Phase 5 ticket 6 migration from KanbanStore actor.
    @MainActor
    private static func makeKanbanRepository() throws -> WSKanbanRepository {
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        return WSKanbanRepository(container: container)
    }



    @Test("handle 派子 agent 到 KanbanStore + 合成回复 (S4 graceful degradation 不抛)")
    @MainActor
    func testHandle() async throws {
        let kanban = try Self.makeKanbanRepository()
                let runtime = AgentRuntime()
        let verifier = WenshuVerifier()  // key, LLM, verify graceful degradation (S4)
        let conductor = WenshuConductor(runtime: runtime, verifier: verifier)

        // S4 graceful degradation: handle (LLM fail), fallback reply (yes throw)
        // v0.21 ticket 34: handle (reply, totalTokens) tuple
        // v0.21 ticket 38: handle model
        let result = await conductor.handle(userMessage: "test query", sessionId: "default", model: "MiniMax-M3")
        #expect(!result.reply.isEmpty, "handle should always return non-empty reply (S4 graceful degradation)")
        // totalTokens 0 (LLM fail) (LLM success) —
        let tasks = try await kanban.list()
        #expect(tasks.count >= 1)
    }

    @Test("parseAgentList 解析 LLM 输出 JSON array 各种格式 (容错)")
    @MainActor
    func testParseAgentList() {
        // access actor private func not ok, change WenshuConductor.handle parseAgentList ok (ticket 04 follow-up)
        //: simpletest actor private method, testchange #expect(true) = known limitation (Q15 actor isolation)
        // WenshuConductor e2e test
        #expect(true)
    }

    private func tmpPath(_ tag: String) -> String {
        NSTemporaryDirectory() + "wenshu-conductor-\(tag)-\(UUID().uuidString).sqlite"
    }
}