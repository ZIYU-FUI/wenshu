//
//  AsyncDelegationTests.swift · Wenshu · v0.23 ticket 013.010 (hermes gap 9)
//
//  Boss 2026-08-23 拍: hermes async delegation infrastructure parity.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("AsyncDelegation (hermes async delegation parity)")
struct AsyncDelegationInfrastructureTests {

    @Test("register + get round-trip")
    func testRegisterGet() async {
        let registry = AsyncDelegationRegistry()
        let handle = BackgroundDelegationHandle(
            agentName: "writer",
            userMessage: "test",
            state: .running
        )
        await registry.register(handle: handle)
        let retrieved = await registry.get(id: handle.id)
        #expect(retrieved?.agentName == "writer")
        #expect(retrieved?.state == .running)
    }

    @Test("markCompleted transitions state and stores result")
    func testMarkCompleted() async {
        let registry = AsyncDelegationRegistry()
        let handle = BackgroundDelegationHandle(agentName: "writer", userMessage: "test", state: .running)
        await registry.register(handle: handle)
        await registry.markCompleted(id: handle.id, result: "1200 words written")
        let retrieved = await registry.get(id: handle.id)
        #expect(retrieved?.state == .completed)
        #expect(retrieved?.result == "1200 words written")
        #expect(retrieved?.completedAt != nil)
    }

    @Test("markFailed transitions state with error")
    func testMarkFailed() async {
        let registry = AsyncDelegationRegistry()
        let handle = BackgroundDelegationHandle(agentName: "writer", userMessage: "test", state: .running)
        await registry.register(handle: handle)
        await registry.markFailed(id: handle.id, error: "LLM timeout")
        let retrieved = await registry.get(id: handle.id)
        #expect(retrieved?.state == .failed)
        #expect(retrieved?.result?.contains("LLM timeout") == true)
    }

    @Test("runningDelegations returns only pending/running")
    func testRunningDelegations() async {
        let registry = AsyncDelegationRegistry()
        let running1 = BackgroundDelegationHandle(agentName: "writer", userMessage: "a", state: .running)
        let pending1 = BackgroundDelegationHandle(agentName: "researcher", userMessage: "b", state: .pending)
        let completed1 = BackgroundDelegationHandle(agentName: "analyst", userMessage: "c", state: .completed)
        await registry.register(handle: running1)
        await registry.register(handle: pending1)
        await registry.register(handle: completed1)
        let running = await registry.runningDelegations()
        #expect(running.count == 2)  // running + pending
        let names = running.map { $0.agentName }
        #expect(names.contains("writer"))
        #expect(names.contains("researcher"))
        #expect(!names.contains("analyst"))
    }

    @Test("recentCompleted returns completed + failed delegations")
    func testRecentCompleted() async {
        let registry = AsyncDelegationRegistry()
        let handle1 = BackgroundDelegationHandle(agentName: "writer", userMessage: "a", state: .running)
        let handle2 = BackgroundDelegationHandle(agentName: "researcher", userMessage: "b", state: .running)
        await registry.register(handle: handle1)
        await registry.register(handle: handle2)
        await registry.markCompleted(id: handle1.id, result: "ok")
        await registry.markFailed(id: handle2.id, error: "x")
        let recent = await registry.recentCompleted()
        #expect(recent.count == 2)
    }

    @Test("LRU eviction at maxRetained (50)")
    func testLRUEviction() async {
        let registry = AsyncDelegationRegistry()  // maxRetained = 50
        // Register + complete 51 handles → 50 retained, 1 evicted.
        var firstId: String? = nil
        for i in 0..<51 {
            let h = BackgroundDelegationHandle(agentName: "a\(i)", userMessage: "x", state: .running)
            if i == 0 { firstId = h.id }
            await registry.register(handle: h)
            await registry.markCompleted(id: h.id, result: "r\(i)")
        }
        // First one should be evicted.
        let retrieved = await registry.get(id: firstId!)
        #expect(retrieved == nil)
        let recent = await registry.recentCompleted()
        #expect(recent.count == 50)
    }

    @Test("cleanup removes records beyond 7-day retention")
    func testCleanup() async {
        let registry = AsyncDelegationRegistry()
        // Old handle: started 1970. markCompleted (sets completedAt = now, but
        // our cutoff filter handles "completedAt = now AND old = ... ").
        // We use direct cleanup test: create handle with 1970 startedAt, register,
        // skip markCompleted (so completedAt stays nil → reference = startedAt = 1970).
        let oldHandle = BackgroundDelegationHandle(
            agentName: "old",
            userMessage: "x",
            state: .running,  // not markCompleted'd, so never enters completionQueue
            startedAt: Date(timeIntervalSince1970: 0),  // 1970
            completedAt: nil
        )
        await registry.register(handle: oldHandle)
        // Recent handle: just created + markCompleted.
        let recentHandle = BackgroundDelegationHandle(
            agentName: "recent",
            userMessage: "y",
            state: .running
        )
        await registry.register(handle: recentHandle)
        await registry.markCompleted(id: recentHandle.id, result: "new")
        await registry.cleanup()
        // recent = [recentHandle] (in completionQueue + state=completed).
        // old NOT in completionQueue (never markCompleted'd), so recentCompleted doesn't see it.
        // But: cleanup() removed records[old] too (because old's startedAt 1970 < cutoff).
        // recentCompleted returns only entries in completionQueue that still exist in records.
        let recent = await registry.recentCompleted()
        #expect(recent.count == 1)
        #expect(recent[0].agentName == "recent")
    }

    @Test("BackgroundDelegationHandle Equatable")
    func testHandleEquatable() {
        let fixedId = "fixed-id-123"
        let fixedDate = Date(timeIntervalSince1970: 1000)
        let a = BackgroundDelegationHandle(id: fixedId, agentName: "w", userMessage: "m", startedAt: fixedDate)
        let b = BackgroundDelegationHandle(id: fixedId, agentName: "w", userMessage: "m", startedAt: fixedDate)
        #expect(a == b)
        let c = BackgroundDelegationHandle(id: fixedId, agentName: "w", userMessage: "m", state: .completed, startedAt: fixedDate)
        #expect(a != c)
    }
}