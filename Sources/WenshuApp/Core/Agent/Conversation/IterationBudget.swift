//
//  IterationBudget.swift · Wenshu · HERMES-INTERNAL-006 (2026-09-04)
//
//  1:1 port of hermes iteration_budget.py (= hermes-internal module #6,
//  boss 2026-09-04 OOB 'A'). Wenshu already has TurnRetryState.swift as
//  the canonical per-turn retry counter; IterationBudget extends that
//  with a per-task budget (iterations + tokens), giving the conversation
//  loop a hard cap on runaway retries.
//
//  Wenshu-side wins preserved: TurnRetryState.swift stays canonical for
//  per-turn retry decisions. IterationBudget is the task-level budget
//  (= both can coexist: turn retries consume iteration budget when the
//  same turn retries repeatedly).
//

import Foundation

public actor IterationBudget {

    private let maxIterations: Int
    private let maxTokens: Int?
    private var iterationsUsed: Int
    private var tokensUsed: Int

    public init(maxIterations: Int, maxTokens: Int? = nil) {
        precondition(maxIterations > 0, "maxIterations must be positive")
        if let maxTokens {
            precondition(maxTokens > 0, "maxTokens must be positive when set")
        }
        self.maxIterations = maxIterations
        self.maxTokens = maxTokens
        self.iterationsUsed = 0
        self.tokensUsed = 0
    }

    /// Record one iteration consumed. Throws when the budget is exhausted.
    public func recordIteration() async throws {
        guard iterationsUsed < maxIterations else {
            throw IterationBudgetError.maxIterationsReached
        }
        iterationsUsed += 1
    }

    /// Record tokens consumed (= token-budget tracker). Throws when the
    /// token budget is exhausted.
    public func recordTokensUsed(_ tokens: Int) async throws {
        precondition(tokens >= 0, "tokens must be non-negative")
        if let maxTokens {
            guard tokensUsed + tokens <= maxTokens else {
                throw IterationBudgetError.maxTokensReached
            }
        }
        tokensUsed += tokens
    }

    public var iterationsRemaining: Int {
        get async {
            max(0, maxIterations - iterationsUsed)
        }
    }

    public var tokensRemaining: Int? {
        get async {
            guard let maxTokens else { return nil }
            return max(0, maxTokens - tokensUsed)
        }
    }
}

public enum IterationBudgetError: Error, Sendable, Equatable {
    case maxIterationsReached
    case maxTokensReached
}