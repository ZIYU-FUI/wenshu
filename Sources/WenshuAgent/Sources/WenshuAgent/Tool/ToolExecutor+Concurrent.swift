//
//  ToolExecutor+Concurrent.swift
//
//  The concurrent path of the tool executor (= all tool calls in
//  parallel, = = one TaskGroup).
//
//  WHY A SEPARATE FILE
//  ===================
//  The executor's file is about the executor's OWN subject (= one call
//  at a time, = = its gates, = = its hooks, = = its error classification).
//  The concurrent path is a second subject (= many calls at once, = =
//  its own result collection, = = its own ordering), = = and it was
//  pushing the file over the project's line cap.
//
//  The behaviour is unchanged (= = this is a move, = = not a rewrite):
//  the same gates, = = the same hooks, = = the same error
//  classification, = = and the same stream callbacks.
//

import Foundation

public extension ToolExecutor {
    // MARK: - Concurrent execution

    /// Run tool_use blocks concurrently (= all in parallel via TaskGroup).
    /// T2-TOOL-UI (2026-09-18): same streamCallback wiring as executeSequential.
    func executeConcurrent(
        assistantMessage: LLMMessage,
        messages: inout [LLMMessage],
        taskId _: String,
        apiCallCount _: Int = 0,
        tools: [String: any Tool] = [:],
        streamCallback: (@Sendable (LLMBlock) async -> Void)? = nil
    ) async throws {
        let toolUseBlocks = assistantMessage.blocks.compactMap { block -> (String, String, String)? in
            if case let .toolUse(id, name, input) = block {
                return (id, name, input)
            }
            return nil
        }

        struct IndexedOutput {
            let index: Int
            let toolUseID: String
            /// Whether the call FAILED (= = the tool threw, = = the tool
            /// was not found, = = or a gate rejected it).
            ///
            /// It travels with the output because the chat layer settles
            /// the call's card from it: a card that says "complete" for a
            /// failed call is a lie.
            let isError: Bool
            /// The tool's name (= needed to decide whether its output is
            /// high-risk, = the wrapper's decision is by name).
            let toolName: String
            /// The output as the USER sees it (= the tool's real output;
            /// = never wrapped).
            let output: String
            /// The output as the MODEL sees it (= the same string, except
            /// for a high-risk tool, whose output is framed in the
            /// untrusted-data boundary; = the promptware defense).
            let modelOutput: String
        }

        let outputs: [IndexedOutput] = await withTaskGroup(of: IndexedOutput.self) { group in
            for (index, (toolUseID, toolName, input)) in toolUseBlocks.enumerated() {
                group.addTask {
                    let call = ToolCall(id: toolUseID, name: toolName, input: input)

                    // step 1: permission gate (sequential-style).
                    if let denial = self.permissionGate(toolName, input) ?? self.safetyLedger.evaluate(toolName: toolName, input: input) {
                        // The permission gate's own message (= the app's
                        // text, not the tool's output) is NOT wrapped.
                        return IndexedOutput(
                            index: index, toolUseID: toolUseID, isError: true, toolName: toolName,
                            output: denial, modelOutput: denial
                        )
                    }

                    // pre-tool-call hook.
                    do {
                        try await self.hookChain.firePreToolCall(call)
                    } catch {
                        let rejectionOutput = "Error: pre-tool-call hook rejected: \(error.localizedDescription)"
                        return IndexedOutput(
                            index: index, toolUseID: toolUseID, isError: true, toolName: toolName,
                            output: rejectionOutput, modelOutput: rejectionOutput
                        )
                    }

                    // + wenshu port step 4: pre-dispatch validator + preDispatch hook.
                    let dispatchInput = ToolDispatchInputParser.parse(input)
                    let validatedInput: [String: String]
                    do {
                        validatedInput = try await self.preDispatchValidator(toolName, dispatchInput)
                    } catch {
                        let rejectionOutput = "Error: pre-dispatch validator rejected: \(error.localizedDescription)"
                        return IndexedOutput(
                            index: index, toolUseID: toolUseID, isError: true, toolName: toolName,
                            output: rejectionOutput, modelOutput: rejectionOutput
                        )
                    }
                    let serializedInput = ToolDispatchInputParser.serialize(validatedInput)

                    do {
                        try await self.dispatchHookChain.firePreDispatch(toolName: toolName, input: validatedInput)
                    } catch {
                        let rejectionOutput = "Error: pre-dispatch hook rejected: \(error.localizedDescription)"
                        return IndexedOutput(
                            index: index, toolUseID: toolUseID, isError: true, toolName: toolName,
                            output: rejectionOutput, modelOutput: rejectionOutput
                        )
                    }

                    // steps 5+6: invoke tool + classify on error.
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
                        // A failed call is what the failure rule counts.
                        self.safetyLedger.recordFailure(
                            toolName: toolName,
                            input: input,
                            text: output
                        )
                        _ = error
                    }

                    // steps 7+8: truncator + post-dispatch validator.
                    let truncated = self.outputTruncator(output, toolName)
                    let validatedOutput: String
                    do {
                        validatedOutput = try await self.postDispatchValidator(toolName, truncated)
                    } catch {
                        validatedOutput = "Error: post-dispatch validation failed: \(error.localizedDescription)"
                        didError = true
                    }

                    // step 9: result formatter.
                    let formatted = self.resultFormatter(validatedOutput, toolName)

                    // post-tool-call hook (errors swallowed).
                    do {
                        let result = ToolResult(toolCallID: toolUseID, output: formatted, isError: didError)
                        try await self.hookChain.firePostToolCall(call, result: result)
                    } catch {
                        _ = error
                    }

                    // post-dispatch hook.
                    await self.dispatchHookChain.firePostDispatch(toolName: toolName, input: validatedInput, output: formatted)
                    // The MODEL's copy is wrapped for a high-risk tool
                    // (= the promptware defense); the USER's copy is not
                    // (= the user asked for the page's text).
                    return IndexedOutput(
                        index: index, toolUseID: toolUseID, isError: didError, toolName: toolName,
                        output: formatted,
                        modelOutput: UntrustedToolResult.maybeWrapUntrusted(
                            toolName: toolName,
                            content: formatted
                        )
                    )
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
                blocks: [.toolResult(toolUseID: result.toolUseID, output: result.modelOutput, isError: result.isError)]
            )
            messages.append(toolMessage)
            // T2-TOOL-UI (2026-09-18): emit the .toolResult block to ChatView.
            // For concurrent path, .toolUse is NOT emitted at start (= all
            // tools run in parallel; = we'd emit N cards at once which is
            // noisy); = ChatView shows the result card directly.
            if let streamCallback {
                await streamCallback(.toolResult(toolUseID: result.toolUseID, output: result.output, isError: result.isError))
            }
        }
    }
}
