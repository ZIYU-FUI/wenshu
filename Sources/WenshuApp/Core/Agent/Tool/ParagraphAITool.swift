//
//  ParagraphAITool.swift · Wenshu · P0 #2 (WIRE-AGENT-002, 2026-09-04)
//
//  STUB implementation of the paragraph AI editing tool. Returns canned
//  expansion data so the tool dispatch path (= ToolExecutor wired into
//  ConversationLoop via WenshuConductor.tools) is fully exercisable in
//  production + tests without an LLM round-trip.
//
//  P3 ticket #15 (= .scratch/2026-09-04-wenshu-integration-plan.md)
//  replaces this stub with the real hermes port of
//  `agent/editing/paragraph_ai.py` (expand / shorten / rewrite actions
//  with model-driven rewriting). This stub intentionally:
//    - returns canned text so production wiring is provably active
//    - accepts JSON input {"text": "...", "mode": "expand"} and
//      always echoes the input text wrapped in an "expanded" frame
//    - exposes a `.shared` singleton so ChatViewModel can register it
//      with `WenshuConductor(tools: [.shared: ParagraphAITool.shared])`
//    - parses JSON via ToolInputParser (= single source of truth per
//      Standards-axis S3 Duplicated Code smell)
//
//  Tool name = "ParagraphAI" (= matches the convention other wenshu
//  tools use: ReadFileTool → "ReadFile", WriteFileTool → "WriteFile").
//

import Foundation

public struct ParagraphAITool: Tool, Sendable {

    /// Shared singleton (= ChatViewModel registers this with the
    /// conductor at construction time). The tool is stateless so a
    /// single instance is sufficient.
    public static let shared = ParagraphAITool()

    public init() {}

    public func execute(input: String) async throws -> String {
        // Parse input JSON. Stub contract: {"text": "...", "mode": "expand"}
        // `mode` is optional (= default = "expand" matches the boss
        // OOB use-case for this ticket = one stub action).
        let dict: [String: Any]
        do {
            dict = try ToolInputParser.parseDictionary(input: input)
        } catch {
            // Empty / malformed input still returns a valid stub frame
            // (= canned expansion of an empty paragraph is empty +
            // "(no input)" annotation; tests assert non-empty output).
            return stubFrame(text: "", mode: "expand")
        }
        let text = (dict["text"] as? String) ?? ""
        let mode = (dict["mode"] as? String) ?? "expand"
        return stubFrame(text: text, mode: mode)
    }

    /// Build the canned expansion frame. Real port (= P3 ticket #15)
    /// replaces this with LLM-driven rewriting.
    private func stubFrame(text: String, mode: String) -> String {
        // Stub contract: return a JSON-shaped string the agent can
        // round-trip without re-parsing. Trim leading/trailing
        // whitespace for nicer presentation in ChatView.
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = trimmed.isEmpty ? "(no input)" : trimmed
        return "[ParagraphAI stub — mode=\(mode)] \(body) [expanded]"
    }
}