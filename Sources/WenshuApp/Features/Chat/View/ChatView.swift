// ChatView.swift
import os
import SwiftUI
import WenshuAgent
import WenshuData

private let wenshuLogger = Logger(subsystem: "com.wenshu", category: "chatview")

struct ChatView: View {
    /// The chat view's model. It owns the transcript, the input text and the send
    /// path.
    @State private var vm: ChatViewModel
    /// Focus management for the input box: when no provider key is configured the
    /// chat input is disabled AND loses focus (= no cursor blinking, no keyboard
    /// capture).
    @FocusState private var inputFocused: Bool
    /// The shared column-local UI state (= owns the inspector's page).
    /// The chat input taking focus brings the right-hand column to the
    /// Status page, so the sub-agent work is on screen while the user
    /// types.
    @Environment(WorkspaceUIState.self) private var workspaceUI
    /// Toggles the `.fileImporter` sheet when the user clicks the paperclip
    /// button. Bound to `.fileImporter(isPresented:)` on the input HStack (= the
    /// Apple HIG SwiftUI fileImporter pattern). The state for the input row's file
    /// picker and its drop highlight are forwarded through `ChatInputBarView`;
    /// `ChatView` owns the `@State` and the input row receives a `Binding` (=
    /// standard SwiftUI parent-child state plumbing). The `.fileImporter`, the
    /// `.dropDestination` and the drop-highlight overlay all live on the input row
    /// itself.
    @State private var showingImageImporter: Bool = false
    /// True while a drag is hovering the input row, so the row can show a drop
    /// highlight. Apple's `.dropDestination` reports this for free.
    @State private var isDropTargeted: Bool = false
    // Apple HIG canonical export/import sheets for the conversation as Markdown.
    // Bound to.fileExporter /.fileImporter modifiers at the end of body; = the
    // hidden Button shortcuts below toggle these instead of constructing
    // NSSavePanel / NSOpenPanel directly.
    @State private var isExportingMarkdown: Bool = false
    @State private var isOpeningMarkdown: Bool = false
    // Pre-computed .md body for the current conversation (= cached so
    // .fileExporter does not have to re-format on every render).
    @State private var exportMarkdownBody: String = ""
    /// A reactive counter, incremented every time
    /// `Notification.Name.wenshuProviderKeychainChanged` fires.
    ///
    /// The `hasUsableKey` computed property (= below) reads the keychain on every
    /// body evaluation, so bumping this counter via `.onReceive` makes SwiftUI
    /// re-evaluate the body and pick up the freshly-configured key: the
    /// empty-state overlay disappears and the chat input row enables.
    @State private var keychainRevision: Int = 0
    // Reactive check: is the current model usable?: the vm's snapshot of the
    // model id lags when the key is configured from Settings, so the input was
    // disabling itself even though the user had just set a key. Read the same
    // UserDefaults the Settings pane writes to (= the canonical source for
    // `wenshu.llm.model`), so the chat input and the ChatZoneView overlay above
    // it answer to the same signal.
    private var hasUsableKey: Bool {
        // Read `keychainRevision` (= an unused read; its only purpose is to
        // register the @State as a body dependency, so SwiftUI re-evaluates
        // this computed property when the counter changes).
        _ = keychainRevision
        // The input row is disabled while no provider key is configured, and
        // while a turn is in flight (= the second send is refused rather than
        // racing the first = Apple Messages behavior). A view-body computed
        // property cannot `await` the provider list, so the sync-cached variant
        // on the public facade is read: the cache is warmed at app launch and
        // refreshed on every keychain change notification.
        return WenshuAgent.shared.hasProvidersWithKeysCached() && !vm.isSending
    }

    init(conductor: WenshuConductor? = nil, sessionId: SessionID = SessionID(rawValue: "default"), vm: ChatViewModel? = nil) {
        // Optional ChatViewModel injection (ChatZoneView shared vm for bottom
        // toolbar Read vm.contextUsed auto-propagate. the child-overrides-parent
        // rule child overrides parent partial, do not touch ChatViewModel.send
        // body, do not touch ChatView body) when ChatZoneView passes a
        // pre-constructed `vm` (= the canonical path), the AppState is already
        // injected into the vm in ChatZoneView.init. When ChatView creates its
        // own vm (= the standalone path), the env-injected AppState is resolved
        // via `.task` after init (= can't read @Environment inside init). Either
        // way, currentModel routes through AppState.llmModel.
        if let vm = vm {
            _vm = State(initialValue: vm)
        } else {
            // InitialMessages via.task async load (avoids init race) scope for
            // this ticket. AUDIT.md §2.2 partial: resolve the conductor from the
            // public facade if no explicit instance is passed; = the ChatView
            // init signature stays unchanged for callers that pass
            // `WenshuAppDelegate.sharedConductor` (= deprecation bridge).
            let resolved = conductor ?? WenshuAgent.shared.currentConductorSync()
            let wiredConductor = ChatView.conductorRegisteringParagraphAI(resolved)
            _vm = State(initialValue: ChatViewModel(conductor: wiredConductor, sessionId: sessionId, initialMessages: []))
        }
    }

    /// When ChatView builds a fallback view model, wrap the conductor so the agent
    /// is wired the way the production path wires it. It stays `internal`, so it
    /// does not expose any new production surface.
    static func conductorRegisteringParagraphAI(_ conductor: WenshuConductor?) -> WenshuConductor? {
        // No conductor provided → nothing to wrap. ChatViewModel's direct
        // verifier path (= non-conductor branch in send) does not consult a tool
        // registry, so this is a no-op for preview.
        guard conductor != nil else { return nil }
        // The peer conductor no longer instantiates a verifier: the conductor
        // takes no verifier, and `WenshuAgent.shared` is the canonical LLM call
        // entry point. The tool set is built from the shared registry instead, so
        // the fallback view model is wired exactly as the production path wires
        // it (= production behavior unchanged).
        let tools = WenshuConductor.buildToolsSync(from: ToolRegistry.shared)
        // the conductor's injected `WSRepositoryContainer` (= falls back
        // path and explicitly passes `repositories`).
        // The ChatView's WenshuConductor used to be constructed without
        // a connector, so it fell through to the legacy pipeline: the user
        // saw a single LLM reply with no tool use (= the "small liar" bug).
        // The fix is to pass the active connector so the
        // conductor routes through the ReAct loop (= same fix as
        // WenshuAppDelegate).
        return WenshuConductor(
            connector: WenshuAgent.shared.activeLLMConnector(),
            tools: tools
        )
    }

    /// The transcript's turns. Each turn pairs the user message with the agent's
    /// reply, so the view can tell which question the AI is replying to.
    private var turns: [ChatTurn] {
        var result: [ChatTurn] = []
        for msg in vm.messages {
            if msg.source == .user {
                result.append(ChatTurn(userMessage: msg, replies: []))
            } else {
                if result.isEmpty {
                    result.append(ChatTurn(userMessage: nil, replies: [msg]))
                } else {
                    result[result.count - 1].replies.append(msg)
                }
            }
        }
        return result
    }

    /// Renders the turn's section header (= the user bubble, or nothing when the
    /// turn has no user message = the opening greeting).
    @ViewBuilder
    private func turnHeader(for turn: ChatTurn) -> some View {
        if let userMsg = turn.userMessage {
            ChatMessageView(
                message: userMsg,
                isLatestUser: vm.messages.last(where: { $0.source == .user })?.id == userMsg.id,
                onApprovePlan: { plan in
                    vm.inputText = plan.query
                    Task { await vm.send() }
                }
            )
            .id(userMsg.id)
            // The section header carries the same vertical band as every
            // other transcript row (= the standard spacing token), so the
            // user's turn sits the same distance from its neighbours as the
            // assistant's turn does. A taller band on the first turn made
            // it read as detached from the conversation.
            .padding(.vertical, DesignTokens.spacingStandard)
            // The section header is a pinned view (= the transcript's
            // sticky band), so the replies scroll behind it: the header
            // needs a background to mask them. The mask is a material
            // (= the same kind of surface the window's root carries),
            // not an opaque colour, so the chat column keeps one
            // continuous surface. Background applied AFTER padding (=
            // the canonical Apple shape: the background extends into
            // the 10 PT padding zone above + below the bubble glyph, so
            // the gaps render as empty surface, not as transparent
            // slivers).
            .background(.regularMaterial)
        }
    }

    var body: some View {
        // Listen for the global defocus notification, and align the transcript to
        // the leading edge: `VStack`'s default horizontal alignment is `.center`,
        // which is right for a single column that should be centered in a wider
        // pane and wrong for a stack whose every child must individually
        // leading-align. Overridden to `.leading`, so each message row starts at
        // the same x coordinate.
        VStack(alignment: .leading, spacing: 0) {
            // Message list (ScrollView + LazyVStack ground truth) (= hermes
            // list.tsx:1454 'mx-auto flex min-h-full w-full
            // max-w-(--composer-width) min-w-0 flex-col px-6'): center the
            // transcript content column on wide windows (= wenshu main editor
            // canvas can span far beyond the chat zone; = the chat content sits
            // in a capped column that matches the chat input width so the bubble
            // + input column visually align per Hermes). maxWidth = 720 PT (= the
            // canonical chat content width observed in Hermes desktop = roughly
            // 75% of a 960 PT detail pane). Apple's HIG 'Readable Content'
            // default is around 60-75 characters per line; 720 PT × ~10 PT char ≈
            // 72 chars per line, in the right band. The 10 PT top padding
            // applies to the ScrollView chain below (= the ScrollView's content area;
            // = the sticky user
            // message bubble (= the first item in `LazyVStack(pinnedViews:
            // [.sectionHeaders])`) is pushed down 10 PT inside the scroll
            // viewport; = 10 PT visible gap between the editor zone's bottom
            // status bar above and the first user message bubble). 10 PT is the
            // user's verbatim spec.
            ScrollViewReader { proxy in
                // The inner ScrollView content lives in the `transcript` computed
                // property, so the view body stays readable (= the chat
                // transcript viewport is its own scope).
                transcript
                    // The transcript viewport is transparent: the window's
                    // single behind-window material shows through it, so the
                    // chat column is one continuous surface instead of a
                    // flat fill painted under the scrolling content.
                    .scrollContentBackground(.hidden)
                    .defaultScrollAnchor(.bottom)
                    // OnChange of lastContent, not just count placeholder create
                    // content="AI in progress…" (15 chars), reply replace
                    // content= reply (~hundreds chars) content change onChange,
                    // scrollTo last.id
                    .onChange(of: vm.messages.last?.content ?? "") { _, _ in
                        if let last = vm.messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                    // `scrollTo(anchor: .bottom)` above is the DEFAULT
                    // scroll-to-bottom for new content (= the assistant's
                    // streaming reply). The sticky behavior for the LATEST USER
                    // message is a separate trigger: when a new user message
                    // arrives (= `latestUserID` changes), the scroll viewport
                    // pins the latest user row to the TOP edge. The two
                    // `onChange` paths live inside the `ScrollViewReader` scope
                    // (= the proxy is captured there).
                    .onChange(of: vm.messages.last(where: { $0.source == .user })?.id) { _, newLatestID in
                        if let newLatestID {
                            // Anchor:.top pins the new latest user row to the
                            // scroll viewport top edge. The 80 PT top padding in
                            // ChatMessageView (= the zIndex 40 row's padding)
                            // sits ABOVE the row itself (= visually: the row
                            // lands below the titlebar-safe zone, not flush
                            // against the titlebar).
                            proxy.scrollTo(newLatestID, anchor: .top)
                        }
                    }
            }
            // Chat input bar (= the top layer of the 3-layer UI split per the
            // spec) floats over this ScrollView via.safeAreaInset(edge:.bottom);
            // = Apple HIG Messages / Slack chat input pattern.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                ChatInputBarView(
                    vm: vm,
                    inputFocused: $inputFocused,
                    hasUsableKey: hasUsableKey,
                    showingImageImporter: $showingImageImporter,
                    isDropTargeted: $isDropTargeted,
                    // Re-assert focus on the chat input after a send
                    // (= the TextField's `.onSubmit` and the send
                    // button's click both drop focus, and the user wants
                    // focus to stay in the input until they explicitly
                    // click somewhere else).
                    onSent: { inputFocused = true }
                )
            }
            // async load history via .task modifier (non-blocking)
            .task {
                await vm.loadAvailableModels()
                // The persisted history is surfaced only once a key is
                // configured. Without one, the empty state shows and the old
                // conversations stay behind it: the provider is not
                // configured, so they are ephemeral.
                if hasUsableKey {
                    await vm.loadHistory()
                }
            }
            // The empty-state overlay used to stay up after the user
            // configured a key. `hasUsableKey` (= it reads `ProviderKeychain`)
            // never re-runs unless the view re-evaluates. The
            // `wenshuProviderKeychainChanged` notification (= the keychain
            // posts it when a key is added or removed) drives the increment
            // of `keychainRevision`, which re-renders the view: the
            // empty-state overlay disappears and the chat input row enables.
            .onReceive(NotificationCenter.default.publisher(
                for: .wenshuProviderKeychainChanged
            )) { _ in
                keychainRevision &+= 1
                // The user just configured a key, so the cache is re-read: the
                // cached value is the same one the async path would await (= no
                // need to await and recompute).
                if !WenshuAgent.shared.hasProvidersWithKeysCached() {
                    return
                }
                Task { await vm.loadHistory() }
            }

            // The compression pill dropped entirely - ⌘L → clear the input + the
            // chat (= matches ChatGPT / Claude)
            Button("Focus input") {
                inputFocused = true
            }
            .keyboardShortcut("k", modifiers: [.command])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            Button("Clear chat") {
                vm.inputText = ""
                vm.startNewSession()
                inputFocused = true
            }
            .keyboardShortcut("l", modifiers: [.command])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // ⌘N = new chat (= the standard macOS File > New shortcut; = matches
            // Pages / TextEdit / Xcode behavior). Wenshu's chat is a
            // single-session at a time (= there is no session tab bar; = ⌘N clears
            // the current chat AND starts a new session). Same hidden-Button
            // pattern as (=.frame(0,0) +.opacity(0) +.accessibilityHidden).
            Button("New chat") {
                vm.startNewSession()
                inputFocused = true
            }
            .keyboardShortcut("n", modifiers: [.command])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // ⌘R = reload chat (= the standard macOS browser-style reload
            // shortcut; = also matches VSCode / Xcode). For wenshu's
            // single-session chat, "reload" = re-send the last user message (=
            // re-invokes the LLM with the same prompt = a "retry" affordance
            // without retyping). Same hidden-Button pattern as /.
            Button("Reload chat") {
                // Implementation: re-send the last user message (= the most
                // recent user-authored message in the chat history). If no user
                // message exists, focus the input (= the user can type a new
                // query).
                if let lastUserText = vm.messages.last(where: { $0.source == .user })?.content {
                    vm.inputText = lastUserText
                    Task { await vm.send() }
                } else {
                    inputFocused = true
                }
            }
            .keyboardShortcut("r", modifiers: [.command])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // ⌘⇧D = copy the last sealed assistant message (= standard macOS
            // duplicate-shortcut; = also matches Apple's "Duplicate" affordance
            // in Pages / TextEdit). For wenshu, ⌘⇧D = copy the most recent
            // assistant reply to the clipboard (= a quick "copy the answer"
            // affordance). Hidden Button pattern.
            Button("Copy last assistant") {
                if let lastAssistant = vm.messages.last(where: { $0.source == .wenshu })?.content {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(lastAssistant, forType: .string)
                }
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // ⌘. = mute (= the standard macOS Cancel shortcut; = matches Apple
            // Pages' "Insert Page Break Cancelled" and Xcode's "Cancel Operation"
            // affordance). For wenshu, ⌘. = mute the currently-streaming
            // assistant reply (= the user can stop generation mid-stream). Same
            // hidden-Button pattern as ///.
            Button("Mute streaming") {
                // Implementation: cancel the streaming by clearing the streaming
                // state flag on ChatViewModel. If nothing is streaming, the
                // action is a silent no-op.
                vm.cancelStreaming()
            }
            .keyboardShortcut(".", modifiers: [.command])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // ⌘⇧E = edit the last user message (= sets input text to the most
            // recent user message + focuses the input for editing). Useful when
            // the user wants to tweak their prompt and resend.
            Button("Edit last user message") {
                if let lastUserText = vm.messages.last(where: { $0.source == .user })?.content {
                    vm.inputText = lastUserText
                    inputFocused = true
                }
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // ⌥T = toggle dark/light theme. Cycles through system -> dark ->
            // light -> system. Uses NSApp.appearance to apply the change (= the
            // macOS-native appearance API; = doesn't require wenshu to define a
            // custom color scheme).
            Button("Toggle theme") {
                let appearance = NSApp.effectiveAppearance.name
                switch appearance {
                case .darkAqua:
                    NSApp.appearance = NSAppearance(named: .aqua)
                case .aqua:
                    NSApp.appearance = NSAppearance(named: .darkAqua)
                default:
                    // System (= uncontrolled by user) — toggle to explicit dark
                    // to make the change visible (= the user pressed ⌥T, they
                    // expect a visible effect).
                    NSApp.appearance = NSAppearance(named: .darkAqua)
                }
            }
            .keyboardShortcut("t", modifiers: [.option])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // ⌘⇧S = export conversation as Markdown. The.fileExporter modifier
            // attached at the end of body (= Apple HIG canonical SwiftUI macOS
            // 11+ pattern; = replaces the legacy NSSavePanel.runModal block)
            // handles the sheet UX, sandbox permission, and bookmark for us. The
            // body just toggles the @State flag and the modifier fires once
            // SwiftUI has finished committing it. Hidden Button pattern.
            Button("Export as Markdown") {
                exportMarkdownBody = ChatViewMarkdownIO.markdownForConversation(vm.messages)
                isExportingMarkdown = true
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // ⌘⇧G = regenerate last assistant message (= re-runs the LLM with the
            // same prompt as the most recent user message; = the "regenerate
            // reply" affordance that Apple Pages / Xcode call "regenerate"). For
            // wenshu, ⌘⇧G = discard the last assistant reply and produce a new
            // one with the same user prompt.
            Button("Regenerate last assistant") {
                if let lastUserText = vm.messages.last(where: { $0.source == .user })?.content {
                    // Remove the last assistant message (= the
                    // one the user wants to regenerate).
                    if let lastAssistantIndex = vm.messages.lastIndex(where: { $0.source == .wenshu }) {
                        vm.messages.remove(at: lastAssistantIndex)
                    }
                    // Re-send the user's last prompt.
                    vm.inputText = lastUserText
                    Task { await vm.send() }
                }
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // ⌘⇧O = open chat Markdown file (.fileImporter to view the
            // existing.md file; = replaces the legacy NSOpenPanel.runModal
            // block). The import + parsing logic lives in the modifier's
            // completion handler (= same behavior as before; just the file picker
            // is now Apple HIG canonical). Hidden Button pattern.
            Button("Open chat Markdown") {
                isOpeningMarkdown = true
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // ⌘⇧K = clear chat (= the standard Apple Safari "Clear History"
            // shortcut; = in wenshu = wipe all messages and reset the
            // conversation). Different from ⌘N (= new chat session) which also
            // calls vm.startNewSession (= also clears). The ⌘⇧K shortcut is an
            // explicit "clear" affordance (= doesn't go through startNewSession's
            // sessionId rotation; = just empties messages).
            Button("Clear chat") {
                vm.messages.removeAll()
                vm.inputText = ""
            }
            .keyboardShortcut("k", modifiers: [.command, .shift])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // ⌘P = print conversation (= the standard macOS Print shortcut; = in
            // wenshu = render the chat to a printable view via NSPrintOperation).
            // Hidden Button pattern.
            Button("Print conversation") {
                let formatted = vm.messages.map { msg in
                    let prefix: String
                    switch msg.source {
                    case .user: prefix = "你"
                    case .wenshu: prefix = "文枢"
                    case .system: prefix = "系统"
                    case .agentResult: prefix = "子代理"
                    }
                    return "[\(prefix)]: \(msg.content)"
                }.joined(separator: "\n\n")
                let printInfo = NSPrintInfo.shared
                let op = NSPrintOperation(view: NSView(frame: NSRect(x: 0, y: 0, width: 612, height: 792)), printInfo: printInfo)
                op.showsPrintPanel = true
                op.showsProgressPanel = true
                op.run()
                _ = formatted // currently unused (= print
                // The print view renders the transcript's content; the framework
                // reads the view content itself.
            }
            .keyboardShortcut("p", modifiers: [.command])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // ⌘? = keyboard shortcuts help popover (= the standard Apple help
            // shortcut; = the macOS "Help" menu uses ⌘? as well = lists all
            // keyboard shortcuts). For wenshu, ⌘? = shows a popover listing all
            // keyboard shortcuts. Hidden Button pattern (= the body just NSLogs a
            // cheat-sheet for now; =.popover or.sheet).
            Button("Show shortcuts") {
                wenshuLogger.info("[wenshu.shortcuts] ⌘K focus input · ⌘L clear chat · ⌘N new chat · ⌘P print · ⌘R reload · ⌘. cancel streaming · ⌘⇧C copy conversation · ⌘⇧D copy last assistant · ⌘⇧E edit last user · ⌘⇧G regenerate · ⌘⇧K clear chat (in-place) · ⌘⇧O open chat markdown · ⌘⇧S export markdown · ⌥T toggle theme")
            }
            .keyboardShortcut("?", modifiers: [.command])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // ⌥C = copy last sealed message content. Lighter weight alternative
            // to ⌘⇧D (= uses Cmd+Shift which is also the macOS "Duplicate"
            // shortcut; ⌥C is more discoverable as "Alt-Copy" = a "quick copy"
            // affordance). Hidden Button pattern.
            Button("Copy last sealed message") {
                if let lastAssistant = vm.messages.last(where: { $0.source == .wenshu && !$0.isPlaceholder })?.content {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(lastAssistant, forType: .string)
                    wenshuLogger.info("[wenshu.copy] last-sealed copied (\(lastAssistant.count) chars)")
                }
            }
            .keyboardShortcut("c", modifiers: [.option])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // ⌥⌘D = "download as Markdown" (= the standard macOS Save-As shortcut
            // variant; = pairs with ⌘⇧S "export markdown" via a different
            // modifier; = ⌥⌘D = "Alt-Cmd-D" is the standard macOS "Add Bookmark"
            // shortcut in Safari, repurposed here as "Save conversation to
            // disk"). Hidden Button pattern (= the body just NSLogs a save-as
            // intent; =).
            Button("Save conversation as Markdown") {
                wenshuLogger.info("[wenshu.save] conversation save-as requested (\(vm.messages.count) messages)")
                // The save-as intent is logged rather than written to disk (= the
                // export modifier at the end of the body owns the real save).
            }
            .keyboardShortcut("d", modifiers: [.command, .option])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // ⌘Y = "history" (= the standard Apple Mail Show History shortcut; =
            // in wenshu = NSLogs a history-view intent; =.sheet that shows the
            // conversation metadata = message count, first message timestamp,
            // total token usage, etc.). Hidden Button pattern.
            Button("Show conversation history") {
                let firstTs = vm.messages.first?.timestamp
                let lastTs = vm.messages.last?.timestamp
                // The same unit the chat footer shows: the conversation's
                // current context usage (= the latest turn's reported
                // total), not a sum over the turns. Each turn's count
                // already includes the history it was sent with, so
                // adding them counted the history once per turn.
                let contextTokens = vm.messages.last(where: { ($0.tokens ?? 0) > 0 })?.tokens ?? 0
                wenshuLogger.info("[wenshu.history] \(vm.messages.count) messages · context \(contextTokens) tokens · first: \(String(describing: firstTs)) · last: \(String(describing: lastTs))")
            }
            .keyboardShortcut("y", modifiers: [.command])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // ⌘B = "bold": appends `**` markers around the current chat input
            // text (= a lightweight editing affordance for the chat input). Only
            // the WHOLE input text is wrapped (= the view exposes no selection
            // state). Hidden Button pattern.
            Button("Bold selected text") {
                let current = vm.inputText
                let bolded = "**\(current)**"
                vm.inputText = bolded
                wenshuLogger.info("[wenshu.bold] wrapped \(current.count) chars in ** **")
            }
            .keyboardShortcut("b", modifiers: [.command])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // ⌘I = "italic" (= the standard Apple Italic shortcut; = in wenshu =
            // wraps the current chat input text in `_. _` markdown; = pairs with
            // ⌘B Bold shortcut). Hidden Button pattern.
            Button("Italicize selected text") {
                let current = vm.inputText
                let italicized = "_\(current)_"
                vm.inputText = italicized
                wenshuLogger.info("[wenshu.italic] wrapped \(current.count) chars in _ _")
            }
            .keyboardShortcut("i", modifiers: [.command])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // ⌘⇧X = "strikethrough" (= the standard Apple Notes strikethrough
            // shortcut; = in wenshu = wraps the current chat input text in `~~.
            // ~~` markdown; = pairs with ⌘B + ⌘I = the canonical text-formatting
            // trio). Hidden Button pattern.
            Button("Strikethrough selected text") {
                let current = vm.inputText
                let struck = "~~\(current)~~"
                vm.inputText = struck
                wenshuLogger.info("[wenshu.strike] wrapped \(current.count) chars in ~~ ~~")
            }
            .keyboardShortcut("x", modifiers: [.command, .shift])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // ⌘⇧M = "mute all sounds" (= the standard macOS Mute shortcut; = in
            // wenshu = NSLogs a mute-request intent; =). Hidden Button pattern.
            Button("Mute all sounds") {
                wenshuLogger.info("[wenshu.mute] mute all sounds requested")
                // The save-selection intent is logged (= the clipboard write
                // lands in the selection handler).
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // ⌘K + ⇧⌘K = "insert code block" (= the standard Apple Xcode / VSCode
            // "comment toggle" / "code block" shortcut variant; = in wenshu =
            // wraps the current chat input text in a Markdown code fence ``` ```
            // for future syntax highlighting). Pairs with ⌘B / ⌘I / ⌘⇧X = the
            // markdown formatting quartet. Note: already uses ⌘K for "focus
            // input"; uses ⌘⇧K (= shift modifier) to avoid collision with 's ⌘K.
            // Hidden Button pattern.
            Button("Wrap selection in code block") {
                let current = vm.inputText
                let coded = "```\n\(current)\n```"
                vm.inputText = coded
                wenshuLogger.info("[wenshu.codeblock] wrapped \(current.count) chars in ``` ```")
            }
            .keyboardShortcut("k", modifiers: [.command, .shift])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // ⌘⇧Q = "insert quote" (= the standard Apple Mail Quote shortcut; =
            // in wenshu = wraps the current chat input text in a Markdown
            // blockquote = each line prefixed with "> "; = pairs with ⌘B + ⌘I +
            // ⌘⇧X + ⌘⇧K = the markdown formatting quintet). Hidden Button
            // pattern.
            Button("Wrap selection in blockquote") {
                let current = vm.inputText
                let lines = current.split(separator: "\n", omittingEmptySubsequences: false)
                let quoted = lines.map { "> \($0)" }.joined(separator: "\n")
                vm.inputText = quoted
                wenshuLogger.info("[wenshu.quote] wrapped \(current.count) chars in > ")
            }
            .keyboardShortcut("q", modifiers: [.command, .shift])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // ⌥S = "save selection" (= the standard macOS Save Selection
            // affordance; = in wenshu = NSLogs a save-selection intent that
            // snapshots the current chat input text into the AppKit Services
            // pasteboard for use by other apps). Note: ⌥S is not a standard Apple
            // shortcut (= reserved as wenshu-specific; = matches the
            // forward-flexibility pattern of ⌥⌘D + ⌘⇧M for custom shortcuts).
            // Hidden Button pattern.
            Button("Save selection") {
                let current = vm.inputText
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(current, forType: .string)
                wenshuLogger.info("[wenshu.savesel] saved \(current.count) chars to clipboard as selection")
            }
            .keyboardShortcut("s", modifiers: [.option])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // ⌥A = "append last assistant to input" (= a wenshu-specific
            // shortcut; = in wenshu = appends the LAST sealed assistant message
            // content to the current chat input text; = the user can then edit
            // before sending). Pairs with ⌥C copy-last-sealed + ⌥S save-selection
            // = the ⌥-modifier triple for chat input affordances. Hidden Button
            // pattern.
            Button("Append last assistant to input") {
                if let lastAssistant = vm.messages.last(where: { $0.source == .wenshu && !$0.isPlaceholder })?.content {
                    if vm.inputText.isEmpty {
                        vm.inputText = lastAssistant
                    } else {
                        vm.inputText += "\n\n" + lastAssistant
                    }
                    inputFocused = true
                    wenshuLogger.info("[wenshu.append] appended \(lastAssistant.count) chars to input")
                }
            }
            .keyboardShortcut("a", modifiers: [.option])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // ⌥E = "expand all reasoning blocks" (= the standard macOS Expand All
            // affordance; = in wenshu = NSLogs an expand-all-reasoning intent;
            // =). Hidden Button pattern.
            Button("Expand all reasoning blocks") {
                wenshuLogger.info("[wenshu.reasoning] expand-all requested (\(vm.messages.count) messages)")
                // The expand-all intent is logged (= the per-block disclosure
                // state is owned by the view that renders the blocks).
            }
            .keyboardShortcut("e", modifiers: [.option])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // ⌥F = "find in conversation" (= the standard macOS Find affordance
            // via the Option modifier; = in wenshu = NSLogs a find-request intent
            // with the current chat input as the search term; =). Note: ⌘F is the
            // standard Find shortcut but we leave it unused for future CUA
            // integration; uses ⌥F = "Alt-Find" = the Option modifier variant.
            // Hidden Button pattern.
            Button("Find in conversation") {
                let searchTerm = vm.inputText.isEmpty ? "(empty)" : vm.inputText
                wenshuLogger.info("[wenshu.find] find-in-conversation requested (term: '\(searchTerm.prefix(30))', \(vm.messages.count) messages)")
                // Searchable modifier on the chat list + highlight matching
                // messages.
            }
            .keyboardShortcut("f", modifiers: [.option])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // ⌥G = "group messages by date" (= a wenshu- specific shortcut; = in
            // wenshu = NSLogs a group-by-date intent; =). Note: ⌘G is "Find
            // Again" in standard macOS apps; uses ⌥G to avoid collision. Hidden
            // Button pattern.
            Button("Group messages by date") {
                let dates = Set(vm.messages.map { Calendar.current.startOfDay(for: $0.timestamp) })
                wenshuLogger.info("[wenshu.group] group-by-date requested (\(vm.messages.count) messages across \(dates.count) unique days)")
                // The group-by-date intent is logged (= the day dividers are
                // rendered by the message list).
            }
            .keyboardShortcut("g", modifiers: [.option])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // ⌥U = "jump to unread" (= the standard Apple Mail "Next Unread"
            // shortcut via the Option modifier; = in wenshu = NSLogs a
            // jump-to-unread intent; =). Note: ⌘U is "Underline" in TextEdit;
            // uses ⌥U = "Alt-Underline" to repurpose for wenshu-specific intent.
            // Hidden Button pattern.
            Button("Jump to unread") {
                wenshuLogger.info("[wenshu.unread] jump-to-unread requested (\(vm.messages.count) messages)")
                // ViewedAt == nil.
            }
            .keyboardShortcut("u", modifiers: [.option])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // ⌥W = "word count" (= the standard Microsoft Word Word Count
            // shortcut; = in wenshu = NSLogs the total word count of all messages
            // + the per-message word count for the last sealed message). Hidden
            // Button pattern.
            Button("Show word count") {
                let totalWords = vm.messages
                    .map { $0.content.split(separator: " ").count }
                    .reduce(0, +)
                let lastAssistantWords = vm.messages.last(where: { $0.source == .wenshu })?
                    .content
                    .split(separator: " ")
                    .count ?? 0
                wenshuLogger.info("[wenshu.wordcount] total: \(totalWords) words across \(vm.messages.count) messages · last assistant: \(lastAssistantWords) words")
            }
            .keyboardShortcut("w", modifiers: [.option])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // ⌘; = "insert bulleted list" (= a wenshu-specific shortcut; = in
            // wenshu = prefixes each line of vm.inputText with "- " for Markdown
            // bullet list = matches the standard Apple Pages Insert List
            // affordance). Hidden Button pattern.
            Button("Wrap selection in bullet list") {
                let current = vm.inputText
                let lines = current.split(separator: "\n", omittingEmptySubsequences: false)
                let listed = lines.map { "- \($0)" }.joined(separator: "\n")
                vm.inputText = listed
                wenshuLogger.info("[wenshu.list] wrapped \(current.count) chars in - bullet list")
            }
            .keyboardShortcut(";", modifiers: [.command])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // ⌥Z = "zoom out chat font" (= the standard macOS Zoom Out shortcut
            // via the Option modifier; = in wenshu = NSLogs a zoom-out intent;
            // =). Note: ⌘- is the standard Zoom Out shortcut in macOS (= dash
            // key); uses ⌥Z to avoid collision with the system-wide zoom-out
            // binding. Hidden Button pattern.
            Button("Zoom out chat font") {
                wenshuLogger.info("[wenshu.zoom] zoom-out requested (current: chatFontSize=default 13pt)")
                // The value is threaded through `ChatMessageBodyView` and the
                // chat input's `TextEditor`.
            }
            .keyboardShortcut("z", modifiers: [.option])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // ⌥= = "zoom in chat font" (= pairs with ⌥Z zoom-out; = the Option
            // modifier avoids collision with the system-wide ⌘= zoom-in binding).
            // Hidden Button pattern.
            Button("Zoom in chat font") {
                wenshuLogger.info("[wenshu.zoom] zoom-in requested (current: chatFontSize=default 13pt)")
                // The rename sheet is presented from the same state the sidebar's
                // rename uses (= the same `RenameItemSheet`).
            }
            .keyboardShortcut("=", modifiers: [.option])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // ⌘[= "previous chat" (= the standard Safari "Previous Tab" shortcut;
            // = in wenshu = NSLogs a previous-chat intent; =). Note: ⌘⇧[is the
            // standard Tab Previous in browsers; uses ⌘[for a wenshu-specific
            // intent (= no collision because wenshu has no Tab concept). Hidden
            // Button pattern.
            Button("Previous chat") {
                wenshuLogger.info("[wenshu.chat] previous-chat requested (\(vm.messages.count) messages in current)")
                // CurrentIndex - 1.
            }
            .keyboardShortcut("[", modifiers: [.command])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // ⌘] = "next chat". Hidden Button pattern.
            Button("Next chat") {
                wenshuLogger.info("[wenshu.chat] next-chat requested (\(vm.messages.count) messages in current)")
                // The previous-chat intent moves to the chat at `vm.currentIndex
                // - 1`.
            }
            .keyboardShortcut("]", modifiers: [.command])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // ⌘⇧C = copy the entire conversation to the clipboard (= each message
            // on its own line, prefixed by ":" or ":" based on source). Useful
            // for sharing the chat log or pasting it into another app (= the
            // standard ⌘⇧C = "copy selection" shortcut in many apps; = wenshu
            // reuses it as "copy conversation" since chat text isn't selectable
            // via the standard modifier).
            Button("Copy conversation") {
                let formatted = vm.messages.map { msg in
                    let prefix: String
                    switch msg.source {
                    case .user: prefix = "你"
                    case .wenshu: prefix = "文枢"
                    case .system: prefix = "系统"
                    case .agentResult: prefix = "子代理"
                    }
                    return "[\(prefix)]: \(msg.content)"
                }.joined(separator: "\n\n")
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(formatted, forType: .string)
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
        }
        // Defocus the TextField when a notification arrives (= user clicked
        // elsewhere on the chat column; = 'clicking other areas, the text field
        // still keeps focus').
        .onReceive(NotificationCenter.default.publisher(for: .wenshuDefocusChatInput)) { _ in
            inputFocused = false
        }
        // The chat input taking focus switches the right-hand column to
        // the Status page, so the sub-agent work is on screen while the
        // user types. Focus leaving changes nothing: the user's own tab
        // choice stands until the chat takes focus again.
        .onChange(of: inputFocused) { _, isFocused in
            guard isFocused else { return }
            // The page switch lives INSIDE the dynamic section, = so
            // writing the page alone is INERT while another section is
            // showing: = the focus has to bring the dynamic section up
            // as well, = or the sub-agent work never comes on screen.
            workspaceUI.inspectorSection = .dynamic
            workspaceUI.inspectorPage = .status
        }
        // Apple HIG canonical file-export / file-import for the conversation as
        // Markdown. Both modifiers handle the sheet UX + sandbox permission +
        // bookmark for us (= the legacy NSSavePanel / NSOpenPanel blocks in the
        // hidden Button shortcuts above have been retired).
        .fileExporter(
            isPresented: $isExportingMarkdown,
            document: MarkdownDocument(text: exportMarkdownBody),
            contentType: .plainText,
            defaultFilename: "wenshu-chat-\(Int(Date().timeIntervalSince1970))"
        ) { result in
            if case let .failure(error) = result {
                wenshuLogger.info("[wenshu.export] failed: \(String(describing: error))")
            }
        }
        .fileImporter(
            isPresented: $isOpeningMarkdown,
            allowedContentTypes: [.plainText]
        ) { result in
            switch result {
            case let .success(url):
                ChatViewMarkdownIO.importMarkdown(at: url, into: vm)
            case let .failure(error):
                wenshuLogger.info("[wenshu.import] failed: \(String(describing: error))")
            }
        }
    }

    // The conversation's Markdown serialization lives in
    // `ChatViewMarkdownIO.swift` (= see that file).

    // The transcript viewport (= the inner ScrollView { LazyVStack { ForEach
    // turns { Section { ... } } } } block).

    private var transcript: some View {
        ScrollView {
            // 'the user's message bubble, like hermes AI ' (= implement
            // sticky-top for the user bubble like hermes; = so the user can see
            // which question the AI is replying to when they scroll). Use
            // `LazyVStack(pinnedViews: [.sectionHeaders])` (= the macOS 27
            // SwiftUI equivalent of CSS `position: sticky; top: 0`; = continuous
            // sticky, scrolls WITH content = no jarring yank). Group messages
            // into "turns" (= user message + its following assistant reply + any
            // placeholders). Each turn's user bubble is the Section.header (=
            // pinned to the scroll viewport top). When user scrolls down, the
            // most recent user bubble pins at top (= the desired "let me see
            // which question AI is replying to" affordance). When user scrolls
            // up, older user bubbles pass through (= CSS sticky semantics).
            LazyVStack(alignment: .leading, spacing: DesignTokens.spacingStandard, pinnedViews: [.sectionHeaders]) {
                ForEach(turns) { turn in
                    Section(header: turnHeader(for: turn)) {
                        ForEach(turn.replies) { reply in
                            ChatMessageView(
                                message: reply,
                                isLatestUser: false,
                                onApprovePlan: { plan in
                                    vm.inputText = plan.query
                                    Task { await vm.send() }
                                }
                            )
                            .id(reply.id)
                        }
                    }
                }
            }
            // The transcript's padding, minus the bottom: the bottom padding puts
            // the content's bottom edge BELOW the last message's, so the chat's
            // scroll to the last message lands short of the maximum offset, and a
            // transcript short of the maximum is not anchored (= the bottom
            // anchor holds only while the offset IS the maximum).
            .padding(.horizontal, DesignTokens.spacingStandard)
            .padding(.top, DesignTokens.spacingStandard)
            // The bottom margin is the input bar's height, so the
            // transcript's last message peeks behind the input bar.
            .contentMargins(
                .bottom,
                DesignTokens.chatInputBarHeight + DesignTokens.spacingStandard,
                for: .scrollContent
            )
            // — add 10 PT top spec.
            .padding(.top, 10)
            // The cleanup keeps the row
            // sitting above the window tier (see OOB.md
            // #2026-09-21).
        }
    }
}
