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
//  Standards-axis S3 fix: input parsing delegated to ToolInputParser
//  (= single source of truth for tool input JSON; replaces hand-rolled
//  regex-free substring scan).
//

import Foundation

public struct ReadFileTool: Tool, Sendable {
    public init() {}

    public func execute(input: String) async throws -> String {
        // Parse input JSON via ToolInputParser (= single source of truth per
        // Standards-axis S3 Duplicated Code smell).
        let dict = try ToolInputParser.parseDictionary(input: input)
        let path = try ToolInputParser.requireString(dict, "path")

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
}