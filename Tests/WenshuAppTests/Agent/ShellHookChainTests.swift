//
//  ShellHookChainTests.swift · Wenshu · TICKET-HERMES-GAP-004
//
//  Unit tests for ShellHookChain actor + ShellHook protocol +
//  NoopShellHook default + ToolExecutor integration (= hook chain
//  wires into ToolExecutor pre/post-tool-call paths).
//
//  Hermes Python target: agent/shell_hooks.py (928 LOC). The Swift
//  port per spec §2.2 thin-port = extract the hook-chain protocol
//  only (= user scripts optional + default off). These tests pin
//  the Swift actor semantics (= sequential firing, throw propagation,
//  registration-order preservation) so future refactors stay
//  observable.
//
//  Test surface:
//    1. testRegisterAndFire: 2 hooks fire on preToolCall
//    2. testUnregister: only the remaining hook fires
//    3. testUnregisterAll: nothing fires
//    4. testPreToolCallThrowsPropagates: throw propagates + short-circuits
//    5. testPostLLMCallFiresAfterResponse: preLLMCall → LLM → postLLMCall order
//    6. testNoopShellHook: NoopShellHook fires all 6 events without error
//    7. testMultipleHooksOrderedExecution: 3 hooks fire in registration order
//    8. testToolExecutorFiresHookChain: ToolExecutor invokes registered hooks
//       (= integration test that proves the wire-up, NOT just the chain).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ShellHookChain (TICKET-HERMES-GAP-004)")
struct ShellHookChainTests {

    // MARK: - Test 1: register + fire

    @Test("register two hooks; both fire on preToolCall")
    func testRegisterAndFire() async throws {
        let chain = ShellHookChain()
        let hookA = RecordingHook(name: "A")
        let hookB = RecordingHook(name: "B")
        await chain.register(hookA)
        await chain.register(hookB)

        let call = ToolCall(id: "t1", name: "Demo", input: "{}")
        try await chain.firePreToolCall(call)

        let aCount = await hookA.preCount
        let bCount = await hookB.preCount
        #expect(aCount == 1)
        #expect(bCount == 1)
        let aLastCall = await hookA.lastPreCall
        let bLastCall = await hookB.lastPreCall
        #expect(aLastCall == call)
        #expect(bLastCall == call)
    }

    // MARK: - Test 2: unregister

    @Test("unregister one hook; only the remaining fires")
    func testUnregister() async throws {
        let chain = ShellHookChain()
        let hookA = RecordingHook(name: "A")
        let hookB = RecordingHook(name: "B")
        await chain.register(hookA)
        await chain.register(hookB)
        await chain.unregister(hookA)

        let call = ToolCall(id: "t1", name: "Demo", input: "{}")
        try await chain.firePreToolCall(call)

        let aCount = await hookA.preCount
        let bCount = await hookB.preCount
        #expect(aCount == 0, "unregistered hook A should never fire")
        #expect(bCount == 1)
    }

    // MARK: - Test 3: unregisterAll

    @Test("unregisterAll clears chain; nothing fires")
    func testUnregisterAll() async throws {
        let chain = ShellHookChain()
        let hookA = RecordingHook(name: "A")
        let hookB = RecordingHook(name: "B")
        await chain.register(hookA)
        await chain.register(hookB)
        await chain.unregisterAll()

        let call = ToolCall(id: "t1", name: "Demo", input: "{}")
        try await chain.firePreToolCall(call)

        let aCount = await hookA.preCount
        let bCount = await hookB.preCount
        let remaining = await chain.current
        #expect(aCount == 0)
        #expect(bCount == 0)
        #expect(remaining.isEmpty)
    }

    // MARK: - Test 4: throw propagates + short-circuits

    @Test("throw in preToolCall propagates and short-circuits later hooks")
    func testPreToolCallThrowsPropagates() async throws {
        let chain = ShellHookChain()
        let hookA = RecordingHook(name: "A")
        let hookB = ThrowingHook(name: "B", message: "nope")
        let hookC = RecordingHook(name: "C")
        await chain.register(hookA)
        await chain.register(hookB)
        await chain.register(hookC)

        let call = ToolCall(id: "t1", name: "Demo", input: "{}")

        await #expect(throws: ShellHookTestError.self) {
            try await chain.firePreToolCall(call)
        }

        let aCount = await hookA.preCount
        let cCount = await hookC.preCount
        #expect(aCount == 1, "A fires first")
        #expect(cCount == 0, "C never fires because B short-circuits")
    }

    // MARK: - Test 5: preLLMCall + postLLMCall ordering

    @Test("preLLMCall + postLLMCall observe the full LLM cycle")
    func testPostLLMCallFiresAfterResponse() async throws {
        let chain = ShellHookChain()
        let hook = RecordingHook(name: "LLM-Observer")
        await chain.register(hook)

        let request = LLMRequest(
            messages: [LLMMessage.user("hello")],
            options: LLMCallOptions(model: "test-model", maxTokens: 100)
        )
        let response = LLMResponse(
            id: "resp-1",
            model: "test-model",
            blocks: [.text("hi")],
            stopReason: .endTurn,
            usage: LLMUsage(inputTokens: 1, outputTokens: 1)
        )

        try await chain.firePreLLMCall(request)
        // (= simulating the LLM call)
        try await chain.firePostLLMCall(request, response: response)

        let preCount = await hook.preLLMCount
        let postCount = await hook.postLLMCount
        let lastResponse = await hook.lastPostResponse
        #expect(preCount == 1)
        #expect(postCount == 1)
        #expect(lastResponse == response)
    }

    // MARK: - Test 6: NoopShellHook

    @Test("NoopShellHook fires all 6 events without error")
    func testNoopShellHook() async throws {
        let chain = ShellHookChain()
        let noop = NoopShellHook(name: "noop")
        await chain.register(noop)

        let call = ToolCall(id: "t1", name: "Demo", input: "{}")
        let result = ToolResult(toolCallID: "t1", output: "ok")
        let request = LLMRequest(
            messages: [],
            options: LLMCallOptions(model: "x")
        )
        let response = LLMResponse(
            id: "r", model: "x", blocks: [],
            stopReason: .endTurn,
            usage: LLMUsage(inputTokens: 0, outputTokens: 0)
        )

        try await chain.firePreToolCall(call)
        try await chain.firePostToolCall(call, result: result)
        try await chain.firePreLLMCall(request)
        try await chain.firePostLLMCall(request, response: response)
        try await chain.firePreTurn("user msg")
        try await chain.firePostTurn(response)

        // NoopShellHook has no observable state; success = no throw.
        // Verifies the chain survives a no-op subscriber (= important
        // for hot-reload / dynamic-registration patterns).
        let current = await chain.current
        #expect(current.count == 1)
    }

    // MARK: - Test 7: ordered execution

    @Test("multiple hooks fire in registration order")
    func testMultipleHooksOrderedExecution() async throws {
        let chain = ShellHookChain()
        let recorder = OrderRecorder()
        let hook1 = OrderRecordingHook(name: "first", recorder: recorder)
        let hook2 = OrderRecordingHook(name: "second", recorder: recorder)
        let hook3 = OrderRecordingHook(name: "third", recorder: recorder)
        await chain.register(hook1)
        await chain.register(hook2)
        await chain.register(hook3)

        let call = ToolCall(id: "t1", name: "Demo", input: "{}")
        try await chain.firePreToolCall(call)

        let order = await recorder.snapshot()
        #expect(order == ["first", "second", "third"])
    }

    // MARK: - Test 8: integration with ToolExecutor

    @Test("ToolExecutor invokes registered hooks (pre + post)")
    func testToolExecutorFiresHookChain() async throws {
        let chain = ShellHookChain()
        let hook = RecordingHook(name: "ToolEx-Observer")
        await chain.register(hook)

        let executor = ToolExecutor(hookChain: chain)
        let echo = EchoToolForTests()
        let assistant = LLMMessage(
            role: .assistant,
            blocks: [.toolUse(id: "t1", name: "Echo", input: "{\"text\":\"hi\"}")]
        )
        var messages: [LLMMessage] = [assistant]

        try await executor.executeSequential(
            assistantMessage: assistant,
            messages: &messages,
            taskId: "task-1",
            tools: ["Echo": echo]
        )

        // Expect: hook observed pre + post; messages has the tool result
        let preCount = await hook.preCount
        let postCount = await hook.postCount
        #expect(preCount == 1)
        #expect(postCount == 1)
        #expect(messages.count == 2)
        #expect(messages[1].role == .tool)
    }
}

// MARK: - Test hooks + helpers

/// Errors thrown by ThrowingHook during tests.
private struct ShellHookTestError: Error, Equatable {
    let message: String
}

/// Recording hook: counts invocations + stores last-seen payloads.
private actor RecordingHook: ShellHook {
    let name: String
    var preCount = 0
    var postCount = 0
    var preLLMCount = 0
    var postLLMCount = 0
    var lastPreCall: ToolCall?
    var lastPostResult: ToolResult?
    var lastPostResponse: LLMResponse?

    func preToolCall(_ call: ToolCall) async throws {
        preCount += 1
        lastPreCall = call
    }
    func postToolCall(_ call: ToolCall, result: ToolResult) async throws {
        postCount += 1
        lastPostResult = result
        _ = call
    }
    func preLLMCall(_ request: LLMRequest) async throws {
        preLLMCount += 1
        _ = request
    }
    func postLLMCall(_ request: LLMRequest, response: LLMResponse) async throws {
        postLLMCount += 1
        lastPostResponse = response
        _ = request
    }
    func preTurn(_ userMessage: String) async throws { _ = userMessage }
    func postTurn(_ response: LLMResponse) async throws { _ = response }
}

/// Hook that always throws (= used to verify propagation + short-circuit).
private actor ThrowingHook: ShellHook {
    let name: String
    let message: String
    init(name: String, message: String) {
        self.name = name
        self.message = message
    }
    func preToolCall(_ call: ToolCall) async throws {
        throw ShellHookTestError(message: "\(name): preToolCall(\(call.name)) rejected: \(message)")
    }
    func postToolCall(_ call: ToolCall, result: ToolResult) async throws {
        _ = call; _ = result
    }
    func preLLMCall(_ request: LLMRequest) async throws { _ = request }
    func postLLMCall(_ request: LLMRequest, response: LLMResponse) async throws {
        _ = request; _ = response
    }
    func preTurn(_ userMessage: String) async throws { _ = userMessage }
    func postTurn(_ response: LLMResponse) async throws { _ = response }
}

/// Shared recorder for ordered-execution test (= multiple hooks share
/// one recorder to assert registration order).
private actor OrderRecorder {
    var seen: [String] = []
    func record(_ name: String) { seen.append(name) }
    func snapshot() -> [String] { seen }
}

/// Hook that records its `name` into a shared recorder on each fire.
private actor OrderRecordingHook: ShellHook {
    let name: String
    let recorder: OrderRecorder
    init(name: String, recorder: OrderRecorder) {
        self.name = name
        self.recorder = recorder
    }
    func preToolCall(_ call: ToolCall) async throws {
        await recorder.record(name)
        _ = call
    }
    func postToolCall(_ call: ToolCall, result: ToolResult) async throws {
        _ = call; _ = result
    }
    func preLLMCall(_ request: LLMRequest) async throws { _ = request }
    func postLLMCall(_ request: LLMRequest, response: LLMResponse) async throws {
        _ = request; _ = response
    }
    func preTurn(_ userMessage: String) async throws { _ = userMessage }
    func postTurn(_ response: LLMResponse) async throws { _ = response }
}

/// Minimal echo tool for the integration test (= local mirror of the
/// one in ToolExecutorTests, kept private to avoid cross-file coupling).
private struct EchoToolForTests: Tool, Sendable {
    func execute(input: String) async throws -> String {
        let stripped = input
            .replacingOccurrences(of: "{\"text\":\"", with: "")
            .replacingOccurrences(of: "\"}", with: "")
        return "echo:\(stripped)"
    }
}