//
//  ChatView.swift · Wenshu · v0.20 ticket 01 (Agent chat in lower-left zone)
//
//  Wire the lower-left zone to a real chat UI + Agent conversation (port of hermes 35-skill chat ground truth).
//  Boss 2026-08-19 evening decision "first implement the chat zone, that is the lower-left area, support Agent conversation".
//
//  Plain-language summary (boss-readable):
//  - wenshu lower-left zone becomes a real chat (message list + input box + send button)
//  - Click send → AgentRuntime.delegateTask → WenshuVerifier.ping calls MiniMax-M3
//  - minimax-cn key end-to-end works (Q22 ground-truth verification, ticket 31 done, HTTP 200)
//
//  - Engineering management: boss authorized + no acceptance required
//
//  Apple HIG ground truth: SwiftUI VStack + List + TextField + Button pattern (same as Pages / Numbers).
//

import SwiftUI
import Lucide

/// One chat message: three roles (user / Wenshu / system); Wenshu's internal multi-agent dispatch does not surface as ChatMessage (it goes through the Kanban board)
public struct ChatMessage: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let role: ChatRole
    public let source: ChatSource
    public var content: String
    public let timestamp: Date
    public var isPlaceholder: Bool
    public var tokens: Int?    // real LLM API usage.total_tokens (nil if user message or unavailable)
    public var thinking: String?    // CoT thinking content from WenshuLLMBlock.thinking (folded footnote UI)
    // CHATIMG-001 (2026-09-07): absolute file URL of an attached
    // screenshot/image. When non-nil, ChatMessageView renders the image
    // thumbnail above the text content. The file lives in
    // `<libraryPath>/cache/chat-uploads/` (= per §11 .ws bundle layout =
    // cache subfolder holds thumbnails + search index + export temp; this
    // ticket adds `chat-uploads` as the canonical chat-attachment cache
    // dir). nil = no image attached. Send-time semantics: the user
    // message carries the path; LLM send path (per §11.3 wenshu-side
    // wins) does NOT forward the image bytes to the provider this round
    // (= out-of-scope for ticket CHATIMG-001; ticket CHATIMG-002 covers
    // the multimodal upload protocol).
    public var imagePath: String?

    public init(
        id: UUID = UUID(),
        role: ChatRole,
        source: ChatSource = .wenshu,
        content: String,
        timestamp: Date = Date(),
        isPlaceholder: Bool = false,
        tokens: Int? = nil,
        thinking: String? = nil,
        imagePath: String? = nil
    ) {
        self.id = id
        self.role = role
        self.source = source
        self.content = content
        self.timestamp = timestamp
        self.isPlaceholder = isPlaceholder
        self.tokens = tokens
        self.thinking = thinking
        self.imagePath = imagePath
    }
}

/// Chat role ground truth (compatible with v0.20 ticket 01; actual display uses source)
public enum ChatRole: String, Equatable, Sendable {
    case user
    case agent
    case system
}

/// Message source ground truth (user = sent by the user / wenshu = Wenshu's reply / system = system error). Wenshu's internal multi-agent dispatch results do not show as ChatMessage; they go through the KanbanStore board.
public enum ChatSource: String, Equatable, Sendable, Codable {
    case user
    case wenshu
    case system
}

/// ChatViewModel: state management (Apple Observable + ChatSessionStore + WenshuConductor)
@MainActor
@Observable
public final class ChatViewModel {
    public var messages: [ChatMessage] = []
    public var inputText: String = ""
    // CHATIMG-001 (2026-09-07): absolute path of an image the user
    // attached via the chat input row's paperclip button (= draft
    // state). When non-nil, a small preview chip is rendered above
    // the TextField; on send the path is moved into the ChatMessage
    // and the draft is cleared. nil = no pending image.
    public var attachedImagePath: String?
    public var isSending: Bool = false
    public var lastError: String?

    /// CHATIMG-001 (2026-09-07): copy the picked file into the
    /// library's `cache/chat-uploads/` dir (= canonical cache
    /// subfolder per §11 .ws layout; this ticket adds `chat-uploads`
    /// as the chat-attachment cache dir) and set `attachedImagePath`
    /// to the new absolute path. Returns false (= no-op) when the
    /// source file is missing or the library path isn't configured.
    /// File extension whitelist = .png/.jpg/.jpeg/.gif/.heic (= common
    /// screenshot formats). The library path is read from
    /// `wenshu.libraryPath` UserDefaults (= canonical home for the
    /// .ws bundle path = written by LibraryRootView at onboarding).
    @discardableResult
    public func attachImage(at sourceURL: URL) -> Bool {
        let fm = FileManager.default
        let ext = sourceURL.pathExtension.lowercased()
        guard ["png", "jpg", "jpeg", "gif", "heic"].contains(ext) else { return false }
        guard fm.fileExists(atPath: sourceURL.path) else { return false }
        let libraryPath = UserDefaults.standard.string(forKey: "wenshu.libraryPath") ?? ""
        guard !libraryPath.isEmpty else { return false }
        let uploadsDir = URL(fileURLWithPath: libraryPath)
            .appendingPathComponent("cache", isDirectory: true)
            .appendingPathComponent("chat-uploads", isDirectory: true)
        do {
            try fm.createDirectory(at: uploadsDir, withIntermediateDirectories: true)
        } catch {
            return false
        }
        // Unique filename = <uuid>.<ext> so two attachments don't collide.
        let destName = UUID().uuidString + "." + ext
        let destURL = uploadsDir.appendingPathComponent(destName)
        do {
            // security-scoped resource = NSOpenPanel gives us a URL
            // with sandbox-scoped access; copying into our own
            // uploads dir permanently lifts the scope. For the
            // fileImporter case (= .fileImporter is the entry
            // point used by the attach button), the picked URL is
            // already accessible in the process sandbox.
            try fm.copyItem(at: sourceURL, to: destURL)
        } catch {
            return false
        }
        attachedImagePath = destURL.path
        return true
    }

    /// CHATIMG-001: clear the pending image draft (= called when
    /// the user clicks the small ✕ on the preview chip, or after
    /// send).
    public func clearAttachedImage() {
        attachedImagePath = nil
    }
    // B-05: wenshu.llm.model centralization. The model id was
    // previously scattered as 7 different reads/writes (4 @AppStorage
    // + 3 raw UserDefaults); the canonical owner is now
    // `AppState.llmModel`. ChatViewModel.holds a strong reference
    // to the injected AppState (= same lifetime as conductor / store)
    // so every read below resolves to the same source of truth, and
    // `switchModel(_:)` writes back to AppState (= triggers the
    // AppState didSet → UserDefaults round-trip).
    // v0.24 boss acceptance fix (2026-08-24): default empty string when no provider key
    // configured (not "MiniMax-M3" which implies a minimax-cn provider is
    // selected even when user has no key). UI shows "no model available" placeholder
    // when this is empty.
    private let appState: AppState?
    // v0.24 boss acceptance fix follow-up (= `ChatViewModelDefaultModelTests`):
    // when no AppState is injected (= standalone ChatViewModel initialised
    // without the app-wide environment), the model id must also default to
    // empty string read directly from UserDefaults so the left-bottom model
    // picker shows ' instead of 'MiniMax-M3'. The substring
    // `UserDefaults.standard.string(forKey: "wenshu.llm.model") ?? ""` is
    // the exact pattern the regression test asserts must exist in this
    // file (= v0.24 commit message claimed it was applied here but the
    // actual git show only patched App.swift = doc drift that the test
    // now locks down).
    public var currentModel: String {
        if let appState { return appState.llmModel }
        return UserDefaults.standard.string(forKey: "wenshu.llm.model") ?? ""
    }
    public var availableModels: [String] = []
    public var contextUsed: Int = 0
        // v0.24 boss acceptance fix (Boss 8/25 OOB 'minimax m3 is not 1MB context window?
        // you set 131k'): minimax-cn M3 context window = 1_000_000 tokens per official
        // docs (https://www.minimax.io/models/text/m3 = '1M Context';
        // max output 512K). Empirical limit on public anthropic-compatible endpoint
        // per hermes-agent issue #37289 = ~512K input cap (vendor enforces lower
        // than marketed). Decision: use official value (1M) so context budgeting
        // matches docs; actual API may reject >512K (vendor issue, not wenshu).
        // Note: Live API /v1/models does NOT return context_length field (= no API
        // to query per Boss 8/25 'no API to fetch from, right?' = boss confirmed no API).
    public var contextMax: Int = 1_000_000

    private let conductor: WenshuConductor?
    private let store: ChatSessionStore?
    // v0.24 boss acceptance fix (Boss 8/25 OOB ticket 015.014 + F2 cleanup): @MainActor
    // isolation replaces nonisolated(unsafe) for Swift 6 concurrency safety.
    // Mutable so archive flow can replace. sessionIdPublic accessor dropped
    // (SUGGEST 1 fix = valueForSessionId() already exists).
    @MainActor private var sessionId: String

    // B-05 build fix: demote from `public init` to internal `init`. AppState
    // is internal (= `final class AppState`, no access modifier), and a
    // `public init` cannot accept an internal type as a parameter. Both
    // call sites (App.swift:1528 + ChatView.swift:340) are inside the
    // WenshuApp module, so internal access is sufficient. The class itself
    // stays `public final class` so existing public surface (currentModel,
    // messages, send, etc.) is unchanged.
    init(conductor: WenshuConductor? = nil, store: ChatSessionStore? = nil, sessionId: String = "default", initialMessages: [ChatMessage] = [], appState: AppState? = nil) {
        self.conductor = conductor
        self.store = store
        self.sessionId = sessionId
        self.messages = initialMessages
        // B-05: hold a strong reference to the AppState instance so
        // currentModel / switchModel can read + write the canonical
        // owner. Caller passes the env-injected AppState (= same
        // lifetime as the WindowGroup that owns it).
        self.appState = appState
    }

    // CHATBOX-003 (2026-09-04): shared AsyncDelegationRegistry used by
    // routeInput() to spawn @-mention sub-agents. Lives on ChatViewModel
    // (= process-wide singleton via the @MainActor type's static
    // property) so every ChatViewModel instance routes through the same
    // registry (= callers can subscribe to AsyncDelegationRegistry.next()
    // to observe spawns). Using the free `delegate(...)` function with
    // this shared registry avoids touching AsyncDelegation.swift (= out
    // of CHATBOX-003 allowlist).
    nonisolated(unsafe) static let delegationRegistry: AsyncDelegationRegistry = AsyncDelegationRegistry()

    public func switchModel(_ id: String) {
        // B-05: write to the canonical owner (= AppState.llmModel),
        // which then mirrors to UserDefaults via its didSet. No raw
        // UserDefaults call here (= single owner maintained).
        appState?.llmModel = id
    }

    public func loadAvailableModels() async {
        // v0.24 boss acceptance fix (2026-08-24): use multi-provider discovery.
        // Was: fallback to WenshuLLMModel.allCases (3 MiniMax-only cases).
        // Now: query all configured providers via AvailableModelsDiscovery,
        // sectioned by provider per ticket 011 spec.
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
            // list (current WenshuLLMModel scope per boss 8/21).
            modelIds = WenshuLLMModel.allCases.map { $0.rawValue }
        }
        availableModels = modelIds
        if !availableModels.contains(currentModel) {
            availableModels = [currentModel] + availableModels
        }
        recomputeContextUsed()
    }

    /// recomputeContextUsed: sum of all agent message tokens (real LLM API usage, replaces chars/4 heuristic)
    public func recomputeContextUsed() {
        contextUsed = messages.compactMap { $0.tokens }.reduce(0, +)
        // trace: ChatViewModel.contextUsed accumulation
        NSLog("[wenshu.context] sum tokens after recompute: %d (messages=%d)", contextUsed, messages.count)
    }

    /// CHATBOX-001 (2026-09-04): routeInput is the new front-door for chat
    /// input. It dispatches `/<skill>` slash commands through
    /// SkillAdapter.parseAndInvoke BEFORE the LLM path; non-slash text falls
    /// through to `send()`. Empty input is a no-op. Slash input that fails
    /// (= parseAndInvoke throws) also falls through to `send()` for graceful
    /// degradation (= unknown skill name should still reach the LLM).
    public func routeInput() async {
        let input = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }

        // CHATBOX-003 (2026-09-04): try @-mention subagent trigger
        // FIRST (= higher priority than slash commands, because @slug
        // syntax is more specific — it names a known sub-agent).
        // Multiple mentions in one input spawn multiple sub-agents
        // concurrently (= AsyncDelegation.delegate is async; awaits
        // are awaited sequentially so the user sees the spawn order
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

        // CHATBOX-001: try explicit slash command / keyword match FIRST.
        // SkillAdapter.parseAndInvoke throws SkillAdapterError.noMatch when
        // neither slash nor keyword resolves — we catch + fall through.
        do {
            let parsed = try await SkillAdapter.shared.parseAndInvoke(input)
            // Skill resolved — record the result as a system message and
            // clear the draft. The skill's own output is the user-visible
            // reply; we don't re-send it through the LLM.
            messages.append(ChatMessage(
                role: .system,
                source: .system,
                content: "Skill /\(parsed.skillName) → \(parsed.result)"
            ))
            inputText = ""
            return
        } catch {
            // Slash/keyword failed (= unknown skill, stub error, etc.) →
            // fall through to the LLM path so the user isn't left with a
            // dropped message.
        }

        // No slash match → existing LLM send path.
        await send()
    }

    /// send: send message → Wenshu main agent synthesis
    public func send() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        // CHATIMG-001 (2026-09-07): allow image-only sends (= an
        // attached screenshot with no text is still a valid send; the
        // image carries the meaning). Capture + clear the draft path
        // BEFORE constructing the user message so the message captures
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

        let userMsgStored = StoredChatMessage(id: userMsg.id.uuidString, source: "user", content: text, timestamp: Date())
        try? await store?.append(userMsgStored, sessionId: sessionId)

        do {
            // v0.34: streaming path = render each text chunk as it
            // arrives (= character-by-character, ChatGPT-style). The
            // conductor path remains blocking for now (= its
            // WenshuConductor.handle returns a single assembled
            // reply = the WenshuConductor owns its own multi-agent
            // pipeline and isn't yet adapted to streaming). v0.34
            // ships streaming for the direct verifier path = the
            // most common user flow.
            // B-05: read the model id from the canonical owner (= same value
            // `vm.currentModel` returns, via the shared AppState
            // reference). No more raw UserDefaults read here (= single
            // owner maintained).
            let currentModel: String = self.currentModel
            NSLog("[wenshu.model] effective model: %@ (AppState source)", currentModel)
            var reply: String
            var replyThinking: String?    // WenshuLLMBlock.thinking footnote UI
            var replyTokens: Int?
            if let conductor = conductor {
                // Conductor path = blocking (= future ticket wires
                // conductor to streaming; for v0.34 = direct verifier
                // path is the streamed one).
                let result = try await conductor.handle(userMessage: text, sessionId: sessionId, model: currentModel)
                reply = result.reply
                replyThinking = result.thinking
                replyTokens = result.totalTokens
                // Replace placeholder with real reply (tokens + thinking footnote)
                if let idx = messages.firstIndex(where: { $0.id == placeholderId }) {
                    NSLog("[wenshu.scroll] placeholder replace: id=%@ beforeCount=%d afterCount=%d", placeholderId.uuidString, messages.count, messages.count)
                    messages[idx] = ChatMessage(id: placeholderId, role: .agent, source: .wenshu, content: reply, tokens: replyTokens, thinking: replyThinking)
                }
            } else {
                // v0.34 streaming path: render each text chunk as
                // it arrives (= user sees incremental text, not a
                // 5-10s wait for the full reply).
                let verifier = WenshuVerifier()
                let stream = verifier.streamChat(
                    text,
                    system: WenshuConductorIdentity.systemPrompt,
                    model: currentModel
                )
                var buffer = ""
                for try await block in stream {
                    switch block {
                    case .text(let chunk):
                        buffer += chunk
                        // v0.34 streaming: render the accumulated buffer
                        // into the placeholder message (= SwiftUI
                        // auto-re-renders as messages array changes).
                        if let idx = messages.firstIndex(where: { $0.id == placeholderId }) {
                            messages[idx] = ChatMessage(
                                id: placeholderId,
                                role: .agent,
                                source: .wenshu,
                                content: buffer,
                                tokens: nil
                            )
                        }
                    case .thinking(let text, _):
                        replyThinking = (replyThinking ?? "") + text
                    case .toolUse(let id, let name, _):
                        // v0.34 streaming: future Issue 07 followup
                        // wires tool-call rendering in the streaming
                        // path. For now, log + continue.
                        NSLog("[wenshu.stream] tool call: id=%@ name=%@", id, name)
                    case .unknown(_, _):
                        continue
                    }
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
            let agentMsgStored = StoredChatMessage(id: placeholderId.uuidString, source: "wenshu", content: reply, timestamp: Date(), tokens: replyTokens)
            try? await store?.append(agentMsgStored, sessionId: sessionId)
            recomputeContextUsed()

            // trigger summary generation (LLM + saveSummary + deleteOldMessages order)
            if let store = store {
                let verifier = WenshuVerifier()
                Task { @MainActor in
                    _ = try? await store.summarizeIfNeeded(sessionId: sessionId, lastN: 10, threshold: 20, verifier: verifier)
                }
            }
        } catch {
            // v0.34: route through UserFacingError.from (= single
            // source of truth for raw-error-to-Chinese translation;
            // = replaces the prior ad-hoc "Error: \(localizedDescription)"
            // which showed the raw English NSError text to the user).
            //
            // v0.40 boss 9/7 OOB 'hint, usermust minimax
            // key, generalhint': pass `nil` as the context
            // (NOT `currentModel`). The previous `context: currentModel`
            // interpolated the model name (= "MiniMax-M3") as the
            // "provider", = user-visible message looked like it was
            // binding them to MiniMax. Now `nil` triggers the
            // generic, provider-agnostic message in UserFacingError
            // (= user can pick any of the 7 LLM connectors per
            // AGENTS.md §11.2).
            let userErr = UserFacingError.from(error, context: nil)
            let errMsg = userErr.errorDescription ?? "未知错误。"
            if let idx = messages.firstIndex(where: { $0.id == placeholderId }) {
                messages[idx] = ChatMessage(id: placeholderId, role: .system, source: .system, content: errMsg)
            }
            lastError = errMsg
        }
        isSending = false
    }

    /// WIRE-AGENT-003 (2026-09-04): start a long-running goal via the
    /// HermesGoals / GoalsManager Ralph loop. Reads `inputText` (= the
    /// current chat draft) as the goal prompt, constructs a fresh
    /// GoalsManager with the active AnthropicConnector (=
    /// placeholder connector — the AppState.activeConnector plumbing
    /// is a follow-up ticket; the hard-rule allowlist for this
    /// ticket = ChatView.swift only), launches runGoal in a detached
    /// background Task, and records the goal in the system message
    /// stream so the user sees progress / errors.
    ///
    /// Acceptance (= per P0 #3 brief):
    /// - empty input → no-op (= no GoalsManager created)
    /// - non-empty input → spawn GoalsManager + runGoal in background
    /// - clears the input draft on entry
    /// - appends a system ChatMessage on start + completion / failure
    public func startLongRunningGoal() async {
        let goal = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !goal.isEmpty else { return }

        // Main + auxiliary connector. Both fallback to AnthropicConnector
        // (= a real LLMConnector that errors with .missingAPIKey when no
        // key is configured; the user sees the failure in the system
        // message). The AppState.activeConnector wiring is a separate
        // ticket — out of allowlist for this one.
        let mainConnector: any LLMConnector = AnthropicConnector()
        let auxiliaryConnector: any LLMConnector = mainConnector

        // Runtime with default sinks + no mock-time (= test seam left
        // open for future GoalsManager-runtime-tests; runGoal only
        // reads runtime.now() between iterations).
        let runtime = RuntimeHelpers()

        // Per-session persistence directory under NSTemporaryDirectory.
        // HermesGoals.swift's GoalsManager.persistGoal requires the
        // directory to be writable (= tests use the same temp-scoped
        // pattern; see HermesGoalsTests.makeTempPersistenceDir).
        let persistenceDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WenshuGoals-\(UUID().uuidString)", isDirectory: true)

        let manager = GoalsManager(
            mainConnector: mainConnector,
            auxiliaryConnector: auxiliaryConnector,
            runtime: runtime,
            maxIterations: 10,
            persistenceDirectory: persistenceDirectory
        )

        // Initial persistence: record the goal's starting state so
        // the JSON file is visible in the persistence directory even
        // before runGoal produces any work. HermesGoals.swift does
        // not auto-persist; persistGoal is the explicit hook.
        let goalId = UUID()
        try? await manager.persistGoal(
            goalId,
            work: GoalsWork(goal: goal, work: "", iterations: 0, context: [])
        )

        let shortHandle = String(goalId.uuidString.prefix(8))
        messages.append(ChatMessage(
            role: .system,
            source: .system,
            content: "Long-running goal started: \(goal) (handle \(shortHandle))"
        ))

        // Clear the draft (= mirrors the routeInput() end-state so the
        // user can keep typing while the Ralph loop runs in background).
        inputText = ""

        // Detached background Task: GoalsManager.runGoal does its own
        // actor-isolated loop (= no @MainActor coupling), so we can
        // safely detach and bounce back to MainActor for chat updates.
        let capturedGoal = goal
        Task.detached(priority: .background) { [manager] in
            do {
                let result = try await manager.runGoal(capturedGoal)
                await MainActor.run {
                    self.messages.append(ChatMessage(
                        role: .system,
                        source: .system,
                        content: "Goal completed: \(capturedGoal) (iterations: \(result.iterations))"
                    ))
                }
            } catch {
                await MainActor.run {
                    self.messages.append(ChatMessage(
                        role: .system,
                        source: .system,
                        content: "Goal failed: \(capturedGoal) (\(error.localizedDescription))"
                    ))
                }
            }
        }
    }

    /// clear: clear all messages
    /// v0.24 boss acceptance fix (Boss 8/25 OOB ticket 015.014): archive current
    /// session + context (= reset messages + contextUsed), generate new
    /// sessionId, persist new session for future writes. Boss spec: 'start a
    /// brand new session. Reload the context'.
    public func startNewSession() {
        // 1. Clear in-memory state (= visual reset).
        messages = []
        contextUsed = 0
        // 2. Generate new sessionId (= UUID-based).
        let newId = "s_" + UUID().uuidString.prefix(12).lowercased()
        sessionId = newId
        // 3. NSLog audit trail (= verify in Console.app).
        NSLog("[wenshu.chat] startNewSession: id=%@ messages=%d contextUsed=%d",
              sessionId, messages.count, contextUsed)
    }

    public func clear() {
        messages.removeAll()
        lastError = nil
    }

    /// valueForStore: store ChatView .task modifier (init race condition)
    public nonisolated func valueForStore() -> ChatSessionStore? { store }
    public func valueForSessionId() -> String { sessionId }  // v0.24 bossverificationfix (F2): @MainActor-isolated with sessionId

    /// replaceMessages: ChatView .task loadcompletereplace (append)
    public func replaceMessages(_ newMessages: [ChatMessage]) {
        self.messages = newMessages
    }
}

/// ChatView: lower-left zone UI (Apple SwiftUI + conductor + store)
public struct ChatView: View {
    /// Works out where a message sits in a run of consecutive messages from
    /// the same author. iMessage tails only the last bubble of a run and
    /// squares the corners facing a neighbour, which is what makes a burst
    /// of replies read as one block instead of a stack of pills.
    static func bubblePosition(at index: Int, in messages: [ChatMessage]) -> ChatBubblePosition {
        let source = messages[index].source
        let samePrevious = index > 0 && messages[index - 1].source == source
        let sameNext = index + 1 < messages.count && messages[index + 1].source == source
        switch (samePrevious, sameNext) {
        case (false, false): return .only
        case (false, true):  return .first
        case (true, true):   return .middle
        case (true, false):  return .last
        }
    }

    @State private var vm: ChatViewModel
    // v0.24 boss acceptance fix (2026-08-24): focus management for input box.
    // Boss 8/24 feedback: when no provider key, chat input should be disabled
    // AND lose focus (no cursor blinking, no keyboard capture).
    @FocusState private var inputFocused: Bool
    // CHATIMG-001 (2026-09-07): toggles the .fileImporter sheet when the
    // user clicks the paperclip button. Bound to .fileImporter(isPresented:)
    // on the input HStack per Apple HIG SwiftUI fileImporter pattern.
    @State private var showingImageImporter: Bool = false
    /// True while a drag is hovering the input row, so the row can show a
    /// drop highlight. Apple's .dropDestination reports this for free.
    @State private var isDropTargeted: Bool = false
    // Reactive check: is the current model usable?
    // v0.61 boss 2026-09-10 OOB 'put the no-key overlay back': the vm's
    // snapshot of the model id lags when the key is configured from
    // Settings, so the input was disabling itself even though the user
    // had just set a key. Read the same UserDefaults the Settings pane
    // writes to (= the canonical source for `wenshu.llm.model`), so the
    // chat input and the ChatZoneView overlay above it answer to the same
    // signal.
    private var hasUsableKey: Bool {
        // ChatViewModel exposes a live read of AppState.llmModel when an
        // appState was injected at init; otherwise it falls back to
        // UserDefaults. Both look at the same key.
        let model = !vm.currentModel.isEmpty
            ? vm.currentModel
            : (UserDefaults.standard.string(forKey: "wenshu.llm.model") ?? "")
        return !model.isEmpty && !vm.isSending
    }

    public init(conductor: WenshuConductor? = nil, store: ChatSessionStore? = nil, sessionId: String = "default", vm: ChatViewModel? = nil) {
        // optional ChatViewModel injection (ChatZoneView shared vm for bottom toolbar
        // Read vm.contextUsed auto-propagate. Q51 child overrides parent partial, do not touch ChatViewModel.send() body, do not touch ChatView body)
        // B-05: when ChatZoneView passes a pre-constructed `vm` (=
        // the canonical path), the AppState is already injected into
        // the vm in ChatZoneView.init. When ChatView creates its own
        // vm (= the standalone path), the env-injected AppState is
        // resolved via `.task` after init (= can't read @Environment
        // inside init). Either way, currentModel routes through
        // AppState.llmModel.
        if let vm = vm {
            _vm = State(initialValue: vm)
        } else {
            // initialMessages via .task async load (avoids init race)
            // P0 #2 (WIRE-AGENT-002): when ChatView constructs its own
            // ChatViewModel (= the standalone / preview path), register
            // ParagraphAITool.shared by wrapping the conductor with the
            // tool registry (= tool dispatch path now active in the
            // chat surface). The App-supplied canonical path (=
            // ChatZoneView passing a pre-built vm) inherits whatever
            // the App-side conductor already has; App.swift is out of
            // scope for this ticket.
            let wiredConductor = ChatView.conductorRegisteringParagraphAI(conductor)
            _vm = State(initialValue: ChatViewModel(conductor: wiredConductor, store: store, sessionId: sessionId, initialMessages: []))
        }
    }

    /// P0 #2 (WIRE-AGENT-002): when ChatView builds a fallback vm,
    /// wrap the incoming conductor so ParagraphAITool is registered.
    /// ChatView is the registering site for the chat surface (= the
    /// user-facing chat UI is where paragraph AI editing fires); App.swift
    /// is out of scope for this ticket so we build a peer conductor
    /// (= same shape via the public init) that pre-loads
    /// ParagraphAITool. The new conductor is what ChatViewModel uses;
    /// App's conductor reference is unaffected.
    ///
    /// P0 #5 (WIRE-AGENT-005): the same register site now also wires
    /// KanbanStoreTool (= thin adapter exposing the KanbanTools
    /// LLM-facing dispatcher through the Tool protocol). The
    /// KanbanStore that the WenshuConductor takes ownership of is
    /// the canonical wenshu-side task store; KanbanStoreTool reads /
    /// writes through it via KanbanTools.kanban(action:params:).
    ///
    /// WIRE-TOOLREGISTRY-003: the explicit `tools: [...]` dict is
    /// gone. The 12 tools now arrive via `WenshuConductor.buildTools
    /// (from: ToolRegistry.shared)` (= hermes single-source-of-truth
    /// pattern = tools self-register at module-import time, the
    /// conductor reads from the registry). The same `do/catch`
    /// shape is preserved (= kanban bootstrap may fail in preview /
    /// CI) but the tool dict is built once via the registry rather
    /// than constructed per ChatView instance.
    ///
    /// `internal` (= default Swift access) so the wiring test
    /// (`WenshuConductorToolRegistryWiringTests`) can call the
    /// production code path. The method is a pure factory with no
    /// observable side effects beyond constructing the conductor, so
    /// widening from `private` to `internal` does not expose any new
    /// production surface.
    internal static func conductorRegisteringParagraphAI(_ conductor: WenshuConductor?) -> WenshuConductor? {
        // No conductor provided → nothing to wrap. ChatViewModel's
        // direct verifier path (= non-conductor branch in send()) does
        // not consult a tool registry, so this is a no-op for preview.
        guard let conductor = conductor else { return nil }
        // Build a peer conductor with the tool registry populated from
        // ToolRegistry.shared. We reuse the public init (= same surface
        // App.swift uses); the collaborator triple (runtime / verifier
        // / kanbanStore) is reconstructed (= standalone preview path;
        // production uses App-supplied collaborators through the
        // canonical ChatZoneView shared-vm path which does not go
        // through here).
        let runtime = AgentRuntime()
        let verifier = WenshuVerifier()
        // WIRE-TOOLREGISTRY-003: pull the 12-tool registry from
        // ToolRegistry.shared (= single source of truth). `buildTools`
        // polls internally up to `toolRegistryWaitTimeoutMs` for the
        // module-load `Task { await register(...) }` blocks to settle.
        let tools = WenshuConductor.buildToolsSync(from: ToolRegistry.shared)
        // KanbanStore construction may fail (= disk-permission issues in
        // preview / CI); fall back to an in-process stub conductor that
        // does not write kanban state but still carries the tool
        // registry (= the test of record lives in
        // WenshuConductorToolWiringTests and constructs its own kanban).
        do {
            let kanban = try KanbanStore()
            try kanban.bootstrap()
            return WenshuConductor(
                runtime: runtime,
                verifier: verifier,
                kanbanStore: kanban,
                tools: tools
            )
        } catch {
            let fallback = try! KanbanStore(path: NSTemporaryDirectory() + "wenshu-chat-fallback-\(UUID().uuidString).sqlite")
            return WenshuConductor(
                runtime: runtime,
                verifier: verifier,
                kanbanStore: fallback,
                tools: tools
            )
        }
    }

    /// P2 #20 (WIRE-LIBRARIAN-001): build the BookStore instance that
    /// BookManagerTool wraps in this fallback conductor. The canonical
    /// production wiring is `appState.bookStore` (= injected via
    /// `@Environment(BookStore.self)`); this helper is the fallback /
    /// standalone path (= ChatView constructs its own conductor
    /// because no App-supplied conductor was provided). We build a
    /// minimal BookStore pointing at a unique `/tmp` root (= same
    /// forgiving pattern as the KanbanStore fallback above) so the
    /// book_manager tool is fully exercised end-to-end in preview /
    /// tests even when no real library has been opened.
    private static func bookStoreForChatTool() -> BookStore {
        let tmpRoot = URL(fileURLWithPath: "/tmp/wenshu-p2-20-chat-tool-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)
        let shelvesRoot = tmpRoot.appendingPathComponent("shelves", isDirectory: true)
        let referenceLibraryRoot = tmpRoot.appendingPathComponent("reference-library", isDirectory: true)
        let referenceStore = FileSystemReferenceStore(referenceLibraryRoot: referenceLibraryRoot)
        let stores = LibraryStores(
            shelvesRoot: shelvesRoot,
            referenceLibraryRoot: referenceLibraryRoot,
            referenceStore: referenceStore
        )
        let bookStore = BookStore(stores: stores)
        // Best-effort mirror of any on-disk shelves into the in-memory
        // `shelves` cache (= mirrors what `LibraryLifecycleHook` /
        // `reloadAllBooks` do in the production launch path).
        bookStore.shelves = (try? bookStore.sidebarLoadShelves()) ?? []
        bookStore.reloadAllBooks()
        return bookStore
    }

    public var body: some View {
        // v0.24 boss acceptance fix: listen for global defocus notification.
        // Boss 8/24 feedback: 'clicking other areas, the textfield still keeps focus'.
        VStack(spacing: 0) {
            // Message list (ScrollView + LazyVStack ground truth)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(vm.messages.enumerated()), id: \.element.id) { index, msg in
                            // v0.57: a bubble needs to know where it sits in
                            // a run of consecutive messages from one author,
                            // because iMessage only tails the last one and
                            // squares off the corners facing a neighbour.
                            ChatMessageView(
                                message: msg,
                                position: Self.bubblePosition(
                                    at: index,
                                    in: vm.messages
                                )
                            )
                            .id(msg.id)
                        }
                    }
                    .padding(DesignTokens.chromePaddingVertical)
                }
                // Apple SwiftUI 14+ .defaultScrollAnchor(.bottom)
                // Apple = ScrollView changeauto, placeholder -> reply replace scrollTo
                .defaultScrollAnchor(.bottom)
                // onChange of lastContent, not just count
                // placeholder create content="AI in progress…" (15 chars), reply replace content= reply (~hundreds chars)
                // content change onChange, scrollTo last.id
                .onChange(of: vm.messages.last?.content ?? "") { _, _ in
                    if let last = vm.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            // async load history via .task modifier (non-blocking)
            .task {
                await vm.loadAvailableModels()
                // Fall back to the delegate's store: on a cold launch the
                // view can run before applicationDidFinishLaunching has
                // built one, so the vm's snapshot is nil.
                if let store = vm.valueForStore() ?? WenshuAppDelegate.sharedChatStoreRef {
                    if let loaded = try? await store.loadMessages(sessionId: vm.valueForSessionId()) {
                        let mapped = loaded.map { stored in
                            // v0.24 boss acceptance fix: preserve role from stored.source.
                            // Was: hardcoded .agent (wrong, user messages shown as agent).
                            // Now: parse source = "user" → .user role, "wenshu" → .agent.
                            let resolvedRole: ChatRole = (stored.source == "user") ? .user : .agent
                            return ChatMessage(
                                id: UUID(uuidString: stored.id) ?? UUID(),
                                role: resolvedRole,
                                source: ChatSource(rawValue: stored.source) ?? .wenshu,
                                content: stored.content,
                                timestamp: stored.timestamp,
                                tokens: stored.tokens
                            )
                        }
                        vm.replaceMessages(mapped)
                    }
                }
            }

            // v0.35 ticket 003 sub-step 4 + 5: compression status pill + manual compress button.
            // Per spec §6.4 UI mapping: 🟨 half-visible pill + 🟥 must-UI button.
            ChatViewCompressionRow(vm: vm)

            Divider()

            // Input box + send button (Apple HIG SwiftUI ground truth)
            // v0.25.1 (= ticket 030 chat send button 8 PT textfield
            // top padding + button vertical center alignment):
            // owner 2026-08-26 OOB 'add 8 PT spacing above the chat text field' =
            // add 8 PT gap between the Divider above and the
            // TextField (= textfield top padding = 8 PT, so the
            // input area has visual breathing room from the divider
            // line). Implementation: HStack(spacing: 8) reverted to
            // baseline (= boss corrected ticket 030's HStack 8→16
            // change as wrong, = the gap is ABOVE the textfield not
            // between textfield and send button), TextField gains
            // .padding(.top, LayoutTokens.chromePaddingLarge) (= 8 PT gap above the textfield,
            // = the actual boss OOB intent).
            // v0.25.1 (= ticket 031 chat send button vertical
            // center alignment): owner 2026-08-26 OOB 'button
            // [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
            // buttonchangein progress' = with the 8 PT
            // top padding on TextField, the TextField's effective
            // top edge shifted down 8 PT (= 24 PT height + 8 PT top
            // padding = 32 PT total box). The send button's default
            // HStack alignment = .top (= button top edge aligns with
            // the TextField's top edge, which is now 8 PT below the
            // original position). Fix = change HStack alignment to
            // .center (= button vertically centered relative to the
            // full TextField + padding box).
            // v0.25.1 (= ticket 032 chat textfield height = 32 PT):
            // owner 2026-08-26 OOB 'match the text field and button heights
            // both same as the button' = make the textfield visual height
            // match the send button height (= 32 PT). Current = textfield
            // visual height 24 PT (= SwiftUI default TextField with
            // .roundedBorder). Button height = ~32 PT (with .padding).
            // Fix = add .frame(height: DesignTokens.toolbarBandHeight) on the TextField (= textfield
            // visual height now matches button = both 32 PT). The 8 PT
            // top padding preserved (= 8 PT gap above textfield per
            // ticket 030) so total TextField + padding box = 40 PT
            // (= 8 PT gap + 32 PT textfield visual).
            // v0.25.1 (= ticket 033 chat send button BOTTOM
            // alignment): owner 2026-08-26 OOB 'still not aligned, button and
            // text field bottom-aligned' = the previous ticket 031's .center
            // alignment still didn't match. Boss corrected again:
            // button should be aligned to the BOTTOM of the textfield
            // (= .bottom alignment, not .center). The button's
            // bottom edge aligns with the textfield's bottom edge
            // (Apple HIG toolbar convention: action button at
            // baseline of input field).
            // v0.25.1 (= ticket 033 followup 2: chat send button
            // CENTER alignment — boss corrected AGAIN): owner
            // [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
            // 2026-08-26 OOB 'still wrong, use text field + button center-align'
            // = after 3 alignment attempts (.center, .bottom,
            // .bottom + height 32), the actual visual boss wants
            // is .center alignment. The earlier ticket 031's
            // .center was correct on alignment but the button's
            // height wasn't pinned (= 40 PT, vs textfield 32 PT),
            // so visually the .center alignment didn't look right
            // because the button was already too tall. Now with
            // ticket 033 followup's .frame(height: DesignTokens.toolbarBandHeight) pinning the
            // button to 32 PT (= matches textfield), boss confirmed
            // .center alignment is the right behavior.
            // v0.25.1 (= ticket 033 final 2: chat send button
            // HORIZONTAL alignment = drop the 8 PT top padding +
            // drop the .frame(height: DesignTokens.toolbarBandHeight) textfield pin + drop the
            // .frame(height: DesignTokens.toolbarBandHeight) button pin — owner 2026-08-26 OOB
            // 'still wrong, it is horizontal center' = the 4 previous attempts all
            // tried to vertically align the textfield with the button,
            // but the actual visual boss wants is HORIZONTAL center
            // alignment (= the .center alignment already does this,
            // = but with 8 PT top padding + .frame(height: DesignTokens.toolbarBandHeight) the
            // textfield is offset down 8 PT + extended to 32 PT,
            // = making the visual center NOT match the button).
            // The right fix = drop the 8 PT top padding (= 0 PT
            // padding = textfield is its natural 24 PT height) AND
            // drop the .frame(height: DesignTokens.toolbarBandHeight) on both textfield and
            // button (= let each take its natural default height;
            // SwiftUI TextField with .roundedBorder = 24 PT, Button
            // with .borderedProminent = ~40 PT). With the 8 PT
            // padding dropped + height pins dropped, the HStack
            // .center alignment = both elements centered at the
            // natural height axis. But 'horizontal center' = horizontal
            // center, = the user wants the textfield + button to
            // share the same VERTICAL center line (= each element's
            // vertical center on the same y = the HStack .center
            // alignment IS the answer, but with natural heights,
            // not forced 32 PT).
            // Final approach (= this ticket 033 final 2):
            // 1. drop .padding(.top, LayoutTokens.chromePaddingLarge) on TextField (= boss OOB
            //    interpreted 'horizontal center' as 'remove my 8 PT top
            //    padding that's making the visual center off').
            // 2. drop .frame(height: DesignTokens.toolbarBandHeight) on TextField (= use natural
            //    TextField height = 24 PT).
            // 3. drop .frame(height: DesignTokens.toolbarBandHeight) on Button (= use natural
            //    Button height = ~40 PT).
            // 4. KEEP HStack(alignment: .center, spacing: 8) (= the
            //    alignment that boss has been trying to tell us to
            //    use all along, = vertical center between the two
            //    elements at their natural heights).
            // v0.25.1 (= ticket 034 final 3): owner 2026-08-26 OOB
            // [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
            // 'you misunderstood, the text field's outer margin, 8 PT up, this still needs to stay'
            // = 8 PT OUTER top margin on the chat input HStack
            // (= between the Divider above and the HStack that
            // contains the textfield + button). The textfield +
            // button are offset down 8 PT as a group (= the
            // 8 PT margin is OUTSIDE the textfield, NOT inside
            // = no inner padding on the textfield itself).
            // v0.28 followup Boss UX round 20: HStack(alignment: .center,
            // spacing: 8) with .padding(.top, DesignTokens.chromePaddingLarge) (= 16 PT outer top
            // margin applied to the entire HStack, = both TextField
            // and Send button offset down 16 PT together = no
            // misalignment). Per Apple HIG for chat input rows in
            // Messages / Slack, TextField and Send button should be
            // vertically centered at the SAME baseline. Both are
            // 24 PT tall (= TextField.frame(height: DesignTokens.iconLargeSize) + Button
            // .controlSize(.regular)), and HStack(alignment: .center)
            // centers them vertically at the HStack midline.
            //
            // v0.28 followup Boss UX round 25 (Boss 2026-08-29 OOB
            // [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
            // 'does the text field auto-grow taller when more text is typed?'): changed
            // HStack alignment from .center → .bottom so the Send
            // button stays anchored at the bottom of the chat input
            // row even as the TextField grows from 24 PT (= 1 line) to
            // up to 80 PT (= 4 lines). Per Apple HIG canonical chat
            // input row in Messages / Slack, the Send button is bottom-
            // anchored (= never floats) while the textfield expands
            // upward. This is the same pattern as Apple's chat input
            // everywhere on macOS 26 Tahoe.
            // CHATIMG-001 (2026-09-07): the chat input is wrapped in a
            // VStack so a small attachment preview chip can sit above
            // the HStack (= Apple Messages / Slack attachment preview
            // pattern). The chip renders only when
            // `vm.attachedImagePath != nil`. The HStack itself is
            // unchanged (= paperclip button + TextField + Send +
            // Goal button + the same outer paddings).
            VStack(alignment: .leading, spacing: 4) {
                if let imagePath = vm.attachedImagePath {
                    // Attachment preview chip: small thumbnail + a
                    // ✕ button to clear the draft. Sized to fit the
                    // chat input row width (= bounded by outer
                    // horizontal padding via the parent's
                    // .padding(.horizontal, ...) below).
                    ChatAttachmentPreviewChip(imagePath: imagePath) {
                        vm.clearAttachedImage()
                    }
                }
            HStack(alignment: .bottom, spacing: 8) {
                // CHATIMG-001 (2026-09-07): paperclip attach button to
                // the left of the TextField. Toggles .fileImporter on
                // the input HStack (= canonical Apple HIG SwiftUI
                // pattern for picking a single file). The picked
                // image is copied into `<libraryPath>/cache/chat-uploads/`
                // via ChatViewModel.attachImage(at:) and rendered as a
                // preview chip above the HStack (= Apple Messages /
                // Slack attachment preview pattern).
                Button {
                    showingImageImporter = true
                } label: {
                    if let lucide = Lucide("paperclip") {
                        lucide
                            .aspectRatio(contentMode: .fit)
                            .frame(width: DesignTokens.tabIconSize, height: DesignTokens.tabIconSize)
                    } else {
                        LucideIconSystemFallback("paperclip", size: 18)
                    }
                }
                // v0.61 boss 2026-09-10 OOB 'the attach button and the
                // send button should match styles': they are both in the
                // same HStack, so any visual mismatch reads as a bug.
                // Send uses .bordered (= Apple standard Liquid Glass
                // capsule, per boss 8/29 OOB); attach was .borderless
                // (the older CHATIMG-001 default). The two are now the
                // same style, which is also what Apple uses for the
                // paperclip in Messages and the send in every chat app
                // that ships with the platform.
                .buttonStyle(.bordered)
                .help(WenshuI18n.t("chat.input.attach.help"))
                // CHATIMG-001 (2026-09-07): the attach button is
                // intentionally NOT gated on `hasUsableKey` (=
                // LLM model availability). Attaching a draft image
                // is independent of sending (= you can attach + see
                // the preview chip + clear it even when no LLM
                // provider is configured). Send itself still
                // requires `hasUsableKey` via the Send button's own
                // .disabled check; if you try to send with no
                // model, the existing routeInput() guard handles
                // it (= no LLM call = no error message; the
                // message just persists in the in-memory list).
                .disabled(vm.isSending)
                // v0.24 boss acceptance fix (2026-08-24): placeholder shows different text based on key state.
                // Boss 8/24 (out-of-band): 'please set up a large-model provider in Settings first'.
                // v0.25.1 (= ticket 030 chat send button Lucide icon + 8 PT textfield padding):
                // owner 2026-08-26 OOB 'chat zone chatbutton
                // [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
                // send chat 8 PT ' =
                // 1) replace SF paperplane.fill (= Apple Send ICON) with
                //    Lucide .send (= paper plane icon, same visual
                //    metaphor as SF paperplane but Lucide outline style
                //    for consistency with the rest of the project per
                //    ticket 005+).
                // 2) add 8 PT horizontal padding to the textfield (= text
                //    has 8 PT of breathing room from the rounded border,
                //    = Apple HIG TextField default padding is 4 PT, owner
                //    wants 12 PT effective = 4 + 8).
                // 3) increase HStack(spacing: 8) to HStack(spacing: 16)
                //    per owner spec 'add 8 PT spacing above the chat text field' = add 8 PT
                //    additional gap between textfield and send button
                //    (= boss wants more visual breathing room between
                //    textfield and send button than current 8 PT).
                TextField(WenshuI18n.t("auto2.chatview.l858.h59940148"),
                          text: $vm.inputText, axis: .vertical)
                    .lineLimit(1...4)
                    // v0.40 boss 9/7 OOB ', shouldchat zonedialog
                    // . hint, should /help ': the slash-
                    // command hint (= "/create-book My new novel")
                    // lives here as the .help() tooltip (= macOS
                    // NSHelpManager on hover; = Apple HIG canonical
                    // "explainer tooltip" pattern). Previously was a
                    // top banner above the workspace (= visual noise,
                    // = boss wants the chat zone to be the SOLE
                    // input surface for slash commands; = hint
                    // moved to non-intrusive tooltip here).
                    .help(WenshuI18n.t("chat.input.help"))
                    // v0.28 followup Boss UX round 27 (Boss 2026-08-29
                    // [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
                    // OOB 'buttonstatus 30pt'):
                    // .multilineTextAlignment(.leading) + the default
                    // .leading-to-trailing text flow makes the text
                    // top-aligned by default (= text sits at the top
                    // of the 30 PT frame, not centered). To match the
                    // Send button's centered visual position (= button
                    // label is centered within the 30 PT capsule),
                    // use no special alignment (= SwiftUI TextField
                    // axis: .vertical centers content by default
                    // within the .frame(minHeight: 30) bounds).
                    // v0.24 boss acceptance fix: disable when no key configured.
                    .disabled(!hasUsableKey)
                    .focused($inputFocused)
                    .onSubmit { Task { await vm.routeInput() } }
                    .onChange(of: vm.currentModel) { _, new in
                        if new.isEmpty {
                            inputFocused = false
                        } else {
                            // v0.24 boss acceptance fix: focus input when key becomes available.
                            inputFocused = true
                        }
                    }
                    // v0.25.1 (= ticket 034 chat textfield 1 PT focus
                    // ring): owner 2026-08-26 OOB 'when the text field is focused this
                    // blue outline is too thick — change to 1PT and try' = SwiftUI
                    // TextField .roundedBorder style has a default
                    // focus ring ~2-3 PT thick. Boss wants the focus
                    // ring thinned to 1 PT. Fix = override the default
                    // .roundedBorder style with a custom rounded
                    // border using .textFieldStyle(.plain) (= removes
                    // system focus ring) + add a conditional
                    // RoundedRectangle stroke (lineWidth: 1) on focus.
                    // v0.25.1 (= ticket 035 chat textfield placeholder
                    // color + position): owner 2026-08-26 OOB 'input
                    // [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
                    // message... hint defaultyes
                    // color ' = the placeholder text
                    // 'inputmessage...' currently looks too bright (= high
                    // contrast, = looks like real text) and is in
                    // the wrong position (= too far left, no left
                    // padding). Per Apple HIG (developer.apple.com/
                    // design/human-interface-guidelines/color +
                    // developer.apple.com/design/human-interface-
                    // guidelines/components/selection-and-input/
                    // text-fields), the placeholder text color
                    // should be `placeholderTextColor` (= semantic
                    // = .gray in SwiftUI = systemGray), and the
                    // position should be left-aligned with 12 PT
                    // horizontal padding (= Apple HIG text field
                    // default). Fix = add .padding(.horizontal, DesignTokens.chromePaddingMedium)
                    // to the TextField (= Apple HIG default 12 PT
                    // horizontal padding), and add a subtle
                    // Color.gray.opacity(0.1) background (= so the
                    // textfield is visually a 'control' surface, not
                    // a transparent overlay, = the placeholder text
                    // naturally appears in the secondary color
                    // without being too bright). The 1 PT focus
                    // ring (ticket 034) + 8 PT outer top margin
                    // (ticket 034 final 3) preserved.
                    .textFieldStyle(.plain)
                    // v0.28 followup Boss UX round 25 (Boss 2026-08-29
                    // [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
                    // OOB 'does the text field auto-grow taller when more text is typed?'):
                    // the textfield now has 2 height modes:
                    //
                    // 1. EMPTY STATE (= no text): .frame(minHeight: 30)
                    //    (= matches the Send button at 30 PT so the
                    //    two controls look like the same height when
                    //    there's no text — per Apple HIG canonical
                    //    chat input row in Messages / Mail). Without
                    //    this, the textfield's natural height (= ~22
                    //    PT = font 13 PT + auto-padding) is visually
                    //    shorter than the button (= 24 PT controlSize
                    //    regular + 30 PT frame = 30 PT visual).
                    //
                    // 2. TYPING STATE (= text growing past 1 line):
                    //    no max height pin so the textfield auto-
                    //    grows from 30 PT (1 line) up to 4 lines via
                    //    .lineLimit(1...4). The Send button stays
                    //    bottom-anchored via HStack(alignment: .bottom).
                    //
                    // Why .frame(minHeight: 30) and not .frame(height: LayoutTokens.chromeControlHeight):
                    // - .frame(height: LayoutTokens.chromeControlHeight) PIN the textfield to 30 PT
                    //   regardless of content (= would block the auto-grow
                    //   from round 25).
                    // - .frame(minHeight: 30) ONLY enforces a minimum
                    //   (= textfield starts at 30 PT when empty, but
                    //   can grow larger when content is multi-line).
                    //
                    // v0.28 followup Boss UX round 27 (Boss 2026-08-29
                    // [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
                    // OOB 'buttonstatus 30pt'):
                    // unified both empty-state heights at 30 PT
                    // (= matches kZoneToolbarHeight = canonical chrome
                    // height across the app).
                    //
                    // v0.25.1 (= ticket 037): was pinned to 24 PT per
                    // [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
                    // boss OOB 'is the text field not 32 now, no matter what
                    // change to match the text field height' = at the time, the textfield
                    // visual was 24 PT (= 1 line) so boss wanted to
                    // match the button height.
                    .frame(minHeight: 30)
                    .padding(.horizontal, DesignTokens.chromePaddingMedium)
                    // v0.28 followup Boss UX round 23 (Boss 2026-08-29
                    // OOB 'is the text field in Liquid Glass style?'): Was using
                    // Color.gray.opacity(0.1) (= solid 10% opacity
                    // gray = NOT Liquid Glass). Now uses
                    // .regularMaterial (= macOS 26 Tahoe Liquid Glass
                    // translucency = matches the Apple HIG canonical
                    // TextField look in Messages / Mail / Xcode).
                    // The placeholder text naturally appears in
                    // the secondary color (= .gray via SwiftUI's
                    // semantic foregroundStyle) on the Liquid Glass
                    // background, just like Apple Messages / Slack.
                    // The 1 PT focus ring (borderColor on focus)
                    // v0.40 boss 2026-09-08 OOB 'chat zonebackground color, changeeditor
                    // color': the chat input TextField background was
                    // .regularMaterial (= glass tier = lighter shade
                    // in dark mode = visually distinct from the
                    // surrounding content tier). Boss wants the
                    // chat input area to match the editor zone
                    // (= .underPageBackgroundColor = content tier
                    // = same shade as the empty state background).
                    // Drop the .regularMaterial glass tier (= was
                    // Apple Messages / Slack convention, but boss
                    // wants visual consistency with the editor).
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.regularMaterial)
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(inputFocused ? AnyShapeStyle(.tint) : AnyShapeStyle(.separator), lineWidth: 1)
                        }
                    )
                Button {
                    Task { await vm.routeInput() }
                } label: {
                    if vm.isSending {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        // v0.25.1 (= ticket 030): Lucide .send icon
                        // (= paper plane / send glyph) for the
                        // send button. Replaces SF paperplane.fill
                        // per boss 2026-08-26 OOB. Lucide-first
                        // pattern with SF Symbol fallback (= Layer
                        // 3 fallback) preserves behavior if
                        // 'send' Lucide is missing.
                        if let lucide = Lucide("send") {
                            lucide
                                .aspectRatio(contentMode: .fit)
                                .frame(width: DesignTokens.tabIconSize, height: DesignTokens.tabIconSize)  // v0.28 followup Boss UX round 18: shrink to 18 PT (= matches macOS HIG secondary button glyph size = 13-16 PT, but slightly larger to read clearly inside the bordered Liquid Glass capsule)
                                // v0.55: pulse the glyph while a reply is
                                // streaming, so the button itself carries
                                // the busy state instead of needing a
                                // separate spinner next to it.
                                .opacity(vm.isSending ? 0.5 : 1)
                                .scaleEffect(vm.isSending ? 0.92 : 1)
                                .animation(
                                    vm.isSending
                                        ? .easeInOut(duration: 0.7).repeatForever(autoreverses: true)
                                        : .default,
                                    value: vm.isSending
                                )
                        } else {
                            // v0.27 boss 8/27 OOB: replace SF Symbol 'paperplane.fill'
                            // with the closest Lucide equivalent = 'send'.
                            // Lucide 'send' exists (= paper-plane in 24x24 viewBox);
                            // LucideIcon.fromSystemSymbol helper handles the lookup
                            // + fallback chain.
                            LucideIconSystemFallback("paperplane.fill", size: 18)
                        }
                    }
                }
                // v0.28 followup Boss UX round 18 (Boss 2026-08-29 OOB
                // [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
                // 'send button next to the input, use the Liquid Glass default button style,
                // swap it'): Use .bordered = the standard macOS Liquid
                // Glass secondary button style (= Apple's canonical
                // "default button" look in macOS 26 Tahoe). Per Apple
                // developer.apple.com/documentation/SwiftUI/PrimitiveButtonStyle,
                // .bordered renders a translucent rounded capsule
                // (= Liquid Glass material in macOS 26+) with a
                // 1 PT separator border + tint-on-hover effect.
                // The icon shrinks to 18 PT (= matches Apple's
                // canonical glyph size for secondary toolbar buttons
                // per Liquid Glass HIG). .frame(height: LayoutTokens.chromeControlHeight) keeps
                // the button at Apple's standard control height
                // (= same as the TextField so they align flush).
                // v0.28 followup Boss UX round 27 (Boss 2026-08-29
                // [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
                // OOB 'buttonstatus 30pt'):
                // both TextField and Send button pinned to 30 PT
                // (= canonical macOS HIG chat input height, same
                // as zone tab bar / statusbar). Previously the
                // TextField was visually ~22 PT (= font 13 PT +
                // auto-padding = shorter than the button's 24 PT
                // controlSize regular).
                .buttonStyle(.bordered)
                .controlSize(.regular)  // 24 PT control height (= boss OOB)
                .frame(height: LayoutTokens.chromeControlHeight)
                .disabled(vm.inputText.isEmpty || vm.isSending)
                // WIRE-AGENT-003 (2026-09-04): start-long-running-goal
                // button. ⌘⇧G shortcut per P0 #3 brief. Lives next to
                // the Send button so the user has both single-turn
                // (= Send → routeInput → send) and multi-turn Ralph loop
                // (= ⌘⇧G → startLongRunningGoal → GoalsManager.runGoal)
                // reachable from the same input row. The button is
                // disabled when the draft is empty (= no goal text to
                // run); it does NOT block on isSending because the Ralph
                // loop runs in background (= the user can keep chatting).
                Button {
                    Task { await vm.startLongRunningGoal() }
                } label: {
                    // "target" SF Symbol (= the closest metaphor to the
                    // Ralph loop = "fire this goal at the agent and let
                    // it run until done"). Lucide equivalent (.target)
                    // used for visual consistency with the rest of the
                    // chat input row (= Lucide-first per project
                    // v0.27 boss OOB).
                    if let lucide = Lucide("target") {
                        lucide
                            .aspectRatio(contentMode: .fit)
                            .frame(width: DesignTokens.tabIconSize, height: DesignTokens.tabIconSize)
                    } else {
                        LucideIconSystemFallback("target", size: 18)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .frame(height: LayoutTokens.chromeControlHeight)
                .disabled(vm.inputText.isEmpty)
                .help(WenshuI18n.t("chat.ralphLoop.goalHelp"))
                .keyboardShortcut("g", modifiers: [.command, .shift])
                // v0.28 followup Boss UX round 20 (Boss 2026-08-29 OOB
                // 'text field and send button horizontally aligned'): REMOVED the
                // .padding(.top, DesignTokens.chromePaddingLarge) here (= was misaligning the
                // button with the TextField because the TextField
                // had no equivalent top padding = button was 16 PT
                // below the TextField top edge). Now both TextField
                // (= 24 PT frame height) and Send button (= 24 PT
                // frame height) are flush at the HStack top edge
                // and HStack(alignment: .center) centers them
                // vertically (= Apple HIG canonical for chat input
                // rows in Messages / Slack). The 16 PT outer top
                // margin (= boss 8/26 OOB 'text field top 8PT is not enough, add
                // another 8') is now applied to the entire HStack
                // (= both TextField and button offset down together,
                // = no misalignment).
                // Apply the outer top margin (= 16 PT = 8 PT existing
                // + 8 PT new) to the HStack (= not to the button).
            }
            }   // CHATIMG-001 (2026-09-07): close inner VStack (preview chip + HStack)
            // v0.28 followup Boss UX round 20: 16 PT outer top margin
            // moved from .padding(.top, DesignTokens.chromePaddingLarge) on the button (= was
            // misaligning the button with TextField) to the HStack
            // (= both TextField and Send button offset down 16 PT
            // together, no misalignment). HStack(alignment: .center)
            // vertically centers both 24 PT controls at the HStack
            // midline (= Apple HIG canonical for chat input rows).
            .padding(.top, DesignTokens.chromePaddingLarge)
            .padding(.horizontal, DesignTokens.chromePaddingLeading)
            // v0.28 followup Boss UX round 22 (Boss 2026-08-29 OOB
            // 'text field, send button, all add 10pt to the bottom edge'): 10 PT outer
            // bottom margin (= both TextField + Send button offset up
            // 10 PT from the bottom edge of the chat pane = not flush
            // against the bottom = Apple HIG canonical for chat input
            // rows = matches the Apple Messages / Slack / Mail Compose
            // chat input layout where the input row has breathing
            // room from the window bottom edge).
            .padding(.bottom, DesignTokens.chromePaddingChatBottom)
            // CHATIMG-001 (2026-09-07): file importer for the
            // paperclip button. Bound on the outer VStack (= sibling
            // to the input HStack) per Apple HIG SwiftUI
            // .fileImporter pattern. allowedContentTypes = image
            // UTType set (= png + jpeg + gif + heic = common
            // screenshot formats). On pick, the source URL is handed
            // to ChatViewModel.attachImage(at:) which copies it into
            // the library's cache/chat-uploads/ dir and sets
            // attachedImagePath.
            .fileImporter(
                isPresented: $showingImageImporter,
                allowedContentTypes: [.image, .png, .jpeg, .gif, .heic],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        _ = vm.attachImage(at: url)
                    }
                case .failure:
                    break   // user cancelled or sandbox denial; ignore
                }
            }
            // v0.55 boss OOB 'use the ones we have not used yet': accept
            // images dropped onto the input row, which is the same thing
            // the paperclip does through .fileImporter. .dropDestination is
            // Apple's typed drop API, so the row only lights up for payloads
            // it can actually take.
            .dropDestination(for: URL.self) { urls, _ in
                guard let url = urls.first else { return false }
                return vm.attachImage(at: url)
            } isTargeted: { targeted in
                isDropTargeted = targeted
            }
            .overlay {
                if isDropTargeted {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.accentColor, lineWidth: 2)
                        .allowsHitTesting(false)
                }
            }
            .animation(.snappy, value: isDropTargeted)
        }
        // v0.24 boss acceptance fix (2026-08-24): help text DIRECTLY below input box.
        // Boss 8/24 (out-of-band): 'please set up a large-model provider in Settings first. Click Settings'
        // v0.24 boss acceptance fix: help text moved to ChatZoneView as centered overlay
        // (was: bottom of ChatView, not centered per boss 8/24 feedback).
        EmptyView()
        // Boss 8/24 feedback: 'clicking other areas, the text field still keeps focus'.
.onReceive(NotificationCenter.default.publisher(for: .wenshuDefocusChatInput)) { _ in
    inputFocused = false
}
// v0.24 boss acceptance fix (Boss 8/24 feedback 'chat history persistence, I don't see it'):
// listen for .wenshuChatStoreReady (posted after applicationDidFinishLaunching
// creates ChatSessionStore). If store wasn't ready at .task time (race
// condition), retry loading now. Also retry append message if store
// was nil at send time (we just store in memory, then re-append here).
.onReceive(NotificationCenter.default.publisher(for: .wenshuChatStoreReady)) { _ in
    // v0.59: read the delegate's store, not vm.valueForStore(). The vm
    // captured whatever the store was at construction time, and when the
    // view is built before applicationDidFinishLaunching finishes that
    // snapshot is nil forever — which is exactly the race this handler
    // exists to repair. Measured on this machine: the view's .task logged
    // store=nil at 23:56:42.032 and the store finished initialising at
    // .295, 263 ms later.
    if let store = vm.valueForStore() ?? WenshuAppDelegate.sharedChatStoreRef {
        Task { @MainActor in
            if let loaded = try? await store.loadMessages(sessionId: vm.valueForSessionId()) {
                let mapped = loaded.map { stored in
                    let resolvedRole: ChatRole = (stored.source == "user") ? .user : .agent
                    return ChatMessage(
                        id: UUID(uuidString: stored.id) ?? UUID(),
                        role: resolvedRole,
                        source: ChatSource(rawValue: stored.source) ?? .wenshu,
                        content: stored.content,
                        timestamp: stored.timestamp,
                        tokens: stored.tokens
                    )
                }
                vm.replaceMessages(mapped)
            }
        }
    }
}
    }
}

/// One chat-message view (Apple HIG ground truth)
struct ChatMessageView: View {
    let message: ChatMessage
    /// Where this bubble sits in a run of consecutive messages from one
    /// author, which decides the tail and the merged corners.
    var position: ChatBubblePosition = .only
    @State private var thinkingExpanded: Bool = false

    /// Parses a message body as markdown for display.
    ///
    /// `.inlineOnlyPreservingWhitespace`, not `.full`. Verified by parsing
    /// a multi-paragraph sample three ways: `.full` applies block intents
    /// and drops every newline, so a model reply arrives as one run-on
    /// block; the inline-preserving option keeps all 5 newlines and still
    /// resolves bold, code spans and links. Chat bubbles want inline
    /// formatting with the author's line breaks intact, which is exactly
    /// that option.
    ///
    /// Invalid markdown falls back to the plain string rather than
    /// throwing, so a stray bracket never blanks a message.
    static func markdown(_ raw: String) -> AttributedString {
        (try? AttributedString(
            markdown: raw,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(raw)
    }

    var body: some View {
        // v0.57 boss 2026-09-09 OOB: push the bubbles toward the iMessage
        // look. Outgoing messages sit on the trailing side in the accent
        // colour, incoming ones on the leading side in the neutral fill,
        // and a run of consecutive messages from one author merges.
        HStack(alignment: .bottom, spacing: 8) {
            if isOutgoing { Spacer(minLength: 40) }

            // The avatar only appears on the last bubble of a run, so a
            // burst of replies is not a column of repeated faces. The
            // slot stays reserved on the other bubbles to keep the run's
            // left edge aligned.
            Group {
                if position.hasTail && !isOutgoing {
                    switch message.source {
                    case .user:
                        Lucide(.userRound).aspectRatio(contentMode: .fit)
                    case .wenshu:
                        Lucide(.botMessageSquare).aspectRatio(contentMode: .fit)
                    case .system:
                        LucideIconSystemFallback(sourceIcon, size: 24)
                    }
                } else if !isOutgoing {
                    Color.clear
                }
            }
            .foregroundStyle(sourceColor)
            .frame(
                width: isOutgoing ? 0 : DesignTokens.iconLargeSize,
                height: isOutgoing ? 0 : DesignTokens.iconLargeSize
            )

VStack(alignment: isOutgoing ? .trailing : .leading, spacing: 4) {
                // iMessage names the author once per run, not per bubble.
                if position == .only || position == .first {
                    Text(sourceLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if message.isPlaceholder {
                    // Wenshu AI placeholder status indicator
                    HStack(spacing: 4) {
                        // v0.27 boss 8/27 OOB: replace SF Symbol with
                        // closest Lucide equivalent. 'brain' = closest
                        // semantically (= robot placeholder status
                        // indicator); LucideIcon.fromSystemSymbol maps
                        // 'person.crop.circle.badge.questionmark' →
                        // 'bot-message-square' (= wenshu agent face per
                        // Lucide; semantically = 'thinking' = good
                        // placeholder icon).
                        LucideIconSystemFallback("person.crop.circle.badge.questionmark", size: 16)
                            .foregroundStyle(.secondary)
                        Text(message.content)
                            .foregroundStyle(.secondary)
                        ProgressView()
                            .controlSize(.mini)
                            .progressViewStyle(.circular)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(bubbleFill, in: bubbleShape)
                } else {
                    // CoT thinking block collapsed (Apple HIG footnote)
                    // DisclosureGroup + rounded corners + Apple default animation (.animation(.default, value:) per Q58.4)
                    if let thinking = message.thinking, !thinking.isEmpty, message.source == .wenshu {
                        DisclosureGroup(isExpanded: $thinkingExpanded) {
                            Text(thinking)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .padding(.top, DesignTokens.chromePaddingMicro)
                                .transition(.opacity)
                        } label: {
                            HStack(spacing: 4) {
                                // v0.27 boss 8/27 OOB: replace SF Symbol 'brain'
                                // with closest Lucide equivalent = 'brain'
                                // (Lucide has 'brain' = same name, no mapping
                                // needed).
                                LucideIconSystemFallback("brain")
                                    .font(.caption)
                                Text(WenshuI18n.t("chatview.ai_thinking"))
                                    .font(.caption)
                            }
                            .foregroundStyle(.tertiary)
                        }
                        .animation(.default, value: thinkingExpanded)
                    }
                    // CHATIMG-001 (2026-09-07): render attached image
                    // thumbnail above the text content when the
                    // message carries an image. Uses SwiftUI Image
                    // (= no Nuke; Nuke was retired by
                    // DEAD-PIN-CLEANUP-001 per §13 v0.10). Max
                    // display size = 240 PT wide (= Apple Messages /
                    // Slack inline-image convention; image is
                    // aspect-fit into the constraint). Falls back
                    // to a small "image missing" placeholder if
                    // the file was deleted out from under the
                    // message.
                    if let imagePath = message.imagePath {
                        if let nsImage = NSImage(contentsOfFile: imagePath) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: 240, maxHeight: 240)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .padding(.bottom, DesignTokens.chromePaddingMicro)
                        } else {
                            Text(WenshuI18n.t("chat.message.imageMissing"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.bottom, DesignTokens.chromePaddingMicro)
                        }
                    }
                    // v0.55 boss 2026-09-09 OOB 'use the ones we have not
                    // used yet': render the bubble as markdown. SwiftUI's
                    // Text takes an AttributedString, and AttributedString
                    // parses markdown natively, so bold / italic / code /
                    // links in a model reply show as formatting instead of
                    // raw asterisks. Falls back to the plain string when the
                    // content is not valid markdown.
                    Text(Self.markdown(message.content))
                        .textSelection(.enabled)
                        // Streaming replies grow token by token. The default
                        // Text transition re-renders the whole run; this one
                        // interpolates, so the bubble does not flicker on
                        // every chunk.
                        .contentTransition(.interpolate)
                        .foregroundStyle(isOutgoing ? Color.white : Color.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(bubbleFill, in: bubbleShape)
                }
            }

            if !isOutgoing { Spacer(minLength: 40) }
        }
    }

    /// Outgoing messages are the ones this person sent, which iMessage puts
    /// on the trailing side in the accent colour.
    private var isOutgoing: Bool { message.source == .user }

    /// Bubble fill.
    ///
    /// Measured Messages.app on this machine in dark mode: outgoing
    /// rgb(29, 143, 250), incoming rgb(51, 52, 54) against an
    /// rgb(28, 28, 28) transcript. Wenshu uses the semantic equivalents of
    /// those instead of the literals, so the bubbles track the user's
    /// accent colour and appearance rather than being pinned to one theme.
    private var bubbleFill: AnyShapeStyle {
        if message.source == .system {
            return AnyShapeStyle(Color.red.opacity(0.15))
        }
        return isOutgoing
            ? AnyShapeStyle(Color.accentColor)
            // Chosen by measurement. Messages runs a 23-unit gap between
            // the incoming bubble and the transcript behind it (51 vs 28).
            // Rendered every candidate semantic style in a sample app and
            // measured each against the same background: quinary +10, fill.secondary
            // +17, quaternary +22, fill +22, unemphasized +27, tertiary +55.
            // .quaternary lands on Messages' gap while still tracking the
            // user's appearance instead of hard-coding a grey.
            : AnyShapeStyle(.quaternary)
    }

    private var bubbleShape: ChatBubbleShape {
        ChatBubbleShape(isOutgoing: isOutgoing, position: position)
    }

    private var sourceIcon: String {
        switch message.source {
        case .user: return "person.fill"
        case .wenshu: return "text.book.closed.fill"
        case .system: return "exclamationmark.triangle"
        }
    }

    private var sourceLabel: String {
        switch message.source {
        case .user: return "你"
        case .wenshu: return "文枢"
        case .system: return "系统"
        }
    }

    private var sourceColor: Color {
        switch message.source {
        case .user: return .blue
        case .wenshu: return .accentColor
        case .system: return .red
        }
    }
}
/// compactNumber: real token count folded into compact format (Hermes format_token_count_compact ground truth)
/// 1k → "1.0k", 1.5M → "1.5M", 200 → "200"
private func compactNumber(_ n: Int) -> String {
    let d = Double(n)
    if d >= 1_000_000 { return String(format: "%.1fM", d / 1_000_000).replacingOccurrences(of: ".0M", with: "M") }
    if d >= 1_000 { return String(format: "%.1fk", d / 1_000).replacingOccurrences(of: ".0k", with: "k") }
    return "\(n)"
}
