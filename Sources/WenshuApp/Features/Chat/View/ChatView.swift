// ChatView.swift
import os
import SwiftUI
import WenshuAgent
import WenshuData

private let wenshuLogger = Logger(subsystem: "com.wenshu", category: "chatview")

struct ChatView: View {
    /// The chat view's model. It owns the transcript, the input text and the send
    /// path.
    /// The chat's model, observed.
    ///
    /// `@Bindable` holds the model AND observes it (= = the tree's own
    /// way, = = and the way the chat's input bar does it).
    /// MEASURED: a plain `onChange(of: vm.someProperty)` on a
    /// `@State`-held `@Observable` model never fired (= = the change does
    /// not reach the view), = = and a SECOND copy of the model (= = a
    /// `@Bindable` beside the `@State`) is a DIFFERENT observation of
    /// the same instance, = = so a change the test made was invisible to
    /// the view. One property, observed once.
    @Bindable var vm: ChatViewModel
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
    /// product SwiftUI fileImporter pattern). The state for the input row's file
    /// picker and its drop highlight are forwarded through `ChatInputBarView`;
    /// `ChatView` owns the `@State` and the input row receives a `Binding` (=
    /// standard SwiftUI parent-child state plumbing). The `.fileImporter`, the
    /// `.dropDestination` and the drop-highlight overlay all live on the input row
    /// itself.
    @State private var showingImageImporter: Bool = false
    /// True while a drag is hovering the input row, so the row can show a drop
    /// highlight. Apple's `.dropDestination` reports this for free.
    @State private var isDropTargeted: Bool = false
    // the product export/import sheets for the conversation as Markdown.
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
    /// Is the reader the one moving the transcript? Apple's own phase.
    @State private var readerIsScrolling = false
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
        // racing the first, per the product's send policy). A view-body computed
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
            _vm = Bindable(wrappedValue: vm)
        } else {
            // InitialMessages via.task async load (avoids init race) scope for
            // this ticket. AUDIT.md §2.2 partial: resolve the conductor from the
            // public facade if no explicit instance is passed; = the ChatView
            // init signature stays unchanged for callers that pass
            // `WenshuAppDelegate.sharedConductor` (= deprecation bridge).
            let resolved = conductor ?? WenshuAgent.shared.currentConductorSync()
            let wiredConductor = ChatView.conductorRegisteringParagraphAI(resolved)
            _vm = Bindable(
                wrappedValue: ChatViewModel(
                    conductor: wiredConductor,
                    sessionId: sessionId,
                    initialMessages: []
                )
            )
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
        // The ChatView's WenshuConductor used to be constructed without
        // a connector, so it fell through to the legacy pipeline: the user
        // saw a single LLM reply with no tool use (= the "small liar" bug).
        // The fix is to pass the active connector so the
        // conductor routes through the ReAct loop (= same fix as
        // WenshuAppDelegate).
        return WenshuConductor(
            connector: WenshuAgent.shared.activeLLMConnector(),
            tools: tools,
            // The book's own report, = = so this path's turns carry it
            // too (= the same report the launch path carries).
            continuityProvider: BookContinuityProvider.live()
        )
    }

    /// One row of the transcript.
    ///
    /// The transcript is ONE flat list of messages: the user's own message
    /// is a row among the others, and every row scrolls with the content.
    ///
    /// The user's row carries the standard vertical band, so the bubble
    /// sits the same distance from its neighbours as every other row's
    /// text does.
    @ViewBuilder
    private func transcriptRow(_ message: ChatMessage) -> some View {
        let row = ChatMessageView(
            message: message,
            onApprovePlan: { plan in
                vm.inputText = plan.query
                Task { await vm.send() }
            },
            // The reader's collapse of a thinking block goes back into the
            // message and the part it belongs to (= the writer is the
            // model's own, held here because this is where the model is in
            // scope). Nothing in the transcript keeps that answer in a
            // view.
            onThinkingReveal: { messageID, partID, revealed in
                vm.setThinkingRevealed(revealed, messageID: messageID, partID: partID)
            }
        )
        // A row for a reply the frame did not touch is the same row it was
        // a moment ago. The comparison is what stops one appended token
        // from being laid out through every row of the conversation.
        .equatable()
        .id(message.id)
        if message.source == .user {
            row.padding(.vertical, DesignTokens.spacingStandard)
        } else {
            row
        }
    }

    var body: some View {
        // Whether the way back is offered (= = the reader is away from
        // the bottom). It is read ONCE, = = here, = = because the
        // control's own condition (= = inside the overlay) is not a
        // dependency the body takes: MEASURED, the control never
        // appeared while the condition lived in the overlay.
        let offersWayBack = vm.offersWayBack
        // The request to go back is READ here, = = so the view knows
        // about it: a modifier's argument (= = `.task(id:)`) is not a
        // dependency the body takes, = = so without this read the view
        // would not re-evaluate when the request changed, = = and the
        // task would never restart. MEASURED: the scroll never
        // happened.
        let _ = vm.jumpToNewestRequest
        // The newest block's key is READ here, = = so the view knows
        // when the reply grew (= = the follow's trigger; = = see the
        // `.task(id:)` above).
        let _ = vm.messages.last?.streamFollowKey
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
            // 75% of a 960 PT detail pane). the product design rules 'Readable Content'
            // default is around 60-75 characters per line; 720 PT × ~10 PT char ≈
            // 72 chars per line, in the right band. The 10 PT top padding
            // applies to the ScrollView chain below (= the ScrollView's content area;
            // = the transcript's first message is pushed down 10 PT inside the
            // scroll viewport; = 10 PT visible gap between the editor zone's
            // bottom status bar above and the first message bubble). 10 PT is
            // the user's verbatim spec.
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
                    //
                    // The viewport's bottom edge is the content's bottom
                    // edge (= = the last line stays visible when the
                    // column re-wraps and the content grows).
                    //
                    // MEASURED: without it, the transcript's own suite
                    // fails its width invariant (= = the last line falls
                    // below the viewport when the column narrows).
                    .defaultScrollAnchor(.bottom)
                    //
                    // The viewport is ALSO bound to the ROW the reader
                    // is looking at.
                    //
                    // Apple's `scrollPosition(id:anchor:)` binds the
                    // scroll view to the id of the row at the anchor,
                    // and its own documentation says the binding "is
                    // updated when a scroll view within this view
                    // scrolls" (= = the reader's own scroll writes it
                    // back).
                    //
                    // It is what the follow names (= = the clearance
                    // row, = = the content's bottom edge), = = and it is
                    // what holds the reader's place while the content
                    // grows underneath them.
                    //
                    // MEASURED on macOS 27.2.1: with the bottom anchor
                    // alone, a reader who had scrolled up was dragged
                    // back to the bottom by the arriving reply (= = their
                    // offset jumped from 480 to 1200, = = the new
                    // maximum); with the row binding naming the
                    // reader's row, their offset stayed put (= = 272
                    // while the content grew).
                    .scrollPosition(id: $vm.anchoredRowID, anchor: .bottom)
                    // Apple's own change detection: the action runs when
                    // the content's height changes, not on every scroll
                    // event. The follow is the app's own: it runs only
                    // while the reader is at the bottom, so a reader who
                    // is reading history keeps their place.
                    .onScrollGeometryChange(for: CGFloat.self) { geometry in
                        geometry.contentSize.height
                    } action: { _, _ in
                        followNewestContent(proxy)
                    }
                    // Is the reader the one moving? Apple's own answer
                    // (= = it names the gesture, the trackpad's inertia, and
                    // the moment they let go), so the gate never has to
                    // guess that a scroll happened.
                    .onScrollPhaseChange { _, phase in
                        readerIsScrolling = (phase == .interacting || phase == .decelerating)
                    }
                    // Apple's own answer to "is the reader at the bottom":
                    // the clearance row IS the content's bottom edge, and
                    // Apple reports the visibility of the transcript's
                    // scroll targets as it changes. A reader who nudged the
                    // scroll still has that row on screen; a reader who
                    // went back into the history does not.
                    .onScrollTargetVisibilityChange(idType: UUID.self) { ids in
                        // The bottom of the transcript is either row: the
                        // clearance row (the content's bottom edge) or the
                        // newest message, because the lazy stack lays the
                        // clearance row out last. MEASURED in the hosted
                        // chat: the signal fires with 0 visible targets,
                        // then 1 without the clearance row, then 2 with it.
                        // A report taken mid-layout therefore names the
                        // newest row and not the clearance row, and reading
                        // that as "away" would flash the way back on window
                        // open and on every conversation switch.
                        let newest = vm.messages.last?.id
                        let bottomVisible = ids.contains(ChatTranscriptBottom.clearanceID)
                            || (newest.map(ids.contains) ?? false)
                        // Two different facts must not be read as one:
                        // "the bottom is not on screen" and "the reader
                        // left the bottom". Writing the gate from the
                        // absence alone would offer the way back and stop
                        // the follow while the reader never moved.
                        //
                        // So the absence counts only when the reader is the
                        // one moving (= = Apple's own phase), and the
                        // presence always counts (= = they are back).
                        if bottomVisible || readerIsScrolling {
                            vm.readerAtBottomChanged(bottomVisible)
                        }
                    }
                    //
                    // The transcript follows the newest content: when the
                    // newest block of the last message changes (= the
                    // assistant's streaming reply growing), the viewport
                    // scrolls to that message's bottom. There is no second
                    // trigger that jumps the viewport to the newest user row:
                    // the conversation is one list, so every message scrolls
                    // with the rest of it.
                    //
                    // The key is the newest block's identity and length, not
                    // the reply's whole text. Reading the whole text made the
                    // frame compare the entire answer against what it was a
                    // moment ago (= an O(reply) copy and comparison per
                    // token), which is the cost this card exists to remove.
                    // Following the newest block rather than only the answer
                    // text also means a tool card that lands at the end of a
                    // reply is scrolled to, which is what "follow the newest
                    // content" says it should do.
                    //
                    // `.task(id:)` carries it, = = not `onChange`:
                    // MEASURED, `onChange` over a model's `@Observable`
                    // property never fired here (= = the view was not
                    // re-evaluated, = = so the follow never happened).
                    // The key is READ in the body (= = see below), = = so
                    // the view knows the newest block changed.
                    .task(id: vm.messages.last?.streamFollowKey) {
                        followNewestContent(proxy)
                    }
                    // The reader asked to go back to the newest content
                    // (= = the floating control's click). The request
                    // lives in the model (= = "the reader wants the
                    // newest content" is a fact about the conversation,
                    // = = not about the viewport), = = and the view is
                    // what turns it into a scroll.
                    //
                    // `.task(id:)` is what carries it, = = not
                    // `onChange`: MEASURED, `onChange` over a model's
                    // `@Observable` property never fired here (= = the
                    // view was not re-evaluated, = = so the scroll never
                    // happened), = = and `.task(id:)` restarts when the
                    // id changes, = = which is Apple's own pattern for
                    // "something happened, = = do it now".
                    .task(id: vm.jumpToNewestRequest) {
                        guard vm.jumpToNewestRequest > 0 else { return }
                        followNewestContent(proxy, force: true)
                    }
            }
            // The way back to the newest content, floating above the
            // composer. It appears only while the reader is away from
            // the bottom, and it takes no room while it is hidden (= =
            // it cannot swallow a click meant for the transcript).
            //
            // It sits on the VIEW, = = not on the transcript: the
            // transcript is a computed property, = = and a condition it
            // does not read does not make it re-evaluate. MEASURED: the
            // control never appeared when the condition lived there.
            .overlay(alignment: .bottom) {
                if offersWayBack {
                    ChatScrollToBottomButton {
                        vm.requestJumpToNewest()
                    }
                    .padding(.bottom, DesignTokens.spacingStandard)
                }
            }
            // Chat input bar (= the top layer of the 3-layer UI split per the
            // spec) floats over this ScrollView via .safeAreaInset(edge:.bottom);
            // = the product's own chat-input placement, no vendor pattern claimed.
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
        // the product file-export / file-import for the conversation as
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
    // messages { ... } } } block).

    private var transcript: some View {
        ScrollView {
            // The transcript is ONE flat list of messages.
            //
            // Every message is a row among the others: the user's own
            // message scrolls with the conversation like every other row,
            // and the newest content is what the panel shows. Nothing is
            // held at the viewport's top edge, so no row is ever cut off
            // by the panel's own top area.
            LazyVStack(alignment: .leading, spacing: DesignTokens.spacingStandard) {
                ForEach(vm.messages) { message in
                    transcriptRow(message)
                }
                // The blank space below the last message (= = the input
                // bar's height), as a row OF the content.
                //
                // A bottom margin on the scroll content sits OUTSIDE the
                // content's own height, = = so the content's bottom edge is below
                // the last message's, = = and no row's bottom edge was
                // the content's bottom edge (= = the viewport's anchor,
                // = = which names a ROW, = = could not put the content's
                // bottom edge at the viewport's bottom edge).
                //
                // As a row of the content, it IS the content's bottom
                // edge, = = and the anchor names it.
                //
                // The row is the input bar's height, = = and the stack's
                // spacing (8 PT) sits before it, = = so the blank space
                // below the last message is the same 88 PT the margin
                // gave (= = the margin is gone, = = so the two must not
                // both be there).
                Color.clear
                    .frame(height: DesignTokens.chatInputBarHeight)
                    .id(ChatTranscriptBottom.clearanceID)
            }
            // The rows are the scroll view's targets, = = so the binding
            // can name the row the reader is looking at (= = Apple's
            // `scrollPosition(id:)` needs `scrollTargetLayout()` to know
            // what the ids belong to).
            .scrollTargetLayout()
            // The transcript's padding, minus the bottom: the bottom padding puts
            // the content's bottom edge BELOW the last message's, so the chat's
            // scroll to the last message lands short of the maximum offset, and a
            // transcript short of the maximum is not anchored (= the bottom
            // anchor holds only while the offset IS the maximum).
            .padding(.horizontal, DesignTokens.spacingStandard)
            .padding(.top, DesignTokens.spacingStandard)
            // — add 10 PT top spec.
            .padding(.top, 10)
            // The cleanup keeps the row sitting above
            // the window tier (see OOB.md #2026-09-21).
        }
    }
}
