//
//  SubAgentPermissions.swift · Wenshu · v0.23 ticket 012
//
//  Boss 2026-08-23 拍: '去 hermes 源码里扒, 一定有对应的解决方案'.
//  Source: https://github.com/NousResearch/hermes-agent/blob/main/tools/delegate_tool.py
//
//  Hermes `DELEGATE_BLOCKED_TOOLS` (tools sub-agents must NEVER have access to):
//    "delegate_task"  — no recursive delegation
//    "clarify"        — no user interaction from sub-agent
//    "memory"         — no writes to shared MEMORY.md (READ-ONLY is OK)
//    "send_message"   — no cross-platform side effects
//    "cronjob"        — no scheduling in parent's name
//
//  This wenshu impl mirrors that contract. Policy:
//    - For tools in `writeOnlyBlocked`: sub-agent always blocked (delegate_task, clarify, send_message, cronjob).
//    - For tools in `memoryOnlyAllowed`: sub-agent allowed ONLY for read-only ops (auditor's `memory` access).
//    - Memory writes (`memory.add`) from sub-agent: blocked.
//

import Foundation

/// Centralized permission policy for sub-agent tool calls.
/// Mirrors hermes `DELEGATE_BLOCKED_TOOLS` frozenset.
public enum SubAgentPermissions {

    /// Tools that sub-agents must NEVER call (any op).
    /// Mirrors 4 of 5 hermes DELEGATE_BLOCKED_TOOLS (memory handled separately).
    public static let writeOnlyBlocked: Set<String> = [
        "delegate_task",  // no recursive delegation
        "clarify",        // no user interaction
        "send_message",   // no cross-platform side effects
        "cronjob",        // no scheduling in parent's name
    ]

    /// Tools that sub-agents may call BUT only in read-only mode.
    /// Per hermes contract: 'memory' is read-only for sub-agents; only main agent writes.
    /// Implementation: sub-agent calls with op="read" are allowed; "add"/"delete" blocked.
    public static let readOnlyAllowed: Set<String> = [
        "memory",
    ]

    /// Check if a sub-agent can call a given tool (with a given op).
    /// Returns nil if allowed; returns reason string if blocked.
    public static func checkPermission(tool: String, op: String = "") -> String? {
        // writeOnlyBlocked: sub-agent blocked entirely
        if writeOnlyBlocked.contains(tool) {
            return blockReason(tool: tool, why: "write-only-blocked (hermes DELEGATE_BLOCKED_TOOLS)")
        }
        // readOnlyAllowed: sub-agent blocked on write ops
        if readOnlyAllowed.contains(tool) {
            let writeOps: Set<String> = ["add", "write", "delete", "patch", "update"]
            if writeOps.contains(op.lowercased()) {
                return blockReason(tool: tool, why: "write op '\(op)' blocked (hermes: sub-agent memory is read-only)")
            }
        }
        return nil  // allowed
    }

    /// Check tool only (ignoring op) — for tools that don't have op semantics.
    /// Returns nil if allowed; reason if blocked.
    public static func checkToolOnly(_ tool: String) -> String? {
        if writeOnlyBlocked.contains(tool) {
            return blockReason(tool: tool, why: "write-only-blocked (hermes DELEGATE_BLOCKED_TOOLS)")
        }
        return nil
    }

    private static func blockReason(tool: String, why: String) -> String {
        return "(sub-agent blocked: '\(tool)' — \(why). Boss 8/23 拍: hermes DELEGATE_BLOCKED_TOOLS parity)"
    }
}

/// Identifies who is calling invokeTool — used for permission check.
public enum AgentCaller: Sendable, Equatable {
    case main              // WenshuConductor (textbook main agent)
    case subAgent(name: String)  // any of the 5 sub-agents (researcher/writer/analyst/archivist/auditor)

    public var isSubAgent: Bool {
        if case .subAgent = self { return true }
        return false
    }
}