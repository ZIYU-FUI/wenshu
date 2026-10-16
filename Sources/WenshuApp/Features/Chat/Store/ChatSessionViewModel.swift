// 
// … (= 37 rationale lines collapsed; = A112 docblock collapse per §1.8)
// 
import Foundation
import WenshuData
import os.log

// / reference-type accumulator for the streaming LLMBlock callback. Required
// … (= 15 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
    // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
    // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // and the draft is cleared. nil = no pending image.
    var attachedImagePath: String?
    var isSending: Bool = false
    var lastError: String?
    // 'check split, check dead code'.
    // … (= 8 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // retention (= keep cancelRequested):
    var cancelRequested: Bool = false
    // / T67-MUTE-SHORTCUT (2026-09-18): ⌘. handler (= cancel the
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / no-op when nothing is streaming.
    func cancelStreaming() {
        cancelRequested = true
    }

    // / CHATIMG-001 (2026-09-07): copy the picked file into the library's
    // … (= 13 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / LiveChatRepository.
    @discardableResult
    func attachImage(at sourceURL: URL) async -> Bool {
        // Config lookup (= business layer reads app config from
        // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
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

    /// CHATIMG-001: clear the pending image draft (= called when the user
    /// clicks the small ✕ on the preview chip, or after send).
    func clearAttachedImage() {
        attachedImagePath = nil
    }
    // wenshu.llm.model centralization. The model id was
    // … (= 10 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // when this is empty.
    private let appState: AppState?
    // Follow-up (= `ChatViewModelDefaultModelTests`):
    // … (= 8 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // now locks down).
    var currentModel: String {
        if let appState { return appState.llmModel }
        return UserDefaults.standard.string(forKey: "wenshu.llm.model") ?? ""
    }
    var availableModels: [String] = []
    var contextUsed: Int = 0
        // 'minimax m3 is not 1MB context window?
        // … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // to query per the 2026-08-25 'no API to fetch from, right?' = the user confirmed no API).
    var contextMax: Int = 1_000_000

    private let conductor: WenshuConductor?
    // Chat persistence lives in `WSChatRepository.shared` (= a
    // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // Mutable so the archive flow can replace the session id.
    @MainActor private var sessionId: SessionID

    // Current scope bookID for all persistence calls.
    // … (= 8 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // P2-02 audit (2026-09-24): BookID brand wrapper.
    @MainActor internal var currentBookID: BookID?

    // / Update the active scope (= called by the view layer when the user picks
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / session) and reloads history. No-op if the bookID is unchanged.
    func setCurrentBookID(_ bookID: BookID?) {
        if currentBookID == bookID { return }
        currentBookID = bookID
        // Per-book session id: same key prefix + bookID suffix so the
        // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // is what scopes reads, not the session id).
        sessionId = Self.makeSessionID(for: bookID)
        // Fire-and-forget reload against the new scope.
        Task { await self.loadHistory() }
    }

    // build fix: demote from `public init` to internal `init`.
    // … (= 12 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // this parameter to avoid touching SwiftData stack.
    init(
        conductor: WenshuConductor? = nil,
        sessionId: SessionID = SessionID(rawValue: "default"),
        initialMessages: [ChatMessage] = [],
        appState: AppState? = nil,
        repository: ChatRepositoryProtocol = LiveChatRepository.shared,
        bookID: BookID? = nil
    ) {
        self.conductor = conductor
        // Per-book session id when bookID is set
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // per-book session id keeps chat rows cleanly partitioned).
        self.sessionId = Self.makeSessionID(for: bookID, fallback: sessionId.rawValue)
        self.currentBookID = bookID
        self.messages = initialMessages
        // hold a strong reference to the AppState instance so
        // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // lifetime as the WindowGroup that owns it).
        self.appState = appState
        // C-4: data-layer seam. The protocol handles StoredChatMessage
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // ChatMessage only).
        self.repository = repository
    }

    // / Build a per-book session id. Returns `book:<id>:default` when scoped to
    // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / bookID always hit the same SwiftData row.
    static func makeSessionID(for bookID: BookID?, fallback: String = "default") -> SessionID {
        guard let bookID else { return SessionID(rawValue: fallback) }
        return SessionID(rawValue: "book:\(bookID.rawValue):\(fallback)")
    }

    /// C-4: the data-layer seam. Defaults to LiveChatRepository.shared at init
    /// (= production path); tests inject a fake.
    private let repository: ChatRepositoryProtocol

    // (2026-09-04): shared AsyncDelegationRegistry used by
    // … (= 23 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // methods require `await`.
    nonisolated static let delegationRegistry: AsyncDelegationRegistry = AsyncDelegationRegistry()

    func switchModel(_ id: String) {
        // write to the canonical owner (= AppState.llmModel),
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // UserDefaults call here (= single owner maintained).
        appState?.llmModel = id
    }

    // / UI layer must not call the data layer directly (= the canonical
    // … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / `ChatZoneView` (= UI layer) into the business layer.
    func openSettingsToProviderApi() {
        UserDefaultsStore.shared.setString("providerApi", forKey: .settingsTab)
    }

    func loadAvailableModels() async {
        // Use multi-provider discovery (= query all configured
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // `WenshuLLMModel.allCases` = 3 MiniMax-only cases).
        let configured = AvailableModelsDiscovery.loadFromKeychain()
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
        // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // counts as a closure).
        let totalContext = contextUsed
        let messageCount = messages.count
        Logger(subsystem: "com.wenshu.app", category: "chat.context")
            .info("[wenshu.context] sum tokens after recompute: total=\(totalContext, privacy: .public) messages=\(messageCount, privacy: .public)")
    }

    // / routeInput is the front-door for chat input. It dispatches `/plan
    // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / a stub skill-invoke result).
    func routeInput() async {
        let input = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }

        // T20c-PLAN-ROUTE (2026-09-18): intercept `/plan <query>` BEFORE
        // … (= 9 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // type change required for T20c).
        if let planQuery = stripPlanPrefix(input) {
            await runPlanMode(query: planQuery)
            return
        }

        // (2026-09-04): try @-mention subagent trigger
        // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // interprets it as a prompt template per ChatHubCommands.
        await send()
    }

    // MARK: - T20c-PLAN-ROUTE (2026-09-18): /plan command surface
    // … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / collision with future /plans commands)
    private func stripPlanPrefix(_ input: String) -> String? {
        guard input.hasPrefix("/plan") else { return nil }
        // Exact-match on "/plan" + whitespace (= no args means
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / user sees why the plan failed).
    private func runPlanMode(query: String) async {
        inputText = ""
        // Resolve connector + model from the active conductor
        // … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // for T20c.
        let model = self.currentModel
        let connector: any LLMConnector = AnthropicConnector()
        let engine = PlanModeEngine(connector: connector, model: model)
        do {
            let plan = try await engine.run(query: query)
            // T22-PLAN-PART (2026-09-18): surface the plan as a
            // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
        // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // business layer speaks ChatMessage only.
        do {
            try await repository.append(userMsg, sessionId: sessionId, bookID: currentBookID)
        } catch {
            Self.logSwallowedPersistenceFailure(operation: "append user message", error: error)
        }

        do {
            // streaming path = render each text chunk as it
            // … (= 10 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // owner maintained).
            let currentModel: String = self.currentModel
            // Per Apple HIG + 12 standard + Swift 6 strict-concurrency:
            // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // Logger interpolation (= Swift 6 closure-capture rule).
            let modelForLog = currentModel
            Logger(subsystem: "com.wenshu.app", category: "chat.model")
                .info("[wenshu.model] effective model: \(modelForLog, privacy: .public) (AppState source)")
            var reply: String
            var replyThinking: String?    // WenshuLLMBlock.thinking footnote UI
            var replyTokens: Int?
            if let conductor = conductor {
                // 
                // … (= 19 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // class reference IS thread-safe here).
                let accumulator = StreamingAccumulator()
                // 
                // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // message with an in-flight snapshot).
                let streamingTaskBox = StreamingTaskBox()
                let result = await conductor.handle(
                    userMessage: text,
                    sessionId: sessionId.rawValue,
                    model: currentModel,
                    streamCallback: { [weak self] block in
                        // T1-THINKING-VISIBLE (2026-09-18): log each
                        // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
                        // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
                        // accesses).
                        let kindTagForLog = kindTag
                        let modelForLog = currentModel
                        Logger(subsystem: "com.wenshu.app", category: "chat.conductor")
                            .info("[wenshu.conductor] PATH=stream BLOCK=\(kindTagForLog, privacy: .public) (model=\(modelForLog, privacy: .public)")
                        // dead marker-parsing block
                        // … (= 10 rationale lines collapsed; = A112 docblock collapse per §1.8)
                        // we can pass it across the actor boundary.
                        let blockCopy = block
                        // First, accumulate parts in the
                        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
                        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
                // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // the final sealed mutation below).
                for task in streamingTaskBox.tasks { await task.value }
                reply = result.reply
                replyThinking = result.thinking ?? accumulator.thinking
                replyTokens = result.totalTokens
                // Mark the conductor's bubble as
                // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // final message.
                if let idx = messages.firstIndex(where: { $0.id == placeholderId }) {
                    // Per Apple HIG + 12 standard + Swift 6 strict-concurrency:
                    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
                // Render each text chunk as
                // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // 5-10s wait for the full reply).
                let verifier = WenshuVerifier()
                let stream = verifier.streamChat(
                    text,
                    system: WenshuConductorIdentity.systemPrompt,
                    model: currentModel
                )
                var buffer = ""
                // 
                // … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // open .text part" strategy in `use-message-stream`).
                var streamingParts: [ChatMessagePart] = []
                var streamingThinking: String = ""
                for try await block in stream {
                    switch block {
                    case .text(let chunk):
                        buffer += chunk
                        // Append into the trailing .text
                        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
                        // Hermes `appendAssistantTextPart`.
                        if case .text(let last) = streamingParts.last?.kind {
                            streamingParts[streamingParts.count - 1] = .text(last + chunk)
                        } else {
                            streamingParts.append(.text(chunk))
                        }
                        // Render the accumulated buffer into the
                        // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
                        // streaming UI in ChatMessageView).
                        if let idx = messages.firstIndex(where: { $0.id == placeholderId }) {
                            messages[idx] = ChatMessage(
                                id: placeholderId,
                                role: .agent,
                                source: .wenshu,
                                content: buffer,
                                tokens: nil,
                                parts: streamingParts,
                                streamState: .streaming
                            )
                        }
                    case .thinking(let text, _):
                        streamingThinking += text
                        replyThinking = streamingThinking
                        // Append into the trailing .reasoning
                        // part (= Hermes `appendReasoningPart`).
                        if case .reasoning(let last) = streamingParts.last?.kind {
                            streamingParts[streamingParts.count - 1] = .reasoning(last + text)
                        } else {
                            streamingParts.append(.reasoning(text))
                        }
                        if let idx = messages.firstIndex(where: { $0.id == placeholderId }) {
                            messages[idx] = ChatMessage(
                                id: placeholderId,
                                role: .agent,
                                source: .wenshu,
                                content: buffer,
                                tokens: nil,
                                thinking: streamingThinking,
                                parts: streamingParts,
                                streamState: .streaming
                            )
                        }
                    case .toolUse(let id, let name, let input):
                        // `tool_use` events now
                        // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
                        // legacy `content` until P7 lands.
                        streamingParts.append(.toolUse(
                            id: ToolCallID(rawValue: id), name: name, args: input
                        ))
                        if let idx = messages.firstIndex(where: { $0.id == placeholderId }) {
                            messages[idx] = ChatMessage(
                                id: placeholderId,
                                role: .agent,
                                source: .wenshu,
                                content: buffer,
                                tokens: nil,
                                parts: streamingParts,
                                streamState: .streaming
                            )
                        }
                    case .unknown:
                        // `WenshuVerifier.streamChat`
                        // … (= 18 rationale lines collapsed; = A112 docblock collapse per §1.8)
                        // conductor path above).
                        break
                        }
                }
                // Mark the message as sealed (= the
                // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // shimmer / hide the activity timer.
                if let idx = messages.firstIndex(where: { $0.id == placeholderId }) {
                    messages[idx] = ChatMessage(
                        id: placeholderId,
                        role: .agent,
                        source: .wenshu,
                        content: buffer,
                        tokens: nil,
                        thinking: streamingThinking,
                        parts: streamingParts,
                        streamState: .sealed
                    )
                }
                reply = buffer
                if reply.isEmpty {
                    reply = "(no reply)"
                }
            }
            // If the placeholder wasn't updated by streaming (= the
            // blocking path), set it now (= single-replacement).
            if !messages.contains(where: { $0.id == placeholderId }) {
                messages.append(ChatMessage(id: placeholderId, role: .agent, source: .wenshu, content: reply))
            }
            // C-4: route the agent message through ChatRepositoryProtocol
            // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
            // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
            // route through UserFacingError.from (= single
            // … (= 14 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // slug, not the model id.
            let activeProvider = WenshuAppDelegateLLMHelpers.activeConnectorSlug()
            // also log the raw underlying error to the
            // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // the chat-layer catch ate the message).
            let rawDesc = String(describing: error)
            Logger(subsystem: "com.wenshu.app", category: "chat.persist")
                .error("[wenshu.chat.persist] operation=send_chat error=\(rawDesc, privacy: .public) provider=\(activeProvider, privacy: .public)")
            let userErr = UserFacingError.from(error, context: activeProvider)
            let errMsg = userErr.errorDescription ?? "未知错误。"
            if let idx = messages.firstIndex(where: { $0.id == placeholderId }) {
                messages[idx] = ChatMessage(id: placeholderId, role: .system, source: .system, content: errMsg)
            }
            lastError = errMsg
        }
        isSending = false
    }

    // / WIRE-AGENT-003 (2026-09-04): start a long-running goal via the
    // … (= 14 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / context'.
    func startNewSession() {
        // 1. Clear in-memory state (= visual reset).
        messages = []
        contextUsed = 0
        // 2. Generate new sessionId (= UUID-based).
        let newId = SessionID(rawValue: "s_" + UUID().uuidString.prefix(12).lowercased())
        sessionId = newId
        // 3. NSLog audit trail (= verify in Console.app).
        // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
    // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / global un-attached).
    func loadHistory() async {
        do {
            let loaded = try await repository.loadMessages(sessionId: sessionId, bookID: currentBookID)
            // "持久化的聊天记录, 重新渲染顺序有问题, 问答先后顺序混乱" (see OOB.md #2026-07-23)
            // … (= 13 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
            // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // empty-state placeholder).
        }
    }
}

// MARK: - Try-logging helper (= 12 standard P1-02 try?  scaffolding)
// … (= 9 rationale lines collapsed; = A112 docblock collapse per §1.8)
// across Core/Agent and Core/Tools.
extension ChatViewModel {
    fileprivate static let persistLogger = Logger(subsystem: "com.wenshu.app", category: "chat.persist")

    static func logSwallowedPersistenceFailure(operation: String, error: Error) {
        let errorString = String(describing: error)
        persistLogger.error("[wenshu.chat.persist] operation=\(operation, privacy: .public) dropped-error=\(errorString, privacy: .public)")
    }
}
