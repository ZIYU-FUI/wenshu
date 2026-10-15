// TurnRetryState.swift
//
// Per-turn retry budget tracker. Maps to hermes `turn_retry_state.py`
// + `iteration_budget.py` (= tracks attempt count + max attempts +
// reset between turns).
//
// Mutable struct (= `recordAttempt` mutates `attemptNumber`). NOT
// an actor (= callers are expected to synchronize in their own
// actor context; = `ConversationLoop` actor owns the retry state).

import Foundation

struct TurnRetryState: Sendable {
    let maxAttempts: Int
    private(set) var attemptNumber: Int

    init(maxAttempts: Int, attemptNumber: Int = 0) {
        self.maxAttempts = max(1, maxAttempts)
        // maxAttempts counts attempts; initial state has consumed none.
        self.attemptNumber = attemptNumber
    }

    var canRetry: Bool {
        attemptNumber < maxAttempts
    }

    var remainingAttempts: Int {
        max(0, maxAttempts - attemptNumber)
    }

    mutating func recordAttempt() {
        attemptNumber += 1
    }

    mutating func reset() {
        attemptNumber = 0
    }
}
