//
//  ReadFileTool.swift · Wenshu · v0.35 ticket 001 sub-step 6
//
//  Reads a UTF-8 file at the given path (= wenshu-side wins thin wrapper
//  over existing Core/Tools/FileTools.swift.read, per AGENTS.md §11.3).
//
//  Pre-tool guardrail = FileTools.pathDenied (= reuses existing safety
//  checks; hermes tool_guardrails.py is a thin layer over its own path
//  checks, wenshu's existing FileTools already implements the equivalent).
//
//  v0.35 sub-step 6 of 8 for ticket 001.
//

import Foundation

public struct ReadFileTool: Tool, Sendable {
    public init() {}

    public func execute(input: String) async throws -> String {
        // Parse input JSON: {"path": "/absolute/path"}
        let path = try parsePath(input)

        // Pre-tool guardrail (= reuses FileTools.pathDenied)
        let tools = FileTools()
        guard !tools.pathDenied(path) else {
            throw ToolExecutorError.invalidInput(
                name: "ReadFile",
                reason: "Path '\\(path)' is denied by sandbox."
            )
        }

        // Delegate to existing FileTools.read (= sync)
        return try await Task.detached(priority: .userInitiated) {
            try tools.read(path: path)
        }.value
    }

    private func parsePath(_ input: String) throws -> String {
        // Simple JSON parse: {"path": "..."} — for v0.35 minimum
        // (full JSON parser integration lands in ticket 005 OpenAI path)
        guard let pathRange = input.range(of: "\"path\"\\s*:\\s*\"") else {
            throw ToolExecutorError.invalidInput(
                name: "ReadFile",
                reason: "Input must be JSON with 'path' key: \\(input)"
            )
        }
        let afterKey = input[pathRange.upperBound...]
        guard let endQuote = afterKey.firstIndex(of: "\"") else {
            throw ToolExecutorError.invalidInput(
                name: "ReadFile",
                reason: "Unterminated path string in: \\(input)"
            )
        }
        return String(afterKey[..<endQuote])
    }
}