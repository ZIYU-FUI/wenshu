//
//  E2EDelegateResearchPathTests.swift = Wenshu's own acceptance suite
//
//  The delegate_research path (= a vague prompt makes the LLM emit
//  delegate_research, = = and the kanban gets the row).
//
//  WHY A SEPARATE FILE
//  ===================
//  The live end-to-end file holds three flows (= one prompt and its
//  memory write, = = the auto-triggered research, = = the delegate
//  path). = = The delegate flow is its own subject (= it asserts the
//  kanban row, = = not the memory write), = = and it lives here so the
//  other file stays under the project's line cap.
//

import Foundation
import os
import SwiftData
import Testing
import WenshuAgent
@testable import WenshuApp
import WenshuData

@Suite("E2E: a vague prompt delegates the research (LIVE)")
@MainActor
struct E2EDelegateResearchPathTests {
    // MARK: - delegate_research (= the fire-and-forget path)

    @Test("vague prompt -> LLM emits delegate_research (NOT web_search), kanban gets the row")
    func delegateResearchPath() async throws {
        guard E2ELive.enabled else {
            print("[E2E] skipped (= WENSHU_LIVE_API_TESTS not set)")
            return
        }

        // Step 0: prepare the user-bound reference store (= same
        // pattern as autoTriggerResearch; = delegate_research does
        // NOT touch the reference store directly, but the LLM's
        // reply may still cite context from previous research).
        let wsRoot = E2EShared.anbaiqiangWSRoot
        E2EShared.resetReferenceLibrary(wsRoot: wsRoot)
        let lifecycle = LibraryLifecycleHook(wsRoot: wsRoot)
        let launchResult: LibraryLaunchResult
        do {
            launchResult = try lifecycle.runLaunch()
        } catch {
            Issue.record("LibraryLifecycleHook.runLaunch failed: \(error)")
            return
        }
        let referenceStore = launchResult.stores.referenceStore
        print("[E2E] reference-library root = \(referenceStore.referenceLibraryRoot.path)")

        // Step 1: build the tool set. The LLM sees ONLY:
        //   - delegate_research (the new fire-and-forget path)
        //   - reference_library.find (so the LLM can check if a
        //     noun is already in the library before delegating)
        // NOT web_search (= the main agent must delegate the research
        // NOT do research itself; = it delegates).
        let delegateTool = DelegateResearchTool.shared
        let referenceLibraryTool = ReferenceLibraryTool(
            actor: ReferenceLibraryActor(referenceStore: referenceStore)
        )
        let delegateResearchSchema = ToolRegistrySchema(
            name: "delegate_research",
            description: """
            Delegate concrete-noun research to the Researcher sub-agent
            (fire-and-forget; = main agent does NOT block on web_search).
            The researcher sub-agent runs in the background, writes the
            grounded summary to reference_library (layer=entities,
            section_title=概要), and transitions the kanban task to done.
            You do NOT block waiting for the result; = you reply
            "已发起调研" immediately. The kanban task transitions to
            done when research completes (= the user does not need to poll).
            """,
            inputSchema: [
                "action": ToolRegistrySchemaProperty(
                    type: "string",
                    description: "The delegate operation to perform.",
                    enumValues: ["delegate"]
                ),
                "nouns": ToolRegistrySchemaProperty(
                    type: "string",
                    description: "Array of concrete proper nouns to research. Each noun becomes one researcher delegation + one kanban task (= 1..N per call). Required."
                ),
                "context": ToolRegistrySchemaProperty(
                    type: "string",
                    description: "Optional free-text context passed to the researcher sub-agent."
                ),
            ],
            required: ["action", "nouns"]
        )
        let referenceLibrarySchema = ToolRegistrySchema(
            name: "reference_library",
            description: """
            Library-public reference CRUD. Use action='find' to check
            whether a noun is already in the library before delegating
            (= if found, no new delegation is needed; = just extend).
            """,
            inputSchema: [
                "action": ToolRegistrySchemaProperty(
                    type: "string",
                    description: "The reference operation.",
                    enumValues: ["find"]
                ),
                "title": ToolRegistrySchemaProperty(
                    type: "string",
                    description: "Reference title (= required for find)."
                ),
            ],
            required: ["action"]
        )
        let tools: [String: any Tool] = [
            "delegate_research": delegateTool,
            "reference_library": referenceLibraryTool,
        ]
        let toolSchemas: [ToolRegistrySchema] = [delegateResearchSchema, referenceLibrarySchema]
        print("[E2E] step 1 done: tools = {delegate_research, reference_library}; = NO web_search (= main agent delegates)")

        // Step 2: wire the real minimax connector + RecordingLLMConnector
        // (= observe what the LLM actually does).
        let realConnector = MinimaxConnector()
        let recording = RecordingLLMConnector(wrapping: realConnector)
        let loop = ConversationLoop(connection: recording)

        // Step 3: vague prompt (= same wording as autoTriggerResearch; the
        // name is withheld, a profession and a birthplace are given).
        let userMessage = """
        我想写一部小说，主角名字还没想好。
        设定是入殓师职业，出生在沧州。
        你看怎么规划？
        """

        // Step 4: run the turn.
        let result = try await loop.runTurn(
            userMessage: userMessage,
            systemMessage: nil,
            conversationHistory: [],
            tools: tools,
            taskId: "e2e-003-delegate",
            toolSchemas: toolSchemas
        )

        // Step 5: verify the LLM actually called delegate_research
        // (= NOT web_search, since web_search is NOT in the tool set).
        let captured = await recording.capturedCalls()
        var emittedToolUseNames: Set<String> = []
        for call in captured {
            for block in call.response.blocks {
                if case let .toolUse(_, name, _) = block {
                    emittedToolUseNames.insert(name)
                }
            }
        }
        print("[E2E] LLM send calls captured = \(captured.count)")
        for (idx, call) in captured.enumerated() {
            let toolNames = call.response.blocks.compactMap { block -> String? in
                if case let .toolUse(_, name, _) = block {
                    return name
                }
                return nil
            }
            print("[E2E]   call[\(idx)] blocks=\(call.response.blocks.count) toolUse_in_response=\(toolNames)")
        }
        print("[E2E] LLM-emitted tool_use names (across all calls): \(emittedToolUseNames.sorted().joined(separator: ", "))")

        // Step 6: verify kanban got a row per detected noun
        // (= the user-visible progress surface for delegation).
        let kanbanTasks = (try? await WSKanbanRepository.shared.list()) ?? []
        let researchTasks = kanbanTasks.filter { $0.title.hasPrefix("research: ") }
        print("[E2E] kanban tasks total = \(kanbanTasks.count); research-prefixed = \(researchTasks.count)")
        for task in researchTasks {
            print("[E2E]   kanban task: id=\(task.id) title=\"\(task.title)\" status=\(task.status) priority=\(task.priority)")
        }

        // Step 7: extract the LLM's final reply text (= for the
        // boss visual proof).
        let resultTexts = result.response.blocks.compactMap { block -> String? in
            if case let .text(s) = block {
                return s
            }
            return nil
        }
        let resultTextBlob = resultTexts.joined(separator: "\n")
        print("")
        print("========== [E2E] delegate_research path summary ==========")
        print("LLM send calls (one LLM round-trip per call):       \(captured.count)")
        print("LLM-emitted tool_use names (across all calls):      \(emittedToolUseNames.sorted().joined(separator: ", "))")
        print("Kanban 'research: <noun>' tasks added:              \(researchTasks.count)")
        for task in researchTasks {
            print("  - id=\(task.id) title=\"\(task.title)\"")
        }
        print("Final reply (\(resultTextBlob.count) chars):")
        print(resultTextBlob)
        print("======================================================================")

        // Acceptance: the LLM must have emitted delegate_research
        // (= not web_search, since web_search isn't in the tool set).
        #expect(
            emittedToolUseNames.contains("delegate_research"),
            "LLM must use delegate_research (= the boss 2026-09-25 fire-and-forget path; = main agent does NOT call web_search directly)"
        )
        #expect(
            !emittedToolUseNames.contains("web_search"),
            "LLM must NOT call web_search directly (= web_search is not in this tool set; = delegate_research is the path)"
        )
        #expect(
            captured.count >= 1,
            "ConversationLoop.runTurn must call LLM at least once"
        )
        // Acceptance: kanban must have at least one research-prefixed
        // task (= the user-visible delegation record). The LLM may
        // emit multiple delegate_research calls (= one per detected
        // noun); = each registers one kanban row.
        #expect(
            researchTasks.count >= 1,
            "kanban must record at least one 'research: <noun>' task (= the delegation surface for the user)"
        )
        // Acceptance: each kanban task title starts with "research: "
        // (= the canonical delegate_research marker).
        for task in researchTasks {
            #expect(task.title.hasPrefix("research: "))
        }
    }
}
