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
    /// selected). Drives preview pane scope (= see
    /// WorkspaceView.previewScope).
    ///
    /// Persisted to `wenshu.sidebarSelection` UserDefaults key
    /// (= JSON shape, = set by WorkspaceView's `.onChange`).
    var sidebarSelection: SidebarItem? = nil

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
                mode: $0.mode.rawValue
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
                mode: mode
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
        mode: EditorMode = .edit
    ) {
        self.id = id
        self.documentPath = documentPath
        self.draft = draft
        self.originalBody = originalBody
        self.mode = mode
        self.sourceScope = nil
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
        case .preview: return "预览模式"
        case .edit:    return "编辑模式"
        }
    }
}