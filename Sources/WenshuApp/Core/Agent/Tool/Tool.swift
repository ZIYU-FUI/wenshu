//
//  Tool.swift · Wenshu · v0.35 ticket 001 sub-step 5
//
//  Tool protocol = the contract every wenshu tool (= ReadFileTool,
//  WriteFileTool, KanbanTool, etc.) must satisfy.
//
//  A Tool is a Sendable async function: String input (typically JSON)
//  -> String output (typically JSON). The ToolExecutor calls
//  execute(input:) at most once per tool invocation, with the tool_use
//  block's `input` field passed through verbatim.
//
//  v0.35 sub-step 5 of 8 for ticket 001.
//

import Foundation

public protocol Tool: Sendable {
    func execute(input: String) async throws -> String
}

/// Errors thrown by Tool.execute or ToolExecutor dispatch.
public enum ToolExecutorError: Error, LocalizedError, Sendable {
    case toolNotFound(name: String)
    case toolFailed(name: String, underlying: String)
    case invalidInput(name: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case .toolNotFound(let n):
            return "Tool '\\(n)' not found in registry."
        case .toolFailed(let n, let u):
            return "Tool '\\(n)' failed: \\(u)"
        case .invalidInput(let n, let r):
            return "Tool '\\(n)' rejected input: \\(r)"
        }
    }
}