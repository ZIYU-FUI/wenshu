//
//  WriteFileTool.swift · Wenshu · v0.35 ticket 001 sub-step 6
//
//  Writes UTF-8 content to a file at the given path (= wenshu-side wins
//  thin wrapper over existing Core/Tools/FileTools.swift.write, per
//  AGENTS.md §11.3).
//
//  Pre-tool guardrail = FileTools.pathDenied (= reuses existing safety
//  checks; hermes tool_guardrails.py equivalent).
//
//  v0.35 sub-step 6 of 8 for ticket 001.
//

import Foundation

public struct WriteFileTool: Tool, Sendable {
    public init() {}

    public func execute(input: String) async throws -> String {
        let parsed = try parsePathAndContent(input)

        // Pre-tool guardrail
        let tools = FileTools()
        guard !tools.pathDenied(parsed.path) else {
            throw ToolExecutorError.invalidInput(
                name: "WriteFile",
                reason: "Path '\\(parsed.path)' is denied by sandbox."
            )
        }

        // Delegate to existing FileTools.write
        try await Task.detached(priority: .userInitiated) {
            try tools.write(path: parsed.path, content: parsed.content)
        }.value

        return "wrote \\(parsed.content.utf8.count) bytes to \\(parsed.path)"
    }

    private struct Parsed { let path: String; let content: String }

    private func parsePathAndContent(_ input: String) throws -> Parsed {
        // Simple regex-free JSON parse for v0.35 minimum
        guard let pathRange = input.range(of: "\"path\"\\s*:\\s*\"") else {
            throw ToolExecutorError.invalidInput(
                name: "WriteFile",
                reason: "Input must be JSON with 'path' + 'content' keys: \\(input)"
            )
        }
        let afterPathKey = input[pathRange.upperBound...]
        guard let pathEndQuote = afterPathKey.firstIndex(of: "\"") else {
            throw ToolExecutorError.invalidInput(
                name: "WriteFile",
                reason: "Unterminated path string"
            )
        }
        let path = String(afterPathKey[..<pathEndQuote])

        // Content key (use first 'content' key after the path)
        let afterPathEnd = afterPathKey[pathEndQuote...]
        guard let contentRange = afterPathEnd.range(of: "\"content\"\\s*:\\s*\"") else {
            throw ToolExecutorError.invalidInput(
                name: "WriteFile",
                reason: "Missing 'content' key"
            )
        }
        let afterContentKey = afterPathEnd[contentRange.upperBound...]
        // Find end of content (= first unescaped \")
        var content = ""
        var iter = afterContentKey.makeIterator()
        while let ch = iter.next() {
            if ch == "\\", let next = iter.next() {
                if next == "\"" { content.append("\"") }
                else if next == "n" { content.append("\n") }
                else if next == "\\" { content.append("\\") }
                else { content.append("\\"); content.append(next) }
                continue
            }
            if ch == "\"" { break }
            content.append(ch)
        }
        return Parsed(path: path, content: content)
    }
}