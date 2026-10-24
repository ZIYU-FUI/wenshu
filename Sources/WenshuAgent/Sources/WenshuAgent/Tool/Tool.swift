// Tool.swift
//
// Tool protocol = the contract every wenshu tool (= ReadFileTool,
// WriteFileTool, KanbanTool, etc.) must satisfy.
//
// A `Tool` is a Sendable async function: `String` input (typically
// JSON) -> `String` output (typically JSON). The `ToolExecutor`
// calls `execute(input:)` at most once per tool invocation, with
// the tool-use block's `input` field passed through verbatim.
//
// Error cases updated in the path-guard v2:
//   - `sandboxViolation` renamed to `pathGuardViolation` (=
//     `PathGuard` v2 uses the canonical wenshu path-guard surface;
//     = "sandbox" implied Apple kernel sandbox; = "pathGuard"
//     is the allow-list policy name).
//   - The closure passed into `preDispatchValidator` is now
//     `(String, PathGuardInput) throws -> PathGuardInput` (= typed
//     input wrapper; = v1 used raw `[String: String]`).

import Foundation

/// The contract every wenshu tool satisfies.
///
/// A tool is a `Sendable` async function: `String` input (typically
/// JSON) to `String` output (typically JSON). The `ToolExecutor`
/// calls `execute(input:)` at most once per tool invocation, with
/// the tool-use block's `input` field passed through verbatim.
public protocol Tool: Sendable {
    func execute(input: String) async throws -> String
}

/// A `Tool` that builds the real tool the first time it is CALLED.
///
/// Module-load registration must not build a tool: several of the app's
/// tools expose a `@MainActor` / actor-isolated `shared` singleton whose
/// initializer opens a disk-backed store or a SwiftData container. Touching
/// it during registration puts that work on the main actor (or on the tool's
/// own actor), and under a parallel test suite the main actor is busy enough
/// that the registration loses the 5-second settle window and the tool never
/// appears in `ToolRegistry.shared` at all.
///
/// Registering the wrapper instead keeps registration cheap and off the main
/// actor; the real tool is built on the first call, which is where its cost
/// belongs.
public struct LazyTool: Tool, Sendable {
    private let make: @Sendable () async -> any Tool

    public init(_ make: @escaping @Sendable () async -> any Tool) {
        self.make = make
    }

    public func execute(input: String) async throws -> String {
        let tool = await make()
        return try await tool.execute(input: input)
    }
}

/// Errors thrown by Tool.execute or ToolExecutor dispatch.
public enum ToolExecutorError: Error, LocalizedError, Sendable {
    case toolNotFound(name: String)
    case toolFailed(name: String, underlying: String)
    case invalidInput(name: String, reason: String)
    /// Tool call rejected by the wenshu PathGuard (= the requested
    /// path resolves outside the .ws library root; = wenshu built-in
    /// tools only operate inside the user's selected library bundle,
    /// see AGENTS.md §11 baseline + PathGuard).
    case pathGuardViolation(toolName: String, key: String, underlying: PathGuard.GuardError)

    public var errorDescription: String? {
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
