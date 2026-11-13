// ChatZoneView.swift
//
// per Apple HIG = one view per file.
//
// ChatZoneView = the chat-zone root container (= AI provider model
// selector + ChatView + HelpTextOverlay).
//
// -m1-shell (see OOB.md #2026-09-10) OOB 'drop the chat zone's top bar entirely, including the archive
// icon button and the tabs — basically the whole top bar. For the zone's internal padding, if the API
// provides one, let the API handle the defaults':
// the chat zone no longer hosts any top-bar chrome (= no top
// tab bar, no 3-tab HStack, no archive icon, no TEB). The
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
import WenshuAgent
import WenshuData

struct ChatZoneView: View {
    let conductor: WenshuConductor?
    // Chat persistence lives
    // in WSChatRepository.shared (= the SwiftData migration; see CHANGELOG.md) (= @MainActor SwiftData wrapper).

    @Environment(AppState.self) private var envAppState
    // sidebarSelection moved from ShellState to WorkspaceUIState.
    @Environment(WorkspaceUIState.self) private var workspaceUI
    @Environment(WenshuLibrary.self) private var library
    @Environment(BookStore.self) private var bookStore

    private var appState: AppState {
        envAppState
    }

    private var currentModel: String {
        get { appState.llmModel }
        nonmutating set { appState.llmModel = newValue }
    }

    @State private var vm: ChatViewModel
    /// / Reactive counter incremented every time
    /// / `Notification.Name.wenshuProviderKeychainChanged` fires.
    /// / The empty-state gate below (= `if !ProviderKeychain
    /// / .listProvidersWithKeys().isEmpty`) reads the keychain
    /// / on every body evaluation; = bumping this counter via
    /// / `.onReceive` makes SwiftUI re-evaluate the body and
    /// / re-pick up the freshly-configured key (= the
    /// / `ChatHelpTextOverlay` disappears the moment a key is
    /// / configured; = the chat input row becomes interactive).
    /// The previous commit (= 342098394) gated the history load;
    /// / the commit right after this one (= fffd74af5) gated
    /// / `ChatView` re-render. This gate (= on `ChatZoneView`)
    /// / was still missing; = the empty-state overlay kept
    /// / floating above the now-loaded transcript until the user
    /// / manually forced a body invalidation.
    @State private var keychainRevision: Int = 0

    init(conductor: WenshuConductor? = nil) {
        // AUDIT.md §2.2 partial (2026-10-16): the public
        // facade is the canonical source of truth for the
        // conductor; = if no conductor is injected, resolve
        // it from the facade. Callers that still pass
        // `WenshuAppDelegate.sharedConductor` (= the
        // deprecation bridge = the same value, since the
        // static is now a 1-line forwarder to the facade)
        // continue to work unchanged.
        let resolved = conductor ?? WenshuAgent.shared.currentConductorSync()
        self.conductor = resolved
        _vm = State(initialValue: ChatViewModel(conductor: resolved, appState: nil))
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
            // / Per boss 2026-10-16 OOB "配上了 KEY 之后,
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // / the keychain is the empty-state gate (= below); =
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // / body dependency (= = the SwiftUI re-render trigger
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // / `.onReceive` of `wenshuProviderKeychainChanged` at
            // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
            // / empty-state overlay disappears the moment a key
            // / is configured. Reading the counter here (= in the
            // / outer body) registers the @State as a body
            // / dependency for the whole `VStack`.
            let _ = keychainRevision
            // The session tab bar (= the chat zone's top bar). It shows
            // one page per conversation scope: the repository
            // conversation, one page per ordinary book, and the
            // reference-library conversation.
            //
            // The bar and the directory tree are two views over ONE
            // selection (= `workspaceUI.sidebarSelection`), so the
            // bar's page and the tree's row can never disagree. The
            // asset pane reads that same field, so its rules are
            // unchanged (= it shows the filter of the selected tree
            // row).
            //
            // The pages come from the library's CURRENT books, so a
            // new book gets a page at once (= the page list follows the
            // collection) and a deleted book leaves none behind.
            //
            // ⇒ ⇒ ⇒ IT IS BUILT BY `sessionBar`, = the one named door
            // the guard drives: = so the wiring from the bar's pick to
            // the tree's write is the wiring the guard holds.
            ChatZoneTabBar.sessionBar(
                pages: scopePages,
                selectedScope: currentScope,
                in: workspaceUI,
                applyScope: applyScope
            ).bar
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
                // before; = the revert was due to that earlier
                // branch being part of the broader migration
                // chat-input-row work that itself crashed =
                // unrelated to this empty-state gate logic):
                // the ProviderKeychain.listProvidersWithKeys() call
                // is in-memory after first read; = chat zone
                // re-renders are infrequent; = the cost is
                // negligible. Source of truth stays in one place
                // (SettingView + ChatZoneView + ChatView.hasUsableKey
                // = all three call ProviderKeychain.listProvidersWithKeys()).
                // / AUDIT.md §2.2 partial (2026-10-16): the
                // `listProvidersWithKeys().isEmpty` check now
                // goes through WenshuAgent.shared (= the public
                // facade; = sync `hasProvidersWithKeysCached()`
                // = no main-actor await; = the cache is warmed
                // by `ChatSessionViewModel.swift:656` at app
                // launch + refreshed on every keychain change
                // notification via `_publishCachedSnapshot`).
                if WenshuAgent.shared.hasProvidersWithKeysCached() {
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
        // wire the four book_X tools to honor
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
            Self.publishScope(vm: vm, into: envAppState)
            await wireBookScopeGuardIfPossible()
        }
        // The chat's identity (= session + book) is published so the
        // right-hand column's Status page can list this chat's
        // sub-agent tasks. Both halves travel as their strong types.
        .onChange(of: vm.currentBookID) { _, _ in
            Self.publishScope(vm: vm, into: envAppState)
        }
        .onChange(of: vm.valueForSessionId()) { _, _ in
            Self.publishScope(vm: vm, into: envAppState)
        }
        .onChange(of: library.selectedBookId) { _, _ in
            Task { await wireBookScopeGuardIfPossible() }
        }
        // / Per boss 2026-10-16 OOB "配上了 KEY 之后, 聊天记
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // / The chat zone's body reads `ProviderKeychain
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // / the `ChatHelpTextOverlay` (= the empty-state hint)
        // / on top of the now-loaded transcript. Bumping the
        // … (= 1 rationale lines collapsed; = A115 aggressive docblock collapse)
        // / `ChatHelpTextOverlay` to disappear the moment a key
        // / is configured.
        .onReceive(NotificationCenter.default.publisher(
            for: .wenshuProviderKeychainChanged
        )) { _ in
            keychainRevision &+= 1
            // AUDIT.md §2.2 partial (2026-10-16): refresh the
            // WenshuAgent.shared cache (= the sync-cached
            // variant that ChatZoneView + ChatView.hasUsableKey
            // read from). Without this refresh, the cache
            // would only update when `providersWithKeys()`
            // is explicitly awaited (= the chat-session
            // viewmodel path). The keychain change is
            // the canonical trigger for "the user just
            // configured a key" = refresh on every
            // notification.
            Task { await WenshuAgent.shared.providersWithKeys() }
        }
        // The chat column's background comes from the window's single
        // behind-window material. The NSWindow is non-opaque (= its
        // background colour cleared), the window's root carries one
        // `.regularMaterial` container background, and every container
        // inside the window stays transparent, so that one layer shows
        // through instead of a stack of opaque fills.
        //
        // The flat opaque sidebar fill that used to sit here was a
        // retreat from the behind-window material (= an
        // `NSVisualEffectView` with `.behindWindow` blending, = Apple's
        // sidebar primitive): it was taken while the window was opaque,
        // because a behind-window material cannot read the desktop
        // behind an opaque window.
        .environment(appState)
        // chat-by-book (after wire-up audit 2026-09-24):
        // the canonical source for the user's active book is
        // `workspaceUI.sidebarSelection` (= mutated by AppleSidebarView's
        // `forwardSelection(_:)` whenever the user clicks a row; = see
        // AppleSidebarView.swift L446-L465). WenshuLibrary.selectedBookId
        // was tried first (= the bookish-named field), but no code in the
        // production tree actually mutates it; = the same pattern
        // applies to `BookStore.reload(bookId:)` (= both functions exist but
        // neither has a caller; = the field stays at init time).
        //
        // Resolution: derive the scope from sidebarSelection.
        // - `.book` / `.folder` → that book's scope
        // - the reference-library root → the library scope
        // - every other row (a shelf, a reference category, a tag, no
        //   row) → the repository scope
        //
        // The bar's page and the tree's row are two views over this ONE
        // field, so this handler is the tree's half of the linkage.
        //
        // The handler also fires for the bar's OWN write (= SwiftUI
        // delivers it on the next render pass). That is harmless and it
        // is NOT a loop: the scope the bar wrote maps back to the same
        // scope, and `ChatViewModel.setScope` does nothing when the
        // scope is unchanged.
        .onChange(of: workspaceUI.sidebarSelection) { _, newSelection in
            applyScope(ChatScope.scope(for: newSelection))
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

    // MARK: - The session scope (= the tab bar and the tree over one selection)

    /// The scope the chat is talking about.
    ///
    /// It is derived from the tree's selection (= the tree is the app's
    /// source of truth for "what is selected"; = the asset pane reads the
    /// same field), so the bar's page and the tree's row can never
    /// disagree.
    private var currentScope: ChatScope {
        ChatScope.scope(for: workspaceUI.sidebarSelection)
    }

    /// The bar's pages, in display order.
    ///
    /// The repository conversation first, one page per ordinary book
    /// (= the help book contributes none), and the reference-library
    /// conversation last.
    private var scopePages: [ChatScopePage] {
        ChatScope.pageList(
            books: bookStore.books,
            repositoryTitle: String(localized: "chat.tab.repository_title"),
            libraryTitle: String(localized: "sidebar.reference_library.title")
        )
    }

    /// Point the chat at a scope (= its session id, = and its history).
    private func applyScope(_ scope: ChatScope) {
        vm.setScope(scope)
    }

    // MARK: - Book scope guard wiring (see OOB.md #2026-09-25)

    /// Publish the chat's identity (= session id + book id) onto the
    /// shared app state, so the right-hand column's Status page can
    /// list this chat's sub-agent tasks.
    ///
    /// Both halves travel as their strong types: the status page builds
    /// its registry scope from them directly, so no string conversion
    /// happens on the way out.
    static func publishScope(vm: ChatViewModel, into appState: AppState) {
        appState.chatSessionID = vm.valueForSessionId()
        appState.chatBookID = vm.currentBookID
    }

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
