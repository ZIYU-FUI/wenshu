// 
// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
import Foundation
import WenshuData
import os.log

// / reference-type accumulator for the streaming LLMBlock callback. Required
// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
// / returned by `snapshotParts()` is safe to pass across actor boundaries.
final class StreamingTaskBox: @unchecked Sendable {
    var tasks: [Task<Void, Never>] = []
}

final class StreamingAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var _parts: [ChatMessagePart] = []
    private var _thinking: String = ""
    var parts: [ChatMessagePart] {
        get { lock.lock(); defer { lock.unlock() }; return _parts }
        set { lock.lock(); defer { lock.unlock() }; _parts = newValue }
    }
    var thinking: String {
        get { lock.lock(); defer { lock.unlock() }; return _thinking }
        set { lock.lock(); defer { lock.unlock() }; _thinking = newValue }
    }
    // / Take a thread-safe snapshot of `parts` (= returns a copy safe to pass
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / access at the message-replacement site).
    func snapshotParts() -> [ChatMessagePart] {
        lock.lock(); defer { lock.unlock() }
        return _parts
    }
    func snapshotThinking() -> String {
        lock.lock(); defer { lock.unlock() }
        return _thinking
    }
}

/// ChatViewModel: state management (Apple Observable + WSChatRepository + WenshuConductor)
@MainActor
@Observable
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var inputText: String = ""
    // CHATIMG-001 (2026-09-07): absolute path of an image the user
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // and the draft is cleared. nil = no pending image.
    var attachedImagePath: String?
    var isSending: Bool = false
    var lastError: String?
    // 'check split, check dead code'.
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // retention (= keep cancelRequested):
    var cancelRequested: Bool = false
    // / T67-MUTE-SHORTCUT (2026-09-18): ⌘. handler (= cancel the
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / no-op when nothing is streaming.
    func cancelStreaming() {
        cancelRequested = true
    }

    // / CHATIMG-001 (2026-09-07): copy the picked file into the library's
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / LiveChatRepository.
    @discardableResult
    func attachImage(at sourceURL: URL) async -> Bool {
        // Config lookup (= business layer reads app config from
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // lives in LiveChatRepository.
        guard let libraryPath = ActiveLibrary.path, !libraryPath.isEmpty else { return false }
        // Delegate the actual copy to the data layer.
        let destPath: String?
        do {
            destPath = try await repository.copyChatUpload(
                sourceURL: sourceURL,
                intoLibraryAt: libraryPath
            )
        } catch {
            Self.logSwallowedPersistenceFailure(operation: "copyChatUpload", error: error)
            return false
        }
        guard let destPath else { return false }
        attachedImagePath = destPath
        return true
    }

    // / CHATIMG-001: clear the pending image draft (= called when the user
    // / clicks the small ✕ on the preview chip, or after send).
    func clearAttachedImage() {
        attachedImagePath = nil
    }
    // wenshu.llm.model centralization. The model id was
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // when this is empty.
    private let appState: AppState?
    // Follow-up (= `ChatViewModelDefaultModelTests`):
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // now locks down).
    var currentModel: String {
        let raw = appState?.llmModel
            ?? UserDefaults.standard.string(forKey: "wenshu.llm.model")
            ?? ""
        // Per boss 2026-10-16 OOB "还是没有内容":
        // if the model selection is empty (= first
        // launch with no UserDefaults entry AND no
        // appState wiring; = the chat sends a POST
        // with `model: ""` to minimax, which
        // minimax rejects with HTTP 400 = the
        // verifier SSE stream emits 0 events =
        // the chat bubble stays empty), fall
        // back to the active provider's first
        // default model (= "MiniMax-M3" for
        // minimax-cn = the canonical "this is
        // the model the user configured" pick).
        if !raw.isEmpty { return raw }
        let activeSlug = WenshuAppDelegateLLMHelpers.activeConnectorSlug()
        let provider = Provider.by(slug: activeSlug)
        if let firstDefault = provider?.defaultModels.first, !firstDefault.isEmpty {
            return firstDefault
        }
        return "MiniMax-M3"
    }
    var availableModels: [String] = []
    var contextUsed: Int = 0
        // 'minimax m3 is not 1MB context window?
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // to query per the 2026-08-25 'no API to fetch from, right?' = the user confirmed no API).
    var contextMax: Int = 1_000_000

    private let conductor: WenshuConductor?
    // Chat persistence lives in `WSChatRepository.shared` (= a
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // Mutable so the archive flow can replace the session id.
    @MainActor private var sessionId: SessionID

    // Current scope bookID for all persistence calls.
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // P2-02 audit (2026-09-24): BookID brand wrapper.
    @MainActor internal var currentBookID: BookID?

    // / Update the active scope (= called by the view layer when the user picks
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / session) and reloads history. No-op if the bookID is unchanged.
    func setCurrentBookID(_ bookID: BookID?) {
        if currentBookID == bookID { return }
        currentBookID = bookID
        // Per-book session id: same key prefix + bookID suffix so the
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // is what scopes reads, not the session id).
        sessionId = Self.makeSessionID(for: bookID)
        // Fire-and-forget reload against the new scope.
        Task { await self.loadHistory() }
    }

    // build fix: demote from `public init` to internal `init`.
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // this parameter to avoid touching SwiftData stack.
    init(
        conductor: WenshuConductor? = nil,
        sessionId: SessionID = SessionID(rawValue: "default"),
        initialMessages: [ChatMessage] = [],
        appState: AppState? = nil,
        repository: ChatRepositoryProtocol = LiveChatRepository.shared,
        bookID: BookID? = nil
    ) {
        // AUDIT.md §2.2 partial (2026-10-16): the public
        // facade is the canonical source of truth for
        // the conductor; = if no conductor is injected,
        // resolve it from the facade (= same value as
        // `WenshuAppDelegate.sharedConductor` since the
        // static is now a 1-line forwarder to the
        // facade).
        self.conductor = conductor ?? WenshuAgent.shared.currentConductorSync()
        // Per-book session id when bookID is set
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // per-book session id keeps chat rows cleanly partitioned).
        self.sessionId = Self.makeSessionID(for: bookID, fallback: sessionId.rawValue)
        self.currentBookID = bookID
        self.messages = initialMessages
        // hold a strong reference to the AppState instance so
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // lifetime as the WindowGroup that owns it).
        self.appState = appState
        // C-4: data-layer seam. The protocol handles StoredChatMessage
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // ChatMessage only).
        self.repository = repository
    }

    // / Build a per-book session id. Returns `book:<id>:default` when scoped to
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / bookID always hit the same SwiftData row.
    static func makeSessionID(for bookID: BookID?, fallback: String = "default") -> SessionID {
        guard let bookID else { return SessionID(rawValue: fallback) }
        return SessionID(rawValue: "book:\(bookID.rawValue):\(fallback)")
    }

    // / C-4: the data-layer seam. Defaults to LiveChatRepository.shared at init
    // / (= production path); tests inject a fake.
    private let repository: ChatRepositoryProtocol

    // (2026-09-04): shared AsyncDelegationRegistry used by
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // methods require `await`.
    nonisolated static let delegationRegistry: AsyncDelegationRegistry = AsyncDelegationRegistry()

    func switchModel(_ id: String) {
        // write to the canonical owner (= AppState.llmModel),
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // UserDefaults call here (= single owner maintained).
        appState?.llmModel = id
    }

    // / UI layer must not call the data layer directly (= the canonical
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / `ChatZoneView` (= UI layer) into the business layer.
    func openSettingsToProviderApi() {
        UserDefaultsStore.shared.setString("providerApi", forKey: .settingsTab)
    }

    func loadAvailableModels() async {
        // Use multi-provider discovery (= query all configured
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // `WenshuLLMModel.allCases` = 3 MiniMax-only cases).
        //
        // Per boss 2026-10-16 OOB "配好 KEY 后, 模型设置
        // 中的可选模型, 也应该通过 API 查询. 同样不
        // 能写死": use the live `loadLive()` (= calls
        // `LLMModelDiscovery.discover` for each
        // configured provider, which hits the
        // provider's `/models` endpoint and falls
        // back to `Provider.defaultModels` when the
        // endpoint is unreachable).
        let configured = await AvailableModelsDiscovery.loadLive()
        var modelIds: [String] = []
        for section in configured {
            for modelId in section.models {
                // Prefix with provider slug for clarity (e.g. "anthropic / claude-3.7-sonnet").
                modelIds.append(modelId)
            }
        }
        if modelIds.isEmpty {
            // No provider keys configured. Fall back to MiniMax hardcoded
            // list (current WenshuLLMModel scope per the 2026-08-21 spec).
            modelIds = WenshuLLMModel.allCases.map { $0.rawValue }
        }
        availableModels = modelIds
        if !availableModels.contains(currentModel) {
            availableModels = [currentModel] + availableModels
        }
        recomputeContextUsed()
    }

    /// recomputeContextUsed: sum of all agent message tokens (real LLM API usage, replaces chars/4 heuristic)
    func recomputeContextUsed() {
        contextUsed = messages.compactMap { $0.tokens }.reduce(0, +)
        // trace: ChatViewModel.contextUsed accumulation
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // counts as a closure).
        let totalContext = contextUsed
        let messageCount = messages.count
        Logger(subsystem: "com.wenshu.app", category: "chat.context")
            .info("[wenshu.context] sum tokens after recompute: total=\(totalContext, privacy: .public) messages=\(messageCount, privacy: .public)")
    }

    // / routeInput is the front-door for chat input. It dispatches `/plan
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / a stub skill-invoke result).
    func routeInput() async {
        let input = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }

        // T20c-PLAN-ROUTE (2026-09-18): intercept `/plan <query>` BEFORE
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // type change required for T20c).
        if let planQuery = stripPlanPrefix(input) {
            await runPlanMode(query: planQuery)
            return
        }

        // (2026-09-04): try @-mention subagent trigger
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // preserved in the chat log).
        let mentions = SubAgentMentionParser.parseAll(input)
        if !mentions.isEmpty {
            for mention in mentions {
                do {
                    let result = try await delegate(
                        subagentProfile: mention.subagentSlug,
                        task: mention.task,
                        context: [:],
                        registry: ChatViewModel.delegationRegistry
                    )
                    let shortId = String(result.handle.id.prefix(8))
                    messages.append(ChatMessage(
                        role: .system,
                        source: .system,
                        content: "Sub-agent @\(mention.subagentSlug) → handle \(shortId)"
                    ))
                } catch {
                    messages.append(ChatMessage(
                        role: .system,
                        source: .system,
                        content: "Failed to spawn @\(mention.subagentSlug): \(error)"
                    ))
                }
            }
            inputText = ""
            return
        }

        // No slash match → existing LLM send path. The slash prefix
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // interprets it as a prompt template per ChatHubCommands.
        await send()
    }

    // MARK: - T20c-PLAN-ROUTE (2026-09-18): /plan command surface
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / collision with future /plans commands)
    private func stripPlanPrefix(_ input: String) -> String? {
        guard input.hasPrefix("/plan") else { return nil }
        // Exact-match on "/plan" + whitespace (= no args means
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // the LLM verbatim as a slash command per ChatHubCommands).
        let afterPrefix = input.dropFirst("/plan".count)
        // Either whitespace (= normal command) or end-of-string
        // (= no args) is allowed.
        if afterPrefix.isEmpty {
            return nil
        }
        // First character must be whitespace (= prevents /plans
        // from matching /plan as a prefix).
        guard afterPrefix.first == " " else { return nil }
        let trimmed = afterPrefix.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }

    // / Run plan mode for the given query: invoke PlanModeEngine (= wraps the
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / user sees why the plan failed).
    private func runPlanMode(query: String) async {
        inputText = ""
        // Resolve connector + model from the active conductor
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // for T20c.
        let model = self.currentModel
        // AUDIT.md §2.2 partial (2026-10-16 boss "只做把之前的
        // 调用方式改成调用包" arc): resolve the active
        // connector through the public facade.
        let connector: any LLMConnector = WenshuAgent.shared.activeLLMConnector()
        let engine = PlanModeEngine(connector: connector, model: model)
        do {
            let plan = try await engine.run(query: query)
            // T22-PLAN-PART (2026-09-18): surface the plan as a
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // future ticket = T22b).
            messages.append(ChatMessage(
                role: .system,
                source: .system,
                content: plan.query,
                parts: [ChatMessagePart.plan(plan)]
            ))
        } catch let error as PlanModeError {
            messages.append(ChatMessage(
                role: .system,
                source: .system,
                content: error.errorDescription
                    ?? String(localized: "chatview.plan.failed")
            ))
        } catch {
            messages.append(ChatMessage(
                role: .system,
                source: .system,
                content: String(localized: "chatview.plan.failed")
                    + ": \(error.localizedDescription)"
            ))
        }
    }

    /// send: send message → Wenshu main agent synthesis
    func send() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        // CHATIMG-001 (2026-09-07): allow image-only sends (= an
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // the image atomically.
        let imagePath = attachedImagePath
        attachedImagePath = nil
        guard !text.isEmpty || imagePath != nil, !isSending else { return }
        let userMsg = ChatMessage(role: .user, source: .user, content: text, imagePath: imagePath)
        messages.append(userMsg)
        inputText = ""
        isSending = true

        // append AI placeholder message (name + avatar + "AI thinking..." in list immediately)
        let placeholderId = UUID()
        let placeholder = ChatMessage(id: placeholderId, role: .agent, source: .wenshu, content: "AI 思考中…", isPlaceholder: true)
        messages.append(placeholder)

        // C-4: route through ChatRepositoryProtocol (= the data-layer
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // business layer speaks ChatMessage only.
        do {
            try await repository.append(userMsg, sessionId: sessionId, bookID: currentBookID)
        } catch {
            Self.logSwallowedPersistenceFailure(operation: "append user message", error: error)
        }

        do {
            try Task.checkCancellation()
            // streaming path = render each text chunk as it
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // owner maintained).
            let currentModel: String = self.currentModel
            // Per Apple HIG + 12 standard + Swift 6 strict-concurrency:
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // Logger interpolation (= Swift 6 closure-capture rule).
            let modelForLog = currentModel
            Logger(subsystem: "com.wenshu.app", category: "chat.model")
                .info("[wenshu.model] effective model: \(modelForLog, privacy: .public) (AppState source)")
            var reply: String
            var replyThinking: String?    // WenshuLLMBlock.thinking footnote UI
            var replyTokens: Int?
            if let conductor = conductor {
                // 
                // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                // class reference IS thread-safe here).
                let accumulator = StreamingAccumulator()
                // 
                // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                // message with an in-flight snapshot).
                let streamingTaskBox = StreamingTaskBox()
                let result = await conductor.handle(
                    userMessage: text,
                    sessionId: sessionId.rawValue,
                    model: currentModel,
                    streamCallback: { [weak self] block in
                        // T1-THINKING-VISIBLE (2026-09-18): log each
                        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                        // PATH=... so it grep-parity with T0 logs.
                        let kindTag: String = {
                            switch block {
                            case .text: return "text"
                            case .thinking: return "thinking"
                            case .toolUse: return "toolUse"
                            case .toolResult: return "toolResult"
                            }
                        }()
                        // Per Apple HIG + 12 standard + Swift 6 strict-concurrency:
                        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                        // accesses).
                        let kindTagForLog = kindTag
                        let modelForLog = currentModel
                        Logger(subsystem: "com.wenshu.app", category: "chat.conductor")
                            .info("[wenshu.conductor] PATH=stream BLOCK=\(kindTagForLog, privacy: .public) (model=\(modelForLog, privacy: .public)")
                        // dead marker-parsing block
                        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                        // we can pass it across the actor boundary.
                        let blockCopy = block
                        // First, accumulate parts in the
                        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                        // isolation needed for the mutation).
                        switch blockCopy {
                        case .text(let chunk):
                            if case .text(let last) = accumulator.parts.last?.kind {
                                accumulator.parts[accumulator.parts.count - 1] = .text(last + chunk)
                            } else {
                                accumulator.parts.append(.text(chunk))
                            }
                        case .thinking(let t, _):
                            if case .reasoning(let last) = accumulator.parts.last?.kind {
                                accumulator.parts[accumulator.parts.count - 1] = .reasoning(last + t)
                            } else {
                                accumulator.parts.append(.reasoning(t))
                            }
                            accumulator.thinking += t
                        case .toolUse(let id, let name, let input):
                            accumulator.parts.append(.toolUse(id: ToolCallID(rawValue: id), name: name, args: input))
                        case .toolResult(let toolUseID, let output):
                            accumulator.parts.append(.toolResult(
                                toolUseID: ToolCallID(rawValue: toolUseID), content: output, isError: false
                            ))
                        }
                        // Then dispatch the messages mutation to
                        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                        // @MainActor-isolated).
                        streamingTaskBox.tasks.append(Task { @MainActor [weak self] in
                            guard let self else { return }
                            if let idx = self.messages.firstIndex(where: { $0.id == placeholderId }) {
                                self.messages[idx] = ChatMessage(
                                    id: placeholderId,
                                    role: .agent,
                                    source: .wenshu,
                                    content: ChatMessagePart.joinedText(accumulator.parts),
                                    tokens: nil,
                                    thinking: accumulator.thinking,
                                    parts: accumulator.parts,
                                    streamState: .streaming
                                )
                            }
                        })
                    }
                )
                // Wait for all in-flight streaming-update Tasks to complete
                // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                // the final sealed mutation below).
                for task in streamingTaskBox.tasks { await task.value }
                reply = result.reply
                replyThinking = result.thinking ?? accumulator.thinking
                replyTokens = result.totalTokens
                // Mark the conductor's bubble as
                // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                // final message.
                if let idx = messages.firstIndex(where: { $0.id == placeholderId }) {
                    // Per Apple HIG + 12 standard + Swift 6 strict-concurrency:
                    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                    // unavailable). Local captures avoid closure-capture complaint.
                    let placeholderIDString = placeholderId.uuidString
                    let messageCount = messages.count
                    Logger(subsystem: "com.wenshu.app", category: "chat.scroll")
                        .info("[wenshu.scroll] conductor placeholder replace: id=\(placeholderIDString, privacy: .public) beforeCount=\(messageCount, privacy: .public) afterCount=\(messageCount, privacy: .public)")
                    messages[idx] = ChatMessage(
                        id: placeholderId,
                        role: .agent,
                        source: .wenshu,
                        content: reply,
                        tokens: replyTokens,
                        thinking: replyThinking,
                        parts: accumulator.parts,
                        streamState: .sealed
                    )
                }
            } else {
                // AGENT-LOOP (boss 2026-10-16 OOB "agent 没有达到 agent
                // 的标准"): the conductor is now ALWAYS wired with the
                // active connector (= commit 7de86fc08 = WenshuAppDelegate
                // + ChatView both pass `WenshuAppDelegateLLMHelpers.
                // activeLLMConnector()` at construction time). The
                // old `WenshuVerifier.streamChat` fallback (= the
                // "small liar" path that returned a single LLM reply
                // with no tool dispatch) is unreachable in production.
                // If we ever land here (= conductor is nil), the
                // agent is not configured at all. Surface the failure
                // plainly instead of silently running the no-ReAct
                // fallback. (= the WenshuLLMBlock / WenshuLLMError
                // types remain on disk for the legacy pipeline in
                // WenshuConductorLegacyPipeline; the streaming method
                // is gone.)
                reply = "（agent 未配置, 请检查 WenshuAppDelegate 是否注入了 connector）"
                let msgPrefixForLog = String(text.prefix(40))
                Logger(subsystem: "com.wenshu.app", category: "chat.conductor")
                    .error("[wenshu.conductor] PATH=missing-conductor REASON=conductor_was_nil msg_prefix=\(msgPrefixForLog, privacy: .public)")
            }
            // If the placeholder wasn't updated by streaming (= the
            // blocking path), set it now (= single-replacement).
            if !messages.contains(where: { $0.id == placeholderId }) {
                messages.append(ChatMessage(id: placeholderId, role: .agent, source: .wenshu, content: reply))
            }
            // C-4: route the agent message through ChatRepositoryProtocol
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // empty-thinking-nil-collapse logic).
            let agentMsg = ChatMessage(
                id: placeholderId,
                role: .agent,
                source: .wenshu,
                content: reply,
                timestamp: Date(),
                tokens: replyTokens,
                thinking: replyThinking?.isEmpty == false ? replyThinking : nil
            )
            do {
                try await repository.append(agentMsg, sessionId: sessionId, bookID: currentBookID)
            } catch {
                Self.logSwallowedPersistenceFailure(operation: "append agent message", error: error)
            }
            recomputeContextUsed()

            // trigger summary generation (LLM + saveSummary + deleteOldMessages order)
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // pattern that lost errors silently).
            let verifier = WenshuVerifier()
            do {
                try await repository.summarizeIfNeeded(
                    sessionId: sessionId,
                    lastN: 10,
                    threshold: 20,
                    verifier: verifier,
                    bookID: currentBookID
                )
            } catch {
                Self.logSwallowedPersistenceFailure(operation: "summarizeIfNeeded", error: error)
            }
        } catch {
            // Per boss 2026-10-19 OOB "macbook 上聊天一直思考
            // 中, 看不到实际错误": the chat layer no longer
            // collapses every error to the single `modelConfigInvalid`
            // line. The granular `UserFacingError.from` mapping
            // (= network, key, rate-limit, etc.) is now the user-
            // visible message so the user (= the boss + power
            // users) can tell whether the failure is a 401 (key
            // missing / wrong) vs a transport timeout (network /
            // proxy) vs a 5xx (server) vs a malformed body
            // (response shape). The previous single-line collapse
            // hid the real cause (= boss reported "AI 思考中
            // 29.4s" with no further detail; = impossible to
            // distinguish key from network).
            let activeProvider = WenshuAppDelegateLLMHelpers.activeConnectorSlug()
            let rawDesc = String(describing: error)
            Logger(subsystem: "com.wenshu.app", category: "chat.persist")
                .error("[wenshu.chat.persist] operation=send_chat error=\(rawDesc, privacy: .public) provider=\(activeProvider, privacy: .public)")
            // Use the granular classifier (= surfaces the real
            // underlying message body, not the generic
            // "模型配置有误" line). Falls back to the raw
            // underlying description when no classifier matches
            // (= matches the previous behavior for unknown error
            // shapes).
            let userErr = UserFacingError.from(error)
            let errMsg: String
            switch userErr {
            case .modelConfigInvalid:
                errMsg = userErr.errorDescription ?? "模型配置有误"
            default:
                let granular = userErr.errorDescription ?? rawDesc
                errMsg = "[\(activeProvider)] \(granular)"
            }
            lastError = errMsg
            if let idx = messages.firstIndex(where: { $0.id == placeholderId }) {
                messages[idx] = ChatMessage(id: placeholderId, role: .system, source: .system, content: errMsg)
            }
        }
        isSending = false
    }

    // / WIRE-AGENT-003 (2026-09-04): start a long-running goal via the
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / context'.
    func startNewSession() {
        // 1. Clear in-memory state (= visual reset).
        messages = []
        contextUsed = 0
        // 2. Generate new sessionId (= UUID-based).
        let newId = SessionID(rawValue: "s_" + UUID().uuidString.prefix(12).lowercased())
        sessionId = newId
        // 3. NSLog audit trail (= verify in Console.app).
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // = use Logger instead per Apple's modern logging guidance).
        let logger = Logger(subsystem: "com.wenshu.app", category: "chat")
        let sessionIdRaw = sessionId.rawValue
        let messageCount = messages.count
        let contextUsedLocal = contextUsed
        logger.info("[wenshu.chat] startNewSession: id=\(sessionIdRaw, privacy: .public) messages=\(messageCount, privacy: .public) contextUsed=\(contextUsedLocal, privacy: .public)")
    }

    func clear() {
        messages.removeAll()
        lastError = nil
    }

    /// valueForSessionId: used by ChatView .task to load history.
    func valueForSessionId() -> SessionID { sessionId }  // @MainActor-isolated helper

    /// replaceMessages: ChatView .task loadcompletereplace (append)
    func replaceMessages(_ newMessages: [ChatMessage]) {
        self.messages = newMessages
    }

    // / C-5: load chat history from the data layer (= formerly lived inline in
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / global un-attached).
    func loadHistory() async {
        // / Per boss 2026-10-16 OOB "如果没配 key, 就只显示空态,
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // / chat history (= call sites in `ChatView.task` also
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // / when no key is configured = the persisted rows are not
        // / surfaced behind the empty-state overlay. This is the
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // / ephemeral when the provider is not configured.
        // AUDIT.md §2.2 partial (2026-10-16): route through
        // WenshuAgent.shared (= the public facade; =
        // the 14 callers migration enabler; = commit
        // `a0b371b45` added `providersWithKeys()`; =
        // commit `fd5baaee6` added the conductor
        // lifecycle).
        if await WenshuAgent.shared.providersWithKeys().isEmpty {
            self.messages = []
            return
        }
        do {
            let loaded = try await repository.loadMessages(sessionId: sessionId, bookID: currentBookID)
            // "持久化的聊天记录, 重新渲染顺序有问题, 问答先后顺序混乱" (see OOB.md #2026-07-23)
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // timestamp (= <1 ms apart on fast hardware).
            let sorted = loaded.sorted { a, b in
                if a.timestamp != b.timestamp {
                    return a.timestamp < b.timestamp
                }
                return a.id.uuidString < b.id.uuidString
            }
            self.messages = sorted
        } catch {
            // Silent no-op (= matches legacy behavior; = the view
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // empty-state placeholder).
        }
    }
}

// MARK: - Try-logging helper (= 12 standard P1-02 try?  scaffolding)
// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
// across Core/Agent and Core/Tools.
extension ChatViewModel {
    fileprivate static let persistLogger = Logger(subsystem: "com.wenshu.app", category: "chat.persist")

    static func logSwallowedPersistenceFailure(operation: String, error: Error) {
        let errorString = String(describing: error)
        persistLogger.error("[wenshu.chat.persist] operation=\(operation, privacy: .public) dropped-error=\(errorString, privacy: .public)")
    }
}
