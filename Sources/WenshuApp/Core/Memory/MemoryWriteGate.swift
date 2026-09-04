//
//  MemoryWriteGate.swift · Wenshu · v0.23 ticket 013.001 (hermes gap 1)
//
//  Boss 2026-08-23 拍: '全修, 参考原则 3' (效果优先不打折).
//  Source: github.com/NousResearch/hermes-agent/blob/main/tools/memory_tool.py:949 _apply_write_gate
//
//  Hermes pattern: every memory write (add/replace/remove) goes through a gate
//  that classifies the operation as allow / block / stage-for-approval.
//  Wenshu implements the gate but defaults to auto-allow for non-destructive
//  ops (boss 8/23 security + UX tradeoff: don't ask user to approve every
//  memory add; only gate destructive ones).
//

import Foundation

/// Decision returned by MemoryWriteGate.
public enum MemoryWriteDecision: Sendable, Equatable {
    case allow                  // write proceeds
    case block(reason: String)   // write refused; caller surfaces reason
    case stageForApproval       // write deferred to pending queue (future GUI hook)
}

/// Per-write gate policy for memory mutations.
/// Mirrors hermes `_apply_write_gate(action, target, content, old_text)`.
public enum MemoryWriteGate {

    /// Decision rules for `memory.add`:
    /// - empty content → block (defensive)
    /// - content > 500 chars → stageForApproval (boss shouldn't be surprised by big dumps)
    /// - otherwise → allow
    public static func evaluateAdd(content: String) -> MemoryWriteDecision {
        if content.isEmpty {
            return .block(reason: "memory content is empty (nothing to remember)")
        }
        if content.count > 500 {
            return .stageForApproval
        }
        return .allow
    }

    /// Decision rules for `memory.replace`:
    /// - oldText empty → block
    /// - content differs significantly from oldText → stageForApproval
    public static func evaluateReplace(content: String, oldText: String) -> MemoryWriteDecision {
        if oldText.isEmpty {
            return .block(reason: "memory replace requires non-empty oldText")
        }
        // Significant change = length grows by > 100% (i.e. content much longer than oldText)
        // OR leading 16 chars differ (totally different content).
        // Use 100% to avoid false-positive on append-only edits (e.g. "abc" → "abcd").
        let lenDelta = content.count - oldText.count
        let significantChange = lenDelta > oldText.count ||
                                 !content.hasPrefix(oldText.prefix(16))
        if significantChange {
            return .stageForApproval
        }
        return .allow
    }

    /// Decision rules for `memory.remove`:
    /// - ALWAYS requires approval (destructive)
    public static func evaluateRemove() -> MemoryWriteDecision {
        return .stageForApproval
    }
}