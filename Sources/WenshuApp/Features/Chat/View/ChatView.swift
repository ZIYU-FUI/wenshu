// ChatView.swift
// … (= 42 rationale lines collapsed; = A112 docblock collapse per §1.8)
// 
import SwiftUI
import WenshuData
import os

private let wenshuLogger = Logger(subsystem: "com.wenshu", category: "chatview")

struct ChatView: View {
    // / true when `messageID` is the most recent user-sourced message in the
    // … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / Walks from the end (= the common case where
    @State private var vm: ChatViewModel
    // 2026-08-24 acceptance fix: focus management for input box.
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // AND lose focus (no cursor blinking, no keyboard capture).
    @FocusState private var inputFocused: Bool
    // CHATIMG-001 (2026-09-07): toggles the .fileImporter sheet when the
    // … (= 9 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // live on the input row itself (= ChatInputBarView body).
    @State private var showingImageImporter: Bool = false
    /// True while a drag is hovering the input row, so the row can show a drop
    /// highlight. Apple's .dropDestination reports this for free.
    @State private var isDropTargeted: Bool = false
    // Apple HIG canonical export/import sheets for the conversation as
    // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // NSSavePanel / NSOpenPanel directly.
    @State private var isExportingMarkdown: Bool = false
    @State private var isOpeningMarkdown: Bool = false
    // Pre-computed .md body for the current conversation (= cached so
    // .fileExporter does not have to re-format on every render).
    @State private var exportMarkdownBody: String = ""
    // Reactive check: is the current model usable?
    // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // signal.
    private var hasUsableKey: Bool {
        // chat-input-disabled-key-check: gate on the
        // … (= 15 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // race-fire a second send; = Apple Messages behavior).
        return !ProviderKeychain.listProvidersWithKeys().isEmpty && !vm.isSending
    }

    init(conductor: WenshuConductor? = nil, sessionId: SessionID = SessionID(rawValue: "default"), vm: ChatViewModel? = nil) {
        // optional ChatViewModel injection (ChatZoneView shared vm for bottom toolbar
        // … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // AppState.llmModel.
        if let vm = vm {
            _vm = State(initialValue: vm)
        } else {
            // initialMessages via .task async load (avoids init race)
            // … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // scope for this ticket.
            let wiredConductor = ChatView.conductorRegisteringParagraphAI(conductor)
            _vm = State(initialValue: ChatViewModel(conductor: wiredConductor, sessionId: sessionId, initialMessages: []))
        }
    }

    // / P0 #2 (WIRE-AGENT-002): when ChatView builds a fallback vm, wrap the
    // … (= 22 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / `internal` does not expose any new production surface.
    internal static func conductorRegisteringParagraphAI(_ conductor: WenshuConductor?) -> WenshuConductor? {
        // No conductor provided → nothing to wrap. ChatViewModel's
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // not consult a tool registry, so this is a no-op for preview.
        guard conductor != nil else { return nil }
        // : peer conductor no longer instantiates a
        // … (= 8 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // coverage; = production behavior unchanged).
        let runtime = AgentRuntime()
        let verifier = WenshuVerifier()
        let tools = WenshuConductor.buildToolsSync(from: ToolRegistry.shared)
        // the conductor's injected `WSRepositoryContainer` (= falls back
        // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // path and explicitly passes `repositories`).
        return WenshuConductor(
            runtime: runtime,
            verifier: verifier,
            tools: tools
        )
    }

    // / P2 #20 (WIRE-LIBRARIAN-001): build the BookStore instance that
    // … (= 26 rationale lines collapsed; = A112 docblock collapse per §1.8)
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

    /// Render the Section header (= the user bubble OR nothing if this turn has
    /// no user message = opening greeting).
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
            // section header needs `.background()` to mask
            // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // seamlessly with the scroll viewport background.
            .background(DesignTokens.sidebarBackground)
        }
    }

    var body: some View {
        // acceptance fix: listen for global defocus notification.
        // … (= 13 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // leading-aligned rendering per the 'all 1:1' rule).
        VStack(alignment: .leading, spacing: 0) {
            // Message list (ScrollView + LazyVStack ground truth)
            // … (= 25 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // spec.
            ScrollViewReader { proxy in
                // Inner ScrollView content extracted to `transcript` computed property (= the chat transcript viewport; = ~129 LOC moved out of body; = A99 god-class split)
                transcript
                // ScrollView background. SwiftUI on macOS 27 wraps the
                // … (= 15 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // = inspector/content tier; = controlBackgroundColor).
                .scrollContentBackground(.hidden)
                // 2026-09-23: 'the chat zone, the text echo layer, whether
                // … (= 10 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // design system)).
                .background(DesignTokens.sidebarBackground)
                // -cleanup E3 (see OOB.md #2026-09-21) '，'
                // … (= 8 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // other row in the transcript).
                .defaultScrollAnchor(.bottom)
                // onChange of lastContent, not just count
                // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // content change onChange, scrollTo last.id
                .onChange(of: vm.messages.last?.content ?? "") { _, _ in
                    if let last = vm.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
                // 
                // … (= 45 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // new values).
                .onChange(of: vm.messages.last(where: { $0.source == .user })?.id) { newLatestID in
                    if let newLatestID {
                        // anchor: .top pins the new latest user row
                        // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
                        // against the titlebar).
                        proxy.scrollTo(newLatestID, anchor: .top)
                    }
                }
            }
            // chat input bar (= the top layer of the
            // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // Messages / Slack chat input pattern.
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    ChatInputBarView(
                        vm: vm,
                        inputFocused: $inputFocused,
                        hasUsableKey: hasUsableKey,
                        showingImageImporter: $showingImageImporter,
                        isDropTargeted: $isDropTargeted
                    )
                }
            // async load history via .task modifier (non-blocking)
            .task {
                await vm.loadAvailableModels()
                // C-5: chat history loads via ChatSessionViewModel.loadHistory()
                // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // to ChatMessage lives in LiveChatRepository).
                await vm.loadHistory()
            }

            // 2026-09-23: the compression pill dropped entirely
            // … (= 13 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
            // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
            // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // Same hidden-Button pattern as T37/T48.
            Button("Reload chat") {
                // T59 implementation: re-send the last user message
                // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
            // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
            // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // Same hidden-Button pattern as T37/T48/T59/T66.
            Button("Mute streaming") {
                // T67 implementation: cancel the streaming
                // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // the action is a silent no-op.
                vm.cancelStreaming()
            }
            .keyboardShortcut(".", modifiers: [.command])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T69-EDIT-SHORTCUT (2026-09-18): ⌘⇧E = edit
            // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
            // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
                    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
                    // expect a visible effect).
                    NSApp.appearance = NSAppearance(named: .darkAqua)
                }
            }
            .keyboardShortcut("t", modifiers: [.option])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T76-EXPORT-MD (2026-09-18): ⌘⇧S = export
            // … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
            // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
            // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // Hidden Button pattern.
            Button("Open chat Markdown") {
                isOpeningMarkdown = true
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T79-CLEAR-CHAT (2026-09-18): ⌘⇧K = clear chat
            // … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
            // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
                                // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
                                // into a real print view).
            }
            .keyboardShortcut("p", modifiers: [.command])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T82-SHORTCUT-HELP (2026-09-18): ⌘? = keyboard
            // … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // wire it to a real SwiftUI .popover or .sheet).
            Button("Show shortcuts") {
                wenshuLogger.info("[wenshu.shortcuts] ⌘K focus input · ⌘L clear chat · ⌘N new chat · ⌘P print · ⌘R reload · ⌘. cancel streaming · ⌘⇧C copy conversation · ⌘⇧D copy last assistant · ⌘⇧E edit last user · ⌘⇧G regenerate · ⌘⇧K clear chat (in-place) · ⌘⇧O open chat markdown · ⌘⇧S export markdown · ⌥T toggle theme")
            }
            .keyboardShortcut("?", modifiers: [.command])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T85-ALT-C-SHORTCUT (2026-09-18): ⌥C = copy
            // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
            // … (= 10 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // with the file written to Downloads).
            Button("Save conversation as Markdown") {
                wenshuLogger.info("[wenshu.save] conversation save-as requested (\(vm.messages.count) messages)")
                // Future ticket: wire to NSSavePanel
                // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // T76 via a shared helper).
            }
            .keyboardShortcut("d", modifiers: [.command, .option])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T92-HISTORY-SHORTCUT (2026-09-18): ⌘Y
            // … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // Hidden Button pattern.
            Button("Show conversation history") {
                let firstTs = vm.messages.first?.timestamp
                let lastTs = vm.messages.last?.timestamp
                let totalTokens = vm.messages.compactMap { $0.tokens }.reduce(0, +)
                wenshuLogger.info("[wenshu.history] \(vm.messages.count) messages · \(totalTokens) tokens · first: \(String(describing: firstTs)) · last: \(String(describing: lastTs))")
            }
            .keyboardShortcut("y", modifiers: [.command])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T93-BOLD-SHORTCUT (2026-09-18): ⌘B
            // … (= 12 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
            // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
            // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
            // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // Hidden Button pattern.
            Button("Mute all sounds") {
                wenshuLogger.info("[wenshu.mute] mute all sounds requested")
                // Future ticket: wire to a real
                // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // VoiceMode feature).
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T101-CODE-BLOCK-SHORTCUT (2026-09-18):
            // … (= 11 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
            // … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
            // … (= 10 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
            // … (= 8 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
            // … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // Hidden Button pattern.
            Button("Expand all reasoning blocks") {
                wenshuLogger.info("[wenshu.reasoning] expand-all requested (\(vm.messages.count) messages)")
                // Future ticket: wire to a @State
                // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // each ChatReasoningPartView.
            }
            .keyboardShortcut("e", modifiers: [.option])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T106-FIND-SHORTCUT (2026-09-18): ⌥F =
            // … (= 11 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // Hidden Button pattern.
            Button("Find in conversation") {
                let searchTerm = vm.inputText.isEmpty ? "(empty)" : vm.inputText
                wenshuLogger.info("[wenshu.find] find-in-conversation requested (term: '\(searchTerm.prefix(30))', \(vm.messages.count) messages)")
                // Future ticket: wire to a real SwiftUI
                // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // + highlight matching messages.
            }
            .keyboardShortcut("f", modifiers: [.option])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T107-GROUP-SHORTCUT (2026-09-18): ⌥G =
            // … (= 9 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // Hidden Button pattern.
            Button("Group messages by date") {
                let dates = Set(vm.messages.map { Calendar.current.startOfDay(for: $0.timestamp) })
                wenshuLogger.info("[wenshu.group] group-by-date requested (\(vm.messages.count) messages across \(dates.count) unique days)")
                // Future ticket: wire to a @State
                // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // messages.
            }
            .keyboardShortcut("g", modifiers: [.option])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T108-UNREAD-SHORTCUT (2026-09-18): ⌥U
            // … (= 10 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // Hidden Button pattern.
            Button("Jump to unread") {
                wenshuLogger.info("[wenshu.unread] jump-to-unread requested (\(vm.messages.count) messages)")
                // Future ticket: wire to a ScrollViewReader
                // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // message where message.viewedAt == nil.
            }
            .keyboardShortcut("u", modifiers: [.option])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T109-WORD-COUNT-SHORTCUT (2026-09-18):
            // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
            // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
            // … (= 10 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // Hidden Button pattern.
            Button("Zoom out chat font") {
                wenshuLogger.info("[wenshu.zoom] zoom-out requested (current: chatFontSize=default 13pt)")
                // Future ticket: wire to a @State
                // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // TextEditor.
            }
            .keyboardShortcut("z", modifiers: [.option])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T113-ZOOM-IN-SHORTCUT (2026-09-18): ⌥=
            // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // Hidden Button pattern.
            Button("Zoom in chat font") {
                wenshuLogger.info("[wenshu.zoom] zoom-in requested (current: chatFontSize=default 13pt)")
                // Future ticket: wire to the same
                // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // ChatMessageBodyView + ChatInput).
            }
            .keyboardShortcut("=", modifiers: [.option])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T114-PREV-CHAT-SHORTCUT (2026-09-18): ⌘[
            // … (= 10 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // Hidden Button pattern.
            Button("Previous chat") {
                wenshuLogger.info("[wenshu.chat] previous-chat requested (\(vm.messages.count) messages in current)")
                // Future ticket: wire to a
                // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // to the chat at vm.currentIndex - 1.
            }
            .keyboardShortcut("[", modifiers: [.command])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T115-NEXT-CHAT-SHORTCUT (2026-09-18): ⌘]
            // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // Hidden Button pattern.
            Button("Next chat") {
                wenshuLogger.info("[wenshu.chat] next-chat requested (\(vm.messages.count) messages in current)")
                // Future ticket: wire to the same
                // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // to the chat at vm.currentIndex + 1).
            }
            .keyboardShortcut("]", modifiers: [.command])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T70-COPY-CONVERSATION (2026-09-18): ⌘⇧C = copy
            // … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // the text field still keeps focus').
        .onReceive(NotificationCenter.default.publisher(for: .wenshuDefocusChatInput)) { _ in
            inputFocused = false
        }
        // Apple HIG canonical file-export / file-import for the
        // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // MARK: - Transcript viewport (= the inner ScrollView { LazyVStack { ForEach turns { Section { ... } } } } block; = extracted from body in A99 to fight the 1368-LOC god-class)
    @ViewBuilder
    private var transcript: some View {

    ScrollView {
                        // 2026-09-23: 'the user's message bubble, like
                        // … (= 16 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
                        // … (= 55 rationale lines collapsed; = A112 docblock collapse per §1.8)
                        // peeks behind the input bar).
                        .contentMargins(.bottom, DesignTokens.chatInputBarHeight, for: .scrollContent)
                        // 2026-10-12 round-19 — add 10 PT top
                        // … (= 11 rationale lines collapsed; = A112 docblock collapse per §1.8)
                        // spec.
                        .padding(.top, 10)
                        // -cleanup E3 (see OOB.md #2026-09-21) '
                        // … (= 18 rationale lines collapsed; = A112 docblock collapse per §1.8)
                        // sitting above the window tier).
                    }
        }

}
