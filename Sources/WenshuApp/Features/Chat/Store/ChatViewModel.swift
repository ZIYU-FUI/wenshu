//
// ChatViewModel.swift = the chat session's state and its turn path.
// The class's STORED PROPERTIES live here (= = an extension cannot hold
// them); = = its methods live in the files beside it.
import Foundation
import WenshuAgent
import WenshuData

/// ChatViewModel: state management (Apple Observable + WSChatRepository + WenshuConductor)
@MainActor
@Observable
final class ChatViewModel {
    /// The last message whose turn is OVER (= = the reply is final).
    ///
    /// "Sealed" means the row is NOT arriving any more: not streaming
    /// (= = a row that is still receiving is no longer a placeholder,
    /// = = because the placeholder flag is cleared on the FIRST FRAME,
    /// = = and "the last sealed message" would be a half-written
    /// reply).
    ///
    /// It is deliberately NOT "the state is `.sealed`": a restored
    /// session's rows carry the DEFAULT state (= `.idle`), = = because
    /// the persisted read mapping never writes the state (= = the store
    /// keeps a message's words, = = not the fact that it was streaming
    /// when it was written).
    ///
    /// The shortcut asks the model (= = not the view), = = so the rule
    /// is one rule, = = and it can be tested as a behaviour.
    var lastSealedMessage: ChatMessage? {
        // "Sealed" = = the turn is not arriving any more.
        //
        // It is NOT "the state is .sealed": a restored session's rows
        // carry the DEFAULT state (= .idle), = = because the persisted
        // read mapping never writes the state (= the store keeps a
        // message's words, = = not the fact that it was streaming when
        // it was written). MEASURED: with the rule "the state is
        // .sealed", a restored session had NO sealed message at all
        // (= = ⌥C and ⌥A went silent after a restart).
        //
        // So the rule asks the question the shortcut actually means:
        // is this row still arriving? A row that is streaming is not
        // sealed; a row that is not (= = final, = = restored) is. A failed
        // turn leaves no wenshu row at all: it is replaced by a .system row.
        messages.last { $0.source == .wenshu && !$0.isPlaceholder && $0.streamState != .streaming }
    }

    var messages: [ChatMessage] = []
    var inputText: String = ""
    // Absolute path of an image the user attached via the chat input row's
    // paperclip button (= draft state). When non-nil, a small preview chip is
    // rendered above the TextField; on send the path is moved into the
    // ChatMessage and the draft is cleared. nil = no pending image.
    var attachedImagePath: String?
    var isSending: Bool = false
    var lastError: String?
    /// Whether the reader is at the bottom of the transcript.
    ///
    /// The follow's gate: while the reader is at the bottom the
    /// transcript follows the newest content; while they are away, the
    /// arriving reply must not drag them down (= = and the floating
    /// control offers the way back).
    ///
    /// It is the reader's OWN place (= = the row their viewport is
    /// bound to), = = and not a number derived from the content's
    /// height: the content growing underneath the reader moves every
    /// distance, = = so only the reader's own scroll says where they
    /// are.
    var readerIsAtBottom: Bool = true

    /// Apple's own answer changed: the transcript's bottom target is
    /// on screen, or it is not.
    ///
    /// The answer is Apple's, not ours: the view hands us the
    /// visibility of the clearance row (= = the content's bottom edge)
    /// as it changes, and Apple's `onScrollTargetVisibilityChange` is
    /// what raises it. So there is no distance to measure and no band
    /// to tune: a reader who nudged the scroll by a hair still has the
    /// bottom target on screen (= = Apple still says "at the bottom"),
    /// and the reader counts as away only once the bottom of the
    /// transcript has left the viewport (= = "scrolled far away", = =
    /// the boss's rule of 2026-11-25).
    ///
    /// - Parameter atBottom: whether the bottom target is on screen.
    func readerAtBottomChanged(_ atBottom: Bool) {
        // One plain write, and no dedup of our own. MEASURED by the
        // reviewer round of 2026-11-26 (scratch/obs_probe.swift): an
        // `@Observable` property written with the value it already holds
        // does NOT fire its observers, = = Apple's Observation compares the
        // write. A guard here would re-implement the framework's own job,
        // and the test that tried to pin it could not fail.
        readerIsAtBottom = atBottom
    }

    /// Whether the way back to the newest content is offered.
    ///
    /// True while the reader is away from the bottom. The view draws
    /// the control from this, = = and the test reads it from here, = =
    /// because the control's own presence in a rendered tree is a
    /// rendering question (= = MEASURED: an offscreen host's
    /// accessibility tree does not publish the control's element).
    var offersWayBack: Bool {
        !readerIsAtBottom
    }

    /// The reader asked to go back to the newest content.
    ///
    /// A counter, = = not a flag: a flag would fire only once, = = and
    /// the reader can ask again and again.
    func requestJumpToNewest() {
        jumpToNewestRequest &+= 1
    }

    /// The reader asked to go back to the newest content.
    ///
    /// Set by the transcript's floating control (= = the way back). The
    /// view reads it and scrolls the viewport. It lives here (= = in the
    /// model, = = not in the view) because "the reader wants the newest
    /// content" is a fact about the conversation, = = not about the
    /// viewport: the same request means the same thing in any surface
    /// that shows the conversation.
    var jumpToNewestRequest: Int = 0

    /// The coalescing buffer for the reply in flight.
    ///
    /// It exists only while a turn is streaming. Its flush handler writes
    /// the accumulated text into the streaming message, so the view sees one
    /// update per frame instead of one per token.
    @ObservationIgnored
    var streamBuffer: StreamBuffer?
    /// 'check split, check dead code'. Removed dead `activeSubAgentName` +
    /// `currentAgentTurn` fields —
    /// these were read by ChatSubAgentTag + ChatTurnProgress (. both files
    /// deleted). No view in the codebase consumes these values anymore; = dead
    /// reactive state. The corresponding `[wenshu.subagent]` + `[wenshu.agent]
    /// turn` marker emission (= ConversationLoop + WenshuConductor) and
    /// marker-parsing block below are also removed. retention (= keep
    /// cancelRequested):
    var cancelRequested: Bool = false
    /// The model id was scattered across several reads and writes (4 `@AppStorage`
    /// and 3 raw `UserDefaults`); the canonical owner is now `AppState.llmModel`,
    /// and this property reads it.
    let appState: AppState?
    var availableModels: [String] = []

    /// The last request's context reading (= what the provider received, and
    /// the parts that made it up).
    ///
    /// The reading comes from the agent's recorder, so it is the
    /// provider's own count of the prompt: the window's occupancy is
    /// measured against the same number the agent compresses against, and
    /// the parts say which part of the prompt is filling it.
    var contextUsage: ContextUsageSnapshot?

    /// The conductor the chat path runs the turn on. It is patched when the
    /// AppDelegate publishes one: a chat hung because the field was still nil at
    /// the moment the user pressed send.
    ///
    /// The chat hung for 20 seconds: the SwiftUI @State ChatViewModel
    var conductor: WenshuConductor?
    /// Chat persistence lives in `WSChatRepository.shared` (= a
    /// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    /// Mutable so the archive flow can replace the session id.
    /// The adopter that takes in a sub-agent's results.
    ///
    /// It is a stored property, = not a local, = because it holds the
    /// ids being taken in right now, = and a local would be a fresh
    /// copy every time (= so two notifications for the same result
    /// would both take it in).
    var resultAdopter: SubAgentResultAdopter

    @MainActor var sessionId: SessionID

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
    let providersConfigured: (@Sendable () async -> Bool)?

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
        resultAdopter = SubAgentResultAdopter(repository: repository)
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
    let repository: ChatRepositoryProtocol
}
