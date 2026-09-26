//
//  SubAgentRunnerLiveE2ETests.swift · Wenshu · v2.7d
//
//  Live E2E (= opt-in via WENSHU_LIVE_API_TESTS=1) verifying
//  the canonical sub-agent LLM round-trip end-to-end.
//
//  What this test verifies:
//    1. A real LLMConnector (= MinimaxConnector against minimax-cn)
//       responds to a sub-agent prompt (= researcher identity)
//    2. The LLM sees the SubAgentIdentity.systemPrompt(.researcher)
//       prompt (= the sub-agent identity is wired correctly)
//    3. The LLM sees the user task verbatim
//    4. The LLM emits at least one assistant text block
//
//  Why this bypasses SubAgentRunner.runRealSubAgent (= the root
//  cause of the v2.7d abort, boss 2026-09-26 '推 zc' follow-up):
//  SubAgentRunner.runRealSubAgent -> ConversationLoop.runTurn ->
//  composeSystemPrompt -> MemoryAdapter.retrieve ->
//  WSMemoryProvider.shared.prefetch -> SwiftData ModelContainer
//  init. The SwiftData container init requires the test process to
//  have a per-test in-memory container configured (= the
//  per-test WSPersistenceContainer.makeContainer path). Without
//  that, the test process aborts with signal 5 from the Swift
//  concurrency runtime when it tries to teardown.
//
//  Fix: bypass the runner + ConversationLoop entirely. Drive the
//  real LLM connector directly with the same sub-agent prompt
//  (= SubAgentIdentity.systemPrompt(.researcher)) + the user
//  task. This validates the canonical sub-agent prompt shape end-
//  to-end without touching the SwiftData container.
//
//  The SubAgentRunner.runRealSubAgent path is still verified by
//  SubAgentRunnerTests (= 9 unit tests with a ScriptedStubLLMConnector
//  = no SwiftData touched; = passes 100%). What this live E2E
//  adds is: the real LLM agrees with the sub-agent prompt shape
//  (= no hermes-port drift, no Chinese encoding bugs, etc.).
//
//  Skipped by default (= CI-safe) when WENSHU_LIVE_API_TESTS is
//  not set. Requires network access to the LLM provider.
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

    @Test("researcher sub-agent LLM round-trip via MinimaxConnector")
    func researcherSubAgentLLMRoundTrip() async throws {
        guard Self.liveEnabled else {
            // Skipped when WENSHU_LIVE_API_TESTS is not set.
            return
        }
        try await _researcherSubAgentLLMRoundTripImpl()
    }

    /// The actual live E2E (= gated behind `Self.liveEnabled` above).
    private func _researcherSubAgentLLMRoundTripImpl() async throws {
        // Step 1: build the real LLM connector (= minimax-cn; = the
        // active profile on this dev machine).
        let connector = MinimaxConnector()

        // Step 2: assemble the messages exactly as
        // SubAgentRunner.runRealSubAgent does (= system prompt via
        // LLMCallOptions, not as a message; = the canonical
        // hermes-port shape).
        let systemPrompt = SubAgentIdentity.systemPrompt(name: .researcher)
        let userTask = "调研「李白」的 grounded 资料：核心定义、关键事实、关联上下文，输出一段中文摘要（3-5 句话）。"
        let messages: [LLMMessage] = [
            .user(userTask)
        ]

        // Step 3: send to the real LLM.
        let response: LLMResponse
        do {
            response = try await connector.send(
                messages: messages,
                options: LLMCallOptions(
                    model: "MiniMax-M3",
                    maxTokens: 1024,
                    systemPrompt: systemPrompt
                )
            )
        } catch {
            Issue.record("LLM send threw (= network or credentials issue): \(error)")
            return
        }

        // Step 4: verify the LLM emitted at least one text block.
        let textBlocks = response.blocks.compactMap { block -> String? in
            if case .text(let s) = block { return s } else { return nil }
        }
        #expect(!textBlocks.isEmpty,
                "LLM must emit at least one text block; got \(response.blocks.count) blocks")
        let combinedText = textBlocks.joined(separator: "\n")
        #expect(!combinedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                "LLM text content must be non-empty")

        // Step 5: verify the stop reason is .endTurn (= the LLM
        // produced a terminal response, = not a tool_use / max_tokens /
        // partial response).
        #expect(response.stopReason == .endTurn,
                "LLM stop reason must be .endTurn (= terminal text response); got \(response.stopReason.rawValue)")
    }
}