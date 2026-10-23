// WenshuConductor.swift
// … (= 33 rationale lines collapsed; = A112 docblock collapse per §1.8)
// 
import Foundation
import WenshuData
import os.log

private let wenshuLogger = Logger(subsystem: "com.wenshu", category: "wenshuconductor")

// See commit 49 (= ContextEngine deferred) for the full rationale.
// … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / Wenshu orchestrator (actor thread-safe, consistent with the data-layer repositories).
public actor WenshuConductor {
    // AUDIT.md §2.2 partial (2026-10-16 boss "把切换包的事
    // 清干净" arc): the `verifier: WenshuVerifier` field was
    // deleted; = the conductor routes every LLM call through
    // WenshuAgent.shared.chat() (= the public facade; = the
    // verifier bridge to WenshuAgent.shared is now indirect).
    // / Long-term memory persistence for agent (now SwiftData-backed via
    // … (= 11 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / ChatView call site keeps working.
    let repositories: WSRepositoryContainer
    // / P0 #1 (WIRE-AGENT-001): optional active connector profile. When non-nil,
    // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / App.swift follow-up.
    private let connector: (any LLMConnector)?
    // / P0 #1 (WIRE-AGENT-001): optional RuntimeHelpers instance for the
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / ConversationLoop creates a fresh actor instance.
    private let loopRuntime: RuntimeHelpers?
    /// The settings the last turn ran with.
    ///
    /// The seam between the settings screen and the turn is the
    /// `settingsProvider`; this records what that seam delivered, so a test
    /// can prove the user's value crossed it (= the screen writes a value
    /// and the turn receives THAT value, not the struct defaults).
    public private(set) var lastTurnSettings: AgentSettings?

    /// The settings the last turn ran with. For tests.
    public func turnSettingsForTesting() async -> AgentSettings {
        lastTurnSettings ?? AgentSettings()
    }

    // / P0 #2 (WIRE-AGENT-002): tool registry forwarded to
    // … (= 13 rationale lines collapsed, = A112 docblock collapse per §1.8)
    // / `registeredToolNames` accessor + the `wireBookScopeGuard` writer.
    public var tools: [String: any Tool]
    // / Turn-time tool source: the registry's live registrations, so a
    // / turn sees what the app registered after launch.
    private let toolProvider: (@Sendable () async -> [String: any Tool])?
    // / Turn-time settings source: the values the user chose in the
    // / settings screen, so a turn runs with the user's recovery policy
    // / and memory backend instead of the struct defaults.
    // / Nil = the defaults (= the behaviour before this was wired).
    private let settingsProvider: (@Sendable () async -> AgentSettings)?
    // AUDIT.md §2.9 partial (2026-10-16): the stream single-
    // writer fence (= hermes `stream_single_writer.py` port).
    // One per conductor instance (= the conductor is the
    // single chat surface; = different chat sessions get
    // different conductor instances via
    // `WenshuAppDelegate.sharedConductor` per session).
    private let streamWriterFence = WAStreamWriterFence()


    // / P0 #1 (WIRE-AGENT-001): new init that wires WenshuConductor.handle()
    // … (= 13 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / nil, `ConversationLoop` falls back to a fresh `RuntimeHelpers()` actor.
    public init(
        connector: (any LLMConnector)? = nil,
        loopRuntime: RuntimeHelpers? = nil,
        tools: [String: any Tool] = [:],
        toolProvider: (@Sendable () async -> [String: any Tool])? = nil,
        settingsProvider: (@Sendable () async -> AgentSettings)? = nil,
        repositories: WSRepositoryContainer? = nil
    ) {
        self.connector = connector
        self.loopRuntime = loopRuntime
        // P0 #2 (WIRE-AGENT-002): store the tool registry so the loop
        // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // every existing call site compiles unchanged.
        self.tools = tools
        self.toolProvider = toolProvider
        self.settingsProvider = settingsProvider
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


    // / handle: receive user message, dispatch sub-agents, synthesize final
    // … (= 24 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / `(reply, tokens, thinking)` tuple without the streaming side-effect.
    public func handle(
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

        // The settings for this turn (= the recovery policy and the memory
        // backend the user chose). Resolved once per turn, so a change in
        // the settings screen takes effect on the next turn.
        let turnSettings = await settingsProvider?() ?? AgentSettings()
        lastTurnSettings = turnSettings

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
            streamCallback: fencedCallback,
            settings: turnSettings
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
        streamCallback: (@Sendable (LLMBlock) async -> Void)?,
        // The settings for this turn (= the recovery policy and the memory
        // backend the user chose). Resolved by the caller, so a change in
        // the settings screen takes effect on the next turn.
        settings: AgentSettings
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
            // Resolve the registry's tools at turn time (= the app
            // registers them after launch, so a launch-time snapshot is
            // empty for the first turns). The book-scoped set wins: it
            // is bound to the currently selected book, while the
            // registry's instance is the generic one.
            let providerTools = await toolProvider?() ?? [:]
            let effectiveTools = tools.merging(providerTools) { scoped, _ in scoped }
            // The turn's session is bound around the turn, so a tool the
            // model calls learns which chat asked for it (= the tool
            // protocol carries only its input string).
            let result = try await TurnScope.withScope(sessionID: sessionId) {
                try await loop.runTurn(
                    userMessage: userMessage,
                    // Pass the agent-driver reminder as the systemMessage
                    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
                    // most attention to imperative instructions).
                    systemMessage: agentDriverReminder,
                    conversationHistory: [],
                    // P0 #2 (WIRE-AGENT-002): forward the conductor's
                    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
                    // registered wenshu tools.
                    tools: effectiveTools,
                    // The user's settings for this turn (= the recovery policy
                    // and the memory backend they chose). Without this the
                    // loop runs on AgentSettings() defaults, and every
                    // settings-screen control is a promise nothing keeps.
                    settings: settings,
                    // Forward streamCallback (= Hermes
                    // … (= 4 rationale lines collapsed, = A112 docblock collapse per §1.8)
                    // token-by-token). Legacy callers (= tests) pass nil.
                    streamCallback: streamCallback,
                    // P5-AGENT-STREAMING-VISIBILITY (2026-09-25): forward
                    // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
                    // did not register (= hermes get_definitions parity).
                    toolSchemas: await ToolRegistry.shared.getDefinitions(
                        toolNames: Set(effectiveTools.keys)
                    )
                )
            }
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
    public static func makeFencedCallback(
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
