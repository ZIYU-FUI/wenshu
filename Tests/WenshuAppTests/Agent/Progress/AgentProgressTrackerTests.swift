//
//  AgentProgressTrackerTests.swift · Wenshu · v0.41 WIRE-AGENT-006
//
//  Round-trip tests for the `AgentProgressTracker` actor
//  (= P2 #21 wire progress from ConversationLoop into OpenBox).
//
//  Five tests as specified in the ticket:
//    1. testStart_createsEntry        — start() inserts a running entry
//    2. testAdvance_updatesStepNumber — advance() bumps stepNumber + label
//    3. testComplete_marksSucceeded   — complete() flips status to .succeeded
//    4. testCancel_marksCancelled    — cancel() flips status to .cancelled
//    5. testCurrent_returnsLatestRunningEntry — current(sessionId:)
//       walks back through session entries and returns the latest
//       running one (skipping succeeded / failed / cancelled entries).
//
//  All tests use a fresh `AgentProgressTracker()` (= not the .shared
//  singleton) for isolation. The .noop singleton is a separate
//  concern (= it just accepts and drops all calls; tested implicitly
//  by ConversationLoopRunTurnTests passing under the default tracker).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("AgentProgressTracker (WIRE-AGENT-006)")
struct AgentProgressTrackerTests {

    // MARK: - Test 1

    @Test("start() creates a running entry with stepNumber 1 and the given label")
    func testStart_createsEntry() async throws {
        let tracker = AgentProgressTracker()

        let entry = await tracker.start(
            sessionId: "session-A",
            label: "Reading user message"
        )

        #expect(entry.sessionId == "session-A")
        #expect(entry.label == "Reading user message")
        #expect(entry.stepNumber == 1)
        #expect(entry.totalSteps == AgentProgressTracker.standardStepCount)
        #expect(entry.status == .running)
        #expect(entry.etaSeconds == nil)

        // list(sessionId:) should include the new entry.
        let listed = await tracker.list(sessionId: "session-A")
        #expect(listed.count == 1)
        #expect(listed.first?.id == entry.id)
    }

    // MARK: - Test 2

    @Test("advance() bumps stepNumber by 1 and updates the label")
    func testAdvance_updatesStepNumber() async throws {
        let tracker = AgentProgressTracker()
        let entry = await tracker.start(
            sessionId: "session-A",
            label: "Reading user message"
        )

        await tracker.advance(id: entry.id, label: "Compressing context if needed")

        let listed = await tracker.list(sessionId: "session-A")
        #expect(listed.count == 1)
        let updated = try #require(listed.first)
        #expect(updated.id == entry.id)
        #expect(updated.stepNumber == 2)
        #expect(updated.label == "Compressing context if needed")
        #expect(updated.status == .running)
        // advance() clears the ETA (= caller can set a new ETA via setStep()).
        #expect(updated.etaSeconds == nil)
    }

    // MARK: - Test 3

    @Test("complete() flips status to .succeeded and stops appearing in current()")
    func testComplete_marksSucceeded() async throws {
        let tracker = AgentProgressTracker()
        let entry = await tracker.start(
            sessionId: "session-A",
            label: "Reading user message"
        )

        await tracker.complete(id: entry.id, status: .succeeded)

        let listed = await tracker.list(sessionId: "session-A")
        #expect(listed.count == 1)
        let completed = try #require(listed.first)
        #expect(completed.status == .succeeded)
        // current() should now return nil (= entry is no longer running).
        let current = await tracker.current(sessionId: "session-A")
        #expect(current == nil)
    }

    // MARK: - Test 4

    @Test("cancel() flips status to .cancelled and stops appearing in current()")
    func testCancel_marksCancelled() async throws {
        let tracker = AgentProgressTracker()
        let entry = await tracker.start(
            sessionId: "session-A",
            label: "Reading user message"
        )

        await tracker.cancel(id: entry.id)

        let listed = await tracker.list(sessionId: "session-A")
        #expect(listed.count == 1)
        let cancelled = try #require(listed.first)
        #expect(cancelled.status == .cancelled)
        // current() should now return nil (= cancelled entries skip the lookup).
        let current = await tracker.current(sessionId: "session-A")
        #expect(current == nil)
    }

    // MARK: - Test 5

    @Test("current(sessionId:) returns the latest running entry across multiple entries")
    func testCurrent_returnsLatestRunningEntry() async throws {
        let tracker = AgentProgressTracker()
        // Entry 1: starts + completes immediately.
        let first = await tracker.start(
            sessionId: "session-A",
            label: "Reading user message"
        )
        await tracker.complete(id: first.id, status: .succeeded)

        // Entry 2: still running (= the "latest running").
        let second = await tracker.start(
            sessionId: "session-A",
            label: "Calling LLM"
        )
        await tracker.advance(id: second.id, label: "Parsing response")

        // Entry 3: starts but immediately fails.
        let third = await tracker.start(
            sessionId: "session-A",
            label: "Executing tools"
        )
        await tracker.complete(id: third.id, status: .failed)

        let current = await tracker.current(sessionId: "session-A")
        #expect(current != nil)
        // Should be the "Calling LLM" entry (= the latest running one).
        // Entry 3 failed so it's skipped, entry 1 succeeded so it's skipped,
        // entry 2 is still .running so it's returned.
        let resolved = try #require(current)
        #expect(resolved.id == second.id)
        #expect(resolved.label == "Parsing response")
        #expect(resolved.stepNumber == 2)
        #expect(resolved.status == .running)
    }
}