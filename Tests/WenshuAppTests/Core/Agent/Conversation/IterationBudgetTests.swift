//
//  IterationBudgetTests.swift · Wenshu · HERMES-INTERNAL-006 (2026-09-04)
//
//  Round-trip tests for IterationBudget (= hermes iteration_budget.py port).
//
//  Tests covered:
//    1. testRecordIteration_decrementsBudget   — counter decrements remaining
//    2. testMaxIterationsReached_throws         — throws after N iterations
//    3. testRecordTokensUsed_decrementsRemaining — token tracker decrements
//    4. testMaxTokensReached_throws              — throws when tokens exhausted
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("IterationBudget (HERMES-INTERNAL-006)")
struct IterationBudgetTests {

    @Test("recordIteration decrements iterationsRemaining")
    func testRecordIteration_decrementsBudget() async throws {
        let budget = IterationBudget(maxIterations: 3)
        #expect(await budget.iterationsRemaining == 3)

        try await budget.recordIteration()
        #expect(await budget.iterationsRemaining == 2)

        try await budget.recordIteration()
        #expect(await budget.iterationsRemaining == 1)
    }

    @Test("maxIterationsReached thrown once budget is exhausted")
    func testMaxIterationsReached_throws() async throws {
        let budget = IterationBudget(maxIterations: 2)
        try await budget.recordIteration()
        try await budget.recordIteration()
        await #expect(throws: IterationBudgetError.self) {
            try await budget.recordIteration()
        }
        #expect(await budget.iterationsRemaining == 0)
    }

    @Test("recordTokensUsed decrements tokensRemaining")
    func testRecordTokensUsed_decrementsRemaining() async throws {
        let budget = IterationBudget(maxIterations: 5, maxTokens: 100)
        #expect(await budget.tokensRemaining == 100)

        try await budget.recordTokensUsed(30)
        #expect(await budget.tokensRemaining == 70)

        try await budget.recordTokensUsed(20)
        #expect(await budget.tokensRemaining == 50)
    }

    @Test("maxTokensReached thrown once token budget is exhausted")
    func testMaxTokensReached_throws() async throws {
        let budget = IterationBudget(maxIterations: 5, maxTokens: 100)
        try await budget.recordTokensUsed(60)
        try await budget.recordTokensUsed(30)  // total 90 → still OK
        await #expect(throws: IterationBudgetError.self) {
            try await budget.recordTokensUsed(20)  // would exceed 100
        }
        #expect(await budget.tokensRemaining == 10)
    }
}