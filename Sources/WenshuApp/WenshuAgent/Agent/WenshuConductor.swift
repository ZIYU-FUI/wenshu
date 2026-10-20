// WenshuConductor.swift
// … (= 33 rationale lines collapsed; = A112 docblock collapse per §1.8)
// 
import Foundation
import WenshuAgent
import WenshuData
import os.log

private let wenshuLogger = Logger(subsystem: "com.wenshu", category: "wenshuconductor")

// See commit 49 (= ContextEngine deferred) for the full rationale.
// … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / Wenshu orchestrator (actor thread-safe, consistent with AgentRuntime / WSKanbanRepository / WSMemoryRepository).
actor WenshuConductor {
    private let runtime: AgentRuntime
    // AUDIT.md §2.2 partial (2026-10-16 boss "把切换包的事
    // 清干净" arc): the `verifier: WenshuVerifier` field was
    // deleted; = the conductor routes every LLM call through
    // WenshuAgent.shared.chat() (= the public facade; = the
    // verifier bridge to WenshuAgent.shared is now indirect).
    // / Long-term memory persistence for agent (now SwiftData-backed via
    // … (= 11 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / ChatView call site keeps working.
    let repositories: WSRepositoryContainer
    /// See .scratch/2026-08-22-frontend-integration/issues/h10-tools-frontend.md.
    private let fileTools: FileTools = FileTools()
    private let webTools: WebTools = WebTools()
    private let visionTools: VisionTools = VisionTools()
    // / h14: AVMediaTools — agent toolkit dispatch + chat UI read-aloud button.
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / .scratch/2026-08-22-frontend-integration/issues/h14-avmedia-tools-frontend.md.
    private let avMediaTools: AVMediaTools = AVMediaTools()
    // / P0 #1 (WIRE-AGENT-001): optional active connector profile. When non-nil,
    // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / App.swift follow-up.
    private let connector: (any LLMConnector)?
    // / P0 #1 (WIRE-AGENT-001): optional RuntimeHelpers instance for the
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / ConversationLoop creates a fresh actor instance.
    private let loopRuntime: RuntimeHelpers?
    // / P0 #2 (WIRE-AGENT-002): tool registry forwarded to
    // … (= 13 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / `registeredToolNames` accessor + the `wireBookScopeGuard` writer.
    var tools: [String: any Tool]
    // AUDIT.md §2.9 partial (2026-10-16): the stream single-
    // writer fence (= hermes `stream_single_writer.py` port).
    // One per conductor instance (= the conductor is the
    // single chat surface; = different chat sessions get
    // different conductor instances via
    // `WenshuAppDelegate.sharedConductor` per session).
    private let streamWriterFence = WAStreamWriterFence()

    init(
        runtime: AgentRuntime,
        tools: [String: any Tool] = [:],
        repositories: WSRepositoryContainer? = nil
    ) {
        // AUDIT.md §2.2 partial (2026-10-16 boss "把切换包的事
        // 清干净" arc): the `verifier` parameter was deleted;
        // = the conductor no longer holds a `WenshuVerifier`
        // instance (= the verifier actor is now a thin bridge
        // to WenshuAgent.shared; = the conductor routes
        // every LLM call through the WenshuAgent.shared.chat()
        // entry point; = the verifier field is no longer
        // needed for any call site).
        self.init(
            runtime: runtime,
                connector: nil,
            loopRuntime: nil,
            tools: tools,
            repositories: repositories
        )
    }

    // / P0 #1 (WIRE-AGENT-001): new init that wires WenshuConductor.handle()
    // … (= 13 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / nil, `ConversationLoop` falls back to a fresh `RuntimeHelpers()` actor.
    init(
        runtime: AgentRuntime,
        connector: (any LLMConnector)? = nil,
        loopRuntime: RuntimeHelpers? = nil,
        tools: [String: any Tool] = [:],
        repositories: WSRepositoryContainer? = nil
    ) {
        self.runtime = runtime
        self.connector = connector
        self.loopRuntime = loopRuntime
        // P0 #2 (WIRE-AGENT-002): store the tool registry so the loop
        // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // every existing call site compiles unchanged.
        self.tools = tools
        // P1-01 fix: prefer the injected WSRepositoryContainer; fall
        // … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // boundaries at runtime.
        if let repositories {
            self.repositories = repositories
        } else {
            self.repositories = MainActor.assumeIsolated { WSRepositoryContainer.shared }
        }
        // Bootstrap deferred to first handle() call (Swift actor init cannot await).
    }


    // / h10: dispatch an agent tool call. Returns "" on unknown tool / failure.
    // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / input = text → speaks aloud (fire-and-forget)
    func invokeTool(name: String, input: String, caller: AgentCaller = .main) async -> String {
        // hermes DELEGATE_BLOCKED_TOOLS parity ((see OOB.md #2026-08-23)).
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // Sub-agents can call memory but only for read ops (no add/delete).
        if caller.isSubAgent {
            let parts = input.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            let op = parts.first.map(String.init) ?? ""
            if let reason = SubAgentPermissions.checkPermission(tool: name, op: op) {
                return reason
            }
        }
        // .003: tool-level allowlist ((see OOB.md #2026-08-23) — user cannot change system via chat).
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // Unknown op = blocked (per-tool allowlist below).
        let parts = input.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let op = parts.first.map(String.init) ?? ""
        let arg = parts.count > 1 ? String(parts[1]) : ""

        switch name {
        case "file":
            // Allowlist: read / list / search only (NOT write / patch).
            guard ["read", "list", "search"].contains(op) else {
                return "(tool blocked: file.\(op) is in deny-list — (see OOB.md #2026-08-23): user cannot change code / config via chat)"
            }
            switch op {
            case "read": return (try? fileTools.read(path: arg)) ?? ""
            case "list": return (try? fileTools.list(path: arg).map { $0.path }.joined(separator: "\n")) ?? ""
            case "search": return (try? fileTools.search(rootDir: arg, pattern: "").joined(separator: "\n")) ?? ""
            default: return ""
            }
        case "process":
            // Deny all (chat-triggered shell = arbitrary code execution).
            return "(tool blocked: process is deny-all — (see OOB.md #2026-08-23): user cannot change system via chat. Use wenshu-devtool CLI.)"
        case "web":
            // Per 12 standard P1-02 try?  (= wenshu tries to surface
            // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // failure via Console.app.
            do {
                return try await webTools.extract(url: input)
            } catch {
                WenshuConductor.toolLogger.error("[wenshu.conductor.tool] web.extract url=\(input, privacy: .public) silently dropped error: \(String(describing: error), privacy: .public)")
                return ""
            }
        case "vision":
            // Same pattern (= silent fallback on the bottom-rung of
            // the multi-tool pipeline).
            var recognizedResults: [VisionTextResult] = []
            do {
                recognizedResults = try await visionTools.recognizeText(imagePath: input)
            } catch {
                WenshuConductor.toolLogger.error("[wenshu.conductor.tool] vision.recognizeText imagePath=\(input, privacy: .public) silently dropped error: \(String(describing: error), privacy: .public)")
                return ""
            }
            return recognizedResults.map(\.text).joined(separator: "\n")
        case "av":
            avMediaTools.speak(text: input)
            return "[spoken]"
        default:
            return "(tool blocked: unknown tool '\(name)')"
        }
    }

    // / handle: receive user message, dispatch sub-agents, synthesize final
    // … (= 24 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / `(reply, tokens, thinking)` tuple without the streaming side-effect.
    func handle(
        userMessage: String,
        sessionId: String,
        model: String,
        streamCallback: (@Sendable (LLMBlock) async -> Void)? = nil
    ) async -> (reply: String, totalTokens: Int, thinking: String?) {
        // AUDIT.md §2.9 partial (2026-10-16 boss "中途别停" arc):
        // WAStreamWriterFence prevents the multi-stream race
        // (= two streaming responses trying to write to the
        // same `messages[idx]` slot). Every new `handle` call
        // claims a fresh fence token (= monotonic counter; =
        // 1 user message = 1 token); the wrapped stream
        // callback below checks `fence.isCurrent(token)`
        // before forwarding each block. If a newer stream
        // has claimed, the older one bails out (= hermes
        // `stream_single_writer.py` port; = 38 LOC source
        // translated to Swift).
        let fenceToken = streamWriterFence.claim()

        // P0-AGENT-LOOP (boss 2026-10-16 OOB "agent 没有达到 agent
        // 的标准" + commit 7de86fc08): the conductor is now ALWAYS
        // wired with the active connector (= `WenshuAppDelegate`
        // and `ChatView` both pass `WenshuAppDelegateLLMHelpers.
        // activeLLMConnector()` at construction time). The legacy
        // pipeline (= the "small liar" no-ReAct path) is gone
        // (= deleted alongside this commit). If the connector is
        // missing or the ReAct loop throws, surface the failure
        // plainly; do NOT silently run a no-tool-dispatch path.
        guard let connector = connector else {
            wenshuLogger.error("[wenshu.conductor] PATH=missing-connector REASON=conductor_was_nil msg_prefix=\(String(userMessage.prefix(40)))")
            return (reply: "（agent 未配置, 请检查 WenshuAppDelegate 是否注入了 connector）", totalTokens: 0, thinking: nil)
        }
        // Wrap the caller's streamCallback in a fence-guarded
        // adapter. Each block passes through the fence check
        // before reaching the caller's callback (= the
        // multi-stream race the fence exists to prevent).
        let fencedCallback = Self.makeFencedCallback(
            userCallback: streamCallback,
            fence: streamWriterFence,
            token: fenceToken
        )
        guard let loopResult = await runConversationLoopPath(
            userMessage: userMessage,
            sessionId: sessionId,
            model: model,
            connector: connector,
            streamCallback: fencedCallback
        ) else {
            // The ReAct loop threw (= it catches its own errors and
            // returns nil per the loop's contract; = see
            // `runConversationLoopPath` catch block for the
            // diagnostic log). Surface the failure rather than
            // silently routing through a no-ReAct path.
            wenshuLogger.error("[wenshu.conductor] PATH=react-loop-failed REASON=runConversationLoopPath_returned_nil msg_prefix=\(String(userMessage.prefix(40)))")
            return (reply: "（agent 暂时不可用, 请稍后再试）", totalTokens: 0, thinking: nil)
        }
        return loopResult
    }

    // / P0 #1 (WIRE-AGENT-001): route the user message through the full
    // … (= 10 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / broken agent.
    private func runConversationLoopPath(
        userMessage: String,
        sessionId: String,
        model: String,
        connector: any LLMConnector,
        // Forward streamCallback to ConversationLoop
        // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // triggers), no callback fires.
        streamCallback: (@Sendable (LLMBlock) async -> Void)?
    ) async -> (reply: String, totalTokens: Int, thinking: String?)? {
        // Step 1: write 1 conductor parent task to WSKanbanRepository (= legacy
        // parity: same Kanban behaviour as the legacy path).
        let added = await MainActor.run { () -> String? in
            try? self.repositories.kanban.add(title: "conductor: \(userMessage.prefix(50))", status: "running")
        }
        if let task = added {
            // Mark done after the loop attempt (= best-effort; matches
            // the legacy code path exactly).
            Task {
                await MainActor.run {
                    _ = try? self.repositories.kanban.transition(id: task, to: "done")
                }
            }
        }

        // Step 2: build the ConversationLoop bound to the active connector.
        let loop = ConversationLoop(
            connection: connector,
            systemPrompt: WenshuConductorIdentity.systemPrompt,
            runtime: loopRuntime
        )

        // Step 3: invoke the full turn orchestrator. On any throw, log
        // … (= 15 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // itself from the user prompt.
        let agentDriverReminder = """
        [WENSHU AGENT DRIVER] This user prompt contains concrete
        proper nouns (= profession / place / period / event / brand /
        etc.). You MUST call `web_search` (= action="search", =
        query=<the noun verbatim>) for EACH one BEFORE writing
        your reply. Emit the tool_use blocks as parallel content
        blocks in this same assistant turn (= Anthropic tool_use
        wire shape, NOT markdown code fences). After tool results
        land, follow up with `reference_library.create` (= or
        `upsert`) to persist. THEN write the user reply grounded
        in the search hits. If a noun's search returns nothing,
        say so plainly — do NOT fabricate.
        """
        do {
            let result = try await loop.runTurn(
                userMessage: userMessage,
                // Pass the agent-driver reminder as the systemMessage
                // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // most attention to imperative instructions).
                systemMessage: agentDriverReminder,
                conversationHistory: [],
                // P0 #2 (WIRE-AGENT-002): forward the conductor's
                // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // registered wenshu tools.
                tools: tools,
                // Forward streamCallback (= Hermes
                // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // token-by-token). Legacy callers (= tests) pass nil.
                streamCallback: streamCallback,
                // P5-AGENT-STREAMING-VISIBILITY (2026-09-25): forward
                // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // did not register (= hermes get_definitions parity).
                toolSchemas: await ToolRegistry.shared.getDefinitions(
                    toolNames: Set(tools.keys)
                )
            )
            // Step 4: shape the ConversationResult into the canonical
            // (reply, totalTokens, thinking) tuple expected by ChatView.
            let reply = result.response.blocks
                .compactMap { block -> String? in
                    if case .text(let s) = block { return s }
                    return nil
                }
                .joined()
            let thinking = result.response.blocks.first { block in
                if case .thinking = block { return true }
                return false
            }.flatMap { block -> String? in
                if case .thinking(let text, _) = block { return text }
                return nil
            }
            let totalTokens = result.response.usage.totalTokens
            // sessionId is the parameter retained for future per-session
            // hook injection (= parity with legacy handle signature).
            _ = sessionId
            // model parameter is used by the legacy path; the loop reads
            // its model from the connector's default-model resolution.
            _ = model
            // T0-PATH-VISIBLE (2026-09-18): explicit success log
            // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // executed end-to-end, not just the fallback).
            wenshuLogger.info("[wenshu.conductor] PATH=new_agent REASON=ConversationLoop.runTurn succeeded (model=\(model) tokens=\(totalTokens))")
            return (reply.isEmpty ? "(文枢暂时无法回复, 请稍后再试)" : reply, totalTokens, thinking)
        } catch {
            // S4 graceful degradation: never throw out of handle(). Log
            // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // grep parity with the success path.
            wenshuLogger.info("[wenshu.conductor] PATH=legacy REASON=ConversationLoop.runTurn threw (model=\(model) err=\(String(describing: error)))")
            return nil
        }
    }

    // / Legacy conductor pipeline (= intent+sub-agent+synthesis). Preserved
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / parseAgentList: parse the JSON array output by LLM (fault-tolerant: truth may return ["search"] or [search, outline] or ['search'])
    func parseAgentList(_ raw: String) -> [String] {
        // Simple regex: capture [...] contents
        guard let start = raw.firstIndex(of: "["),
              let end = raw[start...].firstIndex(of: "]") else {
            return []
        }
        let inner = String(raw[start...end])
        // Split + clean (remove ", ', whitespace)
        return inner
            .components(separatedBy: ",")
            .compactMap { token -> String? in
                let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\"", with: "")
                    .replacingOccurrences(of: "'", with: "")
                return trimmed.isEmpty ? nil : trimmed
            }
    }

    /// buildSynthesisPrompt: assemble sub-agent results into prompt
    func buildSynthesisPrompt(userMessage: String, subResults: [(String, String)]) -> String {
        var prompt = """
        你是 wenshu 文枢. user 问: "\(userMessage)"

        """
        if subResults.isEmpty {
            prompt += "无子 agent 调度, 直接答.\n"
        } else {
            prompt += "子 agent 调度结果:\n"
            for (name, result) in subResults {
                prompt += "- \(name): \(result.prefix(200))\n"
            }
        }
        prompt += "\n基于以上信息, 用中文给 user 一个完整自然的回复 (200 字内)."
        return prompt
    }

    // MARK: - ToolRegistry wiring (WIRE-TOOLREGISTRY-003)
    // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / and the ChatView wiring agree on the set (= deterministic diff).
    static let defaultToolNames: [String] = [
        "ParagraphAI",      // Core/Agent/Tool/ParagraphAITool.swift
        "ReadFile",         // Core/Agent/Tool/ReadFileTool.swift
        "WriteFile",        // Core/Agent/Tool/WriteFileTool.swift
        "av",               // Core/Tools/AVMediaTools.swift
        "background_review", // Core/Agent/Tool/BackgroundReviewTool.swift  (= manual + auto BackgroundReview consolidation surface)
        "book_chapter",     // Core/Agent/Librarian/BookChapterTool.swift
        "book_edit_chapter", // Core/Agent/Librarian/EditChapterTool.swift  (= hermes edit_file 1:1)
        "book_entity",      // Core/Agent/Librarian/BookEntityTool.swift  (= entity schema redesign)
        "book_manager",     // Core/Agent/Librarian/BookManagerTool.swift
        "book_outline",     // Core/Agent/Librarian/BookOutlineTool.swift
        "file",             // Core/Tools/FileTools.swift
        "delegate_research", // Core/Agent/Tool/DelegateResearchTool.swift  (= self-evolution: main agent delegates research to researcher sub-agent async; = main agent does NOT block on web_search)
        "kanban",           // Core/Agent/Tool/KanbanStoreTool.swift
        "llm_wiki",         // Core/Agent/Tool/LLMWikiTool.swift  (= LLM Wiki 4-layer pipeline manual + auto surface)
        "process",          // Core/Tools/ProcessTools.swift
        "reference_library",// Core/Agent/Librarian/ReferenceLibraryTool.swift
        "todo",             // Core/Tool/TodoStoreTool.swift
        "todo_hermes",      // Core/Agent/Todo/HermesTodoTool.swift
        "vision",           // Core/Tools/VisionTools.swift
        "web",              // Core/Tools/WebTools.swift  (= URL fetch only)
        "web_search"        // Core/Agent/Tool/WebSearchTool.swift — main agent has this for synchronous lookups; = for noun research, prefer `delegate_research` (fire-and-forget)
    ]

    // / Maximum time `buildToolsSync(from:)` will wait for the detached async
    // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / covers the scheduling jitter.
    static let toolRegistryWaitTimeoutMs: UInt64 = 250

    // / Build the conductor's tool registry from `ToolRegistry.shared` (= hermes
    // … (= 15 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / deterministic.
    static func buildTools(from registry: ToolRegistry) async -> [String: any Tool] {
        // Step 1: brief warmup window. Registrations are fire-and-forget
        // … (= 15 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // always time out and waste 250 ms.
        try? await Task.sleep(nanoseconds: toolRegistryWarmupMs * 1_000_000)

        // Step 2: assemble the dict via `getHandler`. Unknown names are
        // silently dropped (= spec: `testBuildTools_excludesUnknownNames`).
        var tools: [String: any Tool] = [:]
        for name in defaultToolNames {
            if let handler = await registry.getHandler(name: name) {
                tools[name] = handler
            }
        }
        return tools
    }

    // / Brief settle window for `buildTools(from:)` (= 50 ms). Registrations are
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / which would time out in tests where not all 12 tool files are linked).
    static let toolRegistryWarmupMs: UInt64 = 50

    // / Synchronous bridge to `buildTools(from:)` for callers that cannot await
    // … (= 15 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / ChatView.init fires.

    // AUDIT.md §2.9 (2026-10-16): wrap a user-supplied
    // streamCallback in a fence-guarded adapter. The adapter
    // checks `fence.isCurrent(token)` before forwarding each
    // block; older streams bail out when a newer one has
    // claimed. Extracted as a `static` (= isolated from
    // actor-isolated state) to keep the closure body small
    // (= the Swift type-checker chokes on long multi-closure
    // expressions in actor methods; = per the previous
    // compile-time diagnostic).
    static func makeFencedCallback(
        userCallback: (@Sendable (LLMBlock) async -> Void)?,
        fence: WAStreamWriterFence,
        token: Int
    ) -> (@Sendable (LLMBlock) async -> Void)? {
        guard let userCallback = userCallback else { return nil }
        return { block in
            guard fence.isCurrent(token) else {
                // Older stream superseded by a newer one;
                // silently drop the block (= the user sees
                // only the new stream's text; = matches
                // hermes `stream_single_writer.py` bail-out).
                return
            }
            await userCallback(block)
        }
    }
}
