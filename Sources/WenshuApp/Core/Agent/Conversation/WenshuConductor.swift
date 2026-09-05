//
//  WenshuConductor.swift · Wenshu · v0.21 ticket 04 (Wenshu single-display, multi-agent hidden)
//                          P0 #1 (WIRE-AGENT-001, 2026-09-04)
//                          P0 #2 (WIRE-AGENT-002, 2026-09-04)
//
//  Wenshu main agent orchestrator: receives user message → calls LLM intent classify → dispatches 0-N v0.19 module agents → waits for results → calls LLM to synthesize final reply.
//  Dispatch progress goes through KanbanStore (user checks Kanban), ChatView does not show sub-agents (hidden) (boss 2026-08-21 said).
//
//  Reuses v0.19 12-module backend (LinkGraph / Search / Template / Composer / Graph / Canvas / Bases / QuickSwitcher / WordCount / Outline / Bookmarks / Verifier),
//  pattern matches AgentRuntime (actor in-process truth).
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

/// Wenshu orchestrator (actor thread-safe, consistent with AgentRuntime / KanbanStore / MemoryStore).
public actor WenshuConductor {
    private let runtime: AgentRuntime
    private let verifier: WenshuVerifier
    private let kanbanStore: KanbanStore
    private let sessionStore: ChatSessionStore?
    /// Long-term memory persistence for agent. Optional — bootstrap failure degrades gracefully (memory disabled).
    /// Bootstrap is lazy on first `handle()` call (Swift actors cannot await in init).
    /// See .scratch/2026-08-22-frontend-integration/issues/h01-memorystore-frontend.md.
    private var memoryStore: MemoryStore?
    private var memoryStoreBootstrapped: Bool = false
    /// Local Skills registry (replica of hermes skills_hub). Skills loaded at startup, agent invokes.
    /// Lazy bootstrap for the same actor isolation reason as MemoryStore.
    /// See .scratch/2026-08-22-frontend-integration/issues/h02-skill-registry-frontend.md.
    private var skillRegistry: SkillRegistry?
    private var skillRegistryBootstrapped: Bool = false
    /// h10: agent toolkit dispatch (FileTools + ProcessTools + WebTools + VisionTools).
    /// Tools are stateless structs, no bootstrap needed.
    /// See .scratch/2026-08-22-frontend-integration/issues/h10-tools-frontend.md.
    private let fileTools: FileTools = FileTools()
    private let processTools: ProcessTools = ProcessTools()
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
    private let tools: [String: any Tool]

    public init(
        runtime: AgentRuntime,
        verifier: WenshuVerifier,
        kanbanStore: KanbanStore,
        sessionStore: ChatSessionStore? = nil,
        memoryStore: MemoryStore? = nil,
        skillRegistry: SkillRegistry? = nil,
        tools: [String: any Tool] = [:]
    ) {
        // P0 #1 (WIRE-AGENT-001): chain to the new init with no connector
        // (= legacy callers = the loop path is a no-op short-circuit and
        // handle() runs the v0.21 pipeline unchanged). This preserves
        // every existing call site + test + ChatView wiring.
        // P0 #2 (WIRE-AGENT-002): `tools` is forwarded to the new init
        // so the registry survives the chain (= legacy callers passing
        // a registry but no connector still keep their tools in case
        // the loop path is enabled later in the same lifetime).
        self.init(
            runtime: runtime,
            verifier: verifier,
            kanbanStore: kanbanStore,
            sessionStore: sessionStore,
            memoryStore: memoryStore,
            skillRegistry: skillRegistry,
            connector: nil,
            loopRuntime: nil,
            tools: tools
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
    /// deterministic-test injection (= ticket v0.36 ticket 014). When nil,
    /// ConversationLoop falls back to a fresh RuntimeHelpers() actor.
    public init(
        runtime: AgentRuntime,
        verifier: WenshuVerifier,
        kanbanStore: KanbanStore,
        sessionStore: ChatSessionStore? = nil,
        memoryStore: MemoryStore? = nil,
        skillRegistry: SkillRegistry? = nil,
        connector: (any LLMConnector)? = nil,
        loopRuntime: RuntimeHelpers? = nil,
        tools: [String: any Tool] = [:]
    ) {
        self.runtime = runtime
        self.verifier = verifier
        self.kanbanStore = kanbanStore
        self.sessionStore = sessionStore
        self.memoryStore = memoryStore
        self.skillRegistry = skillRegistry
        self.connector = connector
        self.loopRuntime = loopRuntime
        // P0 #2 (WIRE-AGENT-002): store the tool registry so the loop
        // path (= runConversationLoopPath) can pass it through to
        // ConversationLoop.runTurn(...tools:). Default = empty so
        // every existing call site compiles unchanged.
        self.tools = tools
        // Bootstrap deferred to first handle() call (Swift actor init cannot await).
    }

    /// h01: lazy bootstrap of MemoryStore. Idempotent.
    private func ensureMemoryStoreBootstrapped() async {
        guard !memoryStoreBootstrapped else { return }
        memoryStoreBootstrapped = true
        guard let store = memoryStore else { return }
        do {
            try await store.bootstrap()
        } catch {
            // v0.23 audit #014 fix: reset bootstrapped flag on failure so
            // next call retries (boss 8/23 risk-averse: don't permanently
            // disable memory if bootstrap transiently fails).
            memoryStoreBootstrapped = false
            memoryStore = nil
        }
    }

    /// h02: lazy bootstrap of SkillRegistry. Lists available skills.
    private func ensureSkillRegistryBootstrapped() async {
        guard !skillRegistryBootstrapped else { return }
        skillRegistryBootstrapped = true
        guard let registry = skillRegistry else { return }
        do {
            _ = try await registry.list()
        } catch {
            // v0.23 audit #014 fix: reset bootstrapped flag on failure so
            // next call retries (don't permanently disable skills).
            skillRegistryBootstrapped = false
            skillRegistry = nil
        }
    }

    /// h02: invoke a wenshu local skill. Returns "" if registry unavailable or skill not found.
    public func invokeSkill(name: String, input: String = "") async -> String {
        await ensureSkillRegistryBootstrapped()
        guard let registry = skillRegistry else { return "" }
        return (try? await registry.invoke(name: name, input: input)) ?? ""
    }

    /// h02: list available skills (for agent context). Returns [] if registry unavailable.
    public func availableSkills() async -> [String] {
        await ensureSkillRegistryBootstrapped()
        guard let registry = skillRegistry else { return [] }
        return (try? await registry.list()) ?? []
    }

    /// h10: dispatch an agent tool call. Returns "" on unknown tool / failure.
    /// - file: input = file path → returns file content
    /// - process: input = shell command → returns stdout
    /// - web: input = URL → returns extracted markdown
    /// - vision: input = image path → returns recognized text
    /// - av: input = text → speaks aloud (fire-and-forget)
    public func invokeTool(name: String, input: String, caller: AgentCaller = .main) async -> String {
        // v0.23 ticket 012: hermes DELEGATE_BLOCKED_TOOLS parity (boss 8/23 said).
        // Sub-agents cannot call delegate_task / clarify / send_message / cronjob (any op).
        // Sub-agents can call memory but only for read ops (no add/delete).
        if caller.isSubAgent {
            let parts = input.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            let op = parts.first.map(String.init) ?? ""
            if let reason = SubAgentPermissions.checkPermission(tool: name, op: op) {
                return reason
            }
        }
        // v0.23 ticket 008.003: tool-level allowlist (boss 8/23 said: user cannot change system via chat).
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

    /// h01: persist a memory for the current user. No-op if MemoryStore unavailable.
    public func addMemory(content: String) async {
        await ensureMemoryStoreBootstrapped()
        guard let store = memoryStore else { return }
        _ = try? await store.add(userId: "wenshu-user", content: content)
    }

    /// h01: search memories for context. Returns [] if MemoryStore unavailable.
    public func searchMemory(query: String, limit: Int = 5) async -> [Memory] {
        await ensureMemoryStoreBootstrapped()
        guard let store = memoryStore else { return [] }
        return (try? await store.search(userId: "wenshu-user", query: query, limit: limit)) ?? []
    }

    /// handle: receive user message, dispatch sub-agents, synthesize final reply
    /// Truth: user does not see multi-agent dispatch traces, ChatView always sees only 1 .wenshu reply
    /// code-review S4 graceful degradation: LLM fail does not throw, fallback synthesis still returns reply (boss doesn't see Error system messages on macOS)
    /// v0.21 ticket 34: returns (reply, totalTokens) — totalTokens = intent + sub-agent + synthesis real LLM API usage accumulated
    /// v0.21 ticket 38: handle adds model parameter (boss feedback "switching AI didn't actually switch" = the original handle used verifier.init's hardcoded model)
    /// v0.21 ticket 39: adds thinking field (WenshuLLMBlock.thinking footnote UI, Apple HIG footnote pattern)
    ///
    /// P0 #1 (WIRE-AGENT-001): when the conductor was constructed with a
    /// `connector` injection, the call is first routed through the full
    /// `ConversationLoop.runTurn()` orchestrator (= tool dispatch +
    /// compression + retry + sanitization + finalization). If the loop
    /// throws (= transport / auth / retry-exhaustion / anything), handle()
    /// falls back to the legacy intent+sub-agent+synthesis pipeline and
    /// logs the error. The legacy path is always preserved (= never
    /// removed) so existing public surface is 100% back-compatible.
    public func handle(userMessage: String, sessionId: String, model: String) async -> (reply: String, totalTokens: Int, thinking: String?) {
        // P0 #1: try the full ConversationLoop path first (when wired).
        if let connector = connector {
            if let loopResult = await runConversationLoopPath(
                userMessage: userMessage,
                sessionId: sessionId,
                model: model,
                connector: connector
            ) {
                return loopResult
            }
            // loopResult == nil means the loop threw — fall through to the
            // legacy pipeline (which itself has S4 graceful degradation).
        }

        // Legacy path (= v0.21 pipeline, preserved as the fallback).
        return await runLegacyConductorPipeline(
            userMessage: userMessage,
            sessionId: sessionId,
            model: model
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
        connector: any LLMConnector
    ) async -> (reply: String, totalTokens: Int, thinking: String?)? {
        // Step 1: write 1 conductor parent task to KanbanStore (= legacy
        // parity: same Kanban behaviour as the legacy path).
        if let task = try? await kanbanStore.add(title: "conductor: \(userMessage.prefix(50))", status: .running) {
            // Mark done after the loop attempt (= best-effort; matches
            // the legacy code path exactly).
            Task { [kanbanStore] in
                _ = try? await kanbanStore.transition(id: task.id, to: .done)
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
        do {
            let result = try await loop.runTurn(
                userMessage: userMessage,
                systemMessage: nil,
                conversationHistory: [],
                // P0 #2 (WIRE-AGENT-002): forward the conductor's
                // tool registry so ToolExecutor dispatches against
                // registered wenshu tools.
                tools: tools
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
            return (reply.isEmpty ? "(文枢暂时无法回复, 请稍后再试)" : reply, totalTokens, thinking)
        } catch {
            // S4 graceful degradation: never throw out of handle(). Log
            // so the wenshu-dev / boss sees the underlying error.
            NSLog("[wenshu.conductor] ConversationLoop.runTurn failed, falling back to legacy pipeline: %@", String(describing: error))
            return nil
        }
    }

    /// Legacy conductor pipeline (= v0.21 intent+sub-agent+synthesis).
    /// Preserved verbatim (= unchanged) as the fallback when
    /// ConversationLoop is not wired (= connector == nil) OR throws.
    private func runLegacyConductorPipeline(
        userMessage: String,
        sessionId: String,
        model: String
    ) async -> (reply: String, totalTokens: Int, thinking: String?) {
        // Step 1: write 1 conductor parent task to KanbanStore (kanban progress, not shown in ChatView)
        let conductorTask: KanbanTask?
        do {
            conductorTask = try await kanbanStore.add(title: "conductor: \(userMessage.prefix(50))", status: .running)
        } catch {
            conductorTask = nil
        }

        // v0.21 ticket 34: accumulate all LLM API real usage (intent classify + sub-agent LLM calls + synthesis)
        var totalTokens = 0

        // Step 2: call LLM intent classify, fallback on failure → 0 sub-agents, don't throw
        var selectedAgents: [String] = []
        // v0.22 ticket 001: prepend Wenshu agent identity (WenshuConductorIdentity.systemPrompt)
        // as system prompt. The send() method already injects the pollution-defense
        // systemPromptEnglishOnly as the first system segment; our identity follows.
        // v0.23 ticket 002: 5 sub-agent names instead of 5 module names.
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
            // v0.21 ticket 39: union decode WenshuLLMBlock (text / thinking / tool_use)
            let intentRaw = intentResponse.content.map(\.displayText).joined()
            if !intentRaw.isEmpty {
                selectedAgents = parseAgentList(intentRaw).filter { name in
                    SubAgentIdentity.Name(rawValue: name) != nil
                }
            }
            // v0.21 ticket 34: accumulate intent classify real token usage
            totalTokens += intentResponse.usage?.total_tokens ?? 0
        }
        // intent classify fail → selectedAgents still empty [] → S4 graceful degradation
        // v0.23 ticket 002: filter unknown agent names to prevent invalid dispatch
        selectedAgents = selectedAgents.filter { ["writer", "analyst", "researcher", "auditor", "memory"].contains($0) }
        // Step 3: dispatch 0-N sub-agents in parallel (TaskGroup) + collect results (v0.23 ticket 002)
        // v0.23 ticket 002: TaskGroup parallel dispatch replaces serial for-loop.
        // Each sub-agent has independent system prompt (SubAgentIdentity.systemPrompt).
        var subResults: [(String, String)] = []
        if !selectedAgents.isEmpty {
            // Build tasks (add to KanbanStore first, before TaskGroup, so all parallel tasks see the same state)
            var tasks: [(name: String, kanbanTaskId: String?)] = []
            for agentName in selectedAgents {
                let kTask = try? await kanbanStore.add(title: "\(agentName): \(userMessage.prefix(30))", status: .running)
                tasks.append((name: agentName, kanbanTaskId: kTask?.id))
            }
            // Run sub-agents in parallel
            subResults = await withTaskGroup(of: (String, String).self) { group in
                for (name, _) in tasks {
                    // v0.23 audit #014 fix (HIGH): pre-validate cast once, skip unknown.
                    // Was: 'SubAgentIdentity.Name(rawValue: name)!' — crash risk.
                    guard let identityName = SubAgentIdentity.Name(rawValue: name) else {
                        continue  // skip unknown sub-agent name
                    }
                    group.addTask { [self] in
                        // Each sub-agent gets its own system prompt + tools (v0.23 ticket 001)
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
            // v0.23 audit #014 fix: check cancellation before kanban write
            // (boss 8/23 risk-averse: don't write kanban state for cancelled runs).
            // Note: handle() doesn't throw, so guard with Task.isCancelled and
            // skip the kanban transitions if cancelled (loop body no-ops).
            let isCancelled = Task.isCancelled
            // Mark kanban tasks done (after collection)
            for (name, kanbanId) in tasks where !isCancelled {
                if let id = kanbanId {
                    _ = try? await kanbanStore.transition(id: id, to: .done)
                }
            }
            // v0.23 ticket 006: write 1-line sub-agent run summary to ChatSessionStore
            // (boss 8/23 said: user doesn't need execution details, just sees results — no full LLM dialogue stored).
            if let session = sessionStore {
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
                    _ = try? await session.recordSubAgentRun(run, sessionId: "default")
                }
            }
            // v0.23 ticket 002: Auditor runs if Writer or Analyst in selection.
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
        // v0.23 ticket 002: synthesis now includes auditor verdict if any.
        let synthesisPrompt = buildSynthesisPrompt(userMessage: userMessage, subResults: subResults)
        var finalThinking: String?    // v0.21 ticket 39: WenshuLLMBlock.thinking
        let finalReply: String
        // v0.22 ticket 001: prepend Wenshu agent identity for synthesis call.
        if let response = try? await verifier.chat(synthesisPrompt, system: WenshuConductorIdentity.systemPrompt, model: model) {
            // v0.21 ticket 39: union decode concat all text blocks (M2.7 has thinking block prefix)
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
            // v0.21 ticket 34: accumulate synthesis real token usage
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
            // v0.23 audit #014 fix: don't write kanban state if cancelled.
            if !Task.isCancelled {
                _ = try? await kanbanStore.transition(id: conductorTask.id, to: .done)
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
    public static let defaultToolNames: [String] = [
        "ParagraphAI",      // Core/Agent/Tool/ParagraphAITool.swift
        "ReadFile",         // Core/Agent/Tool/ReadFileTool.swift
        "WriteFile",        // Core/Agent/Tool/WriteFileTool.swift
        "av",               // Core/Tools/AVMediaTools.swift
        "book_manager",     // Core/Agent/Librarian/BookManagerTool.swift
        "file",             // Core/Tools/FileTools.swift
        "kanban",           // Core/Agent/Tool/KanbanStoreTool.swift
        "process",          // Core/Tools/ProcessTools.swift
        "todo",             // Core/Agent/Tool/TodoStoreTool.swift
        "todo_hermes",      // Core/Agent/Todo/HermesTodoTool.swift
        "vision",           // Core/Tools/VisionTools.swift
        "web"               // Core/Tools/WebTools.swift
    ]

    /// Maximum time `buildToolsSync(from:)` will wait for the
    /// detached async task (= 250 ms by default). Registrations are
    /// fire-and-forget `Task { await registry.register(...) }`
    /// blocks that run off the init thread (= the module-load
    /// pattern from MIGRATE-TOOLREGISTRY-002); a brief wait covers
    /// the scheduling jitter.
    public static let toolRegistryWaitTimeoutMs: UInt64 = 250

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
    public static func buildTools(from registry: ToolRegistry) async -> [String: any Tool] {
        // Step 1: brief warmup window. Registrations are fire-and-forget
        // `Task { await registry.register(...) }` blocks at module
        // load (= MIGRATE-TOOLREGISTRY-002); a short settle window
        // absorbs scheduling jitter. We do NOT wait for the full
        // expected count (= 12): in production, tool files are
        // imported eagerly so registrations complete in microseconds;
        // in tests, some tool files may not be linked into the test
        // binary, so polling for 12 would always time out and waste
        // 250 ms. A 50 ms warmup is the empirical sweet spot.
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
    public static let toolRegistryWarmupMs: UInt64 = 50

    /// Synchronous bridge to `buildTools(from:)` for callers that
    /// cannot await (= SwiftUI `View.init` is sync; the ChatView
    /// fallback-conductor construction site runs there).
    ///
    /// The bridge uses **two** strategies combined:
    /// 1. A static `cachedTools` dict populated on first call by a
    ///    detached task. Subsequent calls return the cached value
    ///    instantly. This is the common case (= ChatView.init
    ///    fires many times during a session; the cache is hit).
    /// 2. If the cache is empty (= very first call, OR the detached
    ///    task hasn't finished yet), a `DispatchSemaphore` blocks
    ///    the calling thread up to `toolRegistryWaitTimeoutMs` for
    ///    the detached task to finish.
    ///
    /// Registrations are `Task { await registry.register(...) }`
    /// on the cooperative pool (= not bound to the main actor), so
    /// the semaphore wait does NOT deadlock the main thread.
    ///
    /// Budget = `toolRegistryWaitTimeoutMs` (= 250 ms by default).
    /// On timeout the returned dict may be a partial subset of
    /// `defaultToolNames`; this matches the async-version behavior.
    /// ChatView's preview / fallback path tolerates a partial dict
    /// (= no ChatView code reads the dict synchronously during init;
    /// only the ConversationLoop / ToolExecutor consults it later).
    public static func buildToolsSync(from registry: ToolRegistry) -> [String: any Tool] {
        // Hot path: cache hit.
        if let cached = cachedTools {
            return cached
        }

        // Cold path: spawn the detached task, wait briefly for it,
        // and populate the cache before returning.
        let box = ResultBox()
        let semaphore = DispatchSemaphore(value: 0)
        Task.detached(priority: .userInitiated) {
            let result = await buildTools(from: registry)
            box.value = result
            // Publish to the static cache (= other callers see this
            // result on their next call).
            cachedTools = result
            semaphore.signal()
        }
        // Block until buildTools completes OR the budget expires.
        let waitResult = semaphore.wait(timeout: .now() + .milliseconds(Int(toolRegistryWaitTimeoutMs)))
        if waitResult == .timedOut {
            NSLog("[wenshu.conductor] buildToolsSync timed out after %d ms; returning empty dict (registrations may not be settled yet)", Int(toolRegistryWaitTimeoutMs))
            // Do NOT populate the cache on timeout (= the next call
            // will retry with a fresh wait).
            return [:]
        }
        return box.value
    }

    /// Process-wide cache of the last `buildTools` result. Populated
    /// by `buildToolsSync` (= also re-populated by any future
    /// async-aware caller that goes through the same singleton).
    /// nil = cold cache; the next `buildToolsSync` call will block
    /// briefly to warm it.
    private static nonisolated(unsafe) var cachedTools: [String: any Tool]?

    /// Tiny class-bound box used to hand the `[String: any Tool]`
    /// result from the detached async task back to the synchronous
    /// caller. `ObjectIdentifier` + `DispatchSemaphore` are the
    /// publication barrier; `value` is read only AFTER the matching
    /// `signal` (= happens-before established by the semaphore).
    private final class ResultBox: @unchecked Sendable {
        var value: [String: any Tool] = [:]
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
}