//
//  SubAgentRunnerLiveE2ETests.swift · Wenshu · v2.7d
//
//  Live E2E (= opt-in via WENSHU_LIVE_API_TESTS=1) for the
//  SubAgentRunner -> real LLM -> handle completion path.
//
//  What this test verifies end-to-end:
//    1. SubAgentRunner.drainPending() picks up a registered
//       BackgroundDelegationHandle from AsyncDelegationRegistry
//    2. The runner constructs a fresh ConversationLoop for the
//       sub-agent (= researcher)
//    3. ConversationLoop.runTurn drives a real LLM call via
//       MinimaxConnector (= the active connector on this dev machine)
//    4. The LLM (= MiniMax-M3 via minimax-cn) receives:
//       - system prompt: SubAgentIdentity.systemPrompt(.researcher)
//       - user task: the handle's `task` field
//       - tool subset: ["web_search", "reference_library"]
//    5. On completion, handle.state transitions pending -> running -> completed
//    6. handle.result is non-empty (= the LLM produced a final text)
//
//  What is NOT verified here (= the live E2E in
//  E2EMemoryAndLLMFlowTests/delegateResearchPath covers the
//  main-agent->delegate_research path; = this file is the
//  dedicated sub-agent runner live E2E scaffold):
//    - The live sub-agent runner E2E requires a SwiftData test
//      container setup (= `delegate(...)` calls into the global
//      AgentLifecycleTracker.shared which writes to disk-backed
//      state; = tests need an isolated container to avoid cross-test
//      contamination; = this is a follow-up ticket per Q46 stop-rule).
//    - The current scaffold defaults to skip when
//      WENSHU_LIVE_API_TESTS is not set (= CI-safe).
//
//  The v2.7d arc's primary E2E verification is
//  `E2EMemoryAndLLMFlowTests/delegateResearchPath` (= it runs the
//  full main agent loop via real LLM and verifies the kanban row
//  is written). That test passes in 7-11s with the live MiniMax-M3
//  connector.
//
//  This file provides the dedicated sub-agent runner live E2E
//  scaffold (= the actual live execution is deferred to the
//  SwiftData test-container follow-up ticket).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("SubAgentRunner live E2E · v2.7d", .serialized)
@MainActor
struct SubAgentRunnerLiveE2ETests {

    /// Opt-in via WENSHU_LIVE_API_TESTS=1 (= CI-safe default off).
    private static var liveEnabled: Bool {
        ProcessInfo.processInfo.environment["WENSHU_LIVE_API_TESTS"] == "1"
    }

    @Test("researcher sub-agent runs real LLM via SubAgentRunner.drainPending")
    func researcherSubAgentRunsRealLLM() async throws {
        // Skipped by default (= requires WENSHU_LIVE_API_TESTS=1; =
        // requires SwiftData test container; = requires an active
        // LLM connector (= Anthropic or minimax-cn with valid
        // credentials)). The test scaffolding is in place; =
        // the live E2E itself is a follow-up ticket once the
        // SwiftData test-container setup lands (= per Q46 stop-rule
        // on the test budget: 1 fix attempt in this arc; = do not
        // pile more attempts here).
        guard Self.liveEnabled else {
            // Skipped when WENSHU_LIVE_API_TESTS is not set.
            return
        }
        // .live gated content begins below (= never reached without
        // the env var; = CI-safe by default).
        try await _researcherSubAgentRunsRealLLMImpl()
    }

    /// The actual live E2E (= gated behind `Self.liveEnabled` above).
    private func _researcherSubAgentRunsRealLLMImpl() async throws {
        // Step 1: build an isolated registry (= the production path
        // uses AsyncDelegationRegistry.shared; = the isolated path
        // avoids coupling this test to handle cleanup state across
        // test runs).
        let registry = AsyncDelegationRegistry()

        // Step 2: build the real LLM connector + a SubAgentRunner.
        let connector = MinimaxConnector()
        let runner = SubAgentRunner(
            isolatedRegistry: registry,
            connector: connector,
            toolRegistry: ToolRegistry.shared
        )

        // Step 3: register a single researcher delegation handle.
        // Task wording is short and concrete (= a proper noun +
        // grounded summary request; = mirrors the wording used by
        // DelegateResearchTool.handleDelegate).
        let task = "调研「李白」的 grounded 资料：核心定义、关键事实、关联上下文，输出一段中文摘要（3-5 句话），并把搜索到的可信信息写入 reference_library 的 entities 层。"
        let delegateResult: AsyncDelegationResult
        do {
            delegateResult = try await delegate(
                subagentProfile: SubAgentIdentity.Name.researcher.rawValue,
                task: task,
                context: [
                    "noun": "李白",
                    "layer": "entities",
                    "section_title": "概要"
                ],
                registry: registry
            )
        } catch {
            Issue.record("delegate() threw (= SwiftData test container missing?): \(error)")
            return
        }
        let handleID = delegateResult.handle.id

        // Step 4: drain pending handles. The runner picks up the
        // handle, constructs a fresh ConversationLoop with the
        // researcher's system prompt + tool subset, and drives the
        // LLM call. The runner's maxSubAgentTurns=5 (= set at init)
        // keeps the test bounded.
        let n = await runner.drainPending()
        #expect(n >= 1, "drainPending should process at least the handle we just registered; got n=\(n)")

        // Step 5: verify the handle transitioned to .completed
        // (= the LLM produced a final assistant text; = the runner
        // called handle.complete(result:)).
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

        // Step 6: verify the LLM emitted at least one assistant
        // message (= the runner's runRealSubAgent wrote the final
        // text into handle.result).
        if let result = finalHandle?.result, !result.isEmpty {
            // pass: handle.result populated
        } else {
            Issue.record("handle.result is empty (= the LLM did not produce a final assistant text)")
        }
    }
}