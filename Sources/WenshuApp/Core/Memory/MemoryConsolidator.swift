//
//  MemoryConsolidator.swift · Wenshu · v0.23 ticket 013.005 (hermes gap 4)
//
//  Boss 2026-08-23 拍: hermes memory char budget + consolidation parity.
//  Source: github.com/NousResearch/hermes-agent/blob/main/tools/memory_tool.py
//
//  Hermes pattern:
//    - memory_char_limit = 2200 (general)
//    - user_char_limit = 1375 (user profile)
//    - When at capacity: consolidate (merge similar entries, drop oldest)
//    - _consolidation_failure counter (max 3 retries per turn)
//    - reset_consolidation_failures() at turn start
//
//  wenshu impl mirrors the budget + consolidation logic.
//

import Foundation

/// Memory char budget configuration (hermes parity).
public struct MemoryBudget: Sendable {
    /// General memory char limit (hermes default = 2200).
    public var memoryCharLimit: Int = 2200
    /// User profile char limit (hermes default = 1375).
    public var userCharLimit: Int = 1375
    /// Max consolidation failure retries per turn (hermes default = 3).
    public var maxConsolidationFailuresPerTurn: Int = 3

    public init(
        memoryCharLimit: Int = 2200,
        userCharLimit: Int = 1375,
        maxConsolidationFailuresPerTurn: Int = 3
    ) {
        self.memoryCharLimit = memoryCharLimit
        self.userCharLimit = userCharLimit
        self.maxConsolidationFailuresPerTurn = maxConsolidationFailuresPerTurn
    }
}

/// Result of a consolidation attempt.
public enum ConsolidationResult: Sendable, Equatable {
    /// Memory within budget, no action needed.
    case withinBudget
    /// Consolidated: some entries merged/dropped, new total within budget.
    case consolidated(newTotalChars: Int, droppedCount: Int, mergedCount: Int)
    /// At capacity but consolidation failed (hermes _consolidation_failure logic).
    case failed(reason: String, currentTotalChars: Int)
}

/// MemoryConsolidator: enforces char budget via consolidation.
/// Hermes-equivalent of `_consolidation_failure` + `_MAX_CONSOLIDATION_FAILURES_PER_TURN`.
public actor MemoryConsolidator {
    private let budget: MemoryBudget
    private var consolidationFailures: Int = 0

    public init(budget: MemoryBudget = MemoryBudget()) {
        self.budget = budget
    }

    /// Reset the per-turn consolidation-failure counter.
    /// Call at turn start (hermes `reset_consolidation_failures()`).
    public func resetConsolidationFailures() {
        consolidationFailures = 0
    }

    /// Check current memory total + budget + consolidate if needed.
    /// - Parameter entries: current memory entries (strings).
    /// - Returns: ConsolidationResult with outcome.
    public func checkAndConsolidate(entries: [String]) -> ConsolidationResult {
        let total = entries.reduce(0) { $0 + $1.count }
        guard total > budget.memoryCharLimit else {
            // Within budget — reset failure counter (success).
            consolidationFailures = 0
            return .withinBudget
        }
        // At capacity. Try to consolidate (drop oldest, merge near-duplicates).
        return tryConsolidate(entries: entries, currentTotal: total)
    }

    /// tryConsolidate: drop oldest entries until within budget, or merge near-duplicates.
    private func tryConsolidate(entries: [String], currentTotal: Int) -> ConsolidationResult {
        // Strategy 1: Drop oldest until within budget (LRU-style).
        // We treat entries as ordered (oldest first).
        var workingEntries = entries
        var droppedCount = 0
        while workingEntries.reduce(0, { $0 + $1.count }) > budget.memoryCharLimit && workingEntries.count > 1 {
            workingEntries.removeFirst()
            droppedCount += 1
        }
        let newTotal = workingEntries.reduce(0, { $0 + $1.count })
        if newTotal <= budget.memoryCharLimit {
            consolidationFailures = 0  // success
            return .consolidated(newTotalChars: newTotal, droppedCount: droppedCount, mergedCount: 0)
        }
        // Strategy 2: After dropping, if still over, this is a failure.
        // Increment failure counter, give up.
        consolidationFailures += 1
        if consolidationFailures <= budget.maxConsolidationFailuresPerTurn {
            // Caller may retry this turn.
            return .failed(reason: "consolidation dropped all-but-one but still over budget (retry \(consolidationFailures)/\(budget.maxConsolidationFailuresPerTurn))", currentTotalChars: currentTotal)
        }
        // Max retries exceeded → return terminal failure, caller stops trying.
        // Clamp counter to maxConsolidationFailuresPerTurn (hermes semantics:
        // counter never exceeds the cap, signals "stuck at cap = no more retries").
        consolidationFailures = budget.maxConsolidationFailuresPerTurn
        return .failed(
            reason: "consolidation failed \(consolidationFailures) times this turn — giving up (hermes #42405: failed side effect must never block reply)",
            currentTotalChars: currentTotal
        )
    }

    /// Get current failure counter (for diagnostics / tests).
    public func currentFailureCount() -> Int {
        return consolidationFailures
    }
}