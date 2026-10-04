// ChatZoneView.swift · Wenshu · v1.91b
//
// b (2026-09-23): the directive '聊天区的，文字回显层，是否可以变成左栏
// 的颜色参数。没有实现，是不是被限制了，是不是 NSV 框架里限制了，
// 你参数加的位置没有生效'. v1.91 added `.background(DesignTokens.
// sidebarBackground)` to ChatView's inner ScrollView; = that only
// paints the ScrollView's content area, NOT the visible chat column
// chrome around it (= the outer VStack + the NSSplitViewItem's AppKit
// container). Move the background to this outer VStack (= the view
// that actually fills the chat column's visible bounds). Same token,
// correct layer.
//
// per Apple HIG = one view per file.
//
// ChatZoneView = the chat-zone root container (= AI provider model
// selector + ChatView + HelpTextOverlay).
//
// -m1-shell (see OOB.md #2026-09-10) OOB 'drop the chat zone's top bar entirely, including the archive
// icon button and the tabs — basically the whole top bar. For the zone's internal padding, if the API
// provides one, let the API handle the defaults':
// the chat zone no longer hosts any top-bar chrome (= no
// ChatZoneTabBar, no 3-tab HStack, no archive ICON, no TEB). The
// body of the chat zone = bare ChatView (= the chat history +
// input field). Per Apple HIG TabViews docs 'if you only need
// to show ONE tab, don't show a tab bar at all'. All padding +
// inset inside the chat zone body = Apple API default (= no
// hand-rolled padding/spacing; = the SwiftUI List / NSSplitView
// system defaults decide).
//
// Architecture:
// - chat zone lives inside an `NSSplitViewItem` (= canCollapse
//   = true) in `EditorChatNSController` (= AppKit
//   NSSplitViewController; = the canonical Apple Keynote
//   speaker-notes API).
// - chat zone visibility is controlled by
//   `AppState.chatVisible` (= bound to the View > Show Chat
//   Zone menu item; ⌥⌘K).
// - the chat zone body hosts: ZStack { ChatView;
//   ChatHelpTextOverlay }.

import SwiftUI

struct ChatZoneView: View {
    let conductor: WenshuConductor?
    // Chat persistence lives
    // in WSChatRepository.shared (= v0.72 SwiftData migration; see CHANGELOG.md) (= @MainActor SwiftData wrapper).

    @Environment(AppState.self) private var envAppState
    // sidebarSelection moved from ShellState to WorkspaceUIState.
    @Environment(WorkspaceUIState.self) private var workspaceUI
    @Environment(WenshuLibrary.self) private var library
    @Environment(BookStore.self) private var bookStore

    private var appState: AppState { envAppState }

    private var currentModel: String {
        get { appState.llmModel }
        nonmutating set { appState.llmModel = newValue }
    }

    @State private var vm: ChatViewModel

    init(conductor: WenshuConductor?) {
        self.conductor = conductor
        _vm = State(initialValue: ChatViewModel(conductor: conductor, appState: nil))
    }

    var body: some View {
        // chapter-dialog 2026-09-28 T1: host the chapter focus-lock
        // Allow/Deny alert. The presenter (= ChapterFocusLockDialogPresenter)
        // is a @MainActor singleton that the conductor writes to; =
        // we observe it via the @State binding below so SwiftUI
        // re-renders when a new request is enqueued. The alert's
        // actions delegate back to the presenter (= the view layer
        // is dumb; = no business logic here).
        //
        // -m1-shell (see OOB.md #2026-09-10) OOB 'chat zone doesn't fill the width':
        // apply `.frame(maxWidth: .infinity, maxHeight: .infinity)` to
        // the outer VStack so the chat zone fills the full width
        // and height of its NSSplitViewItem slot.
        VStack(spacing: 0) {
            ZStack {
                ChatView(conductor: conductor, vm: vm)
                // Switch the empty
                // state gate from `appState.llmModel.isEmpty` (=
                // checks the SELECTED MODEL ID, not whether a
                // key is configured) to `!ProviderKeychain.
                // listProvidersWithKeys().isEmpty` (= checks the
                // authoritative source of truth for 'is the LLM
                // configured?' = same call SettingView uses to
                // know whether the LLM Connector tab has anything
                // configured). With a key already in the keychain,
                // `listProvidersWithKeys().isEmpty` returns false,
                // so the ChatHelpTextOverlay is dismissed and
                // the chat zone becomes interactive.
                // message (= the same bug was fixed once
                // before; = the revert was due to that v1.53
                // branch being part of the broader v1.55/v1.57
                // chat-input-row work that itself crashed =
                // unrelated to this empty-state gate logic):
                // the ProviderKeychain.listProvidersWithKeys() call
                // is in-memory after first read; = chat zone
                // re-renders are infrequent; = the cost is
                // negligible. Source of truth stays in one place
                // (SettingView + ChatZoneView + ChatView.hasUsableKey
                // = all three call ProviderKeychain.listProvidersWithKeys()).
                if !ProviderKeychain.listProvidersWithKeys().isEmpty {
                    EmptyView()
                } else {
                    ChatHelpTextOverlay {
                        // 
                        // Move the UserDefaults write into the business
                        // layer (= `ChatSessionViewModel.openSettingsToProviderApi`)
                        // so the UI only triggers the side-effect (= opens
                        // Settings) and doesn't own the storage write.
                        vm.openSettingsToProviderApi()
                        WenshuAppDelegate.openSettings?()
                    }
                    .allowsHitTesting(true)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // v2.1 (2026-09-25): wire the four book_X tools to honor
        // the chat session's currently-bound book + the user's
        // sidebar-selected book directory. Without this, the agent
        // can pass any book_id in JSON envelopes (= scope guard
        // would still reject cross-book writes; = but the
        // bookDirectory is also re-derived here so the actor
        // writes land on the right disk path).
        //
        // Re-wired on each change of `library.selectedBookId` so
        // switching books mid-conversation is honored. The
        // providers are cheap closures (= they just read
        // @Observable state on the main actor).
        // chapter-dialog 2026-09-28 T1: the Allow/Deny dialog for the
        // chapter focus lock. The presenter holds the current pending
        // request; = when it becomes non-nil, .alert(item:) renders
        // the dialog with Allow / Deny buttons (= Apple HIG canonical
        // permission prompt). The buttons delegate back to the
        // presenter (= no business logic in the view).
        .alert(
            item: Binding(
                get: { ChapterFocusLockDialogPresenter.shared.pendingRequest },
                set: { newValue in
                    ChapterFocusLockDialogPresenter.shared.pendingRequest = newValue
                }
            ),
            content: { request in
                ChapterFocusLockDialogAlert.makeAlert(for: request)
            }
        )
        .task {
            await wireBookScopeGuardIfPossible()
        }
        .onChange(of: library.selectedBookId) { _, _ in
            Task { await wireBookScopeGuardIfPossible() }
        }
        // 2026-09-23: '我们 UI 有多层，windows 层，
        // NVS层，聊天回显层，逻辑上，应该是 NVS 层，赋予各区说背景色
        // 和风格。但现在的颜色应该是 NVS 默认的。不知道能否修改。
        // 如果不能，那 windows\NVS 聊天区，变成透明的，聊天回显层
        // 指定颜色，应该也能正常显示。现在大概率是多层结构，导致
        // 颜色多层叠加就无限接近于黑色'.
        //
        // Apple HIG multi-layer background analysis:
        //   Layer 1: NSWindow (= opaque by default = .windowBackgroundColor)
        //   Layer 2: NSSplitViewItem (= opaque AppKit default)
        //   Layer 3: SwiftUI ChatZoneView (= our code)
        //   Layer 4: SwiftUI ChatView ScrollView (= our code)
        // Each layer paints a color; = stacking N colored layers
        // darkens the result (= user's '颜色多层叠加就无限接近于黑色').
        //
        // Apple HIG fix: make Layer 1 + Layer 2 TRANSPARENT;
        // let Layer 3/4 specify the visible chat column bg.
        //
        // Implementation:
        //   1. VisualEffectBlur with material=.sidebar AND blendingMode=underWindow:
        //      'underWindow' (= Apple HIG sidebar primitive; = same as
        //      List(.listStyle(.sidebar)) paints) reads the content
        //      BEHIND the window for vibrancy. But this requires
        //      NSWindow.isOpaque = false (= transparent); = wenshu
        //      uses opaque windows for chrome stability.
        //   2. So use blendingMode = .withinWindow instead:
        //      reads content WITHIN the window as the vibrancy
        //      source; = works with opaque windows; = still produces
        //      the canonical Apple HIG sidebar tint + slight blur
        //      (= identical surface to List(.listStyle(.sidebar))).
        //   3. The ChatView ScrollView's existing
        //      .background(DesignTokens.sidebarBackground) (= a
        //      solid Color that approximates the sidebar tint in
        //      case the visual effect view degrades) ensures the
        //      bg never goes to true black.
        //   4. NSWindow + NSSplitView remain AppKit default opaque
        //      (= they paint NOTHING visible — the chat column
        //      VisualEffectBlur overlays them entirely; = no
        //      multi-layer color stacking; = the chat column
        //      = single sidebar surface layer, identical to the
        //      left sidebar).
        //
        // keeps the v1.91d frame(...) wrap (= NSViewRepresentable
        // in .background() requires explicit frame; = same SwiftUI/AppKit
        // bridging quirk documented in v1.91d).
        // (2026-09-23): the directive '聊天区背景颜色没有实现' OOB follow-up.
// Replace the v1.93 VisualEffectBlur(.sidebar, .withinWindow) with
// the explicit `DesignTokens.sidebarBackground` Color (= the
// .controlBackgroundColor Apple HIG sidebar tint).
//
// Why drop VisualEffectBlur:
//   - v1.93 used NSVisualEffectView via NSViewRepresentable.
//   - In opaque NSWindow (= wenshu's default) .withinWindow
//     blending mode produced a sub-perceptual gradient (= ~14
//     RGB diff between top + bottom).
//   - the directive '聊天区背景颜色没有实现' = visual difference vs. sidebar
//     was still there.
//
// Why DesignTokens.sidebarBackground works (= previously approved):
//   - Single Color source (= same .controlBackgroundColor the
//     macOS sidebar uses). Both sidebars share the SAME bg token.
//   - Layer order = Network/Apple HIG transparent NSSplitView
//     (set in EditorChatNSController.viewDidLoad) + this Color
//     overlay. No more visual effect view gradient under us.
        .background(DesignTokens.sidebarBackground)
        .environment(appState)
        // chat-by-book (after wire-up audit 2026-09-24):
        // the canonical source for the user's active book is
        // `workspaceUI.sidebarSelection` (= mutated by AppleSidebarView's
        // `forwardSelection(_:)` whenever the user clicks a row; = see
        // AppleSidebarView.swift L446-L465). WenshuLibrary.selectedBookId
        // was tried first (= the bookish-named field), but no code in
        // the production tree actually mutates it; = the same pattern
        // applies to `BookStore.reload(bookId:)` (= both functions exist but
        // neither has a caller; = the field stays at init time).
        //
        // Resolution: derive bookID from sidebarSelection.
        // - `.book(let bookID)` → use bookID
        // - `.folder(let bookID, _)` → use bookID (= folder
        //   is a sub-row of a book; = same book scope)
        // - `.shelf / .reference* / nil` → nil (= global
        //   un-attached; = pre-v1.79 behavior when no book
        //   is selected).
        .onChange(of: workspaceUI.sidebarSelection) { _, newSelection in
            let bookID: UUID?
            switch newSelection {
            case .book(let id):
                bookID = id
            case .folder(let id, _):
                bookID = id
            case .shelf, .referenceCategory, .referenceLibraryRoot, .tag, nil:
                // v2.6 facet: tag selection maps to no specific book
                // (= the chat panel scopes to the global un-attached
                // bucket). All non-book selections clear the per-book
                // chat scope.
                bookID = nil
            }
            vm.setCurrentBookID(bookID.map { BookID(rawValue: $0.uuidString) })
        }
    }

    // (compactNumber removed 2026-10 in q99-spec-p0-batch2 — verify-dead.py
    //  confirmed 0 external callers; = the "1500 -> 1.5k / 1.5M" formatter
    //  was retained as a "Hermes format_token_count_compact canonical"
    //  helper but no ChatZoneView body consumed it (= chat-zone
    //  rendering does not surface token counts inline; = the
    //  conductor's token accounting surfaces elsewhere). See
    //  wenshu-pocock-workflow references/v3.0-design-system-rule.md
    //  + wenshu-dead-code-cleanup SKILL.md.)

    // MARK: - Book scope guard wiring (v2.1, 2026-09-25)

    /// Re-wire the four book_X tools on the conductor with
    /// value snapshots for the chat session's currently-bound book
    /// + the sidebar-selected book directory.
    ///
    /// Implementation note: ChatZoneView runs on the main actor
    /// (SwiftUI body default). `library.selectedBookId` and
    /// `bookStore.bookDirectoryCache[id]` are @Observable /
    /// @MainActor state (= cheap sync reads here). The conductor
    /// re-binds on every `.onChange(of: library.selectedBookId)`
    /// so switching books mid-conversation is honored.
    private func wireBookScopeGuardIfPossible() async {
        guard let conductor else { return }
        let currentChatBookID = vm.currentBookID.flatMap {
            UUID(uuidString: $0.rawValue)
        }
        let bookDirectory = library.selectedBookId.flatMap { id in
            bookStore.bookDirectoryCache[id]
        }
        await conductor.wireBookScopeGuard(
            currentChatBookID: currentChatBookID,
            bookDirectory: bookDirectory
        )
    }
}
