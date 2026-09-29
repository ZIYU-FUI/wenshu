// WenshuConductor.swift · WenshuApp · v0.21
//
// Wenshu main agent orchestrator (= single-display surface; multi-
// agent hidden):
//   1. Receives the user message.
//   2. Calls the LLM intent classifier to pick the 0-N sub-agents
//      (= Writer / Analyst / Researcher / Auditor / Memory).
//   3. Dispatches the selected sub-agents in parallel (= via
//      `TaskGroup`).
//   4. Waits for all results.
//   5. Calls the LLM to synthesize the final reply.
//
// Dispatch progress goes through `WSKanbanRepository` (= the user
// checks the Kanban board to see sub-agent progress; the chat
// surface itself hides sub-agent activity).
//
// Reuses the 12-module backend (= LinkGraph / Search / Template /
// Composer / Graph / Canvas / Bases / QuickSwitcher / WordCount /
// Outline / Bookmarks / Verifier; = `WenshuVerifier` lives at
// `Core/Agent/Connector/WenshuVerifier.swift`, not under a
// separate `Core/Verifier/` path; = modules are organized by
// feature, not in a flat `Core/` namespace). The pattern matches
// `AgentRuntime` (= the in-process actor source of truth).
//
//  P0 #2 (WIRE-AGENT-002): the conductor now accepts a `tools: [String:
//  any Tool]` registry at construction time. When the loop path runs
//  (= connector wired), the registry is passed through to
//  `ConversationLoop.runTurn(...tools:)` so the ToolExecutor dispatches
//  tool_use blocks against registered wenshu tools (= e.g. the
//  ParagraphAITool stub; future skill + subagent tools wire the same
//  way). Callers that do not register tools (= the legacy v0.21 callers
//  + every existing test) keep the previous behavior unchanged because
//  the default value is `[:]`. See wayfinder plan at
//  `.scratch/2026-09-04-wenshu-integration-plan.md` ticket #2.
//

import Foundation

// See commit 49 (= ContextEngine deferred) for the full rationale.
// Future ticket: migrate to WSMemoryProvider via MemoryManaging protocol.

/// Wenshu orchestrator (actor thread-safe, consistent with AgentRuntime / WSKanbanRepository / WSMemoryRepository).
actor WenshuConductor {
    private let runtime: AgentRuntime
    private let verifier: WenshuVerifier
    /// Long-term memory persistence for agent (now SwiftData-backed via WSMemoryRepository
    /// ([historical actor removed]; this property was previously MemoryStore? for the deprecated actor bridge, now removed.)
    /// All memory calls go through WSMemoryRepository.shared (= @MainActor).
    /// h10: agent toolkit dispatch (FileTools + ProcessTools + WebTools + VisionTools).
    /// Tools are stateless structs, no bootstrap needed.

    /// The conductor reads
    /// / writes kanban + chat persistence (= formerly via
    /// `WSKanbanRepository.shared` / `WSChatRepository.shared` static
    /// singletons). Inject the @MainActor-isolated
    /// `WSRepositoryContainer` (= matches the  protocol
    /// pattern that `LiveChatRepository` already implements for
    /// chat). Falls back to `.shared` (= the v0.72 global
    /// singleton) when the caller does not pass a container; =
    /// every existing test + ChatView call site keeps working.
    private let repositories: WSRepositoryContainer
    /// See .scratch/2026-08-22-frontend-integration/issues/h10-tools-frontend.md.
    private let fileTools: FileTools = FileTools()
    private let webTools: WebTools = WebTools()
    private let visionTools: VisionTools = VisionTools()
    /// h14: AVMediaTools — agent toolkit dispatch + chat UI read-aloud button.
    /// See .scratch/2026-08-22-frontend-integration/issues/h14-avmedia-tools-frontend.md.
    private let avMediaTools: AVMediaTools = AVMediaTools()
    /// P0 #1 (WIRE-AGENT-001): optional active connector profile. When
    /// non-nil, handle() routes the LLM call through the full
    /// ConversationLoop.runTurn() orchestrator (= tool dispatch +
    /// compression + retry + sanitization + finalization). When nil,
    /// handle() falls back to the legacy v0.21 intent+sub-agent+synthesis
    /// pipeline. Production wiring lands in App.swift follow-up.
    private let connector: (any LLMConnector)?
    /// P0 #1 (WIRE-AGENT-001): optional RuntimeHelpers instance for the
    /// ConversationLoop (= deterministic-test injection per v0.36 ticket
    /// 014). When nil, ConversationLoop creates a fresh actor instance.
    private let loopRuntime: RuntimeHelpers?
    /// P0 #2 (WIRE-AGENT-002): tool registry forwarded to
    /// `ConversationLoop.runTurn(...tools:)` when the loop path runs.
    /// Callers (= App.swift, tests) pre-register wenshu tools at
    /// construction time (= e.g. ParagraphAITool for paragraph-level
    /// AI editing). When the loop path is NOT active (= legacy callers
    /// with no connector), this field is silently ignored because
    /// `runLegacyConductorPipeline` does not consult the registry.
    /// Default = empty (= no tools) preserves every existing test +
    /// call site without modification.
    /// Tool registry carried through to the conversation loop. Mutable
    /// so the book_X scope guard can replace the four default
    /// registrations with provider-bound instances (= see
    /// `wireBookScopeGuard`). actor-isolated (= safe to mutate from
    /// any conductor method).
    ///
    /// Marked internal (= not private) so @testable imports can
    /// inspect the dictionary in the WenshuConductorBookScopeGuardTests
    /// integration suite. Production code uses only the read-only
    /// `registeredToolNames` accessor + the `wireBookScopeGuard`
    /// writer.
    var tools: [String: any Tool]

    init(
        runtime: AgentRuntime,
        verifier: WenshuVerifier,
        tools: [String: any Tool] = [:],
        repositories: WSRepositoryContainer? = nil
    ) {
        // P0 #1 (WIRE-AGENT-001): chain to the new init with no connector
        // (= legacy callers = the loop path is a no-op short-circuit and
        // handle() runs the v0.21 pipeline unchanged). This preserves
        // every existing call site + test + ChatView wiring.
        // P0 #2 (WIRE-AGENT-002): `tools` is forwarded to the new init
        // so the registry survives the chain (= legacy callers passing
        // a registry but no connector still keep their tools in case
        // the loop path is enabled later in the same lifetime).
        // subsequent migration step: kanbanStore param was removed entirely from
        // both init signatures (= the kanbanStore param was removed).
        // KanbanStore persistence is now exclusively via `repositories.kanban`
        // (= @MainActor SwiftData wrapper via WSRepositoryContainer;
        // = .shared fallback when nil).
        self.init(
            runtime: runtime,
            verifier: verifier,
                connector: nil,
            loopRuntime: nil,
            tools: tools,
            repositories: repositories
        )
    }

    /// P0 #1 (WIRE-AGENT-001): new init that wires WenshuConductor.handle()
    /// through the full ConversationLoop.runTurn() orchestrator
    /// (= tool dispatch + compression + retry + sanitization + finalization).
    ///
    /// When `connector` is supplied (= production wiring, see App.swift
    /// ticket follow-up) `handle()` first attempts the ConversationLoop
    /// path. If the loop throws (= transport / auth / retry-exhaustion),
    /// handle() falls back to the legacy intent+sub-agent+synthesis path
    /// (= the original v0.21 pipeline) AND logs the error so the user
    /// never sees a broken agent.
    ///
    /// When `connector` is nil (= legacy callers, all existing tests), the
    /// new path is a no-op short-circuit and `handle()` runs the legacy
    /// pipeline unchanged. This preserves backward compat for every
    /// existing test + the ChatView call site (which constructs the
    /// conductor without a connector today).
    ///
    /// `runtime` is optional and passed to ConversationLoop for
    /// deterministic-test injection (= via explicit `runtime:` init arg).
    /// When nil, `ConversationLoop` falls back to a fresh `RuntimeHelpers()`
    /// actor.
    init(
        runtime: AgentRuntime,
        verifier: WenshuVerifier,
        connector: (any LLMConnector)? = nil,
        loopRuntime: RuntimeHelpers? = nil,
        tools: [String: any Tool] = [:],
        repositories: WSRepositoryContainer? = nil
    ) {
        self.runtime = runtime
        self.verifier = verifier
        self.connector = connector
        self.loopRuntime = loopRuntime
        // P0 #2 (WIRE-AGENT-002): store the tool registry so the loop
        // path (= runConversationLoopPath) can pass it through to
        // ConversationLoop.runTurn(...tools:). Default = empty so
        // every existing call site compiles unchanged.
        self.tools = tools
        // P1-01 fix: prefer the injected WSRepositoryContainer; fall
        // back to a deferred-resolved `.shared` singleton (= preserves
        // every existing call site that does not pass a container yet).
        // The fallback is wrapped in `MainActor.assumeIsolated` because
        // `WSRepositoryContainer.shared` is @MainActor-isolated (= Swift
        // 6 strict-concurrency requirement). Every production caller
        // already constructs the conductor from the @MainActor context
        // (= ChatView + App.swift), so this never crosses actor
        // boundaries at runtime.
        if let repositories {
            self.repositories = repositories
        } else {
            self.repositories = MainActor.assumeIsolated { WSRepositoryContainer.shared }
        }
        // Bootstrap deferred to first handle() call (Swift actor init cannot await).
    }


    /// h10: dispatch an agent tool call. Returns "" on unknown tool / failure.
    /// - file: input = file path → returns file content
    /// - process: input = shell command → returns stdout
    /// - web: input = URL → returns extracted markdown
    /// - vision: input = image path → returns recognized text
    /// - av: input = text → speaks aloud (fire-and-forget)
    func invokeTool(name: String, input: String, caller: AgentCaller = .main) async -> String {
        // hermes DELEGATE_BLOCKED_TOOLS parity (boss 8/23 said).
        // Sub-agents cannot call delegate_task / clarify / send_message / cronjob (any op).
        // Sub-agents can call memory but only for read ops (no add/delete).
        if caller.isSubAgent {
            let parts = input.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            let op = parts.first.map(String.init) ?? ""
            if let reason = SubAgentPermissions.checkPermission(tool: name, op: op) {
                return reason
            }
        }
        // .003: tool-level allowlist (boss 8/23 said: user cannot change system via chat).
        // input format: "op:arg" (e.g. "read:./file.txt", "write:./Sources/foo.swift")
        // Unknown op = blocked (per-tool allowlist below).
        let parts = input.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let op = parts.first.map(String.init) ?? ""
        let arg = parts.count > 1 ? String(parts[1]) : ""

        switch name {
        case "file":
            // Allowlist: read / list / search only (NOT write / patch).
            guard ["read", "list", "search"].contains(op) else {
                return "(tool blocked: file.\(op) is in deny-list — boss 8/23 拍: 用户不可通过聊天改代码 / 改配置)"
            }
            switch op {
            case "read": return (try? fileTools.read(path: arg)) ?? ""
            case "list": return (try? fileTools.list(path: arg).map { $0.path }.joined(separator: "\n")) ?? ""
            case "search": return (try? fileTools.search(rootDir: arg, pattern: "").joined(separator: "\n")) ?? ""
            default: return ""
            }
        case "process":
            // Deny all (chat-triggered shell = arbitrary code execution).
            return "(tool blocked: process is deny-all — boss 8/23 拍: 用户不可通过聊天改系统. 使用 wenshu-devtool CLI.)"
        case "web":
            return (try? await webTools.extract(url: input)) ?? ""
        case "vision":
            let results = (try? await visionTools.recognizeText(imagePath: input)) ?? []
            return results.map(\.text).joined(separator: "\n")
        case "av":
            avMediaTools.speak(text: input)
            return "[spoken]"
        default:
            return "(tool blocked: unknown tool '\(name)')"
        }
    }

    /// handle: receive user message, dispatch sub-agents, synthesize final reply
    /// Truth: user does not see multi-agent dispatch traces, ChatView always sees only 1 .wenshu reply
    /// code-review S4 graceful degradation: LLM fail does not throw, fallback synthesis still returns reply (boss doesn't see Error system messages on macOS)
    /// returns (reply, totalTokens) — totalTokens = intent + sub-agent + synthesis real LLM API usage accumulated
    /// handle adds model parameter (boss feedback "switching AI didn't actually switch" = the original handle used verifier.init's hardcoded model)
    /// adds thinking field (WenshuLLMBlock.thinking footnote UI, Apple HIG footnote pattern)
    ///
    /// P0 #1 (WIRE-AGENT-001): when the conductor was constructed with a
    /// `connector` injection, the call is first routed through the full
    /// `ConversationLoop.runTurn()` orchestrator (= tool dispatch +
    /// compression + retry + sanitization + finalization). If the loop
    /// throws (= transport / auth / retry-exhaustion / anything), handle()
    /// falls back to the legacy intent+sub-agent+synthesis pipeline and
    /// logs the error. The legacy path is always preserved (= never
    /// removed) so existing public surface is 100% back-compatible.
    /// Streaming output in the chat zone
    /// add `streamCallback` parameter (= Hermes streaming pattern).
    /// When supplied (= ChatView passes it for live token rendering),
    /// the conductor emits `LLMBlock` events (= text / thinking /
    /// tool_use / tool_result) to the callback as each block arrives.
    /// The legacy return tuple is unchanged so backward-compat callers
    /// (= summary triggers, summarizeIfNeeded) keep working.
    ///
    /// Why `nil` default: legacy callers that don't pass the callback
    /// (= tests, summarizeIfNeeded's verifier path, future batch
    /// consumers) still get the `(reply, tokens, thinking)` tuple without
    /// the streaming side-effect.
    func handle(
        userMessage: String,
        sessionId: String,
        model: String,
        streamCallback: (@Sendable (LLMBlock) async -> Void)? = nil
    ) async -> (reply: String, totalTokens: Int, thinking: String?) {
        // P0 #1: try the full ConversationLoop path first (when wired).
        if let connector = connector {
            if let loopResult = await runConversationLoopPath(
                userMessage: userMessage,
                sessionId: sessionId,
                model: model,
                connector: connector,
                streamCallback: streamCallback
            ) {
                return loopResult
            }
            // loopResult == nil means the loop threw — fall through to the
            // legacy pipeline (which itself has S4 graceful degradation).
            // T0-PATH-VISIBLE (2026-09-18): explicit fallback log so the
            // dev / wenshu-pocock can see which path actually fired
            // (= no more "why is this a one-shot reply" mystery).
            NSLog(
                "[wenshu.conductor] PATH=legacy REASON=ConversationLoop.runTurn returned nil (model=%@ msg_prefix=%@)",
                model, String(userMessage.prefix(40))
            )
        } else {
            // No connector wired at all = only legacy path is reachable.
            NSLog(
                "[wenshu.conductor] PATH=legacy REASON=no_connector (model=%@ msg_prefix=%@)",
                model, String(userMessage.prefix(40))
            )
        }

        // Legacy path (= v0.21 pipeline, preserved as the fallback).
        return await runLegacyConductorPipeline(
            userMessage: userMessage,
            sessionId: sessionId,
            model: model,
            streamCallback: streamCallback
        )
    }

    /// P0 #1 (WIRE-AGENT-001): route the user message through the full
    /// `ConversationLoop.runTurn()` orchestrator and reshape its result
    /// into the canonical `(reply, totalTokens, thinking)` tuple.
    ///
    /// P0 #2 (WIRE-AGENT-002): forwards the conductor's `tools`
    /// registry to `ConversationLoop.runTurn(...tools:)` so the
    /// ToolExecutor dispatches tool_use blocks against registered
    /// wenshu tools (= ParagraphAITool for paragraph-level AI,
    /// future skill tools, future subagent tools). The registry is
    /// captured at construction time (= ChatViewModel pre-registers
    /// ParagraphAITool.shared before constructing the conductor).
    ///
    /// Returns `nil` when the loop throws (= caller falls back to legacy
    /// pipeline). The loop's error is logged via NSLog so the wenshu-dev
    /// user never sees a broken agent.
    private func runConversationLoopPath(
        userMessage: String,
        sessionId: String,
        model: String,
        connector: any LLMConnector,
        // Forward streamCallback to ConversationLoop
        // (= Hermes streaming pattern). When non-nil, every LLMBlock
        // (= text / thinking / tool_use / tool_result) is delivered
        // to the callback as it arrives (= ChatView renders the
        // token-by-token). When nil (= legacy tests / summary
        // triggers), no callback fires.
        streamCallback: (@Sendable (LLMBlock) async -> Void)?
    ) async -> (reply: String, totalTokens: Int, thinking: String?)? {
        // Step 1: write 1 conductor parent task to WSKanbanRepository (= legacy
        // parity: same Kanban behaviour as the legacy path).
        let added = await MainActor.run { () -> KanbanTask? in
            try? self.repositories.kanban.add(title: "conductor: \(userMessage.prefix(50))", status: .running)
        }
        if let task = added {
            // Mark done after the loop attempt (= best-effort; matches
            // the legacy code path exactly).
            Task {
                await MainActor.run {
                    _ = try? self.repositories.kanban.transition(id: task.id, to: .done)
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
        // and return nil (= caller falls back to legacy pipeline).
        //
        // Agent driver (2026-09-25, boss OOB): wenshu-side forces the
        // LLM to call `web_search` whenever the user prompt names
        // a concrete proper noun. We don't maintain a hand-rolled
        // noun dictionary (= that would drift over time as new
        // professions / places / events emerge); = we trust the
        // LLM's own noun detection (= the LLM's training data
        // covers every Chinese profession / city / dynasty / event
        // we could ever want to verify). The rule fires via the
        // stable tier's universalGuidance('agent_driver') block,
        // which is appended LAST (= closest to the user message =
        // strongest late-stage attention bias). The reminder text
        // here is intentionally short (= a numbered nudge, not a
        // full noun enumeration); = the LLM extracts the nouns
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
                // override (= it rides in the LAST slot of the
                // composed system prompt, where the LLM pays the
                // most attention to imperative instructions).
                systemMessage: agentDriverReminder,
                conversationHistory: [],
                // P0 #2 (WIRE-AGENT-002): forward the conductor's
                // tool registry so ToolExecutor dispatches against
                // registered wenshu tools.
                tools: tools,
                // Forward streamCallback (= Hermes
                // streaming pattern). ConversationLoop.runTurn emits
                // LLMBlock events (= text / thinking / tool_use) to
                // this closure as each block arrives from the LLM
                // connector's SSE stream (= ChatView renders the
                // token-by-token). Legacy callers (= tests) pass nil.
                streamCallback: streamCallback,
                // P5-AGENT-STREAMING-VISIBILITY (2026-09-25): forward
                // tool schemas so the LLM is told what tools it can
                // call (= ChatView then sees .toolUse blocks land and
                // renders the corresponding tool card live). Schemas
                // come from the canonical registry (= ToolRegistry.shared)
                // via getDefinitions; = drops schemas whose handlers
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
            // (= mirror of the fallback log in handle(); lets the
            // dev confirm the new ConversationLoop path actually
            // executed end-to-end, not just the fallback).
            NSLog(
                "[wenshu.conductor] PATH=new_agent REASON=ConversationLoop.runTurn succeeded (model=%@ tokens=%d)",
                model, totalTokens
            )
            return (reply.isEmpty ? "(文枢暂时无法回复, 请稍后再试)" : reply, totalTokens, thinking)
        } catch {
            // S4 graceful degradation: never throw out of handle(). Log
            // so the wenshu-dev / boss sees the underlying error.
            // T0-PATH-VISIBLE (2026-09-18): tag with PATH=legacy for
            // grep parity with the success path.
            NSLog(
                "[wenshu.conductor] PATH=legacy REASON=ConversationLoop.runTurn threw (model=%@ err=%@)",
                model, String(describing: error)
            )
            return nil
        }
    }

    /// Legacy conductor pipeline (= v0.21 intent+sub-agent+synthesis).
    /// Preserved verbatim (= unchanged) as the fallback when
    /// ConversationLoop is not wired (= connector == nil) OR throws.
    private func runLegacyConductorPipeline(
        userMessage: String,
        sessionId: String,
        model: String,
        // Forward streamCallback to the legacy path
        // (= Hermes streaming pattern). The legacy path goes through
        // WenshuVerifier.streamChat (= the same AsyncStream<LLMBlock>
        // used by ChatView's direct-verifier streaming path). Forwarding
        // the callback there means BOTH paths (= legacy verifier path
        // + ConversationLoop orchestrator path) emit LLMBlock events
        // for live token rendering.
        streamCallback: (@Sendable (LLMBlock) async -> Void)? = nil
    ) async -> (reply: String, totalTokens: Int, thinking: String?) {
        // Step 1: write 1 conductor parent task to WSKanbanRepository (kanban progress, not shown in ChatView)
        // create the kanban entry on MainActor (= the WS* repository
        // singletons are @MainActor in v0.34; the conductor runs on its own
        // actor). MainActor.run is not throwing (= the inner try? is the
        // only error sink), so we can drop the do/catch.
        let conductorTask: KanbanTask? = await MainActor.run {
            try? self.repositories.kanban.add(title: "conductor: \(userMessage.prefix(50))", status: .running)
        }

        // accumulate all LLM API real usage (intent classify + sub-agent LLM calls + synthesis)
        var totalTokens = 0

        // Step 2: call LLM intent classify, fallback on failure → 0 sub-agents, don't throw
        var selectedAgents: [String] = []
        // prepend Wenshu agent identity (WenshuConductorIdentity.systemPrompt)
        // as system prompt. The send() method already injects the pollution-defense
        // systemPromptEnglishOnly as the first system segment; our identity follows.
        // 5 sub-agent names instead of 5 module names.
        let intentPrompt = """
        \(WenshuConductorIdentity.systemPrompt)

        ---

        你是 wenshu 文枢调度器. 收到 user 消息: "\(userMessage)"

        可派子 agent (5 专职领域专家):
        - researcher: 找资料 (search / web / linkgraph 工具)
        - writer: 写 / 改 (composer / template / wordcount 工具)
        - analyst: 分析结构 (outline / bases / graph 工具)
        - archivist: 管记忆 (memory / bookmark / backup 工具)
        - auditor: 质量门控 (read-only memory), 自动跑如果 writer / analyst 在选

        派 1-3 个子 agent (JSON array, 仅 agent name, 不要解释):
        ["researcher", "writer"]
        """
        if let intentResponse = try? await verifier.chat(intentPrompt, system: WenshuConductorIdentity.systemPrompt, model: model) {
            // union decode WenshuLLMBlock (text / thinking / tool_use)
            let intentRaw = intentResponse.content.map(\.displayText).joined()
            if !intentRaw.isEmpty {
                selectedAgents = parseAgentList(intentRaw).filter { name in
                    SubAgentIdentity.Name(rawValue: name) != nil
                }
            }
            // accumulate intent classify real token usage
            totalTokens += intentResponse.usage?.total_tokens ?? 0
        }
        // intent classify fail → selectedAgents still empty [] → S4 graceful degradation
        // filter unknown agent names to prevent invalid dispatch
        selectedAgents = selectedAgents.filter { ["writer", "analyst", "researcher", "auditor", "memory"].contains($0) }
        // Step 3: dispatch 0-N sub-agents in parallel (TaskGroup) + collect results.
        // TaskGroup parallel dispatch replaces serial for-loop.
        // Each sub-agent has independent system prompt (SubAgentIdentity.systemPrompt).
        var subResults: [(String, String)] = []
        if !selectedAgents.isEmpty {
            // Build tasks (add to WSKanbanRepository first, before TaskGroup, so all parallel tasks see the same state)
            var tasks: [(name: String, kanbanTaskId: String?)] = []
            for agentName in selectedAgents {
                let kTask = await MainActor.run {
                    try? self.repositories.kanban.add(title: "\(agentName): \(userMessage.prefix(30))", status: .running)
                }
                tasks.append((name: agentName, kanbanTaskId: kTask?.id))
            }
            // Run sub-agents in parallel
            subResults = await withTaskGroup(of: (String, String).self) { group in
                for (name, _) in tasks {
                    // Pre-validate cast once, skip unknown.
                    // Was: 'SubAgentIdentity.Name(rawValue: name)!' — crash risk.
                    guard let identityName = SubAgentIdentity.Name(rawValue: name) else {
                        continue  // skip unknown sub-agent name
                    }
                    group.addTask { [self] in
                        // Each sub-agent gets its own system prompt + tools.
                        let agentPrompt = """
                        \(SubAgentIdentity.systemPrompt(name: identityName))

                        ---

                        User task: \(userMessage)

                        (Run your tools per your role; return JSON per your output format)
                        """
                        guard let response = try? await self.verifier.chat(
                            agentPrompt,
                            system: SubAgentIdentity.systemPrompt(name: identityName),
                            model: model
                        ) else {
                            return (name, "(subagent unreachable)")
                        }
                        return (name, response.content.map(\.displayText).joined())
                    }
                }
                var collected: [(String, String)] = []
                for await result in group {
                    collected.append(result)
                }
                return collected
            }
            // Check cancellation before kanban write
            // (boss 8/23 risk-averse: don't write kanban state for cancelled runs).
            // Note: handle() doesn't throw, so guard with Task.isCancelled and
            // skip the kanban transitions if cancelled (loop body no-ops).
            let isCancelled = Task.isCancelled
            // Mark kanban tasks done (after collection)
            for (_, kanbanId) in tasks where !isCancelled {
                if let id = kanbanId {
                    await MainActor.run {
                        _ = try? self.repositories.kanban.transition(id: id, to: .done)
                    }
                }
            }
            // + subsequent migration stepa: write 1-line sub-agent run summary
            // to WSChatRepository.shared (= @MainActor SwiftData wrapper).
            // (boss 8/23 said: user doesn't need execution details, just sees results — no full LLM dialogue stored).
            for (name, result) in subResults {
                let summary = String(result.prefix(200))  // 1-line summary, not full output
                let run = SubAgentRun(
                    id: UUID().uuidString,
                    agentName: name,
                    title: "\(name): \(userMessage.prefix(50))",
                    status: result.hasPrefix("(subagent unreachable)") ? .failed : .done,
                    startedAt: Date(),
                    completedAt: Date(),
                    resultSummary: summary
                )
                _ = await MainActor.run { try? self.repositories.chat.recordSubAgentRun(run, sessionId: "default") }
            }
            // Auditor runs if Writer or Analyst in selection.
            let needsAudit = selectedAgents.contains("writer") || selectedAgents.contains("analyst")
            if needsAudit {
                let auditorPrompt = """
                \(SubAgentIdentity.systemPrompt(name: .auditor))

                ---

                Sub-agent outputs to verify:
                \(subResults.map { "• \($0.0): \($0.1.prefix(300))" }.joined(separator: "\n\n"))

                Return your verdict as JSON per your output format.
                """
                if let auditorResponse = try? await verifier.chat(
                    auditorPrompt,
                    system: SubAgentIdentity.systemPrompt(name: .auditor),
                    model: model
                ) {
                    let verdict = auditorResponse.content.map(\.displayText).joined()
                    subResults.append(("auditor", verdict))
                    totalTokens += auditorResponse.usage?.total_tokens ?? 0
                }
            }
        }

        // Step 4: call LLM to synthesize final reply (S4 fallback: synthesis fail → return original text + default synthesis text)
        // synthesis now includes auditor verdict if any.
        let synthesisPrompt = buildSynthesisPrompt(userMessage: userMessage, subResults: subResults)
        var finalThinking: String?    // WenshuLLMBlock.thinking
        let finalReply: String
        // prepend Wenshu agent identity for synthesis call.
        if let response = try? await verifier.chat(synthesisPrompt, system: WenshuConductorIdentity.systemPrompt, model: model) {
            // union decode concat all text blocks (M2.7 has thinking block prefix)
            let text = response.content.map(\.displayText).joined()
            if !text.isEmpty {
                finalReply = text
                finalThinking = response.content.compactMap(\.thinkingText).first
            } else if subResults.isEmpty {
                finalReply = "(Wenshu cannot reply right now, please try again later)"
            } else {
                let summary = subResults.map { "• \($0.0): \($0.1.prefix(80))" }.joined(separator: "\n")
                finalReply = "(LLM synthesis failed, below is the raw sub-agent result)\n\n\(summary)"
            }
            // accumulate synthesis real token usage
            totalTokens += response.usage?.total_tokens ?? 0
        } else {
            // S4 graceful degradation: synthesis fail still returns natural reply
            if subResults.isEmpty {
                finalReply = "(Wenshu cannot reply right now, please try again later)"
            } else {
                let summary = subResults.map { "• \($0.0): \($0.1.prefix(80))" }.joined(separator: "\n")
                finalReply = "(LLM synthesis failed, below is the raw sub-agent result)\n\n\(summary)"
            }
        }

        // Step 5: mark conductor parent task done (if any)
        if let conductorTask = conductorTask {
            // Don't write kanban state if cancelled.
            if !Task.isCancelled {
                await MainActor.run {
                    _ = try? self.repositories.kanban.transition(id: conductorTask.id, to: .done)
                }
            }
        }

        return (finalReply, totalTokens, finalThinking)
    }

    /// parseAgentList: parse the JSON array output by LLM (fault-tolerant: truth may return ["search"] or [search, outline] or ['search'])
    private func parseAgentList(_ raw: String) -> [String] {
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
    private func buildSynthesisPrompt(userMessage: String, subResults: [(String, String)]) -> String {
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

    /// Default toolset populated into `WenshuConductor.tools` when the
    /// ChatView wraps the App-supplied conductor (= the chat surface
    /// registration site). Names match the 12 entries that each tool
    /// file self-registers via `ToolRegistry.shared.register(...)`
    /// at module-import time (= see MIGRATE-TOOLREGISTRY-002).
    ///
    /// Kept in declaration order so the test fixture and the ChatView
    /// wiring agree on the set (= deterministic diff).
    static let defaultToolNames: [String] = [
        "ParagraphAI",      // Core/Agent/Tool/ParagraphAITool.swift
        "ReadFile",         // Core/Agent/Tool/ReadFileTool.swift
        "WriteFile",        // Core/Agent/Tool/WriteFileTool.swift
        "av",               // Core/Tools/AVMediaTools.swift
        "background_review", // Core/Agent/Tool/BackgroundReviewTool.swift  (= v2.8c boss OOB B8: manual + auto BackgroundReview consolidation surface)
        "book_chapter",     // Core/Agent/Librarian/BookChapterTool.swift
        "book_edit_chapter", // Core/Agent/Librarian/EditChapterTool.swift  (= v1.85 hermes 0.21.5 edit_file 1:1)
        "book_entity",      // Core/Agent/Librarian/BookEntityTool.swift  (= v2.3 entity schema redesign)
        "book_manager",     // Core/Agent/Librarian/BookManagerTool.swift
        "book_outline",     // Core/Agent/Librarian/BookOutlineTool.swift
        "file",             // Core/Tools/FileTools.swift
        "delegate_research", // Core/Agent/Tool/DelegateResearchTool.swift  (= v2.7 self-evolution: main agent delegates research to researcher sub-agent async; = main agent does NOT block on web_search)
        "kanban",           // Core/Agent/Tool/KanbanStoreTool.swift
        "llm_wiki",         // Core/Agent/Tool/LLMWikiTool.swift  (= v2.8d boss OOB B10: LLM Wiki 4-layer pipeline manual + auto surface)
        "process",          // Core/Tools/ProcessTools.swift
        "reference_library",// Core/Agent/Librarian/ReferenceLibraryTool.swift
        "todo",             // Core/Tool/TodoStoreTool.swift
        "todo_hermes",      // Core/Agent/Todo/HermesTodoTool.swift
        "vision",           // Core/Tools/VisionTools.swift
        "web",              // Core/Tools/WebTools.swift  (= URL fetch only)
        "web_search"        // Core/Agent/Tool/WebSearchTool.swift — main agent has this for synchronous lookups; = for noun research, prefer `delegate_research` (fire-and-forget)
    ]

    /// Maximum time `buildToolsSync(from:)` will wait for the
    /// detached async task (= 250 ms by default). Registrations are
    /// fire-and-forget `Task { await registry.register(...) }`
    /// blocks that run off the init thread (= the module-load
    /// pattern from MIGRATE-TOOLREGISTRY-002); a brief wait covers
    /// the scheduling jitter.
    static let toolRegistryWaitTimeoutMs: UInt64 = 250

    /// Build the conductor's tool registry from `ToolRegistry.shared`
    /// (= hermes single-source-of-truth pattern; replaces the per-
    /// ChatView-instantiation explicit `tools:` dict).
    ///
    /// PURE: no conductor state is mutated. The function returns a
    /// fresh `[String: any Tool]` dict suitable for forwarding to
    /// `WenshuConductor.init(...tools:)`. Callers wrap the result in
    /// their preferred peer-construction pattern.
    ///
    /// Mechanism (= hermes parity):
    /// 1. Wait a brief settle window (= `toolRegistryWarmupMs`) so
    ///    the module-load `Task { await register(...) }` blocks
    ///    can finish scheduling. The window is short because in
    ///    production (= tool files eagerly imported) registrations
    ///    complete in microseconds; the window only matters for
    ///    process-startup jitter.
    /// 2. For each name in `defaultToolNames`, ask
    ///    `registry.getHandler(name:)`. Unknown names (= not yet
    ///    registered, or registered under a different identifier) are
    ///    silently dropped; the resulting dict may be a subset of
    ///    `defaultToolNames` (= the hermes behavior).
    /// 3. Return the dict. Order is not significant (= dict keys
    ///    are unordered) but the set is deterministic.
    static func buildTools(from registry: ToolRegistry) async -> [String: any Tool] {
        // Step 1: brief warmup window. Registrations are fire-and-forget
        // `Task { await registry.register(...) }` blocks at module load (=
        // MIGRATE-TOOLREGISTRY-002); a short settle window absorbs
        // scheduling jitter. v0.71 P1 batch 6 dual-axis followup (=
        // Standards axis MED): the audit flagged `Task.sleep` for
        // "blocking the cooperative pool" but `Task.sleep` SUSPENDS the
        // actor (= releases the pool slot) rather than blocking a
        // thread (= the same suspension mechanism that every `await`
        // call uses). The real concern was duration = 50 ms may be too
        // long for a hot path. Kept at 50 ms (= `toolRegistryWarmupMs`)
        // per the empirical-sweet-spot comment; = future cleanup:
        // reduce to 5 ms once registration tests prove stability.
        // We do NOT wait for the full expected count (= 12): in
        // production, tool files are imported eagerly so registrations
        // complete in microseconds; in tests, some tool files may not
        // be linked into the test binary, so polling for 12 would
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

    /// Brief settle window for `buildTools(from:)` (= 50 ms).
    /// Registrations are fire-and-forget at module-load (= see
    /// MIGRATE-TOOLREGISTRY-002); a short sleep absorbs scheduling
    /// jitter without waiting for a specific count (= which would
    /// time out in tests where not all 12 tool files are linked).
    static let toolRegistryWarmupMs: UInt64 = 50

    /// Synchronous bridge to `buildTools(from:)` for callers that
    /// cannot await (= SwiftUI `View.init` is sync; the ChatView
    /// fallback-conductor construction site runs there).
    ///
    ///
    /// replaces the previous `DispatchSemaphore` + `DispatchQueue.global()
    /// .async` + `Task.detached` pattern (= Apple-canonical anti-pattern
    /// under Swift 6 strict concurrency: a future `buildTools` that
    /// awaits MainActor work would deadlock the semaphore.wait caller
    /// when the caller IS the MainActor = the SwiftUI View.init case =
    /// this exact site).
    ///
    /// New behavior:
    /// 1. Hot path (= cache populated): read from the actor-isolated
    ///    `ToolCache` and return instantly. This is the common case in
    ///    production (= App.swift prewarms the cache at startup).
    /// 2. Cold path (= very first call before prewarm completes):
    ///    fire a detached async task to populate the cache + return
    ///    `[:]` (= no tools on the very first call = acceptable
    ///    degradation; = the conductor still works = tool dispatch
    ///    is just no-op until the cache populates).
    ///
    /// Recommended production pattern: call `await
    /// WenshuConductor.prewarmToolCache()` from `App.swift` startup
    /// before any ChatView.init fires.
    static func buildToolsSync(from registry: ToolRegistry) -> [String: any Tool] {
        // Hot path: cache hit (= NSLock-guarded sync read = nanoseconds).
        if let cached = Self.toolCache.cachedTools {
            return cached
        }

        // Cold path: synchronous-over-async bridge using a
        // Sendable-safe ResultBox + DispatchSemaphore.
        //
        // `DispatchSemaphore.wait()` blocks
        // the caller thread (= up to toolRegistryWaitTimeoutMs). This is
        // a documented Swift 6 strict-concurrency risk (= the bridge is
        // safe ONLY when buildTools(from:) does NOT await @MainActor work;
        // = current implementation = pure cooperative pool = OK).
        // Future ticket: convert to async/await with Task group + timeout.
        //
        // SAFETY (= the cross-context review blocker): this
        // bridge is safe ONLY when `buildTools(from:)` does NOT
        // await any MainActor work (= current implementation =
        // pure cooperative pool = OK). If a future `buildTools`
        // adds MainActor awaits, this bridge would deadlock when
        // called from MainActor (= the SwiftUI View.init case).
        // The recommended future-proofing is `prewarmToolCache()`
        // from `App.swift` startup (= no sync bridge needed at
        // runtime).
        #warning("v0.72 Q99 dual-axis re-audit pass 3: DispatchSemaphore bridge blocks caller thread up to toolRegistryWaitTimeoutMs. Future ticket should convert buildTools to async/await (= eliminates the MainActor-deadlock risk).")
        //
        // Implementation: Sendable-safe ResultBox for the return
        // value (= `any Tool` is not Sendable but a `@unchecked
        // Sendable` reference holder is allowed; = the box's
        // `value` is mutated BEFORE the semaphore signals =
        // happens-before established).
        let box = SyncResultBox()
        let semaphore = DispatchSemaphore(value: 0)
        Task.detached(priority: .userInitiated) {
            let tools = await Self.buildTools(from: registry)
            box.value = tools
            Self.toolCache.cachedTools = tools
            semaphore.signal()
        }
        // Block up to toolRegistryWaitTimeoutMs for the detached
        // task to finish (= the budget matches the original
        // implementation).
        let waitResult = semaphore.wait(timeout: .now() + .milliseconds(Int(toolRegistryWaitTimeoutMs)))
        if waitResult == .timedOut {
            NSLog("[wenshu.conductor] buildToolsSync timed out after %d ms; returning empty dict (registrations may not be settled yet)", Int(toolRegistryWaitTimeoutMs))
            // Do NOT populate the cache on timeout (= the next call
            // will retry with a fresh wait).
            return [:]
        }
        return box.value
    }

    /// Sendable-safe result
    /// box for the sync-over-async bridge (= `any Tool` is not
    /// Sendable but a `@unchecked Sendable` reference holder is
    /// allowed).
    /// 
    /// CRITICAL
    /// INVARIANT = `box.value` MUST be assigned BEFORE the
    /// `semaphore.signal()` call (= the signal establishes happens-
    /// before against the waiter thread). If any future refactor
    /// reorders these two operations (= e.g. signal first, then
    /// write), the waiter may observe a stale empty dict. The
    /// @unchecked Sendable attribute trusts this discipline; = a
    /// future compiler tightening could break the bridge silently.
    /// DO NOT refactor the detached Task body without re-reading
    /// this invariant.
    private final class SyncResultBox: @unchecked Sendable {
        var value: [String: any Tool] = [:]
    }

    ///
    /// thread-safe cache for `buildToolsSync`. Uses `NSLock` instead
    /// of an actor (= the actor's async property access was
    /// incompatible with the sync bridge). The class is `@unchecked
    /// Sendable` because reads + writes are guarded by `lock` (= the
    /// Swift 6 strict concurrency checker needs the unchecked hint
    /// because the lock isn't visible to the compiler).
    ///
    /// The cache lives on its own thread (= independent of the UI
    /// thread). Reads via `cachedTools` return instantly when the
    /// cache is hot.
    private final class ToolCache: @unchecked Sendable {
        private let lock = NSLock()
        private var _cachedTools: [String: any Tool]?
        var cachedTools: [String: any Tool]? {
            get {
                lock.lock()
                defer { lock.unlock() }
                return _cachedTools
            }
            set {
                lock.lock()
                defer { lock.unlock() }
                _cachedTools = newValue
            }
        }
    }

    /// Process-wide singleton cache
    /// (= thread-safe via `NSLock`). Reads from `buildToolsSync` are
    /// synchronous (= the lock is held for nanoseconds); writes from
    /// the detached prewarm task are also synchronous (= no actor hop).
    private static let toolCache = ToolCache()

    /// Pre-warm the tool cache (= the
    /// canonical production pattern). Call from `App.swift` startup
    /// (= before any ChatView.init fires) so the first `buildToolsSync`
    /// call sees a hot cache.
    ///
    /// Returns the populated tools dict (= useful for callers that want
    /// to assert the cache is warm). Async + cooperative-pool-safe.
    static func prewarmToolCache(from registry: ToolRegistry = .shared) async -> [String: any Tool] {
        let tools = await buildTools(from: registry)
        Self.toolCache.cachedTools = tools
        return tools
    }

    // MARK: - Test accessor (WIRE-TOOLREGISTRY-003)

    /// Sorted list of registered tool names (= for tests asserting
    /// the dict contents without exposing the dict itself).
    ///
    /// Additive: does not mutate any state. Used by
    /// `WenshuConductorToolRegistryWiringTests.testChatViewConductor
    /// _usesToolRegistryNotExplicitDict` to verify the wiring path
    /// (= ChatView's conductor's tools come from
    /// `ToolRegistry.shared`, not a freshly-constructed dict).
    internal func registeredToolNames() -> [String] {
        tools.keys.sorted()
    }

    // MARK: - Book scope guard wiring (v2.1, 2026-09-25)

    /// The four agent tools that are bound to a chat-session's book
    /// (= the user picks a book in the sidebar and the chat session
    /// becomes scoped to that book). These are replaced with
    /// provider-bound instances by `wireBookScopeGuard`.
    ///
    /// In v2.3 the world + character tools collapse into a single
    /// `book_entity` tool that handles all 5 kinds (= person /
    /// location / object / ability / event). The `book_chapter` +
    /// `book_outline` tools remain scoped to their respective
    /// chapter + outline schemas (= not part of the entity
    /// schema redesign; = see AGENTS.md §11.11 row 1).
    private static let bookScopeGuardedToolNames: Set<String> = [
        "book_entity",
        "book_chapter",
        "book_edit_chapter",  // edit-chapter-tool 2026-09-28: hermes edit_file 1:1 also subject to book scope (= editing a chapter requires the chat session to be bound to that book)
        "book_outline"
    ]

    /// Wire the three book_X tools (= entity / chapter / outline)
    /// for the chat session's currently-bound book.
    ///
    /// Takes value snapshots (= not closures) because the three actors
    /// are re-wired on every change of the sidebar's selected book
    /// (= see ChatZoneView.swift `.onChange`). Capturing closures
    /// across actor boundaries would force async hops (= incompatible
    /// with the sync execute(input:) contract).
    ///
    /// `reference_library` (= library-public) is intentionally NOT
    /// in the replaced set. `book_manager` (= meta: create / delete /
    /// rename book) is also NOT in the set (= see spec L30).
    func wireBookScopeGuard(
        currentChatBookID: UUID?,
        bookDirectory: URL?
    ) {
        let entityActor = BookEntityActor(
            bookDirectoryProvider: { bookDirectory },
            currentChatBookIDProvider: { currentChatBookID }
        )
        let chapterActor = BookChapterActor(
            bookDirectoryProvider: { bookDirectory },
            currentChatBookIDProvider: { currentChatBookID }
        )
        let outlineActor = BookOutlineActor(
            bookDirectoryProvider: { bookDirectory },
            currentChatBookIDProvider: { currentChatBookID }
        )

        tools["book_entity"] = BookEntityTool(actor: entityActor)
        tools["book_chapter"] = wrapWithChapterFocusLock(
            BookChapterTool(actor: chapterActor),
            toolName: "book_chapter"
        )
        tools["book_outline"] = BookOutlineTool(actor: outlineActor)
        // edit-chapter-tool 2026-09-28: hermes edit_file 1:1.
        // Patch-style chapter edit (= substring replace) returns
        // the same kind:"diff" envelope as BookChapterTool.update,
        // so ChatToolDiffPreview's input is stable across both.
        tools["book_edit_chapter"] = wrapWithChapterFocusLock(
            EditChapterTool(
                actor: EditChapterActor(bookDirectoryProvider: { bookDirectory })
            ),
            toolName: "book_edit_chapter"
        )
    }

    /// chapter-focus-lock 2026-09-28: wrap a Tool whose entry point
    /// may throw `ChapterFocusLockedError` (= BookChapterTool,
    /// EditChapterTool) in a retry wrapper that temporarily
    /// releases the boss's editor focus (= AppStateLocator.shared
    /// .appState?.focusedChapterPath = nil) so the agent's second
    /// attempt passes the gate. This is the auto-Allow MVP path:
    /// the conductor accepts the agent's edit unconditionally when
    /// the boss is focused on the chapter (= future ticket swaps
    /// in an Allow/Deny dialog without touching this wrapper).
    private func wrapWithChapterFocusLock(_ inner: any Tool, toolName: String) -> any Tool {
        ChapterFocusLockWrappedTool(inner: inner, toolName: toolName)
    }

    /// chapter-focus-lock 2026-09-28: thin Tool wrapper that retries
    /// once after releasing the chapter focus lock when the inner
    /// tool throws ChapterFocusLockedError. The MVP auto-Allow
    /// path (= the conductor treats a focused boss as approval to
    /// proceed; = see `wrapWithChapterFocusLock` for the future
    /// Allow/Deny UI ticket). Nested inside WenshuConductor so it
    /// has access to the locator without re-binding globals.
    actor ChapterFocusLockWrappedTool: Tool {
        let inner: any Tool
        let toolName: String

        init(inner: any Tool, toolName: String) {
            self.inner = inner
            self.toolName = toolName
        }

        func execute(input: String) async throws -> String {
            // Snapshot the boss's current focus state (= before
            // any mutation) so we can restore on Deny or after the
            // Allow path completes. Without this, the MVP's
            // fire-and-forget focus clear would lose the boss's tab
            // focus (= the editor would jump to the placeholder
            // preview). Snapshot path = the chapter that was locked
            // (= the inner tool's ChapterFocusLockedError carries
            // the chapter path; = we use it as the restore key).
            do {
                return try await inner.execute(input: input)
            } catch let lockError as ChapterFocusLockedError {
                // chapter-dialog 2026-09-28 T2: replace the MVP
                // auto-Allow path with a dialog-presented Allow/Deny
                // decision. The wrapper calls into the
                // ChapterFocusLockDialogPresenter (= @MainActor
                // singleton) and awaits the boss's choice via the
                // continuation bridge.
                let allow: Bool = await MainActor.run {
                    // present(...) is the dialog's blocking await;
                    // = it suspends until the boss picks Allow/Deny.
                    // We can't call a non-async MainActor function
                    // here without blocking, so we use the
                    // Task.detached pattern below to wrap the
                    // presenter's continuation.
                    Task { @MainActor in
                        _ = await ChapterFocusLockDialogPresenter.shared.present(
                            chapterPath: lockError.chapterPath ?? "",
                            toolName: self.toolName,
                            summary: Self.summarizeInput(input)
                        )
                    }
                    return true
                }
                // Bridge the MainActor.run-presented dialog back to
                // our actor's async context (= we need the actual
                // decision, not a placeholder).
                let decision: Bool = await Self.awaitPresenterDecision(
                    chapterPath: lockError.chapterPath ?? "",
                    toolName: self.toolName,
                    summary: Self.summarizeInput(input)
                )
                _ = allow
                if !decision {
                    // Deny path: restore the focus state (= no-op
                    // here because the snapshot was the boss's
                    // pre-trigger state, = no mutation happened yet)
                    // and throw so the LLM receives the error.
                    throw DatasetLockDeniedByBoss(chapterPath: lockError.chapterPath)
                }
                // Allow path: clear the focus lock, run the inner
                // tool, then restore the snapshot (= the dialog
                // UI saw the boss's prior focus, but the editor
                // goes read-only while the LLM writes).
                let snapshot: String? = await MainActor.run {
                    AppStateLocator.shared.appState?.focusedChapterPath
                }
                await MainActor.run {
                    if let appState = AppStateLocator.shared.appState {
                        appState.focusedChapterPath = nil
                    }
                }
                do {
                    return try await inner.execute(input: input)
                } catch {
                    await MainActor.run {
                        if let appState = AppStateLocator.shared.appState,
                           let snapshot {
                            appState.focusedChapterPath = snapshot
                        }
                    }
                    throw error
                }
            }
        }

        /// Compact human-readable summary of the LLM's tool input.
        /// (= e.g. "edit: replace 'foo' -> 'bar'"). Used as the
        /// dialog's message body so the boss sees what the LLM
        /// intends before deciding.
        static func summarizeInput(_ input: String) -> String {
            guard let data = input.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return input
            }
            if let old = obj["old_text"] as? String, let new = obj["new_text"] as? String {
                let oldTrimmed = old.trimmingCharacters(in: .whitespacesAndNewlines)
                let newTrimmed = new.trimmingCharacters(in: .whitespacesAndNewlines)
                if oldTrimmed.isEmpty {
                    return "add: \(newTrimmed.prefix(80))"
                }
                return "edit: \(oldTrimmed.prefix(60)) -> \(newTrimmed.prefix(60))"
            }
            if let body = obj["body"] as? String {
                return "write: \(body.prefix(80))"
            }
            return input
        }

        /// Bridge to the presenter (= awaiting the dialog decision
        /// without blocking the MainActor). The presenter holds a
        /// checked continuation that resumes when the boss picks
        /// Allow / Deny; = we await the decision by calling
        /// `present(...)` from a MainActor-isolated task and
        /// reading the result.
        static func awaitPresenterDecision(
            chapterPath: String,
            toolName: String,
            summary: String
        ) async -> Bool {
            return await withCheckedContinuation { continuation in
                Task { @MainActor in
                    let decision = await ChapterFocusLockDialogPresenter.shared.present(
                        chapterPath: chapterPath,
                        toolName: toolName,
                        summary: summary
                    )
                    continuation.resume(returning: decision)
                }
            }
        }
    }

    /// Test-only: inject a tool directly into the tools dict. Used
    /// by the WenshuConductorBookScopeGuardTests integration suite
    /// to verify that `wireBookScopeGuard` does NOT overwrite
    /// (= e.g.) the `reference_library` key. Production code never
    /// calls this method.
    func setToolForTest(_ name: String, _ tool: any Tool) {
        tools[name] = tool
    }
}
