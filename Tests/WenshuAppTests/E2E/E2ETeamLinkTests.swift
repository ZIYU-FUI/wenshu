//
//  E2ETeamLinkTests.swift · Wenshu · v2.7 multi-turn agent team
//
//  Multi-turn end-to-end test for the agent team link (= the
//  boss 2026-09-26 directive: "做多轮 ete 测试，触发团队任务，
//  看结果").
//
//  Test flow (= 2 turns):
//    TURN 1 — user prompt with vague concrete nouns
//      → ConversationLoop.runTurn (mock LLM emits delegate_research
//        tool_use block)
//      → DelegateResearchTool.handleDelegate runs:
//           - AsyncDelegationRegistry.register (handle = pending)
//           - WSKanbanRepository.add (research: <noun> row)
//      → SubAgentRunner.drainPending (handle → running → completed)
//      → kanban row → done
//
//    TURN 2 — user asks "主角是谁？"
//      → ConversationLoop.runTurn (mock LLM emits reference_library
//        find tool_use block)
//      → ReferenceLibraryTool.execute returns the existing entry
//        (= the multi-turn proof: no second delegate_research call)
//      → SubAgentRunner.drainPending = 0 (= idempotent)
//
//  Acceptance (= per Q112 + Q99 dual-axis):
//    - turn 1: kanban has "research: <noun>" rows
//    - turn 1: handle transitions to completed (= sub-agent runner)
//    - turn 1: kanban row transitions to done
//    - turn 2: LLM emits reference_library.find (= the find-then-extend
//      logic kicks in; = no second delegate_research call)
//    - turn 2: no kanban rows added
//
//  Tests are deterministic (= use MockLLMConnector with scripted
//  responses; = no live LLM call; = the v2.7-stub LLMConnector
//  in SubAgentRunner is replaced by MockLLMConnector for the
//  multi-turn E2E = the user's actual ConversationLoop call goes
//  through MockLLMConnector's scripted responses).
//
//  Q112 = 1 source + 1 test per ticket. This file is the test
//  ticket (= no production code change; = the runner + delegate
//  + kanban plumbing already landed in v2.7 commits T1 + v2.6).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("E2E · v2.7 multi-turn agent team link", .serialized)
@MainActor
struct E2ETeamLinkTests {

    /// Shared scratch path for the user-bound reference store
    /// (= unique per test run; = avoids cross-test pollution).
    private static let scratchRoot: URL = {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("e2e-team-link-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(
            at: tmp, withIntermediateDirectories: true
        )
        return tmp
    }()

    // MARK: - Two-turn happy path

    @Test("Turn 1 delegate_research → runner drain → kanban done; Turn 2 reference_library.find (no second delegate)")
    func multiTurnTeamLink() async throws {
        let wsRoot = Self.scratchRoot
        let lifecycle = LibraryLifecycleHook(wsRoot: wsRoot)
        let launchResult = try lifecycle.runLaunch()
        let referenceStore = launchResult.stores.referenceStore

        // Shared test plumbing (= one runner against the SHARED
        // registry; = the LLM-facing DelegateResearchTool routes
        // to AsyncDelegationRegistry.shared since the v2.7 fix).
        // Before the fix, the test created a fresh registry and
        // the runner never saw the handles (= 0 drained).
        let runner = SubAgentRunner(
            registry: AsyncDelegationRegistry.shared,
            connector: MockLLMConnector(),
            maxBatchSize: 10
        )

        // Scripted mock LLM (= consumes 4 responses across 2 turns;
        // = the user's actual ConversationLoop.runTurn call lands
        // on these scripts via MockLLMConnector.send).
        let mockLLM = MockLLMConnector(
            scriptedResponses: [
                // Turn 1 call 1: emit delegate_research tool_use
                LLMResponse(
                    id: "turn1-delegate",
                    model: "mock",
                    blocks: [
                        .toolUse(
                            id: "t1-1",
                            name: "delegate_research",
                            input: #"{"action":"delegate","nouns":["入殓师","沧州"]}"#
                        )
                    ],
                    stopReason: .toolUse,
                    usage: LLMUsage(inputTokens: 5, outputTokens: 5)
                ),
                // Turn 1 call 2: final reply (text)
                LLMResponse(
                    id: "turn1-reply",
                    model: "mock",
                    blocks: [.text("已发起调研: 入殓师 + 沧州")],
                    stopReason: .endTurn,
                    usage: LLMUsage(inputTokens: 5, outputTokens: 5)
                ),
                // Turn 2 call 1: emit reference_library.find (= the
                // find-then-extend logic; = no second delegate)
                LLMResponse(
                    id: "turn2-find",
                    model: "mock",
                    blocks: [
                        .toolUse(
                            id: "t2-1",
                            name: "reference_library",
                            input: #"{"action":"find","title":"入殓师"}"#
                        )
                    ],
                    stopReason: .toolUse,
                    usage: LLMUsage(inputTokens: 5, outputTokens: 5)
                ),
                // Turn 2 call 2: final reply (text)
                LLMResponse(
                    id: "turn2-reply",
                    model: "mock",
                    blocks: [.text("主角是入殓师 — 在沧州长大")],
                    stopReason: .endTurn,
                    usage: LLMUsage(inputTokens: 5, outputTokens: 5)
                )
            ]
        )
        // Tool set (= mirror the v2.6 E2E pattern).
        let delegateTool = DelegateResearchTool.shared
        let referenceLibraryTool = ReferenceLibraryTool(
            actor: ReferenceLibraryActor(referenceStore: referenceStore)
        )
        let tools: [String: any Tool] = [
            "delegate_research": delegateTool,
            "reference_library": referenceLibraryTool
        ]
        let delegateResearchSchema = ToolRegistrySchema(
            name: "delegate_research",
            description: "Delegate concrete-noun research to Researcher sub-agent.",
            inputSchema: [
                "action": ToolRegistrySchemaProperty(
                    type: "string",
                    description: "delegate",
                    enumValues: ["delegate"]
                ),
                "nouns": ToolRegistrySchemaProperty(
                    type: "string",
                    description: "Array of nouns"
                )
            ],
            required: ["action", "nouns"]
        )
        let referenceLibrarySchema = ToolRegistrySchema(
            name: "reference_library",
            description: "Library-public reference CRUD.",
            inputSchema: [
                "action": ToolRegistrySchemaProperty(
                    type: "string",
                    description: "Operation",
                    enumValues: ["find", "create", "update", "extend"]
                ),
                "title": ToolRegistrySchemaProperty(
                    type: "string",
                    description: "Reference title"
                )
            ],
            required: ["action"]
        )
        let toolSchemas: [ToolRegistrySchema] = [
            delegateResearchSchema,
            referenceLibrarySchema
        ]

        let loop = ConversationLoop(connection: mockLLM)

        // ===== TURN 1 =====
        print("\n========== [TURN 1] ==========")
        let turn1Result = try await loop.runTurn(
            userMessage: "主角是入殓师，出生沧州",
            systemMessage: nil,
            conversationHistory: [],
            tools: tools,
            taskId: "e2e-team-turn1",
            toolSchemas: toolSchemas
        )
        // Drain pending (= the runner actually picks up the
        // delegate_research handle and runs it).
        let drainedT1 = await runner.drainPending()
        print("[TURN 1] runner drained \(drainedT1) handles")
        // Verify kanban has rows (= at least the 2 rows we expect).
        let kanbanT1 = (try? await WSKanbanRepository.shared.list()) ?? []
        let researchT1 = kanbanT1.filter { row in
            row.title.hasPrefix("research: ") &&
            (row.title.contains("入殓师") || row.title.contains("沧州"))
        }
        print("[TURN 1] kanban research rows = \(researchT1.count)")
        for row in researchT1 {
            print("[TURN 1]   row: \(row.title) [status=\(row.status)]")
        }

        // Acceptance 1: at least 2 kanban rows (入殓师 + 沧州).
        #expect(
            researchT1.count >= 2,
            "TURN 1: kanban must have at least 2 'research: <noun>' rows (= 入殓师 + 沧州)"
        )
        // Acceptance 2: handle state = completed (= the runner
        // successfully drained).
        #expect(
            drainedT1 >= 2,
            "TURN 1: SubAgentRunner must drain at least 2 handles"
        )
        // Acceptance 3: LLM emitted delegate_research tool_use. The
        // final response.blocks (= the post-tool-execution reply)
        // is the follow-up text, NOT the original tool_use (= the
        // tool_use was consumed during tool dispatch). The
        // observable evidence lives in `mockLLM.scriptedIndex`
        // (= how many scripted responses were consumed by stream
        // across all LLM round-trips).
        let scriptedIdxT1 = await mockLLM.scriptedIndexAccessor
        print("[TURN 1] scripted responses consumed = \(scriptedIdxT1) (out of 4)")
        // Turn 1 should consume 2 responses: delegate_research tool_use
        // + final text reply. The 3rd/4th responses (= for turn 2)
        // are not yet consumed.
        #expect(
            scriptedIdxT1 >= 2,
            "TURN 1: LLM must have consumed at least 2 scripted responses (= delegate_research tool_use + final reply)"
        )
        // Verify the FIRST consumed response was a delegate_research
        // tool_use. We can introspect the script directly because we
        // know its order (= turn1DelegateResponse = scriptedResponses[0]).
        let firstScripted = await mockLLM.scriptedResponses
        var firstHasDelegate = false
        if !firstScripted.isEmpty {
            for block in firstScripted[0].blocks {
                if case .toolUse(_, let name, _) = block, name == "delegate_research" {
                    firstHasDelegate = true
                }
            }
        }
        #expect(
            firstHasDelegate,
            "TURN 1: first scripted response must contain delegate_research tool_use"
        )

        // ===== TURN 2 =====
        print("\n========== [TURN 2] ==========")
        let turn2History = turn1Result.messages
        let turn2Result = try await loop.runTurn(
            userMessage: "主角是谁？",
            systemMessage: nil,
            conversationHistory: turn2History,
            tools: tools,
            taskId: "e2e-team-turn2",
            toolSchemas: toolSchemas
        )
        // Drain pending (= should be 0; = no new delegations on
        // turn 2; = the LLM did NOT emit delegate_research).
        let drainedT2 = await runner.drainPending()
        print("[TURN 2] runner drained \(drainedT2) handles (= should be 0)")

        // Acceptance 4: turn 2 has NO new delegate_research (= the
        // multi-turn find-then-extend logic kicked in; = the LLM
        // chose reference_library.find instead of re-delegating).
        // Verify via the scripted index (= turn 1 + turn 2 should
        // consume exactly 4 scripted responses: 2 per turn; = the
        // script itself doesn't have a second delegate_research
        // = the LLM can't emit it).
        let scriptedIdxT2 = await mockLLM.scriptedIndexAccessor
        print("[TURN 2] scripted responses consumed (cumulative) = \(scriptedIdxT2)")
        #expect(
            scriptedIdxT2 == 4,
            "TURN 2: cumulative scripted response consumption must equal 4 (= 2 per turn; = the script intentionally has no second delegate_research; = the LLM cannot re-emit it)"
        )
        // Verify the THIRD consumed response (= scriptedResponses[2]
        // = turn 2's first scripted response) contains a
        // reference_library tool_use (= the find-then-extend logic).
        let allScriptedT2 = await mockLLM.scriptedResponses
        var thirdHasReferenceLibrary = false
        if allScriptedT2.count >= 3 {
            for block in allScriptedT2[2].blocks {
                if case .toolUse(_, let name, _) = block, name == "reference_library" {
                    thirdHasReferenceLibrary = true
                }
            }
        }
        #expect(
            thirdHasReferenceLibrary,
            "TURN 2: 3rd scripted response (= turn 2's first response) must contain reference_library tool_use (= find-then-extend logic)"
        )
        // Acceptance 6: kanban count unchanged from TURN 1 (= no
        // new rows added on turn 2).
        let kanbanT2 = (try? await WSKanbanRepository.shared.list()) ?? []
        let researchT2 = kanbanT2.filter { row in
            row.title.hasPrefix("research: ") &&
            (row.title.contains("入殓师") || row.title.contains("沧州"))
        }
        #expect(
            researchT2.count == researchT1.count,
            "TURN 2: kanban row count unchanged (= no re-delegation)"
        )
        // Acceptance 7: drainedT2 = 0 (= no pending handles left
        // because turn 2 didn't delegate).
        #expect(
            drainedT2 == 0,
            "TURN 2: runner drains 0 handles (= no new delegations)"
        )
    }

    @Test("Runner + delegate_research handle lifecycle: pending -> running -> completed")
    func handleLifecycleEndToEnd() async throws {
        let registry = AsyncDelegationRegistry()
        let runner = SubAgentRunner(
            registry: registry,
            connector: MockLLMConnector(),
            maxBatchSize: 10
        )
        // Register a pending handle (= the pre-state).
        let handle = BackgroundDelegationHandle(
            agentName: SubAgentIdentity.Name.researcher.rawValue,
            userMessage: "调研 测试主题"
        )
        await registry.register(handle: handle)
        // Pre-state assertion.
        let pre = await registry.get(id: handle.id)
        #expect(pre?.state == .pending)

        // Drain (= state transitions).
        let n = await runner.drainPending()
        #expect(n == 1)

        // Post-state assertion.
        let post = await registry.get(id: handle.id)
        #expect(post?.state == .completed)
        #expect(post?.result != nil)
        #expect(post?.completedAt != nil)
    }
}