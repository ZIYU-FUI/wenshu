//
//  WriteFileTool.swift · Wenshu · v0.35 ticket 001 sub-step 6
//
//  Writes UTF-8 content to a file at the given path (= wenshu-side wins
//  thin wrapper over existing Core/Tools/FileTools.swift.write, per
//  AGENTS.md §11.3).
//
//  Pre-tool guardrail = FileTools.pathDenied (= reuses existing safety
//  checks).
//
//  v0.35 sub-step 6 of 8 for ticket 001.
//
//  Standards-axis S3 fix: input parsing delegated to ToolInputParser
//  (= single source of truth for tool input JSON; replaces hand-rolled
//  regex-free substring scan + ad-hoc unescape loop).
//

import Foundation

public struct WriteFileTool: Tool, Sendable {
    public init() {}

    public func execute(input: String) async throws -> String {
        // Parse input JSON via ToolInputParser (= single source of truth per
        // Standards-axis S3 Duplicated Code smell).
        let dict = try ToolInputParser.parseDictionary(input: input)
        let path = try ToolInputParser.requireString(dict, "path")
        let content = try ToolInputParser.requireString(dict, "content")

        // Pre-tool guardrail
        let tools = FileTools()
        guard !tools.pathDenied(path) else {
            throw ToolExecutorError.invalidInput(
                name: "WriteFile",
                reason: "Path '\\(path)' is denied by sandbox."
            )
        }

        // Delegate to existing FileTools.write
        try await Task.detached(priority: .userInitiated) {
            try tools.write(path: path, content: content)
        }.value

        return "wrote \(content.utf8.count) bytes to \(path)"
    }
}