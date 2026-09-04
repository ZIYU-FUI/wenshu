//
//  ToolExecutor.swift · Wenshu · v0.35 ticket 001 sub-step 5
//                          TICKET-HERMES-GAP-004 (hook chain wiring)
//                          TICKET-HERMES-GAP-008 (dispatch hook chain)
//                          HERMES-PARTIAL-003 (2026-09-04, 6 helpers wired)
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
//  Per-tool-call pipeline (HERMES-PARTIAL-003 = full 6-helper surface):
//    1. Permission gate (= hermes DELEGATE_BLOCKED_TOOLS via wenshu
//       SubAgentPermissions). Rejected tools emit a denial toolResult
//       without any I/O.
//    2. ShellHookChain.preToolCall (= TICKET-HERMES-GAP-004). Empty
//       chain = no-op.
//    3. ToolDispatchHookChain.firePreDispatch (= TICKET-HERMES-GAP-008).
//       Empty chain = no-op.
//    4. Pre-dispatch validator (= hermes
//       _apply_tool_request_middleware_for_agent). Default = identity.
//    5. tool.execute(input:) (= returns String output).
//    6. Error classifier (= hermes tool_result_classification). Invoked
//       in the catch path.
//    7. Output truncator (= hermes enforce_turn_budget). Default no-op.
//    8. Post-dispatch validator (= hermes _run_agent_tool_execution_middleware).
//       Default = identity.
//    9. Result formatter (= hermes make_tool_result_message). Default
//       identity (= output passes through).
//   10. ShellHookChain.postToolCall (= TICKET-HERMES-GAP-004).
//   11. ToolDispatchHookChain.firePostDispatch (= TICKET-HERMES-GAP-008).
//   12. Append .toolResult(toolUseID:output:) LLMBlock to messages.
//
//  Errors from individual tools are caught + reported as toolResult
//  with isError flag (= hermes _emit_terminal_post_tool_call pattern).
//
//  HERMES-PARTIAL-003 (2026-09-04, boss OOB 'B' = port 18 partial modules):
//    The 6 helpers (permission gate, output truncator, error classifier,
//    result formatter, pre-dispatch validator, post-dispatch validator)
//    are now configurable via init. Defaults preserve pre-existing
//    behavior (= no behavior change for callers using `ToolExecutor()`).
//
//  v0.35 sub-step 5 of 8 for ticket 001.
//

import Foundation

public actor ToolExecutor {

    // MARK: - Public state (= hermes dispatch-layer plumbing)

    /// Lifecycle hook chain (= TICKET-HERMES-GAP-004). Default = empty
    /// (= `firePreToolCall` / `firePostToolCall` are no-ops on an empty
    /// registry). Inject hooks via `init(hookChain:)`.
    public let hookChain: ShellHookChain

    /// Dispatch hook chain (= TICKET-HERMES-GAP-008). Default = empty
    /// (= `firePreDispatch` / `firePostDispatch` are no-ops on an empty
    /// registry). Inject hooks via `init(hookChain:dispatchHookChain:)`.
    public let dispatchHookChain: ToolDispatchHookChain

    // MARK: - HERMES-PARTIAL-003 dispatch helpers (6 helpers)

    /// Permission gate (= hermes DELEGATE_BLOCKED_TOOLS check; wenshu
    /// SubAgentPermissions parity). Invoked BEFORE `tool.execute(input:)`.
    /// Return `nil` to allow; return a non-nil string to deny (= the
    /// string becomes the tool result output).
    public let permissionGate: @Sendable (String, String) -> String?

    /// Output truncator (= hermes tool_result_storage.enforce_turn_budget).
    /// Invoked AFTER `tool.execute(input:)`, BEFORE post hooks fire.
    /// Return the (possibly truncated) output string.
    public let outputTruncator: @Sendable (String, String) -> String

    /// Error classifier (= hermes tool_result_classification). Invoked
    /// when `tool.execute(input:)` throws. Return a classification
    /// string for observability.
    public let errorClassifier: @Sendable (String, Error) -> String

    /// Result formatter (= hermes make_tool_result_message). Invoked
    /// AFTER output truncator + post-dispatch validator. Returns the
    /// formatted tool output (= the string that ends up in the
    /// `.toolResult` LLMBlock).
    public let resultFormatter: @Sendable (String, String) -> String

    /// Pre-dispatch validator (= hermes
    /// `_apply_tool_request_middleware_for_agent` L247). Returns the
    /// (possibly transformed) input dictionary. Throws to abort.
    public let preDispatchValidator: @Sendable (String, [String: String]) async throws -> [String: String]

    /// Post-dispatch validator (= hermes
    /// `_run_agent_tool_execution_middleware` L274). Invoked AFTER
    /// the tool returns, BEFORE post hooks fire. Throws to abort.
    public let postDispatchValidator: @Sendable (String, String) async throws -> String

    // MARK: - Init

    /// Initializer accepting the optional pre-configured hook chains
    /// + 6 HERMES-PARTIAL-003 dispatch helpers. Defaults preserve
    /// pre-HERMES-PARTIAL-003 behavior.
    public init(
        hookChain: ShellHookChain = ShellHookChain(),
        dispatchHookChain: ToolDispatchHookChain = ToolDispatchHookChain(),
        permissionGate: @escaping @Sendable (String, String) -> String? = ToolExecutor.defaultPermissionGate,
        outputTruncator: @escaping @Sendable (String, String) -> String = ToolExecutor.defaultOutputTruncator,
        errorClassifier: @escaping @Sendable (String, Error) -> String = ToolExecutor.defaultErrorClassifier,
        resultFormatter: @escaping @Sendable (String, String) -> String = ToolExecutor.defaultResultFormatter,
        preDispatchValidator: @escaping @Sendable (String, [String: String]) async throws -> [String: String] = ToolExecutor.defaultPreDispatchValidator,
        postDispatchValidator: @escaping @Sendable (String, String) async throws -> String = ToolExecutor.defaultPostDispatchValidator
    ) {
        self.hookChain = hookChain
        self.dispatchHookChain = dispatchHookChain
        self.permissionGate = permissionGate
        self.outputTruncator = outputTruncator
        self.errorClassifier = errorClassifier
        self.resultFormatter = resultFormatter
        self.preDispatchValidator = preDispatchValidator
        self.postDispatchValidator = postDispatchValidator
    }

    // MARK: - Default helper closures (= hermes-equivalent fallbacks)

    /// Default permission gate: allow all.
    public static let defaultPermissionGate: @Sendable (String, String) -> String? = { _, _ in nil }

    /// Default output truncator: no-op.
    public static let defaultOutputTruncator: @Sendable (String, String) -> String = { output, _ in output }

    /// Default error classifier: classify everything as "internal".
    public static let defaultErrorClassifier: @Sendable (String, Error) -> String = { _, _ in "internal" }

    /// Default result formatter: identity.
    public static let defaultResultFormatter: @Sendable (String, String) -> String = { output, _ in output }

    /// Default pre-dispatch validator: identity.
    public static let defaultPreDispatchValidator: @Sendable (String, [String: String]) async throws -> [String: String] = { _, input in input }

    /// Default post-dispatch validator: identity.
    public static let defaultPostDispatchValidator: @Sendable (String, String) async throws -> String = { _, output in output }

    // MARK: - Sequential execution

    /// Run tool_use blocks sequentially (= one at a time, in order).
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

            // HERMES-PARTIAL-003 step 1: permission gate.
            if let denial = permissionGate(toolName, input) {
                let toolMessage = LLMMessage(
                    role: .tool,
                    blocks: [.toolResult(toolUseID: toolUseID, output: denial)]
                )
                messages.append(toolMessage)
                continue
            }

            // TICKET-HERMES-GAP-004: pre-tool-call hook.
            try await hookChain.firePreToolCall(call)

            // TICKET-HERMES-GAP-008 + HERMES-PARTIAL-003 step 4: pre-dispatch validator + preDispatch hook.
            let dispatchInput = ToolDispatchInputParser.parse(input)
            let validatedInput = try await preDispatchValidator(toolName, dispatchInput)
            let serializedInput = ToolDispatchInputParser.serialize(validatedInput)

            try await dispatchHookChain.firePreDispatch(toolName: toolName, input: validatedInput)

            // HERMES-PARTIAL-003 step 5+6: invoke tool + classify on error.
            let output: String
            var didError = false
            do {
                if let tool = tools[toolName] {
                    output = try await tool.execute(input: serializedInput)
                } else if let tool = await lookupTool(name: toolName, registry: tools) {
                    output = try await tool.execute(input: serializedInput)
                } else {
                    output = "Error: tool '\(toolName)' not found"
                    didError = true
                    _ = ToolExecutorError.toolNotFound(name: toolName)
                }
            } catch {
                let classification = errorClassifier(toolName, error)
                output = "Error [\(classification)]: \(error.localizedDescription)"
                didError = true
                _ = error
            }

            // HERMES-PARTIAL-003 steps 7+8: truncator + post-dispatch validator.
            let truncated = outputTruncator(output, toolName)
            let validatedOutput: String
            do {
                validatedOutput = try await postDispatchValidator(toolName, truncated)
            } catch {
                validatedOutput = "Error: post-dispatch validation failed: \(error.localizedDescription)"
                didError = true
            }

            // HERMES-PARTIAL-003 step 9: result formatter.
            let formatted = resultFormatter(validatedOutput, toolName)

            // TICKET-HERMES-GAP-004: post-tool-call hook.
            let result = ToolResult(toolCallID: toolUseID, output: formatted, isError: didError)
            try await hookChain.firePostToolCall(call, result: result)

            // TICKET-HERMES-GAP-008: post-dispatch hook.
            await dispatchHookChain.firePostDispatch(toolName: toolName, input: validatedInput, output: formatted)

            let toolMessage = LLMMessage(
                role: .tool,
                blocks: [.toolResult(toolUseID: toolUseID, output: formatted)]
            )
            messages.append(toolMessage)
        }
    }

    // MARK: - Concurrent execution

    /// Run tool_use blocks concurrently (= all in parallel via TaskGroup).
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

        struct IndexedOutput {
            let index: Int
            let toolUseID: String
            let output: String
        }

        let outputs: [IndexedOutput] = await withTaskGroup(of: IndexedOutput.self) { group in
            for (index, (toolUseID, toolName, input)) in toolUseBlocks.enumerated() {
                group.addTask {
                    let call = ToolCall(id: toolUseID, name: toolName, input: input)

                    // HERMES-PARTIAL-003 step 1: permission gate (sequential-style).
                    if let denial = self.permissionGate(toolName, input) {
                        return IndexedOutput(index: index, toolUseID: toolUseID, output: denial)
                    }

                    // TICKET-HERMES-GAP-004: pre-tool-call hook.
                    do {
                        try await self.hookChain.firePreToolCall(call)
                    } catch {
                        let rejectionOutput = "Error: pre-tool-call hook rejected: \(error.localizedDescription)"
                        return IndexedOutput(index: index, toolUseID: toolUseID, output: rejectionOutput)
                    }

                    // TICKET-HERMES-GAP-008 + HERMES-PARTIAL-003 step 4: pre-dispatch validator + preDispatch hook.
                    let dispatchInput = ToolDispatchInputParser.parse(input)
                    let validatedInput: [String: String]
                    do {
                        validatedInput = try await self.preDispatchValidator(toolName, dispatchInput)
                    } catch {
                        let rejectionOutput = "Error: pre-dispatch validator rejected: \(error.localizedDescription)"
                        return IndexedOutput(index: index, toolUseID: toolUseID, output: rejectionOutput)
                    }
                    let serializedInput = ToolDispatchInputParser.serialize(validatedInput)

                    do {
                        try await self.dispatchHookChain.firePreDispatch(toolName: toolName, input: validatedInput)
                    } catch {
                        let rejectionOutput = "Error: pre-dispatch hook rejected: \(error.localizedDescription)"
                        return IndexedOutput(index: index, toolUseID: toolUseID, output: rejectionOutput)
                    }

                    // HERMES-PARTIAL-003 steps 5+6: invoke tool + classify on error.
                    let output: String
                    var didError = false
                    do {
                        if let tool = tools[toolName] {
                            output = try await tool.execute(input: serializedInput)
                        } else {
                            output = "Error: tool '\(toolName)' not found"
                            didError = true
                            _ = ToolExecutorError.toolNotFound(name: toolName)
                        }
                    } catch {
                        let classification = self.errorClassifier(toolName, error)
                        output = "Error [\(classification)]: \(error.localizedDescription)"
                        didError = true
                        _ = error
                    }

                    // HERMES-PARTIAL-003 steps 7+8: truncator + post-dispatch validator.
                    let truncated = self.outputTruncator(output, toolName)
                    let validatedOutput: String
                    do {
                        validatedOutput = try await self.postDispatchValidator(toolName, truncated)
                    } catch {
                        validatedOutput = "Error: post-dispatch validation failed: \(error.localizedDescription)"
                        didError = true
                    }

                    // HERMES-PARTIAL-003 step 9: result formatter.
                    let formatted = self.resultFormatter(validatedOutput, toolName)

                    // TICKET-HERMES-GAP-004: post-tool-call hook (errors swallowed).
                    do {
                        let result = ToolResult(toolCallID: toolUseID, output: formatted, isError: didError)
                        try await self.hookChain.firePostToolCall(call, result: result)
                    } catch {
                        _ = error
                    }

                    // TICKET-HERMES-GAP-008: post-dispatch hook.
                    await self.dispatchHookChain.firePostDispatch(toolName: toolName, input: validatedInput, output: formatted)
                    return IndexedOutput(index: index, toolUseID: toolUseID, output: formatted)
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

    // MARK: - Lookup

    /// Look up a tool by name from the registry.
    public func lookupTool(name: String, registry: [String: any Tool]) -> (any Tool)? {
        registry[name]
    }
}