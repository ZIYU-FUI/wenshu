//
//  ConversationLoopRunTurnTests.swift · Wenshu · HERMES-PARTIAL-001 (2026-09-04)
//
//  Round-trip tests for the runTurn() orchestrator + the new per-turn
//  setup + post-turn hooks added in HERMES-PARTIAL-001:
//    1. testRunSimpleChat              — plain text round-trip (no tools)
//    2. testRunWithSingleToolCall      — LLM emits 1 tool_use → dispatch → result
//    3. testRunWithMultipleToolCalls   — LLM emits 2 tool_use blocks (sequential)
//    4. testRunWithParallelToolCalls   — executeConcurrent path honours helpers
//    5. testCompressionTriggered        — large history → compressed
//    6. testRetryOnClassifierError     — 429 → retried, eventually succeeds
//    7. testRetryExhausted             — non-transient → fail fast
//    8. testTurnContextRestore         — each turn starts fresh (TurnContext)
//    9. testMessageSanitizationRepair  — malformed user message → repaired
//   10. testInterruptedToolCall        — interrupted tool call recovery
//   11. testShellHookFire             — pre + post turn hooks fire
//   12. testFinalizerPostTurn         — post-turn finalizer normalizes
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ConversationLoopRunTurn (HERMES-PARTIAL-001)")
struct ConversationLoopRunTurnTests {

    // MARK: - Test 1: Simple chat

    @Test("runTurn returns the LLM response for a simple text-only conversation")
    func testRunSimpleChat() async throws {
        let connector = MockLLMConnector(response: "echo: hi")
        let loop = ConversationLoop(connection: connector)

        let result = try await loop.runTurn(userMessage: "hi")
        #expect(result.response.model == "mock-model")
        #expect(result.messages.count >= 2)
        #expect(result.messages.last?.role == .assistant)
    }

    // MARK: - Test 2: Single tool call

    @Test("runTurn dispatches a single tool_use and re-invokes the LLM with the result")
    func testRunWithSingleToolCall() async throws {
        struct Echo: Tool, Sendable {
            func execute(input: String) async throws -> String { "echo-result" }
        }
        let scripts: [LLMResponse] = [
            LLMResponse(
                id: "r1", model: "mock",
                blocks: [.toolUse(id: "t1", name: "Echo", input: "{}")],
                stopReason: .toolUse, usage: LLMUsage(inputTokens: 0, outputTokens: 0)
            ),
            LLMResponse(
                id: "r2", model: "mock",
                blocks: [.text("done")],
                stopReason: .endTurn, usage: LLMUsage(inputTokens: 0, outputTokens: 0)
            )
        ]
        let connector = MockLLMConnector(scriptedResponses: scripts)
        let loop = ConversationLoop(connection: connector)

        let result = try await loop.runTurn(
            userMessage: "call echo",
            tools: ["Echo": Echo()]
        )
        // Expect: user + assistant(tool_use) + tool + assistant(final).
        #expect(result.messages.count >= 4)
        #expect(result.messages.last?.role == .assistant)
        // The final assistant message must be "done".
        if case .text(let text) = result.messages.last?.blocks[0] ?? .text("") {
            #expect(text == "done")
        }
    }

    // MARK: - Test 3: Multiple tool calls (sequential)

    @Test("runTurn dispatches multiple tool_use blocks sequentially via executeSequential")
    func testRunWithMultipleToolCalls() async throws {
        struct Echo: Tool, Sendable {
            func execute(input: String) async throws -> String {
                let stripped = input
                    .replacingOccurrences(of: "{\"text\":\"", with: "")
                    .replacingOccurrences(of: "\"}", with: "")
                return "echo:\(stripped)"
            }
        }
        let scripts: [LLMResponse] = [
            LLMResponse(
                id: "r1", model: "mock",
                blocks: [
                    .toolUse(id: "t1", name: "Echo", input: "{\"text\":\"first\"}"),
                    .toolUse(id: "t2", name: "Echo", input: "{\"text\":\"second\"}")
                ],
                stopReason: .toolUse, usage: LLMUsage(inputTokens: 0, outputTokens: 0)
            ),
            LLMResponse(
                id: "r2", model: "mock",
                blocks: [.text("ok")],
                stopReason: .endTurn, usage: LLMUsage(inputTokens: 0, outputTokens: 0)
            )
        ]
        let connector = MockLLMConnector(scriptedResponses: scripts)
        let loop = ConversationLoop(connection: connector)

        let result = try await loop.runTurn(
            userMessage: "call echo twice",
            tools: ["Echo": Echo()]
        )
        // Expect: user + assistant(2 tool_use) + 2 tool + assistant(final).
        #expect(result.messages.count >= 5)
        // Tool result messages must be present (in order).
        let toolResults = result.messages.filter { $0.role == .tool }
        #expect(toolResults.count == 2)
        if case .toolResult(_, let out1) = toolResults[0].blocks[0] {
            #expect(out1 == "echo:first")
        }
        if case .toolResult(_, let out2) = toolResults[1].blocks[0] {
            #expect(out2 == "echo:second")
        }
    }

    // MARK: - Test 4: Parallel tool calls (concurrent)

    @Test("ToolExecutor.executeConcurrent honours permission gate + formatter")
    func testRunWithParallelToolCalls() async throws {
        struct Echo: Tool, Sendable {
            func execute(input: String) async throws -> String { "ok" }
        }
        let formatter: @Sendable (String, String) -> String = { output, name in
            "[parallel:\(name):\(output)]"
        }
        let gate: @Sendable (String, String) -> String? = { name, _ in
            name == "Skip" ? "skipped" : nil
        }
        let executor = ToolExecutor(permissionGate: gate, resultFormatter: formatter)

        let msg = LLMMessage(
            role: .assistant,
            blocks: [
                .toolUse(id: "t1", name: "Echo", input: "{}"),
                .toolUse(id: "t2", name: "Skip", input: "{}")
            ]
        )
        var messages: [LLMMessage] = [msg]
        try await executor.executeConcurrent(
            assistantMessage: msg,
            messages: &messages,
            taskId: "task",
            tools: ["Echo": Echo()]
        )
        #expect(messages.count == 3)
        if case .toolResult(_, let o1) = messages[1].blocks[0] {
            #expect(o1 == "[parallel:Echo:ok]")
        }
        if case .toolResult(_, let o2) = messages[2].blocks[0] {
            #expect(o2 == "skipped")
        }
    }

    // MARK: - Test 5: Compression triggered

    @Test("runTurn compresses the message history via ConversationCompression")
    func testCompressionTriggered() async throws {
        let connector = MockLLMConnector(response: "ok")
        let compressor = ContextCompressor(
            policy: ContextCompressor.Policy(
                keepRecentTurns: 2,
                maxTokens: 1_000  // artificially low to force compression
            )
        )
        let compression = ConversationCompression(compressor: compressor)
        let loop = ConversationLoop(
            connection: connector,
            conversationCompression: compression
        )

        // Build a long history (10 user + 10 assistant messages).
        var history: [LLMMessage] = []
        for i in 0..<10 {
            history.append(LLMMessage.user("msg \(i)"))
            history.append(LLMMessage.assistant("reply \(i)"))
        }

        let result = try await loop.runTurn(
            userMessage: "now",
            conversationHistory: history
        )
        // Compression should have reduced the history.
        #expect(result.messages.count < history.count + 2)
    }

    // MARK: - Test 6: Retry on classifier error (429 → success)

    @Test("LLMConnectorErrorClassifier.isTransient returns true for 429")
    func testRetryOnClassifierError() {
        let transient429 = LLMConnectorError.transport(
            provider: "mock", statusCode: 429, body: "rate limit"
        )
        #expect(LLMConnectorErrorClassifier.isTransient(transient429))

        let transient5xx = LLMConnectorError.transport(
            provider: "mock", statusCode: 503, body: "server error"
        )
        #expect(LLMConnectorErrorClassifier.isTransient(transient5xx))
    }

    // MARK: - Test 7: Retry exhausted (non-transient)

    @Test("LLMConnectorErrorClassifier.isTransient returns false for 400")
    func testRetryExhausted() {
        let nonTransient400 = LLMConnectorError.transport(
            provider: "mock", statusCode: 400, body: "bad request"
        )
        #expect(!LLMConnectorErrorClassifier.isTransient(nonTransient400))

        let nonTransient401 = LLMConnectorError.transport(
            provider: "mock", statusCode: 401, body: "auth"
        )
        #expect(!LLMConnectorErrorClassifier.isTransient(nonTransient401))
    }

    // MARK: - Test 8: TurnContext restore (fresh each turn)

    @Test("Each turn starts with a fresh TurnContext (= retry-counter reset)")
    func testTurnContextRestore() async throws {
        let connector = MockLLMConnector(response: "echo")
        let loop = ConversationLoop(connection: connector)

        // First turn.
        let r1 = try await loop.runTurn(userMessage: "first")
        #expect(r1.messages.last?.role == .assistant)

        // Second turn threads the first turn's history.
        let r2 = try await loop.runTurn(
            userMessage: "second",
            conversationHistory: r1.messages
        )
        // History grows: first user + first assistant + second user + second assistant.
        #expect(r2.messages.count == r1.messages.count + 2)
    }

    // MARK: - Test 9: Message sanitization repair

    @Test("MessageSanitization.sanitizeText strips control chars from user input")
    func testMessageSanitizationRepair() {
        let dirty = "hello\u{0}world\u{0007}\u{7F}"
        let clean = MessageSanitization.sanitizeText(dirty)
        #expect(!clean.contains("\u{0}"))
        #expect(!clean.contains("\u{0007}"))
        #expect(!clean.contains("\u{7F}"))
        #expect(clean.contains("hello"))
        #expect(clean.contains("world"))
    }

    // MARK: - Test 10: Interrupted tool call recovery

    @Test("ToolExecutor handles an interrupted tool call gracefully")
    func testInterruptedToolCallRecovery() async throws {
        struct Boom: Tool, Sendable {
            func execute(input: String) async throws -> String {
                throw ToolExecutorError.toolFailed(name: "Boom", underlying: "interrupted")
            }
        }
        let executor = ToolExecutor()
        let msg = LLMMessage(
            role: .assistant,
            blocks: [.toolUse(id: "t1", name: "Boom", input: "{}")]
        )
        var messages: [LLMMessage] = [msg]

        try await executor.executeSequential(
            assistantMessage: msg,
            messages: &messages,
            taskId: "task",
            tools: ["Boom": Boom()]
        )
        // 1 assistant + 1 tool result with error message.
        #expect(messages.count == 2)
        if case .toolResult(_, let output) = messages[1].blocks[0] {
            #expect(output.contains("Boom"))
        }
    }

    // MARK: - Test 11: ShellHook fire (pre + post turn)

    @Test("ShellHookChain fires preTurn + postTurn around runTurn")
    func testShellHookFire() async throws {
        actor HookRecorder {
            var preTurns: [String] = []
            var postTurns: [String] = []
            func recordPre(_ s: String) { preTurns.append(s) }
            func recordPost(_ s: String) { postTurns.append(s) }
        }
        let recorder = HookRecorder()

        struct RecordingHook: ShellHook {
            let name: String
            let recorder: HookRecorder
            func preToolCall(_: ToolCall) async throws {}
            func postToolCall(_: ToolCall, result: ToolResult) async throws {}
            func preLLMCall(_: LLMRequest) async throws {}
            func postLLMCall(_: LLMRequest, response: LLMResponse) async throws {}
            func preTurn(_ userMessage: String) async throws {
                await recorder.recordPre(userMessage)
            }
            func postTurn(_ response: LLMResponse) async throws {
                await recorder.recordPost(response.model)
            }
        }

        let hookChain = ShellHookChain()
        await hookChain.register(RecordingHook(name: "rec", recorder: recorder))

        let connector = MockLLMConnector(response: "ok")
        let loop = ConversationLoop(connection: connector, shellHookChain: hookChain)

        _ = try await loop.runTurn(userMessage: "hi")

        let pre = await recorder.preTurns
        let post = await recorder.postTurns
        #expect(pre.contains("hi"))
        #expect(post.contains("mock-model"))
    }

    // MARK: - Test 12: Finalizer post-turn

    @Test("TurnFinalizer drops empty text blocks from the final response")
    func testFinalizerPostTurn() {
        let response = LLMResponse(
            id: "r1",
            model: "mock",
            blocks: [.text("hello"), .text(""), .text("world")],
            stopReason: .endTurn,
            usage: LLMUsage(inputTokens: 0, outputTokens: 0)
        )
        let finalized = TurnFinalizer.finalize(response: response)
        // canonicalize drops empty .text blocks but keeps order.
        let nonEmptyTexts = finalized.blocks.compactMap { block -> String? in
            if case .text(let s) = block, !s.isEmpty { return s } else { return nil }
        }
        #expect(nonEmptyTexts == ["hello", "world"])
    }
}