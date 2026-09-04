//
//  ToolDispatchHelpersTests.swift · Wenshu · TICKET-HERMES-GAP-008
//
//  Tests for ToolDispatchHookChain actor + ToolDispatchHook protocol +
//  ToolDispatchInputParser + ToolExecutor integration (= verifies the
//  wire-up around `tool.execute(input:)`, NOT just the chain itself).
//
//  Hermes Python target: agent/tool_dispatch_helpers.py (503 LOC). The
//  wenshu port narrows to the dispatch-hook-chain layer (= pre/post
//  tool call). The other helpers (= parallelism gating, multimodal
//  envelopes, mutation tracking, trajectory normalization) are out
//  of scope for v0.40 and intentionally not tested here (see the
//  ToolDispatchHelpers.swift header for the rationale).
//
//  Test surface:
//    1. testRegisterAndFire: 2 hooks fire on preDispatch; both observe
//       the same (toolName, input).
//    2. testFirePreDispatchThrowsPropagates: throw from preDispatch
//       propagates + short-circuits later hooks (= abort semantics).
//    3. testFirePostDispatchSwallowsErrors: throw from postDispatch is
//       swallowed (= observability contract; never breaks the
//       execution path).
//    4. testToolExecutorWiresDispatchHookChain: ToolExecutor invokes
//       registered dispatch hooks on executeSequential (= proves the
//       wire-up). Also exercises ToolDispatchInputParser via the
//       parsed input arriving at the hook.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ToolDispatchHelpers (TICKET-HERMES-GAP-008)")
struct ToolDispatchHelpersTests {

    // MARK: - Test 1: register + fire

    @Test("register two dispatch hooks; both fire on preDispatch")
    func testRegisterAndFire() async throws {
        let chain = ToolDispatchHookChain()
        let hookA = RecordingDispatchHook(name: "A")
        let hookB = RecordingDispatchHook(name: "B")
        await chain.register(hookA)
        await chain.register(hookB)

        let input: [String: String] = ["path": "/tmp/example.txt"]
        try await chain.firePreDispatch(toolName: "ReadFile", input: input)

        let aCount = await hookA.preCount
        let bCount = await hookB.preCount
        #expect(aCount == 1)
        #expect(bCount == 1)
        let aLast = await hookA.lastPreCall
        let bLast = await hookB.lastPreCall
        #expect(aLast?.toolName == "ReadFile")
        #expect(aLast?.input == input)
        #expect(bLast?.toolName == "ReadFile")
        #expect(bLast?.input == input)

        // unregisterAll clears the chain.
        await chain.unregisterAll()
        try await chain.firePreDispatch(toolName: "ReadFile", input: input)
        let aCount2 = await hookA.preCount
        let bCount2 = await hookB.preCount
        #expect(aCount2 == 1, "unregisterAll stops subsequent fires")
        #expect(bCount2 == 1)
    }

    // MARK: - Test 2: pre throw propagates + short-circuits

    @Test("throw in preDispatch propagates and short-circuits later hooks")
    func testFirePreDispatchThrowsPropagates() async throws {
        let chain = ToolDispatchHookChain()
        let hookA = RecordingDispatchHook(name: "A")
        let hookB = ThrowingDispatchHook(name: "B", message: "blocked by B")
        let hookC = RecordingDispatchHook(name: "C")
        await chain.register(hookA)
        await chain.register(hookB)
        await chain.register(hookC)

        await #expect(throws: ToolDispatchHookTestError.self) {
            try await chain.firePreDispatch(toolName: "WriteFile", input: ["path": "/etc/hosts"])
        }

        let aCount = await hookA.preCount
        let cCount = await hookC.preCount
        #expect(aCount == 1, "A fires first")
        #expect(cCount == 0, "C never fires because B short-circuits")
    }

    // MARK: - Test 3: post throw is swallowed

    @Test("throw in postDispatch is swallowed (observability contract)")
    func testFirePostDispatchSwallowsErrors() async throws {
        let chain = ToolDispatchHookChain()
        let hookA = RecordingDispatchHook(name: "A")
        let hookB = ThrowingDispatchHook(name: "B", message: "post blew up")
        let hookC = RecordingDispatchHook(name: "C")
        await chain.register(hookA)
        await chain.register(hookB)
        await chain.register(hookC)

        // postDispatch must NOT throw — it swallows post-hook errors
        // so observability hooks don't break the tool execution.
        await chain.firePostDispatch(
            toolName: "ReadFile",
            input: ["path": "/tmp/x.txt"],
            output: "file contents"
        )

        let aCount = await hookA.postCount
        let cCount = await hookC.postCount
        #expect(aCount == 1, "A fires first")
        #expect(cCount == 1, "C fires despite B's throw (short-circuit does NOT apply to post)")
    }

    // MARK: - Test 4: ToolExecutor integration + ToolDispatchInputParser

    @Test("ToolExecutor wires dispatch hook chain (pre + post) around tool.execute")
    func testToolExecutorWiresDispatchHookChain() async throws {
        let chain = ToolDispatchHookChain()
        let hook = RecordingDispatchHook(name: "dispatch-observer")
        await chain.register(hook)

        let executor = ToolExecutor(dispatchHookChain: chain)
        let echo = EchoToolForTests()
        let assistant = LLMMessage(
            role: .assistant,
            blocks: [.toolUse(id: "t1", name: "Echo", input: "{\"text\":\"hello\"}")]
        )
        var messages: [LLMMessage] = [assistant]

        try await executor.executeSequential(
            assistantMessage: assistant,
            messages: &messages,
            taskId: "task-1",
            tools: ["Echo": echo]
        )

        let preCount = await hook.preCount
        let postCount = await hook.postCount
        #expect(preCount == 1, "preDispatch fired once")
        #expect(postCount == 1, "postDispatch fired once")

        let pre = await hook.lastPreCall
        let post = await hook.lastPostCall
        #expect(pre?.toolName == "Echo")
        // ToolDispatchInputParser converts {"text":"hello"} → ["text":"hello"].
        #expect(pre?.input == ["text": "hello"])
        #expect(post?.toolName == "Echo")
        #expect(post?.output == "echo:hello")

        // The message list still has the tool result (= dispatch hook
        // did NOT alter the normal flow).
        #expect(messages.count == 2)
        #expect(messages[1].role == .tool)
    }

    // MARK: - Test 4b: ToolDispatchInputParser

    @Test("ToolDispatchInputParser converts valid JSON to [String:String]; invalid = empty")
    func testInputParser() {
        let parsed = ToolDispatchInputParser.parse(#"{"path":"/tmp/x","mode":"read"}"#)
        #expect(parsed == ["path": "/tmp/x", "mode": "read"])

        // Invalid JSON → empty dict (= fall-through).
        let invalid = ToolDispatchInputParser.parse("not json")
        #expect(invalid.isEmpty)

        // Nested objects get JSON-encoded into a single string.
        let nested = ToolDispatchInputParser.parse(#"{"args":{"a":1,"b":[1,2]}}"#)
        #expect(nested["args"] != nil)
        #expect(nested["args"]?.contains("\"a\":1") == true)
    }
}

// MARK: - Test helpers

private struct ToolDispatchHookTestError: Error, Equatable {
    let message: String
}

private actor RecordingDispatchHook: ToolDispatchHook {
    let name: String
    var preCount = 0
    var postCount = 0
    var lastPreCall: (toolName: String, input: [String: String])?
    var lastPostCall: (toolName: String, output: String)?

    init(name: String) { self.name = name }

    func preDispatch(toolName: String, input: [String: String]) async throws {
        preCount += 1
        lastPreCall = (toolName, input)
    }
    func postDispatch(toolName: String, input: [String: String], output: String) async throws {
        postCount += 1
        lastPostCall = (toolName, output)
        _ = input
    }
}

private actor ThrowingDispatchHook: ToolDispatchHook {
    let name: String
    let message: String
    init(name: String, message: String) {
        self.name = name
        self.message = message
    }
    func preDispatch(toolName: String, input: [String: String]) async throws {
        _ = toolName; _ = input
        throw ToolDispatchHookTestError(message: "\(name): preDispatch blocked: \(message)")
    }
    func postDispatch(toolName: String, input: [String: String], output: String) async throws {
        _ = toolName; _ = input; _ = output
        throw ToolDispatchHookTestError(message: "\(name): postDispatch blew up: \(message)")
    }
}

/// Local echo tool (= mirrors `EchoTool` in ToolExecutorTests but kept
/// private to avoid cross-file coupling).
private struct EchoToolForTests: Tool, Sendable {
    func execute(input: String) async throws -> String {
        let stripped = input
            .replacingOccurrences(of: "{\"text\":\"", with: "")
            .replacingOccurrences(of: "\"}", with: "")
        return "echo:\(stripped)"
    }
}
