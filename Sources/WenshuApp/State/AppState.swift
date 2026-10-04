// Sources/WenshuApp/State/AppState.swift
//
// (see OOB.md #2026-08-31) — adopted: global @Observable +
// @Environment injection (option A for cross-zone communication).
// This file centralizes cross-zone UI state (formerly scattered
// as @Binding across 4 view layers = WorkspaceView -> PaneRenderer
// -> TabContentDispatcher -> PaneView -> AppleSidebarView,
// per commit d845fe9c9).
//
// Why a global @Observable (= per Apple Observation framework,
// Swift 5.9+):
// 1. Instant reactivity (= any descendant view that reads
//    `workspaceUI.sidebarSelection` auto-re-renders on change).
// 2. Single source of truth (= one place for cross-zone signals).
// 3. Zero plumbing (= no @Binding chain to thread through new
//    views).
// 4. Boss can debug = `print(workspaceUI.sidebarSelection)` directly
//    (= vs grep NotificationCenter post names across N files).
// 5. Apple-native (= no 3rd-party dep, AGENTS.md §11.1 stays
//    unchanged).
//
// Per-window ownership: each WindowGroup instance creates its own
// AppState via `@State private var appState = AppState()` (= per-window
// multi-window future-proofing; = (see OOB.md #2026-08-27)).
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

    /// opt-in to the Apple-native
    /// NavigationSplitView path (= 3-column layout per macOS 27
    /// `NavigationSplitView` = the canonical Apple HIG pattern
    /// per developer.apple.com/documentation/swiftui/navigationsplitview).
    ///
    // useThreeColumnSplit was here (= a leftover "global @Observable
    // mirror" before LayoutTreeState owned the activation gate).
    // Per P2-06 audit (2026-09-24): removed because:
    // - 0 production callers in the runtime (= the canonical
    //   NavigationSplitView reads LayoutTreeState.useThreeColumnSplit,
    //   not AppState's).
    // - Persistence is unchanged (= UserDefaults key
    //   "wenshu.useThreeColumnSplit" is still owned by LayoutTreeState).
    // - AppState no longer needs this field; = the canonical home is
    //   LayoutTreeState.swift:834.
    //
    // The flag's behaviour (= which user setting activates the
    // Apple 3-column shell) is owned by LayoutTreeState; = this
    // AppState mirror was dead since the v1.29 M1 shell arc
    // (= LayoutTreeState absorbed the role). The mirror lingered
    // only as a user-toggle surface (= defaulted to false).

    // Sidebar tree selection moved to WorkspaceUIState.swift (= P2-06
    // split). Drives Preview pane scope. Persisted to the same
    // UserDefaults key "wenshu.sidebarSelection" (= JSON via Codable).
    // The key string is unchanged so no user-data migration is
    // needed. Callers now read `workspaceUI.sidebarSelection` (= via
    // `@Environment(WorkspaceUIState.self)` injected at AppRootScene).

    // previewSortOrder + editMode moved to WorkspaceUIState.swift
    // (= P2-06 split batch 3 = column-local UI state; = bundled
    // because both share the same lifecycle + reset semantics).
    // Lives on AppState no longer (= the column-local UI scope is
    // a separate concern from cross-zone state + openTabs +
    // llmModel = the only remaining AppState contents).

    // 3 sheet-request triggers (= newBook / newShelf / choice) moved
    // to SheetRequestState.swift (= the P2-06 split batch 4 host).
    // The counters are fire-and-forget triggers (= toolbar Menu
    // bumps the counter = sidebar body observes .onChange and
    // flips its local @State showXSheet). Same pattern in 3
    // places, all bundled on SheetRequestState.

    // The search text lives in AppState (= a single source of truth
    // shared across all `.searchable` modifiers attached to
    // different column views). Per Apple SwiftUI docs, multiple
    // `.searchable` modifiers on the same binding (= `Binding<String>`
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

    // editorWordCount moved to EditorCounters.swift (= P2-06 split
    // batch 5 = editor zone counter). EditorView writes via
    // .onChange(of: draft) callback (= the host routes the value);
    // = chrome bottom-bar left field would read via @Environment
    // (= current callers: 0 readers in this commit; = future
    // chrome widget reads from `editorCounters.wordCount`).

    // (= (see OOB.md #2026-09-02) — multi-tab editor, Safari style):
    // open document tabs in the editor zone. Each tab = one open
    // document (= independent draft, mode, auto-save task, file
    // watcher). activeTabId identifies the currently focused tab.
    // Single source of truth across views (= TabContentDispatcher,
    // EditorView, any future cross-zone tab bar).
    // (see OOB.md #2026-09-07) — persist openTabs + activeTabId
    // across launches (= JSON in UserDefaults). Empty array on launch
    // = no persisted tabs = editor zone shows an onboarding hint
    // instead of the samplePreviewBody.
    var openTabs: [EditorTab] = [] {
        didSet {
            persistOpenTabs()
        }
    }
    // chapter-focus-lock: single-focus source of truth
    // for chapter editing. nil = no tab is open OR the active tab
    // has no document (= LLM can edit). non-nil = the user has this
    // chapter's tab open AND that tab is the currently-active one
    // (= LLM tool calls into this path throw `chapterFocusedByBoss`).
    // chatVisible gate (= LLM can edit when the user is in chat)
    // lives at the call site (= EditorView computes the final
    // isChapterLockedByLLM using its @Environment(WorkspaceUIState.self)
    // because AppState cannot hold @Environment-bound state).
    var focusedChapterPath: String? {
        get {
            guard let tab = openTabs.first(where: { $0.id == activeTabId }) else { return nil }
            return tab.documentPath
        }
        // chapter-focus-lock 2026-09-28: setter exists so the
        // conductor's retry wrapper can clear the focus lock when
        // the chapter-edit gate fires (= auto-Allow path).
        // The setter is also used by the future Allow/Deny UI to
        // restore the prior value after a dialog decision. Production
        // code outside the focus-lock retry path does not write
        // focusedChapterPath (= the editor view's focus state drives
        // the getter via activeTabId updates).
        set {
            // activeTabId tracks the focused tab (= the active one).
            // Setting focusedChapterPath = nil means "no tab owns the
            // cursor"; = setting it to a non-nil path would require
            // switching activeTabId to the matching tab. The MVP path
            // only clears (= the retry wrapper sets nil), so this
            // setter accepts only nil assignment. Future ticket
            // (= Allow/Deny dialog) can extend it to accept path
            // strings and switch activeTabId.
            guard newValue == nil else {
                return
            }
            // The active user releases focus by either closing the active
            // tab or switching to chat. We pick the chat-switch path
            // because it preserves the tab (= the user can return).
            // Setting chatVisible is owned by WorkspaceUIState (=
            // environment-injected) so we route via AppStateLocator
            // when set;
            // otherwise we drop the active tab (= the chapter tab
            // simply goes inactive and the editor reload shows the
            // agent's edits).
            if let appState = AppStateLocator.shared.appState {
                _ = appState
                // Note: actual chat-visible toggle happens in the
                // caller (= WorkspaceUIState), not here. We simply clear
                // activeTabId so the active-tab lookup below returns
                // nil (= focusedChapterPath becomes nil on next read).
            }
            // The activeTabId rewrite is the durable clear: re-using
            // the same UUID does nothing (= oldValue == newValue), so
            // we swap to a fresh UUID to force a no-match. This is
            // idempotent because activeTabId is just an index into
            // openTabs (= the editor zone reads activeTab to find the
            // visible tab; = nil = placeholder preview).
            activeTabId = UUID()
        }
    }
    var activeTabId: UUID = UUID() {
        didSet {
            // 
            // the audit's concern about "activeTabId.didSet not going through
            // the same `.constant(nil)` reset guard" doesn't apply here (=
            // `activeTabId` is `UUID` non-optional; = there's no nil
            // reset path). The early-exit guard for duplicate writes is
            // correct (= prevents redundant UserDefaults writes when
            // openTabs persistence calls `self.activeTabId = activeId`
            // during init, even though didSet is suppressed during init
            // per Swift property wrapper semantics, = safety belt).
            guard oldValue != activeTabId else { return }
            UserDefaultsStore.shared.setUUID(activeTabId, forKey: .activeTabId)
        }
    }

    /// UserDefaults keys for openTabs persistence (= (see OOB.md #2026-09-07)).
    /// Mirrors the existing llmModel / sidebarSelection pattern in
    /// this same file (= small JSON-blob pattern; no SQLite needed
    /// since openTabs is bounded to the editor-zone session state).
    static let openTabsKey = "wenshu.editor.openTabs.v1"
    static let activeTabIdKey = "wenshu.editor.activeTabId.v1"

    /// Persist openTabs to UserDefaults as JSON.

    // MARK: - P2-06 extracted concerns (= openTabs persistence lives in AppState+Tabs.swift)

    /// 
    /// Settings), editortop bar (= openTabs default)'. Fix = inject a
    /// single default Welcome tab when openTabs is empty (= gives the
    /// editor top tab bar at least one tab to render so the bar is
    /// visually present at launch; = matches chat's fixed-tab-set
    /// pattern where the tab bar is always visible).
    ///
    /// Why a static welcome tab (= not a "no document" placeholder):
    /// - EditorView's tab strip iterates `appState.openTabs`;
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

    // Tab close button: the business entry point for the new X
    // button on the editor tab strip (= closes one tab by id; =
    // flushes dirty drafts synchronously so closing doesn't lose
    // pending edits).
    //
    // Auto-save guarantee (= the canonical invariant):
    // - dirty tab + pending auto-save Task (= 3-second debounce
    //   mid-flight): cancel the Task (= prevents it from resuming
    //   on a deleted tab = potential crash + stale write) + flush
    //   the draft synchronously via EditorPersistence.save (= no
    //   lost edits).
    // - dirty tab + no pending Task: sync save (= same path).
    // - clean tab: no save needed; just remove + stop watcher.
    //
    // After remove: if openTabs ends up empty, re-inject the
    // welcome tab (= matches the ensureWelcomeTabIfEmpty invariant;
    // = tab strip stays visible at all times). If the closed tab
    // was active, pick a neighbor: next tab preferred; = fall back
    // to previous; = fall back to the welcome tab if empty.
    //
    // BookStore is passed in (= the same pattern as
    // EditorPersistence.save); = AppState itself doesn't hold a
    // BookStore (the view layer does via @Environment).
    func closeTab(id: UUID, bookStore: BookStore?) {
        guard let idx = openTabs.firstIndex(where: { $0.id == id }) else {
            // Unknown id (= stale UI; = safe to ignore).
            return
        }
        let tab = openTabs[idx]

        // 1. Cancel any pending auto-save Task on this tab (= prevents
        // Task.resume on a deleted tab; = prevents the Task from
        // writing to a stale slot).
        tab.autoSaveTask?.cancel()
        tab.autoSaveTask = nil

        // 2. Stop the file watcher (= v1.70 T1a EditorFileWatcher;
        // = prevents zombie DispatchSource holding the fd).
        EditorFileWatcher.stop(tab: tab)

        // 3. Flush the dirty draft synchronously if needed (= the
        // canonical auto-save invariant). clean tabs compare
        // equal so the EditorPersistence.save is skipped (= idempotent).
        if tab.draft != tab.originalBody {
            EditorPersistence.save(tab: tab, bookStore: bookStore)
            // After sync save, mark the tab clean (= no further writes
            // will happen; = the doc is consistent on disk).
            tab.originalBody = tab.draft
        }

        // 4. Remove the tab (= didSet triggers persistOpenTabs; =
        // UserDefaults write is automatic).
        openTabs.remove(at: idx)

        // 5. If the closed tab was active, pick a neighbor.
        if activeTabId == id {
            if openTabs.isEmpty {
                // All tabs closed = re-inject welcome (= tab strip
                // stays visible per the welcomeTab invariant).
                let welcome = welcomeTab
                openTabs.append(welcome)
                activeTabId = welcome.id
            } else if idx < openTabs.count {
                // Closed a non-last tab = next tab in the list wins.
                activeTabId = openTabs[idx].id
            } else {
                // Closed the last tab in the list = previous (now
                // last) tab wins (= Safari / Chrome convention).
                activeTabId = openTabs[idx - 1].id
            }
        }
    }

    // editMode moved to WorkspaceUIState.swift (= P2-06 split
    // batch 3; = bundled with previewSortOrder because both
    // are column-local UI state with the same lifecycle).
    // Previously: a LayoutEditMode @Observable class instance
    // (= Apple Observation framework; = shared across workspace
    // descendants via @Bindable; = ⌘⇧\ hotkey in
    // EditModeHotkey.swift toggled `appState.editMode`).
    // Now: same lifecycle, just lives on WorkspaceUIState.

    // wenshu.llm.model centralization. Single owner of the
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
            UserDefaultsStore.shared.setString(llmModel, forKey: .llmModel)
        }
    }

    init() {
        // useThreeColumnSplit seed block removed (= P2-06 audit 2026-09-24):
        // AppState no longer owns this flag. LayoutTreeState owns the
        // canonical flag (= Codable + UserDefaults-backed). The seed
        // lives in LayoutTreeState's own init.
        // seed from the existing UserDefaults value. didSet is
        // not called during init (= Swift property wrapper semantics),
        // so this assignment does NOT trigger a write back to
        // UserDefaults on launch (= pure read-side migration).
        self.llmModel = UserDefaultsStore.shared.string(forKey: .llmModel)
        // (see OOB.md #2026-09-07) — restore persisted open tabs BEFORE
        // any view reads appState.openTabs (= EditorView's
        // .onAppear reads it). Sets openTabs via the regular
        // assignment (= triggers didSet → persistOpenTabs = write
        // back the same data; = harmless redundant write).
        restoreOpenTabs()
        // Sidebar selection restore moved to WorkspaceUIState.init()
        // (= P2-06 split; = reads the same UserDefaults key
        // "wenshu.sidebarSelection"; = no behavior change for
        // users).
    }
}

/// JSON-friendly shape for persisting open
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
    // Persist the card title (= 'Red Cliffs' / 'Du Fu' etc.) so the
    // tab strip shows the real name after relaunch (= instead of
    // 'preview-sample').
    let title: String?
}

// per-tab editor state. Holds all data that was previously
// View-local @State on EditorView (= draft, originalBody,
// mode, documentPath, autoSaveTask, fileWatcher). Each tab = one open
// document with independent state; = when the user opens a 2nd
// document via double-click (= (see OOB.md #2026-09-02) scenario),
// it creates a new tab without disturbing the current tab's
// in-progress edits.
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
    // when openCardInEditor opens a reference-library card (= no
    // documentPath = no absolute path = the deferred path-resolution
    // path), the tab strip used to render 'preview-sample' as a
    // placeholder (= ugly = the user sees a non-meaningful name in
    // the tab strip). Populate `title` at openCardInEditor time (=
    // the entity / book-doc title = 'Red Cliffs' / 'Du Fu' /
    // 'What is Wenshu' etc.) so `tabDisplayTitle` can show it instead
    // of 'preview-sample'. When the real documentPath lands, the
    // basename wins (= same precedence as the existing fallback
    // chain).
    var title: String?

    // capture the scope where this doc was opened
    // from (= drives sidebar selection + preview cards on
    // restore). = .referenceScope(cat) for library refs,
    // = .bookScope(bookId, folder) for book docs, etc. Optional
    // (= the placeholder tab + document-load path don't supply
    // it; = those default to nil = no restore behavior).
    var sourceScope: PreviewScope?

    // (per-tab): auto-save debounce Task. Replaces
    // EditorView's View-local autoSaveTask (= that pattern
    // worked for one tab but doesn't survive a tab switch; = the
    // 3-second timer must follow the active tab).
    var autoSaveTask: Task<Void, Never>?

    // (per-tab): file-system watcher (= DispatchSource).
    // Survives only while the tab is mounted (= cancelled on tab
    // close or documentPath change).
    var fileWatcher: DispatchSourceFileSystemObject?
    var watchedFD: Int32 = -1

    // local notification posted when an external file
    // change overwrites dirty user edits (= saves them to .local-wenshu-conflict-...md).
    var externalChangeNotice: String?

    // dirty-discard alert (= only relevant in edit mode).
    var showDirtyDiscardConfirm: Bool = false

    init(
        id: UUID,
        documentPath: String?,
        draft: String,
        originalBody: String,
        // default to `.edit` (= was `.preview` in v0.34; = the reason the
        // placeholder tab and any caller that uses the default init
        // landed users in raw-text preview mode rather than the
        // live-styling editor). openCardInEditor passes `.edit`
        // explicitly too, but this default is the one the placeholder
        // tab + 027-35 document-load path use, so it must match.
        mode: EditorMode = .edit,
        // when `documentPath` is nil (= reference-library entity; =
        // the deferred path-resolution path), the tab strip
        // displays `title` (= 'Red Cliffs' / 'Du Fu' etc.) instead
        // of the 'preview-sample' placeholder. Default nil = no
        // override (= the existing fallback chain shows
        // 'preview-sample').
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

    // The canonical display title for a tab (= the value shown in
    // the tab strip). Single source of truth = `EditorTab.displayTitle`
    // (= the v0.71 P1 batch 4 dual-axis fix removed the duplicate
    // wrappers in WorkspaceView + PreviewPane; this comment was
    // updated to reflect the now-eliminated drift risk).
    //
    // Precedence:
    //   1. documentPath basename (= the real file wins; = strips
    //      the .md extension). If the path is set and the
    //      basename is non-empty, use it.
    //   2. tab.title (= the entity / book-doc title = 'Red Cliffs'
    //      / 'Du Fu' / 'What is Wenshu' etc.). For reference-library
    //      cards without a real documentPath (= the deferred
    //      path resolution), this is the only source of a
    //      meaningful name.
    //   3. 'preview-sample' (= the legacy placeholder; = only
    //      reached when neither documentPath nor title is set;
    //      = the deferred path-resolution will narrow this
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

// top-level enum (= EditorTab is a top-level class; = can't
// reference nested Mode). Mirrors the previous nested enum (= .preview
// / .edit) but lifted to module scope. Was: EditorView.Mode.
// Carries iconName + tooltip (= the format-bar / keyboard-shortcut
// helpers previously read these from the nested Mode; = kept here
// so EditorTab / EditorView can both reference them).
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
