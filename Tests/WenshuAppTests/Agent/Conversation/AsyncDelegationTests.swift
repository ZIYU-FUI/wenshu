//
//  AsyncDelegationTests.swift · Wenshu · HERMES-PARTIAL-018 (2026-09-04)
//
//  Round-trip tests for the AsyncDelegation surface added in
//  HERMES-PARTIAL-018:
//    - delegate(...) public entry
//    - AsyncDelegationRegistry progress stream
//    - SubAgentPermissions integration (permission gate)
//
//  Tests covered (per boss 2026-09-04 OOB 'B'):
//    1. testDelegateSimpleTask              — delegate(simpleProfile, task, [:]) returns handle
//    2. testDelegateWithContext             — context keys pass through metadata
//    3. testDelegatePermissionDenied        — blocked tool key in context throws
//    4. testDelegateProgressReported        — registry emits .pending/.completed
//    5. testDelegateResultRouted            — markCompleted routes summary + emits progress
//    6. testSubAgentLifecycle               — register → running → completed → cleanup path
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("AsyncDelegation (HERMES-PARTIAL-018)")
struct AsyncDelegationTests {

    // MARK: - Test 1: delegate simple task

    @Test("delegate(simpleProfile, task, [:]) registers handle + returns result")
    func testDelegateSimpleTask() async throws {
        let registry = AsyncDelegationRegistry()
        let result = try await delegate(
            subagentProfile: "researcher",
            task: "find sources for chapter 3",
            registry: registry
        )
        #expect(result.handle.agentName == "researcher")
        #expect(result.handle.state == .pending)
        #expect(result.summary.isEmpty)  // parent fills this after invocation
        #expect(result.metadata["agent"] == "researcher")
        #expect(result.metadata["registered_at"] != nil)

        // The registry must contain the new handle.
        let stored = await registry.get(id: result.handle.id)
        #expect(stored != nil)
        #expect(stored?.agentName == "researcher")
    }

    // MARK: - Test 2: delegate with context

    @Test("delegate passes non-blocked context keys through without error")
    func testDelegateWithContext() async throws {
        let registry = AsyncDelegationRegistry()
        let result = try await delegate(
            subagentProfile: "writer",
            task: "draft chapter 3 outline",
            context: ["style": "wuxia", "audience": "adventurous"],
            registry: registry
        )
        #expect(result.handle.agentName == "writer")
        #expect(result.metadata["agent"] == "writer")
        // Stored handle carries the task as userMessage.
        #expect(result.handle.userMessage == "draft chapter 3 outline")
    }

    // MARK: - Test 3: delegate permission denied

    @Test("delegate throws permissionDenied when context contains a blocked tool key")
    func testDelegatePermissionDenied() async throws {
        let registry = AsyncDelegationRegistry()
        // "delegate_task" is in SubAgentPermissions.writeOnlyBlocked.
        await #expect(throws: AsyncDelegationError.self) {
            _ = try await delegate(
                subagentProfile: "researcher",
                task: "spawn another sub-agent",
                context: ["delegate_task": "child goal"],
                registry: registry
            )
        }
        // After the throw, the registry must NOT contain a partial
        // record for the rejected delegate call.
        let running = await registry.runningDelegations()
        #expect(running.isEmpty)
    }

    // MARK: - Test 4: progress reported

    @Test("registry emits .pending then .completed progress events")
    func testDelegateProgressReported() async throws {
        let registry = AsyncDelegationRegistry()
        let result = try await delegate(
            subagentProfile: "analyst",
            task: "build outline graph",
            registry: registry
        )
        // The .pending emit was inline in delegate(...); next() should
        // either return it now or block until markCompleted emits one.
        // To make the test deterministic, race: collect any pending
        // events first, then trigger markCompleted.
        let initialPending = await registry.pendingProgressSnapshot
        #expect(initialPending.contains { $0.handleID == result.handle.id && $0.state == .pending })

        await registry.markCompleted(id: result.handle.id, result: "graph: ok")

        // The completion must have been emitted (either to a waiter or
        // into pendingProgress).
        let afterPending = await registry.pendingProgressSnapshot
        let emittedCompletion = afterPending.contains {
            $0.handleID == result.handle.id && $0.state == .completed
        }
        #expect(emittedCompletion)
    }

    // MARK: - Test 5: result routed

    @Test("markCompleted routes summary back through handle.result")
    func testDelegateResultRouted() async throws {
        let registry = AsyncDelegationRegistry()
        let result = try await delegate(
            subagentProfile: "archivist",
            task: "backup vault",
            registry: registry
        )
        await registry.markCompleted(id: result.handle.id, result: "backup ok")

        let stored = await registry.get(id: result.handle.id)
        #expect(stored?.state == .completed)
        #expect(stored?.result == "backup ok")
        #expect(stored?.completedAt != nil)
    }

    // MARK: - Test 6: sub-agent lifecycle

    @Test("sub-agent lifecycle: register → markCompleted → cleanup path")
    func testSubAgentLifecycle() async throws {
        let registry = AsyncDelegationRegistry()

        // 1. Spawn (delegate).
        let spawned = try await delegate(
            subagentProfile: "auditor",
            task: "verify chapter 3",
            registry: registry
        )
        #expect(spawned.handle.state == .pending)

        // 2. Move to running.
        var running = spawned.handle
        running.state = .running
        await registry.update(running)
        let stored1 = await registry.get(id: spawned.handle.id)
        #expect(stored1?.state == .running)
        let active = await registry.runningDelegations()
        #expect(active.contains { $0.id == spawned.handle.id })

        // 3. Complete.
        await registry.markCompleted(id: spawned.handle.id, result: "verdict pass")
        let stored2 = await registry.get(id: spawned.handle.id)
        #expect(stored2?.state == .completed)

        // 4. cleanup() is a no-op for a fresh-completion (< 7 days old).
        await registry.cleanup()
        let stillThere = await registry.get(id: spawned.handle.id)
        #expect(stillThere != nil)

        // 5. recentCompleted() must surface the audit result.
        let recent = await registry.recentCompleted()
        #expect(recent.contains { $0.id == spawned.handle.id && $0.result == "verdict pass" })
    }
}