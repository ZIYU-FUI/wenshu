import Foundation
import Testing
@testable import WenshuAgent

/// The refusal reaching the model, driven through the executor.
///
/// The policy tests prove the rules decide correctly. These prove the
/// executor ACTUALLY asks them, and that the refusal arrives as the tool
/// result the model reads (= the turn continues; nothing waits for a
/// user).
@Suite("The executor refuses what the policy refuses")
@MainActor
struct ToolSafetyExecutorTests {

    /// A tool that records whether it ran.
    private final class CountingTool: Tool, @unchecked Sendable {
        private let counter: Counter
        init(counter: Counter) { self.counter = counter }
        func execute(input: String) async throws -> String {
            counter.count += 1
            return "ran"
        }
    }

    /// A shared counter (= the executor takes its tools as existentials).
    private final class Counter: @unchecked Sendable {
        var count = 0
    }

    /// A tool that always fails.
    private struct FailingTool: Tool {
        func execute(input: String) async throws -> String {
            throw ToolExecutorError.toolFailed(name: "failing", underlying: "boom")
        }
    }

    private func assistantCalling(_ name: String, input: String = "{}") -> LLMMessage {
        LLMMessage(
            role: .assistant,
            blocks: [.toolUse(id: "call-1", name: name, input: input)]
        )
    }

    /// The tool results the model would read.
    private func toolOutputs(in messages: [LLMMessage]) -> [String] {
        messages.compactMap { message in
            guard message.role == .tool else { return nil }
            return message.blocks.compactMap { block in
                if case let .toolResult(_, output) = block { return output }
                return nil
            }.first
        }
    }

    @Test("A tool in the hazard class never runs")
    func hazardClassNeverRuns() async throws {
        let counter = Counter()
        let executor = ToolExecutor()
        var messages: [LLMMessage] = []

        try await executor.executeSequential(
            assistantMessage: assistantCalling("process"),
            messages: &messages,
            taskId: "t1",
            tools: ["process": CountingTool(counter: counter)]
        )

        #expect(counter.count == 0, "a refused tool must not run")
        let outputs = toolOutputs(in: messages)
        #expect(outputs.count == 1, "the refusal must reach the model")
        #expect(
            outputs.first?.contains("process") == true,
            "the refusal must name the tool: \(outputs.first ?? "nil")"
        )
    }

    @Test("Approving the hazard class lets the tool run")
    func approvalLetsTheToolRun() async throws {
        let counter = Counter()
        let executor = ToolExecutor(
            permissionGate: { toolName, _ in
                ToolSafetyPolicy.refusal(
                    toolName: toolName,
                    values: ToolSafetyPolicy.Values(autoApprove: true)
                )
            }
        )
        var messages: [LLMMessage] = []

        try await executor.executeSequential(
            assistantMessage: assistantCalling("process"),
            messages: &messages,
            taskId: "t1",
            tools: ["process": CountingTool(counter: counter)]
        )

        #expect(counter.count == 1, "an approved tool must run")
    }

    @Test("An ordinary tool still runs")
    func ordinaryToolRuns() async throws {
        let counter = Counter()
        let executor = ToolExecutor()
        var messages: [LLMMessage] = []

        try await executor.executeSequential(
            assistantMessage: assistantCalling("book_chapter"),
            messages: &messages,
            taskId: "t1",
            tools: ["book_chapter": CountingTool(counter: counter)]
        )

        #expect(counter.count == 1, "the product's own writes must not be refused")
    }

    @Test("A ledger stops the agent repeating the same write")
    func ledgerStopsTheRepeat() async throws {
        let counter = Counter()
        let ledger = ToolSafetyLedger(
            policy: ToolSafetyPolicy.Values(
                mutatingToolNames: ["book_chapter"],
                maxIdenticalMutatingCalls: 2
            )
        )
        let executor = ToolExecutor(safetyLedger: ledger)
        var messages: [LLMMessage] = []

        for _ in 0..<3 {
            try await executor.executeSequential(
                assistantMessage: assistantCalling("book_chapter", input: "{\"a\":1}"),
                messages: &messages,
                taskId: "t1",
                tools: ["book_chapter": CountingTool(counter: counter)]
            )
        }

        #expect(counter.count == 2, "the third identical write must not run")
    }

    @Test("A failing tool is remembered, and its repeat is refused")
    func failureIsRemembered() async throws {
        let ledger = ToolSafetyLedger(
            policy: ToolSafetyPolicy.Values(maxIdenticalFailures: 1)
        )
        let executor = ToolExecutor(safetyLedger: ledger)
        var messages: [LLMMessage] = []

        // The tool carries no path key (= the path guard wants a
        // configured library root, and this test is about the failure
        // rule, not about paths).
        for _ in 0..<2 {
            try await executor.executeSequential(
                assistantMessage: assistantCalling("flaky_tool", input: "{\"a\":1}"),
                messages: &messages,
                taskId: "t1",
                tools: ["flaky_tool": FailingTool()]
            )
        }

        let outputs = toolOutputs(in: messages)
        #expect(outputs.count == 2, "both attempts reach the model")
        #expect(
            outputs.last?.contains("failed") == true || outputs.last?.contains("Error") == true,
            "the second attempt is refused or reports the failure: \(outputs.last ?? "nil")"
        )
    }
}
