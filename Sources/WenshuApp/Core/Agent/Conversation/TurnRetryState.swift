//
//  TurnRetryState.swift · Wenshu · v0.35 ticket 001 sub-step 4
//
//  Per-turn retry budget tracker. Maps to hermes turn_retry_state.py
//  + iteration_budget.py (= tracks attempt count + max attempts + reset
//  between turns).
//
//  Mutable struct (= recordAttempt mutates attemptNumber). NOT an actor
//  (= callers are expected to synchronize in their own actor context, e.g.
//  ConversationLoop actor owns the retry state).
//
//  v0.35 sub-step 4 of 8 for ticket 001.
//

import Foundation

public struct TurnRetryState: Sendable {
    public let maxAttempts: Int
    public private(set) var attemptNumber: Int

    public init(maxAttempts: Int, attemptNumber: Int = 0) {
        precondition(maxAttempts > 0, "maxAttempts must be positive")
        self.maxAttempts = maxAttempts
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