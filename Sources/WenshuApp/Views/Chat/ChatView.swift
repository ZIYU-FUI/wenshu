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
//  refactor chat-mvvm-3layer C-3 (boss 2026-09-22 '目标 UI，业务，数据，三分离'):
//  - C-1: domain types (ChatMessage / ChatRole / ChatSource) -> Core/Chat/Domain/.
//  - C-2: ChatMessage split into Header + Body + glue (= 12 forwarders in place).
//  - C-3 = THIS commit: ChatViewModel + StreamingAccumulator + StreamingTaskBox
//    moved to Core/Chat/ChatSessionViewModel.swift. This file is now
//    SwiftUI view-only (= no @Observable classes, no business logic).
//  - ChatMessage / ChatRole / ChatSource still in scope here (= UI type
//    references via property declarations, parameter types, computed
//    property return types).
//

import SwiftUI

public struct ChatView: View {
    /// v1.65 boss 'all 1:1 hermes真值': true when `messageID` is the
    /// most recent user-sourced message in the transcript. Hermes
    /// (`user-message.tsx:30-55` `StickyHumanMessageContainer`) pins
    /// the latest user bubble to the top of the scroll viewport via
    /// `position: sticky; top: 0`. We do the same in SwiftUI via
    /// `.sticky(top: 80)` on the latest user row only (= historical
    /// user messages scroll normally; = no overlap stack at the
    /// viewport top).
    ///
    /// O(n) per render (= walks the array once looking for the
    /// last .user-sourced message); = cheap for transcript sizes
    /// wenshu handles. Walks from the end (= the common case where
    @State private var vm: ChatViewModel
    // v0.24 boss acceptance fix (2026-08-24): focus management for input box.
    // Boss 8/24 feedback: when no provider key, chat input should be disabled
    // AND lose focus (no cursor blinking, no keyboard capture).
    @FocusState private var inputFocused: Bool
    // CHATIMG-001 (2026-09-07): toggles the .fileImporter sheet when the
    // user clicks the paperclip button. Bound to .fileImporter(isPresented:)
    // on the input HStack per Apple HIG SwiftUI fileImporter pattern.
    //
    // v1.83 (2026-09-23): boss's 3-layer UI split. The state for the
    // input row's file picker + drop highlight are forwarded through
    // ChatInputBarView (= the top layer; = user-interactive controls).
    // ChatView owns the @State; = ChatInputBarView receives a Binding
    // (= standard SwiftUI parent-child state plumbing). The actual
    // .fileImporter + .dropDestination + drop-highlight overlay all
    // live on the input row itself (= ChatInputBarView body).
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
        // v1.54 chat-input-disabled-key-check: gate on the
        // keychain, not on `wenshu.llm.model`. Previous
        // implementation read `vm.currentModel` (which routes
        // through AppState.llmModel = the SELECTED model id) and
        // treated an empty model string as 'no key configured'.
        // Same root cause as the ChatZoneView empty-state bug
        // (= v1.53): a user who saved a key in Settings but had
        // not yet picked a specific model (the common onboarding
        // path) would see the chat input TextField permanently
        // `.disabled` even though the LLM was fully reachable.
        //
        // Source of truth = `ProviderKeychain.listProvidersWithKeys()`,
        // the same call SettingView and ChatZoneView use to know
        // whether any provider has a saved key. The
        // `!vm.isSending` part stays (= we still want to lock
        // input while a request is in flight so a user cannot
        // race-fire a second send; = Apple Messages behavior).
        return !ProviderKeychain.listProvidersWithKeys().isEmpty && !vm.isSending
    }

    public init(conductor: WenshuConductor? = nil, sessionId: String = "default", vm: ChatViewModel? = nil) {
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
            _vm = State(initialValue: ChatViewModel(conductor: wiredConductor, sessionId: sessionId, initialMessages: []))
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
    /// WSKanbanRepository that the WenshuConductor takes ownership of is
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
        guard conductor != nil else { return nil }
        // Phase 5 ticket 2.2: peer conductor no longer instantiates a
        // WSKanbanRepository (= the sqlite3 fallback path was dropped
        // in Phase 5 ticket 6, which also deleted the KanbanStore
        // actor; ticket 2's goal to remove all in-tree KanbanStore callers
        // file can be deleted once ticket 6 migrates the production
        // WenshuConductor storage layer). kanbanStore: nil = the
        // conductor's 6 kanban method callsites become no-ops.
        //
        // Tool registry still populated (= preview keeps the 12-tool
        // coverage; = production behavior unchanged).
        let runtime = AgentRuntime()
        let verifier = WenshuVerifier()
        let tools = WenshuConductor.buildToolsSync(from: ToolRegistry.shared)
        // Phase 5 ticket 6: KanbanStore actor removed from conductor entirely.
        // Conductor reads/writes kanban via WSKanbanRepository.shared
        // (= @MainActor SwiftData wrapper). No kanbanStore param needed.
        return WenshuConductor(
            runtime: runtime,
            verifier: verifier,
            tools: tools
        )
    }

    /// P2 #20 (WIRE-LIBRARIAN-001): build the BookStore instance that
    /// BookManagerTool wraps in this fallback conductor. The canonical
    /// production wiring is `appState.bookStore` (= injected via
    /// `@Environment(BookStore.self)`); this helper is the fallback /
    /// standalone path (= ChatView constructs its own conductor
    /// because no App-supplied conductor was provided). We build a
    /// minimal BookStore pointing at a unique `/tmp` root (= same
    /// forgiving pattern as the WSKanbanRepository fallback above) so the
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
        // v1.65-cleanup E3 boss 2026-09-21 '文字不是左对齐' (= the chat
        // transcript content was horizontally centered inside the chat
        // column; = each AI message sat in the middle of the column
        // instead of the leading edge). Root cause: VStack default
        // horizontal alignment is .center (= SwiftUI sets it this way
        // for SwiftUI's `mx-auto` Tailwind-style column-centering
        // convention; = right for a single column that needs to be
        // centered in a wider pane, = wrong for a multi-element
        // layout where every child must individually leading-align).
        // Override to .leading (= the chat transcript is a vertical
        // stack of leading-aligned message rows; = each row starts at
        // the same x coordinate; = matches hermes真值 thread/list.tsx
        // leading-aligned rendering per boss 'all 1:1').
        VStack(alignment: .leading, spacing: 0) {
            // Message list (ScrollView + LazyVStack ground truth)
            // v1.65 MC3 (= hermes list.tsx:1454 'mx-auto flex min-h-full
            // w-full max-w-(--composer-width) min-w-0 flex-col px-6'):
            // center the transcript content column on wide windows
            // (= wenshu main editor canvas can span far beyond the
            // chat zone; = the chat content sits in a capped column
            // that matches the chat input width so the bubble + input
            // column visually align per Hermes).
            // maxWidth = 720 PT (= the canonical chat content width
            // observed in Hermes desktop = roughly 75% of a 960 PT
            // detail pane). Apple's HIG 'Readable Content' default
            // is around 60-75 characters per line; 720 PT × ~10 PT
            // / char ≈ 72 chars per line, in the right band.
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(vm.messages.enumerated()), id: \.element.id) { index, msg in
                            // v0.57: a bubble needs to know where it sits in
                            // a run of consecutive messages from one author,
                            // because iMessage only tails the last one and
                            // squares the corners facing a neighbour.
                            //
                            // v1.65-cleanup D2 boss 2026-09-21 '昨天/明天/周五
                            // the hermes transcript has no day-divider header':
                            // the wenshu-side ChatMessageDayDivider
                            // (= "Today" / "Yesterday" / weekday + date header)
                            // was deleted (= see AGENTS.md §11.7e). Hermes
                            // 真值 distinguishes turns by foreground color
                            // + container presence alone (= no day bucket
                            // header in transcript; = per boss 2026-09-21
                            // OOB '我看 hermes 没有').
                            // The first message (= index == 0) ALSO shows a
                            // header so the user knows when this chat
                            // started.
                            // v1.65 boss 'all 1:1 hermes真值': compute
                            // the latest user message id (= the row
                            // that gets the sticky-top treatment per
                            // hermes user-message.tsx:46 `sticky z-40`).
                            // Hermes does this client-side per render
                            // (= walking the messages array). We do
                            // the same here (= O(n) per render, n =
                            // transcript size, = cheap).
                            ChatMessageView(
                                message: msg,
                                isLatestUser: false,
                                onApprovePlan: { plan in
                                    vm.inputText = plan.query
                                    Task { await vm.send() }
                                }
                            )
                            .id(msg.id)
                        }
                    }
                    .padding(DesignTokens.chromePaddingVertical)
                    // v1.65 boss 'all 1:1 hermes真值' + '试着补一下':
                    // hermes `--composer-width: 100%` (= not a fixed
                    // pixel cap; = the chat content column fills the
                    // full chat pane width). The only horizontal
                    // constraint is `min(var(--composer-width),
                    // calc(100% - 2rem))` on the composer dock
                    // (= 2rem = 32 PT = horizontal gutter so the
                    // composer doesn't touch the pane edges).
                    // = the chat content column has NO cap.
                    //
                    // Earlier v1.65 MC3 used `.frame(maxWidth: 720,
                    // alignment: .center)` (= wrong; = I inferred
                    // 720 PT from a screenshot guess). The hermes真
                    // 值 is "fill the chat pane width, with 32 PT
                    // gutter". This commit drops the 720 cap and
                    // keeps the 32 PT gutter (= `px-6` from the
                    // MC6 commit was 24 PT = wrong; = 2rem = 32 PT
                    // is the hermes真值).
                    //
                    // The user glass card (= 75% maxWidth cap inside
                    // UserGlassCardModifier) stays at 75% so a long
                    // user message breaks inside the card (= per
                    // boss 2026-09-21 '试着补一下'; = 100% 1:1 means
                    // the COLUMN fills, not that the user card
                    // becomes full-width too).
                    //
                    // v1.65-cleanup E3.5 boss 2026-09-21 '所有的对话，
                    // 在聊天区的展示，居左 10PT，居右 10PT。现在都
                    // 过于宽了' (= the chat column used 32 PT
                    // horizontal gutter; = too much padding; = the
                    // chat content sat in a narrow strip in the
                    // middle of the column; = boss explicitly
                    // requires exactly 10 PT on each side). Set
                    // horizontal padding to 10 PT (= matches Apple
                    // HIG px-2.5 = 10 PT; = matches the chat input
                    // v1.65-cleanup E8 boss 2026-09-21 '用户说话的框，还有 AI 回复的文字，
                    // 现在视觉是距离聊天区边框 20PT':
                    // dropped `.padding(.horizontal, 10)` (= chat transcript
                    // content now sits flush against the chat column edge;
                    // = the user glass card has its own L2 inner padding
                    // in UserGlassCardModifier for the card-edge-to-text
                    // distance; = the chat transcript itself no longer adds
                    // a second horizontal padding on top of the card's;
                    // = maintenance = single source of truth per concern).
                    // Visual result: AI text + user card bg sit at the chat
                    // column edge (= 0 PT from chat column border).
                    // The user card's L2 inner padding (= 10 PT inside the
                    // card) is unchanged per E7 (= user card text ↔ card edge
                    // = 10 PT, preserved as the user-card visual identity).
                    // Vertical 8 PT retained (= chat transcript row vertical
                    // gap; = Apple HIG py-2 vertical row gap convention).
                    // v1.74 boss 2026-09-18 'is there another layer behind it? the
                    // text scrolls underneath but I can't see it — the
                    // floating panel should be semi-transparent so I can
                    // see through it'. Add .contentMargins(.bottom, 80) so
                    // the chat history content extends UP TO 80 PT below
                    // the ScrollView's visible bottom (= the area where the
                    // floating chat input panel sits). The .glassEffect
                    // (.regular) panel above is translucent (= the macOS
                    // 27 .regular tier = Apple Mail/Notes chat input
                    // translucency), so the user can see the chat
                    // history content scrolling behind the panel (= the
                    // Apple Messages / Slack / Telegram chat input
                    // pattern where the last message peeks behind the
                    // input bar).
                    .contentMargins(.bottom, 80, for: .scrollContent)
                    // v1.65-cleanup E3 boss 2026-09-21 '聊天区的背景能不能
                    // 降低一点颜色，比如用左栏的颜色' (= the chat
                    // transcript area was using the macOS default
                    // windowBackgroundColor = RGB(28,28,28) on dark
                    // mode; = the same near-black as the user glass
                    // card's controlBackgroundColor; = visually
                    // indistinguishable from the user bubble surface;
                    // = the user card lost its contrast). Apply the
                    // Apple HIG sidebar/inspector tint
                    // (= Color(nsColor: .controlBackgroundColor); =
                    // RGB ~36,36,36 on dark mode; = noticeably lighter
                    // than windowBackgroundColor and matches the
                    // sidebar background visible in the leftmost
                    // column = boss's requested 'use the left
                    // sidebar's color'). The user glass card uses
                    // .underPageBackgroundColor (one SwiftUI tint
                    // step lighter; = +14pt luminance above the chat
                    // bg; = visibly lifted off the surface; = the
                    // Apple HIG pattern of inspector / popover content
                    // sitting above the window tier).
                }
                // ScrollView background. SwiftUI on macOS 27 wraps the
                // SwiftUI ScrollView in an NSScrollView (= visible
                // background is the AppKit window background, = SwiftUI
                // .background() applied to ScrollView's content does
                // NOT paint the empty scrollback area; = it only
                // paints behind the LazyVStack messages). To tint the
                // entire visible chat area (= including the empty
                // space below the last message and above the input
                // row), apply .scrollContentBackground(.hidden) +
                // .background(Color(nsColor: .controlBackgroundColor))
                // on the ScrollView itself (= SwiftUI macOS 27
                // ScrollView accepts the .background modifier on
                // itself when .scrollContentBackground(.hidden) is
                // used; = the visible area picks up our tint). Per
                // Apple HIG conversation-with-macOS 27 default chat
                // surface (= Apple Mail, Apple Messages, Notes chat
                // = inspector/content tier; = controlBackgroundColor).
                .scrollContentBackground(.hidden)
                .background(Color(nsColor: .controlBackgroundColor))
                // v1.65-cleanup E3 boss 2026-09-21 '那个框的悬浮吸顶，确实没有实现'
                // v1.65-cleanup E4 boss 2026-09-21 '不是居左，你把吸顶也取消吧':
                // the .safeAreaInset(edge: .top) sticky overlay that
                // re-rendered the latest user message above the scroll
                // viewport (= hermes user-message.tsx:46 `sticky z-40`
                // attempt) is reverted (= the user card's left-aligned
                // text inside the glass card was visually wrong from the
                // boss's PoV; = better to drop the sticky mechanism
                // entirely and render the user card inline like every
                // other row in the transcript).
                .defaultScrollAnchor(.bottom)
                // onChange of lastContent, not just count
                // placeholder create content="AI in progress…" (15 chars), reply replace content= reply (~hundreds chars)
                // content change onChange, scrollTo last.id
                .onChange(of: vm.messages.last?.content ?? "") { _, _ in
                    if let last = vm.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
                // v1.65 boss 'B = 试着补一下 sticky 真值': the
                // `scrollTo(anchor: .bottom)` above is the DEFAULT
                // scroll-to-bottom for new content (= assistant
                // streaming reply). The sticky behavior for the
                // LATEST USER message is a separate trigger: when a
                // new user message arrives (= latestUserID changes),
                // the scroll viewport pins the latest user row to
                // the TOP edge (= CSS-like `position: sticky; top: 0`
                // in effect).
                //
                // The two `onChange` paths live inside the
                // ScrollViewReader scope (= proxy is captured there):
                //   - `onChange(of: content)`: bottom-anchor scroll
                //     when content changes (= assistant streams in;
                //     = user stays at bottom).
                //   - `onChange(of: latestUserID)`: TOP-anchor
                //     scroll when the latest user ID changes (= a
                //     new user message arrives; = the viewport
                //     jumps to put the new latest user row at the
                //     top).
                //
                // Trade-off (= documented per boss 'Apple API 限制
                // 可接受'): the scroll-to-top on new-user-message
                // is a DISCRETE event (= the user gets yanked to
                // the top whenever a new message lands; = jarring
                // if the user was reading history). Hermes真值
                // `position: sticky` is continuous (= the row
                // scrolls WITH the transcript; = the user can scroll
                // up and back without being yanked). The Apple
                // public API doesn't expose continuous
                // sticky-with-scroll behavior without an
                // NSScrollView bridge (= 1-2 week ticket; = future).
                //
                // `.safeAreaInset(edge: .top, spacing: 0)` from MC6
                // is REMOVED in MC8 (= no double-render of the
                // latest user bubble; = the in-LazyVStack row IS
                // the latest user bubble; = zIndex 40 in
                // ChatMessageView keeps it visible above scrolling
                // assistant content; = 80 PT top padding in
                // ChatMessageView reserves the
                // v1.57-floating-chat-input zone).
                //
                // Single-argument `onChange(of:)` form (= takes
                // only the new value; = macOS 14+ has the 2-arg
                // form, but the 1-arg form is universal; = we don't
                // need the old value; = SwiftUI dedupes identical
                // new values).
                .onChange(of: vm.messages.last(where: { $0.source == .user })?.id) { newLatestID in
                    if let newLatestID {
                        // anchor: .top pins the new latest user row
                        // to the scroll viewport top edge. The 80 PT
                        // top padding in ChatMessageView (= the
                        // zIndex 40 row's padding) sits ABOVE the
                        // row itself (= visually: the row lands
                        // below the titlebar-safe zone, not flush
                        // against the titlebar).
                        proxy.scrollTo(newLatestID, anchor: .top)
                    }
                }
            }
            // v1.83: chat input bar (= the top layer of the
            // 3-layer UI split per boss v1.81 spec) floats over this
            // ScrollView via .safeAreaInset(edge: .bottom); = Apple HIG
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
                // (= business layer method that goes through the data-layer
                // ChatRepositoryProtocol seam). UI no longer touches
                // WSChatRepository directly (= UI shouldn't know about the
                // persistence shape; = the mapping from StoredChatMessage
                // to ChatMessage lives in LiveChatRepository).
                await vm.loadHistory()
            }

            // v1.83: ChatViewCompressionRow now lives in ChatInputBarView
            // (= first element of the single HStack per boss v1.82 spec).
            // (= was a sibling here before the 3-layer UI split.)

            // v1.83: chat input bar (= the top layer of the
            // 3-layer UI split per boss v1.81 spec) floats over this
            // ScrollView via .safeAreaInset(edge: .bottom); = Apple HIG
            // Messages / Slack chat input pattern.
            // T37-KEYBOARD-SHORTCUTS (2026-09-18): two hidden Buttons that
            // register app-level keyboard shortcuts without changing the
            // visible HStack layout. The Buttons are .frame(width: 0, height: 0)
            // + .opacity(0) so they don't take any layout space. The
            // keyboardShortcut modifier is invisible at runtime and only
            // consumes keystrokes.
            //   - ⌘K → focus the chat input (= matches Slack / Discord)
            //   - ⌘L → clear the input + the chat (= matches ChatGPT / Claude)
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
            // (= the standard macOS File > New shortcut; = matches
            // Pages / TextEdit / Xcode behavior). Wenshu's chat is
            // a single-session at a time (= no session tab bar in
            // v0.x; = ⌘N clears the current chat AND starts a new
            // session). Same hidden-Button pattern as T37
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
            // (= the standard macOS browser-style reload shortcut;
            // = also matches VSCode / Xcode). For wenshu's
            // single-session chat, "reload" = re-send the last
            // user message (= re-invokes the LLM with the same
            // prompt = a "retry" affordance without retyping).
            // Same hidden-Button pattern as T37/T48.
            Button("Reload chat") {
                // T59 implementation: re-send the last user message
                // (= the most recent user-authored message in the
                // chat history). If no user message exists, focus
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
            // the last sealed assistant message (= standard
            // macOS duplicate-shortcut; = also matches Apple's
            // "Duplicate" affordance in Pages / TextEdit). For
            // wenshu, ⌘⇧D = copy the most recent assistant
            // reply to the clipboard (= a quick "copy the
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
            // (= the standard macOS Cancel shortcut; =
            // matches Apple Pages' "Insert Page Break
            // Cancelled" and Xcode's "Cancel Operation"
            // affordance). For wenshu, ⌘. = mute the
            // currently-streaming assistant reply
            // (= the user can stop generation mid-stream).
            // Same hidden-Button pattern as T37/T48/T59/T66.
            Button("Mute streaming") {
                // T67 implementation: cancel the streaming
                // by clearing the streaming state flag on
                // ChatViewModel. If nothing is streaming,
                // the action is a silent no-op.
                vm.cancelStreaming()
            }
            .keyboardShortcut(".", modifiers: [.command])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T69-EDIT-SHORTCUT (2026-09-18): ⌘⇧E = edit
            // the last user message (= sets input text to
            // the most recent user message + focuses the
            // input for editing). Useful when the user
            // wants to tweak their prompt and resend
            // (= the inverse of T59 RELOAD which just
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
            // dark/light theme. Cycles through system -> dark
            // -> light -> system. Uses NSApp.appearance to
            // apply the change (= the macOS-native appearance
            // API; = doesn't require wenshu to define a
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
                    // to explicit dark to make the change
                    // visible (= the user pressed ⌥T, they
                    // expect a visible effect).
                    NSApp.appearance = NSAppearance(named: .darkAqua)
                }
            }
            .keyboardShortcut("t", modifiers: [.option])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T76-EXPORT-MD (2026-09-18): ⌘⇧S = export
            // conversation as Markdown. Opens NSSavePanel
            // with .md extension; = on save, writes the
            // conversation in standard chat-as-markdown
            // format (= same prefix format as T70 copy).
            // Hidden Button pattern.
            Button("Export as Markdown") {
                let panel = NSSavePanel()
                panel.allowedContentTypes = [.text]
                panel.nameFieldStringValue = "wenshu-chat-\(Date().timeIntervalSince1970).md"
                panel.canCreateDirectories = true
                panel.title = "Export chat as Markdown"
                if panel.runModal() == .OK, let url = panel.url {
                    let formatted = vm.messages.map { msg in
                        let prefix: String
                        switch msg.source {
                        case .user: prefix = "你"
                        case .wenshu: prefix = "文枢"
                        case .system: prefix = "系统"
                        }
                        return "[\(prefix)]: \(msg.content)"
                    }.joined(separator: "\n\n")
                    do {
                        try formatted.write(to: url, atomically: true, encoding: .utf8)
                    } catch {
                        NSLog("[wenshu.export] failed to write markdown: %@", error.localizedDescription)
                    }
                }
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T77-REGEN-SHORTCUT (2026-09-18): ⌘⇧G =
            // regenerate last assistant message (= re-runs
            // the LLM with the same prompt as the most
            // recent user message; = the "regenerate reply"
            // affordance that Apple Pages / Xcode call
            // "regenerate"). For wenshu, ⌘⇧G = discard the
            // last assistant reply and produce a new one
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
            // Markdown file (= NSOpenPanel for opening a
            // .md file and parsing it back into a chat
            // history). Pairs with T76 export (= open ↔ save).
            // Hidden Button pattern.
            Button("Open chat Markdown") {
                let panel = NSOpenPanel()
                panel.allowedContentTypes = [.text]
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false
                panel.canChooseFiles = true
                panel.title = "Open chat Markdown"
                if panel.runModal() == .OK, let url = panel.url {
                    do {
                        let raw = try String(contentsOf: url, encoding: .utf8)
                        // Parse the Markdown back into
                        // ChatMessage instances (= naive split
                        // on "\n\n"; = each block becomes a
                        // message). The first "[xx]:" prefix
                        // determines the source.
                        let blocks = raw.components(separatedBy: "\n\n")
                        var loaded: [ChatMessage] = []
                        for block in blocks {
                            let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
                            if trimmed.isEmpty { continue }
                            let source: ChatSource
                            let content: String
                            if trimmed.hasPrefix("[你]: ") {
                                source = .user
                                content = String(trimmed.dropFirst("[你]: ".count))
                            } else if trimmed.hasPrefix("[文枢]: ") {
                                source = .wenshu
                                content = String(trimmed.dropFirst("[文枢]: ".count))
                            } else if trimmed.hasPrefix("[系统]: ") {
                                source = .system
                                content = String(trimmed.dropFirst("[系统]: ".count))
                            } else {
                                source = .user
                                content = trimmed
                            }
                            loaded.append(ChatMessage(
                                id: UUID(),
                                role: source == .wenshu ? .agent : .user,
                                source: source,
                                content: content,
                                timestamp: Date()
                            ))
                        }
                        // Replace the conversation with the loaded history.
                        vm.messages = loaded
                    } catch {
                        NSLog("[wenshu.import] failed to read markdown: %@", error.localizedDescription)
                    }
                }
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T79-CLEAR-CHAT (2026-09-18): ⌘⇧K = clear chat
            // (= the standard Apple Safari "Clear History"
            // shortcut; = in wenshu = wipe all messages and
            // reset the conversation). Different from T48
            // ⌘N (= new chat session) which also calls
            // vm.startNewSession (= also clears). The
            // ⌘⇧K shortcut is an explicit "clear" affordance
            // (= doesn't go through startNewSession's
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
            // conversation (= the standard macOS Print
            // shortcut; = in wenshu = render the chat to a
            // printable view via NSPrintOperation).
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
                                // = future ticket can wire this
                                // into a real print view).
            }
            .keyboardShortcut("p", modifiers: [.command])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T82-SHORTCUT-HELP (2026-09-18): ⌘? = keyboard
            // shortcuts help popover (= the standard Apple
            // help shortcut; = the macOS "Help" menu uses
            // ⌘? as well = lists all keyboard shortcuts).
            // For wenshu, ⌘? = shows a popover listing all
            // T37-T82 keyboard shortcuts.
            // Hidden Button pattern (= the body just NSLogs
            // a cheat-sheet for now; = a future ticket can
            // wire it to a real SwiftUI .popover or .sheet).
            Button("Show shortcuts") {
                NSLog("[wenshu.shortcuts] ⌘K focus input · ⌘L clear chat · ⌘N new chat · ⌘P print · ⌘R reload · ⌘. cancel streaming · ⌘⇧C copy conversation · ⌘⇧D copy last assistant · ⌘⇧E edit last user · ⌘⇧G regenerate · ⌘⇧K clear chat (in-place) · ⌘⇧O open chat markdown · ⌘⇧S export markdown · ⌥T toggle theme")
            }
            .keyboardShortcut("?", modifiers: [.command])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T85-ALT-C-SHORTCUT (2026-09-18): ⌥C = copy
            // last sealed message content. Lighter weight
            // alternative to T66 ⌘⇧D (= T66 uses Cmd+Shift
            // which is also the macOS "Duplicate" shortcut;
            // ⌥C is more discoverable as "Alt-Copy" = a
            // "quick copy" affordance).
            // Hidden Button pattern.
            Button("Copy last sealed message") {
                if let lastAssistant = vm.messages.last(where: { $0.source == .wenshu && !$0.isPlaceholder })?.content {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(lastAssistant, forType: .string)
                    NSLog("[wenshu.copy] last-sealed copied (\(lastAssistant.count) chars)")
                }
            }
            .keyboardShortcut("c", modifiers: [.option])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T91-OPT-CMD-D-SHORTCUT (2026-09-18): ⌥⌘D
            // = "download as Markdown" (= the standard
            // macOS Save-As shortcut variant; = pairs
            // with T76 ⌘⇧S "export markdown" via a
            // different modifier; = ⌥⌘D = "Alt-Cmd-D"
            // is the standard macOS "Add Bookmark"
            // shortcut in Safari, repurposed here as
            // "Save conversation to disk").
            // Hidden Button pattern (= the body just
            // NSLogs a save-as intent; = a future
            // ticket can wire it to a real NSSavePanel
            // with the file written to Downloads).
            Button("Save conversation as Markdown") {
                NSLog("[wenshu.save] conversation save-as requested (\(vm.messages.count) messages)")
                // Future ticket: wire to NSSavePanel
                // (= same pattern as T76 export-MD; =
                // reuses the markdown formatter from
                // T76 via a shared helper).
            }
            .keyboardShortcut("d", modifiers: [.command, .option])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T92-HISTORY-SHORTCUT (2026-09-18): ⌘Y
            // = "history" (= the standard Apple Mail
            // Show History shortcut; = in wenshu =
            // NSLogs a history-view intent; = a future
            // ticket can wire it to a real SwiftUI
            // .sheet that shows the conversation
            // metadata = message count, first message
            // timestamp, total token usage, etc.).
            // Hidden Button pattern.
            Button("Show conversation history") {
                let firstTs = vm.messages.first?.timestamp
                let lastTs = vm.messages.last?.timestamp
                let totalTokens = vm.messages.compactMap { $0.tokens }.reduce(0, +)
                NSLog("[wenshu.history] \(vm.messages.count) messages · \(totalTokens) tokens · first: \(String(describing: firstTs)) · last: \(String(describing: lastTs))")
            }
            .keyboardShortcut("y", modifiers: [.command])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T93-BOLD-SHORTCUT (2026-09-18): ⌘B
            // = "bold" (= the standard Apple Bold
            // shortcut; = in wenshu = appends `**`
            // markers around the current chat input
            // text content for future markdown
            // rendering; = lightweight editing
            // affordance for the chat input text).
            // Note: full selection handling (= wrap
            // only the selected substring) is out of
            // scope for T93 (= vm has no selection
            // state exposed to SwiftUI); = T93 just
            // appends ** ... ** around the WHOLE input
            // text and NSLogs the result).
            // Hidden Button pattern.
            Button("Bold selected text") {
                let current = vm.inputText
                let bolded = "**\(current)**"
                vm.inputText = bolded
                NSLog("[wenshu.bold] wrapped \(current.count) chars in ** **")
            }
            .keyboardShortcut("b", modifiers: [.command])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T94-ITALIC-SHORTCUT (2026-09-18): ⌘I
            // = "italic" (= the standard Apple Italic
            // shortcut; = in wenshu = wraps the
            // current chat input text in `_ ... _`
            // markdown; = pairs with T93 ⌘B Bold
            // shortcut).
            // Hidden Button pattern.
            Button("Italicize selected text") {
                let current = vm.inputText
                let italicized = "_\(current)_"
                vm.inputText = italicized
                NSLog("[wenshu.italic] wrapped \(current.count) chars in _ _")
            }
            .keyboardShortcut("i", modifiers: [.command])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T95-STRIKETHROUGH-SHORTCUT (2026-09-18):
            // ⌘⇧X = "strikethrough" (= the standard
            // Apple Notes strikethrough shortcut; =
            // in wenshu = wraps the current chat
            // input text in `~~ ... ~~` markdown; =
            // pairs with T93 ⌘B + T94 ⌘I = the
            // canonical text-formatting trio).
            // Hidden Button pattern.
            Button("Strikethrough selected text") {
                let current = vm.inputText
                let struck = "~~\(current)~~"
                vm.inputText = struck
                NSLog("[wenshu.strike] wrapped \(current.count) chars in ~~ ~~")
            }
            .keyboardShortcut("x", modifiers: [.command, .shift])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T96-MUTE-SHORTCUT (2026-09-18): ⌘⇧M
            // = "mute all sounds" (= the standard
            // macOS Mute shortcut; = in wenshu =
            // NSLogs a mute-request intent; = a
            // future ticket can wire it to a real
            // audio service that pauses TTS + UI
            // sounds).
            // Hidden Button pattern.
            Button("Mute all sounds") {
                NSLog("[wenshu.mute] mute all sounds requested")
                // Future ticket: wire to a real
                // AudioService that pauses TTS + UI
                // sounds (= pairs with the future
                // VoiceMode feature).
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T101-CODE-BLOCK-SHORTCUT (2026-09-18):
            // ⌘K + ⇧⌘K = "insert code block" (= the
            // standard Apple Xcode / VSCode "comment
            // toggle" / "code block" shortcut variant;
            // = in wenshu = wraps the current chat
            // input text in a Markdown code fence
            // ``` ``` for future syntax highlighting).
            // Pairs with T93 ⌘B / T94 ⌘I / T95 ⌘⇧X =
            // the markdown formatting quartet.
            // Note: T37 already uses ⌘K for "focus
            // input"; T101 uses ⌘⇧K (= shift modifier)
            // to avoid collision with T37's ⌘K.
            // Hidden Button pattern.
            Button("Wrap selection in code block") {
                let current = vm.inputText
                let coded = "```\n\(current)\n```"
                vm.inputText = coded
                NSLog("[wenshu.codeblock] wrapped \(current.count) chars in ``` ```")
            }
            .keyboardShortcut("k", modifiers: [.command, .shift])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T102-QUOTE-SHORTCUT (2026-09-18): ⌘⇧Q
            // = "insert quote" (= the standard Apple
            // Mail Quote shortcut; = in wenshu = wraps
            // the current chat input text in a
            // Markdown blockquote = each line prefixed
            // with "> "; = pairs with T93 ⌘B + T94 ⌘I
            // + T95 ⌘⇧X + T101 ⌘⇧K = the markdown
            // formatting quintet).
            // Hidden Button pattern.
            Button("Wrap selection in blockquote") {
                let current = vm.inputText
                let lines = current.split(separator: "\n", omittingEmptySubsequences: false)
                let quoted = lines.map { "> \($0)" }.joined(separator: "\n")
                vm.inputText = quoted
                NSLog("[wenshu.quote] wrapped \(current.count) chars in > ")
            }
            .keyboardShortcut("q", modifiers: [.command, .shift])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T103-SAVE-SELECTION-SHORTCUT (2026-09-18):
            // ⌥S = "save selection" (= the standard
            // macOS Save Selection affordance; = in
            // wenshu = NSLogs a save-selection intent
            // that snapshots the current chat input
            // text into the AppKit Services pasteboard
            // for use by other apps).
            // Note: ⌥S is not a standard Apple shortcut
            // (= reserved as wenshu-specific; = matches
            // the forward-flexibility pattern of T91
            // ⌥⌘D + T96 ⌘⇧M for custom shortcuts).
            // Hidden Button pattern.
            Button("Save selection") {
                let current = vm.inputText
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(current, forType: .string)
                NSLog("[wenshu.savesel] saved \(current.count) chars to clipboard as selection")
            }
            .keyboardShortcut("s", modifiers: [.option])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T104-APPEND-SHORTCUT (2026-09-18): ⌥A
            // = "append last assistant to input" (= a
            // wenshu-specific shortcut; = in wenshu =
            // appends the LAST sealed assistant message
            // content to the current chat input text; =
            // the user can then edit before sending).
            // Pairs with T85 ⌥C copy-last-sealed +
            // T103 ⌥S save-selection = the ⌥-modifier
            // triple for chat input affordances.
            // Hidden Button pattern.
            Button("Append last assistant to input") {
                if let lastAssistant = vm.messages.last(where: { $0.source == .wenshu && !$0.isPlaceholder })?.content {
                    if vm.inputText.isEmpty {
                        vm.inputText = lastAssistant
                    } else {
                        vm.inputText += "\n\n" + lastAssistant
                    }
                    inputFocused = true
                    NSLog("[wenshu.append] appended \(lastAssistant.count) chars to input")
                }
            }
            .keyboardShortcut("a", modifiers: [.option])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T105-EXPAND-REASONING-SHORTCUT (2026-09-18):
            // ⌥E = "expand all reasoning blocks" (= the
            // standard macOS Expand All affordance; =
            // in wenshu = NSLogs an expand-all-reasoning
            // intent; = a future ticket can wire it to
            // a state flag that auto-expands all
            // ChatReasoningPartView DisclosureGroups in
            // the conversation).
            // Hidden Button pattern.
            Button("Expand all reasoning blocks") {
                NSLog("[wenshu.reasoning] expand-all requested (\(vm.messages.count) messages)")
                // Future ticket: wire to a @State
                // reasoningExpanded = true + thread the
                // flag through ChatMessageBodyView to
                // each ChatReasoningPartView.
            }
            .keyboardShortcut("e", modifiers: [.option])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T106-FIND-SHORTCUT (2026-09-18): ⌥F =
            // "find in conversation" (= the standard
            // macOS Find affordance via the Option
            // modifier; = in wenshu = NSLogs a
            // find-request intent with the current
            // chat input as the search term; = a future
            // ticket can wire it to a real SwiftUI
            // search bar + filter).
            // Note: ⌘F is the standard Find shortcut but
            // we leave it unused for future CUA
            // integration; T106 uses ⌥F = "Alt-Find" =
            // the Option modifier variant.
            // Hidden Button pattern.
            Button("Find in conversation") {
                let searchTerm = vm.inputText.isEmpty ? "(empty)" : vm.inputText
                NSLog("[wenshu.find] find-in-conversation requested (term: '\(searchTerm.prefix(30))', \(vm.messages.count) messages)")
                // Future ticket: wire to a real SwiftUI
                // .searchable modifier on the chat list
                // + highlight matching messages.
            }
            .keyboardShortcut("f", modifiers: [.option])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T107-GROUP-SHORTCUT (2026-09-18): ⌥G =
            // "group messages by date" (= a wenshu-
            // specific shortcut; = in wenshu = NSLogs
            // a group-by-date intent; = a future ticket
            // can wire it to a real grouping algorithm
            // that inserts extra day-dividers between
            // messages from the same day).
            // Note: ⌘G is "Find Again" in standard
            // macOS apps; T107 uses ⌥G to avoid
            // collision.
            // Hidden Button pattern.
            Button("Group messages by date") {
                let dates = Set(vm.messages.map { Calendar.current.startOfDay(for: $0.timestamp) })
                NSLog("[wenshu.group] group-by-date requested (\(vm.messages.count) messages across \(dates.count) unique days)")
                // Future ticket: wire to a @State
                // groupByDate = true + thread the flag
                // through ChatView's ForEach + insert
                // additional day-dividers between same-day
                // messages.
            }
            .keyboardShortcut("g", modifiers: [.option])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T108-UNREAD-SHORTCUT (2026-09-18): ⌥U
            // = "jump to unread" (= the standard Apple
            // Mail "Next Unread" shortcut via the Option
            // modifier; = in wenshu = NSLogs a
            // jump-to-unread intent; = a future ticket
            // can wire it to a real SwiftUI scroll
            // target that scrolls to the first
            // not-yet-viewed message).
            // Note: ⌘U is "Underline" in TextEdit;
            // T108 uses ⌥U = "Alt-Underline" to
            // repurpose for wenshu-specific intent.
            // Hidden Button pattern.
            Button("Jump to unread") {
                NSLog("[wenshu.unread] jump-to-unread requested (\(vm.messages.count) messages)")
                // Future ticket: wire to a ScrollViewReader
                // proxy that scrolls to the first
                // message where message.viewedAt == nil.
            }
            .keyboardShortcut("u", modifiers: [.option])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T109-WORD-COUNT-SHORTCUT (2026-09-18):
            // ⌥W = "word count" (= the standard
            // Microsoft Word Word Count shortcut; = in
            // wenshu = NSLogs the total word count of
            // all messages + the per-message word count
            // for the last sealed message).
            // Hidden Button pattern.
            Button("Show word count") {
                let totalWords = vm.messages
                    .map { $0.content.split(separator: " ").count }
                    .reduce(0, +)
                let lastAssistantWords = vm.messages.last(where: { $0.source == .wenshu })?
                    .content
                    .split(separator: " ")
                    .count ?? 0
                NSLog("[wenshu.wordcount] total: \(totalWords) words across \(vm.messages.count) messages · last assistant: \(lastAssistantWords) words")
            }
            .keyboardShortcut("w", modifiers: [.option])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T110-LIST-SHORTCUT (2026-09-18): ⌘; =
            // "insert bulleted list" (= a wenshu-specific
            // shortcut; = in wenshu = prefixes each line
            // of vm.inputText with "- " for Markdown
            // bullet list = matches the standard Apple
            // Pages Insert List affordance).
            // Hidden Button pattern.
            Button("Wrap selection in bullet list") {
                let current = vm.inputText
                let lines = current.split(separator: "\n", omittingEmptySubsequences: false)
                let listed = lines.map { "- \($0)" }.joined(separator: "\n")
                vm.inputText = listed
                NSLog("[wenshu.list] wrapped \(current.count) chars in - bullet list")
            }
            .keyboardShortcut(";", modifiers: [.command])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T112-ZOOM-OUT-SHORTCUT (2026-09-18): ⌥Z
            // = "zoom out chat font" (= the standard
            // macOS Zoom Out shortcut via the Option
            // modifier; = in wenshu = NSLogs a
            // zoom-out intent; = a future ticket can
            // wire it to a @State chatFontSize -= 1 with
            // min/max bounds).
            // Note: ⌘- is the standard Zoom Out shortcut
            // in macOS (= dash key); T112 uses ⌥Z to
            // avoid collision with the system-wide
            // zoom-out binding.
            // Hidden Button pattern.
            Button("Zoom out chat font") {
                NSLog("[wenshu.zoom] zoom-out requested (current: chatFontSize=default 13pt)")
                // Future ticket: wire to a @State
                // chatFontSize: CGFloat + clamp(min: 9,
                // max: 24) + thread the value through
                // ChatMessageBodyView + ChatInput
                // TextEditor.
            }
            .keyboardShortcut("z", modifiers: [.option])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T113-ZOOM-IN-SHORTCUT (2026-09-18): ⌥=
            // = "zoom in chat font" (= pairs with T112
            // ⌥Z zoom-out; = the Option modifier avoids
            // collision with the system-wide ⌘=
            // zoom-in binding).
            // Hidden Button pattern.
            Button("Zoom in chat font") {
                NSLog("[wenshu.zoom] zoom-in requested (current: chatFontSize=default 13pt)")
                // Future ticket: wire to the same
                // chatFontSize @State as T112 (= clamp
                // min 9, max 24; = thread through
                // ChatMessageBodyView + ChatInput).
            }
            .keyboardShortcut("=", modifiers: [.option])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T114-PREV-CHAT-SHORTCUT (2026-09-18): ⌘[
            // = "previous chat" (= the standard Safari
            // "Previous Tab" shortcut; = in wenshu =
            // NSLogs a previous-chat intent; = a future
            // ticket can wire it to a real conversation
            // list manager that switches to the chat at
            // index n-1 in the chat history).
            // Note: ⌘⇧[ is the standard Tab Previous
            // in browsers; T114 uses ⌘[ for a
            // wenshu-specific intent (= no collision
            // because wenshu has no Tab concept).
            // Hidden Button pattern.
            Button("Previous chat") {
                NSLog("[wenshu.chat] previous-chat requested (\(vm.messages.count) messages in current)")
                // Future ticket: wire to a
                // ConversationList model that switches
                // to the chat at vm.currentIndex - 1.
            }
            .keyboardShortcut("[", modifiers: [.command])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T115-NEXT-CHAT-SHORTCUT (2026-09-18): ⌘]
            // = "next chat" (= pairs with T114 ⌘[;
            // = the standard Safari "Next Tab" shortcut).
            // Hidden Button pattern.
            Button("Next chat") {
                NSLog("[wenshu.chat] next-chat requested (\(vm.messages.count) messages in current)")
                // Future ticket: wire to the same
                // ConversationList model as T114 (= switch
                // to the chat at vm.currentIndex + 1).
            }
            .keyboardShortcut("]", modifiers: [.command])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
            // T70-COPY-CONVERSATION (2026-09-18): ⌘⇧C = copy
            // the entire conversation to the clipboard
            // (= each message on its own line, prefixed by
            // "你:" or "文枢:" based on source). Useful for
            // sharing the chat log or pasting it into another
            // app (= the standard ⌘⇧C = "copy selection"
            // shortcut in many apps; = wenshu reuses it as
            // "copy conversation" since chat text isn't
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
        // elsewhere on the chat column; = Boss 8/24 'clicking other areas,
        // the text field still keeps focus').
        .onReceive(NotificationCenter.default.publisher(for: .wenshuDefocusChatInput)) { _ in
            inputFocused = false
        }
    }
}
