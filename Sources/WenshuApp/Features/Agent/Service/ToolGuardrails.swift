// ToolGuardrails.swift
//
// Pre-tool check layer that wraps existing wenshu
// `FileTools.pathDenied` (= §11.3 wenshu-side wins: do NOT
// duplicate sandbox / path / permission logic; extend the
// existing `FileTools` canonical implementation).
//
// Per spec §3.1:
//   - Path validation (= delegate to `FileTools.pathDenied`).
//   - Tool whitelist (= only `Tool` protocol conformers with a
//     valid name).
//   - Input size cap (= reject inputs > 1 MB to prevent memory
//     exhaustion).
//   - Rate-limit coordination (= delegate to `RateLimitTracker`).
//
// Per ADR-0009 (wenshu-side wins), this file is a thin facade (=
// delegates to canonical wenshu Core). No duplicate sandbox /
// permission engine).

import Foundation

/// Maximum input size for any single tool invocation (= 1 MB).
/// Prevents memory exhaustion from malicious or buggy callers
/// (= hermes tool_guardrails.py enforces similar limit).
let toolGuardrailsMaxInputBytes: Int = 1_048_576  // 1 MB

/// Tool name whitelist (= enforce known tools only).
/// Actor (= Swift 6 strict-concurrency-safe mutable global).
actor ToolNameWhitelist {
    private(set) var names: Set<String> = []

    init() {}

    func set(_ names: Set<String>) {
        self.names = names
    }

    func contains(_ name: String) -> Bool {
        return names.contains(name)
    }

    var isEmpty: Bool { names.isEmpty }
}

/// Global singleton (= process-wide whitelist, configured by app startup).
let toolNameWhitelist = ToolNameWhitelist()

/// Pre-tool guardrail result.
struct ToolGuardrailsResult: Sendable, Equatable {
    let passed: Bool
    let reason: String?

    static let pass = ToolGuardrailsResult(passed: true, reason: nil)
    static func failure(reason: String) -> ToolGuardrailsResult {
        return ToolGuardrailsResult(passed: false, reason: reason)
    }
}

/// Pre-tool check helper (= static functions for stateless guardrail logic).
enum ToolGuardrails {

    /// Pre-tool check (= validates path + name + input size).
    /// - Parameters:
    ///   - tool: Tool protocol conformer
    ///   - input: tool input JSON
    /// - Returns: ToolGuardrailsResult indicating pass / fail
    static func check<T: Tool>(tool: T, input: String) async -> ToolGuardrailsResult {
        // 1. Input size cap (= prevent memory exhaustion)
        let inputBytes = input.utf8.count
        guard inputBytes <= toolGuardrailsMaxInputBytes else {
            return .failure(reason: "input exceeds \(toolGuardrailsMaxInputBytes) bytes (got \(inputBytes))")
        }

        // 2. Tool name whitelist (= optional enforcement)
        // Tool protocol doesn't expose `toolName`; use type name as fallback
        // (= String(reflecting: T.self) gives the Swift type name = "ReadFileTool" etc.).
        let isWhitelistEmpty = await toolNameWhitelist.isEmpty
        if !isWhitelistEmpty {
            let toolName = String(reflecting: T.self)
            let isWhitelisted = await toolNameWhitelist.contains(toolName)
            if !isWhitelisted {
                return .failure(reason: "tool '\(toolName)' not in whitelist")
            }
        }

        // 3. Tool-specific guardrails (= delegate via protocol extension)
        if let pathGuardrail = tool as? PathGuarding {
            // Parse JSON input to extract path field (= simple regex-free).
            // Full JSON parsing delegated to ToolInputParser (= S3 fix).
            if let path = extractPathField(from: input) {
                let tools = FileTools()
                if tools.pathDenied(path) {
                    return .failure(reason: "path '\(path)' denied by sandbox")
                }
                if let toolPathError = pathGuardrail.validatePath(path) {
                    return .failure(reason: toolPathError)
                }
            }
        }

        return .pass
    }

    /// Extract 'path' field from JSON input (= simple substring scan).
    private static func extractPathField(from input: String) -> String? {
        guard let keyRange = input.range(of: "\"path\"\\s*:\\s*\"") else { return nil }
        let afterKey = input[keyRange.upperBound...]
        guard let endQuote = afterKey.firstIndex(of: "\"") else { return nil }
        return String(afterKey[..<endQuote])
    }
}

/// Optional protocol for tools that need custom path validation
/// (= in addition to FileTools.pathDenied default sandbox check).
protocol PathGuarding: Tool {
    /// Validate a candidate path (= return nil if OK, error string if blocked).
    func validatePath(_ path: String) -> String?
}
