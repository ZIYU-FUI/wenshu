//
//  ToolExecutorStreamCallbackTests.swift · Wenshu · T2-TOOL-UI (2026-09-18)
//
//  Verifies ToolExecutor emits .toolUse + .toolResult LLMBlocks via
//  the streamCallback parameter (= the fix that lets ChatView's
//  ChatToolUsePartView / ChatToolResultPartView cards appear live).
//
//  Before T2: ToolExecutor returned blocks only inside
//  ConversationResult.blocks[] at end of turn; = ChatView never saw
//  tool cards during streaming (= silent "one-shot reply" symptom).
//
//  After T2: ToolExecutor.executeSequential accepts streamCallback and
//  emits each toolUse before running + each toolResult after running.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ToolExecutor streamCallback (T2-TOOL-UI)")
struct ToolExecutorStreamCallbackTests {

    /// T2 contract: when streamCallback is provided, ToolExecutor
    /// emits a .toolUse block before running the tool + a .toolResult
    /// block after. ChatView's ChatToolUsePartView + ChatToolResultPartView
    /// then render live.
    @Test func streamCallback_receives_toolUse_then_toolResult() async throws {
        // Mock tool: returns a fixed string when executed.
        struct EchoTool: Tool {
            func execute(input: String) async throws -> String {
                "echoed:\(input)"
            }
        }
        // Build an assistant LLMMessage with a toolUse block.
        let assistant = LLMMessage(
            role: .assistant,
            blocks: [.toolUse(id: "test-1", name: "echo_tool", input: "{\"x\":1}")]
        )
        var messages: [LLMMessage] = [assistant]
        // Capture what streamCallback receives.
        actor Sink {
            var blocks: [LLMBlock] = []
            func append(_ b: LLMBlock) { blocks.append(b) }
            func snapshot() -> [LLMBlock] { blocks }
        }
        let sink = Sink()
        let cb: @Sendable (LLMBlock) async -> Void = { block in
            await sink.append(block)
        }
        // Run.
        let executor = ToolExecutor()
        try await executor.executeSequential(
            assistantMessage: assistant,
            messages: &messages,
            taskId: "test-task",
            tools: ["echo_tool": EchoTool()],
            streamCallback: cb
        )
        // Verify: streamCallback received .toolUse BEFORE the tool ran + .toolResult AFTER.
        let received = await sink.snapshot()
        #expect(received.count >= 2, "expected at least 2 blocks, got \(received.count)")
        // First block must be .toolUse (T2 emits toolUse before execution)
        if case .toolUse(let id, let name, _) = received[0] {
            #expect(id == "test-1")
            #expect(name == "echo_tool")
        } else {
            Issue.record("expected first block to be .toolUse, got \(received[0])")
        }
        // Last block must be .toolResult (T2 emits toolResult after execution)
        if case .toolResult(let toolUseID, let output) = received.last {
            #expect(toolUseID == "test-1")
            #expect(output.contains("echoed:"))
        } else {
            Issue.record("expected last block to be .toolResult, got \(String(describing: received.last))")
        }
    }

    /// T2 contract: when streamCallback is nil (= legacy callers), the
    /// tool still runs + tool_result still appends to messages (= no
    /// behavior regression for callers that don't opt in).
    @Test func nil_streamCallback_still_appends_to_messages() async throws {
        struct EchoTool: Tool {
            func execute(input: String) async throws -> String { "ok" }
        }
        let assistant = LLMMessage(
            role: .assistant,
            blocks: [.toolUse(id: "no-cb-1", name: "echo_tool", input: "{}")]
        )
        var messages: [LLMMessage] = [assistant]
        let executor = ToolExecutor()
        try await executor.executeSequential(
            assistantMessage: assistant,
            messages: &messages,
            taskId: "test-task",
            tools: ["echo_tool": EchoTool()],
            streamCallback: nil  // legacy caller
        )
        // Tool result must still be in messages (= no regression).
        let lastMessage = messages.last
        #expect(lastMessage?.role == .tool)
        if case .toolResult(let id, let output) = lastMessage?.blocks.first {
            #expect(id == "no-cb-1")
            #expect(output == "ok")
        } else {
            Issue.record("expected .toolResult in messages, got \(String(describing: lastMessage?.blocks.first))")
        }
    }
}