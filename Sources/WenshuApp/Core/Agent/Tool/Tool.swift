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
// sub-step 5 of 8 for ticket 001.
//
//  Error cases updated in wt/path-guard-v2-2026-09-25:
//    - `sandboxViolation` renamed to `pathGuardViolation` (= PathGuard
//      replaces the v1 WenshuSandbox enum; = "sandbox" implied Apple
//      kernel sandbox; = "pathGuard" is the allow-list policy name).
//    - The closure passed into `preDispatchValidator` is now
//      `(String, PathGuardInput) throws -> PathGuardInput` (= typed
//      input wrapper; = v1 used raw [String: String]).
//

import Foundation

protocol Tool: Sendable {
    func execute(input: String) async throws -> String
}

/// Errors thrown by Tool.execute or ToolExecutor dispatch.
enum ToolExecutorError: Error, LocalizedError, Sendable {
    case toolNotFound(name: String)
    case toolFailed(name: String, underlying: String)
    case invalidInput(name: String, reason: String)
    /// Tool call rejected by the wenshu PathGuard (= the requested
    /// path resolves outside the .ws library root; = wenshu built-in
    /// tools only operate inside the user's selected library bundle,
    /// see AGENTS.md §11 baseline + PathGuard).
    case pathGuardViolation(toolName: String, key: String, underlying: PathGuard.GuardError)

    var errorDescription: String? {
        switch self {
        case .toolNotFound(let n):
            return String(format: "Tool '%@' not found in registry.", n)
        case .toolFailed(let n, let u):
            return String(format: "Tool '%@' failed: %@", n, u)
        case .invalidInput(let n, let r):
            return String(format: "Tool '%@' rejected input: %@", n, r)
        case .pathGuardViolation(let n, let k, let underlying):
            // Surface only the basename via underlying.errorDescription;
            // the absolute path stays in os_log (debug-level only).
            return String(
                format: "Tool '%@' blocked by PathGuard: key '%@' — %@",
                n, k, underlying.errorDescription ?? "outside library"
            )
        }
    }
}
