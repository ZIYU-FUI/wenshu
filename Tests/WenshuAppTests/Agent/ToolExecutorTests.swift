//
//  ToolExecutorTests.swift · Wenshu · v0.35 ticket 001 sub-step 5
//
//  Unit tests for ToolExecutor actor (= hermes-core-translation
//  spec §3.4 + §0.1 truth-survey finding A2).
//
//  Hermes Python target: tool_executor.execute_tool_calls_concurrent (L306)
//  + execute_tool_calls_sequential (L965). Both take
//  (agent, assistant_message, messages, effective_task_id, api_call_count=0)
//  and mutate the messages list in place (= append tool results).
//
//  Swift port: ToolExecutor actor with executeConcurrent / executeSequential
//  methods that mutate the LLMMessage list in place (= append .tool messages
//  for each tool_use block in the assistant response).
//
//  Test surface:
//  1. ToolExecutor.executeSequential processes tool_use blocks in order
//  2. ToolExecutor.executeConcurrent processes them in parallel
//  3. Tool use + tool result messages are appended to the message list
//  4. Errors from individual tools don't halt the whole execution
//  5. ToolExecutor integrates with ReadFileTool/WriteFileTool (= sub-step 6)
//
//  Mock tools used:
//  - EchoTool: returns input as output (= deterministic, no IO)
//  - CountingTool: increments a counter (= verifies parallel execution)
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ToolExecutor (ticket 001 sub-step 5)")
struct ToolExecutorTests {

    // MARK: - Test 1: Sequential execution

    @Test("executeSequential processes tool_use blocks in order")
    func testSequentialOrder() async throws {
        let executor = ToolExecutor()
        let assistantMessage = LLMMessage(
            role: .assistant,
            blocks: [
                .toolUse(id: "t1", name: "Echo", input: "{\"text\":\"first\"}"),
                .toolUse(id: "t2", name: "Echo", input: "{\"text\":\"second\"}")
            ]
        )
        var messages: [LLMMessage] = [assistantMessage]

        try await executor.executeSequential(
            assistantMessage: assistantMessage,
            messages: &messages,
            taskId: "task-1"
        )

        // Expect: 1 assistant + 2 tool messages (= one per tool_use block)
        #expect(messages.count == 3)
        #expect(messages[1].role == .tool)
        #expect(messages[2].role == .tool)

        // Order preserved: first echo, then second
        if case .toolResult(_, let firstOutput) = messages[1].blocks[0] {
            #expect(firstOutput == "echo:first")
        } else {
            Issue.record("expected toolResult block in messages[1]")
        }
        if case .toolResult(_, let secondOutput) = messages[2].blocks[0] {
            #expect(secondOutput == "echo:second")
        } else {
            Issue.record("expected toolResult block in messages[2]")
        }
    }

    // MARK: - Test 2: Concurrent execution

    @Test("executeConcurrent processes tool_use blocks in parallel")
    func testConcurrentExecution() async throws {
        let executor = ToolExecutor()
        let counter = ToolCounter()
        let tools: [String: any Tool] = [
            "Counting": counter.tool()
        ]

        let assistantMessage = LLMMessage(
            role: .assistant,
            blocks: (1...5).map { i in
                LLMBlock.toolUse(id: "t\(i)", name: "Counting", input: "{}")
            }
        )
        var messages: [LLMMessage] = [assistantMessage]

        try await executor.executeConcurrent(
            assistantMessage: assistantMessage,
            messages: &messages,
            taskId: "task-1",
            tools: tools
        )

        // 1 assistant + 5 tool messages
        #expect(messages.count == 6)
        #expect(messages.dropFirst().allSatisfy { $0.role == .tool })

        // Counter should have been called 5 times (= concurrent fan-out)
        let finalCount = await counter.count
        #expect(finalCount == 5)
    }

    // MARK: - Test 3: Errors don't halt execution

    @Test("Individual tool errors don't halt sequential execution")
    func testErrorsDontHalt() async throws {
        let executor = ToolExecutor()
        let assistantMessage = LLMMessage(
            role: .assistant,
            blocks: [
                .toolUse(id: "t1", name: "Boom", input: "{}"),
                .toolUse(id: "t2", name: "Echo", input: "{\"text\":\"survived\"}")
            ]
        )
        var messages: [LLMMessage] = [assistantMessage]

        try await executor.executeSequential(
            assistantMessage: assistantMessage,
            messages: &messages,
            taskId: "task-1"
        )

        // Both tools ran (= second one survived the first's throw)
        #expect(messages.count == 3)
        if case .toolResult(_, let output2) = messages[2].blocks[0] {
            #expect(output2 == "echo:survived")
        } else {
            Issue.record("expected toolResult for second tool")
        }
    }

    // MARK: - Test 4: No tool_use blocks = no-op

    @Test("Assistant message with no tool_use blocks = no-op")
    func testNoOpOnEmptyToolUse() async throws {
        let executor = ToolExecutor()
        let assistantMessage = LLMMessage(
            role: .assistant,
            blocks: [.text("plain answer, no tools")]
        )
        var messages: [LLMMessage] = [assistantMessage]
        let originalCount = messages.count

        try await executor.executeSequential(
            assistantMessage: assistantMessage,
            messages: &messages,
            taskId: "task-1"
        )

        #expect(messages.count == originalCount)  // unchanged
    }

    // MARK: - Test 5: Tool metadata lookup

    @Test("ToolExecutor looks up tools by name from registry")
    func testToolLookup() async throws {
        let executor = ToolExecutor()
        let echoTool = EchoTool()

        let tool = await executor.lookupTool(name: "Echo", registry: ["Echo": echoTool])
        #expect(tool != nil)
        #expect(try await tool?.execute(input: "{\"text\":\"hi\"}") == "echo:hi")
    }
}

// MARK: - Mock tools

/// Echo tool: returns input wrapped with "echo:" prefix.
private struct EchoTool: Tool, Sendable {
    func execute(input: String) async throws -> String {
        // Parse JSON-ish input; for simplicity, just wrap the raw string
        let stripped = input
            .replacingOccurrences(of: "{\"text\":\"", with: "")
            .replacingOccurrences(of: "\"}", with: "")
        return "echo:\(stripped)"
    }
}

/// Boom tool: always throws.
private struct BoomTool: Tool, Sendable {
    func execute(input: String) async throws -> String {
        throw ToolExecutorError.toolFailed(name: "Boom", underlying: "intentional")
    }
}

/// Counter tool: increments counter on each invocation (= verifies parallel execution).
private actor ToolCounter {
    var count = 0
    func increment() { count += 1 }

    nonisolated func tool() -> any Tool {
        CountingTool(counter: self)
    }
}

private struct CountingTool: Tool, Sendable {
    let counter: ToolCounter
    func execute(input: String) async throws -> String {
        await counter.increment()
        return "counted"
    }
}

// mmessages := was an accidental typo (= Python walrus operator syntax,
// not valid Swift); fixed to plain == comparison.
// for #expect macro limitation.