// Sources/WenshuApp/State/AppState.swift
//
// v0.30 boss 8/31 OOB "option A for cross-zone communication"
// (= adopted = global @Observable + @Environment injection).
// This file centralizes cross-zone UI state (formerly scattered
// as @Binding across 4 view layers = WorkspaceView -> PaneRenderer
// -> TabContentDispatcher -> ZoneModuleView -> NewLibraryOutlineView,
// per commit d845fe9c9).
//
// Why a global @Observable (= per Apple Observation framework,
// Swift 5.9+):
// 1. Instant reactivity (= any descendant view that reads
//    `appState.sidebarSelection` auto-re-renders on change).
// 2. Single source of truth (= one place for cross-zone signals).
// 3. Zero plumbing (= no @Binding chain to thread through new
//    views).
// 4. Boss can debug = `print(appState.sidebarSelection)` directly
//    (= vs grep NotificationCenter post names across N files).
// 5. Apple-native (= no 3rd-party dep, AGENTS.md §11.1 stays
//    unchanged).
//
// Per-window ownership: each WindowGroup instance creates its own
// AppState via `@State private var appState = AppState()` (= per
// boss 8/27 OOB multi-window future-proofing).
//
// Adding a new cross-zone signal = add 1 var here, done. No init
// signature changes, no binding chain updates.

import SwiftUI

/// App-wide observable state for cross-zone UI communication.
///
/// Owned by `WenshuApp` (= the App struct, = per-window via
/// `@State`), injected via `.environment(appState)` on
/// WiredShell. Descendants read it with
/// `@Environment(AppState.self) private var appState`.
///
/// All cross-zone UI state (= sidebar selection, sort order, etc.)
/// lives here. Persistence is handled at the observer (= typically
/// WorkspaceView writes to `@AppStorage` via `.onChange`).
@MainActor
@Observable
final class AppState {

    /// M1-shell (2026-09-08): opt-in to the Apple-native
    /// NavigationSplitView path (= 3-column layout per macOS 27
    /// `NavigationSplitView` = the canonical Apple HIG pattern
    /// per developer.apple.com/documentation/swiftui/navigationsplitview).
    ///
    /// Default `false` = existing users see ZERO behavior change
    /// on app upgrade (= `PaneSplitHost` path unchanged per the
    /// spec's "legacy path" rule).
    ///
    /// Set via:
    ///   defaults write com.wenshu.app wenshu.useThreeColumnSplit -bool true
    /// Reset via:
    ///   defaults delete com.wenshu.app wenshu.useThreeColumnSplit
    ///
    /// Lives on `AppState` (= the @Observable SwiftUI state; = read
    /// directly by `WorkspaceView.body` for the flag branch) NOT on
    /// `LayoutTreeState` (= the Codable workspace tree; = reserved
    /// for per-pane state like divider positions + column widths). The
    /// two states serve different scopes:
    /// - `AppState.useThreeColumnSplit` (= global = app-wide shell choice)
    /// - `LayoutTreeState.*` (= per-pane = divider positions, weights, collapsed flags)
    var useThreeColumnSplit: Bool = false

    /// Sidebar tree selection (= 5 cases: .book(UUID) / .folder / .shelf
    /// / .referenceCategory / .referenceLibraryRoot, nil = nothing
    /// selected). Drives Preview pane scope (= see
    /// WorkspaceView.previewScope).
    ///
    /// Persisted to `wenshu.sidebarSelection` UserDefaults key
    /// (= JSON shape via Codable; = set by didSet = write back on
    /// every change; = read by AppState.init() at launch).
    ///
    /// v1.0.0-m1-shell boss 2026-09-10 OOB 'look at this persistence,
    /// I picked the directory I selected as Help > World, what the card
    /// displays is wenshu. Now restart. Let me see. It should disappear':
    /// the comment here previously claimed
    /// 'Persisted to wenshu.sidebarSelection' but the actual write
    /// / read code was missing (= only `useThreeColumnSplit`,
    /// `llmModel`, and `openTabs` had real persistence in init +
    /// didSet; = `sidebarSelection` was an in-memory @Observable
    /// property that reset to `nil` on every launch; = the boss's
    /// 'should disappear on restart' prediction was correct). This
    /// change restores the documented behavior: write the JSON
    /// encoding to UserDefaults on every set, read it back at
    /// AppState.init() (= the same pattern used for `openTabs`).
var sidebarSelection: SidebarItem? = nil {
        didSet {
            // B-05: didSet is NOT called during init (= Swift property
            // wrapper semantics), so this does NOT trigger a write
            // back to UserDefaults on launch (= pure read-side
            // migration). Encoded as JSON via the existing Codable
            // conformance (= SidebarItem: Hashable, Codable, declared
            // at NewLibraryOutlineView.swift:61).
            //
            // v0.71 P1 batch 6 dual-axis followup (= Q99 Standards axis MED):
            // added duplicate-write guard (= same pattern as
            // `activeTabId.didSet` and `llmModel.didSet` below) so a
            // burst of clicks (= N identical sets) only writes once.
            // UserDefaults.standard.set is in-memory fast (= does not
            // sync to disk synchronously per the Apple HIG UserDefaults
            // queue contract); = the "synchronous main-thread write"
            // audit concern is overblown for the actual implementation,
            // but the guard still helps avoid N redundant write calls
            // during rapid interaction (= e.g. keyboard nav spam).
            guard oldValue != sidebarSelection else { return }
            if let item = sidebarSelection,
               let data = try? JSONEncoder().encode(item) {
                UserDefaults.standard.set(data, forKey: Self.sidebarSelectionKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.sidebarSelectionKey)
            }
        }
    }

    /// UserDefaults key for sidebar selection persistence (= JSON).
    static let sidebarSelectionKey = "wenshu.sidebarSelection"

    // v1.0.0-m1-shell boss 2026-09-10 OOB 'Keynote + Pages + Numbers
    // all three office apps use this logic' (= 'Keynote / Pages / Numbers all use the same
    // inspector toggle logic'): the user can drag the right-column
    // divider to close the inspector, and clicking the right
    // content toggle in the top-right toolbar reopens the inspector
    // AND restores the previous content. This is the canonical
    // Apple HIG behavior for `.inspector(isPresented:)` per Apple's
    // WWDC23-10161 documentation: 'Inspectors can collapse by
    // default, but they aren't resizable by default. We can change
    // it with .inspectorColumnWidth. We can also add a toolbar
    // button to toggle the presented property.'
    //
    // Was previously removed by commit 5ad064686 (the boss's
    // earlier directive that 'Apple Pages/Keynote don't show a
    // inspector toggle button' = incorrect; = the toolbar toggle
    // button IS the Keynote/Pages/Numbers pattern for the
    // "presenter notes" / inspector reopen action; = per WWDC23).
    var inspectorVisible: Bool = true

    // v1.0.0-m1-shell boss 2026-09-10 OOB 'NSV default, the chat
    // zone area can be shown/hidden but the function is in the menu bar,
    // no dedicated button. I need to make this area toggleable now,
    // menu bar first, whether to add a button later is TBD':
    // the chat zone (= the bottom half of the detail column =
    // hosted by an `NSSplitViewItem` inside
    // `EditorChatNSController`) has a Show/Hide toggle that lives
    // in the macOS menu bar (= Apple HIG canonical pattern for
    // View > Show/Hide {Pane Name} menu items; = NO toolbar
    // button today; = matches the boss's 'menu bar first, whether to
    // add a button later is TBD' directive).
    //
    // When `chatVisible = true`, the chat zone NSSplitViewItem is
    // visible (= editor + chat zone = 50/50 detail column).
    // When `chatVisible = false`, the NSSplitViewItem.isCollapsed
    // = true (= the editor fills the full detail column; =
    // matches Keynote's 'presenter notes' Show/Hide behavior).
    var chatVisible: Bool = true

    // v1.0.0-m1-shell boss 2026-09-10 OOB 'the sidebar tree syntax does not match
    // Apple API': 3 sheet-request triggers moved from
    // NotificationCenter (.wenshuNewBookRequested /
    // .wenshuNewShelfRequested / .wenshuChoiceRequested) into
    // @Observable shared state. The toolbar Menu in AppRootScene
    // (.keyboardShortcut("n", modifiers: .command)) and the
    // sidebar's own New buttons (zoneHeaderButtons +
    // sidebarBottomNewButton) all need to flip the same `showNewX
    // Sheet` @State on the sidebar body. Cross-component writes
    // belong in shared @Observable state, not in a Notification
    // channel (= NotificationCenter is fire-and-forget, no observed
    // binding, requires manual @State copy on receiver side, =
    // fragile data flow). The pattern: the toolbar Menu or
    // sidebar button mutates appState.newBookRequestCount += 1;
    // the sidebar body observes via .onChange(of: appState.
    // newBookRequestCount) and flips its local showNewBookSheet.
    // Same approach for newShelfRequestCount + choiceRequestCount.
    var newBookRequestCount: Int = 0
    var newShelfRequestCount: Int = 0
    var choiceRequestCount: Int = 0

    // v1.0.0-m1-shell boss 2026-09-10 OOB 'global search': promote
    // the search text to AppState (= a single source of truth
    // shared across all `.searchable` modifiers attached to
    // different column views). Per Apple SwiftUI docs, multiple
    // `.searchable` modifiers on the same binding (= Binding<String>
    // bound to this @Observable property) will all reflect the
    // same live value, but only the active-focused column's
    // search field is rendered visible (= the others auto-focus
    // when the user activates their column).
    //
    // Use case: user types in the cards column's toolbar search
    // field → searchText updates → the sidebar / inspector
    // `.searchable` modifiers all see the same value → future
    // filters can read searchText from AppState instead of
    // threading bindings. This is the canonical SwiftUI Observation
    // pattern for app-wide search state (= developer.apple.com/
    // documentation/swiftui/view/searchable).
    var searchText: String = ""

    // v0.34 B-18 (= boss 9/2 OOB ', editor, yesno
    // '): editor zone's live word count, owned globally so
    // both the chrome bottom-bar left field (= ": N" in
    // TabContentDispatcher.editor case) and any future editor-zone
    // status widgets share one source of truth. EditorPlaceholder
    // writes via .onChange(of: draft); chrome reads via @Environment.
    var editorWordCount: Int = 0

    // v0.34 B-24 (= boss 9/2 OOB 'multi-tab editor, Safari style'):
    // open document tabs in the editor zone. Each tab = one open
    // document (= independent draft, mode, auto-save task, file
    // watcher). activeTabId identifies the currently focused tab.
    // Single source of truth across views (= TabContentDispatcher,
    // EditorPlaceholder, any future cross-zone tab bar).
    // v0.40 boss 9/7 OOB 'delete, ': persist
    // openTabs + activeTabId across launches (= JSON in UserDefaults).
    // Empty array on launch = no persisted tabs = editor zone shows
    // an onboarding hint instead of the samplePreviewBody.
    var openTabs: [EditorTab] = [] {
        didSet {
            persistOpenTabs()
        }
    }
    var activeTabId: UUID = UUID() {
        didSet {
            guard oldValue != activeTabId else { return }
            UserDefaults.standard.set(activeTabId.uuidString, forKey: AppState.activeTabIdKey)
        }
    }

    /// UserDefaults keys for openTabs persistence (= boss 9/7 OOB).
    /// Mirrors the existing llmModel / sidebarSelection pattern in
    /// this same file (= small JSON-blob pattern; no SQLite needed
    /// since openTabs is bounded to the editor-zone session state).
    static let openTabsKey = "wenshu.editor.openTabs.v1"
    static let activeTabIdKey = "wenshu.editor.activeTabId.v1"

    /// Persist openTabs to UserDefaults as JSON (= v0.40 boss 9/7).
    /// Persisted shape = PersistedEditorTab (= id + documentPath +
    /// draft + originalBody + mode). Tasks / file-watchers / dirty
    /// state are runtime-only (= recreated on launch when tabs are
    /// reloaded from disk).
    private func persistOpenTabs() {
        let snapshot = openTabs.map {
            PersistedEditorTab(
                id: $0.id,
                documentPath: $0.documentPath,
                draft: $0.draft,
                originalBody: $0.originalBody,
                mode: $0.mode.rawValue,
                title: $0.title
            )
        }
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: AppState.openTabsKey)
        }
    }

    /// Restore openTabs from UserDefaults (= v0.40 boss 9/7). Called
    /// from init() so subsequent view code reads the restored state
    /// on the first render.
    private func restoreOpenTabs() {
        guard let data = UserDefaults.standard.data(forKey: AppState.openTabsKey),
              let snapshot = try? JSONDecoder().decode([PersistedEditorTab].self, from: data) else {
            return
        }
        self.openTabs = snapshot.compactMap { p in
            guard let mode = EditorMode(rawValue: p.mode) else { return nil }
            return EditorTab(
                id: p.id,
                documentPath: p.documentPath,
                draft: p.draft,
                originalBody: p.originalBody,
                mode: mode,
                title: p.title
            )
        }
        if let activeIdStr = UserDefaults.standard.string(forKey: AppState.activeTabIdKey),
           let activeId = UUID(uuidString: activeIdStr),
           openTabs.contains(where: { $0.id == activeId }) {
            self.activeTabId = activeId
        } else if let first = openTabs.first {
            self.activeTabId = first.id
        }
    }

    /// v0.40 boss 2026-09-08 OOB 'chattop bar 3 tab (= dialog / search /
    /// Settings), editortop bar (= openTabs default)'. Fix = inject a
    /// single default Welcome tab when openTabs is empty (= gives the
    /// editor top tab bar at least one tab to render so the bar is
    /// visually present at launch; = matches chat's fixed-tab-set
    /// pattern where the tab bar is always visible).
    ///
    /// Why a static welcome tab (= not a "no document" placeholder):
    /// - EditorPlaceholder's tab strip iterates `appState.openTabs`;
    ///   = an empty list = zero tabs = no tab strip = the editor
    ///   top tab bar is invisible.
    /// - The welcome tab has `documentPath = nil` (= renders the
    ///   sample preview body; = the user sees a visible
    ///   "Welcome" tab + content; = clicking opens it as the active
    ///   tab; = deleting it (= the close button on the tab strip)
    ///   returns to the empty state, which is fine).
    ///
    /// Persistence interaction: if the user has persisted real tabs
    /// from a previous session, those take precedence and this
    /// welcome tab is NOT injected (= preserves the user's real
    /// open documents). The welcome tab only appears when the
    /// persisted tab list is empty (= first launch or after
    /// "close all tabs").
    var welcomeTab: EditorTab {
        EditorTab(
            id: UUID(),
            documentPath: nil,
            draft: "",
            originalBody: "",
            mode: .preview
        )
    }

    /// Called by WorkspaceView.body at first render if openTabs
    /// is empty (= injects one welcome tab so the editor top tab
    /// bar is visible at launch).
    func ensureWelcomeTabIfEmpty() {
        guard openTabs.isEmpty else { return }
        openTabs = [welcomeTab]
        activeTabId = openTabs[0].id
    }

    // v0.40 apple-001 Q3 surgical: hoist `LayoutEditMode` (= the
    // ⌘⇧\ layout-edit hotkey state) from WorkspaceView-local
    // `@State private var editMode = LayoutEditMode()` into AppState
    // so all workspace descendants share one instance (= single
    // source of truth for the layout edit on/off boolean). The class
    // is already @Observable + @MainActor (= Apple-native Observation
    // framework) so injecting via the existing `.environment(appState)`
    // chain (= added in v0.30) is the canonical path. WorkspaceView
    // now reads `appState.editMode` via @Environment instead of owning
    // its own instance; = the `WindowGroup` content tree has exactly
    // one `editMode` instance (per-window) and any sibling view that
    // needs to gate drag gestures reads the same one. `var` (not
    // `let`) so descendants can take a `Binding<Bool>` via
    // `@Bindable` (= the EditModeBadge / EditModeHotkey consumers
    // need a writable binding to toggle the on/off boolean).
    var editMode = LayoutEditMode()

    // B-05: wenshu.llm.model centralization. Single owner of the
    // active LLM model id (= was previously scattered as 4 separate
    // @AppStorage("wenshu.llm.model") declarations across App.swift
    // + LibraryRootView.swift, plus 3 raw UserDefaults reads/writes
    // in ChatView.swift = 7 different observation surfaces for 1
    // UserDefaults key). Now AppState.llmModel is the only owner;
    // init seeds from the existing UserDefaults value (= preserves
    // existing user choice across launches; Swift `didSet` does NOT
    // fire during init so no redundant write happens on launch) and
    // didSet writes back on every subsequent change (= mirror of the
    // LayoutTreeStore UserDefaults pattern in this same State/ folder).
    // All callers now read/write `appState.llmModel` (= one path, no
    // synchronization drift across zones).
    var llmModel: String = "" {
        didSet {
            guard oldValue != llmModel else { return }
            UserDefaults.standard.set(llmModel, forKey: "wenshu.llm.model")
        }
    }

    init() {
        // M1-shell (2026-09-08): seed `useThreeColumnSplit` from
        // UserDefaults at app launch. Without this read, the flag
        // stays at its hard-coded default (= `false`) and the
        // user's `defaults write` call has no effect (= the
        // NavigationSplitShell path never activates).
        //
        // Set via:
        //   defaults write com.wenshu.app wenshu.useThreeColumnSplit -bool true
        // Reset via:
        //   defaults delete com.wenshu.app wenshu.useThreeColumnSplit
        //
        // Mirrors the pattern already used for `llmModel` (= the
        // property's default `false` is correct for a fresh launch
        // and for users who never set the flag; = the UserDefaults
        // read only fires if the key actually exists).
        if UserDefaults.standard.object(forKey: "wenshu.useThreeColumnSplit") != nil {
            self.useThreeColumnSplit = UserDefaults.standard.bool(
                forKey: "wenshu.useThreeColumnSplit"
            )
        }
        // B-05: seed from the existing UserDefaults value. didSet is
        // not called during init (= Swift property wrapper semantics),
        // so this assignment does NOT trigger a write back to
        // UserDefaults on launch (= pure read-side migration).
        self.llmModel = UserDefaults.standard.string(forKey: "wenshu.llm.model") ?? ""
        // v0.40 boss 9/7 OOB: restore persisted open tabs BEFORE
        // any view reads appState.openTabs (= EditorPlaceholder's
        // .onAppear reads it). Sets openTabs via the regular
        // assignment (= triggers didSet → persistOpenTabs = write
        // back the same data; = harmless redundant write).
        restoreOpenTabs()
        // v1.0.0-m1-shell boss 2026-09-10 OOB 'look at this persistence,
        // I picked the directory I selected as Help > World, what the card
        // displays is wenshu. Now restart. Let me see. It should disappear':
        // restore the sidebar
        // selection from UserDefaults (= JSON-encoded via Codable;
        // = same pattern as openTabs). Without this read, the
        // sidebar selection resets to nil on every launch (= the
        // boss's prediction that 'it will disappear' was correct
        // before this fix).
        //
        // Assignment via `self.sidebarSelection = ...` does NOT
        // trigger the didSet write-back (= Swift property wrapper
        // semantics; = didSet is suppressed during init). So this
        // read is purely load-side (= no UserDefaults write during
        // launch = no extra disk churn).
        if let data = UserDefaults.standard.data(forKey: AppState.sidebarSelectionKey),
           let decoded = try? JSONDecoder().decode(SidebarItem.self, from: data) {
            self.sidebarSelection = decoded
        }
    }
}

/// v0.40 boss 9/7 OOB: JSON-friendly shape for persisting open
/// editor tabs to UserDefaults (= small, bounded session state;
/// not worth a SQLite table). EditorTab itself is not Codable
/// because it holds runtime-only state (= Tasks, DispatchSource
/// file-watcher, dirty flag) that doesn't survive a process exit.
/// PersistedEditorTab = the slice of EditorTab that does.
struct PersistedEditorTab: Codable {
    let id: UUID
    let documentPath: String?
    let draft: String
    let originalBody: String
    let mode: String  // EditorMode.rawValue (= "preview" / "edit")
    // v1.0.0-m1-shell boss 2026-09-12 OOB 'tab is not showing the filename bug':
    // persist the card title (= 'Red Cliffs' / 'Du Fu' etc.) so the
    // tab strip shows the real name after relaunch (= instead of
    // 'preview-sample').
    let title: String?
}

// v0.34 B-24: per-tab editor state. Holds all data that was previously
// View-local @State on EditorPlaceholder (= draft, originalBody,
// mode, documentPath, autoSaveTask, fileWatcher). Each tab = one open
// document with independent state; = when the user opens a 2nd
// document via double-click (= boss 9/2 OOB scenario), it creates a
// new tab without disturbing the current tab's in-progress edits.
//
// Lives in AppState (= @Observable); = cross-view reactivity without
// @Binding plumbing. SwiftUI redraws the editor zone whenever any
// field on the active tab changes (= @Observable per-property tracking).
@MainActor
@Observable
final class EditorTab: Identifiable {
    let id: UUID
    var documentPath: String?
    var draft: String
    var originalBody: String
    var mode: EditorMode
    // v1.0.0-m1-shell boss 2026-09-12 OOB 'tab is not showing the filename bug':
    // when openCardInEditor opens a reference-library card (= no
    // documentPath = no absolute path = the ticket 027-35 deferred
    // path-resolution path), the tab strip used to render
    // 'preview-sample' as a placeholder (= ugly = the user sees a
    // non-meaningful name in the tab strip). Populate `title` at
    // openCardInEditor time (= the entity / book-doc title =
    // 'Red Cliffs' / 'Du Fu' / 'What is Wenshu' etc.) so tabDisplayTitle
    // can show it instead of 'preview-sample'. When the real
    // documentPath lands (ticket 027-35), the basename wins (= same
    // precedence as the existing fallback chain).
    var title: String?

    // v0.40 boss 9/7 OOB 'card zoneshouldshowin progress
    // card': capture the scope where this doc was opened
    // from (= drives sidebar selection + preview cards on
    // restore). = .referenceScope(cat) for library refs,
    // = .bookScope(bookId, folder) for book docs, etc. Optional
    // (= the placeholder tab + document-load path don't supply
    // it; = those default to nil = no restore behavior).
    var sourceScope: PreviewScope?

    // v0.34 B-22 (per-tab): auto-save debounce Task. Replaces
    // EditorPlaceholder's View-local autoSaveTask (= that pattern
    // worked for one tab but doesn't survive a tab switch; = the
    // 3-second timer must follow the active tab).
    var autoSaveTask: Task<Void, Never>?

    // v0.34 B-23 (per-tab): file-system watcher (= DispatchSource).
    // Survives only while the tab is mounted (= cancelled on tab
    // close or documentPath change).
    var fileWatcher: DispatchSourceFileSystemObject?
    var watchedFD: Int32 = -1

    // v0.34 B-23: local notification posted when an external file
    // change overwrites dirty user edits (= saves them to .local-wenshu-conflict-...md).
    var externalChangeNotice: String?

    // v0.34 ticket 09: dirty-discard alert (= only relevant in edit mode).
    var showDirtyDiscardConfirm: Bool = false

    init(
        id: UUID,
        documentPath: String?,
        draft: String,
        originalBody: String,
        // v0.39 ticket 001-A-extended: default to .edit (= was .preview
        // in v0.34; = the reason the placeholder tab and any caller that
        // uses the default init landed users in raw-text preview mode
        // rather than the live-styling editor). openCardInEditor passes
        // .edit explicitly too, but this default is the one the placeholder
        // tab + 027-35 document-load ticket use, so it must match.
        mode: EditorMode = .edit,
        // v1.0.0-m1-shell boss 2026-09-12 OOB 'tab is not showing the filename bug':
        // when documentPath is nil (= reference-library entity; =
        // path resolution deferred to ticket 027-35), the tab strip
        // displays `title` (= 'Red Cliffs' / 'Du Fu' etc.) instead of
        // the 'preview-sample' placeholder. Default nil = no override
        // (= the existing fallback chain shows 'preview-sample').
        title: String? = nil
    ) {
        self.id = id
        self.documentPath = documentPath
        self.draft = draft
        self.originalBody = originalBody
        self.mode = mode
        self.sourceScope = nil
        self.title = title
    }

    // v1.0.0-m1-shell boss 2026-09-12 OOB 'tab is not showing the filename bug':
    // the canonical display title for a tab (= the value shown in
    // the tab strip). Single source of truth = `EditorTab.displayTitle`
    // (= v0.71 P1 batch 4 dual-axis fix removed the duplicate
    // wrappers in WorkspaceView + PreviewPane; this comment was
    // updated to reflect the now-eliminated drift risk).
    //
    // Precedence:
    //   1. documentPath basename (= the real file wins; = strips
    //      the .md extension). If the path is set and the
    //      basename is non-empty, use it.
    //   2. tab.title (= the entity / book-doc title = 'Red Cliffs'
    //      / 'Du Fu' / 'What is Wenshu' etc.). For reference-library
    //      cards without a real documentPath (= ticket 027-35
    //      deferred path resolution), this is the only source of
    //      a meaningful name.
    //   3. 'preview-sample' (= the legacy placeholder; = only
    //      reached when neither documentPath nor title is set;
    //      = the ticket 027-35 path-resolution will narrow this
    //      fallback to the empty / placeholder tabs).
    static func displayTitle(_ tab: EditorTab) -> String {
        if let path = tab.documentPath, !path.isEmpty {
            let url = URL(fileURLWithPath: path)
            let basename = url.deletingPathExtension().lastPathComponent
            if !basename.isEmpty { return basename }
        }
        if let title = tab.title, !title.isEmpty { return title }
        return "preview-sample"
    }
}

// v0.34 B-24: top-level enum (= EditorTab is a top-level class; = can't
// reference nested Mode). Mirrors the previous nested enum (= .preview
// / .edit) but lifted to module scope. Was: EditorPlaceholder.Mode.
// Carries iconName + tooltip (= the format-bar / keyboard-shortcut
// helpers previously read these from the nested Mode; = kept here
// so EditorTab / EditorPlaceholder can both reference them).
enum EditorMode: String, CaseIterable, Identifiable {
    case preview
    case edit
    var id: String { rawValue }
    var iconName: String {
        switch self {
        case .preview: return "eye"
        case .edit:    return "pencil"
        }
    }
    var tooltip: String {
        switch self {
        case .preview: return "Preview Mode"
        case .edit:    return "Edit Mode"
        }
    }
}