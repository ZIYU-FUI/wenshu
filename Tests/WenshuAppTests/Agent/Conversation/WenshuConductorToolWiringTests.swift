//
//  WenshuConductorToolWiringTests.swift · Wenshu · P0 #2 (WIRE-AGENT-002)
//
//  Round-trip tests for the ToolExecutor wiring through WenshuConductor
//  (= P0 #2 = tool dispatch path now active). The conductor's
//  `tools: [String: any Tool]` registry is forwarded to
//  `ConversationLoop.runTurn(...tools:)` so the ToolExecutor dispatches
//  tool_use blocks against registered wenshu tools.
//
//  Tests:
//    1. testConductor_toolsPassedToLoop — tools dict reaches ConversationLoop.runTurn
//    2. testConductor_toolDispatch_invokesParagraphAI — mock LLM toolUse → ParagraphAITool.execute called
//    3. testConductor_toolDispatch_resultsBackInFinalResponse — tool output bubbles into final assistant message
//    4. testConductor_multipleTools_allRegistered — register 3 tools → all 3 available for dispatch
//
//  Plus a unit-level test for ParagraphAITool itself:
//    5. testParagraphAI_stubReturnsCannedExpansion — stub contract holds (non-empty output, mode echo)
//
//  Companion file: ParagraphAIToolTests.swift holds test #5 (kept
//  separate so each @Suite is focused and the acceptance filter
//  `--filter "WenshuConductorToolWiring|ParagraphAITool"` matches
//  both suites).
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("WenshuConductor → ToolExecutor wiring (P0 #2 / WIRE-AGENT-002)")
struct WenshuConductorToolWiringTests {

    // MARK: - Test 1: tools dict reaches ConversationLoop.runTurn

    @Test("handle forwards the registered tools dictionary to ConversationLoop.runTurn")
    func testConductor_toolsPassedToLoop() async throws {
        // Capturing connector records both the LLMCallOptions and the
        // message list it received on each call. The first call's
        // options do NOT carry the tool registry directly (= the
        // tools dictionary flows through runTurn's `tools:` parameter,
        // not the LLM call options). Instead, we verify the wiring
        // by checking that ConversationLoop.runTurn was reached (= 1+
        // LLM call) AND that a tool_use block in the assistant
        // message is dispatched (= the executed tool comes from the
        // conductor's registry, not the empty default).
        let connector = RecordingMockConnector(
            scriptedResponses: [
                LLMResponse(
                    id: "r1",
                    model: "mock",
                    blocks: [.toolUse(id: "t1", name: "ProbeTool", input: "{}")],
                    stopReason: .toolUse,
                    usage: LLMUsage(inputTokens: 1, outputTokens: 1)
                ),
                LLMResponse(
                    id: "r2",
                    model: "mock",
                    blocks: [.text("final")],
                    stopReason: .endTurn,
                    usage: LLMUsage(inputTokens: 2, outputTokens: 2)
                )
            ]
        )
        let probe = ProbeTool()
        let conductor = try await makeConductor(
            connector: connector,
            tools: ["ProbeTool": probe]
        )

        let result = await conductor.handle(
            userMessage: "ping",
            sessionId: "default",
            model: "MiniMax-M3"
        )

        // The probe was called at least once (= the registry reached
        // the ToolExecutor).
        let probeHits = await probe.callCount
        #expect(probeHits >= 1, "conductor must forward tools to ConversationLoop.runTurn so the executor can dispatch")
        // The final reply came from the second scripted response.
        #expect(result.reply == "final", "tool result → next assistant message loop body must still produce the final reply")
    }

    // MARK: - Test 2: tool dispatch invokes ParagraphAITool

    @Test("handle dispatches tool_use blocks to ParagraphAITool when registered")
    func testConductor_toolDispatch_invokesParagraphAI() async throws {
        let connector = RecordingMockConnector(
            scriptedResponses: [
                LLMResponse(
                    id: "r1",
                    model: "mock",
                    blocks: [.toolUse(
                        id: "t1",
                        name: "ParagraphAI",
                        input: "{\"text\":\"hello world\",\"mode\":\"expand\"}"
                    )],
                    stopReason: .toolUse,
                    usage: LLMUsage(inputTokens: 1, outputTokens: 1)
                ),
                LLMResponse(
                    id: "r2",
                    model: "mock",
                    blocks: [.text("paragraph processed")],
                    stopReason: .endTurn,
                    usage: LLMUsage(inputTokens: 2, outputTokens: 2)
                )
            ]
        )
        let conductor = try await makeConductor(
            connector: connector,
            tools: ["ParagraphAI": ParagraphAITool.shared]
        )

        _ = await conductor.handle(
            userMessage: "expand this",
            sessionId: "default",
            model: "MiniMax-M3"
        )

        // Capture all tool messages appended to the conversation —
        // ParagraphAITool.execute produces a non-empty canned
        // expansion that the ToolExecutor wraps into a .toolResult
        // block. If the registry reached the executor, the tool
        // message will be present.
        let toolResults = await connector.allToolResults()
        #expect(toolResults.count >= 1, "tool_use → ParagraphAI must produce at least one tool result")
        let paragraphResult = toolResults.first { $0.contains("ParagraphAI stub") || $0.contains("hello world") }
        #expect(paragraphResult != nil, "ParagraphAITool's canned expansion must surface in the tool result stream")
    }

    // MARK: - Test 3: tool output bubbles back into the final reply

    @Test("handle surfaces tool output in the final assistant reply (= LLM is re-invoked with tool results)")
    func testConductor_toolDispatch_resultsBackInFinalResponse() async throws {
        // The mock returns a toolUse block on the first call. The
        // ConversationLoop runs the ToolExecutor (= ParagraphAITool
        // stub returns canned text) and re-invokes the connector with
        // the tool result appended. We capture the messages passed to
        // the SECOND connector call (= the re-invocation) and assert
        // the toolResult block is present (= tool output reached the
        // LLM). The final reply is whatever the second scripted
        // response says.
        let connector = RecordingMockConnector(
            scriptedResponses: [
                LLMResponse(
                    id: "r1",
                    model: "mock",
                    blocks: [.toolUse(id: "t1", name: "ParagraphAI", input: "{\"text\":\"input-text\",\"mode\":\"expand\"}")],
                    stopReason: .toolUse,
                    usage: LLMUsage(inputTokens: 1, outputTokens: 1)
                ),
                LLMResponse(
                    id: "r2",
                    model: "mock",
                    blocks: [.text("got-tool-result")],
                    stopReason: .endTurn,
                    usage: LLMUsage(inputTokens: 2, outputTokens: 2)
                )
            ]
        )
        let conductor = try await makeConductor(
            connector: connector,
            tools: ["ParagraphAI": ParagraphAITool.shared]
        )

        let result = await conductor.handle(
            userMessage: "run paragraph",
            sessionId: "default",
            model: "MiniMax-M3"
        )

        // 2 connector calls (= toolUse → re-invoke after tool result).
        let callCount = await connector.callCount
        #expect(callCount >= 2, "ConversationLoop must re-invoke the connector after tool dispatch")
        // The second call's message list must contain a toolResult
        // block (= tool output reached the LLM).
        let secondCallHadToolResult = await connector.secondCallHadToolResult()
        #expect(secondCallHadToolResult, "tool output must be appended to messages before the second LLM call")
        // Final reply is the second scripted text.
        #expect(result.reply == "got-tool-result", "post-tool-dispatch reply must surface verbatim")
    }

    // MARK: - Test 4: multiple tools all registered

    @Test("registering multiple tools makes all of them available for dispatch (= tool registry is the single source)")
    func testConductor_multipleTools_allRegistered() async throws {
        // Each probe increments its own counter. The mock emits a
        // tool_use for one tool per call; across three turns we cover
        // all three tools. After three turns, every probe's counter
        // must have advanced to at least 1 (= every tool in the
        // registry was reachable from the ToolExecutor).
        let toolA = ProbeTool()
        let toolB = ProbeTool()
        let toolC = ProbeTool()
        let connector = RecordingMockConnector(
            scriptedResponses: [
                // Turn 1: emit toolA
                LLMResponse(
                    id: "r1",
                    model: "mock",
                    blocks: [.toolUse(id: "ta", name: "ToolA", input: "{}")],
                    stopReason: .toolUse,
                    usage: LLMUsage(inputTokens: 1, outputTokens: 1)
                ),
                LLMResponse(
                    id: "r2",
                    model: "mock",
                    blocks: [.text("ok-a")],
                    stopReason: .endTurn,
                    usage: LLMUsage(inputTokens: 2, outputTokens: 2)
                ),
                // Turn 2: emit toolB
                LLMResponse(
                    id: "r3",
                    model: "mock",
                    blocks: [.toolUse(id: "tb", name: "ToolB", input: "{}")],
                    stopReason: .toolUse,
                    usage: LLMUsage(inputTokens: 1, outputTokens: 1)
                ),
                LLMResponse(
                    id: "r4",
                    model: "mock",
                    blocks: [.text("ok-b")],
                    stopReason: .endTurn,
                    usage: LLMUsage(inputTokens: 2, outputTokens: 2)
                ),
                // Turn 3: emit toolC
                LLMResponse(
                    id: "r5",
                    model: "mock",
                    blocks: [.toolUse(id: "tc", name: "ToolC", input: "{}")],
                    stopReason: .toolUse,
                    usage: LLMUsage(inputTokens: 1, outputTokens: 1)
                ),
                LLMResponse(
                    id: "r6",
                    model: "mock",
                    blocks: [.text("ok-c")],
                    stopReason: .endTurn,
                    usage: LLMUsage(inputTokens: 2, outputTokens: 2)
                )
            ]
        )
        let conductor = try await makeConductor(
            connector: connector,
            tools: ["ToolA": toolA, "ToolB": toolB, "ToolC": toolC]
        )

        // Three turns, each dispatching a different tool.
        _ = await conductor.handle(userMessage: "a", sessionId: "default", model: "MiniMax-M3")
        _ = await conductor.handle(userMessage: "b", sessionId: "default", model: "MiniMax-M3")
        _ = await conductor.handle(userMessage: "c", sessionId: "default", model: "MiniMax-M3")

        let aCount = await toolA.callCount
        let bCount = await toolB.callCount
        let cCount = await toolC.callCount
        #expect(aCount >= 1, "ToolA in registry must be reachable from the executor")
        #expect(bCount >= 1, "ToolB in registry must be reachable from the executor")
        #expect(cCount >= 1, "ToolC in registry must be reachable from the executor")
    }

    // MARK: - Test fixtures

    /// Build a WenshuConductor with a freshly-bootstrapped KanbanStore
    /// + the supplied connector + tool registry. Centralizes the
    /// boilerplate so each test reads as a focused assertion.
    private func makeConductor(
        connector: any LLMConnector,
        tools: [String: any Tool]
    ) async throws -> WenshuConductor {
        let kanban = try KanbanStore(path: tmpPath("tools-\(UUID().uuidString.prefix(6))"))
        try await kanban.bootstrap()
        return WenshuConductor(
            runtime: AgentRuntime(),
            verifier: WenshuVerifier(),
            kanbanStore: kanban,
            connector: connector,
            tools: tools
        )
    }

    private func tmpPath(_ tag: String) -> String {
        NSTemporaryDirectory() + "wenshu-tool-wiring-\(tag).sqlite"
    }
}

// MARK: - Probe + recording fixtures

/// A minimal `Tool` whose only behavior is to bump a call counter.
/// Used to verify the registry reached the executor AND which tools
/// were dispatched.
actor ProbeTool: Tool {
    private var _count: Int = 0
    var callCount: Int { _count }
    func execute(input: String) async throws -> String {
        _count += 1
        return "probe-ok"
    }
}

/// LLMConnector that records every (messages, options) pair it
/// receives AND serves a scripted sequence of responses. Adds two
/// inspection helpers used by the wiring tests:
///   - callCount: number of .send() invocations (= how many times
///     the connector was called during the handle)
///   - secondCallHadToolResult(): whether the second call's message
///     list contained a `.toolResult` block (= proves tool output
///     reached the LLM)
///   - allToolResults(): every .toolResult output string observed in
///     the recorded message lists (= proves which tools ran + what
///     they returned)
actor RecordingMockConnector: LLMConnector {
    nonisolated public let connectorID: String = "recording-mock"

    public var scriptedResponses: [LLMResponse]
    private var scriptedIndex: Int = 0
    private var receivedCalls: [(messages: [LLMMessage], options: LLMCallOptions)] = []

    public init(scriptedResponses: [LLMResponse]) {
        self.scriptedResponses = scriptedResponses
    }

    public var callCount: Int { receivedCalls.count }

    public func send(messages: [LLMMessage], options: LLMCallOptions) async throws -> LLMResponse {
        receivedCalls.append((messages: messages, options: options))
        if scriptedIndex < scriptedResponses.count {
            let response = scriptedResponses[scriptedIndex]
            scriptedIndex += 1
            return response
        }
        // Fallback: echo the last user message verbatim.
        let echo = messages.last?.blocks.first.flatMap { block -> String? in
            if case .text(let s) = block { return s }
            return nil
        } ?? ""
        return LLMResponse(
            id: "recording-fallback-\(UUID().uuidString)",
            model: options.model,
            blocks: [.text("echo: \(echo)")],
            stopReason: .endTurn,
            usage: LLMUsage(inputTokens: 0, outputTokens: 0)
        )
    }

    /// Whether the second .send() call (= re-invocation after tool
    /// dispatch) saw a `.toolResult` block in its message list.
    public func secondCallHadToolResult() -> Bool {
        guard receivedCalls.count >= 2 else { return false }
        let second = receivedCalls[1]
        return second.messages.contains { msg in
            msg.blocks.contains { block in
                if case .toolResult = block { return true }
                return false
            }
        }
    }

    /// All `.toolResult` output strings observed across every
    /// recorded message list. Used to assert that a specific tool's
    /// output made it through the dispatch path.
    public func allToolResults() -> [String] {
        var results: [String] = []
        for call in receivedCalls {
            for msg in call.messages {
                for block in msg.blocks {
                    if case .toolResult(_, let output) = block {
                        results.append(output)
                    }
                }
            }
        }
        return results
    }
}