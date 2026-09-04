//
//  WenshuConductorConversationLoopWiringTests.swift · Wenshu · P0 #1 (WIRE-AGENT-001)
//
//  Round-trip tests for the ConversationLoop routing wired into
//  WenshuConductor.handle() (= tool dispatch + compression + retry +
//  sanitization + finalization now active for any conductor constructed
//  with a connector injection).
//
//  1. testConductor_routesToConversationLoop
//     (= mock connector returns canned response; verify the loop's
//     `runTurn` was the path that produced the reply).
//  2. testConductor_preservesToolDispatch
//     (= canned response contains a tool_use block; verify the loop's
//     ToolExecutor dispatches it and the LLM is re-invoked with the
//     tool result before the final text reply is returned).
//  3. testConductor_preservesCompression
//     (= long conversation history (>8 messages) triggers
//     ConversationCompression.historyAfterCompression — verified by
//     observing the loop's per-turn compression step is exercised and
//     the reply still arrives).
//  4. testConductor_handlesFallbackWhenLoopErrors
//     (= connector throws on every call; verify handle() does NOT throw,
//     returns a non-empty fallback reply (= S4 graceful degradation),
//     AND the legacy intent+sub-agent+synthesis path ran (= same
//     fallback reply text the legacy path produces)).
//
//  These tests construct the conductor via the new
//  `init(...:connector:loopRuntime:)` overload. The legacy
//  `init(...:)` stays unchanged and is exercised by
//  WenshuConductorTests / WenshuConductorE2ETests (= no regression).
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("WenshuConductor → ConversationLoop wiring (P0 #1 / WIRE-AGENT-001)")
struct WenshuConductorConversationLoopWiringTests {

    // MARK: - Test 1: routes to ConversationLoop

    @Test("handle routes through ConversationLoop.runTurn when a connector is injected")
    func testConductor_routesToConversationLoop() async throws {
        // Scripted response so the mock returns the canned text verbatim
        // (= not the default echo mode that prefixes "echo: ").
        let scripts: [LLMResponse] = [
            LLMResponse(
                id: "r1",
                model: "mock",
                blocks: [.text("loop-reply")],
                stopReason: .endTurn,
                usage: LLMUsage(inputTokens: 5, outputTokens: 7)
            )
        ]
        let connector = MockLLMConnector(scriptedResponses: scripts)
        let kanban = try KanbanStore(path: tmpPath("route"))
        try await kanban.bootstrap()
        let verifier = WenshuVerifier()
        let conductor = WenshuConductor(
            runtime: AgentRuntime(),
            verifier: verifier,
            kanbanStore: kanban,
            connector: connector
        )

        let result = await conductor.handle(
            userMessage: "ping",
            sessionId: "default",
            model: "MiniMax-M3"
        )

        // ConversationLoop delegates to connector.send — verify the mock
        // was hit (= loop ran end-to-end). MockLLMConnector is an actor;
        // read the counter through await.
        let receivedCount = await connector.receivedMessages.count
        #expect(receivedCount >= 1, "ConversationLoop must invoke the connector.send path")
        // The reply text comes from the connector's scripted response.
        #expect(result.reply == "loop-reply", "handle must surface the loop's reply text verbatim")
        // totalTokens is the loop's usage (= 5 in + 7 out = 12 from the
        // scripted response).
        #expect(result.totalTokens == 12, "handle must surface the loop's usage total")
    }

    // MARK: - Test 2: tool dispatch survives

    @Test("handle preserves tool dispatch (tool_use → executor → re-invoke LLM → final reply)")
    func testConductor_preservesToolDispatch() async throws {
        // Two canned responses: first emits tool_use, second returns the
        // final text after the tool result is appended (= hermes
        // tool result → next assistant message loop body).
        let scripts: [LLMResponse] = [
            LLMResponse(
                id: "r1",
                model: "mock",
                blocks: [.toolUse(id: "t1", name: "Echo", input: "{}")],
                stopReason: .toolUse,
                usage: LLMUsage(inputTokens: 1, outputTokens: 2)
            ),
            LLMResponse(
                id: "r2",
                model: "mock",
                blocks: [.text("final-after-tool")],
                stopReason: .endTurn,
                usage: LLMUsage(inputTokens: 3, outputTokens: 4)
            )
        ]
        let connector = MockLLMConnector(scriptedResponses: scripts)
        let kanban = try KanbanStore(path: tmpPath("tools"))
        try await kanban.bootstrap()
        let conductor = WenshuConductor(
            runtime: AgentRuntime(),
            verifier: WenshuVerifier(),
            kanbanStore: kanban,
            connector: connector
        )

        let result = await conductor.handle(
            userMessage: "call tool",
            sessionId: "default",
            model: "MiniMax-M3"
        )

        // The connector received 2 calls (= tool_use → re-invoke after
        // tool result). That's the proof that tool dispatch ran.
        let receivedCount = await connector.receivedMessages.count
        #expect(receivedCount >= 2, "ConversationLoop must re-invoke LLM after tool dispatch")
        // The final reply is the text from the second scripted response.
        #expect(result.reply == "final-after-tool", "handle must surface the post-tool-dispatch final reply")
    }

    // MARK: - Test 3: compression survives

    @Test("handle preserves ConversationCompression wiring (= long history → compression exercised → reply still arrives)")
    func testConductor_preservesCompression() async throws {
        // ConversationCompression is a concrete actor (= Swift forbids
        // subclassing actors), so we cannot instrument it directly.
        // What this test proves:
        //   (a) ConversationLoop.runTurn with a >8-message history
        //       (= ConversationCompression's default keepRecentTurns = 8)
        //       completes end-to-end without throwing. ConversationLoop
        //       calls historyAfterCompression on every turn
        //       (= ConversationLoop.swift line ~410); when the
        //       message count exceeds the policy's keepRecentTurns, the
        //       compressor's split logic runs.
        //   (b) The Conductor path still works end-to-end with the
        //       compression wired (= no regression in handle()).
        let scripts: [LLMResponse] = [
            LLMResponse(
                id: "r1",
                model: "mock",
                blocks: [.text("after-compression")],
                stopReason: .endTurn,
                usage: LLMUsage(inputTokens: 0, outputTokens: 0)
            )
        ]
        let connector = MockLLMConnector(scriptedResponses: scripts)
        let loop = ConversationLoop(
            connection: connector,
            systemPrompt: "test-system"
        )

        // Build a >8-message history so the default keepRecentTurns = 8
        // actually triggers the split logic.
        var history: [LLMMessage] = []
        for i in 0..<12 {
            history.append(.user("msg-\(i)"))
        }

        let loopResult = try await loop.runTurn(
            userMessage: "trigger compression",
            systemMessage: nil,
            conversationHistory: history
        )

        // Loop completed without throwing (= compression did not abort
        // the turn). The reply carries the canned text.
        let reply = loopResult.response.blocks.compactMap { block -> String? in
            if case .text(let s) = block { return s }
            return nil
        }.joined()
        #expect(reply == "after-compression", "loop must surface the canned reply after compression")

        // Also verify the Conductor path still works end-to-end with the
        // compression wired (= no regression in handle()).
        let kanban = try KanbanStore(path: tmpPath("compression"))
        try await kanban.bootstrap()
        let conductor = WenshuConductor(
            runtime: AgentRuntime(),
            verifier: WenshuVerifier(),
            kanbanStore: kanban,
            connector: connector
        )
        let conductorResult = await conductor.handle(
            userMessage: "conductor path",
            sessionId: "default",
            model: "MiniMax-M3"
        )
        #expect(!conductorResult.reply.isEmpty, "conductor path must return non-empty reply")
    }

    // MARK: - Test 4: fallback when loop errors

    @Test("handle falls back to legacy pipeline when ConversationLoop throws (= S4 graceful degradation)")
    func testConductor_handlesFallbackWhenLoopErrors() async throws {
        let connector = ThrowingMockConnector()
        let kanban = try KanbanStore(path: tmpPath("fallback"))
        try await kanban.bootstrap()
        let conductor = WenshuConductor(
            runtime: AgentRuntime(),
            verifier: WenshuVerifier(),
            kanbanStore: kanban,
            connector: connector
        )

        // No API key → legacy pipeline's LLM calls fail → S4 fallback
        // reply is the curated "（文枢暂时无法回复, 请稍后再试）" string
        // OR the sub-agent summary if any sub-agent ran. We only assert
        // S4 graceful degradation invariants (= never throws, reply
        // non-empty, totalTokens = 0 because LLM never succeeded).
        let result = await conductor.handle(
            userMessage: "fallback test",
            sessionId: "default",
            model: "MiniMax-M3"
        )

        #expect(!result.reply.isEmpty, "S4 graceful degradation must always return non-empty reply")
        #expect(result.totalTokens == 0, "no LLM call succeeded → totalTokens must be 0")
        // Kanban must still have the conductor parent task (= legacy
        // path wrote it).
        let tasks = try await kanban.list()
        #expect(tasks.contains(where: { $0.title.contains("conductor:") }), "fallback path must write the Kanban parent task")
    }

    private func tmpPath(_ tag: String) -> String {
        NSTemporaryDirectory() + "wenshu-conductor-loop-\(tag)-\(UUID().uuidString).sqlite"
    }
}

// MARK: - Test fixtures

/// LLMConnector that throws on every send — used to prove
/// WenshuConductor.handle() falls back to the legacy pipeline
/// (= ConversationLoop.runTurn throws → handle() never throws → legacy
/// intent+sub-agent+synthesis path runs and returns S4 graceful
/// degradation reply).
private actor ThrowingMockConnector: LLMConnector {
    nonisolated public let connectorID: String = "throwing-mock"

    public func send(messages: [LLMMessage], options: LLMCallOptions) async throws -> LLMResponse {
        throw LLMConnectorError.transport(
            provider: "throwing-mock",
            statusCode: 500,
            body: "simulated failure for WIRE-AGENT-001 fallback test"
        )
    }
}

/// ConversationCompression is a concrete actor (= Swift forbids
/// subclassing actors) so there is no CountingCompressionActor fixture
/// for test 3. The compression hook is observed indirectly through
/// ConversationLoop.runTurn succeeding with a >8-message history.