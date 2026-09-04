//
//  MemoryConsolidatorTests.swift · Wenshu · v0.23 ticket 013.005 (hermes gap 4)
//
//  Boss 2026-08-23 拍: hermes memory char budget + consolidation parity.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("MemoryConsolidator (hermes char budget + consolidation)")
struct MemoryConsolidatorTests {

    @Test("withinBudget: total chars ≤ limit → .withinBudget")
    func testWithinBudget() async {
        let consolidator = MemoryConsolidator(budget: MemoryBudget(memoryCharLimit: 100))
        let result = await consolidator.checkAndConsolidate(entries: ["a", "bc", "def"])
        #expect(result == .withinBudget)
    }

    @Test("overBudget: total > limit, drop oldest until within")
    func testOverBudgetDropOldest() async {
        let consolidator = MemoryConsolidator(budget: MemoryBudget(memoryCharLimit: 10))
        let entries = ["aaaaa", "bbbbb", "ccccc"]  // 15 total > 10
        let result = await consolidator.checkAndConsolidate(entries: entries)
        // Drop "aaaaa" (5 chars) → 10 chars left, exactly at limit.
        if case .consolidated(let total, let dropped, _) = result {
            #expect(total == 10)
            #expect(dropped == 1)
        } else {
            Issue.record("expected .consolidated, got \(result)")
        }
    }

    @Test("overBudget: drop multiple until within")
    func testOverBudgetDropMultiple() async {
        let consolidator = MemoryConsolidator(budget: MemoryBudget(memoryCharLimit: 5))
        let entries = ["aaaaa", "bbbbb", "ccccc", "ddddd"]  // 20 total
        let result = await consolidator.checkAndConsolidate(entries: entries)
        if case .consolidated(_, let dropped, _) = result {
            #expect(dropped >= 3)
        } else {
            Issue.record("expected .consolidated")
        }
    }

    @Test("overBudget: 1 entry always preserved (drop stops at 1)")
    func testOverBudgetOneEntryPreserved() async {
        let consolidator = MemoryConsolidator(budget: MemoryBudget(memoryCharLimit: 3))
        // Single entry > limit, can't consolidate.
        let entries = ["verylongentry"]
        let result = await consolidator.checkAndConsolidate(entries: entries)
        if case .failed = result {
            // Expected — entry itself exceeds budget.
        } else {
            Issue.record("expected .failed for single oversized entry")
        }
    }

    @Test("failure counter resets on success")
    func testFailureCounterReset() async {
        let consolidator = MemoryConsolidator(budget: MemoryBudget(memoryCharLimit: 5))
        _ = await consolidator.checkAndConsolidate(entries: ["oversized"])
        let countAfter1 = await consolidator.currentFailureCount()
        #expect(countAfter1 >= 1)
        // Within budget → resets counter
        _ = await consolidator.checkAndConsolidate(entries: ["a"])
        let countAfter2 = await consolidator.currentFailureCount()
        #expect(countAfter2 == 0)
    }

    @Test("failure counter capped at maxConsolidationFailuresPerTurn")
    func testFailureCounterCap() async {
        let consolidator = MemoryConsolidator(
            budget: MemoryBudget(memoryCharLimit: 3, maxConsolidationFailuresPerTurn: 2)
        )
        // Trigger 3 failures (beyond cap of 2).
        _ = await consolidator.checkAndConsolidate(entries: ["oversized"])
        _ = await consolidator.checkAndConsolidate(entries: ["oversized"])
        _ = await consolidator.checkAndConsolidate(entries: ["oversized"])
        let count = await consolidator.currentFailureCount()
        // Counter capped at maxConsolidationFailuresPerTurn.
        #expect(count <= 2)
    }

    @Test("resetConsolidationFailures() explicit reset")
    func testExplicitReset() async {
        let consolidator = MemoryConsolidator(budget: MemoryBudget(memoryCharLimit: 3))
        _ = await consolidator.checkAndConsolidate(entries: ["oversized"])
        #expect(await consolidator.currentFailureCount() >= 1)
        await consolidator.resetConsolidationFailures()
        #expect(await consolidator.currentFailureCount() == 0)
    }

    @Test("MemoryBudget default values match hermes (2200 + 1375)")
    func testDefaultBudget() {
        let budget = MemoryBudget()
        #expect(budget.memoryCharLimit == 2200)
        #expect(budget.userCharLimit == 1375)
        #expect(budget.maxConsolidationFailuresPerTurn == 3)
    }

    @Test("empty entries → withinBudget")
    func testEmptyEntries() async {
        let consolidator = MemoryConsolidator(budget: MemoryBudget(memoryCharLimit: 100))
        let result = await consolidator.checkAndConsolidate(entries: [])
        #expect(result == .withinBudget)
    }
}