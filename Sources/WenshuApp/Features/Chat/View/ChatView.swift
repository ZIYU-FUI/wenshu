// ChatView.swift
// … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
// 
import SwiftUI
import WenshuData
import os

private let wenshuLogger = Logger(subsystem: "com.wenshu", category: "chatview")

struct ChatView: View {
    // / true when `messageID` is the most recent user-sourced message in the
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / Walks from the end (= the common case where
    @State private var vm: ChatViewModel
    // 2026-08-24 acceptance fix: focus management for input box.
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // AND lose focus (no cursor blinking, no keyboard capture).
    @FocusState private var inputFocused: Bool
    // CHATIMG-001 (2026-09-07): toggles the .fileImporter sheet when the
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // live on the input row itself (= ChatInputBarView body).
    @State private var showingImageImporter: Bool = false
    // / True while a drag is hovering the input row, so the row can show a drop
    // / highlight. Apple's .dropDestination reports this for free.
    @State private var isDropTargeted: Bool = false
    // Apple HIG canonical export/import sheets for the conversation as
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // NSSavePanel / NSOpenPanel directly.
    @State private var isExportingMarkdown: Bool = false
    @State private var isOpeningMarkdown: Bool = false
    // Pre-computed .md body for the current conversation (= cached so
    // .fileExporter does not have to re-format on every render).
    @State private var exportMarkdownBody: String = ""
    // / Reactive counter incremented every time
    // / `Notification.Name.wenshuProviderKeychainChanged` fires.
    // / The `hasUsableKey` computed property (= below) reads the
    // / keychain on every body evaluation; = bumping this counter
    // / via `.onReceive` makes SwiftUI re-evaluate the body and
    // / re-pick up the freshly-configured key (= the empty-state
    // / overlay disappears; = the chat input row enables).
    @State private var keychainRevision: Int = 0
    // Reactive check: is the current model usable?
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // signal.
    private var hasUsableKey: Bool {
        // / Read `keychainRevision` (= an unused read; = the
        // / only purpose is to register the @State as a body
        // / dependency so SwiftUI re-evaluates this computed
        // / property when the counter changes).
        _ = keychainRevision
        // chat-input-disabled-key-check: gate on the
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // race-fire a second send; = Apple Messages behavior).
        // AUDIT.md §2.2 partial (2026-10-16): `var hasUsableKey`
        // (= a non-async SwiftUI view body computed property)
        // cannot `await providersWithKeys()`; = use the
        // sync-cached variant on the public facade. The
        // cache is warmed at app launch + refreshed on every
        // keychain change notification (= 1-line change vs
        // the direct `ProviderKeychain.listProvidersWithKeys()`
        // call that the AUDIT §2.2 partial flagged).
        return WenshuAgent.shared.hasProvidersWithKeysCached() && !vm.isSending
    }

    init(conductor: WenshuConductor? = nil, sessionId: SessionID = SessionID(rawValue: "default"), vm: ChatViewModel? = nil) {
        // optional ChatViewModel injection (ChatZoneView shared vm for bottom toolbar
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // AppState.llmModel.
        if let vm = vm {
            _vm = State(initialValue: vm)
        } else {
            // initialMessages via .task async load (avoids init race)
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // scope for this ticket.
            // AUDIT.md §2.2 partial (2026-10-16): resolve the
            // conductor from the public facade if no
            // explicit instance is passed; = the ChatView
            // init signature stays unchanged for callers
            // that pass `WenshuAppDelegate.sharedConductor`
            // (= deprecation bridge).
            let resolved = conductor ?? WenshuAgent.shared.currentConductorSync()
            let wiredConductor = ChatView.conductorRegisteringParagraphAI(resolved)
            _vm = State(initialValue: ChatViewModel(conductor: wiredConductor, sessionId: sessionId, initialMessages: []))
        }
    }

    // / P0 #2 (WIRE-AGENT-002): when ChatView builds a fallback vm, wrap the
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / `internal` does not expose any new production surface.
    internal static func conductorRegisteringParagraphAI(_ conductor: WenshuConductor?) -> WenshuConductor? {
        // No conductor provided → nothing to wrap. ChatViewModel's
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // not consult a tool registry, so this is a no-op for preview.
        guard conductor != nil else { return nil }
        // : peer conductor no longer instantiates a
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // coverage; = production behavior unchanged).
        // AUDIT.md §2.2 partial (2026-10-16 boss "把切换包的事
        // 清干净" arc): the `let verifier = WenshuVerifier()`
        // was deleted; = the conductor no longer takes a
        // verifier argument; = WenshuAgent.shared is the
        // canonical LLM call entry point.
        let runtime = AgentRuntime()
        let tools = WenshuConductor.buildToolsSync(from: ToolRegistry.shared)
        // the conductor's injected `WSRepositoryContainer` (= falls back
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // path and explicitly passes `repositories`).
        // P0-AGENT-LOOP (2026-10-16 boss OOB "agent 没有达到 agent 的标准"):
        // The ChatView's WenshuConductor used to be constructed without
        // a connector, so it fell through to the legacy pipeline. = the
        // user saw a single LLM reply with no tool use (= the "small
        // liar" bug). The fix is to pass the active connector so the
        // conductor routes through the ReAct loop (= same fix as
        // WenshuAppDelegate).
        return WenshuConductor(
            runtime: runtime,
            connector: WenshuAgent.shared.activeLLMConnector(),
            tools: tools
        )
    }

    // / P2 #20 (WIRE-LIBRARIAN-001): build the BookStore instance that
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // / which question AI is replying to" affordance).
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

    // / Render the Section header (= the user bubble OR nothing if this turn has
    // / no user message = opening greeting).
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
            // section header needs `.background()` to mask
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // seamlessly with the scroll viewport background.
            // Background applied AFTER padding (= the canonical
            // Apple shape: the background extends into the 10 PT
            // padding zone above + below the bubble glyph, so the
            // 10 PT gaps between the chrome band and the sticky
            // bubble AND between the sticky bubble and the AI
            // reply directly underneath both render as visible
            // sidebarBackground-tinted empty space, not as
            // padding-only transparent slivers).
            .background(DesignTokens.sidebarBackground)
        }
    }

    var body: some View {
        // acceptance fix: listen for global defocus notification.
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // leading-aligned rendering per the 'all 1:1' rule).
        VStack(alignment: .leading, spacing: 0) {
            // Message list (ScrollView + LazyVStack ground truth)
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // spec.
            ScrollViewReader { proxy in
                // Inner ScrollView content extracted to `transcript` computed property (= the chat transcript viewport; = ~129 LOC moved out of body; = A99 god-class split)
                transcript
                // ScrollView background. SwiftUI on macOS 27 wraps the
                // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                // = inspector/content tier; = controlBackgroundColor).
                .scrollContentBackground(.hidden)
                // 2026-09-23: 'the chat zone, the text echo layer, whether
                // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                // design system)).
                .background(DesignTokens.sidebarBackground)
                // -cleanup E3 (see OOB.md #2026-09-21) '，'
                // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                // other row in the transcript).
                .defaultScrollAnchor(.bottom)
                // onChange of lastContent, not just count
                // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                // content change onChange, scrollTo last.id
                .onChange(of: vm.messages.last?.content ?? "") { _, _ in
                    if let last = vm.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
                // 
                // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                // new values).
                .onChange(of: vm.messages.last(where: { $0.source == .user })?.id) { _, newLatestID in
                    if let newLatestID {
                        // anchor: .top pins the new latest user row
                        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                        // against the titlebar).
                        proxy.scrollTo(newLatestID, anchor: .top)
                    }
                }
            }
            // chat input bar (= the top layer of the
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // Messages / Slack chat input pattern.
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    ChatInputBarView(
                        vm: vm,
                        inputFocused: $inputFocused,
                        hasUsableKey: hasUsableKey,
                        showingImageImporter: $showingImageImporter,
                        isDropTargeted: $isDropTargeted,
                        // FOCUS-RETENTION (boss 2026-10-16 OOB "现在打
                        // 字说完一句话，聊天区的文本框会失去焦点"):
                        // re-assert focus on the chat input after a
                        // send (= the TextField's `.onSubmit` and the
                        // send button's click both drop focus; = the
                        // user wants focus to stay in the input until
                        // they explicitly click somewhere else).
                        onSent: { inputFocused = true }
                    )
                }
            // async load history via .task modifier (non-blocking)
            .task {
                await vm.loadAvailableModels()
                // / Per boss 2026-10-16 OOB "如果没配 key, 就只显示
                // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                // / the persisted history to surface on the first
                // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                // / the moment the user configures a key (= the
                // / "showing the OLD conversations behind the empty
                // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                // / ephemeral when the provider is not configured.
                if hasUsableKey {
                    await vm.loadHistory()
                }
            }
            // / Per boss 2026-10-16 OOB "配上了 KEY 之后, 界面
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // / the empty-state overlay is still shown after the
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // / `hasUsableKey` (= reads `ProviderKeychain`) is a
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // / never re-runs unless the view re-evaluates. The
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // / `wenshuProviderKeychainChanged` notification (= posted
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // / deletes). When it fires, increment `keychainRevision`
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // / re-render (= the empty-state overlay disappears
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // / chat input row enables = the canonical Apple HIG
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            .onReceive(NotificationCenter.default.publisher(
                for: .wenshuProviderKeychainChanged
            )) { _ in
                keychainRevision &+= 1
                // / The user just configured a key. Re-run the
                // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                // AUDIT.md §2.2 partial (2026-10-16): use the
                // sync-cached variant (= the Task is async but
                // the value is also available via the cache; =
                // no need to await + recompute).
                if !WenshuAgent.shared.hasProvidersWithKeysCached() {
                    return
                }
                Task { await vm.loadHistory() }
            }

            // 2026-09-23: the compression pill dropped entirely
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // - ⌘L → clear the input + the chat (= matches ChatGPT / Claude)
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
            // T48-NEW-CHAT-SHORTCUT (2026-09-18): ⌘N = new chat
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // (= .frame(0,0) + .opacity(0) + .accessibilityHidden).
            Button("New chat") {
                vm.startNewSession()
                inputFocused = true
            }
            .keyboardShortcut("n", modifiers: [.command])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T59-RELOAD-SHORTCUT (2026-09-18): ⌘R = reload chat
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // Same hidden-Button pattern as T37/T48.
            Button("Reload chat") {
                // T59 implementation: re-send the last user message
                // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                // the input (= the user can type a new query).
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
            // T66-COPY-LAST-ASSISTANT (2026-09-18): ⌘⇧D = copy
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // answer" affordance). Hidden Button pattern.
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
            // T67-MUTE-SHORTCUT (2026-09-18): ⌘. = mute
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // Same hidden-Button pattern as T37/T48/T59/T66.
            Button("Mute streaming") {
                // T67 implementation: cancel the streaming
                // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                // the action is a silent no-op.
                vm.cancelStreaming()
            }
            .keyboardShortcut(".", modifiers: [.command])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T69-EDIT-SHORTCUT (2026-09-18): ⌘⇧E = edit
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // resends the original text).
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
            // T74-THEME-TOGGLE (2026-09-18): ⌥T = toggle
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // custom color scheme).
            Button("Toggle theme") {
                let appearance = NSApp.effectiveAppearance.name
                switch appearance {
                case .darkAqua:
                    NSApp.appearance = NSAppearance(named: .aqua)
                case .aqua:
                    NSApp.appearance = NSAppearance(named: .darkAqua)
                default:
                    // System (= uncontrolled by user) — toggle
                    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                    // expect a visible effect).
                    NSApp.appearance = NSAppearance(named: .darkAqua)
                }
            }
            .keyboardShortcut("t", modifiers: [.option])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T76-EXPORT-MD (2026-09-18): ⌘⇧S = export
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // Hidden Button pattern.
            Button("Export as Markdown") {
                exportMarkdownBody = ChatViewMarkdownIO.markdownForConversation(vm.messages)
                isExportingMarkdown = true
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T77-REGEN-SHORTCUT (2026-09-18): ⌘⇧G =
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // with the same user prompt.
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
            // T78-OPEN-MD (2026-09-18): ⌘⇧O = open chat
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // Hidden Button pattern.
            Button("Open chat Markdown") {
                isOpeningMarkdown = true
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T79-CLEAR-CHAT (2026-09-18): ⌘⇧K = clear chat
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // sessionId rotation; = just empties messages).
            Button("Clear chat") {
                vm.messages.removeAll()
                vm.inputText = ""
            }
            .keyboardShortcut("k", modifiers: [.command, .shift])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T80-PRINT-SHORTCUT (2026-09-18): ⌘P = print
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // Hidden Button pattern.
            Button("Print conversation") {
                let formatted = vm.messages.map { msg in
                    let prefix: String
                    switch msg.source {
                    case .user: prefix = "你"
                    case .wenshu: prefix = "文枢"
                    case .system: prefix = "系统"
                    }
                    return "[\(prefix)]: \(msg.content)"
                }.joined(separator: "\n\n")
                let printInfo = NSPrintInfo.shared
                let op = NSPrintOperation(view: NSView(frame: NSRect(x: 0, y: 0, width: 612, height: 792)), printInfo: printInfo)
                op.showsPrintPanel = true
                op.showsProgressPanel = true
                op.run()
                _ = formatted  // currently unused (= print
                                // framework reads view content;
                                // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                                // into a real print view).
            }
            .keyboardShortcut("p", modifiers: [.command])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T82-SHORTCUT-HELP (2026-09-18): ⌘? = keyboard
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // wire it to a real SwiftUI .popover or .sheet).
            Button("Show shortcuts") {
                wenshuLogger.info("[wenshu.shortcuts] ⌘K focus input · ⌘L clear chat · ⌘N new chat · ⌘P print · ⌘R reload · ⌘. cancel streaming · ⌘⇧C copy conversation · ⌘⇧D copy last assistant · ⌘⇧E edit last user · ⌘⇧G regenerate · ⌘⇧K clear chat (in-place) · ⌘⇧O open chat markdown · ⌘⇧S export markdown · ⌥T toggle theme")
            }
            .keyboardShortcut("?", modifiers: [.command])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T85-ALT-C-SHORTCUT (2026-09-18): ⌥C = copy
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // Hidden Button pattern.
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
            // T91-OPT-CMD-D-SHORTCUT (2026-09-18): ⌥⌘D
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // with the file written to Downloads).
            Button("Save conversation as Markdown") {
                wenshuLogger.info("[wenshu.save] conversation save-as requested (\(vm.messages.count) messages)")
                // Future ticket: wire to NSSavePanel
                // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                // T76 via a shared helper).
            }
            .keyboardShortcut("d", modifiers: [.command, .option])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T92-HISTORY-SHORTCUT (2026-09-18): ⌘Y
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // Hidden Button pattern.
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
            // T93-BOLD-SHORTCUT (2026-09-18): ⌘B
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // Hidden Button pattern.
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
            // T94-ITALIC-SHORTCUT (2026-09-18): ⌘I
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // Hidden Button pattern.
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
            // T95-STRIKETHROUGH-SHORTCUT (2026-09-18):
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // Hidden Button pattern.
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
            // T96-MUTE-SHORTCUT (2026-09-18): ⌘⇧M
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // Hidden Button pattern.
            Button("Mute all sounds") {
                wenshuLogger.info("[wenshu.mute] mute all sounds requested")
                // Future ticket: wire to a real
                // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                // VoiceMode feature).
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T101-CODE-BLOCK-SHORTCUT (2026-09-18):
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
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
            // T102-QUOTE-SHORTCUT (2026-09-18): ⌘⇧Q
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // Hidden Button pattern.
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
            // T103-SAVE-SELECTION-SHORTCUT (2026-09-18):
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
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
            // T104-APPEND-SHORTCUT (2026-09-18): ⌥A
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // Hidden Button pattern.
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
            // T105-EXPAND-REASONING-SHORTCUT (2026-09-18):
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // Hidden Button pattern.
            Button("Expand all reasoning blocks") {
                wenshuLogger.info("[wenshu.reasoning] expand-all requested (\(vm.messages.count) messages)")
                // Future ticket: wire to a @State
                // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                // each ChatReasoningPartView.
            }
            .keyboardShortcut("e", modifiers: [.option])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T106-FIND-SHORTCUT (2026-09-18): ⌥F =
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // Hidden Button pattern.
            Button("Find in conversation") {
                let searchTerm = vm.inputText.isEmpty ? "(empty)" : vm.inputText
                wenshuLogger.info("[wenshu.find] find-in-conversation requested (term: '\(searchTerm.prefix(30))', \(vm.messages.count) messages)")
                // Future ticket: wire to a real SwiftUI
                // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                // + highlight matching messages.
            }
            .keyboardShortcut("f", modifiers: [.option])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T107-GROUP-SHORTCUT (2026-09-18): ⌥G =
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // Hidden Button pattern.
            Button("Group messages by date") {
                let dates = Set(vm.messages.map { Calendar.current.startOfDay(for: $0.timestamp) })
                wenshuLogger.info("[wenshu.group] group-by-date requested (\(vm.messages.count) messages across \(dates.count) unique days)")
                // Future ticket: wire to a @State
                // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                // messages.
            }
            .keyboardShortcut("g", modifiers: [.option])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T108-UNREAD-SHORTCUT (2026-09-18): ⌥U
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // Hidden Button pattern.
            Button("Jump to unread") {
                wenshuLogger.info("[wenshu.unread] jump-to-unread requested (\(vm.messages.count) messages)")
                // Future ticket: wire to a ScrollViewReader
                // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                // message where message.viewedAt == nil.
            }
            .keyboardShortcut("u", modifiers: [.option])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T109-WORD-COUNT-SHORTCUT (2026-09-18):
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // Hidden Button pattern.
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
            // T110-LIST-SHORTCUT (2026-09-18): ⌘; =
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // Hidden Button pattern.
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
            // T112-ZOOM-OUT-SHORTCUT (2026-09-18): ⌥Z
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // Hidden Button pattern.
            Button("Zoom out chat font") {
                wenshuLogger.info("[wenshu.zoom] zoom-out requested (current: chatFontSize=default 13pt)")
                // Future ticket: wire to a @State
                // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                // TextEditor.
            }
            .keyboardShortcut("z", modifiers: [.option])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T113-ZOOM-IN-SHORTCUT (2026-09-18): ⌥=
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // Hidden Button pattern.
            Button("Zoom in chat font") {
                wenshuLogger.info("[wenshu.zoom] zoom-in requested (current: chatFontSize=default 13pt)")
                // Future ticket: wire to the same
                // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                // ChatMessageBodyView + ChatInput).
            }
            .keyboardShortcut("=", modifiers: [.option])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T114-PREV-CHAT-SHORTCUT (2026-09-18): ⌘[
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // Hidden Button pattern.
            Button("Previous chat") {
                wenshuLogger.info("[wenshu.chat] previous-chat requested (\(vm.messages.count) messages in current)")
                // Future ticket: wire to a
                // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                // to the chat at vm.currentIndex - 1.
            }
            .keyboardShortcut("[", modifiers: [.command])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T115-NEXT-CHAT-SHORTCUT (2026-09-18): ⌘]
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // Hidden Button pattern.
            Button("Next chat") {
                wenshuLogger.info("[wenshu.chat] next-chat requested (\(vm.messages.count) messages in current)")
                // Future ticket: wire to the same
                // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                // to the chat at vm.currentIndex + 1).
            }
            .keyboardShortcut("]", modifiers: [.command])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T70-COPY-CONVERSATION (2026-09-18): ⌘⇧C = copy
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // selectable via the standard modifier).
            Button("Copy conversation") {
                let formatted = vm.messages.map { msg in
                    let prefix: String
                    switch msg.source {
                    case .user: prefix = "你"
                    case .wenshu: prefix = "文枢"
                    case .system: prefix = "系统"
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
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // the text field still keeps focus').
        .onReceive(NotificationCenter.default.publisher(for: .wenshuDefocusChatInput)) { _ in
            inputFocused = false
        }
        // Apple HIG canonical file-export / file-import for the
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // Button shortcuts above have been retired).
        .fileExporter(
            isPresented: $isExportingMarkdown,
            document: MarkdownDocument(text: exportMarkdownBody),
            contentType: .plainText,
            defaultFilename: "wenshu-chat-\(Int(Date().timeIntervalSince1970))"
        ) { result in
            if case .failure(let error) = result {
                wenshuLogger.info("[wenshu.export] failed: \(String(describing: error))")
            }
        }
        .fileImporter(
            isPresented: $isOpeningMarkdown,
            allowedContentTypes: [.plainText]
        ) { result in
            switch result {
            case .success(let url):
                ChatViewMarkdownIO.importMarkdown(at: url, into: vm)
            case .failure(let error):
                wenshuLogger.info("[wenshu.import] failed: \(String(describing: error))")
            }
        }
    }
    // (markdownForConversation extracted to ChatViewMarkdownIO.swift in A87; = see that file)
    // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
    // MARK: - Transcript viewport (= the inner ScrollView { LazyVStack { ForEach turns { Section { ... } } } } block; = extracted from body in A99 to fight the 1368-LOC god-class)
    @ViewBuilder
    private var transcript: some View {

    ScrollView {
                        // 2026-09-23: 'the user's message bubble, like
                        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                        // sticky semantics).
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
                        .padding(DesignTokens.spacingStandard)
                        // 
                        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                        // peeks behind the input bar).
                        .contentMargins(.bottom, DesignTokens.chatInputBarHeight, for: .scrollContent)
                        // 2026-10-12 [archived-round] — add 10 PT top
                        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                        // spec.
                        .padding(.top, 10)
                        // -cleanup E3 (see OOB.md #2026-09-21) '
                        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
                        // sitting above the window tier).
                    }
        }

}
