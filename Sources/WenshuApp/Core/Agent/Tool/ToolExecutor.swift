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
    /// T2-TOOL-UI (2026-09-18): added `streamCallback` parameter so
    /// each `.toolUse` block + its matching `.toolResult` block are
    /// emitted via the same streamCallback that ConversationLoop uses
    /// for text/thinking. Without this, ChatView never sees the tool
    /// UI cards (ChatToolUsePartView / ChatToolResultPartView) because
    /// the blocks stayed inside ConversationResult.blocks[] without
    /// a per-block notification.
    public func executeSequential(
        assistantMessage: LLMMessage,
        messages: inout [LLMMessage],
        taskId: String,
        apiCallCount: Int = 0,
        tools: [String: any Tool] = [:],
        streamCallback: (@Sendable (LLMBlock) async -> Void)? = nil
    ) async throws {
        let toolUseBlocks = assistantMessage.blocks.compactMap { block -> (String, String, String)? in
            if case .toolUse(let id, let name, let input) = block {
                return (id, name, input)
            }
            return nil
        }

        for (toolUseID, toolName, input) in toolUseBlocks {
            let call = ToolCall(id: toolUseID, name: toolName, input: input)

            // T2-TOOL-UI (2026-09-18): emit the .toolUse block FIRST so
            // ChatView's ChatToolUsePartView appears immediately (= the
            // user sees "Tool: read_file" card while the tool is
            // executing). Without this, the tool card only appears
            // after the whole tool finishes.
            if let streamCallback {
                await streamCallback(.toolUse(id: toolUseID, name: toolName, input: input))
            }

            // HERMES-PARTIAL-003 step 1: permission gate.
            if let denial = permissionGate(toolName, input) {
                let toolMessage = LLMMessage(
                    role: .tool,
                    blocks: [.toolResult(toolUseID: toolUseID, output: denial)]
                )
                messages.append(toolMessage)
                // T2-TOOL-UI: emit matching toolResult so ChatToolResultPartView shows denial
                if let streamCallback {
                    await streamCallback(.toolResult(toolUseID: toolUseID, output: denial))
                }
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
                } else if let tool = lookupTool(name: toolName, registry: tools) {
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
            // T2-TOOL-UI: emit matching .toolResult so ChatToolResultPartView
            // (= green checkmark / red X card) appears after the tool finishes.
            if let streamCallback {
                await streamCallback(.toolResult(toolUseID: toolUseID, output: formatted))
            }
        }
    }

    // MARK: - Concurrent execution

    /// Run tool_use blocks concurrently (= all in parallel via TaskGroup).
    /// T2-TOOL-UI (2026-09-18): same streamCallback wiring as executeSequential.
    public func executeConcurrent(
        assistantMessage: LLMMessage,
        messages: inout [LLMMessage],
        taskId: String,
        apiCallCount: Int = 0,
        tools: [String: any Tool] = [:],
        streamCallback: (@Sendable (LLMBlock) async -> Void)? = nil
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
            // T2-TOOL-UI (2026-09-18): emit the .toolResult block to ChatView.
            // For concurrent path, .toolUse is NOT emitted at start (= all
            // tools run in parallel; = we'd emit N cards at once which is
            // noisy); = ChatView shows the result card directly.
            if let streamCallback {
                await streamCallback(.toolResult(toolUseID: result.toolUseID, output: result.output))
            }
        }
    }

    // MARK: - Lookup

    /// Look up a tool by name from the registry.
    public func lookupTool(name: String, registry: [String: any Tool]) -> (any Tool)? {
        registry[name]
    }
}

// MARK: - P6 Hermes-Python gap port (= 1:1 port of hermes
//         `agent/tool_executor.py` pure helpers).
//
// Wenshu-side wins (= per AGENTS.md §11.3):
//
// Direct port of hermes `agent/tool_executor.py` per spec
// §3.1 #12 (= TICKET-HERMES-PARTIAL-003 follow-up). The target
// file already existed at 400 LOC with full surface
// (= executeConcurrent + executeSequential + 5 helper
// functions = wenshu chose an actor-based dispatch
// architecture per the wenshu-side-wins pattern). This P6
// ticket adds the 2 hermes pure helpers that are reusable
// outside the actor (= the runtime-error check + the
// cancelled-tool-result JSON builder):
//
//   1. _is_interpreter_shutdown_submit_error (= hermes L120-L123)
//   2. _cancelled_tool_result (= hermes L159-L167)
//
// These 2 helpers close the audit-described gap
// (= 6 helpers not ported; = the other 4 are not pure
// functions and live in the wenshu ToolExecutor actor
// already).
//
// Hermes Python line ranges cited in doc-comments below
// (= for traceability back to `/Volumes/ANAN/.hermes/agent/
// tool_executor.py`).
//
// Per AGENTS.md §11.3 wenshu-side wins:
//   - Pre-existing ToolExecutor actor + executeConcurrent +
//     executeSequential + ShellHookChain + ToolDispatchHookChain
//     preserved (= Q112 no regressions).
//   - The interpreter-shutdown check is hermes-specific
//     (= Python's asyncio interpreter shutdown = "cannot
//     schedule new futures after interpreter shutdown");
//     = wenshu uses Swift Concurrency (= no interpreter
//     shutdown concept); = the check returns false for
//     any RuntimeError in wenshu (matches hermes behavior
//     when the wenshu runtime never reaches this state but
//     the function is preserved for API parity + test
//     coverage).
//   - The cancelled-tool-result JSON uses hermes's
//     canonical shape (= {"error": "Tool execution
//     cancelled by <reason>", "status": "cancelled"}).
//
// Per AGENTS.md §11 hard rule: Apple Foundation only. No
// third-party imports.

extension ToolExecutor {

    // MARK: -- P6.1 interpreter shutdown check (= hermes L120-L123)

    /// Pure-function: return true when a RuntimeError indicates
    /// the Python interpreter was shut down (= hermes
    /// `_is_interpreter_shutdown_submit_error` at
    /// `agent/tool_executor.py` L120-L123).
    ///
    /// This pattern surfaces in hermes when a concurrent
    /// tool-dispatch Task tries to submit a new future
    /// after the Python interpreter has begun tearing down
    /// (= e.g. on Ctrl-C during a parallel batch). The
    /// hermes match string is `"cannot schedule new futures
    /// after interpreter shutdown"`.
    ///
    /// Wenshu-side wins: Swift Concurrency has no interpreter
    /// shutdown concept (= actor deinit vs. interpreter
    /// shutdown are different lifecycles); = the check
    /// preserves hermes's API shape for API parity but
    /// returns false in practice (= wenshu RuntimeErrors
    /// don't carry this signature).
    public static func isInterpreterShutdownSubmitError(_ error: Error) -> Bool {
        let message = String(describing: error)
        return message.contains("cannot schedule new futures after interpreter shutdown")
    }

    // MARK: -- P6.2 cancelled tool result (= hermes L159-L167)

    /// Pure-function: return the JSON body for a cancelled
    /// tool result (= hermes `_cancelled_tool_result` at
    /// `agent/tool_executor.py` L159-L167).
    ///
    /// Canonical shape (hermes):
    /// ```json
    /// {
    ///   "error": "Tool execution cancelled by <reason>",
    ///   "status": "cancelled"
    /// }
    /// ```
    public static func cancelledToolResultJSON(reason: String = "user interrupt") -> String {
        let dict: [String: Any] = [
            "error": "Tool execution cancelled by \(reason)",
            "status": "cancelled",
        ]
        guard JSONSerialization.isValidJSONObject(dict),
              let data = try? JSONSerialization.data(
                  withJSONObject: dict,
                  options: [.fragmentsAllowed]
              ) else {
            return "{}"
        }
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}