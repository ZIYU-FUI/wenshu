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

    /// Sidebar tree selection (= 5 cases: .book(UUID) / .folder / .shelf
    /// / .referenceCategory / .referenceLibraryRoot, nil = nothing
    /// selected). Drives preview pane scope (= see
    /// WorkspaceView.previewScope).
    ///
    /// Persisted to `wenshu.sidebarSelection` UserDefaults key
    /// (= JSON shape, = set by WorkspaceView's `.onChange`).
    var sidebarSelection: SidebarItem? = nil

    // v0.34 B-18 (= boss 9/2 OOB '现在用的, 这个编辑器, 是否自带
    // 字数统计'): editor zone's live word count, owned globally so
    // both the chrome bottom-bar left field (= "字数: N" in
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
    // The placeholder tab (= shows samplePreviewBody) is seeded with
    // empty draft; = EditorPlaceholder.onAppear fills it with
    // samplePreviewBody content (= avoids the circular dependency
    // between AppState and EditorPlaceholder.samplePreviewBody).
    var openTabs: [EditorTab] = []
    var activeTabId: UUID = UUID()

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
    // WorkspaceStore UserDefaults pattern in this same State/ folder).
    // All callers now read/write `appState.llmModel` (= one path, no
    // synchronization drift across zones).
    var llmModel: String = "" {
        didSet {
            guard oldValue != llmModel else { return }
            UserDefaults.standard.set(llmModel, forKey: "wenshu.llm.model")
        }
    }

    init() {
        // B-05: seed from the existing UserDefaults value. didSet is
        // not called during init (= Swift property wrapper semantics),
        // so this assignment does NOT trigger a write back to
        // UserDefaults on launch (= pure read-side migration).
        self.llmModel = UserDefaults.standard.string(forKey: "wenshu.llm.model") ?? ""
    }
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
        mode: EditorMode = .preview
    ) {
        self.id = id
        self.documentPath = documentPath
        self.draft = draft
        self.originalBody = originalBody
        self.mode = mode
    }

    /// Placeholder tab (= the default tab that shows samplePreviewBody).
    /// Single instance = single source of truth for the "no document
    /// open yet" state. Caller fills draft / originalBody with
    /// EditorPlaceholder.samplePreviewBody (= can't reference the
    /// EditorPlaceholder.samplePreviewBody static here because it
    /// would create a circular dependency between AppState and the
    /// EditorPlaceholder view file).
    static let placeholderId = UUID()
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