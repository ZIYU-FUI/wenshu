//
//  WenshuConductorImportRouter+ToolUse.swift
//
//  The LLM's tool-use loop: the `web_search` tool_use round trip the
//  reference library's rewrite mode drives.
//
//  Why: the loop is a cluster of its own (= the router drives the LLM
//  through a series of tool_use blocks), and the router's file was over
//  the file-size cap.
//
import Foundation
import WenshuAgent

extension WenshuConductorImportRouter {
    // MARK: - Tool-use loop (= searchAndRewrite)

    /// (= the `searchAndRewrite` rewriteMode's LLM-call pattern). Drives the
    /// LLM through a series of `web_search` tool_use blocks; = each tool_use
    /// block is dispatched to `WebSearchTool.shared.execute` and the result is
    /// sent back as a `tool_result` block; = the loop terminates when the LLM
    /// responds with `stopReason = .endTurn` (= the LLM has produced its final
    /// classification + the rewritten body); = a hard turn cap (= 5) prevents
    /// runaway token spend (= the boss's "Token 高消耗" concern; = a search call
    /// that doesn't converge in 5 turns is a clear signal of a misbehaving LLM
    /// or a stale web result; = the orchestrator still produces a result (= the
    /// last response's text is the best effort); = = in practice the LLM
    /// converges in 1-2 turns for typical reference-library imports).
    func runToolUseLoop(
        initialUserPrompt: String,
        options: LLMCallOptions,
        body _: String,
        filePath _: String
    ) async throws -> LLMResponse {
        var messages: [LLMMessage] = [.user(initialUserPrompt)]
        let maxTurns = 5
        for _ in 0 ..< maxTurns {
            let response = try await connector.send(messages: messages, options: options)
            // Check stop reason (= endTurn = LLM finished; = toolUse = LLM wants to call
            // a tool; = maxTokens = LLM hit the cap; = unknown = bail).
            switch response.stopReason {
            case .endTurn:
                return response
            case .maxTokens, .stopSequence, .unknown:
                return response
            case .toolUse:
                break
            }
            // Collect tool_use blocks (= one or more in a single response; = the
            // Anthropic API allows parallel tool_use).
            var toolUseBlocks: [(id: String, name: String, input: String)] = []
            var assistantTextBlocks: [String] = []
            for block in response.blocks {
                switch block {
                case let .text(s):
                    assistantTextBlocks.append(s)
                case let .toolUse(id, name, input):
                    toolUseBlocks.append((id, name, input))
                case .thinking, .toolResult:
                    continue
                }
            }
            if toolUseBlocks.isEmpty {
                // LLM said toolUse but didn't emit any tool_use blocks; = the LLM
                // misbehaved; = return the text we have.
                return response
            }
            // Append the assistant message (= the full response blocks, not just text; =
            // the LLMConnector serializes this into the wire request's
            // `messages` array).
            messages.append(LLMMessage(role: .assistant, blocks: response.blocks))
            // Dispatch each tool_use; = collect tool_result blocks for the next request.
            for tool in toolUseBlocks {
                let output: String
                if tool.name == "web_search" {
                    output = await dispatchWebSearch(input: tool.input)
                } else {
                    output = "{\"ok\":false,\"error\":\"unknown tool: \(tool.name)\"}"
                }
                messages.append(.toolResult(
                    toolUseID: tool.id,
                    output: output
                ))
            }
        }
        // Fall through (= turn cap exceeded; = return the last response we have; = in
        // practice unreachable because we return on .endTurn inside the loop).
        return try await connector.send(messages: messages, options: options)
    }

    /// Dispatch a `web_search` tool call. The LLM passes the tool's `input`
    /// field as a JSON string (= the Anthropic shape); = we hand that string
    /// straight to `WebSearchTool.shared.execute` which understands the same
    /// JSON shape (= the canonical wenshu tool dispatcher).
    private func dispatchWebSearch(input: String) async -> String {
        do {
            return try await WebSearchTool.shared.execute(input: input)
        } catch {
            return "{\"ok\":false,\"error\":\"web_search dispatch failed: \(error.localizedDescription)\"}"
        }
    }
}
