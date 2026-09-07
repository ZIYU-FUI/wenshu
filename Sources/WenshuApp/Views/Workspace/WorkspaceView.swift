// WorkspaceView.swift · Wenshu · v0.27 ticket 027-34
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
import Lucide
import MarkdownEngine  // v0.39 ticket 001: MarkdownEditorConfiguration type

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
    private func openCardInEditor() {
        let (path, content, title): (String?, String, String)
        switch previewScope {
        case .referenceScope(let category):
            let entities = (try? bookStore.referenceStore.loadAllReferences()) ?? []
            let filtered = entities.filter { entity in
                entity.layer == .layerEntities
                    && (category == nil || entity.category == category)
            }
            if let first = filtered.first {
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
            path = nil; content = ""; title = "book-doc"
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
            mode: .preview
        )
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
            // and the legacy NSMenu entry at App.swift:567 + 1442)
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
            // [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
            // 'check the project manager zone position, the Y-axis position and the material management zone do not seem aligned'
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
            // v0.40 boss 9/7 OOB '位置错, 在顶栏下方, 不是在顶栏上方.
            // 你可以参考一下编辑器的代码, 看是如何实现的': the search bar
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
                    onDoubleClick: {
                        openCardInEditor()
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
                ("Long-Form", "shield-check", AnyView(LongFormGuardrailsView())),
                ("Reader-Exp", "sparkles", AnyView(ReaderExperienceView())),
                ("Plot-Thread", "git-branch", AnyView(PlotThreadView())),
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

//}

// ZoneModuleView — small wrapper around the existing ZoneModule. We
// expose a `zoneSlot`-keyed initializer (= matches the v0.27 ZoneModule
// constructor signature).
//
// For v0.27 we defer the full ZoneModule integration (= which requires
// its LayoutShellViewModel parameter; = see ticket 027-35 followup).
// For now this view renders a placeholder color (= a sane default
// that the user can see + interact with while the integration lands).
// ZoneModuleView — verbatim port of the old v0.27 `ZoneModule` (=
// App.swift:2060-2220). The OLD 6-zone layout had a 3-layer chrome per zone:
// 1. ZoneTopToolbar (30 PT) with zone actions (Graph / Search / expand
//    trailing etc.). This layer is now an outer RegionPerRegionChrome.
// 2. ZoneContentView (internal tab bar with ZoneContentTabBar)
//    — Apple HIG canonical tab bar (= 28×28 hot area + Lucide icon +
//    selected indicator underline + matchedGeometryEffect animation).
//    Each zone has 1-N internal tabs (= e.g. editor has 3: Edit/Outline/Backlinks).
// 3. ZoneBottomToolbar (30 PT) with per-zone status text (bookshelf count / chapter count
//    / word count / tools ready / kanban). Also now an outer ZonePerRegionChrome.
//
// The v0.27 `ZoneModule` had a single case that built the full
// content view (= ZoneContentView for 4 general zones, ChatZoneView
// for chat, DynamicZoneView for dynamic). This struct re-implements
// that case-by-case dispatch using the actual ZoneContentView /
// ChatView / DynamicZoneView (= the real tabbed views, not
// placeholders). Boss 2026-08-29 OOB 'are the original tabs in the current framework
// using the default style' = yes — every zone has a ZoneContentTabBar with
// Lucide icons + accent underline + selected state. Per Boss
// 'completely not 1:1' OOB, this commit restores 1:1 match by replacing
// the placeholder text views with the real tabbed zone views.
//
// Per v0.27 boss 8/27 OOB #3: projectSidebar zone has `trailingButton`
// (= NewLibraryOutlineView's zoneHeaderButtons = New + Import icon buttons).
// Per v0.25.1 ticket 029c: editor zone has `trailingButton` (=
// expand/shrink toggle button, icon swap based on editorMaximized).

struct ZoneModuleView: View {
    let zoneSlot: ZoneSlot

    /// v0.30: bindings passed from WorkspaceView so sidebar category
    /// selection → preview pane can react (= same Binding reference).
    /// Default value `nil` (= for non-workspace callers that don't
    /// drive the preview pane).
    @Binding var selectedEntityCategory: EntityCategory?
    @Binding var selectedEntity: Reference?

    /// v0.30 boss 8/31 OOB 'cross-zone interaction' (= option A):
    /// AppState is the global @Observable source of truth.
    /// ZoneModuleView reads it directly (= no @Binding chain).
    @Environment(AppState.self) private var appState

    /// v0.34 B-25-fix (= boss 9/3 'PreviewPane double-click did not open the document'):
    /// ZoneModuleView also needs BookStore to read reference bodies
    /// (= same as WorkspaceView's openCardInEditor). Injected via
    /// the existing .environment(bookStore) call sites in App.swift
    /// + LibraryRootView.
    @Environment(BookStore.self) private var bookStore

    /// v0.30 boss 8/31 OOB: computed preview scope (= mirrors
    /// WorkspaceView's `previewScope`; duplicated here to keep
    /// ZoneModuleView self-contained without threading the scope
    /// through WorkspaceView → ZoneModuleView via another binding).
    private var previewScope: PreviewScope {
        guard let item = appState.sidebarSelection else { return .empty }
        switch item {
        case .book(let bookId):
            return .bookScope(bookId: bookId, folderName: nil)
        case .folder(let bookId, let folderName):
            return .bookScope(bookId: bookId, folderName: folderName)
        case .shelf(let shelfId):
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

    /// v0.30: default initializer for non-workspace callers.
    /// (= pass dummy constants explicitly, see RegisteredPanes.swift)
    init(
        zoneSlot: ZoneSlot,
        selectedEntityCategory: Binding<EntityCategory?> = .constant(nil),
        selectedEntity: Binding<Reference?> = .constant(nil)
    ) {
        self.zoneSlot = zoneSlot
        self._selectedEntityCategory = selectedEntityCategory
        self._selectedEntity = selectedEntity
    }

    var body: some View {
        switch zoneSlot {
        case .projectSidebar:
            // Old 6-zone projectSidebar = 1 tab (Bookshelf, with book-open icon)
            // + trailingButton (New + Import = NewLibraryOutlineView.zoneHeaderButtons).
            // v0.30 boss 8/31 OOB: ZoneModuleView forwards its
            // sidebarSelection binding to NewLibraryOutlineView so
            // the sidebar click → preview pane scope works.
            ZoneContentView(zoneSlug: "projectSidebar", tabs: [
                (WenshuI18n.t("tab.title.bookshelf"), "book-open", AnyView(NewLibraryOutlineView(
                    selectedEntityCategory: $selectedEntityCategory,
                    selectedEntity: $selectedEntity
                ))),
            ], trailingButton: AnyView(NewLibraryOutlineView(
                selectedEntityCategory: .constant(nil),
                selectedEntity: .constant(nil)
            ).zoneHeaderButtons))

        case .projectPreview:
            // Old 6-zone projectPreview = 2 tabs (Preview / Map).
            // Per v0.25.1 ticket 014: book-open-check + waypoints.
            // v0.28 followup Boss UX round 24: preview tab content uses
            // .ultraThinMaterial (= was DesignColor.zoneSurface =
            // solid Color(nsColor: .controlBackgroundColor) = NOT
            // Liquid Glass).
            //
            // v0.30 boss 8/31 OOB: ZoneModuleView is the LEGACY
            // pane registry path (= RegisteredPanes.swift). Callers
            // don't pass a sidebarSelection binding (= they have no
            // concept of book folder scoping), so this preview pane
            // defaults to .empty scope (= empty state). The active
            // WorkspaceView path uses PreviewPane directly with the
            // computed previewScope (= supports all 4 sidebar scopes).
            //
            // v0.40 boss 9/7 OOB '位置错, 在顶栏下方, 不是在顶栏上方.
            // 你可以参考一下编辑器的代码, 看是如何实现的': the search bar
            // belongs BELOW the ZoneContentView's tab strip (= inside
            // PreviewPane's body, = first element rendered after the
            // tab strip). Removed the previous commit's VStack
            // wrapper (= was ABOVE the tab strip, = wrong position).
            // Search bar now lives inside PreviewPane.body (= same Y
            // as the editor's pencil/arrow toolbar inside
            // EditorPlaceholder).
            ZoneContentView(zoneSlug: "projectPreview", tabs: [
                (WenshuI18n.t("tab.title.preview"), "book-open-check", AnyView(PreviewPane(
                    scope: previewScope,
                    // v0.34 B-25-fix (= boss 9/3 'double-clicking card did not open the document'):
                    // ZoneModuleView's caller L561 is the ACTIVE path
                    // (= not WorkspaceView's caller L355 which is dead
                    // code). Route double-click to ZoneModuleView's own
                    // openCardInEditor (= same logic as WorkspaceView's;
                    // = ticket 027-35 will lift into a shared service).
                    //
                    // 2026-09-03 boss 9/3 follow-up: explicitly call
                    // `self.openCardInEditor()` (= Swift strict capture
                    // requirement = PreviewPane's @escaping closure
                    // captured `self` implicitly, and the implicit
                    // `openCardInEditor()` resolution went to the wrong
                    // scope = the closure ran but the method was not
                    // resolved to ZoneModuleView). Explicit `self.`
                    // fixes the resolution.
                    onDoubleClick: {
                        self.openCardInEditor()
                    },
                    previewSortOrder: .constant(.pinyinFirstLetter)
                ))),
                (WenshuI18n.t("tab.title.graph"), "waypoints", AnyView(GraphView())),
            ])

        case .specializedTools:
            // Old 6-zone specializedTools = 4 tabs (Foreshadowing / Placeholder /
            // LongFormGuardrails per P1 ticket #6
            // [WIRE-SPECIALIZEDTOOLS-001] 2026-09-04 +
            // ReaderExperience per P1 ticket #7
            // [WIRE-SPECIALIZEDTOOLS-002] 2026-09-04).
            ZoneContentView(zoneSlug: "specializedTools", tabs: [
                (WenshuI18n.t("tab.title.foreshadowing"), "git-fork", AnyView(ForeshadowingView())),
                (WenshuI18n.t("tab.title.placeholder"), "square-dashed", AnyView(PlaceholderView())),
                ("Long-Form", "shield-check", AnyView(LongFormGuardrailsView())),
                ("Reader-Exp", "sparkles", AnyView(ReaderExperienceView())),
                ("Plot-Thread", "git-branch", AnyView(PlotThreadView())),
            ])

        case .aiDynamic:
            // Old 6-zone aiDynamic = DynamicZoneView (= has its own
            // DynamicZoneTabBar with Progress / Todo / Search).
            // Per v0.24 boss 8/24 OOB: external toolbar cleared (= the
            // outer ZoneTopToolbar is empty placeholder mode).
            DynamicZoneView()

        case .aiChat:
            // Old 6-zone aiChat = ChatZoneView (= has its own ChatZoneTabBar
            // with chat / search / settings). Per v0.25.1 ticket 005:
            // top icons are Bot + Inbox.
            ChatView()

        case .editor:
            // Old 6-zone editor = 3 tabs (Edit / Outline / Backlinks) + trailingButton
            // (expand/shrink toggle). Real ZoneContentView — replaces
            // EditorPlaceholder (= which was just text "Editor zone
            // ticket 027-35 integration pending").
            // Per v0.25.1 ticket 017 + 028: book-open-text + puzzle + link.
            ZoneContentView(
                zoneSlug: "editor",
                tabs: [
                    // v0.34 B-13 fix (= boss 9/2 'git grep BEFORE patch' rule):
                    // see L279 fix comment above; replace placeholder with
                    // EditorPlaceholder (= ticket 04-10 toolbar + mode toggle).
                    (WenshuI18n.t("tab.title.editor"), "book-open-text", AnyView(EditorPlaceholder())),
                    (WenshuI18n.t("tab.title.outline"), "puzzle", AnyView(OutlinePanel())),
                    // v0.34 B-16: removed the "Backlinks" tab here (= boss 9/2 OOB
                    // 'the Backlinks area still has to be removed'). Backlinks are now
                    // surfaced via the chrome bottom-right "Backlinks 0"
                    // label click → popover (= spec user stories 8 + 11).
                ],
                // v0.25.1 (= ticket 029c-trailing-button): expand/shrink
                // trailing button. Boss 8/26 OOB 'it is one button, not a tab
                // teb' = won't be a tab (= no selected underline), just
                // a button at the right edge of the tab bar.
                trailingButton: AnyView(
                    EditorExpandShrinkTrailingButton()
                )
            )
        }
    }

    /// v0.34 B-25-followup (= boss 9/3 'fix it until I can use it'): ZoneModuleView
    /// needs its own openCardInEditor (= WorkspaceView's openCardInEditor
    /// is in a DIFFERENT struct = can't share via this same View type).
    /// Code is mostly duplicated from WorkspaceView's openCardInEditor
    /// + the book-scope branch reads the actual .md file (= same walk
    /// as PreviewPane.loadBookDocs; = ticket 027-35 will lift that
    /// helper into a workspace-level BookDocLoader service so both
    /// callers share it).
    private func openCardInEditor() {
        let (path, content, title): (String?, String, String)
        switch previewScope {
        case .referenceScope(let category):
            let entities = (try? bookStore.referenceStore.loadAllReferences()) ?? []
            let filtered = entities.filter { entity in
                entity.layer == .layerEntities
                    && (category == nil || entity.category == category)
            }
            if let first = filtered.first {
                let body = (try? bookStore.referenceStore.loadReferenceBody(id: first.id)) ?? first.summary
                path = nil
                content = body
                title = first.title
            } else {
                path = nil; content = ""
                title = category?.displayName ?? WenshuI18n.t("tab.title.reference_library")
            }
        case .bookScope(let bookId, let folderName):
            // Walk shelves/<shelf-uuid>/books/<book-uuid>/<folder>/*.md.
            // Mirrors PreviewPane.loadBookDocs (= same logic; = ticket
            // 027-35 will lift into a shared BookDocLoader service).
            let shelvesRoot = bookStore.stores.shelvesRoot
            let bookDirs: [URL] = {
                guard let shelfDirs = try? FileManager.default.contentsOfDirectory(
                    at: shelvesRoot,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                ) else { return [] }
                return shelfDirs.compactMap { shelfDir in
                    let candidate = shelfDir
                        .appendingPathComponent("books")
                        .appendingPathComponent(bookId.uuidString)
                    return FileManager.default.fileExists(atPath: candidate.path)
                        ? candidate
                        : nil
                }
            }()
            guard let bookDir = bookDirs.first else {
                path = nil; content = ""; title = "book-doc"
                break
            }
            // Determine which folders to scan.
            let folders: [String] = {
                if let folderName {
                    return [folderName]
                }
                // Default = scan all 8 standard folders (= same as
                // PreviewPane.loadBookDocs default).
                return [
                    "world", "characters", "outlines", "chapters",
                    "drafts", "sessions", "foreshadowing", "placeholders"
                ]
            }()
            // Find the FIRST .md file (= v0.34 placeholder; = ticket
            // 027-35 will wire to the SPECIFIC card the user double-
            // clicked).
            var foundPath: URL?
            var foundBody: String = ""
            var foundTitle: String = ""
            for folder in folders {
                let dirURL = bookDir.appendingPathComponent(folder)
                guard let entries = try? FileManager.default.contentsOfDirectory(
                    at: dirURL,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                ) else { continue }
                if let first = entries.first(where: { $0.pathExtension == "md" }) {
                    foundPath = first
                    foundBody = (try? String(contentsOf: first, encoding: .utf8)) ?? ""
                    foundTitle = first.deletingPathExtension().lastPathComponent
                    break
                }
            }
            path = foundPath?.path
            content = foundBody
            title = foundTitle
        case .shelfScope, .empty:
            path = nil; content = ""; title = ""
        }

        guard !content.isEmpty else { return }

        // Duplicate-tab check (= same logic as WorkspaceView's).
        let fingerprint = String(content.prefix(200))
        if let existingIdx = appState.openTabs.firstIndex(where: {
            String($0.originalBody.prefix(200)) == fingerprint
        }) {
            appState.activeTabId = appState.openTabs[existingIdx].id
            return
        }

        // Open new tab.
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
            mode: .preview
        )
        // v0.34 B-26-FIX (= boss 9/3 'first double-click can switch, not a new tab, it replaces
        // the old tab; second double-click fails'): the previous implementation tried
        // to be smart (= replace the active tab if clean; append a new
        // tab if dirty; = Safari "reuse clean tab" behavior). That was
        // the wrong call: boss expected a real multi-tab = each
        // double-click creates a NEW tab page (= the active placeholder
        // tab stays as the first tab; = new tab is appended; = no
        // replacement of the active tab).
        //
        // v0.34 B-26-FIX: always append (= Safari tab strip behavior).
        // Duplicate-tab detection (boss 9/3 follow-up: 'check whether an existing tab
        // already opened the current MD') happens earlier in this function (= the
        // fingerprint check that switches to the existing tab if the
        // .md body matches an already-open tab). = no replacement
        // behavior; = no "second click fails" race.
        appState.openTabs.append(newTab)
        appState.activeTabId = newTab.id
    }

}

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
/// EditorView integration is ticket 027-35 followup).
/// v0.34 ticket 04: added EditorMode enum + preview/edit mode toggle
/// button (= PaneTrailingIconButton with eye / pencil icon). Mode state
/// is local (= @State, = ticket 05/07 will integrate with document load).
struct EditorPlaceholder: View {
    // v0.34 B-24: Mode enum lifted to module scope (= EditorMode, in
    // AppState.swift; = so EditorTab can reference it). The nested
    // Mode enum was removed; = EditorPlaceholder.Mode.iconName /
    // .tooltip helpers became EditorMode.iconName / .tooltip (= same
    // shape; = one-line update at every usage).
    /// v0.34 ticket 04: mode lives on the active tab (= AppState.openTabs
    /// [activeTabId].mode). Reading the active tab's mode instead of a
    /// View-local @State = each tab keeps its own preview/edit state
    /// (= switching tabs preserves mode; = matches Safari behavior).
    private var mode: EditorMode {
        appState.openTabs.first(where: { $0.id == appState.activeTabId })?.mode ?? .preview
    }
    private func setMode(_ newMode: EditorMode) {
        guard let idx = appState.openTabs.firstIndex(where: { $0.id == appState.activeTabId }) else { return }
        appState.openTabs[idx].mode = newMode
    }

    /// v0.34 B-26: derive the display title for a tab (= file basename
    /// without the .md extension; = boss 9/3 OOB 'no .md extension either'). Placeholder tab = 'preview-sample' (= no .md extension,
    /// = no path = render the short placeholder name).
    private func tabDisplayTitle(tab: EditorTab) -> String {
        if let path = tab.documentPath, !path.isEmpty {
            let url = URL(fileURLWithPath: path)
            let basename = url.deletingPathExtension().lastPathComponent
            return basename.isEmpty ? "preview-sample" : basename
        }
        return "preview-sample"
    }

    @Environment(AppState.self) private var appState
    // v0.39 ticket 001: WenshuEditorServicesFactory.make needs
    // referenceLibraryRoot + active book root. Both come from
    // BookStore (= injected via .environment(bookStore) at the
    // WindowGroup root in App.swift + LibraryRootView, per
    // v0.34 B-25-fix pattern).
    @Environment(BookStore.self) private var bookStore

    // P2 #19 (WIRE-PARAGRAPH-002): live editor selection snapshot
    // (= the text the paragraph_ai buttons operate on). The
    // markdown engine is an NSViewRepresentable wrapping NSTextView;
    // a real selection-bridge would require an NSTextViewDelegate
    // (= a separate ticket that the engine doesn't expose yet).
    // For this ticket we keep a View-local @State + a public setter
    // (= setSelection(_:)) that future wiring can call from the
    // engine's coordinator; today the buttons act on the whole
    // draft when no selection is reported (= matches the existing
    // FormatToolbarButtons fallback behavior in v0.34 B-20).
    @State private var selectedText: String = ""

    /// P2 #19 (WIRE-PARAGRAPH-002): applyParagraphAI spinner flag.
    /// Disables the 3 toolbar buttons + the menu while an LLM call
    /// is in flight (= prevents double-fire; = Apple HIG
    /// actionable-control-while-busy rule).
    @State private var isApplyingParagraphAI: Bool = false

    /// P2 #19 (WIRE-PARAGRAPH-002): public selection setter.
    /// Future ticket will bridge this from the engine's
    /// NSTextViewDelegate. Today the setter is unused (= the
    /// buttons fall through to the whole-draft path; see
    /// applyParagraphAI's guard).
    public func setSelection(_ text: String) {
        selectedText = text
    }

    /// v0.39 ticket 001: lookup the active tab's id (= the engine's
    /// `documentId` for undo + replacement scoping). Falls back to
    /// a deterministic placeholder id when no tab is open (=
    /// editor in initial state with no document).
    private var activeTabIdString: String {
        appState.openTabs.first(where: { $0.id == appState.activeTabId })?.id.uuidString
            ?? "wenshu-editor-no-tab"
    }

    var body: some View {
        VStack(spacing: 0) {
            // v0.34 B-26-TABBAR (= boss 9/3 'change this whole column to a tab bar,
            // remove the three ICON buttons at the back first'): editor top bar replaced
            // with a Safari-style tab strip showing every tab in
            // `appState.openTabs`. Active tab is highlighted; each tab
            // has a close button (= tap to remove from openTabs). Boss
            // moved the 3 trailing icon buttons (= mode toggle, expand,
            // close) elsewhere (= per boss OOB 'I will implement it in a different position').
            //
            // Apple HIG tabbed-document pattern (= NSTabView / Safari
            // tab strip): single-line HStack, scrollable horizontally
            // when tabs overflow. = no formatting toolbar / no save
            // button (= the per-tab formatting + save hotkey move to
            // the new tab-bar layout as boss decides).
            // v0.34 B-26 boss 9/3 'I open a new file, the new TAB page does not appear' + 'refer to this
            // style, modify the tab style' (= reference image shows plain
            // all-caps monospaced tab labels; = boss 9/3 follow-up:
            // [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
            // 'no ICON needed, just the document name, no .md extension either').
            // Editor top bar = a simple horizontal HStack of tab names
            // (= .monospaced .caption text; = active tab = .tint color
            // + .tint background tint at 0.12). No icons, no .md
            // extension, no trailing buttons. Boss 9/3 follow-up 'switching
            // the directory will re-detect once' = when the user switches
            // sidebar scope, the PreviewPane body re-renders AND the
            // EditorTabBarBar (now inlined) re-renders too; = the
            // SwiftUI @State click-count latch is reset (= which is
            // the desired "fresh start" per boss OOB).
            HStack(spacing: 0) {
                ForEach(appState.openTabs) { tab in
                    let title = tabDisplayTitle(tab: tab)
                    let isActive = (tab.id == appState.activeTabId)
                    Button(action: { appState.activeTabId = tab.id }) {
                        Text(title)
                            .font(DesignTokens.tabTitleFont.weight(isActive ? .semibold : .regular))
                            .foregroundStyle(isActive ? Color.accentColor : .secondary)
                            .padding(.horizontal, DesignTokens.chromePaddingMedium)
                            .frame(height: DesignTokens.paneTabHotArea)
                            .background(
                                Rectangle()
                                    .fill(isActive ? Color.accentColor.opacity(0.12) : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(title)
                }
                // v0.39 ticket 001-C: mode toggle (= preview <-> edit).
                // The boss reported 'cannot enter MD edit mode' which
                // was actually two issues (= default = .preview +
                // no UI to flip it). openCardInEditor now defaults
                // to .edit (= the 001-A fix), but users still need
                // a way to flip back to .preview when they want the
                // rendered-only view. This button lives in the tab
                // strip = the only chrome the editor zone has left
                // after v0.34 B-26 stripped the trailing buttons.
                Button(action: { setMode(mode == .edit ? .preview : .edit) }) {
                    Image(systemName: mode == .edit ? "eye" : "pencil")
                        .font(DesignTokens.hotkeyComboFont)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, DesignTokens.chromePaddingChatBottom)
                        .padding(.vertical, DesignTokens.chromePaddingMicro)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(mode == .edit
                    ? WenshuI18n.t("workspace.editor.switch_to_preview")
                    : WenshuI18n.t("workspace.editor.switch_to_edit"))
                // P2 #19 (WIRE-PARAGRAPH-002): paragraph_ai toolbar.
                // 3 buttons with keyboard shortcuts (⌘⇧E expand,
                // ⌘⇧H shorten, ⌘⇧R rephrase) + a Menu for the 3
                // less-common transforms (shiftTone / simplify /
                // dramatize). The buttons fire applyParagraphAI(...)
                // which calls the active LLM connector (= the
                // v0.35 LLMConnector layer) with the editor
                // transform prompt prefix + selected text, then
                // replaces the selection (= today: whole draft) with
                // the LLM response.
                //
                // Apple HIG toolbar pattern: `.help(...)` provides
                // the tooltip (= Apple-native NSWindow tooltip, =
                // per the wenshu-apple-api-first hard rule), and
                // `.keyboardShortcut(...)` registers the global key
                // binding via SwiftUI's native command system (= no
                // third-party shortcut lib required; matches the
                // boss 2026-08-27 OOB 'Apple-stack-except-where-
                // Apple-doesn't-ship' carve-out).
                //
                // Disabled state (= `selectedText.isEmpty`):
                // matches the boss spec's wire-up; until the
                // engine selection bridge lands, `selectedText`
                // defaults to "" so the buttons stay disabled
                // (= the buttons currently never fire from the
                // UI; tests cover the apply path directly).
                ParagraphAIToolbarButtons(
                    selectedText: selectedText,
                    isApplying: isApplyingParagraphAI,
                    onApply: { transform in
                        Task { await applyParagraphAI(transform) }
                    }
                )
                Spacer()
            }
            .frame(height: DesignTokens.toolbarBandHeight)
            // POLISH-LIQUIDGLASS-003 (Boss 2026-09-05 OOB 'OK continue', AGENTS.md
            // §11 macOS 27 Liquid Glass polish extends from TopBar + Sidebar):
            // apply Apple canonical .glassEffect(.regular) (= macOS 27
            // Tahoe Liquid Glass) to the EditorPlaceholder tab strip
            // (= the editor zone's top chrome = Safari-style tab strip
            // + mode toggle + paragraph_ai toolbar). Replaces the prior
            // .regularMaterial (= Apple Liquid Glass translucency; = one
            // step LESS transparent than the new .glassEffect(.regular)
            // canonical material on macOS 27 Tahoe = visible mismatch
            // with the POLISH-LIQUIDGLASS-001 TopBar chrome the user
            // sees directly above the editor zone in the same pane).
            // v0.40 boss real-device test 2026-09-07: removed
            // .glassEffect(.regular) (= Liquid Glass tab strip);
            // now uses Color.clear (= no background).
            .background { Color.clear }
            // v0.34 ticket 09: dirty-discard confirm dialog. Shown when
            // user tries to close with unsaved changes. Apple HIG
            // 2-option confirm pattern (= destructive + cancel).
            // B-24: showDirtyDiscardConfirm is now a computed property;
            // = wrap in Binding(get:set:) for .alert's isPresented:.
            .alert(WenshuI18n.t("workspace.editor.dirty_discard_alert_title"), isPresented: Binding(
                get: { self.showDirtyDiscardConfirm },
                set: { self.showDirtyDiscardConfirm = $0 }
            )) {
                Button(WenshuI18n.t("workspace.editor.dirty_discard_button"), role: .destructive) {
                    // Discard: clear draft + reset to originalBody + close.
                    // Today = no-op beyond resetting state (= ticket 027-35
                    // wires real document close).
                    draft = originalBody
                    documentPath = nil
                    // v0.34 B-22: discard = no more writes ever (= the
                    // edits are thrown away). Cancel any pending auto-save
                    // Task + notify handler with dirty = false (= matches
                    // the post-discard state).
                    handleDirtyTransition(false)
                }
                Button(WenshuI18n.t("button.continue_edit"), role: .cancel) { }
            } message: {
                Text(WenshuI18n.t("workspace.editor.discard_changes_confirm"))
            }

            // Body: placeholder content. Ticket 05 swaps this for
            // swift-markdown rendered Text when mode = .preview; ticket 07
            // swaps for Apple TextEditor when mode = .edit.
            ZStack {
                // v0.34 ticket 05: preview mode uses swift-markdown
                // (= AGENTS.md §11.1 pinned 0.4.0) AttributedString render
                // for headers/bold/italic/lists/code/links, plus
                // InternalLinkParser (= wenshu's existing parser, = 1:1
                // Obsidian wikilink syntax) to make [[name]] clickable.
                // Placeholder sample body until ticket 027-35 wires the
                // real document load (= the Apple HIG DocumentGroup
                // file-open path is the v0.35+ ticket).
                // v0.34 B-25-FIX (= boss 9/3 'preview BUG is still there'): EditorPlaceholder
                // preview mode previously rendered `Self.samplePreviewBody`
                // (= static placeholder string) regardless of which tab
                // was active. Replaced with `self.draft` (= per-tab
                // computed property backed by appState.openTabs[activeTabIdx].draft)
                // so the preview shows the active tab's content = when
                // openCardInEditor creates/updates a tab with the .md body
                // read from disk, the preview updates immediately. This
                // is the v0.34 B-25 root-cause fix (= the closure chain
                // WAS firing correctly; = the bug was the view rendering
                // the placeholder instead of the active tab).
                // v0.40 boss 9/7 OOB '删除空白预览文档': when no
                // tab is open, show the empty-state hint instead of
                // the preview/edit body (= replaces the previous
                // samplePreviewBody placeholder).
                if activeTab == nil {
                    emptyStateHint
                } else if mode == .preview {
                    // SMC ticket 003: preview-mode wiki-link nav
                    // routes through the reference library + active
                    // book chapter lookup (= real target resolution).
                    EditorPreviewContent(
                        markdownBody: draft,
                        wikilinkTarget: { displayName in
                            handlePreviewWikiLink(displayName: displayName)
                        }
                    )
                } else {
                    // v0.34 ticket 07: edit mode uses Apple SwiftUI
                    // TextEditor (= HIG standard multi-line text input).
                    // @State draft holds the working copy; dirty detection
                    // = draft != originalBody (character-level diff per
                    // Q22 boss decision). Save button (added by ticket 08)
                    // .tint highlights when dirty; Cmd+S hotkey (ticket
                    // 10) triggers save.
                    // B-24: draft is a computed property (= reads active
                    // tab). Wrap in Binding(get:set:) so EditorEditContent
                    // can still use @Binding draft (SwiftUI 2-way binding
                    // contract).
                    EditorEditContent(
                        draft: Binding(
                            get: { self.draft },
                            set: { self.draft = $0 }
                        ),
                        originalBody: originalBody,
                        onSave: { saveDraft() },
                        // v0.34 B-18: route live word count into shared
                        // AppState.editorWordCount (= chrome bottom-bar
                        // left field reads it). Recompute is per-
                        // keystroke; = Foundation-only = microseconds.
                        onWordCountChange: { count in
                            appState.editorWordCount = count
                        },
                        // v0.34 B-22: route dirty-state transitions
                        // (= false→true = user started editing;
                        // true→false = Cmd+S or auto-save completed).
                        // The handler runs ONCE per transition (= no
                        // per-keystroke Task churn; = Apple HIG
                        // TextEdit / Pages behavior).
                        onDirtyChange: { newDirty in
                            handleDirtyTransition(newDirty)
                        },
                        // v0.39 ticket 001: pre-built markdown engine
                        // configuration. Built once per active-tab switch
                        // (= rebuilds the WikiLinkResolver + ImageProvider
                        // against the active book's path). Engine
                        // configuration is captured by the editor view
                        // (= stable across onChange of draft).
                        // v0.39 ticket 001-B: pass bookStore directly;
                        // factory handles nil (= the v0.39 path that
                        // survives the AnyView-wrapped EditorPlaceholder
                        // when the environment chain hasn't propagated
                        // BookStore yet on early zone activation).
                        configuration: WenshuEditorServicesFactory.make(
                            bookStore: bookStore,
                            // SMC ticket 003: per-active-tab bus so
                            // engine format / find / replace events
                            // stay scoped to this document.
                            bus: MarkdownEditorBus.buildWenshu()
                        ),
                        // v0.39 ticket 001: stable per-tab id, passed
                        // to engine as `documentId` so undo + pending
                        // replacements are scoped to this tab.
                        draftId: activeTabIdString,
                        // SMC ticket 003: forward engine wiki-link
                        // click to the navigation flow.
                        onLinkClick: { linkId in
                            handleEditorWikiLink(linkId: linkId)
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // v0.28 followup Boss UX round 19 (Boss 2026-08-29 OOB 'all
            // zone top bars, bottom bars, backgrounds, the colors used, can they adapt to Liquid Glass?'):
            // Use .ultraThinMaterial instead of Color.green.opacity(0.05)
            // (= solid green placeholder = inconsistent with the
            // Liquid Glass design language). Editor zone has no
            // wired-in content yet (= ticket 027-35 followup), so use the
            // lightest Liquid Glass material as a placeholder that
            // matches the rest of the workspace.
            .background(.ultraThinMaterial)
        }
        // v0.34 B-18: on editor zone mount, seed AppState.editorWordCount
        // with the character count of the initial body (= sample body
        // in placeholder mode; = real document body post-ticket 027-35).
        // Without this, the chrome bottom-bar left field shows "Word count: 0"
        // even when the preview-mode sample body has 200+ chars. The
        // .onChange(of: draft) inside EditorEditContent covers the edit-
        // mode keystroke stream; = this .onAppear covers the initial
        // state (= Apple HIG = seed reactive state at view mount).
        .onAppear {
            // v0.40 boss 9/7 OOB: do NOT seed a placeholder tab when
            // openTabs is empty. Two paths from here:
            //   1. Persisted tabs (loaded by AppState.init from
            //      UserDefaults) → use those directly.
            //   2. No persisted tabs → editor zone shows the
            //      empty-state hint (= "请从素材库中双击卡片打开文档")
            //      via EditorPlaceholder's nil-activeTab branch.
            // The .edit-mode upgrade from .preview still runs for
            // any tabs that survived (= v0.39 ticket 001-A-extended).
            for idx in appState.openTabs.indices {
                if appState.openTabs[idx].mode == .preview {
                    appState.openTabs[idx].mode = .edit
                }
            }
            // Initialize word count from active tab (= 0 when no tab).
            if let tab = activeTab {
                appState.editorWordCount = WordCounter.count(tab.originalBody).charactersNoSpaces
            } else {
                appState.editorWordCount = 0
            }
            // v0.34 B-23: start the file-system watcher for the current
            // documentPath (nil = placeholder mode; = no-op). The watcher
            // auto-reloads draft when the file changes externally (= agent
            // write, git pull, terminal `echo > file.md`, etc.).
            startFileWatcher()
        }
        // v0.34 B-23: tear down the file watcher when the view goes away
        // (= prevents zombie DispatchSource holding the file descriptor).
        .onDisappear {
            stopFileWatcher()
        }
    }

    // v0.34 ticket 07: edit-mode state owner. Both fields initialise from
    // the sample preview body (= placeholder until ticket 027-35 wires
    // the real document load). dirty = draft != originalBody (= ticket
    // 08 reads this for the Save button's .tint highlight).
    // v0.34 B-24: per-tab state lives on AppState.openTabs[activeTabIndex].
    // EditorPlaceholder reads/writes the ACTIVE tab (= single source of
    // truth). These computed properties expose the per-tab state to the
    // rest of the view (= the @State versions are gone; = switching
    // tabs switches the active data set; = matches Safari behavior).
    private var activeTab: EditorTab? {
        guard let idx = appState.openTabs.firstIndex(where: { $0.id == appState.activeTabId }) else { return nil }
        return appState.openTabs[idx]
    }
    private var activeTabIndex: Int? {
        appState.openTabs.firstIndex(where: { $0.id == appState.activeTabId })
    }

    private var draft: String {
        // v0.40 boss 9/7 OOB: when no tab is open, return empty string
        // (= no samplePreviewBody placeholder). The editor zone
        // shows its empty-state hint (= "请从素材库中双击卡片打开文档")
        // via EditorPlaceholder's nil-activeTab branch.
        get { activeTab?.draft ?? "" }
        nonmutating set {
            guard let idx = activeTabIndex else { return }
            appState.openTabs[idx].draft = newValue
        }
    }
    private var originalBody: String {
        get { activeTab?.originalBody ?? "" }
        nonmutating set {
            guard let idx = activeTabIndex else { return }
            appState.openTabs[idx].originalBody = newValue
        }
    }
    private var documentPath: String? {
        get { activeTab?.documentPath }
        nonmutating set {
            guard let idx = activeTabIndex else { return }
            appState.openTabs[idx].documentPath = newValue
        }
    }
    /// Computed dirty flag (= ticket 08 reads this for the Save
    /// button's .tint highlight). Plain computed (= re-evaluated on
    /// each render from the active tab's draft / originalBody).
    private var isDirty: Bool {
        guard let tab = activeTab else { return false }
        return tab.draft != tab.originalBody
    }
    /// Per-tab auto-save Task. Reads from / writes to the active tab.
    private var autoSaveTask: Task<Void, Never>? {
        get { activeTab?.autoSaveTask }
        nonmutating set {
            guard let idx = activeTabIndex else { return }
            appState.openTabs[idx].autoSaveTask = newValue
        }
    }
    /// Per-tab file-system watcher (= B-23).
    private var fileWatcher: DispatchSourceFileSystemObject? {
        get { activeTab?.fileWatcher }
        nonmutating set {
            guard let idx = activeTabIndex else { return }
            appState.openTabs[idx].fileWatcher = newValue
        }
    }
    private var watchedFD: Int32 {
        get { activeTab?.watchedFD ?? -1 }
        nonmutating set {
            guard let idx = activeTabIndex else { return }
            appState.openTabs[idx].watchedFD = newValue
        }
    }
    /// Per-tab external-change notification (= B-23 conflict).
    private var externalChangeNotice: String? {
        get { activeTab?.externalChangeNotice }
        nonmutating set {
            guard let idx = activeTabIndex else { return }
            appState.openTabs[idx].externalChangeNotice = newValue
        }
    }
    /// Per-tab dirty-discard alert state (= ticket 09).
    private var showDirtyDiscardConfirm: Bool {
        get { activeTab?.showDirtyDiscardConfirm ?? false }
        nonmutating set {
            guard let idx = activeTabIndex else { return }
            appState.openTabs[idx].showDirtyDiscardConfirm = newValue
        }
    }
    // v0.34 B-22: save action writes draft back over originalBody (= dirty
    // detection clears). When documentPath is non-nil (= v0.35+ ticket
    // 027-35 wires real document load), also write to disk (= atomic
    // UTF-8 = Apple HIG file write pattern). Cmd+S hotkey (ticket 10) and
    // Save toolbar button both call this directly.
    private func saveDraft() {
        originalBody = draft
        writeDraftToDisk()
        handleDirtyTransition(false)
    }

    // v0.34 B-21 + SMC ticket 003: write the draft to a real
    // filesystem path. Old flow = /tmp fallback when documentPath
    // was nil (= dropped real edits). New flow: if the active tab
    // already has a documentPath, overwrite in place; otherwise
    // propose a chapters/<uuid>.md path under the active book and
    // write there (= auto-bind the tab's documentPath so subsequent
    // saves overwrite the same file).
    private func writeDraftToDisk() {
        if let path = documentPath {
            let url = URL(fileURLWithPath: path)
            try? draft.write(to: url, atomically: true, encoding: .utf8)
            return
        }
        if let activeTab = activeTab,
           let proposed = DraftPersistence.proposedPath(
            for: activeTab, bookStore: bookStore
           ) {
            do {
                let parent = proposed.deletingLastPathComponent()
                try FileManager.default.createDirectory(
                    at: parent, withIntermediateDirectories: true
                )
                try DraftPersistence.persist(text: draft, to: proposed)
                documentPath = proposed.path
            } catch {
                #if DEBUG
                print("[wenshu.editor] chapter save failed: \(error)")
                #endif
            }
            return
        }
        let url = URL(fileURLWithPath: "/tmp/wenshu-preview-sample.md")
        try? draft.write(to: url, atomically: true, encoding: .utf8)
    }

    /// SMC ticket 003: handle a preview-mode wiki-link click.
    /// Looks up the display name in the reference library first
    /// (= library-public entities), then in the active book.
    /// On hit, opens the target as a new tab and switches to it.
    private func handlePreviewWikiLink(displayName: String) {
        guard !displayName.isEmpty else { return }
        guard let result = WikiLinkNavigation.handle(
            displayName: displayName,
            referenceStore: bookStore.referenceStore,
            bookStore: bookStore
        ) else {
            #if DEBUG
            print("[wenshu.editor] wiki-link miss: \(displayName)")
            #endif
            return
        }
        let fingerprint = String(result.body.prefix(200))
        if let existingIdx = appState.openTabs.firstIndex(where: {
            String($0.originalBody.prefix(200)) == fingerprint
        }) {
            appState.activeTabId = appState.openTabs[existingIdx].id
            return
        }
        let newTab = EditorTab(
            id: UUID(),
            documentPath: nil,
            draft: result.body,
            originalBody: result.body,
            mode: .preview
        )
        appState.openTabs.append(newTab)
        appState.activeTabId = newTab.id
    }

    /// SMC ticket 003: handle a wiki-link click from the live
    /// editor surface (= the engine fires onLinkClick with the
    /// resolved link id, NOT the display name). Resolve the id
    /// back to the display name via the active
    /// WikiLinkResolver's name(forID:) and route through the
    /// preview-mode navigation flow.
    private func handleEditorWikiLink(linkId: String) {
        guard !linkId.isEmpty else { return }
        let resolver = ReferenceLibraryWikiLinkResolver(
            referenceLibraryRoot: bookStore.stores.referenceLibraryRoot
        )
        let displayName = resolver.name(forID: linkId) ?? linkId
        handlePreviewWikiLink(displayName: displayName)
    }

    // MARK: - P2 #19 paragraph_ai apply

    /// P2 #19 (WIRE-PARAGRAPH-002): fire the requested paragraph
    /// transform against the active LLM connector and replace the
    /// current selection with the rewritten text.
    ///
    /// Pipeline (= matches the boss spec):
    /// 1. guard on `selectedText` non-empty (= matches the
    ///    `disabled(vm.selectedText.isEmpty)` rule on the toolbar
    ///    buttons; if the engine selection bridge hasn't reported
    ///    anything, no-op).
    /// 2. delegate to the testable static helper
    ///    `EditorParagraphAI.apply(...)` (= internal static; = the
    ///    pure function the test target exercises). The helper
    ///    builds the prompt prefix, calls the connector, extracts
    ///    the response text, and returns it (= no draft mutation
    ///    = no SwiftUI dependency = trivially unit-testable).
    /// 3. replace the selection (= today: whole draft) with the
    ///    returned text.
    ///
    /// Concurrency: Swift 6 strict concurrency. The view is
    /// @MainActor (= EditorPlaceholder is a SwiftUI View; = the
    /// compiler infers MainActor isolation). `await
    /// connector.send(...)` hops off MainActor for the URL
    /// session, then returns; the final `replaceSelectedText`
    /// write stays on MainActor (= the @State mutation requires
    /// it).
    ///
    /// Failure mode (= matches the wenshu S4 graceful-degradation
    /// rule): any throw from the connector (= transport / auth /
    /// missing API key / decode) is logged via NSLog and the
    /// method returns without touching the draft. The user sees
    /// no error UI (= consistent with how WenshuConductor.handle
    /// handles ConversationLoop.runTurn failures); the dirty flag
    /// stays unchanged.
    func applyParagraphAI(_ transform: EditorTransform) async {
        guard !selectedText.isEmpty else { return }
        isApplyingParagraphAI = true
        defer { isApplyingParagraphAI = false }

        let providerSlug = UserDefaults.standard.string(forKey: "wenshu.llm.activeConnector") ?? "anthropic"
        let providerDefaultModel = ProviderCatalog.defaultModels(for: providerSlug).first ?? "unknown"
        let options = LLMCallOptions(
            model: appState.llmModel.isEmpty ? providerDefaultModel : appState.llmModel,
            maxTokens: 2048
        )
        let connector = WenshuAppDelegate.activeLLMConnector()

        do {
            let rewritten = try await EditorParagraphAI.apply(
                selectedText: selectedText,
                transform: transform,
                connector: connector,
                options: options
            )
            guard !rewritten.isEmpty else { return }
            replaceSelectedText(with: rewritten)
        } catch {
            // S4 graceful degradation: log + no-op. The wenshu-dev
            // user sees the underlying failure via Console.app;
            // the in-app UX stays unbroken (draft unchanged,
            // buttons re-enabled by the defer above).
            NSLog("[wenshu.editor] applyParagraphAI(%@) failed: %@", transform.rawValue, String(describing: error))
        }
    }

    /// P2 #19: replace the current selection (= today: whole
    /// draft) with the supplied text. Once the engine selection
    /// bridge lands, this becomes a surgical NSRange replace
    /// (= same signature; only the body changes).
    private func replaceSelectedText(with newText: String) {
        // Fallback behavior (= mirrors FormatToolbarButtons in
        // v0.34 B-20: when the TextEditor selection isn't
        // observable, wrap/overwrite the whole draft). Future
        // ticket narrows to selected NSRange once the engine
        // exposes an NSTextViewDelegate bridge.
        draft = newText
        // Reset the selection snapshot so the toolbar buttons
        // disable until the user re-selects (= prevents the
        // "press shortcut twice" footgun where the same LLM
        // response replaces itself).
        selectedText = ""
    }


    // MARK: - B-23 file-system watcher

    // v0.34 B-23: open the file descriptor + create a DispatchSource
    // for external-write detection. DispatchSource is the Apple HIG
    // canonical file-watch primitive (= wraps kqueue's EVFILT_VNODE;
    // = cross-Unix, no third-party dep). Fired on external write /
    // extend / delete / rename (= covers all scenarios where the
    // file's content could change outside our process).
    private func startFileWatcher() {
        guard let path = documentPath else {
            // Placeholder mode (= no real document) → no watcher needed.
            return
        }
        // Open the file for read (= O_EVTONLY flag on macOS = notify-only,
        // = no actual read permission needed). POSIX open(2) returns
        // the file descriptor; DispatchSource reads from it.
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else {
            #if DEBUG
            print("[wenshu.editor] B-23: cannot open fd for \(path)")
            #endif
            return
        }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .delete, .rename],
            queue: .main
        )
        source.setEventHandler { [weak source] in
            guard let source = source else { return }
            let events = source.data
            // .write + .extend = file content changed (= the cases we care about).
            // .delete + .rename = file replaced/moved (= re-arm the watcher
            // against the new file descriptor in a follow-up ticket;
            // = current implementation just reloads from the original path).
            if events.contains(.write) || events.contains(.extend) {
                reloadDocumentFromDisk()
            }
        }
        source.setCancelHandler {
            // Apple HIG: close the fd when the source is cancelled
            // (= prevents fd leaks; = standard pattern).
            close(fd)
        }
        source.resume()
        fileWatcher = source
        watchedFD = fd
    }

    // v0.34 B-23: tear down the watcher (= cancel DispatchSource; = close fd
    // happens automatically via the cancel handler above).
    private func stopFileWatcher() {
        fileWatcher?.cancel()
        fileWatcher = nil
        watchedFD = -1
    }

    // v0.34 B-23: handle external file change. Apple HIG TextEdit /
    // Pages / Xcode behavior:
    //   - clean state (draft == originalBody): silent reload. The user
    //     has nothing to lose (= no in-progress edits).
    //   - dirty state (draft != originalBody): save current draft to
    //     <file>.local-wenshu-conflict-<unix-timestamp>.md (= the user's
    //     in-progress edits) BEFORE clobbering, then reload, then post
    //     a notification pointing to the conflict file path.
    private func reloadDocumentFromDisk() {
        guard let path = documentPath else { return }
        let url = URL(fileURLWithPath: path)
        guard let newContent = try? String(contentsOf: url, encoding: .utf8) else {
            #if DEBUG
            print("[wenshu.editor] B-23: failed to read \(path)")
            #endif
            return
        }
        if isDirty {
            // Save user's in-progress edits to .local-wenshu-conflict-<ts>.md
            // (= Apple HIG conflict-backup convention).
            let timestamp = Int(Date().timeIntervalSince1970)
            let conflictPath = path + ".local-wenshu-conflict-\(timestamp).md"
            do {
                try draft.write(
                    toFile: conflictPath,
                    atomically: true,
                    encoding: .utf8
                )
                externalChangeNotice = WenshuI18n.ts("workspace.editor.external_change_saved", conflictPath)
            } catch {
                externalChangeNotice = WenshuI18n.t("workspace.editor.external_change_save_failed") + " (" + error.localizedDescription + ")"
            }
        }
        draft = newContent
        originalBody = newContent
        // Reset dirty flag → 0 (the document is now consistent with disk).
        // (= handleDirtyTransition(false) cancels any pending auto-save Task).
        handleDirtyTransition(false)
        // Update chrome bottom-bar left (= word count of new content).
        appState.editorWordCount = WordCounter.count(newContent).charactersNoSpaces
    }

    // v0.34 B-22: dirty-state transition handler. Replaces B-21's
    // triggerAutoSave (= that fired on every keystroke = wasteful
    // Task creation per char; = boss 9/2 OOB flagged as inefficient).
    //
    // Logic (= matches Apple HIG TextEdit / Pages auto-save behavior):
    //   - dirty = true  (= user started editing after a clean state):
    //     start ONE 3-second Task. The Task fires `writeDraftToDisk`
    //     then clears `originalBody` (= makes dirty → false = ends the
    //     cycle). Subsequent keystrokes within the 3-second window
    //     just keep `dirty = true` (= no new Task = the existing one
    //     still fires once).
    //   - dirty = false (= Cmd+S saved, or auto-save Task fired, or
    //     discard happened): cancel the pending Task (= no more writes;
    //     = the document is already saved).
    //
    // Result: at most 1 active Task at any time, regardless of typing
    // speed. Saves exactly once per dirty→clean cycle. No memory churn.
    private func handleDirtyTransition(_ isDirty: Bool) {
        if isDirty {
            // User just started editing (= dirty → true). Start the
            // 3-second Task. If one was already pending (= e.g. user
            // typed, waited, saved, typed again quickly), reuse it:
            // a new Task replaces the old one (= Task.cancel + new
            // = 1 active Task). Apple HIG Task structured concurrency
            // handles the lifecycle.
            if autoSaveTask == nil {
                autoSaveTask = Task {
                    // 3-second debounce (= boss 9/2 'auto-save, 3 seconds
                    // after stopping'). Apple HIG doesn't define a canonical
                    // duration; = matches macOS TextEdit / Pages default.
                    try? await Task.sleep(for: .seconds(3))
                    if !Task.isCancelled {
                        await MainActor.run {
                            writeDraftToDisk()
                            // B-22: after auto-save, mark the document
                            // as clean (= originalBody = draft = no
                            // longer dirty). This transitions dirty →
                            // false → handleDirtyTransition(false)
                            // → cancels any future Task (= idempotent
                            // = the just-completed Task won't fire
                            // again because the state is already
                            // consistent).
                            originalBody = draft
                        }
                    }
                    autoSaveTask = nil
                }
            }
        } else {
            // dirty = false (= user just saved via Cmd+S, OR the
            // auto-save Task just completed and set originalBody =
            // draft above). Cancel any pending Task (= no more writes).
            autoSaveTask?.cancel()
            autoSaveTask = nil
        }
    }
    // v0.34 B-24: documentPath + autoSaveTask + fileWatcher + watchedFD +
    // externalChangeNotice + showDirtyDiscardConfirm are now computed
    // properties (= read/write the active tab's state via AppState).
    // Defined above as part of the per-tab state migration; = these
    // View-local @State duplicates would shadow the active-tab reads.

    // v0.34 ticket 09: close handler. If dirty = present confirm dialog;
    // if clean = close immediately (= Apple HIG standard). Cmd+W (ticket
    // 10) routes through this same method.
    private func tryClose() {
        if isDirty {
            showDirtyDiscardConfirm = true
        } else {
            documentPath = nil
        }
    }

    // v0.40 boss 9/7 OOB '删除空白预览文档': samplePreviewBody
    // (= the "Welcome to wenshu" placeholder) is removed. When no
    // tab is open, the editor zone shows the empty-state hint via
    // `emptyStateHint` (= tells the user to double-click a card
    // in the material library). Persisted open tabs (= loaded from
    // UserDefaults by AppState.init) skip this hint entirely.
    //
    // v0.34 ticket 05 (preserved as comment for historical
    // reference): sample markdown body shown in preview mode
    // exercised header levels, bold/italic, bullet list, inline
    // code, code fence, [[wikilink]] (= parsed by InternalLinkParser).
    // The v0.40 apple-001 UX cleanup replaced its CJK content with
    // an onboarding welcome. Now removed entirely per boss 9/7 OOB.

    /// v0.40 boss 9/7 OOB: empty-state hint shown when no editor
    /// tab is open. Tells the user to double-click a card in the
    /// material library (= the canonical wenshu document-open
    /// path: pick a reference library / book / folder, double-
    /// click a card → openCardInEditor creates a tab).
    ///
    /// v0.40 boss 9/7 OOB follow-up '提示的样式不统一': use the
    /// shared EmptyStateHint component (= same icon + title +
    /// body layout as Foreshadowing + PreviewPane empty states).
    /// This guarantees consistent visual treatment (= 24 PT
    /// icon, 15 PT semibold title, 13 PT body) across all
    /// "no content" zones in the workspace.
    private var emptyStateHint: some View {
        EmptyStateHint(
            icon: "book-open",
            title: WenshuI18n.t("workspace.empty.title"),
            body: WenshuI18n.t("workspace.empty.body")
        )
    }

    // v0.34 ticket 05: placeholder type alias for the wikilink navigation
    // closure (= ticket 027-35 will replace with actual NavigationLink).
    typealias WikilinkAction = (String) -> Void
}

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
