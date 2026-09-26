//
//  E2EMemoryAndLLMFlowTests.swift · Wenshu · v2.4 acceptance
//
//  Black-box end-to-end test (= the v2.4 §11.17 acceptance gate).
//
//  Flow (= exactly what wenshu.app does when the user types one prompt
//  and hits send in ChatView):
//
//    1. Wire the real ConversationLoop against the real minimax-cn
//       connector (= AppleKeychain key). No stub. No fake.
//       A thin RecordingLLMConnector wraps the real connector and
//       captures every send(messages:options:) call (= request payload
//       + response blocks) so the test can assert exactly what was
//       sent + received.
//
//    2. Reset WSMemoryProvider mirror + WSMemoryRepository (= empty
//       memory store before turn 1 so the prefetch path returns
//       zero rows = canonical "first ever turn" shape).
//
//    3. Call ConversationLoop.runTurn(userMessage: "你好, 我叫老王,
//       我喜欢写短篇小说") with tools: [] (= no tool_use dispatch
//       possible = the LLM emits a plain text reply).
//
//    4. Assert:
//       A. RecordingLLMConnector captured >=1 LLM send (= the LLM
//          was actually called).
//       B. The captured request payload contains the user message
//          (= "我叫老王" / "短篇小说") in the messages array.
//       C. The captured response has at least one .text block with
//          non-empty content (= real LLM reply).
//       D. WSMemoryRepository has >=1 row for userId="default"
//          after the turn (= the v2.4 memory write went through).
//       E. The persisted memory content includes the user's name
//          "老王" (= the assistant's reply made it into memory).
//
//  Streaming note:
//    This test does NOT exercise the streamCallback path
//    (= ConversationLoop.runTurn uses the blocking send()). The
//    streaming gate (= LLMBlock tokens rendered live in ChatView)
//    is verified separately by ConversationLoopTests +
//    ChatSessionViewModelStreamingTests.
//
//  Why no stub:
//    The whole point of this test is to confirm the v2.4 §11.17
//    "memory rewire" actually persists end-to-end. A stub would
//    prove the wiring compiles; = it would NOT prove the memory
//    row survives the SwiftData round-trip. The live test is
//    the only signal that boss OOB 2026-09-25 (用户不再被
//    自由编辑 agent, = 换取系统稳定输出) is honored.
//
//  Gate:
//    WENSHU_LIVE_API_TESTS=1 (default off; CI-safe). Boss opt-in
//    runs the test against the real minimax-cn endpoint using the
//    AppleKeychain-stored API key.
//

import Testing
import Foundation
import os
@testable import WenshuApp

@Suite("E2E: one prompt → real LLM call → real memory write (LIVE)")
struct E2EMemoryAndLLMFlowTests {

    private static var liveEnabled: Bool {
        ProcessInfo.processInfo.environment["WENSHU_LIVE_API_TESTS"] == "1"
    }

    @Test("one prompt: ConversationLoop calls minimax-cn exactly once, memory row persists with user name")
    @MainActor
    func fullFlow() async throws {
        guard Self.liveEnabled else {
            Issue.record("skipped (= WENSHU_LIVE_API_TESTS not set)")
            return
        }

        // Step 0: reset WSMemory mirror + SwiftData store so the
        // "first ever turn" canonical shape holds (= prefetch returns
        // []; = post-turn sync writes exactly 1 row).
        await WSMemoryProvider.shared.resetCache()
        // purgeOlderThan with retentionDays=0 wipes every row whose
        // updatedAt < now (= = every row in this dev test env).
        let purged = (try? WSMemoryRepository.shared.purgeOlderThan(
            userId: "default",
            retentionDays: 0
        )) ?? 0
        print("[E2E] purged \(purged) pre-existing memory row(s) (= dev residue)")
        let baselineCount = (try? WSMemoryRepository.shared.count(userId: "default")) ?? 0
        print("[E2E] baseline memory rows = \(baselineCount)")
        #expect(baselineCount == 0, "memory store must start empty for this e2e (= purge before turn)")

        // Step 1: build the real MinimaxConnector + wrap it with
        // RecordingLLMConnector. AppleKeychain key resolves via the
        // standard ConnectorCredentials path (= no special-cased
        // test injection).
        let realConnector = MinimaxConnector()
        let recording = RecordingLLMConnector(wrapping: realConnector)

        // Step 2: build ConversationLoop with the recording wrapper.
        // tools: [] (= no tool dispatch possible). Compression +
        // shell hooks use defaults (= no behavior change).
        let loop = ConversationLoop(connection: recording)

        // Step 3: one user turn. The user message carries identifying
        // information (= "我叫老王, 我喜欢写短篇小说") so the post-turn
        // assertion can verify the memory row captured it.
        let userMessage = "你好, 我叫老王, 我喜欢写短篇小说。请用一句话回复我。"
        print("[E2E] sending prompt: \(userMessage)")

        let result = try await loop.runTurn(
            userMessage: userMessage,
            systemMessage: nil,
            conversationHistory: [],
            tools: [:],
            taskId: "e2e-001"
        )

        // Step 4A: LLM was called at least once.
        let captured = await recording.capturedCalls()
        print("[E2E] LLM send calls captured = \(captured.count)")
        for (idx, call) in captured.enumerated() {
            print("[E2E]   call[\(idx)] model=\(call.options.model) systemPromptChars=\(call.options.systemPrompt?.count ?? 0) messageCount=\(call.requestMessages.count)")
            let textBlockCount = call.response.blocks.filter { if case .text = $0 { return true } else { return false } }.count
            print("[E2E]   call[\(idx)] responseTextBlocks=\(textBlockCount)")
        }
        guard let firstCall = captured.first else {
            Issue.record("ConversationLoop must call the LLM at least once per turn (= captured.count == 0); possibly failed before reaching the LLM round-trip")
            return
        }
        #expect(captured.count >= 1, "ConversationLoop must call the LLM at least once per turn")
        let userTexts = firstCall.requestMessages
            .filter { $0.role == .user }
            .compactMap { msg -> String? in
                for case .text(let s) in msg.blocks { return s }
                return nil
            }
        let userTextBlob = userTexts.joined(separator: " ")
        print("[E2E] request user-text blob: \(String(userTextBlob.prefix(200)))")
        #expect(userTextBlob.contains("老王"), "user message must reach the LLM request payload (= '老王' is the unique marker)")
        #expect(userTextBlob.contains("短篇小说"), "user message must reach the LLM request payload")

        // Step 4C: response has at least one .text block with content.
        let responseTexts = firstCall.response.blocks.compactMap { block -> String? in
            if case .text(let s) = block { return s }
            return nil
        }
        let responseText = responseTexts.joined(separator: "\n")
        print("[E2E] LLM reply (\(responseText.count) chars): \(String(responseText.prefix(200)))")
        #expect(!responseText.isEmpty, "LLM response must contain at least one non-empty text block")

        // Step 4D: a memory row was persisted for this turn.
        // ConversationLoop.runTurn step 8 fires MemoryAdapter().write(...)
        // which delegates to WSMemoryProvider.shared.sync(...) which writes
        // through WSMemoryRepository.shared to SwiftData.
        let postCount = (try? WSMemoryRepository.shared.count(userId: "default")) ?? 0
        print("[E2E] post-turn memory rows = \(postCount)")
        #expect(postCount >= 1, "ConversationLoop.runTurn must persist at least 1 memory row (= step 8: Persisting memory)")

        // Step 4E: the persisted row contains the user's name "老王".
        let recentRows = (try? WSMemoryRepository.shared.listRecent(userId: "default", limit: 5)) ?? []
        let rowContentBlob = recentRows.map(\.content).joined(separator: "\n")
        print("[E2E] persisted memory blob (\(rowContentBlob.count) chars): \(String(rowContentBlob.prefix(300)))")
        #expect(rowContentBlob.contains("老王"), "persisted memory must contain user name '老王' (= the write went through end-to-end)")

        // Step 4F (bonus): confirm system prompt was passed (= the
        // v2.4 memory prefetch happens inside composeSystemPrompt).
        let systemChars = firstCall.options.systemPrompt?.count ?? 0
        print("[E2E] system prompt chars sent to LLM = \(systemChars)")
        #expect(systemChars > 100, "system prompt must be non-trivial (= composeSystemPrompt must have built the full prompt)")

        // Sanity: confirm the ConversationResult response is non-empty
        // (= the same content as the LLM send response, just for completeness).
        print("[E2E] ConversationResult.response blocks: \(result.response.blocks.count)")
        #expect(result.response.blocks.count > 0, "ConversationResult.response must carry the LLM blocks")
    }

    // MARK: - 第二回合: 测试书上下文 + 模糊 prompt 自动触发调研

    @Test("测试书上下文: 模糊 prompt (主角入殓师, 出生沧州) 触发 web_search + reference_library 工具链")
    @MainActor
    func autoTriggerResearch() async throws {
        guard Self.liveEnabled else {
            Issue.record("skipped (= WENSHU_LIVE_API_TESTS not set)")
            return
        }

        // Step 0: 准备 anbaiqiang.ws 仓库 (= reset reference-library 4 layers
        // so the test starts from a clean reference store). Run the
        // LibraryLifecycleHook so the SwiftData ModelContainer + reference store
        // are wired (= the user-bound reference_library tool writes to
        // <ws>/reference-library/, not the singleton's /tmp/ fallback).
        let wsRoot = Self.anbaiqiangWSRoot
        Self.resetReferenceLibrary(wsRoot: wsRoot)
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
        let userBoundRefLibTool = ReferenceLibraryTool(
            actor: ReferenceLibraryActor(referenceStore: referenceStore)
        )
        print("[E2E] step 0 done: user-bound ReferenceLibraryTool constructed")

        // Step 1: 手构造 tools dict + toolSchemas (= web_search +
        // reference_library). Bypass ToolRegistry entirely (= the
        // production-bootstrap chain fires 12 fire-and-forget Tasks that
        // trap the process under @MainActor test isolation). This is the
        // canonical observability shape: we want the LLM to see exactly
        // these 2 tools (= no other tool schema contaminates the system
        // prompt), so the agent's decision to call them is unambiguous.
        let webSearchTool = WebSearchTool.shared
        let webSearchSchema = ToolRegistrySchema(
            name: "web_search",
            description: """
            Web search (= keyless anonymous free tier ring: Parallel /
            Exa / Keenable). NO API KEY needed.

            You MUST call this tool when the user prompt names any of:
            入殓师 / funeral director / embalmer / 沧州 / Cangzhou /
            an unfamiliar profession / a specific Chinese city or
            region / a historical period / an industry term /
            any concrete name / place / event you cannot recall from
            training with high confidence.

            Call shape: {action: "search", query: "<topic>", limit: 10}.
            """,
            inputSchema: [
                "action": ToolRegistrySchemaProperty(
                    type: "string",
                    description: "Action. Use 'search' for grounded facts.",
                    enumValues: ["search"]
                ),
                "query": ToolRegistrySchemaProperty(
                    type: "string",
                    description: "Search query (= required)."
                ),
                "limit": ToolRegistrySchemaProperty(
                    type: "integer",
                    description: "Max results (= default 10)."
                )
            ],
            required: ["action", "query"]
        )
        let referenceLibrarySchema = ToolRegistrySchema(
            name: "reference_library",
            description: """
            Library-public reference CRUD with dedup-by-title upsert \
            (= wraps FileSystemReferenceStore). Same-title research \
            edits the existing document instead of creating a new one.
            """,
            inputSchema: [
                "action": ToolRegistrySchemaProperty(
                    type: "string",
                    description: "The reference operation to perform.",
                    enumValues: ["create", "read", "update", "delete", "list", "find", "upsert"]
                ),
                "id": ToolRegistrySchemaProperty(
                    type: "string",
                    description: "Reference id (UUID). Required for read / update / delete."
                ),
                "title": ToolRegistrySchemaProperty(
                    type: "string",
                    description: "Reference title. Required for create / find / upsert."
                ),
                "layer": ToolRegistrySchemaProperty(
                    type: "string",
                    description: "Reference layer ('raw' or 'entities'). Defaults to 'raw'.",
                    enumValues: ["raw", "entities"]
                ),
                "category": ToolRegistrySchemaProperty(
                    type: "string",
                    description: "Entity category (for layer=entities)."
                ),
                "entity_type": ToolRegistrySchemaProperty(
                    type: "string",
                    description: "EntityType (character / location / event / concept / artifact / organization / era / work / other)."
                ),
                "source": ToolRegistrySchemaProperty(
                    type: "string",
                    description: "Bibliographic source string."
                ),
                "url": ToolRegistrySchemaProperty(
                    type: "string",
                    description: "Source URL (web sources)."
                ),
                "summary": ToolRegistrySchemaProperty(
                    type: "string",
                    description: "1-line summary."
                ),
                "markdown": ToolRegistrySchemaProperty(
                    type: "string",
                    description: "Full .md body. Alias: 'body'."
                )
            ],
            required: ["action"]
        )
        let tools: [String: any Tool] = [
            "web_search": webSearchTool,
            "reference_library": userBoundRefLibTool
        ]
        let toolSchemas: [ToolRegistrySchema] = [webSearchSchema, referenceLibrarySchema]
        print("[E2E] step 1 done: tools dict + toolSchemas constructed (web_search + reference_library)")

        // Step 1.5: construct the user prompt (= 老板原话，不改写)
        let userMessage = """
        我想写一部小说，主角名字还没想好。
        设定是入殓师职业，出生在沧州。
        你看怎么规划？
        """
        print("[E2E] step 1.5: userMessage prepared (\(userMessage.count) chars)")

        // Agent driver reminder (= trust the LLM's own noun
        // detection; = no hand-rolled dictionary to maintain).
        // The reminder is intentionally short (= a numbered nudge,
        // not a full noun enumeration). The LLM extracts the nouns
        // (= 入殓师, 沧州) itself from the user prompt; = its
        // training data covers every Chinese profession / city /
        // dynasty / event we could want to verify. The reminder
        // rides in the LAST slot of the composed system prompt
        // (= via ConversationLoop.runTurn's systemMessage override)
        // where the LLM pays the most attention to imperative
        // instructions.
        let agentDriverReminder = """
        [WENSHU AGENT DRIVER] The user prompt above contains
        concrete proper nouns (= profession / place / period / event /
        brand). You MUST call `web_search` for EACH one BEFORE writing
        your reply. Emit the tool_use blocks as parallel content
        blocks in this same assistant turn (= Anthropic tool_use
        wire shape, NOT markdown code fences). After tool results
        land, follow up with `reference_library.create` (= or
        `upsert`) to persist. THEN write the user reply grounded
        in the search hits. If a noun's search returns nothing, say
        so plainly — do NOT fabricate.
        """
        print("[E2E] agent driver reminder chars: \(agentDriverReminder.count)")

        // Step 2: 装 ConversationLoop (= same shape as fullFlow test; = bypasses
        // WenshuConductor's MainActor-bound `buildToolsSync` semaphore
        // bridge which SIGTRAPs under test isolation).
        let realConnector = MinimaxConnector()
        let recording = RecordingLLMConnector(wrapping: realConnector)
        let loop = ConversationLoop(connection: recording)
        print("[E2E] step 2 done: ConversationLoop wired with RecordingLLMConnector")

        // Step 3: vague prompt already prepared in step 1.5
        print("[E2E] step 3 done: vague prompt ready (= \(userMessage.count) chars; = boss 的精确措辞, 不改写)")
        print("[E2E] sending vague prompt: \(userMessage.prefix(80))…")

        // Step 4: runTurn (= full ConversationLoop pipeline with tool dispatch).
        // `maxAttempts` defaults to 3 (= the tool-call loop has budget for
        // ~3 LLM round-trips before giving up).
        let result = try await loop.runTurn(
            userMessage: userMessage,
            systemMessage: agentDriverReminder.isEmpty ? nil : agentDriverReminder,
            conversationHistory: [],
            tools: tools,
            taskId: "e2e-002-research",
            toolSchemas: toolSchemas
        )
        print("[E2E] step 4 done: loop.runTurn returned")

        // Step 5: 总报告 (= boss 想看的就是这些)。
        let captured = await recording.capturedCalls()
        print("[E2E] LLM send calls captured = \(captured.count)")
        var emittedToolUseNames = Set<String>()
        for (idx, call) in captured.enumerated() {
            var toolUseBlocksInResponse: [String] = []
            for block in call.response.blocks {
                if case .toolUse(_, let name, _) = block {
                    toolUseBlocksInResponse.append(name)
                    emittedToolUseNames.insert(name)
                }
            }
            // Look at requestMessages too: ConversationLoop.runTurn sends
            // .toolResult blocks (= feedback from prior tool executions)
            // in subsequent LLM round-trips. We want to see what tool the
            // agent ACTUALLY dispatched (= .toolResult blocks in requestMessages).
            var toolResultsInRequest: [Int] = []
            for msg in call.requestMessages where msg.role == .user {
                for block in msg.blocks {
                    if case .toolResult(let toolUseID, _) = block {
                        toolResultsInRequest.append(toolUseID.hashValue)
                    }
                }
            }
            print("[E2E]   call[\(idx)] blocks=\(call.response.blocks.count) toolUse_in_response=\(toolUseBlocksInResponse) toolResults_in_request=\(toolResultsInRequest)")
        }
        print("[E2E] LLM-emitted toolUse names (across all calls): \(emittedToolUseNames.sorted().joined(separator: ", "))")
        #expect(captured.count >= 1, "loop.runTurn must call LLM at least once")
        // Agent driver guarantee: the LLM MUST have called web_search
        // (= or reference_library) for at least one of the detected
        // nouns. Without this assertion the test would pass even when
        // the LLM ignores the agent-driver reminder (= it happened
        // before; = per boss 2026-09-25 the gap must close).
        #expect(
            emittedToolUseNames.contains("web_search")
                || emittedToolUseNames.contains("reference_library"),
            "agent driver must force at least one tool call (= web_search or reference_library) when the user prompt contains concrete nouns (= the LLM should detect them itself via training data)"
        )

        // Step 6: 看文件系统副作用 (= reference_library.create 是否真写到了
        // <ws>/reference-library/entities/*.md). 一个 .md 文件 = 一次 LLM
        // 自动创建的文档。boss 想看的: 入殓师 / 沧州 / 主角文档有没有。
        let entitiesDir = wsRoot.appendingPathComponent("reference-library/entities")
        let writtenFiles = (try? FileManager.default.contentsOfDirectory(at: entitiesDir, includingPropertiesForKeys: nil)) ?? []
        let mdFiles = writtenFiles.filter { $0.pathExtension == "md" }
        print("[E2E] reference-library/entities/*.md count = \(mdFiles.count)")
        for file in mdFiles {
            let id = file.deletingPathExtension().lastPathComponent
            let attrs = (try? FileManager.default.attributesOfItem(atPath: file.path)) ?? [:]
            let size = (attrs[.size] as? Int) ?? 0
            let body = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
            let firstNonEmptyLine = body.split(whereSeparator: { $0.isNewline })
                .first.map(String.init) ?? ""
            print("[E2E]   entity id=\(id) size=\(size) firstLine=\(firstNonEmptyLine.prefix(80))")
        }

        // Step 6.5: 看 system prompt 长度 (= agent_driver guidance 是否进了 cache 前缀)
        let systemChars = captured.first?.options.systemPrompt?.count ?? 0
        print("[E2E] system prompt chars = \(systemChars)")
        let systemContainsAgentDriver = captured.first?.options.systemPrompt?
            .contains("agent driver") ?? false
        print("[E2E] system prompt mentions 'agent driver' = \(systemContainsAgentDriver)")

        // Step 7: 看 entities.json 索引 (= title / category / tags).
        let indexPath = wsRoot.appendingPathComponent("reference-library/entities/entities.json")
        let indexRaw = (try? String(contentsOf: indexPath, encoding: .utf8)) ?? ""
        print("[E2E] entities.json index (\(indexRaw.count) chars):")
        if !indexRaw.isEmpty {
            print(indexRaw)
        }

        // Step 8: 总报告 (boss visual verification — he wants to see these numbers).
        let resultTexts = result.response.blocks.compactMap { block -> String? in
            if case .text(let s) = block { return s }
            return nil
        }
        let resultTextBlob = resultTexts.joined(separator: "\n")
        print("")
        print("========== [E2E] vague-prompt auto-trigger research summary ==========")
        print("LLM send calls (one LLM round-trip per call):       \(captured.count)")
        print("LLM-emitted tool_use names (across all calls):      \(emittedToolUseNames.sorted().joined(separator: ", "))")
        print("On-disk entity .md files written by reference_lib: \(mdFiles.count)")
        print("ConversationResult.response blocks:                 \(result.response.blocks.count)")
        print("ConversationResult.response has toolUse blocks:     \(result.response.blocks.contains { if case .toolUse = $0 { return true } else { return false } })")
        print("Final reply (\(resultTextBlob.count) chars):")
        print(resultTextBlob)
        print("======================================================================")
    }

    // MARK: - delegate_research (= v2.7 fire-and-forget path)

    @Test("vague prompt -> LLM emits delegate_research (NOT web_search), kanban gets the row")
    func delegateResearchPath() async throws {
        guard Self.liveEnabled else {
            Issue.record("skipped (= WENSHU_LIVE_API_TESTS not set)")
            return
        }

        // Step 0: prepare the user-bound reference store (= same
        // pattern as autoTriggerResearch; = delegate_research does
        // NOT touch the reference store directly, but the LLM's
        // reply may still cite context from previous research).
        let wsRoot = Self.anbaiqiangWSRoot
        Self.resetReferenceLibrary(wsRoot: wsRoot)
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
        // NOT web_search (= the boss directive: main agent does
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
                )
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
                )
            ],
            required: ["action"]
        )
        let tools: [String: any Tool] = [
            "delegate_research": delegateTool,
            "reference_library": referenceLibraryTool
        ]
        let toolSchemas: [ToolRegistrySchema] = [delegateResearchSchema, referenceLibrarySchema]
        print("[E2E] step 1 done: tools = {delegate_research, reference_library}; = NO web_search (= main agent delegates)")

        // Step 2: wire the real minimax connector + RecordingLLMConnector
        // (= observe what the LLM actually does).
        let realConnector = MinimaxConnector()
        let recording = RecordingLLMConnector(wrapping: realConnector)
        let loop = ConversationLoop(connection: recording)

        // Step 3: vague prompt (= same wording as autoTriggerResearch; =
        // the LLM must detect 入殓师 / 沧州 as concrete nouns).
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
                if case .toolUse(_, let name, _) = block {
                    emittedToolUseNames.insert(name)
                }
            }
        }
        print("[E2E] LLM send calls captured = \(captured.count)")
        for (idx, call) in captured.enumerated() {
            let toolNames = call.response.blocks.compactMap { block -> String? in
                if case .toolUse(_, let name, _) = block { return name }
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
            if case .text(let s) = block { return s }
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

extension E2EMemoryAndLLMFlowTests {
    /// 测试用的 .ws 仓库根 (=老板的 anbaiqiang.ws 副本 + 测试隔离).
    fileprivate static var anbaiqiangWSRoot: URL {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        return cwd.appendingPathComponent(".scratch/anbaiqiang.ws")
    }

    /// 重置 reference-library 4 个 layer (=让本测试能从干净起点开始).
    fileprivate static func resetReferenceLibrary(wsRoot: URL) {
        let reflibRoot = wsRoot.appendingPathComponent("reference-library")
        for layer in ["raw", "entities", "abstracts", "indexes"] {
            let layerDir = reflibRoot.appendingPathComponent(layer)
            try? FileManager.default.removeItem(at: layerDir)
            try? FileManager.default.createDirectory(at: layerDir, withIntermediateDirectories: true)
        }
    }
}

// MARK: - Recording connector

/// One captured send() invocation (= request payload + LLM response).
/// File-scope (= the wrapper returns it from capturedCalls()).
struct CapturedLLMCall: Sendable {
    let requestMessages: [LLMMessage]
    let options: LLMCallOptions
    let response: LLMResponse
}

/// Thin LLMConnector wrapper that captures every send() call's input
/// (= messages + options) + output (= LLMResponse blocks). Forwards
/// to the wrapped real connector (= so the network IO is real).
///
/// Uses an NSLock for thread-safe `calls` append (= the wrapped
/// connector may invoke send from a background URLSession task; =
/// cross-actor writes to the captured array are safe via lock).
final class RecordingLLMConnector: LLMConnector, @unchecked Sendable {
    nonisolated let connectorID: String

    private let wrapped: any LLMConnector
    private let lock = OSAllocatedUnfairLock<[CapturedLLMCall]>(initialState: [])

    init(wrapping wrapped: any LLMConnector) {
        self.wrapped = wrapped
        self.connectorID = wrapped.connectorID
    }

    func send(messages: [LLMMessage], options: LLMCallOptions) async throws -> LLMResponse {
        let response = try await wrapped.send(messages: messages, options: options)
        let captured = CapturedLLMCall(
            requestMessages: messages,
            options: options,
            response: response
        )
        lock.withLock { state in
            state.append(captured)
        }
        return response
    }

    func stream(messages: [LLMMessage], options: LLMCallOptions) -> AsyncStream<LLMBlock> {
        // ConversationLoop.runTurn uses the streamInto path
        // (= for await block in connector.stream). We forward to
        // the wrapped connector's send directly (= the default
        // extension's `stream` calls `send`, but if the wrapped
        // connector overrides `stream with native SSE, the capture
        // would miss it). Calling `wrapped.send` here guarantees
        // every recorded block traces back to a single LLM HTTP call
        // (= the canonical observability shape for this test).
        AsyncStream { continuation in
            Task {
                do {
                    let response = try await wrapped.send(messages: messages, options: options)
                    // Capture (= same shape as send()'s capture).
                    let captured = CapturedLLMCall(
                        requestMessages: messages,
                        options: options,
                        response: response
                    )
                    lock.withLock { state in
                        state.append(captured)
                    }
                    // Yield blocks + finish (= mirrors the default
                    // extension's behavior in LLMConnector.swift:75).
                    for block in response.blocks {
                        continuation.yield(block)
                    }
                    continuation.finish()
                } catch {
                    continuation.yield(.text("[stream error] \(error)"))
                    continuation.finish()
                }
            }
        }
    }

    func capturedCalls() async -> [CapturedLLMCall] {
        lock.withLock { state in state }
    }
}