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

public struct TurnRetryState: Sendable {
    public let maxAttempts: Int
    public private(set) var attemptNumber: Int

    public init(maxAttempts: Int, attemptNumber: Int = 0) {
        self.maxAttempts = max(1, maxAttempts)
        // maxAttempts counts attempts; initial state has consumed none.
        self.attemptNumber = attemptNumber
    }

    public var canRetry: Bool {
        attemptNumber < maxAttempts
    }

    public var remainingAttempts: Int {
        max(0, maxAttempts - attemptNumber)
    }

    public mutating func recordAttempt() {
        attemptNumber += 1
    }

    public mutating func reset() {
        attemptNumber = 0
    }
}
