//
//  WenshuConductorE2ETests.swift · Wenshu · v0.23 ticket 007 (end-to-end pipeline test)
//
//  Boss 2026-08-23 拍: '主 agent 派单, 全流程, 能测一下不'.
//
//  This test exercises the FULL conductor pipeline WITHOUT calling real LLM:
//    1. handle() entry point
//    2. intent classify → graceful degradation (no API key → empty selectedAgents)
//    3. sub-agent dispatch loop → no-ops (no agents selected)
//    4. Auditor pass → no-ops
//    5. synthesis → graceful degradation (curated fallback reply)
//    6. ChatSessionStore writes 0 sub-agent runs (because none dispatched)
//    7. KanbanStore writes the conductor parent task
//
//  Verifies the WHOLE pipeline state machine without external dependencies.
//  For real LLM verification, see wenshu manual integration test (boss 8/21+).
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("WenshuConductor E2E (主 agent 派单, 全流程)")
struct WenshuConductorE2ETests {

    /// Pipeline test: handle() with no API key → graceful degradation end-to-end.
    /// Verifies state writes (Kanban + ChatSessionStore) even when LLM calls fail.
    @Test("e2e pipeline: handle → graceful degradation → state writes")
    func testE2EGracefulDegradation() async throws {
        // Set up all stores (real SQLite, tmp paths)
        let kanban = try KanbanStore(path: tmpPath("e2e-kanban"))
        try await kanban.bootstrap()
        let session = try ChatSessionStore(path: tmpPath("e2e-session"))
        try await session.bootstrap()
        let runtime = AgentRuntime()
        let verifier = WenshuVerifier()  // no API key → all LLM calls fail

        let conductor = WenshuConductor(
            runtime: runtime,
            verifier: verifier,
            kanbanStore: kanban,
            sessionStore: session
        )

        // Step 1: handle entry point
        let result = await conductor.handle(
            userMessage: "测试 query",
            sessionId: "default",
            model: "MiniMax-M3"
        )

        // Step 5: synthesis graceful degradation
        #expect(!result.reply.isEmpty, "synthesis graceful degradation should return non-empty reply")
        #expect(result.totalTokens == 0, "no LLM calls succeeded → totalTokens should be 0")

        // Step 7: KanbanStore has the conductor parent task (from handle step 1)
        let kanbanTasks = try await kanban.list()
        #expect(kanbanTasks.count >= 1, "conductor should write parent kanban task")
        let conductorTask = kanbanTasks.first { $0.title.contains("conductor:") }
        #expect(conductorTask != nil, "should have a conductor:* title task")

        // Step 6: sub_agent_runs table should be empty (no sub-agents dispatched since LLM failed)
        let subAgentRuns = try await session.loadSubAgentRuns(sessionId: "default")
        #expect(subAgentRuns.isEmpty, "no LLM → no sub-agent runs persisted")
    }

    /// Pipeline test: ChatSessionStore sub_agent_runs schema is created on bootstrap.
    /// Verifies the table is queryable (separate from full e2e above for granular check).
    @Test("e2e pipeline: ChatSessionStore sub_agent_runs table ready for persistence")
    func testE2ESubAgentRunsTableReady() async throws {
        let session = try ChatSessionStore(path: tmpPath("e2e-subrun-table"))
        try await session.bootstrap()
        // Manually write a run to verify the table works end-to-end
        let run = SubAgentRun(
            id: UUID().uuidString,
            agentName: "writer",
            title: "writer: e2e test task",
            status: .done,
            startedAt: Date(),
            completedAt: Date(),
            resultSummary: "e2e test summary"
        )
        try await session.recordSubAgentRun(run, sessionId: "default")
        let loaded = try await session.loadSubAgentRuns(sessionId: "default")
        #expect(loaded.count == 1)
        #expect(loaded[0].agentName == "writer")
        #expect(loaded[0].status == .done)
    }

    /// Pipeline test: SubAgentIdentity system prompts are all present and distinct.
    /// Verifies the 5 agents can be dispatched (i.e. their prompts exist for handle() to use).
    @Test("e2e pipeline: 5 sub-agent identities ready for handle() dispatch")
    func testE2ESubAgentIdentitiesReady() {
        // This is the gating check: if any sub-agent's identity is missing,
        // handle() cannot dispatch them in real LLM mode.
        for name in SubAgentIdentity.Name.allCases {
            let prompt = SubAgentIdentity.systemPrompt(name: name)
            let tools = SubAgentIdentity.tools(name: name)
            let displayName = SubAgentIdentity.displayName(name: name)
            #expect(!prompt.isEmpty, "missing system prompt for \(name)")
            #expect(!tools.isEmpty, "missing tools for \(name)")
            #expect(!displayName.isEmpty, "missing display name for \(name)")
        }
    }

    /// Pipeline test: WenshuConductorIdentity main agent identity ready.
    @Test("e2e pipeline: 主 agent (文枢) identity ready for handle() injection")
    func testE2EMainAgentIdentityReady() {
        let prompt = WenshuConductorIdentity.systemPrompt
        let caps = WenshuConductorIdentity.capabilitiesList
        let forbidden = WenshuConductorIdentity.forbiddenTokens
        #expect(prompt.contains("文枢"), "main agent identity must mention 文枢")
        #expect(prompt.contains("老板"), "main agent identity must mention 老板")
        #expect(caps.count == 15, "main agent should have 15 capabilities")
        #expect(forbidden.count == 12, "main agent should have 12 forbidden tokens")
    }

    private func tmpPath(_ tag: String) -> String {
        NSTemporaryDirectory() + "wenshu-e2e-\(tag)-\(UUID().uuidString).sqlite"
    }
}