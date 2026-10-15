// MemoryWriteGate.swift
//
// hermes `_apply_write_gate` parity (= every memory write goes
// through a gate that classifies the operation as allow / block /
// stage-for-approval). Wenshu implements the gate but defaults to
// auto-allow for non-destructive ops (= security + UX tradeoff:
// only gate destructive ops, not every memory add).

import Foundation

/// Decision returned by MemoryWriteGate.
enum MemoryWriteDecision: Sendable, Equatable {
    case allow                  // write proceeds
    case block(reason: String)   // write refused; caller surfaces reason
    case stageForApproval       // write deferred to pending queue (future GUI hook)
}

/// Per-write gate policy for memory mutations.
/// Mirrors hermes `_apply_write_gate(action, target, content, old_text)`.
enum MemoryWriteGate {

    /// Decision rules for `memory.add`:
    /// - empty content → block (defensive)
    /// - content > 500 chars → stageForApproval (should not be surprised by big dumps)
    /// - otherwise → allow
    static func evaluateAdd(content: String) -> MemoryWriteDecision {
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
    static func evaluateReplace(content: String, oldText: String) -> MemoryWriteDecision {
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
    static func evaluateRemove() -> MemoryWriteDecision {
        return .stageForApproval
    }
}
