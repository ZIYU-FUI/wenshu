//
import Foundation
import os.log
import WenshuAgent
import WenshuData

// A reference-type accumulator for the streaming LLMBlock callback. It is a
// reference type because the callback is @Sendable, and the value
// `snapshotParts()` returns is safe to pass across actor boundaries.

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

    /// Takes a thread-safe snapshot of `parts` (= a copy that is safe to pass
    /// across the actor boundary at the message-replacement site).
    func snapshotParts() -> [ChatMessagePart] {
        lock.lock(); defer { lock.unlock() }
        return _parts
    }

    func snapshotThinking() -> String {
        lock.lock(); defer { lock.unlock() }
        return _thinking
    }

    /// Append text to the trailing text part, or start one.
    ///
    /// The streaming path used to rebuild the whole parts array per chunk,
    /// which copied every part written so far on every chunk. Appending in
    /// place keeps the cost proportional to the new text.
    func appendText(_ chunk: String) {
        guard !chunk.isEmpty else { return }
        lock.lock(); defer { lock.unlock() }
        if case let .text(last)? = _parts.last?.kind {
            _parts[_parts.count - 1] = .text(last + chunk)
        } else {
            _parts.append(.text(chunk))
        }
    }

    /// The reply text accumulated so far.
    func accumulatedText() -> String {
        lock.lock(); defer { lock.unlock() }
        return _parts.compactMap { part in
            if case let .text(text) = part.kind {
                return text
            }
            return nil
        }.joined()
    }

    /// Move a completed trace marker out of the reply text.
    ///
    /// The model wraps its reasoning in a marker so the reader sees the
    /// reasoning as a separate block rather than as part of the answer. The
    /// marker is complete only once its closing bracket has arrived, so the
    /// check is made on the accumulated text each time the view updates.
    ///
    /// Until the marker is complete the text shows as it arrives, which
    /// includes the opening bracket. The alternative (= hiding the text
    /// until the marker closes) would hide the reply's beginning for as
    /// long as the reasoning takes, which is worse.
    func liftTraceMarker() {
        lock.lock(); defer { lock.unlock() }
        // A model that marks only its steps (= no thinking marker) still
        // gets them lifted, so the condition looks for any of the markers.
        guard let textIndex = _parts.firstIndex(where: { part in
            if case let .text(text) = part.kind {
                return text.contains("[[thinking:")
                    || text.contains("[[action:")
                    || text.contains("[[result:")
            }
            return false
        }) else { return }
        guard case let .text(text) = _parts[textIndex].kind else { return }

        // The whole segment is scanned, not only the thinking marker: the
        // step markers sit after it, in the same text run, and leaving them
        // in the body would show the reader the raw markers.
        let trace = MessageContent.extractTraceTags(from: text)
        guard !trace.thinking.isEmpty || !trace.steps.isEmpty else { return }

        // The trace becomes a reasoning part; the answer stays a text part.
        _parts.remove(at: textIndex)
        var content = trace.thinking
        if !trace.steps.isEmpty {
            content += (content.isEmpty ? "" : "\n") + trace.steps
        }
        _parts.insert(.reasoning(content), at: textIndex)
        let remainder = trace.cleaned
        if !remainder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            _parts.insert(.text(remainder), at: textIndex + 1)
        }
    }

    /// Append reasoning to the trailing reasoning part, or start one.
    func appendReasoning(_ chunk: String) {
        guard !chunk.isEmpty else { return }
        lock.lock(); defer { lock.unlock() }
        if case let .reasoning(last)? = _parts.last?.kind {
            _parts[_parts.count - 1] = .reasoning(last + chunk)
        } else {
            _parts.append(.reasoning(chunk))
        }
        _thinking += chunk
    }

    /// Append a discrete part (= a tool call or a tool result).
    ///
    /// These never coalesce: the user is watching for the boundary between
    /// one tool finishing and the next starting.
    func appendPart(_ part: ChatMessagePart) {
        lock.lock(); defer { lock.unlock() }
        _parts.append(part)
    }
}

/// The chat-area receipt for a background task (= names the handle,
/// never the role; = the board and the activity feed keep the role).
enum ChatSubAgentReceipt {
    /// Receipt for a started task (= the handle is the user's only
    /// reference to the background task).
    static func dispatched(handleID: String, bundle: Bundle = .main) -> String {
        String.localizedStringWithFormat(
            String(localized: "chatview.subagent.dispatched", bundle: bundle),
            handleID
        )
    }

    /// Receipt for a failed task (= the cause is the role-free
    /// user-facing text; = the role stays on the board).
    static func failed(error: Error, bundle: Bundle = .main) -> String {
        let cause = UserFacingError.from(error).errorDescription
            ?? String(localized: "error.unknown", bundle: bundle)
        return String.localizedStringWithFormat(
            String(localized: "chatview.subagent.dispatch_failed", bundle: bundle),
            cause
        )
    }
}

/// ChatViewModel: state management (Apple Observable + WSChatRepository + WenshuConductor)
@MainActor
@Observable
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var inputText: String = ""
    // Absolute path of an image the user attached via the chat input row's
    // paperclip button (= draft state). When non-nil, a small preview chip is
    // rendered above the TextField; on send the path is moved into the
    // ChatMessage and the draft is cleared. nil = no pending image.
    var attachedImagePath: String?
    var isSending: Bool = false
    var lastError: String?

    /// Run the librarian's `curate` procedure and show what it found.
    ///
    /// The run is deterministic (= the analyser's own code, = no
    /// model), = and it reports; = it never deletes. = The report
    /// lands in the conversation as the librarian's own message, =
    /// because it is the librarian's output, = and it is written to
    /// the session as well, = because a report the user has to run
    /// again after a restart is a report that reads as never having
    /// happened.
    private func runCuration() async {
        let runner = LibrarianCurationRunner(
            library: await ReferenceLibraryTool.shared.libraryActor
        )
        let outcome = await runner.run()

        let content: String
        switch outcome {
        case .reported(let report):
            content = LibrarianCurationRunner.text(for: report)
        case .failed(let reason):
            content = "The curation run could not read the library: \(reason)"
        }

        let message = ChatMessage(
            role: .agentResult,
            source: .agentResult,
            content: content
        )
        messages.append(message)

        // Persist it, = so the report survives a restart.
        try? await repository.append(message, sessionId: sessionId, bookID: currentBookID)
    }

    /// Write one coalesced batch into the streaming message.
    ///
    /// The accumulator is updated in place, and the message is rebuilt once
    /// from the accumulated parts. Rebuilding is cheap here because the
    /// accumulator already holds the finished text: the cost that used to
    /// matter was re-parsing and re-copying per token, and that is gone.
    func applyStreamBatch(
        _ batch: StreamBatch,
        placeholderId: UUID,
        accumulator: StreamingAccumulator
    ) {
        if !batch.text.isEmpty {
            accumulator.appendText(batch.text)
        }
        if !batch.reasoning.isEmpty {
            accumulator.appendReasoning(batch.reasoning)
        }
        // The trace marker is lifted once it is complete, so the reader
        // sees the reasoning as its own block rather than as part of the
        // answer.
        accumulator.liftTraceMarker()
        for block in batch.blocks {
            switch block {
            case let .toolUse(id, name, input):
                accumulator.appendPart(.toolUse(id: ToolCallID(rawValue: id), name: name, args: input))
            case let .toolResult(toolUseID, output):
                accumulator.appendPart(.toolResult(toolUseID: ToolCallID(rawValue: toolUseID), content: output, isError: false))
            case .text, .thinking:
                break
            }
        }
        guard let idx = messages.firstIndex(where: { $0.id == placeholderId }) else { return }
        // The message is updated in place rather than replaced. Replacing
        // an element of the observed array tells the view that the row
        // is a different row, so the row is rebuilt on every frame: the
        // text jumps, the animations restart, and the reader sees a
        // flicker. Writing the changed fields of the same message keeps
        // the row's identity, so only the text is drawn again.
        messages[idx].content = ChatMessagePart.joinedText(accumulator.parts)
        messages[idx].thinking = accumulator.snapshotThinking()
        messages[idx].parts = accumulator.snapshotParts()
        messages[idx].streamState = .streaming
    }

    /// The coalescing buffer for the reply in flight.
    ///
    /// It exists only while a turn is streaming. Its flush handler writes
    /// the accumulated text into the streaming message, so the view sees one
    /// update per frame instead of one per token.
    @ObservationIgnored
    private var streamBuffer: StreamBuffer?
    /// 'check split, check dead code'. Removed dead `activeSubAgentName` +
    /// `currentAgentTurn` fields —
    /// these were read by ChatSubAgentTag + ChatTurnProgress (. both files
    /// deleted). No view in the codebase consumes these values anymore; = dead
    /// reactive state. The corresponding `[wenshu.subagent]` + `[wenshu.agent]
    /// turn` marker emission (= ConversationLoop + WenshuConductor) and
    /// marker-parsing block below are also removed. retention (= keep
    /// cancelRequested):
    var cancelRequested: Bool = false
    /// Cancels the streaming reply (= the ⌘. handler). It is a no-op when
    /// nothing is streaming.
    func cancelStreaming() {
        cancelRequested = true
    }

    /// Copies the picked file into the library's attachment folder. The copy
    /// itself is delegated to the data layer (= LiveChatRepository).
    @discardableResult
    func attachImage(at sourceURL: URL) async -> Bool {
        // Config lookup: the business layer reads the app config from
        // `ActiveLibrary` (= the canonical single source of truth for the `.ws`
        // library URL, bound to the security-scoped bookmark via
        // `LibraryBookmark`). This is a config query (= not IO); the directory
        // creation and the file copy live in `LiveChatRepository`.
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

    /// Clears the pending image draft (= called when the user clicks the small ✕
    /// on the preview chip, or after the send).
    func clearAttachedImage() {
        attachedImagePath = nil
    }

    /// The model id was scattered across several reads and writes (4 `@AppStorage`
    /// and 3 raw `UserDefaults`); the canonical owner is now `AppState.llmModel`,
    /// and this property reads it.
    private let appState: AppState?
    /// When no `AppState` is injected (= a standalone `ChatViewModel` initialised
    /// without the app-wide environment), the model id defaults to the empty
    /// string read straight from `UserDefaults`, so the model picker shows nothing
    /// rather than a hard-coded model. The pattern is locked down by
    /// `ChatViewModelDefaultModelTests`.
    var currentModel: String {
        let raw = appState?.llmModel
            ?? UserDefaults.standard.string(forKey: "wenshu.llm.model")
            ?? ""
        // The model selection can be empty (= the first launch with no
        // `UserDefaults` entry AND no appState wiring). The chat would then send
        // a POST with an empty `model`, which the provider rejects with HTTP 400,
        // so the SSE stream emits no events and the chat bubble stays empty. Fall
        // back to the active provider's first default model (= the canonical
        // "this is the model the user configured" pick).
        if !raw.isEmpty {
            return raw
        }
        let activeSlug = WenshuAppDelegateLLMHelpers.activeConnectorSlug()
        let provider = Provider.by(slug: activeSlug)
        if let firstDefault = provider?.defaultModels.first, !firstDefault.isEmpty {
            return firstDefault
        }
        return "MiniMax-M3"
    }

    var availableModels: [String] = []
    var contextUsed: Int = 0
    /// The context window of the active model, in tokens. The provider's published
    /// figure is 1,000,000; the public endpoint enforces a lower input cap than
    /// the published one, so a turn larger than that may be refused by the vendor.
    /// The budget here follows the published figure, so context budgeting matches
    /// the documentation. The provider's model list does not report a context
    /// length, so there is no field to query.
    var contextMax: Int = 1_000_000

    /// The conductor the chat path runs the turn on. It is patched when the
    /// AppDelegate publishes one: a chat hung because the field was still nil at
    /// the moment the user pressed send.
    ///
    /// The chat hung for 20 seconds: the SwiftUI @State ChatViewModel
    private var conductor: WenshuConductor?
    // Chat persistence lives in `WSChatRepository.shared` (= a
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // Mutable so the archive flow can replace the session id.
    // The adopter that takes in a sub-agent's results.
    //
    // It is a stored property, = not a local, = because it holds the
    // ids being taken in right now, = and a local would be a fresh
    // copy every time (= so two notifications for the same result
    // would both take it in).
    private var resultAdopter: SubAgentResultAdopter

    @MainActor private var sessionId: SessionID

    // Current scope bookID for all persistence calls. nil = global un-attached (=
    // the previous default; = used when no book is selected, e.g.
    // onboarding-before-book-selection chats). The view layer is expected to call
    // setCurrentBookID(_:) when the user picks a different book so the chat panel
    // reloads against the new scope. Until the view wires this up:
    // BookID brand wrapper.
    @MainActor var currentBookID: BookID?

    /// Whether any provider holds a key. Nil asks the facade (= production);
    /// a closure lets a test state the answer instead of inheriting whatever
    /// happens to be in the developer's keychain.
    private let providersConfigured: (@Sendable () async -> Bool)?

    /// Updates the active scope (= called by the view layer when the user picks a
    /// book). It sets the session id and reloads the history. It is a no-op when
    /// the bookID is unchanged.
    func setCurrentBookID(_ bookID: BookID?) {
        if currentBookID == bookID {
            return
        }
        currentBookID = bookID
        // Per-book session id: same key prefix + bookID suffix so the global
        // session rows and the per-book session rows can coexist in the same
        // SwiftData store (= the WSChatMessage.bookID column is what scopes
        // reads, not the session id).
        sessionId = Self.makeSessionID(for: bookID)
        // Fire-and-forget reload against the new scope.
        Task { await self.loadHistory() }
    }

    /// Build fix: demote from `public init` to internal `init`. `AppState` is
    /// internal (= `final class AppState`, no access modifier), and a `public
    /// init` cannot accept an internal type as a parameter. Both call sites (= see
    /// `AppRootScene.swift` + `ChatView.swift` init) are inside the `WenshuApp`
    /// module, so internal access is sufficient. The class itself stays `public
    /// final class` so existing public surface (`currentModel`, `messages`,
    /// `send`, etc.) is unchanged. Inject `ChatRepositoryProtocol` (= the
    /// data-layer seam). Default = `LiveChatRepository.shared` so existing call
    /// sites (= `ChatZoneView`, `ChatView`) work unchanged. Tests pass a fake via
    /// this parameter to avoid touching SwiftData stack.
    init(
        conductor: WenshuConductor? = nil,
        sessionId: SessionID = SessionID(rawValue: "default"),
        initialMessages: [ChatMessage] = [],
        appState: AppState? = nil,
        repository: ChatRepositoryProtocol = LiveChatRepository.shared,
        bookID: BookID? = nil,
        // Whether a provider is configured. Injected for the same reason the
        // repository is: `loadHistory` shows an empty state when nothing is
        // configured, and a test cannot make that decision for itself because the
        // real answer comes from the keychain.
        providersConfigured: (@Sendable () async -> Bool)? = nil
    ) {
        // The public facade is the canonical source of truth for the conductor:
        // when no conductor is injected, resolve it from the facade (= the same
        // value the shared conductor static forwards to).
        self.conductor = conductor ?? WenshuAgent.shared.currentConductorSync()
        // Per-book session id when bookID is set (= the SwiftData store keys
        // sessions by sessionID; = a unique per-book session id keeps chat rows
        // cleanly partitioned).
        self.sessionId = Self.makeSessionID(for: bookID, fallback: sessionId.rawValue)
        currentBookID = bookID
        messages = initialMessages
        self.providersConfigured = providersConfigured
        // Hold a strong reference to the AppState instance so currentModel /
        // switchModel can read + write the canonical owner. Caller passes the
        // env-injected AppState (= same lifetime as the WindowGroup that owns
        // it).
        self.appState = appState
        // Data-layer seam. The protocol handles StoredChatMessage ↔ ChatMessage
        // mapping internally (= business layer speaks ChatMessage only).
        self.repository = repository
        self.resultAdopter = SubAgentResultAdopter(repository: repository)
        // Boss 2026-10-19 mac-mini reproducer (= chat
        // hang "AI 思考中 20s"): SwiftUI evaluates the
        // chat zone body BEFORE
        // `applicationDidFinishLaunching` runs; = the
        // `currentConductorSync` snapshot is nil at that
        // moment (= the AppDelegate hasn't called
        // `installConductorSync` yet). Subscribe here
        // (= at the end of init so all stored fields are
        // initialized before the observer closure is
        // allocated; = Swift 6 strict-init avoids
        // "self.x used before initialized" warnings)
        // so the conductor is patched in the moment the
        // AppDelegate publishes it.
        // A sub-agent's result landed in a conversation.
        //
        // The messages this model holds are a snapshot, and the
        // snapshot does not contain a result that landed after it was
        // taken. = The result is on disk, = and the user is looking
        // at a conversation that does not show it. = This observer
        // closes that: = the session that asked for the work gets
        // the answer appended, = and no other session does.
        NotificationCenter.default.addObserver(
            forName: Notification.Name(AppStateEvents.subAgentResultDelivered.rawValue),
            object: nil,
            queue: nil
        ) { [weak self] notification in
            // The values are taken out of the notification here, =
            // because the notification itself is not Sendable and = a
            // main-actor call cannot take one across the boundary.
            //
            // The queue is nil and not .main, = so the closure runs on
            // the thread that posted. = The delivery is main-actor
            // isolated, = so the posting thread is the main actor, =
            // and a `queue: .main` delivery would then wait for the
            // main RUN LOOP to turn before the hop below even
            // started. = A run loop that is busy (= a test suite
            // running many conversations, = or an app under load) =
            // turns late, = and the result sat in the repository
            // while the conversation that asked for it showed
            // nothing. = The hop below is the isolation guarantee, =
            // and it is the same pattern the observer above uses.
            let sessionID = notification.userInfo?["sessionID"] as? String
            let messageID = notification.userInfo?["messageID"] as? String
            Task { @MainActor [weak self] in
                await self?.adoptDeliveredSubAgentResult(sessionID: sessionID, messageID: messageID)
            }
        }

        NotificationCenter.default.addObserver(
            forName: .wenshuConductorInstalled,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // The notification can be posted from any thread, and
            // `queue: .main` is a delivery detail, not an isolation
            // guarantee: the hop below is what makes the main-actor
            // write legal, so changing the queue cannot turn this
            // into a data race.
            Task { @MainActor [weak self] in
                self?.adoptInstalledConductor()
            }
        }
    }

    /// Adopt the conductor the AppDelegate published.
    ///
    /// Main-actor isolated, because the property it writes is.
    @MainActor
    private func adoptInstalledConductor() {
        // Re-resolve the snapshot (= the notification
        // is a signal; the canonical value lives in
        // the lock-protected snapshot). Defensive
        // `??` keeps a previously-captured reference
        // (= the AppDelegate may re-install the same
        // conductor across lifecycle paths; = the
        // snapshot value is identical; = no churn).
        conductor = WenshuAgent.shared.currentConductorSync() ?? conductor
    }

    /// Builds a per-book session id. It returns `book:<id>:default` when scoped
    /// to a book, and `default` when it is not, so every turn of the same book
    /// hits the same SwiftData row.
    static func makeSessionID(for bookID: BookID?, fallback: String = "default") -> SessionID {
        guard let bookID else { return SessionID(rawValue: fallback) }
        return SessionID(rawValue: "book:\(bookID.rawValue):\(fallback)")
    }

    /// The data-layer seam. It defaults to LiveChatRepository.shared at init (=
    /// the production path); the tests inject a fake.
    private let repository: ChatRepositoryProtocol

    func switchModel(_ id: String) {
        // Write to the canonical owner (= AppState.llmModel), which then mirrors
        // to UserDefaults via its didSet. No raw UserDefaults call here (= single
        // owner maintained).
        appState?.llmModel = id
    }

    /// Opens the settings pane at the provider's API section. The UI layer must
    /// not call the data layer directly: the canonical route is the ChatZoneView,
    /// which is the UI layer, into the business layer.
    func openSettingsToProviderApi() {
        UserDefaultsStore.shared.setString("providerApi", forKey: .settingsTab)
    }

    func loadAvailableModels() async {
        // Use multi-provider discovery (= query all configured
        // `WenshuLLMModel.allCases` = 3 MiniMax-only cases).
        //
        // The optional models are read from the API, never written down:
        // use the live `loadLive()` (= calls
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
            // No provider keys are configured, so fall back to the built-in model
            // list.
            modelIds = WenshuLLMModel.allCases.map { $0.rawValue }
        }
        availableModels = modelIds
        if !availableModels.contains(currentModel) {
            availableModels = [currentModel] + availableModels
        }
        recomputeContextUsed()
    }

    /// recomputeContextUsed: the conversation's CURRENT context usage
    /// (real LLM API usage, replaces the chars/4 heuristic).
    ///
    /// The number is the LATEST turn's `usage.totalTokens`, not the sum
    /// over the turns. Each turn's `totalTokens` is the provider's report
    /// for that request, and its INPUT side is the whole conversation so
    /// far — so adding the turns together counted the history once per
    /// turn and grew quadratically. Four turns of a 1,000-token
    /// conversation reported 10,000 tokens of context when the context was
    /// 1,000.
    ///
    /// That also matches what the number is compared against: the chat
    /// footer compares it with `tokenCompressionContextThreshold`, which
    /// is a CONTEXT-WINDOW limit, not a spend limit. A cumulative number
    /// measured against a window limit is the wrong unit.
    ///
    /// The latest turn with a token count is the one that was sent with
    /// the most history, so it is the one that reports the most context
    /// in use. Messages without a token count (= the user's own turns,
    /// which the provider does not bill as a separate request, and
    /// messages from before usage was recorded) are skipped.
    func recomputeContextUsed() {
        contextUsed = messages.last(where: { ($0.tokens ?? 0) > 0 })?.tokens ?? 0
        let totalContext = contextUsed
        let messageCount = messages.count
        Logger(subsystem: "com.wenshu.app", category: "chat.context")
            .info("[wenshu.context] context usage after recompute: total=\(totalContext, privacy: .public) messages=\(messageCount, privacy: .public)")
    }

    /// The front door for the chat input. It dispatches `/plan` and the other
    /// commands, and otherwise runs the turn.
    func routeInput() async {
        let input = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }

        // The `/plan` command surface: intercept `/plan <query>` BEFORE the slash-command
        // path (= /plan is a hub command that needs engine dispatch + plan
        // rendering, = not a normal skill). Strategy: extract the query after
        // `/plan ` and call PlanModeEngine.run to get a numbered plan. The plan
        // is surfaced as a system ChatMessage (= the text content includes the
        // numbered steps; =). This is the lightweight route — keeps the engine
        // integration self-contained (= no ChatMessagePart type change required
        // for this surface).
        if let planQuery = stripPlanPrefix(input) {
            await runPlanMode(query: planQuery)
            return
        }

        // Try @-mention subagent trigger FIRST (= higher priority than slash
        // commands, because @slug syntax is more specific — it names a known
        // sub-agent). Multiple mentions in one input spawn multiple sub-agents
        // concurrently (= AsyncDelegation.delegate is async; awaits are awaited
        // sequentially so the user sees the spawn order preserved in the chat
        // log).
        let mentions = SubAgentMentionParser.parseAll(input)
        if !mentions.isEmpty {
            for mention in mentions {
                do {
                    // The librarian is activated by an explicit
                    // procedure: = `@librarian import <source>` or
                    // `@librarian curate`. = A mention that names no
                    // procedure is not a librarian task, = and it
                    // falls through to the ordinary path rather than
                    // running a procedure nobody named.
                    let taskText: String
                    if mention.subagentSlug == "librarian" {
                        switch LibrarianActivation.parse(mention.task) {
                        case .task(let librarianTask):
                            // `curate` is deterministic, = so it runs
                            // here and does NOT go to a model. = The
                            // analyser is pure data analysis, = and a
                            // model asked to do it would have had no
                            // tool for it, = so it would have guessed.
                            if librarianTask.procedure == .curate {
                                await runCuration()
                                continue
                            }
                            taskText = LibrarianActivation.encodedTask(for: librarianTask)
                        case .notALibrarianTask, .unknownProcedure:
                            taskText = mention.task
                        }
                    } else {
                        taskText = mention.task
                    }
                    let result = try await delegate(
                        subagentProfile: mention.subagentSlug,
                        task: taskText,
                        context: [:],
                        registry: AsyncDelegationRegistry.shared,
                        // The scope says where the result goes. = Without
                        // it the handle carries no destination, = and a
                        // finished run has nowhere to deliver what it
                        // produced.
                        scope: AgentScope(
                            sessionID: sessionId,
                            bookID: currentBookID
                        )
                    )
                    let shortId = String(result.handle.id.prefix(8))
                    messages.append(ChatMessage(
                        role: .system,
                        source: .system,
                        content: ChatSubAgentReceipt.dispatched(handleID: shortId)
                    ))
                } catch {
                    Logger(subsystem: "com.wenshu.app", category: "chat.subagent")
                        .error("[wenshu.chat.subagent] dispatch failed error=\(String(describing: error), privacy: .public)")
                    messages.append(ChatMessage(
                        role: .system,
                        source: .system,
                        content: ChatSubAgentReceipt.failed(error: error)
                    ))
                }
            }
            inputText = ""
            return
        }

        // No slash match → existing LLM send path. The slash prefix (= `/review
        // chapter 1`) is sent verbatim to the LLM, which interprets it as a
        // prompt template per ChatHubCommands.
        await send()
    }

    // The `/plan` command surface.

    /// Strips the `/plan` prefix off the input (= the prefix is a command marker,
    /// not text the user typed).
    private func stripPlanPrefix(_ input: String) -> String? {
        guard input.hasPrefix("/plan") else { return nil }
        // Exact-match on "/plan" + whitespace (= no args means the command is
        // invalid for plan-mode; = send `/plan` to the LLM verbatim as a slash
        // command per ChatHubCommands).
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

    /// Runs plan mode for the given query: it invokes the PlanModeEngine (= which
    /// wraps the model call) and reports a failure, so the user sees why the plan
    /// failed.
    private func runPlanMode(query: String) async {
        inputText = ""
        // Resolve connector + model from the active conductor (= same source of
        // truth ChatViewModel.send uses). The conductor owns a connector actor; =
        // use its currentModel. We don't currently have direct accessor for the
        // connector on WenshuConductor, so instantiate PlanModeEngine with
        // AnthropicConnector (= the conductor's default) + the current model id.
        // Future tickets may route through AppState.activeConnector; = out of
        // scope for this surface.
        let model = currentModel
        // The audit's package cleanup: resolve the active
        // connector through the public facade.
        let connector: any LLMConnector = WenshuAgent.shared.activeLLMConnector()
        let engine = PlanModeEngine(connector: connector, model: model)
        do {
            let plan = try await engine.run(query: query)
            // Surface the plan as a structured.plan ChatMessagePart (= rendered
            // via ChatPlanPartView) instead of a plain system text message. The
            // plan carries query + steps + connectorID + createdAt; =
            // ChatPlanPartView shows them as a numbered step list with an Approve
            // button (= the approve-button primitive; = Approve wiring is a).
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
        // Allow image-only sends (= an attached screenshot with no text is still
        // a valid send; the image carries the meaning). Capture + clear the draft
        // path BEFORE constructing the user message so the message captures the
        // image atomically.
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

        // Route through ChatRepositoryProtocol (= the data-layer seam). The Live
        // impl owns the StoredChatMessage mapping; = business layer speaks
        // ChatMessage only.
        do {
            try await repository.append(userMsg, sessionId: sessionId, bookID: currentBookID)
        } catch {
            Self.logSwallowedPersistenceFailure(operation: "append user message", error: error)
        }

        do {
            try Task.checkCancellation()
            // Streaming path = render each text chunk as it arrives (=
            // character-by-character, ChatGPT-style). The conductor path remains
            // blocking for now (= its WenshuConductor.handle returns a single
            // assembled reply = the WenshuConductor owns its own multi-agent
            // pipeline and isn't yet adapted to streaming). ships streaming for
            // the direct verifier path = the most common user flow. read the
            // model id from the canonical owner (= same value `vm.currentModel`
            // returns, via the shared AppState reference). No more raw
            // UserDefaults read here (= single owner maintained).
            let currentModel: String = self.currentModel
            // Per Apple HIG + 12 standard + Swift 6 strict-concurrency: migrate
            // from `NSLog` (= Swift 6 treats variadic as unavailable). Local
            // variable captures model name for the Logger interpolation (= Swift
            // 6 closure-capture rule).
            let modelForLog = currentModel
            Logger(subsystem: "com.wenshu.app", category: "chat.model")
                .info("[wenshu.model] effective model: \(modelForLog, privacy: .public) (AppState source)")
            var reply: String
            var replyThinking: String? // WenshuLLMBlock.thinking footnote UI
            var replyTokens: Int?
            if let conductor = conductor {
                // The conductor path streams as well, so the same streaming
                // switch below (= the one the direct path uses) handles
                // `LLMBlock` events from either source. Both paths accumulate
                // into the same parts array and the same thinking buffer, so the
                // placeholder renders the same way regardless of which path
                // emitted the event. The stream callback is `@Sendable` (= it can
                // be invoked from any actor, because the conversation loop runs
                // on a separate actor), so a local `var` cannot be captured: the
                // accumulator is a reference type, safe to capture in a
                // `@Sendable` closure (= each invocation is serial with respect
                // to the owning actor, so the reference is thread-safe here).
                let accumulator = StreamingAccumulator()
                // The buffer owns the rate at which the view updates. Its flush
                // handler is the single place that writes to the streaming
                // message, so the message is touched once per frame rather than
                // once per token.
                let buffer = StreamBuffer { [weak self] batch in
                    guard let self else { return }
                    self.applyStreamBatch(batch, placeholderId: placeholderId, accumulator: accumulator)
                }
                streamBuffer = buffer
                defer { self.streamBuffer = nil }
                let result = await conductor.handle(
                    userMessage: text,
                    sessionId: sessionId.rawValue,
                    model: currentModel,
                    bookID: currentBookID?.rawValue,
                    streamCallback: { [weak self] block in
                        // Log each stream block (= dev can
                        // confirm which part kinds the LLM actually emits). Tag
                        // with PATH=.. so it grep-parity with the other logs.
                        let kindTag: String = {
                            switch block {
                            case .text: return "text"
                            case .thinking: return "thinking"
                            case .toolUse: return "toolUse"
                            case .toolResult: return "toolResult"
                            }
                        }()
                        let kindTagForLog = kindTag
                        let modelForLog = currentModel
                        Logger(subsystem: "com.wenshu.app", category: "chat.conductor")
                            .info("[wenshu.conductor] PATH=stream BLOCK=\(kindTagForLog, privacy: .public) (model=\(modelForLog, privacy: .public)")
                        // The chunk goes into the buffer, not into the view.
                        //
                        // Every chunk used to enqueue its own MainActor task
                        // that rebuilt the whole message, so a long reply
                        // meant hundreds of queued tasks and hundreds of full
                        // message replacements, and the display rendered
                        // whatever state survived the queue (= text arriving
                        // in jumps). The buffer publishes once per frame
                        // instead, which is the only rate a person can read.
                        guard let self else { return }
                        await self.streamBuffer?.append(block)
                    }
                )
                // Publish whatever the buffer still holds before sealing the
                // message. Without this the last partial frame would land
                // after the bubble was already marked complete, and the tail
                // of the reply would appear late.
                buffer.flushNow()
                reply = result.reply
                replyThinking = result.thinking ?? accumulator.thinking
                replyTokens = result.totalTokens
                // Mark the conductor's bubble as sealed (= Hermes `pending:
                // false` flip after `message.complete`). Replace placeholder with
                // the final message.
                if let idx = messages.firstIndex(where: { $0.id == placeholderId }) {
                    // Per Apple HIG + 12 standard + Swift 6 strict-concurrency:
                    // migrate from `NSLog` (= Swift 6 treats variadic as
                    // unavailable). Local captures avoid closure-capture
                    // complaint.
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
                // The conductor is now ALWAYS wired with the
                // active connector (= WenshuAppDelegate
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
            // Route the agent message through ChatRepositoryProtocol (=
            // data-layer seam). The Live impl builds the StoredChatMessage from
            // this ChatMessage (= handles the id-stringification +
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

            // Trigger summary generation (LLM + saveSummary + deleteOldMessages
            // order) route through ChatRepositoryProtocol (= data-layer seam).
            // The Live impl hops to MainActor internally (= the protocol method
            // is async + the caller doesn't need a manual Task wrap anymore; =
            // was the bug-prone `Task { @MainActor in.. }` pattern that lost
            // errors silently).
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
            // The chat layer does not collapse every error to a single generic
            // line: the granular `UserFacingError.from` mapping (= network, key,
            // rate limit, etc.) is the user-visible message, so the user can tell
            // a missing or wrong key from a transport timeout from a server error
            // from a malformed response body. The single-line collapse hid the
            // real cause (= a long think with no further detail = impossible to
            // distinguish key from network).
            let activeProvider = WenshuAppDelegateLLMHelpers.activeConnectorSlug()
            let rawDesc = String(describing: error)
            Logger(subsystem: "com.wenshu.app", category: "chat.persist")
                .error("[wenshu.chat.persist] operation=send_chat error=\(rawDesc, privacy: .public) provider=\(activeProvider, privacy: .public)")
            // Use the granular classifier (= surfaces the real
            // underlying message body, not the generic
            // generic line). Falls back to the raw
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

    /// Starts a long-running goal via the agent's own context.
    func startNewSession() {
        // 1. Clear in-memory state (= visual reset).
        messages = []
        contextUsed = 0
        // 2. Generate new sessionId (= UUID-based).
        let newId = SessionID(rawValue: "s_" + UUID().uuidString.prefix(12).lowercased())
        sessionId = newId
        // NSLog audit trail (= verify in Console.app). Migrated from `NSLog` (=
        // the Swift 6 strict-concurrency model treats the variadic signature as
        // unavailable; = = use Logger instead per Apple's modern logging
        // guidance).
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
    func valueForSessionId() -> SessionID {
        sessionId
    } // @MainActor-isolated helper

    /// replaceMessages: ChatView .task loadcompletereplace (append)
    func replaceMessages(_ newMessages: [ChatMessage]) {
        messages = newMessages
    }

    /// Loads the chat history from the data layer. The rows that are not attached
    /// to a session are skipped: they are not global.
    func loadHistory() async {
        // Whether any provider holds a key.
        //
        // The persisted history is surfaced only once a key is configured
        // (= the call sites in `ChatView.task` also skip the load when no
        // key is configured), so the persisted rows are not shown behind the
        // empty-state overlay: they are ephemeral when the provider is not
        // configured.
        //
        // The lookup routes through WenshuAgent.shared (= the public facade).
        let isConfigured: Bool
        if let providersConfigured {
            isConfigured = await providersConfigured()
        } else {
            let configured = await WenshuAgent.shared.providersWithKeys()
            isConfigured = !configured.isEmpty
        }
        if !isConfigured {
            messages = []
            return
        }
        do {
            let loaded = try await repository.loadMessages(sessionId: sessionId, bookID: currentBookID)
            // The persisted rows kept the question and the answer out of
            // order (= the order they were rendered in, not the order they
            // were written). The sort is by
            // timestamp (= <1 ms apart on fast hardware).
            let sorted = loaded.sorted { a, b in
                if a.timestamp != b.timestamp {
                    return a.timestamp < b.timestamp
                }
                return a.id.uuidString < b.id.uuidString
            }
            messages = sorted
        } catch {
            // Silent no-op (= matches legacy behavior; = the view already handles
            // empty messages[] by showing the empty-state placeholder).
        }
    }
}

// MARK: - Try-logging helper (= 12 standard P1-02 try?  scaffolding)

/// across Core/Agent and Core/Tools.
extension ChatViewModel {
    fileprivate static let persistLogger = Logger(subsystem: "com.wenshu.app", category: "chat.persist")

    static func logSwallowedPersistenceFailure(operation: String, error: Error) {
        let errorString = String(describing: error)
        persistLogger.error("[wenshu.chat.persist] operation=\(operation, privacy: .public) dropped-error=\(errorString, privacy: .public)")
    }
    /// Take in a sub-agent's result that landed in this session.
    ///
    /// Only ONE message is taken, = not the whole history. = Reloading
    /// the history would throw away what the user is typing, = and
    /// where they had scrolled to, = and the result is one message
    /// at the end.
    ///
    /// A notification for another session is ignored: = a reply
    /// belongs to the conversation that asked for it, = and not to
    /// whatever conversation happens to be open.
    /// Take in a result that landed in this conversation.
    ///
    /// Internal and not private, = because the adoption's contract is
    /// worth testing without the notification bus in the way. = The
    /// bus is global, = and a whole-suite run has dozens of open
    /// conversations on it, = so a test that goes through the bus
    /// measures the suite's contention and not the adoption. = The
    /// wiring between the bus and this method is pinned by
    /// `SubAgentResultAdoptionTests`, = and the delivery's own test
    /// pins that the delivery writes the row and names it.
    func adoptDeliveredSubAgentResult(sessionID: String?, messageID: String?) async {
        await resultAdopter.adopt(
            sessionID: sessionID,
            messageID: messageID,
            currentSessionID: self.sessionId.rawValue,
            currentBookID: currentBookID,
            alreadyPresent: { id in self.messages.contains { $0.id == id } },
            append: { message in self.messages.append(message) }
        )
    }



}
