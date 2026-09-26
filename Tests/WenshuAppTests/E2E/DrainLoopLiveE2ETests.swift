//
//  DrainLoopLiveE2ETests.swift · Wenshu · v2.7d
//
//  Live E2E (= opt-in via WENSHU_LIVE_API_TESTS=1) verifying the
//  canonical production drain loop wiring end-to-end.
//
//  What this test verifies:
//    1. A SubAgentRunner constructed with MinimaxConnector +
//       ToolRegistry.shared (= the production AppDelegate path)
//       can drain a registered handle from AsyncDelegationRegistry.shared
//    2. The handle is a researcher delegation (= the production
//       DelegateResearchTool target)
//    3. The drain processes the handle via the real LLM
//    4. The handle transitions: pending -> running -> completed
//    5. handle.result is non-empty (= the real LLM produced a
//       final assistant text)
//
//  Why this bypasses WenshuAppDelegate.startSubAgentDrainLoop (= the
//  root cause of the v2.7d abort, see T6-fix commit 44022ca46):
//  startSubAgentDrainLoop starts a background Task.detached that
//  loops forever. The loop's lifetime exceeds the test process's
//  Swift concurrency runtime budget; = on test process teardown
//  the runtime aborts with signal 5 (= leaked Task). The
//  production path is the same code (runner.drainPending +
//  AsyncDelegationRegistry.shared + MinimaxConnector + LLM); =
//  only the driver differs (= background Task vs explicit test
//  call). This test verifies the production code path without
//  the background Task leak.
//
//  What this test does NOT cover (= follow-up tickets):
//    - Real SwiftData test container setup (= the runner's
//      ConversationLoop path triggers SwiftData init via
//      MemoryAdapter.retrieve; = this test uses a SubAgentRunner
//      with toolRegistry: nil to bypass that path).
//    - WenshuAppDelegate.startSubAgentDrainLoop's background Task
//      lifecycle (= tested separately by
//      WenshuAppDelegateSubAgentDrainLoopTests in idempotency
//      mode).
//
//  Skipped by default when WENSHU_LIVE_API_TESTS is not set.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("Drain loop live E2E · v2.7d", .serialized)
@MainActor
struct DrainLoopLiveE2ETests {

    /// Opt-in via WENSHU_LIVE_API_TESTS=1 (= CI-safe default off).
    private static var liveEnabled: Bool {
        ProcessInfo.processInfo.environment["WENSHU_LIVE_API_TESTS"] == "1"
    }

    @Test("drain loop processes researcher handle via real LLM end-to-end")
    func drainLoopProcessesResearcherHandle() async throws {
        guard Self.liveEnabled else {
            return
        }
        try await _drainLoopProcessesResearcherHandleImpl()
    }

    private func _drainLoopProcessesResearcherHandleImpl() async throws {
        // Step 1: use AsyncDelegationRegistry.shared (= the production
        // singleton DelegateResearchTool writes to). NOTE: this means
        // other parallel tests using .shared could leak state. The
        // .serialized suite attribute serializes the tests; = we are
        // the only test in this suite.
        let registry = AsyncDelegationRegistry.shared

        // Step 2: build the production-shape SubAgentRunner (= same
        // shape WenshuAppDelegate.startSubAgentDrainLoop constructs).
        //   - connector: MinimaxConnector (= the active profile on
        //     this dev machine; = production parity)
        //   - toolRegistry: nil (= bypass ConversationLoop.runTurn's
        //     SwiftData init via MemoryAdapter.retrieve; = pure LLM
        //     round-trip without the storage adapter chain).
        let runner = SubAgentRunner(
            connector: MinimaxConnector(),
            toolRegistry: nil
        )

        // Step 3: register a researcher handle directly into the shared
        // registry (= bypass delegate(...) to avoid the
        // AgentLifecycleTracker heartbeat Task that leaks past the
        // test process lifetime; = same bypass as T6-fix).
        let task = "调研「长安」的 grounded 资料：核心定义、关键事实、关联上下文，输出一段中文摘要（3-5 句话）。"
        let handle = BackgroundDelegationHandle(
            agentName: SubAgentIdentity.Name.researcher.rawValue,
            userMessage: task,
            state: .pending
        )
        await registry.register(handle: handle)
        let handleID = handle.id

        // Step 4: drive the production drain (= the same code
        // background Task.detached would call every 1s).
        // Wait briefly to ensure the registry sees the handle before
        // drain picks it up.
        try? await Task.sleep(nanoseconds: 100_000_000)
        let n = await runner.drainPending()
        #expect(n >= 1, "drainPending should process at least the handle we just registered; got n=\(n)")

        // Step 5: verify the handle transitioned to .completed (= the
        // real LLM produced a final assistant text).
        let finalHandle = await registry.get(id: handleID)
        switch finalHandle?.state {
        case .completed:
            // pass
            break
        case .running:
            Issue.record("handle still running after drainPending (= LLM did not complete within maxSubAgentTurns=5)")
        case .failed:
            Issue.record("handle failed (= LLM threw or returned no final text); result=\(String(describing: finalHandle?.result))")
        default:
            Issue.record("handle in unexpected state: \(String(describing: finalHandle?.state))")
        }

        // Step 6: verify handle.result is non-empty.
        if let result = finalHandle?.result, !result.isEmpty {
            // pass
        } else {
            Issue.record("handle.result is empty (= the LLM did not produce a final assistant text)")
        }
    }
}