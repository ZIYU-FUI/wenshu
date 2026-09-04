//
//  ToolExecutor.swift · Wenshu · v0.35 ticket 001 sub-step 5
//                          TICKET-HERMES-GAP-004 (hook chain wiring)
//
//  Tool dispatch actor. Maps to hermes tool_executor.py
//  (= execute_tool_calls_concurrent at L306, execute_tool_calls_sequential
//  at L965).
//
//  Both hermes entry points take
//  (agent, assistant_message, messages, effective_task_id, api_call_count=0)
//  and mutate the `messages` list in place (= append .tool messages for
//  each tool_use block in the assistant response).
//
//  Swift port preserves this in-place mutation pattern:
//    - executeConcurrent(assistantMessage:messages:taskId:apiCallCount:tools:)
//      runs tool_use blocks in parallel via TaskGroup
//    - executeSequential(assistantMessage:messages:taskId:apiCallCount:tools:)
//      runs tool_use blocks one at a time
//
//  Both methods:
//    1. Extract .toolUse blocks from assistantMessage
//    2. Look up each tool by name from the registry
//    3. Fire ShellHookChain.preToolCall (= TICKET-HERMES-GAP-004)
//    4. Invoke tool.execute(input:) (= returns String output)
//    5. Fire ShellHookChain.postToolCall (= TICKET-HERMES-GAP-004)
//    6. Build .toolResult(toolUseID:output:) LLMBlock + wrap in .tool LLMMessage
//    7. Append to messages list
//
//  Errors from individual tools are caught + reported as toolResult
//  with isError flag (= hermes _emit_terminal_post_tool_call pattern).
//  Hook chain defaults to empty (= no behavior change without registered
//  hooks; existing callers using `init()` are unaffected).
//
//  v0.35 sub-step 5 of 8 for ticket 001.
//

import Foundation

public actor ToolExecutor {

    /// Lifecycle hook chain (= TICKET-HERMES-GAP-004). Default = empty
    /// (= `firePreToolCall` / `firePostToolCall` are no-ops on an empty
    /// registry). Inject hooks via `init(hookChain:)`.
    public let hookChain: ShellHookChain

    /// Initializer that accepts an optional pre-configured hook chain.
    /// Omitting the argument = `ShellHookChain()` = empty registry =
    /// identical behavior to the pre-GAP-004 no-arg `init()`.
    public init(hookChain: ShellHookChain = ShellHookChain()) {
        self.hookChain = hookChain
    }

    /// Run tool_use blocks sequentially (= one at a time, in order).
    ///
    /// - Parameters:
    ///   - assistantMessage: The assistant response containing .toolUse blocks.
    ///   - messages: Mutable reference to the message list (= tool result
    ///     messages are appended in order).
    ///   - taskId: Per-turn task identifier (= for tracing).
    ///   - apiCallCount: Current API call count (= passed through to
    ///     hermes `api_call_count` for budget tracking).
    ///   - tools: Registry of available tools (= name → Tool).
    public func executeSequential(
        assistantMessage: LLMMessage,
        messages: inout [LLMMessage],
        taskId: String,
        apiCallCount: Int = 0,
        tools: [String: any Tool] = [:]
    ) async throws {
        let toolUseBlocks = assistantMessage.blocks.compactMap { block -> (String, String, String)? in
            if case .toolUse(let id, let name, let input) = block {
                return (id, name, input)
            }
            return nil
        }

        for (toolUseID, toolName, input) in toolUseBlocks {
            let call = ToolCall(id: toolUseID, name: toolName, input: input)
            // TICKET-HERMES-GAP-004: fire pre-tool-call hook BEFORE
            // dispatch (= throw propagates and aborts the loop). Empty
            // chain = no-op, so behavior is identical to pre-GAP-004.
            try await hookChain.firePreToolCall(call)

            let output: String
            var didError = false
            do {
                if let tool = tools[toolName] {
                    output = try await tool.execute(input: input)
                } else if let tool = await lookupTool(name: toolName, registry: tools) {
                    output = try await tool.execute(input: input)
                } else {
                    output = "Error: tool '\\(toolName)' not found"
                    didError = true
                    _ = ToolExecutorError.toolNotFound(name: toolName)
                }
            } catch {
                output = "Error: \\(error.localizedDescription)"
                didError = true
                _ = error
            }

            // TICKET-HERMES-GAP-004: fire post-tool-call hook AFTER
            // dispatch (= observes success or error). Empty chain =
            // no-op.
            let result = ToolResult(toolCallID: toolUseID, output: output, isError: didError)
            try await hookChain.firePostToolCall(call, result: result)

            let toolMessage = LLMMessage(
                role: .tool,
                blocks: [.toolResult(toolUseID: toolUseID, output: output)]
            )
            messages.append(toolMessage)
        }
    }

    /// Run tool_use blocks concurrently (= all in parallel via TaskGroup).
    ///
    /// Same signature as executeSequential but uses withTaskGroup to fan
    /// out tool invocations. Results are appended to messages in the order
    /// tool_use blocks appear in the assistant message (= hermes preserves
    /// tool ordering regardless of execution parallelism).
    public func executeConcurrent(
        assistantMessage: LLMMessage,
        messages: inout [LLMMessage],
        taskId: String,
        apiCallCount: Int = 0,
        tools: [String: any Tool] = [:]
    ) async throws {
        let toolUseBlocks = assistantMessage.blocks.compactMap { block -> (String, String, String)? in
            if case .toolUse(let id, let name, let input) = block {
                return (id, name, input)
            }
            return nil
        }

        // Capture results in order (= index + output)
        struct IndexedOutput {
            let index: Int
            let toolUseID: String
            let output: String
        }

        let outputs: [IndexedOutput] = await withTaskGroup(of: IndexedOutput.self) { group in
            for (index, (toolUseID, toolName, input)) in toolUseBlocks.enumerated() {
                group.addTask {
                    // TICKET-HERMES-GAP-004: fire pre-tool-call hook
                    // BEFORE dispatch. Task inherits ToolExecutor's
                    // actor context, so `hookChain` access is safe.
                    let call = ToolCall(id: toolUseID, name: toolName, input: input)
                    do {
                        try await self.hookChain.firePreToolCall(call)
                    } catch {
                        // Hook rejected the call; report via toolResult
                        // so the LLM can see the rejection reason.
                        let rejectionOutput = "Error: pre-tool-call hook rejected: \\(error.localizedDescription)"
                        return IndexedOutput(index: index, toolUseID: toolUseID, output: rejectionOutput)
                    }

                    let output: String
                    var didError = false
                    do {
                        if let tool = tools[toolName] {
                            output = try await tool.execute(input: input)
                        } else {
                            output = "Error: tool '\\(toolName)' not found"
                            didError = true
                            _ = ToolExecutorError.toolNotFound(name: toolName)
                        }
                    } catch {
                        output = "Error: \\(error.localizedDescription)"
                        didError = true
                        _ = error
                    }

                    // TICKET-HERMES-GAP-004: fire post-tool-call hook
                    // AFTER dispatch. Errors here are caught (= hermes
                    // post-hook errors don't break tool execution).
                    do {
                        let result = ToolResult(toolCallID: toolUseID, output: output, isError: didError)
                        try await self.hookChain.firePostToolCall(call, result: result)
                    } catch {
                        // Swallow post-hook errors (= observability
                        // hooks must not break the tool execution path).
                        _ = error
                    }
                    return IndexedOutput(index: index, toolUseID: toolUseID, output: output)
                }
            }

            var collected: [IndexedOutput] = []
            for await result in group {
                collected.append(result)
            }
            return collected.sorted { $0.index < $1.index }
        }

        for result in outputs {
            let toolMessage = LLMMessage(
                role: .tool,
                blocks: [.toolResult(toolUseID: result.toolUseID, output: result.output)]
            )
            messages.append(toolMessage)
        }
    }

    /// Look up a tool by name from the registry (= thin wrapper around
    /// Swift dict lookup with async boundary for actor isolation).
    public func lookupTool(name: String, registry: [String: any Tool]) -> (any Tool)? {
        registry[name]
    }
}