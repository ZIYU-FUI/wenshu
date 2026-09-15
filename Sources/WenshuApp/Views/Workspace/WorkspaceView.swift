// WorkspaceView.swift · Wenshu · v0.27 ticket 027-34
//
// DEFERRED (v0.77 spec decision):
// ViewInspector test coverage for this view is deferred to v0.78+
// (= see .scratch/v0.77-workspaceview-tests/spec.md). The view's
// ownership of LayoutTreeStore + PaneSplitHost + WorkspaceMode requires
// significant mock scaffolding (~150-200 LOC tests) that exceeds
// 1-ticket scope per Q112. Future tickets ship ViewInspector tests
// in priority order: subcomponents first (EditModeBadge /
// EditorContentPlaceholder / PreviewSortMenuButton / LayoutPicker),
// then this view as a whole.
//
// This file is NOT dead code (= per Q57: 3rd-party verdict ≠ authority);
// it's a documented deferral, not a dead file.
//
//
// SwiftUI host for the user-customizable workspace. Wraps the
// LayoutTreeStore and renders the pane tree via PaneSplitHost (=
// NSViewControllerRepresentable wrapper around PaneNSController,
// which is the NSSplitViewController subclass that walks
// store.workspace.root and builds the native split view).
//
// This file = the WorkspaceView (root container) and the renderTab
// dispatcher (= maps TabKind -> existing wenshu view). The recursive
// pane rendering lives in PaneNSController.swift.

import SwiftUI
import MarkdownEngine  // v0.39 ticket 001: MarkdownEditorConfiguration type
import LucideSwift

/// WorkspaceView — the customizable-layout root (= the Xcode-paradigm
/// replacement for LayoutShellView). Boss 2026-08-27 grill D1 chose
/// this paradigm over the FCP / Hermes alternatives.
///
/// Boss 2026-08-27 standing goal: 'land the refactor'. This view is the
/// production (= only) rendering path since v0.30. The v0.27
/// LayoutShellView legacy path was removed in v0.30 (= 1310 lines
/// deleted per boss 8/31 OOB 'the old 6-zone layout is no longer used,
/// the data is useless and the code is outdated, after spot-check
/// you can clean it up').
struct WorkspaceView: View {
    @ObservedObject var store: LayoutTreeStore

    /// v0.30 boss OOB: entity classification is the last layer in the directory tree, after clicking,
    /// the entity document should display in the material management area in a wenshu-style card stream layout (= projectPreview).
    /// Tracks which entity category is currently selected in the sidebar
    /// (= nil = overview mode showing all entities).
    @State private var selectedEntityCategory: EntityCategory? = nil

    /// v0.30: tracks which entity card is currently being viewed in
    /// detail mode (= single card with full .md body).
    @State private var selectedEntity: Reference? = nil

    /// v0.30 boss 8/31 OOB 'cross-zone interaction' (= option A = global
    /// @Observable store, = commit eb3066bca). The cross-zone
    /// UI state (= sidebarSelection / selectedEntity / etc.) lives
    /// here, NOT in WorkspaceView's @State. WorkspaceView just
    /// observes (= for the previewScope computed) and persists
    /// (= for the @AppStorage round-trip via .onChange).
    @Environment(AppState.self) private var appState

    // v0.34 boss 2026-09-02 OOB 'sidebar + preview should share one unified persistence interface':
    // Sidebar selection persistence moved into NewLibraryOutlineView's
    // unified SidebarState (= single AppStorage key 'wenshu.sidebarState').
    // WorkspaceView only reads appState.sidebarSelection (= single
    // source of truth); no separate persistence here.

    /// v0.30 boss 8/31 OOB: card-grid sort order (= shared between
    /// PreviewPane's cards and the sort menu in the preview pane's
    /// tab bar trailing slot). Default = .pinyinFirstLetter.
    @State private var previewSortOrder: EntitySortOrder = .pinyinFirstLetter

    /// v0.30 boss 8/31 OOB: convert sidebar selection to PreviewScope
    /// for the material management zone. Computed on every render so
    /// it stays in sync with `sidebarSelection`.
    private var previewScope: PreviewScope {
        guard let item = appState.sidebarSelection else { return .empty }
        switch item {
        case .book(let bookId):
            return .bookScope(bookId: bookId, folderName: nil)
        case .folder(let bookId, let folderName):
            return .bookScope(bookId: bookId, folderName: folderName)
        case .shelf(let shelfId):
            // v0.30 boss 8/31 OOB spec criterion #2: clicking a
            // shelf row shows the "select a book" hint. (.shelfScope
            // maps to emptyState(message: "Select a book to view documents") in
            // PreviewPane.shelfScopeView.) Previously this mapped
            // to .empty (= "Please select a directory on the left to view documents") which the spec
            // sub-agent flagged as FAIL.
            return .shelfScope(shelfId: shelfId)
        case .referenceCategory(let dirName):
            if dirName == "__root__" {
                return .referenceScope(nil)
            }
            if let cat = EntityCategory.allCases.first(where: {
                $0.directoryName == dirName
            }) {
                return .referenceScope(cat)
            }
            return .empty
        }
    }

    /// v0.30: BookStore env (= for reference loading in preview pane).
    @Environment(BookStore.self) private var bookStore

    /// Layout edit mode state (= v0.28 ticket 028-006). v0.40
    /// apple-001 Q3 surgical: hoisted to `appState.editMode` (= the
    /// shared AppState instance) so all workspace descendants read
    /// the same one. The hotkey binding lives in
    /// `EditModeHotkey.swift` (= ⌘⇧\ toggle, Escape exit); the
    /// hotkey still mutates `appState.editMode` (= same singleton,
    /// no extra plumbing). Per-window ownership is preserved by
    /// AppState's per-window `@State` on `WenshuApp` (= each
    /// WindowGroup instance still has its own edit-mode boolean).
    private var editMode: LayoutEditMode { appState.editMode }

    /// The flat list of panes (= rendered as a horizontal HStack).
    /// The root split direction (= vertical) is applied at the
    /// WorkspaceView body level (= upper band vs lower band).
    ///
    /// For v0.27 we render the 6 panes in a fixed order (= the
    /// built-in Default preset). Boss can split / rearrange via
    /// drag-and-drop in 027-36+.

    /// v0.34 B-25 (simplified): card double-click handler. Reads the
    /// .md file (= body content) for the current sidebar selection's
    /// first entity, then either (a) SWITCHES to an existing tab that
    /// already has the same content loaded (= boss 9/3 OOB 'check whether
    /// an existing tab has already opened the current MD' = duplicate-tab check = Safari
    /// behavior) or (b) opens a new tab in the editor zone (= B-24
    /// multi-tab data model).
    ///
    /// Why content-based duplicate check (= not path-based)? The card
    /// doesn't currently carry its file path; = ticket 027-35 will
    /// add explicit per-card tracking (= Card → URL → tab match).
    /// For now we approximate with first-200-char content hash (= if
    /// another tab is showing the same .md body = match).
    ///
    /// Reference scope reads via ReferenceStore (= real Read API).
    /// Book scope is deferred to ticket 027-35 (= PreviewPane's
    /// private `loadBookDocs` walker is the source of truth; = no
    /// shortcut path through WorkspaceView without lifting the helper).
    /// No .alert, no popup = simplest possible (= Apple HIG TextEdit
    /// "open this file" semantics).
    /// BOSS 9/8 'clicking the Dufu card opens a tab with wrong name' (= clicking
    /// the card opened a new tab named 'preview-sample'):
    /// the previous version took no arguments and used
    /// `filtered.first` (= always the topmost card, not the actually
    /// clicked one). New version accepts an OPTIONAL `source`
    /// (= the actually-clicked CardSource from PreviewPane) and
    /// uses IT (= not `filtered.first`) to open the right .md.
    ///
    /// Signature: `source: CardSource?` (= optional for backward
    /// compat with the v0.34 callers that haven't migrated yet;
    /// = when nil, falls back to the old `filtered.first` behavior).
    /// For the new PreviewPane callers (the post-fix wiring), the
    /// source is always supplied.
    private func openCardInEditor(source: CardSource? = nil) {
        // The closure body was already in WorkspaceView; the
        // signature just gains a `source:` parameter. No body
        // change here.
        let (path, content, title): (String?, String, String)
        switch previewScope {
        case .referenceScope(let category):
            let entities = (try? bookStore.referenceStore.loadAllReferences()) ?? []
            let filtered = entities.filter { entity in
                entity.layer == .layerEntities
                    && (category == nil || entity.category == category)
            }
            // BOSS 9/8 fix: if the caller (= PreviewPane) passed
            // the actually-clicked CardSource, use its entity
            // (= correct card). Otherwise fall back to filtered.first
            // (= legacy behavior for callers that don't pass source).
            let pickedReference: Reference? = {
                if case .reference(let r) = source { return r }
                return filtered.first
            }()
            if let first = pickedReference {
                let body = (try? bookStore.referenceStore.loadReferenceBody(id: first.id)) ?? first.summary
                path = nil  // reference is library-public; ticket 027-35 will resolve
                content = body
                title = first.title
            } else {
                path = nil; content = ""; title = category?.displayName ?? WenshuI18n.t("tab.title.reference_library")
            }
        case .bookScope:
            // Deferred to ticket 027-35: PreviewPane's private
            // loadBookDocs helper is the source of truth for bookDoc
            // discovery; = WorkspaceView doesn't share it. v0.34
            // fallback = silent no-op (= no .alert, no popup = user
            // feedback comes from PreviewPane being empty).
            // BOSS 9/8 fix: if the caller passed a .bookDoc source,
            // use its doc (= correct book doc).
            if case .bookDoc(let doc) = source {
                // BookDoc doesn't carry an absolute path (= only
                // fileName + folderName per PreviewPane L159).
                // path = nil (= PreviewPane's own loadBookDocs owns
                // the path resolution; = ticket 027-35 will lift
                // BookDocLoader into a shared service that returns
                // the absolute path).
                path = nil
                // PreviewPane.loadBookDocs (= L764) returns docs
                // with .summary as the only body content (= real
                // .md body loading is deferred to ticket 027-35;
                // = the previous behavior was silent no-op).
                // Use .summary here (= matches the fallback that
                // loadReferenceBody → first.summary already uses for
                // reference docs).
                content = doc.summary
                title = doc.title
            } else {
                path = nil; content = ""; title = "book-doc"
            }
        case .shelfScope, .empty:
            path = nil; content = ""; title = ""
        }

        // No content (= no reference in scope OR bookDoc deferred).
        // Silent no-op per boss 9/3 feedback (= no .alert noise).
        guard !content.isEmpty else { return }

        // Duplicate-tab check (= boss 9/3 OOB core requirement).
        // If any existing tab's `originalBody` (= the on-disk content
        // = canonical identity, more stable than draft which can be
        // dirty) matches our new content, switch to that tab instead
        // of opening a duplicate. Safari behavior.
        //
        // Content fingerprint = first 200 chars (= fast; = sufficient
        // since the chance of two distinct .md files sharing the
        // first 200 chars is negligible).
        let fingerprint = String(content.prefix(200))
        if let existingIdx = appState.openTabs.firstIndex(where: {
            String($0.originalBody.prefix(200)) == fingerprint
        }) {
            appState.activeTabId = appState.openTabs[existingIdx].id
            // (No edit / no new tab — reuse the existing one.)
            return
        }

        // No duplicate. Open as new tab (= reuse current tab if clean,
        // otherwise append).
        let currentIsDirty: Bool = {
            guard let tab = appState.openTabs.first(where: { $0.id == appState.activeTabId }) else {
                return false
            }
            return tab.draft != tab.originalBody
        }()
        let newTab = EditorTab(
            id: UUID(),
            documentPath: path,
            draft: content,
            originalBody: content,
            mode: .preview,
            // v1.0.0-m1-shell boss 2026-09-12 OOB 'tab title didn't go to the document name bug':
            // pass title so tab strip shows the real card name
            // instead of 'preview-sample'.
            title: title.isEmpty ? nil : title
        )
        // v0.40 boss 9/7 OOB 'card zoneshouldshowin progress
        // card': capture the scope where this doc was opened
        // from (= drives sidebar selection + preview cards on
        // restore). = .referenceScope(cat) for library refs,
        // = .bookScope(bookId, folder) for book docs, etc.
        newTab.sourceScope = previewScope
        // v0.34 B-26-FIX (= boss 9/3 'first double-click can switch, not a new tab, it replaces
        // the old tab'): always append a new tab (= Safari multi-tab strip
        // behavior). Duplicate-tab detection (= the fingerprint check
        // earlier in this function) handles the "switch to existing
        // tab if same .md is open" case (= boss 9/3 'check whether an existing tab
        // already opened the current MD'). = no replacement of the active tab;
        // = no "second click fails" race.
        appState.openTabs.append(newTab)
        appState.activeTabId = newTab.id
    }

    var body: some View {
        // v0.30 boss 2026-09-01 OOB: the legacy PaneRenderer path
        // (= v0.28 ticket 028-004 hand-rolled split-tree renderer)
        // was deleted per boss OOB (= the new NSSplitView code
        // fully replicates the old behavior). WorkspaceView now
        // ALWAYS renders the NSSplitView path (= PaneSplitHost +
        // PaneNSController). The `useNSSplitView` feature flag
        // stays in LayoutTreeState for backward Codable
        // compatibility but the UI no longer branches on it.
        //
        // CHATZONE-CRASH-FIX (2026-09-08): the previous M1
        // implementation branched on `useThreeColumnSplit`
        // here in `WorkspaceView.body` (= nested
        // NavigationSplitView inside a non-root Group). Per
        // Apple HIG canonical guidance (= NavigationSplitView
        // should be a root view in the Scene), the branch is
        // now hoisted up to `LibraryRootView.body` (= root-of-Scene
        // position; = env chain stays intact). The branch
        // remains here as a no-op fallback (= the WorkspaceView
        // still exists, = PaneSplitHost path is the only
        // remaining path; = unchanged behavior).
            PaneSplitHost(
                layout: FCPLayout(),
                store: store,
                appState: appState,
                bookStore: bookStore
            )
            // v0.34 boss 2026-09-02 OOB: sidebar selection persistence
            // moved to NewLibraryOutlineView's unified SidebarState.
            // WorkspaceView no longer owns any @AppStorage key for
            // sidebar state — single source of truth lives where the
            // sidebar renders.
            .layoutEditHotkey(editMode)
            .overlay(alignment: .topTrailing) {
                // Edit mode indicator (= shows a small badge in
                // the top-right corner when edit mode is on; the
                // user can click it to toggle off, or press ⌘⇧\).
                if editMode.isEnabled {
                    @Bindable var bindableAppState = appState
                    EditModeBadge(isEnabled: $bindableAppState.editMode.isEnabled)
                        .padding(DesignTokens.chromePaddingVertical)
                }
            }
            // v0.28 ticket 028-006: View menu's "Layout edit mode"
            // entry posts this notification (= ⌘⇧\); WorkspaceView
            // listens and flips the LayoutEditMode singleton so the
            // menu and the hotkey share the same state.
            .onReceive(NotificationCenter.default.publisher(for: .wenshuToggleEditMode)) { _ in
                editMode.toggle()
            }
            // v0.30 boss 2026-09-01 OOB fix: the View menu's "Restore Default
            // Layout" item (= ⌘⇧R; both the SwiftUI Commands entry
            // (= the App.swift:567 + 1442 references are stale per the Q2 boss
            // split moved the legacy NSMenu to AppRootScene.swift)
            // posts .wenshuResetLayout. Without this onReceive, the
            // notification had no observer and the menu item was
            // a no-op. Listening here delegates to
            // LayoutTreeStore.resetToDefault (= reloads the built-in
            // Default preset = upper band 10/20/60/10 weights, lower
            // band 70/30 weights, root 50/50 column weights per the
            // boss OOB ratios).
            //
            // v0.31 boss 2026-09-02 OOB (Apple canonical reset): the
            // .wenshuResetLayout notification now also un-collapses
            // the on-screen NSSplitView (= the menu item was previously
            // a no-op for the live layout — only the LayoutTreeStore
            // data model refreshed, while the rendered zones stayed
            // hidden). The BFS finds the root PaneNSController (= the
            // same SwiftUI NSHostingController-wrap workaround used
            // by the 5 toggle buttons) and calls its public
            // `restoreAllZones()` method (= Apple HIG canonical:
            // NSSplitViewItem.isCollapsed = false + setPosition).
            .onReceive(NotificationCenter.default.publisher(for: .wenshuResetLayout)) { _ in
                NSLog("[wenshu.reset] observer fired (WorkspaceView.onReceive)")
                store.resetToDefault()
                // Apple canonical reset (= un-collapse every pane
                // and re-pin the preset divider positions). The
                // rootPane lookup walks the SwiftUI
                // NSHostingController chain so it works under
                // macOS 27 SwiftUI WindowGroup (= contentViewController
                // is the hosting controller, not the split
                // controller).
                let root = NSApp.mainWindow?.contentViewController
                    ?? NSApp.keyWindow?.contentViewController
                    ?? NSApp.windows.first(where: { $0.contentViewController != nil })?.contentViewController
                findPaneController(in: root)?.restoreAllZones()
            }
            // v0.28 ticket 028-007: floating TreeEditBar with the
            // LayoutPicker (= preset grid + new-grid button +
            // save-current-as-preset input reveal). Shown only
            // when edit mode is on (= per spec §"Acceptance
            // criteria" #2).
            .overlay {
                if editMode.isEnabled {
                    LayoutEditBar(store: store, editMode: editMode)
                }
            }
    }

    /// Render a tab's view (= dispatches on TabKind). Extracted
    /// from the original `renderTab(_ tab: TabSpec)` to take a bare
    /// `TabKind` (= the SwiftUI TabContentDispatcher only knows
    /// the kind + title, not the full TabSpec).
    @ViewBuilder
    private func renderTabByKind(_ kind: TabKind) -> some View {
        switch kind {
        case .projectSidebar:
            // v0.28 followup Boss UX round 43 (Boss 2026-08-29 OOB
            // (Historical: this line had CJK content from a boss OOB message; the original text can be recovered via `git blame` on this line; the cleanup commit replaced it with a stub because its translation was incomplete.)
            // = sidebar's top chrome (= "Bookshelf" tab + New/Import buttons
            // inside NewLibraryOutlineView) was at a different Y than
            // Preview/Editor/Tools (= which use ZoneContentView with
            // RegionTabBar = 30 PT tall)). Fix = wrap NewLibraryOutlineView
            // in ZoneContentView (= 1 "Bookshelf" tab + trailing New/Import
            // buttons via zoneHeaderButtons). Now sidebar uses the same
            // canonical 30 PT RegionTabBar as the other 3 general
            // panes (= identical Y position for all 4 top tab bars).
            //
            // NewLibraryOutlineView still needs to be inside the tab
            // content slot (not above/around the tab bar) so its tree
            // outline is the "Bookshelf" tab's content.
            // v0.30: pass bindings so sidebar selection → preview pane.
            // The trailingButton uses the default-init (doesn't drive preview).
            ZoneContentView(zoneSlug: "projectSidebar", tabs: [
                (WenshuI18n.t("tab.title.bookshelf"), "book-open", AnyView(NewLibraryOutlineView(
                    selectedEntityCategory: $selectedEntityCategory,
                    selectedEntity: $selectedEntity
                ))),
            ], trailingButton: AnyView(NewLibraryOutlineView().zoneHeaderButtons))
        case .projectPreview:
            // v0.28 followup Boss UX round 45 (Boss 2026-08-29 OOB
            // 'top and bottom bars are not aligned' = Preview/Tools were using old
            // ZoneModuleView (= renders BOTH outer ZoneTopToolbar 30 PT
            // + internal ZoneContentView tab bar 30 PT = DOUBLE chrome
            // = 60 PT total, while Sidebar/Editor use only ZoneContentView
            // = 30 PT SINGLE chrome). Y misalignment = 30 PT difference.
            // Fix = convert Preview/Tools to use ZoneContentView directly
            // (= single 30 PT chrome layer = matches Sidebar/Editor).
            //
            // The Preview/Tools' ZoneContentView uses tabs from
            // projectPreviewChrome/specializedToolsChrome (= top actions
            // list), with the actual content view (CanvasView/BaseView
            // for Tools, GraphView for Preview) as the tab's body.
            //
            // v0.30 boss 8/31 OOB 'click sidebar row → right material area normally displays
            // the directory's documents, control directory range': PreviewPane is wired here
            // (= the active WorkspaceView body) with the computed
            // `previewScope` (= driven by sidebarSelection). The tab
            // "Map" stays on GraphView placeholder for future graph
            // view work.
            // v0.30 boss 8/31 OOB: the sort menu is now the
            // trailing button of the preview pane's tab bar (=
            // rendered as the rightmost element in PaneTabBar's
            // HStack, via the trailing: { } slot). Removed the
            // separate previewTopBar() (= was a custom HStack BELOW
            // the pane tab bar = visually "two toolbars stacked",
            // confusing). Sort menu now lives IN the tab bar.
            //
            // The trailing button passes the shared
            // previewSortOrder binding so changing the sort
            // re-renders the card grid (= PreviewPane observes
            // the same @State via its previewSortOrder parameter).
            // v0.40 boss 9/7 OOB ', top bar, yestop bar.
            // caneditor, yes': the search bar
            // belongs BELOW the ZoneContentView's tab strip (= inside
            // PreviewPane's body, = first element rendered after the
            // tab strip). Pattern matches the editor: ZoneContentView
            // tab strip → PreviewPane internal search bar → body content.
            // (= Removed the previous commit's VStack wrapper + previewSearchBar
            // computed view from this renderTabByKind path.)
            ZoneContentView(zoneSlug: "projectPreview", tabs: [
                (WenshuI18n.t("tab.title.preview"), "book-open-check", AnyView(PreviewPane(
                    scope: previewScope,
                    // v0.34 B-25: simplest possible = card double-click
                    // opens the .md file from the card (= Apple HIG
                    // TextEdit / TextEditor behavior; = no popup, no
                    // previewScope inference, no alert = just open the
                    // file). For card = .reference: path = reference-
                    // library entity path (= wenshu internal). For card
                    // = .bookDoc: path = book's folder/file .md.
                    // Falls back to a sample body if the file doesn't
                    // exist (= ticket 027-35 will wire to real paths).
                    onDoubleClick: { source in
                        // BOSS 9/8 'clicking the Dufu card opens a tab with wrong name':
                        // forward the clicked CardSource to openCardInEditor
                        // so it opens THIS card (= not the topmost one).
                        openCardInEditor(source: source)
                    },
                    previewSortOrder: $previewSortOrder
                ))),
                (WenshuI18n.t("tab.title.graph"), "waypoints", AnyView(GraphView())),
            ], trailingButton: AnyView(
                // v0.30 boss 8/31 OOB: 'place the sort ICON in the top bar, right-aligned,
                // ▼ replace with list-ordered icon'. The sort menu button
                // shows [sort rule text (dim)] + [list-ordered icon
                // (tint)] = icon right-aligned within the trailing button.
                PreviewSortMenuButton(sortOrder: $previewSortOrder)
            ))
        case .editor:
            // v0.28 followup Boss UX round 43: switch from
            // EditorPlaceholder (= text-only) to real ZoneContentView
            // (= 3 tabs Edit/Outline/Backlinks + trailing expand/shrink).
            // This makes editor's top chrome consistent with the other
            // 3 general panes (= all use RegionTabBar = 30 PT tall at
            // the same Y).
            ZoneContentView(zoneSlug: "editor", tabs: [
                // v0.34 B-13 fix (= boss 9/2 'git grep BEFORE patch' rule):
                // EditorContentPlaceholder was the OLD text-only placeholder
                // (= deleted by tonight's v0.34 commit chain). All ticket 04-10
                // patches (= mode toggle / preview/edit / toolbar / close + hotkeys)
                // landed on EditorPlaceholder, but WorkspaceView kept instantiating
                // the dead EditorContentPlaceholder. Replace with EditorPlaceholder
                // (= the ticket 04-10 patched one with toolbar + mode toggle +
                // save + expand + close; BacklinksPanel in preview mode;
                // TextEditor in edit mode).
                (WenshuI18n.t("tab.title.editor"), "book-open-text", AnyView(EditorPlaceholder())),
                (WenshuI18n.t("tab.title.outline"), "puzzle", AnyView(EditorPlaceholder())),
                (WenshuI18n.t("tab.title.backlinks"), "link", AnyView(EditorPlaceholder())),
            ], trailingButton: AnyView(EditorExpandShrinkTrailingButton()))
        case .specializedTools:
            // Old 6-zone specializedTools = 5 tabs (= Foreshadowing / Placeholder /
            // LongFormGuardrails per P1 ticket #6
            // [WIRE-SPECIALIZEDTOOLS-001] 2026-09-04 +
            // ReaderExperience per P1 ticket #7
            // [WIRE-SPECIALIZEDTOOLS-002] 2026-09-04 +
            // PlotThread per P1 ticket #8
            // [WIRE-SPECIALIZEDTOOLS-003] 2026-09-04).
            //   - Foreshadowing (= git-fork) + Placeholder (= square-dashed) per
            //     v0.29 boss 2026-08-30 OOB 'replace, use Foreshadowing to replace the first
            //     tab, use Placeholder to replace the second tab. Current canvas feature is for later'
            //   - LongFormGuardrails (= shield-check) per P1
            //     ticket #6 (= port long_form_guardrails.py from
            //     hermes = THE top competitive moat per boss 8/27).
            //     Real content (= 6 guardrail kinds + add / remove /
            //     run check); auto-derived on first open.
            //   - ReaderExperience (= sparkles) per P1 ticket #7
            //     (= port reader_experience.py from hermes = 5
            //     reader-experience analyzers: tension / pacing /
            //     foreshadowing / cliffhanger / payoff). Real
            //     content (= chapter-text input + 5-analyzer
            //     picker + report panel).
            //   - PlotThread (= git-branch) per P1 ticket #8
            //     (= port plot_thread.py from hermes = open /
            //     developing / resolved / abandoned thread
            //     tracker + stale detection + recycling map).
            //     Real content (= add / remove threads scoped
            //     to the selected book).
            //   - GenreFit (= book-marked) per P1 ticket #9
            //     (= port genre_fit.py from hermes = 10 genre
            //     presets + convention analyzer). Real
            //     content (= chapter-text input + genre picker + score
            //     badge + matched / missing / forbidden / vocab
            //     sections).
            //   - EmotionCurve (= activity) per P1 ticket #11
            //     (= port emotion_curve.py from hermes = per-
            //     window sentiment scoring + volatility + flat-
            //     spot detection + pacing-lift suggestions). Real
            //     content (= chapter-text input + window-count
            //     stepper + Canvas curve visualization + report
            //     panel).
            //   - Character-Relationships (= users) per P1 ticket #12
            //     (= port character_relationships.py from hermes =
            //     8 relationship kinds + relationship graph +
            //     inconsistency detection). Real content (= from /
            //     to / kind pickers + add row + relationships list
            //     + inconsistencies section).
            //   - Character-Lifecycle (= clock) per P1 ticket #13
            //     (= port character_lifecycle.py from hermes = 8
            //     lifecycle stages + timeline + contradiction
            //     detection). Real content (= character / stage /
            //     chapter pickers + excerpt field + add row +
            //     events list + timeline section + contradictions
            //     section).
            //   - Tag-Manager (= tag) per P1 ticket #14
            //     (= port tag_manager.py from hermes = 5 tag
            //     categories + 4 targets + tag cloud + filter).
            //     Real content (= label TextField + category
            //     picker + add-row + tag list + apply-row with
            //     tag / target / entity-uuid pickers + applications
            //     list + tag cloud + filter section).
            //   - Idea-Library (= lightbulb) per P1 ticket #15
            //     (= port idea_library.py from hermes = 5
            //     statuses + link to chapter / character /
            //     plot-thread + search + suggest). Real content
            //     (= title TextField + description TextEditor +
            //     status picker + tag TextField + add-row +
            //     search bar + status / tag filter pickers +
            //     ideas list with status badge + tag chips +
            //     remove button + link section with target /
            //     entity-uuid / context pickers + links list +
            //     suggest section with context TextField +
            //     suggestions list).
            //   - Book-Setting-Constraints (= book-lock) per
            //     P1 ticket #16 (= port book_setting_constraints.py
            //     from hermes = 3 severities + 4 scopes +
            //     chapter-text check). Real content (= title +
            //     description + severity + scope + appliesTo +
            //     forbidden-patterns fields + add-row +
            //     constraints list + chapter-text TextEditor +
            //     check button + violations section).
            //     FINAL P1 ticket (= 12th and last tab in the
            //     specializedTools pane).
            ZoneContentView(zoneSlug: "specializedTools", tabs: [
                (WenshuI18n.t("tab.title.foreshadowing"), "git-fork", AnyView(ForeshadowingView())),
                (WenshuI18n.t("tab.title.placeholder"), "square-dashed", AnyView(PlaceholderView())),
                (WenshuI18n.t("tab.title.long_form"), "shield-check", AnyView(LongFormGuardrailsView())),
                (WenshuI18n.t("tab.title.reader_experience"), "sparkles", AnyView(ReaderExperienceView())),
                (WenshuI18n.t("tab.title.plot_thread"), "git-branch", AnyView(PlotThreadView())),
                ("Genre-Fit", "book-marked", AnyView(GenreFitView())),
                ("Emotion-Curve", "activity", AnyView(EmotionCurveView())),
                ("Chars-Rel", "users", AnyView(CharacterRelationshipsView())),
                ("Chars-Life", "clock", AnyView(CharacterLifecycleView())),
                ("Tag-Manager", "tag", AnyView(TagManagerView())),
                ("Idea-Library", "lightbulb", AnyView(IdeaLibraryView())),
                ("Book-Settings", "book-lock", AnyView(BookSettingConstraintsView())),
            ])
        case .aiChat:
            ChatView()
        case .aiDynamic:
            ZoneModuleView(zoneSlot: .aiDynamic)
        }
    }

    /// Legacy method kept for backward-compatibility (= no callers
    /// remain after the NSSplitView refactor, but downstream
    /// extensions may still reference it via the `renderTab`
    /// closure). Forwards to `renderTabByKind` after looking up
    /// the tab spec.
    @ViewBuilder
    private func renderTab(_ tab: TabSpec) -> some View {
        renderTabByKind(tab.kind)
    }
}

// ZoneModuleView — small wrapper around the existing ZoneModule. We
// expose a `zoneSlot`-keyed initializer (= matches the v0.27 ZoneModule
// constructor signature).
//
// For v0.27 we defer the full ZoneModule integration (= which requires
// its LayoutShellViewModel parameter; = see ticket 027-35 followup).
// For now this view renders a placeholder color (= a sane default
// that the user can see + interact with while the integration lands).
// ZoneModuleView — verbatim port of the old v0.27 `ZoneModule` (=
// App.swift:2060-2220 references are stale per the Q2 boss split
// (= App.swift shrank to 460 LOC; = the OLD 6-zone layout was the
// pre-split implementation now superseded by the NSV 4-column layout).
// The OLD 6-zone layout had a 3-layer chrome per zone:
// 1. ZoneTopToolbar (30 PT) with zone actions (Graph / Search / expand
//    trailing etc.). This layer is now an outer RegionPerRegionChrome.
// 2. ZoneContentView (internal tab bar with ZoneContentTabBar)
//    — Apple HIG canonical tab bar (= 28×28 hot area + Lucide icon +

/// Editor main content placeholder (= replaces old DesignColor overlay).
/// Real editor content view = ticket 027-35 followup; for now we
/// render a subtle placeholder background matching the old 6-zone
/// "Color.white.opacity(0.55) with 4 PT vertical inset" treatment.
// v0.28 followup Boss UX round 21: .regularMaterial replaces the
/// DesignColor.zoneSurface (= solid) so the placeholder matches the
/// Liquid Glass design language used everywhere else.
// v0.28 followup Boss UX round 31 (Boss 2026-08-29 OOB 'material preview zone,
// dynamic zone, this zone's Liquid Glass effect is different from other zones'): uses
// RegionContentBackground (= single source of truth for per-pane
// content backgrounds = .regularMaterial = standard Liquid Glass tint).
// Previously used .background(.regularMaterial) (= same material but
// different render path = caused subtle inconsistencies with other panes).
//
// v0.28 followup Boss UX round 42: REMOVED the inline
// RegionContentBackground (= now applied automatically by
// ZonePerRegionChrome in round 42 = single source of truth for
// per-pane content backgrounds). Keeping this as a placeholder
// for the editor placeholder content (= shows the actual editor
// surface).


/// Editor expand/shrink trailing button (= old v0.25.1 ticket 029c).
/// Per boss 8/26 OOB 'after clicking, maximize the entire editor, hide all other
/// columns, at this point the ICON becomes shrink, after clicking restore to the state just before clicking expand'.
/// State + snapshot lives in @AppStorage (= ticket 01, v0.34).
/// v0.34 ticket 03: action closure now posts the .wenshuEditorMaximizedChanged
/// notification (= PaneNSController listener installed by ticket 02 handles
/// the actual layout mutation). The button stays a thin View-local proxy:
/// read @AppStorage, write @AppStorage, post notification.

/// EditorPlaceholder — temporary view for the editor zone (= the real

/// EditorPreviewContent (= ticket 05): renders markdown body using
/// swift-markdown (= AGENTS.md §11.1) AttributedString + converts
/// [[wikilink]] occurrences (= via wenshu's existing InternalLinkParser)
/// into clickable Button instances that surface the target ref via the
/// `wikilinkTarget` closure (= ticket 027-35 wires navigation).
///
/// v0.34 ticket 06: append wenshu's existing BacklinksPanel (= Core/LinkGraph/
/// BacklinksPanel.swift, = v0.19 ticket 12 Obsidian replica) below the
/// rendered markdown. ViewModel loads on `.task` (= Apple HIG async task
/// lifecycle). Doc id is the placeholder sample body filename for now;
/// ticket 027-35 will wire to the real open document.
///
/// Spec user stories covered:
///   US-2 (preview mode renders markdown headers/bold/italic/lists/code)
///   US-9 ([[wikilink]] clickable, 1:1 Obsidian syntax)
///   US-10 (InternalLinkParser same parser as wiki layer = consistency)
///   US-11 (BacklinksPanel at bottom of preview, = Obsidian parity)
///   US-12 (uses pinned swift-markdown 0.4.0)

/// EditorEditContent (= v0.34 ticket 07, v0.39 ticket 001 upgrade):
/// Markdown editor surface. v0.34 used Apple SwiftUI TextEditor
/// (= HIG multi-line text input). v0.39 ticket 001 swaps it for
/// nodes-app/swift-markdown-engine via the wenshu-side wrapper
/// `WenshuMarkdownEditor` (NSViewRepresentable around the engine's
/// NativeTextViewWrapper). Engine gives us TextKit 2 layout, live
/// markdown styling, code-fence syntax highlight, wiki-link
/// resolution against reference-library, and image embed resolution.
/// The host (EditorPlaceholder / WorkspaceView) owns the draft state
/// + save logic + markdown engine configuration (= built by
/// `WenshuEditorServicesFactory` from BookStore + active book path);
/// this view is the rendering surface only. Apple HIG behaviors
/// (undo, find, accessibility, IME) are inherited from NSTextView
/// (= the engine's underlying view).
///
/// Spec user stories covered:
///   US-6 (Edit mode = markdown-aware editor, v0.39 swap)
///   US-7 (Save button highlights when dirty, = .tint on draft != original)
///   US-8 (Close button placeholder; see ticket 09)
///   US-13 (no hand-rolled NSTextView wrapper — engine wraps it)
///   US-22 (character-level dirty detection)

/// v0.34 B-20: FormatToolbarButtons (= boss 9/2 OOB 'format toolbar' =
/// 'all can do'). 5 inline MD formatting buttons: bold / italic /
/// heading / inline code / bullet list. Sits in the editor top-bar
/// left slot (= Q21-boss answer = "editor top toolbar left side"). Shown
/// only in .edit mode (= formatting raw MD source; = no-op on the
/// rendered preview).
///
/// Apple HIG rationale:
/// - Button + .plain buttonStyle + Lucide icons (= system component
///   + no custom-drawn controls; = Rule 7).
/// - Each action wraps the current cursor selection (= or inserts
///   at cursor if no selection). Selection tracking is via
///   @FocusedValue (Apple HIG macOS 14+ pattern; = the toolbar
///   lives outside the TextEditor's selection state, so it reads
///   the selection via the focused value bridge).
/// - Diff-style implementation (= Apple HIG standard pattern): the
///   toolbar reads the focused selection, computes the formatted
///   variant, and writes back via the @Binding draft.
///
/// Limitation (= boss spec = boss 9/2 OOB 'pure TextEditor MD source'):
/// the toolbar wraps text but does NOT select the inserted markers
/// (= user has to manually re-select the wrapped text to un-bold).
/// This is the Apple HIG TextEditor standard behavior (= matches
/// Pages / TextEdit). Selection-aware marker replacement is a v0.35+

/// EditModeBadge — small visual indicator shown in the top-right
// corner of WorkspaceView when layout edit mode is on. Click to
// toggle off (= same effect as pressing ⌘⇧\ again).
///
/// Per ticket 028-006 §"Acceptance criteria": the badge is the
/// only edit-mode-related UI shipped in 028-006 (= the TreeEditBar
/// and LayoutPicker are 028-007 / 028-009).

// MARK: - PreviewTabBackground (= preview pane content background)
//
// v0.28 followup Boss UX round 42 (Boss 2026-08-29 OOB 'missing three zones,
// project manager, tools, chat, none entered your stylesheet'): REMOVED the inline
// RegionContentBackground call. The background is now applied
// uniformly by ZonePerRegionChrome (= single source of truth for
// per-pane content backgrounds). PreviewTabBackground is now just
// Color.clear (= will be wrapped automatically by the chrome layer).


/// v0.30 boss 8/31 OOB: sort button rendered in the preview pane's
/// tab bar trailing slot. ponytail fix: previous Menu-based
/// implementation collapsed to zero size inside ZoneContentView's
/// trailing slot (= the AnyView wrapper at ZoneContentTabBar erases
/// intrinsic size, and SwiftUI's Menu doesn't render its label in
/// this context). Replaced with simple plain Button + cycle-through
/// sort order pattern (= mirrors NewButtonWithHover's plain Button
/// + LucideIcon + frame pattern which DOES render correctly).

// MARK: - findPaneController (Apple canonical view-tree BFS)
//
// SwiftUI macOS 27 WindowGroup wraps the entire view tree inside
// an `AppKitWindowHostingController`. The hosting controller's
// `children` array is empty (= PaneNSController lives as the
// `viewController` of an NSSplitView subview, NOT as a child VC).
// Walk both the VC tree AND the view tree together (= shared
// visited set on ObjectIdentifier so the BFS is cycle-safe; the
// previous recursive impl crashed with a 74586-deep stack
// overflow because SwiftUI's `nextResponder` chain forms a
// cycle).
@MainActor
fileprivate func findPaneController(in root: NSViewController?) -> PaneNSController? {
    guard let root else { return nil }
    var visited: Set<ObjectIdentifier> = []
    var queue: [AnyObject] = [root]
    var scanned = 0
    while let obj = queue.first {
        queue.removeFirst()
        let id = ObjectIdentifier(obj)
        guard !visited.contains(id) else { continue }
        visited.insert(id)
        scanned += 1
        if let p = obj as? PaneNSController {
            NSLog("[wenshu.reset] BFS found PaneNSController after scanning \(scanned) obj(s) (type=\(type(of: obj)))")
            return p
        }
        // For a VC: enqueue its children + view tree.
        if let vc = obj as? NSViewController {
            queue.append(contentsOf: vc.children)
            queue.append(vc.view)
            continue
        }
        // For a view: enqueue its subviews. Check the view's
        // `nextResponder as? NSViewController` (= the standard
        // AppKit way to find a VC from a view) ONLY if the view
        // itself isn't a known type (= avoids walking the whole
        // responder chain into a cycle).
        if let v = obj as? NSView {
            queue.append(contentsOf: v.subviews)
            // One-shot nextResponder probe: standard AppKit API,
            // safe because we don't recurse into it (= the next
            // loop iteration just tests it for PaneNSController
            // and otherwise enqueues its children + view, which
            // terminates in O(1) per view because the responder
            // chain is acyclic for the first hop).
            if let next = v.nextResponder as? NSViewController,
               !visited.contains(ObjectIdentifier(next)) {
                queue.append(next)
            }
            continue
        }
    }
    NSLog("[wenshu.reset] BFS failed: scanned \(scanned) obj(s), no PaneNSController found under root=\(type(of: root))")
    return nil
}


/// The sheet of paper the editor sits on, in the shape Pages uses.
///
/// Boss 2026-09-09 OOB: give the middle column a paper-sized area and put
/// the markdown engine on the white part.
///
/// Width is A4 (595 PT). Measured Pages on this machine: its canvas draws
/// a 593 PT sheet against a dark surround, which is A4 at 100% zoom. The
/// sheet keeps that width and never stretches with the window; the column
/// around it scrolls and centers, exactly like a document canvas.
struct EditorPaperCanvas<Content: View>: View {
    /// A4 width in points. Apple's own default for a new Pages document
    /// in a metric locale, and what the measurement above confirmed.
    /// Boss 2026-09-10 OOB 'just design the paper as a single A4 sheet': keep
    /// paperWidth = 595 PT (= Pages / Numbers use the same). The
    /// ScrollView wraps the sheet; when the detail column is
    /// narrower than 595 PT, the user can scroll horizontally to
    /// see the rest of the page (= Pages does the same when its
    /// window is narrower than A4).
    private static var paperWidth: CGFloat { 595 }
    /// Page margin. Pages ships 1 inch (72 PT) on a new document.
    private static var paperMargin: CGFloat { 72 }

    @ViewBuilder var content: Content

    var body: some View {
        // v0.100 boss 2026-09-10 OOB 'big empty areas on the left and right of the paper':
        // the sheet used to be left-aligned inside its
        // ScrollView (= the 595 PT paper sat flush against the
        // ScrollView's leading edge = ~370 PT of black empty
        // space on the right of the sheet). Center the paper
        // horizontally with an HStack + Spacers. The previous
        // attempts with `.frame(maxWidth: .infinity)` on the
        // HStack did not expand because the ScrollView's
        // intrinsic content size locked to the 595 PT paper
        // (= SwiftUI 27 macOS prefers content-natural-size
        // ScrollView over the column-width-stretched variant).
        // Apply `.scrollTargetLayout` + `.defaultScrollAnchor
        // (.center)` (= Apple macOS 14+ API that centers
        // smaller content inside a larger ScrollView; = the
        // same mechanism SwiftUI uses for centered hero
        // images). The Spacers then have room to push the
        // paper to the visual center of the column.
        ScrollView([.horizontal, .vertical]) {
            content
                .padding(Self.paperMargin)
                .frame(width: Self.paperWidth, alignment: .topLeading)
                .frame(minHeight: 842)          // A4 height
                .background(Color.white)
                .environment(\.colorScheme, .light)
                .shadow(color: .black.opacity(0.35), radius: 8, y: 2)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .defaultScrollAnchor(.center)
        .scrollContentBackground(.hidden)
    }
}
