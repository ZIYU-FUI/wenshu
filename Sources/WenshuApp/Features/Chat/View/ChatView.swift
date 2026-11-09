// ChatView.swift
import os
import SwiftUI
import WenshuAgent
import WenshuData

private let wenshuLogger = Logger(subsystem: "com.wenshu", category: "chatview")

struct ChatView: View {
    /// The chat view's model. It owns the transcript, the input text and the send
    /// path.
    @State var vm: ChatViewModel
    /// Focus management for the input box: when no provider key is configured the
    /// chat input is disabled AND loses focus (= no cursor blinking, no keyboard
    /// capture).
    @FocusState var inputFocused: Bool
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
    @State var isExportingMarkdown: Bool = false
    @State var isOpeningMarkdown: Bool = false
    // Pre-computed .md body for the current conversation (= cached so
    // .fileExporter does not have to re-format on every render).
    @State var exportMarkdownBody: String = ""
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

            // The chat's keyboard shortcuts, = = in a file of their own
            // (= = ChatView+KeyboardShortcuts.swift). = = Every one of them
            // is a hidden button that carries only a shortcut, = = and the
            // VStack's spacing is 0, = = so they take no room here.
            keyboardShortcuts
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
