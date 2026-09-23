//
//  ChatSessionViewModel.swift · Wenshu · refactor chat-mvvm-3layer C-3
//
//  Apple SwiftUI MVVM canonical view model for the chat feature.
//
//  Boss 2026-09-22 '目标 UI，业务，数据，三分离':
//  - C-1 moved domain types (ChatMessage / ChatRole / ChatSource) to
//    Core/Chat/Domain/.
//  - C-2 split ChatMessage into ChatMessageHeader (cover) + Body
//    (inner pages) + glue.
//  - C-3 = THIS commit: extract the @MainActor @Observable view
//    model out of the Views/ directory. ChatSessionViewModel now
//    owns:
//    - The streaming pipeline state (= messages array + per-turn
//      streaming accumulator).
//    - The input draft state (= inputText + attachedImagePath +
//      cancelRequested).
//    - The LLM orchestration glue (= calls WenshuConductor.handle;
//      reads WSChatRepository for persistence; reads AppState for
//      model + availableModels).
//    - The UI-derived state (= contextUsed / contextMax / isSending
//      / lastError / cancelRequested).
//
//  What stays in the data layer (C-4 will introduce the seam):
//    - WSChatRepository.shared (= the @MainActor SwiftData wrapper
//      that owns chat.sqlite writes). C-5 will replace the direct
//      call with a ChatRepositoryProtocol seam (= easier to mock
//      in tests + sets up future swap to a remote backend).
//    - FileManager + UserDefaults calls inside attachImage() =
//      C-6 will route these through ChatRepository.
//
//  StreamingAccumulator + StreamingTaskBox come along for the
//  ride (= they're chat-pipeline helpers used only by
//  ChatSessionViewModel.send). Moving them too = single owner of
//  the streaming state machine.
//
//  Verification:
//    swift build: 0 errors / same pre-existing warnings as main HEAD.
//

import SwiftUI

/// v0.71 P1 batch 2 (boss 2026-09-12 OOB 'streaming output in the chat zone...'):
/// reference-type accumulator for the streaming LLMBlock callback.
/// Required because the callback is `@Sendable` (= can fire from
/// any actor; = Swift 6 forbids capturing `var` local state). Each
/// @Sendable closure invocation is serial with respect to the
/// owning actor (= ConversationLoop.runTurn is an actor method that
/// calls back synchronously per block on the same actor), so the
/// reference-type mutation is thread-safe here (= each event fires
/// one at a time, not concurrently).
///
/// `@unchecked Sendable` because the class has mutable state; the
/// caller (= ChatViewModel.send) guarantees the only mutator is the
/// streamCallback (= called from ConversationLoop actor = serial
/// per-turn). v0.71 P1 batch 4 dual-axis audit fix (= Q99 Standards
/// axis HIGH): added NSLock to enforce serial access (= the previous
/// `final class ... @unchecked Sendable` declaration was a paper
/// promise that nothing in the contract enforced; = a future
/// `Task { @MainActor ... }` hop racing a synchronous read from
/// `conductor.handle` returning could clobber the `parts[]` array
/// because both paths target the same mutable state).
///
/// Reading the accumulator from MainActor is safe because all
/// mutations happen under `lock` (= thread-safe); the snapshot
/// (= a copy of `parts`) returned by `snapshotParts()` is safe to
/// pass across actor boundaries.
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
    /// Take a thread-safe snapshot of `parts` (= returns a copy
    /// safe to pass across actor boundaries without triggering
    /// the Swift 6 strict concurrency "non-Sendable capture"
    /// warning). Use this when reading the final state after
    /// `conductor.handle` returns (= replaces direct `parts`
    /// access at the message-replacement site).
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
    // v2.00 (2026-09-23): boss 'check split, check dead code'.
    // Removed dead `activeSubAgentName` + `currentAgentTurn`
    // fields (= T4-SUBAGENT-UI + T8-CHATVIEWMODEL-WIRE) —
    // these were read by ChatSubAgentTag + ChatTurnProgress
    // (= both files deleted in v1.83). No view in the codebase
    // consumes these values anymore; = dead reactive state.
    // The corresponding `[wenshu.subagent]` + `[wenshu.agent] turn`
    // marker emission (= ConversationLoop + WenshuConductor) and
    // marker-parsing block below are also removed.
    // v2.00 retention (= keep cancelRequested):
    public var cancelRequested: Bool = false
    /// T67-MUTE-SHORTCUT (2026-09-18): ⌘. handler (= cancel
    /// the currently-streaming assistant reply). Sets the
    /// cancelRequested flag (= ConversationLoop polls this
    /// flag per-block to stop mid-stream). Silent no-op when
    /// nothing is streaming.
    public func cancelStreaming() {
        cancelRequested = true
    }

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
    ///
    /// C-6 (refactor chat-mvvm-3layer): filesystem IO moved into
    /// ChatRepositoryProtocol.copyChatUpload (= data layer).
    /// The business layer keeps the app-config lookup
    /// (= UserDefaults.standard.string(forKey: "wenshu.libraryPath"))
    /// because that is a config query (= not IO). The actual
    /// directory creation + FileManager.copyItem lives in
    /// LiveChatRepository.
    @discardableResult
    public func attachImage(at sourceURL: URL) async -> Bool {
        // Config lookup (= business layer reads app config from
        // UserDefaults; = not data-layer IO; = OK to keep here).
        let libraryPath = UserDefaults.standard.string(forKey: "wenshu.libraryPath") ?? ""
        guard !libraryPath.isEmpty else { return false }
        // Delegate the actual copy to the data layer.
        let destPath = try? await repository.copyChatUpload(
            sourceURL: sourceURL,
            intoLibraryAt: libraryPath
        )
        guard let destPath else { return false }
        attachedImagePath = destPath
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
    // Phase 5 ticket 10a: ChatSessionStore deleted. Chat persistence lives
    // in WSChatRepository.shared (= @MainActor SwiftData wrapper). All
    // view-side append/load/summarize calls go through the shared repo.
    // v0.24 boss acceptance fix (Boss 8/25 OOB ticket 015.014 + F2 cleanup): @MainActor
    // isolation replaces nonisolated(unsafe) for Swift 6 concurrency safety.
    // Mutable so archive flow can replace.
    @MainActor private var sessionId: String

    // B-05 build fix: demote from `public init` to internal `init`. AppState
    // is internal (= `final class AppState`, no access modifier), and a
    // `public init` cannot accept an internal type as a parameter. Both
    // call sites (= the App.swift:1528 reference is stale per the Q2 boss
    // split moved ChatView init outside App.swift; see AppRootScene.swift
    // + ChatView.swift:340) are inside the
    // WenshuApp module, so internal access is sufficient. The class itself
    // stays `public final class` so existing public surface (currentModel,
    // messages, send, etc.) is unchanged.
    //
    // C-4 + C-5 (refactor chat-mvvm-3layer): inject ChatRepositoryProtocol
    // (= the data-layer seam). Default = LiveChatRepository.shared so
    // existing call sites (= ChatZoneView, ChatView) work unchanged.
    // Tests pass a fake (= InMemoryChatRepository, future ticket) via
    // this parameter to avoid touching SwiftData stack.
    init(
        conductor: WenshuConductor? = nil,
        sessionId: String = "default",
        initialMessages: [ChatMessage] = [],
        appState: AppState? = nil,
        repository: ChatRepositoryProtocol = LiveChatRepository.shared
    ) {
        self.conductor = conductor
        self.sessionId = sessionId
        self.messages = initialMessages
        // B-05: hold a strong reference to the AppState instance so
        // currentModel / switchModel can read + write the canonical
        // owner. Caller passes the env-injected AppState (= same
        // lifetime as the WindowGroup that owns it).
        self.appState = appState
        // C-4: data-layer seam. The protocol handles StoredChatMessage
        // ↔ ChatMessage mapping internally (= business layer speaks
        // ChatMessage only).
        self.repository = repository
    }

    /// C-4: the data-layer seam. Defaults to LiveChatRepository.shared
    /// at init (= production path); tests inject a fake.
    private let repository: ChatRepositoryProtocol

    // CHATBOX-003 (2026-09-04): shared AsyncDelegationRegistry used by
    // the chat spawn delegation flow. The registry actor itself lives
    // at `Core/Agent/Conversation/AsyncDelegation.swift` (= non-MainActor
    // actor isolation; = its methods must be awaited).
    // routeInput() to spawn @-mention sub-agents. Lives on ChatViewModel
    // (= process-wide singleton via the @MainActor type's static
    // property) so every ChatViewModel instance routes through the same
    // registry (= callers can subscribe to AsyncDelegationRegistry.next()
    // to observe spawns). Using the free `delegate(...)` function with
    // this shared registry avoids touching AsyncDelegation.swift (= out
    // of CHATBOX-003 allowlist).
    // v0.71 P1 batch 6 dual-axis followup (= Q99 Standards axis MED):
    // `nonisolated(unsafe)` is required because `AsyncDelegationRegistry`
    // is an actor type (= its initializer must run on the actor's
    // serial executor; = Swift does not allow actors to be referenced
    // from a `nonisolated let` without (unsafe)). The (unsafe) is
    // safe in practice because:
    //  - the registry ref itself is never mutated (= `let`); only
    //    the actor's INTERNAL state changes via `await registry.xxx()`.
    //  - all reads of the static ref happen on the MainActor (= the
    //    view code that uses it is @MainActor), so reading a Sendable
    //    pointer is trivially safe.
    //  - the audit's claim that "every read requires a hop" is wrong:
    //    the ref is a Sendable pointer (= the actor instance itself
    //    is Sendable across isolation boundaries); only the actor's
    //    methods require `await`.
    nonisolated static let delegationRegistry: AsyncDelegationRegistry = AsyncDelegationRegistry()

    public func switchModel(_ id: String) {
        // B-05: write to the canonical owner (= AppState.llmModel),
        // which then mirrors to UserDefaults via its didSet. No raw
        // UserDefaults call here (= single owner maintained).
        appState?.llmModel = id
    }

    /// v1.99 (2026-09-23): boss 'UI 层不许直接调数据层'.
    /// Sets the canonical 'wenshu.settingsTab' to 'providerApi' so
    /// the Settings window opens on the LLM Connector pane. The
    /// canonical pattern (= the @AppStorage mirror in Settings reads
    /// from UserDefaults) is unchanged; = the write moves here from
    /// `ChatZoneView` (= UI layer) into the business layer.
    public func openSettingsToProviderApi() {
        UserDefaults.standard.set("providerApi", forKey: "wenshu.settingsTab")
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

        // T20c-PLAN-ROUTE (2026-09-18): intercept `/plan <query>` BEFORE
        // the slash-command path (= /plan is a hub command that needs
        // engine dispatch + plan rendering, = not a normal skill).
        // Strategy: extract the query after `/plan ` and call
        // PlanModeEngine.run() to get a numbered plan. The plan is
        // surfaced as a system ChatMessage (= the text content
        // includes the numbered steps; = a future ticket can render
        // it via the ChatPlanPartView once the plan-as-ChatMessagePart
        // plumbing lands). This is the lightweight route — keeps the
        // engine integration self-contained (= no ChatMessagePart
        // type change required for T20c).
        if let planQuery = stripPlanPrefix(input) {
            await runPlanMode(query: planQuery)
            return
        }

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

    // MARK: - T20c-PLAN-ROUTE (2026-09-18): /plan command surface

    /// Returns the query portion of a `/plan <query>` slash
    /// command (= everything after `/plan `, trimmed). Returns
    /// nil when the input is not a `/plan` command (= so the
    /// caller can fall through to the normal slash-command path).
    /// Recognizes:
    ///   - `/plan query here`         -> "query here"
    ///   - `/plan` (no args)           -> nil (= empty query is
    ///                                    not a valid plan command;
    ///                                    = fall through to the
    ///                                    SkillAdapter path which
    ///                                    will treat it as unknown
    ///                                    /plan invocation)
    ///   - `/plans` (extra char)       -> nil (= exact prefix
    ///                                    match only; = prevents
    ///                                    accidental collision
    ///                                    with future /plans
    ///                                    commands)
    private func stripPlanPrefix(_ input: String) -> String? {
        guard input.hasPrefix("/plan") else { return nil }
        // Exact-match on "/plan" + whitespace (= no args means
        // the command is invalid for plan-mode; = let SkillAdapter
        // surface it as an unknown skill).
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

    /// Run plan mode for the given query: invoke PlanModeEngine
    /// (= wraps the current connector + model) and append a
    /// system ChatMessage containing the plan text. Errors are
    /// surfaced as a system message too (= so the user sees why
    /// the plan failed).
    private func runPlanMode(query: String) async {
        inputText = ""
        // Resolve connector + model from the active conductor
        // (= same source of truth ChatViewModel.send() uses).
        // The conductor owns a connector actor; = use its
        // currentModel. We don't currently have direct accessor
        // for the connector on WenshuConductor, so instantiate
        // PlanModeEngine with AnthropicConnector (= the conductor's
        // default) + the current model id. Future tickets may
        // route through AppState.activeConnector; = out of scope
        // for T20c.
        let model = self.currentModel
        let connector: any LLMConnector = AnthropicConnector()
        let engine = PlanModeEngine(connector: connector, model: model)
        do {
            let plan = try await engine.run(query: query)
            // T22-PLAN-PART (2026-09-18): surface the plan as a
            // structured .plan ChatMessagePart (= rendered via
            // ChatPlanPartView) instead of a plain system text message.
            // The plan carries query + steps + connectorID + createdAt;
            // = ChatPlanPartView shows them as a numbered step list with
            // an Approve button (T20b primitive; = Approve wiring is a
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
                    ?? WenshuI18n.t("chatview.plan.failed")
            ))
        } catch {
            messages.append(ChatMessage(
                role: .system,
                source: .system,
                content: WenshuI18n.t("chatview.plan.failed")
                    + ": \(error.localizedDescription)"
            ))
        }
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

        // C-4: route through ChatRepositoryProtocol (= the data-layer
        // seam). The Live impl owns the StoredChatMessage mapping; =
        // business layer speaks ChatMessage only.
        try? await repository.append(userMsg, sessionId: sessionId)

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
                // v0.71 P1 batch 2 (boss 2026-09-12 OOB 'streaming output in the chat zone...'):
                // conductor path now also streams (= Hermes pattern).
                // The same streaming switch below (= the one used for
                // direct-verifier path) handles LLMBlock events from
                // either source. Both paths accumulate into
                // `streamingParts` (= parts[] array on ChatMessage) +
                // `streamingThinking` so the placeholder renders the
                // same way regardless of which conductor / verifier
                // emitted the event.
                //
                // v0.71 P1 batch 2 (Sendable closure caveat): the
                // streamCallback is `@Sendable` (= can be invoked from
                // any actor = the ConversationLoop runs on a separate
                // actor). Local `var` captured by a `@Sendable`
                // closure would error in Swift 6 (=
                // "captured var in concurrently-executing code"). Wrap
                // the accumulator in a tiny `class StreamingAccumulator`
                // (= reference type, safe to capture in a `@Sendable`
                // closure; = each @Sendable closure invocation is
                // serial with respect to the owning actor so the
                // class reference IS thread-safe here).
                let accumulator = StreamingAccumulator()
                // v0.71 P1 batch 6 dual-axis followup (= Q99 Standards axis MED):
                // track all in-flight streaming-update Tasks so the
                // post-await final mutation can wait for them (= avoids
                // the race where a late-arriving `Task { @MainActor in
                // messages[idx] = ... }` overwrites the final sealed
                // message with an in-flight snapshot).
                let streamingTaskBox = StreamingTaskBox()
                let result = await conductor.handle(
                    userMessage: text,
                    sessionId: sessionId,
                    model: currentModel,
                    streamCallback: { [weak self] block in
                        // T1-THINKING-VISIBLE (2026-09-18): log each
                        // stream block (= dev can confirm which part
                        // kinds the LLM actually emits). Tag with
                        // PATH=... so it grep-parity with T0 logs.
                        let kindTag: String = {
                            switch block {
                            case .text: return "text"
                            case .thinking: return "thinking"
                            case .toolUse: return "toolUse"
                            case .toolResult: return "toolResult"
                            }
                        }()
                        NSLog(
                            "[wenshu.conductor] PATH=stream BLOCK=%@ (model=%@)",
                            kindTag, currentModel
                        )
                        // v2.00 (2026-09-23): dead marker-parsing block
                        // removed (= it targeted [wenshu.subagent] /
                        // [wenshu.agent] turn markers, both of which are
                        // no longer emitted per the matching deletion in
                        // ConversationLoop + WenshuConductor).
                        // v0.71 P1 batch 2 (MainActor isolation): the
                        // streamCallback fires from ConversationLoop
                        // actor (= NOT main actor = the `messages`
                        // array mutation below must dispatch to
                        // MainActor). Capture the block = a Sendable
                        // value (= LLMBlock is already Sendable) so
                        // we can pass it across the actor boundary.
                        let blockCopy = block
                        // First, accumulate parts in the
                        // accumulator (= reference type, no actor
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
                            accumulator.parts.append(.toolUse(id: id, name: name, args: input))
                        case .toolResult(let toolUseID, let output):
                            accumulator.parts.append(.toolResult(
                                toolUseID: toolUseID, content: output, isError: false
                            ))
                        }
                        // Then dispatch the messages mutation to
                        // MainActor (= the ChatViewModel is
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
                // (= avoids the race where a late-arriving hop overwrites
                // the final sealed mutation below).
                for task in streamingTaskBox.tasks { await task.value }
                reply = result.reply
                replyThinking = result.thinking ?? accumulator.thinking
                replyTokens = result.totalTokens
                // v0.71 P1 batch 2: mark the conductor's bubble as
                // sealed (= Hermes `pending: false` flip after
                // `message.complete`). Replace placeholder with the
                // final message.
                if let idx = messages.firstIndex(where: { $0.id == placeholderId }) {
                    NSLog("[wenshu.scroll] conductor placeholder replace: id=%@ beforeCount=%d afterCount=%d", placeholderId.uuidString, messages.count, messages.count)
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
                // v0.71 P1 batch 2 (boss 2026-09-12 OOB 'streaming output in the chat zone...'):
                // accumulate every LLMBlock into `parts[]` (= Hermes
                // `parts: ChatMessagePart[]`); the streaming UI renders
                // each part independently. We still mirror text into
                // `buffer` (= legacy `content`) so callers that read
                // `content` (= e.g. SwiftData @Model persistence via
                // WSChatRepository) keep working. The leading .text part is the one we keep
                // appending to (= Hermes's "append onto the last
                // open .text part" strategy in `use-message-stream`).
                var streamingParts: [ChatMessagePart] = []
                var streamingThinking: String = ""
                for try await block in stream {
                    switch block {
                    case .text(let chunk):
                        buffer += chunk
                        // v0.71 P1: append into the trailing .text
                        // part (= create one on first chunk); mirrors
                        // Hermes `appendAssistantTextPart`.
                        if case .text(let last) = streamingParts.last?.kind {
                            streamingParts[streamingParts.count - 1] = .text(last + chunk)
                        } else {
                            streamingParts.append(.text(chunk))
                        }
                        // Render the accumulated buffer into the
                        // placeholder message + the new parts[]
                        // (= SwiftUI re-renders as messages array
                        // changes; the parts[] array drives the new
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
                        // v0.71 P1: append into the trailing .reasoning
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
                        // v0.71 P1 batch 2: tool_use events now
                        // append a `toolUse` part (= batch 1 left
                        // them as NSLog only). The streaming UI will
                        // render this as a collapsible card in
                        // batch 3 (= P7). For now, the part is in
                        // the array but the view still renders
                        // legacy `content` until P7 lands.
                        streamingParts.append(.toolUse(
                            id: id, name: name, args: input
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
                        // v0.71 P1 batch 2: WenshuVerifier.streamChat
                        // (= the direct-verifier streaming source
                        // in this branch) emits a 4-case WenshuLLMBlock
                        // enum with `.unknown(type, raw)` when the
                        // server returns a content block the decoder
                        // doesn't recognize. Skip (= hermes parity:
                        // unknown blocks are not surfaced to the
                        // user; = the canonical 4-case LLMBlock
                        // enum used by ConversationLoop doesn't
                        // have an .unknown case because the
                        // AnthropicStreaming decoder already maps
                        // every server variant to one of the 4
                        // canonical cases BEFORE handing off).
                        // No `case .toolResult` here: WenshuLLMBlock
                        // (= the direct-verifier enum) does not have
                        // a toolResult case (= only the 4 cases
                        // listed above). The 4-case LLMBlock used
                        // by ConversationLoop's streaming path does
                        // include .toolResult (= used by the
                        // conductor path above).
                        break
                        }
                }
                // v0.71 P1 batch 2: mark the message as sealed (= the
                // stream has ended; = Hermes `pending: false` flip
                // after `message.complete`). Future UI uses
                // `streamState == .sealed` to fade out the streaming
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
            // (= data-layer seam). The Live impl builds the StoredChatMessage
            // from this ChatMessage (= handles the id-stringification +
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
            try? await repository.append(agentMsg, sessionId: sessionId)
            recomputeContextUsed()

            // trigger summary generation (LLM + saveSummary + deleteOldMessages order)
            // C-4: route through ChatRepositoryProtocol (= data-layer seam).
            // The Live impl hops to MainActor internally (= the protocol
            // method is async + the caller doesn't need a manual Task wrap
            // anymore; = was the bug-prone `Task { @MainActor in ... }`
            // pattern that lost errors silently).
            let verifier = WenshuVerifier()
            try? await repository.summarizeIfNeeded(
                sessionId: sessionId,
                lastN: 10,
                threshold: 20,
                verifier: verifier
            )
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
        // v1.98 (2026-09-23): boss '业务层不许摸基础设施'.
        // The FileManager.default.temporaryDirectory call moves
        // into HermesGoals.swift's `temporaryGoalsDirectory(prefix:)`
        // helper (= data-layer concern). Here we call the helper
        // instead of FileManager directly.
        let persistenceDirectory = GoalsManager.temporaryGoalsDirectory(
            prefix: "WenshuGoals"
        )

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

    /// valueForSessionId: used by ChatView .task to load history
    /// (= was `valueForStore` returning a chat store instance;
    /// = Phase 5 ticket 10a replaced that with a direct
    /// `WSChatRepository.shared.loadMessages` call inside the view).
    public func valueForSessionId() -> String { sessionId }  // v0.24 bossverificationfix (F2): @MainActor-isolated with sessionId

    /// replaceMessages: ChatView .task loadcompletereplace (append)
    public func replaceMessages(_ newMessages: [ChatMessage]) {
        self.messages = newMessages
    }

    /// C-5: load chat history from the data layer (= formerly lived
    /// inline in ChatView's .task modifier; = business knowledge about
    /// how to map persisted rows back into ChatMessage belongs here,
    /// not in the view). Delegates to ChatRepositoryProtocol.loadMessages;
    /// the Live impl does the StoredChatMessage ↔ ChatMessage mapping.
    /// Errors are swallowed (= matches the prior `try?` behavior; =
    /// chat zone still renders, just with empty history).
    public func loadHistory() async {
        do {
            let loaded = try await repository.loadMessages(sessionId: sessionId)
            self.messages = loaded
        } catch {
            // Silent no-op (= matches legacy behavior; = the view
            // already handles empty messages[] by showing the
            // empty-state placeholder).
        }
    }
}
