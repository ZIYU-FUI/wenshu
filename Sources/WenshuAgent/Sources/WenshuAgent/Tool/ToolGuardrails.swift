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
public actor ToolNameWhitelist {
    private(set) var names: Set<String> = []

    public init() {}

    public func set(_ names: Set<String>) {
        self.names = names
    }

    public func contains(_ name: String) -> Bool {
        return names.contains(name)
    }

    public var isEmpty: Bool { names.isEmpty }
}

/// Global singleton (= process-wide whitelist, configured by app startup).
let toolNameWhitelist = ToolNameWhitelist()

/// Pre-tool guardrail result.
public struct ToolGuardrailsResult: Sendable, Equatable {
    public let passed: Bool
    public let reason: String?

    public static let pass = ToolGuardrailsResult(passed: true, reason: nil)
    public static func failure(reason: String) -> ToolGuardrailsResult {
        return ToolGuardrailsResult(passed: false, reason: reason)
    }
}
