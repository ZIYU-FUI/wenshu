//
//  ToolExecutorHelpersTests.swift · Wenshu · HERMES-PARTIAL-003 (2026-09-04)
//
//  Round-trip tests for the 6 dispatch helpers + ToolDispatchInputParser.serialize
//  added in HERMES-PARTIAL-003:
//    1. testPermissionGate              — denied tool → denial string + no I/O
//    2. testOutputTruncator             — long output → truncated
//    3. testErrorClassifier             — thrown error → classified message
//    4. testResultFormatter             — output wrapped by formatter
//    5. testPreDispatchValidator        — transformed input reaches tool
//    6. testPostDispatchValidator       — transformed output reaches LLM
//    7. testConcurrentWithHelpers       — concurrent path uses all helpers
//    8. testSerializeRoundTrip          — parse → serialize = stable
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ToolExecutorHelpers (HERMES-PARTIAL-003)")
struct ToolExecutorHelpersTests {

    // MARK: - Test 1: Permission gate

    @Test("Permission gate: denied tool emits denial toolResult without invoking the tool")
    func testPermissionGate() async throws {
        actor CallCounter { var count = 0 }
        let counter = CallCounter()
        let tool = CountingTool(counter: counter)

        let gate: @Sendable (String, String) -> String? = { toolName, _ in
            toolName == "Denied" ? "denied by gate" : nil
        }
        let executor = ToolExecutor(permissionGate: gate)
        let msg = LLMMessage(
            role: .assistant,
            blocks: [.toolUse(id: "t1", name: "Denied", input: "{}")]
        )
        var messages: [LLMMessage] = [msg]

        try await executor.executeSequential(
            assistantMessage: msg,
            messages: &messages,
            taskId: "task-1"
        )

        let calls = await counter.count
        #expect(calls == 0)
        if case .toolResult(_, let output) = messages[1].blocks[0] {
            #expect(output == "denied by gate")
        } else {
            Issue.record("expected toolResult block")
        }
    }

    // MARK: - Test 2: Output truncator

    @Test("Output truncator: long output gets truncated to the configured cap")
    func testOutputTruncator() async throws {
        struct Truncator: Tool, Sendable {
            func execute(input: String) async throws -> String {
                "1234567890abcdef"
            }
        }
        let truncator: @Sendable (String, String) -> String = { output, _ in
            String(output.prefix(5))
        }
        let executor = ToolExecutor(outputTruncator: truncator)
        let msg = LLMMessage(
            role: .assistant,
            blocks: [.toolUse(id: "t1", name: "Truncator", input: "{}")]
        )
        var messages: [LLMMessage] = [msg]

        try await executor.executeSequential(
            assistantMessage: msg,
            messages: &messages,
            taskId: "task-1",
            tools: ["Truncator": Truncator()]
        )

        if case .toolResult(_, let output) = messages[1].blocks[0] {
            #expect(output == "12345")
        } else {
            Issue.record("expected toolResult block")
        }
    }

    // MARK: - Test 3: Error classifier

    @Test("Error classifier: thrown error produces '[classification]: ...' message")
    func testErrorClassifier() async throws {
        struct Boom: Tool, Sendable {
            func execute(input: String) async throws -> String {
                throw ToolExecutorError.toolFailed(name: "Boom", underlying: "test")
            }
        }
        let classifier: @Sendable (String, Error) -> String = { _, _ in "transient" }
        let executor = ToolExecutor(errorClassifier: classifier)
        let msg = LLMMessage(
            role: .assistant,
            blocks: [.toolUse(id: "t1", name: "Boom", input: "{}")]
        )
        var messages: [LLMMessage] = [msg]

        try await executor.executeSequential(
            assistantMessage: msg,
            messages: &messages,
            taskId: "task-1",
            tools: ["Boom": Boom()]
        )

        if case .toolResult(_, let output) = messages[1].blocks[0] {
            #expect(output.hasPrefix("Error [transient]:"))
        } else {
            Issue.record("expected toolResult block")
        }
    }

    // MARK: - Test 4: Result formatter

    @Test("Result formatter: output is wrapped by the formatter closure")
    func testResultFormatter() async throws {
        struct Echo: Tool, Sendable {
            func execute(input: String) async throws -> String { "echo" }
        }
        let formatter: @Sendable (String, String) -> String = { output, toolName in
            "[\(toolName):\(output)]"
        }
        let executor = ToolExecutor(resultFormatter: formatter)
        let msg = LLMMessage(
            role: .assistant,
            blocks: [.toolUse(id: "t1", name: "Echo", input: "{}")]
        )
        var messages: [LLMMessage] = [msg]

        try await executor.executeSequential(
            assistantMessage: msg,
            messages: &messages,
            taskId: "task-1",
            tools: ["Echo": Echo()]
        )

        if case .toolResult(_, let output) = messages[1].blocks[0] {
            #expect(output == "[Echo:echo]")
        } else {
            Issue.record("expected toolResult block")
        }
    }

    // MARK: - Test 5: Pre-dispatch validator

    @Test("Pre-dispatch validator: transformed input reaches the tool")
    func testPreDispatchValidator() async throws {
        struct Capture: Tool, Sendable {
            let capture: () async -> String
            func execute(input: String) async throws -> String {
                await capture()
            }
        }
        actor Captured { var lastInput = "" }
        let captured = Captured()
        let tool = Capture(capture: { await captured.lastInput })

        let validator: @Sendable (String, [String: String]) async throws -> [String: String] = { _, input in
            var out = input
            out["added"] = "by-validator"
            return out
        }
        let executor = ToolExecutor(preDispatchValidator: validator)
        let msg = LLMMessage(
            role: .assistant,
            blocks: [.toolUse(id: "t1", name: "Capture", input: "{\"x\":\"y\"}")]
        )
        var messages: [LLMMessage] = [msg]

        try await executor.executeSequential(
            assistantMessage: msg,
            messages: &messages,
            taskId: "task-1",
            tools: ["Capture": tool]
        )

        let received = await captured.lastInput
        #expect(received.contains("\"added\":\"by-validator\""))
        #expect(received.contains("\"x\":\"y\""))
    }

    // MARK: - Test 6: Post-dispatch validator

    @Test("Post-dispatch validator: transformed output reaches the LLM toolResult")
    func testPostDispatchValidator() async throws {
        struct Echo: Tool, Sendable {
            func execute(input: String) async throws -> String { "raw-output" }
        }
        let validator: @Sendable (String, String) async throws -> String = { _, output in
            "validated(\(output))"
        }
        let executor = ToolExecutor(postDispatchValidator: validator)
        let msg = LLMMessage(
            role: .assistant,
            blocks: [.toolUse(id: "t1", name: "Echo", input: "{}")]
        )
        var messages: [LLMMessage] = [msg]

        try await executor.executeSequential(
            assistantMessage: msg,
            messages: &messages,
            taskId: "task-1",
            tools: ["Echo": Echo()]
        )

        if case .toolResult(_, let output) = messages[1].blocks[0] {
            #expect(output == "validated(raw-output)")
        } else {
            Issue.record("expected toolResult block")
        }
    }

    // MARK: - Test 7: Concurrent path with helpers

    @Test("Concurrent execution honours permission gate + result formatter")
    func testConcurrentWithHelpers() async throws {
        struct Echo: Tool, Sendable {
            func execute(input: String) async throws -> String { "ok" }
        }
        let formatter: @Sendable (String, String) -> String = { output, name in
            "[concurrent:\(name):\(output)]"
        }
        let gate: @Sendable (String, String) -> String? = { toolName, _ in
            toolName == "Skip" ? "skipped-by-gate" : nil
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
            taskId: "task-1",
            tools: ["Echo": Echo()]
        )

        #expect(messages.count == 3)
        if case .toolResult(_, let out1) = messages[1].blocks[0] {
            #expect(out1 == "[concurrent:Echo:ok]")
        }
        if case .toolResult(_, let out2) = messages[2].blocks[0] {
            #expect(out2 == "skipped-by-gate")
        }
    }

    // MARK: - Test 8: Serialize round-trip

    @Test("ToolDispatchInputParser.parse then serialize returns the same envelope")
    func testSerializeRoundTrip() throws {
        let original = "{\"path\":\"/tmp/test.md\",\"mode\":\"read\"}"
        let parsed = ToolDispatchInputParser.parse(original)
        #expect(parsed["path"] == "/tmp/test.md")
        #expect(parsed["mode"] == "read")

        let reSerialized = ToolDispatchInputParser.serialize(parsed)
        let reparsed = ToolDispatchInputParser.parse(reSerialized)
        #expect(reparsed["path"] == "/tmp/test.md")
        #expect(reparsed["mode"] == "read")
    }
}

// MARK: - Mock tools (private to this file)

private actor CallCounter { var count = 0 }

private struct CountingTool: Tool, Sendable {
    let counter: CallCounter
    func execute(input: String) async throws -> String {
        await counter.count += 1
        return "counted"
    }
}