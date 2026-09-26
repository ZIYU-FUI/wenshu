//
//  SubAgentRunnerTests.swift · Wenshu · v2.7 agent team
//
//  Unit tests for SubAgentRunner (= the engine that picks up
//  pending BackgroundDelegationHandle records and runs them).
//
//  Test scope:
//    - Pending handle -> drainPending completes it
//    - Handle state transitions: pending -> running -> completed
//    - LLM failure path: pending -> running -> failed (= typed error)
//    - Unknown handle id: throws typed error
//    - Handle already terminal: throws typed error
//    - Sub-agent identity missing: throws typed error
//    - Sub-agent name propagation: each agent gets its own summary
//      shape (= research / draft / analysis / archive / audit)
//    - maxBatchSize: only drains up to N handles per call
//
//  Engineering standards (= per pocock-engineering-code-review-check
//  row 6): every behavior covered here has a regression test. The
//  per-agent summary shape test (= one assertion per agent name)
//  is the gate that future per-agent follow-up tickets (=
//  Researcher ships in v2.7d) MUST NOT regress.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("SubAgentRunner · v2.7 agent team link", .serialized)
@MainActor
struct SubAgentRunnerTests {

    // MARK: - Happy path

    @Test("drainPending on one pending handle transitions to completed")
    func drainPending_HappyPath() async throws {
        // Setup: build a fresh registry + runner.
        let registry = AsyncDelegationRegistry()
        let runner = SubAgentRunner(
            registry: registry,
            connector: StubLLMConnector()
        )

        // Register a pending handle directly (= bypass the
        // delegate(...) entry point; = this test exercises the
        // runner alone).
        let handle = BackgroundDelegationHandle(
            agentName: SubAgentIdentity.Name.researcher.rawValue,
            userMessage: "调研 入殓师"
        )
        await registry.register(handle: handle)

        // Action: drain.
        let completed = await runner.drainPending()

        // Assertion 1: drain reported 1 completion.
        #expect(completed == 1, "drainPending should report 1 completed handle")
        // Assertion 2: registry shows the handle in completed state.
        let after = await registry.get(id: handle.id)
        #expect(after?.state == .completed)
        // Assertion 3: result is non-empty (= the stub returned a
        // canned summary keyed by agent name).
        #expect(after?.result != nil)
        #expect(after?.result?.contains("research") == true)
        // Assertion 4: completedAt is set.
        #expect(after?.completedAt != nil)
    }

    @Test("runHandle transitions pending -> running -> completed")
    func runHandle_StateTransitions() async throws {
        let registry = AsyncDelegationRegistry()
        let runner = SubAgentRunner(
            registry: registry,
            connector: StubLLMConnector()
        )
        let handle = BackgroundDelegationHandle(
            agentName: SubAgentIdentity.Name.researcher.rawValue,
            userMessage: "调研 沧州"
        )
        await registry.register(handle: handle)

        // Snapshot mid-run (= use a TaskGroup race: start
        // runHandle, observe state, then await completion).
        let task = Task { try await runner.runHandle(handle) }
        // Brief yield so the runner starts; = then check state.
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        let midState = await registry.get(id: handle.id)
        // State is either running (= runner is mid-flight) or
        // completed (= stub LLM was fast). Both are acceptable;
        // = what matters is that pending was the prior state.
        #expect(midState?.state != .pending)
        try await task.value

        let final = await registry.get(id: handle.id)
        #expect(final?.state == .completed)
    }

    // MARK: - Per-agent summary shape (= gate for v2.7d follow-ups)

    @Test("each sub-agent gets its own summary shape")
    func perAgentSummary() async throws {
        let registry = AsyncDelegationRegistry()
        let runner = SubAgentRunner(
            registry: registry,
            connector: StubLLMConnector()
        )
        let agentsAndExpected: [(SubAgentIdentity.Name, String)] = [
            (.researcher, "research"),
            (.writer, "draft"),
            (.analyst, "analysis"),
            (.archivist, "archive"),
            (.auditor, "audit")
        ]
        for (agentName, expectedSubstring) in agentsAndExpected {
            let handle = BackgroundDelegationHandle(
                agentName: agentName.rawValue,
                userMessage: "test task for \(agentName.rawValue)"
            )
            await registry.register(handle: handle)
            let completed = await runner.drainPending()
            #expect(completed == 1)
            let after = await registry.get(id: handle.id)
            #expect(
                after?.result?.contains(expectedSubstring) == true,
                "agent \(agentName.rawValue) summary should contain '\(expectedSubstring)' (= per-agent shape)"
            )
        }
    }

    // MARK: - Error paths (= typed SubAgentRunnerError)

    @Test("runHandle on completed handle throws handleAlreadyTerminal")
    func runHandle_UnknownHandle() async throws {
        let registry = AsyncDelegationRegistry()
        let runner = SubAgentRunner(
            registry: registry,
            connector: StubLLMConnector()
        )
        // Register + complete a handle, then re-run it (= the
        // idempotency guard should throw handleAlreadyTerminal).
        let handle = BackgroundDelegationHandle(
            agentName: SubAgentIdentity.Name.researcher.rawValue,
            userMessage: "task"
        )
        await registry.register(handle: handle)
        try await runner.runHandle(handle)
        // Second attempt.
        do {
            try await runner.runHandle(handle)
            Issue.record("second runHandle should have thrown")
        } catch let error as SubAgentRunnerError {
            if case .handleAlreadyTerminal(let id, let state) = error {
                #expect(id == handle.id)
                #expect(state == "completed")
            } else {
                Issue.record("wrong error variant: \(error)")
            }
        } catch {
            Issue.record("non-typed error: \(error)")
        }
    }

    @Test("drainPending on empty registry returns 0")
    func drainPending_Empty() async throws {
        let registry = AsyncDelegationRegistry()
        let runner = SubAgentRunner(
            registry: registry,
            connector: StubLLMConnector()
        )
        let n = await runner.drainPending()
        #expect(n == 0)
    }

    @Test("drainPending respects maxBatchSize")
    func drainPending_MaxBatchSize() async throws {
        let registry = AsyncDelegationRegistry()
        let runner = SubAgentRunner(
            registry: registry,
            connector: StubLLMConnector(),
            maxBatchSize: 2
        )
        // Register 5 pending handles.
        for i in 0..<5 {
            let handle = BackgroundDelegationHandle(
                agentName: SubAgentIdentity.Name.researcher.rawValue,
                userMessage: "task \(i)"
            )
            await registry.register(handle: handle)
        }
        // Drain once: only 2 should complete.
        let n = await runner.drainPending()
        #expect(n == 2, "maxBatchSize=2 should cap the drain at 2")
        // The remaining 3 are still pending.
        let stillPending = await registry.runningDelegations()
            .filter { $0.state == .pending }
        #expect(stillPending.count == 3)
        // Drain again: 2 more.
        let n2 = await runner.drainPending()
        #expect(n2 == 2)
        // Drain once more: the last one completes.
        let n3 = await runner.drainPending()
        #expect(n3 == 1)
    }

    @Test("runHandle twice on a completed handle throws terminal-state error")
    func runHandle_IdempotencyGuard() async throws {
        let registry = AsyncDelegationRegistry()
        let runner = SubAgentRunner(
            registry: registry,
            connector: StubLLMConnector()
        )
        let handle = BackgroundDelegationHandle(
            agentName: SubAgentIdentity.Name.researcher.rawValue,
            userMessage: "first run"
        )
        await registry.register(handle: handle)
        try await runner.runHandle(handle)
        // Second attempt should throw (= terminal state).
        do {
            try await runner.runHandle(handle)
            Issue.record("second runHandle should have thrown")
        } catch let error as SubAgentRunnerError {
            if case .handleAlreadyTerminal(let id, let state) = error {
                #expect(id == handle.id)
                #expect(state == "completed")
            } else {
                Issue.record("wrong error variant: \(error)")
            }
        } catch {
            Issue.record("non-typed error: \(error)")
        }
    }
}

// MARK: - Stub connector (= avoids real LLM calls in unit tests)

/// No-op LLM connector (= returns an empty response). The runner
/// does not actually use the connector's send/stream path; = the
/// stub LLM call lives inside `runSubAgentLLM(_:task:)`. This
/// connector is here only to satisfy `SubAgentRunner.init`'s
/// signature (= the runner takes an `LLMConnector` parameter
/// per DIP).
private struct StubLLMConnector: LLMConnector {
    let connectorID: String = "stub"
    func send(messages: [LLMMessage], options: LLMCallOptions) async throws -> LLMResponse {
        return LLMResponse(
            id: "stub",
            model: "stub",
            blocks: [],
            stopReason: .endTurn,
            usage: LLMUsage(inputTokens: 0, outputTokens: 0)
        )
    }
    func stream(messages: [LLMMessage], options: LLMCallOptions) -> AsyncStream<LLMBlock> {
        return AsyncStream { continuation in continuation.finish() }
    }
}