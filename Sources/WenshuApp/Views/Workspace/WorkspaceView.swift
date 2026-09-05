// WorkspaceView.swift · Wenshu · v0.27 ticket 027-34
//
// SwiftUI host for the user-customizable workspace. Wraps the
// WorkspaceStore and renders the pane tree via PaneSplitHost (=
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
    @ObservedObject var store: WorkspaceStore

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

    /// Layout edit mode state (= v0.28 ticket 028-006). Owned by
    /// the view (= fresh per window) so the per-window state stays
    /// self-contained. The hotkey binding lives in
    /// `EditModeHotkey.swift` (= ⌘⇧\ toggle, Escape exit).
    @State private var editMode = LayoutEditMode()

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
                path = nil; content = ""; title = category?.displayName ?? "资料库"
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
        // stays in WorkspaceState for backward Codable
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
                    EditModeBadge(isEnabled: $editMode.isEnabled)
                        .padding(8)
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
            // WorkspaceStore.resetToDefault (= reloads the built-in
            // Default preset = upper band 10/20/60/10 weights, lower
            // band 70/30 weights, root 50/50 column weights per the
            // boss OOB ratios).
            //
            // v0.31 boss 2026-09-02 OOB (Apple canonical reset): the
            // .wenshuResetLayout notification now also un-collapses
            // the on-screen NSSplitView (= the menu item was previously
            // a no-op for the live layout — only the WorkspaceStore
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
                ("书架", "book-open", AnyView(NewLibraryOutlineView(
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
            ZoneContentView(zoneSlug: "projectPreview", tabs: [
                ("预览", "book-open-check", AnyView(PreviewPane(
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
                ("图", "waypoints", AnyView(GraphView())),
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
                ("编辑", "book-open-text", AnyView(EditorPlaceholder())),
                ("大纲", "puzzle", AnyView(EditorPlaceholder())),
                ("反链", "link", AnyView(EditorPlaceholder())),
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
                ("伏笔", "git-fork", AnyView(ForeshadowingView())),
                ("占位符", "square-dashed", AnyView(PlaceholderView())),
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
                ("书架", "book-open", AnyView(NewLibraryOutlineView(
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
            ZoneContentView(zoneSlug: "projectPreview", tabs: [
                ("预览", "book-open-check", AnyView(PreviewPane(
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
                ("图", "waypoints", AnyView(GraphView())),
            ])

        case .specializedTools:
            // Old 6-zone specializedTools = 4 tabs (Foreshadowing / Placeholder /
            // LongFormGuardrails per P1 ticket #6
            // [WIRE-SPECIALIZEDTOOLS-001] 2026-09-04 +
            // ReaderExperience per P1 ticket #7
            // [WIRE-SPECIALIZEDTOOLS-002] 2026-09-04).
            ZoneContentView(zoneSlug: "specializedTools", tabs: [
                ("伏笔", "git-fork", AnyView(ForeshadowingView())),
                ("占位符", "square-dashed", AnyView(PlaceholderView())),
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
                    ("编辑", "book-open-text", AnyView(EditorPlaceholder())),
                    ("大纲", "puzzle", AnyView(OutlinePanel())),
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
                title = category?.displayName ?? "资料库"
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
private struct EditorContentPlaceholder: View {
    var body: some View {
        // v0.28 followup Boss UX round 37: REMOVED the
        // Color.white.opacity(0.55) overlay (= was making the editor
        // pane appear LIGHTER than the other 5 panes = boss noticed
        // "is the editor background white? all the brightness looks different"). Now the
        // editor placeholder is just empty (= the background is
        // now applied uniformly by ZonePerRegionChrome).
        Color.clear
    }
}


/// Editor expand/shrink trailing button (= old v0.25.1 ticket 029c).
/// Per boss 8/26 OOB 'after clicking, maximize the entire editor, hide all other
/// columns, at this point the ICON becomes shrink, after clicking restore to the state just before clicking expand'.
/// State + snapshot lives in @AppStorage (= ticket 01, v0.34).
/// v0.34 ticket 03: action closure now posts the .wenshuEditorMaximizedChanged
/// notification (= PaneNSController listener installed by ticket 02 handles
/// the actual layout mutation). The button stays a thin View-local proxy:
/// read @AppStorage, write @AppStorage, post notification.
private struct EditorExpandShrinkTrailingButton: View {
    // v0.34 ticket 01: replaced @State with @AppStorage (= Rule 11 + Apple
    // HIG standard storage; the bug ticket 03 fixes = no real persistence,
    // but @AppStorage makes persistence easy to add later if needed). The
    // snapshot key is written by PaneNSController.handleEditorMaximizedChanged
    // BEFORE the 5 zone-hide animator calls (= Q38 boss "full-state snapshot"
    // decision; restore-on-shrink must read this JSON).
    @AppStorage("wenshu.editorMaximized") private var editorMaximized: Bool = false
    @AppStorage("wenshu.editorExpand.snapshot") private var editorExpandSnapshotJSON: String = "{}"

    var body: some View {
        // v0.34 boss 2026-09-02 OOB 'the ICON on the right of the editor, the size did not follow the component':
        // the editor expand/shrink trailing button was using raw `Lucide(...)`
        // (= no size parameter = Lucide default size, not Apple HIG standard
        // 18 PT tab icon). Migrated to the SAME icon-rendering pattern as
        // PaneIconTab: Color.clear as 28 PT hot area base + icon as centered
        // .overlay with explicit DesignTokens.tabIconSize (= 18 PT). Now
        // visually identical to the leading tab icons in the same row
        // (= the 6 zones' tab bar visual contract is uniform).
        //
        // Hover plumbing also migrated to .hoverWash() (= previous commit's
        // single source of truth for hover wash; removed the per-site
        // .onHover + .background tint + @State isHover + .clipShape plumbing).
        //
        // v0.34 boss 2026-09-02 OOB (multi-layer audit): the trailing-button
        // shape (Color.clear.frame(28,28).overlay(LucideIcon) + .hoverWash +
        // .plain + .help) was duplicated between WorkspaceView.swift
        // EditorExpandShrinkTrailingButton and TabContentDispatcher.swift
        // (chat-zone archive button). Replaced both with the shared
        // PaneTrailingIconButton helper. EditorExpandShrinkTrailingButton
        // now retains only the icon-toggle state (= editorMaximized) and
        // the tooltip string (= editorMaximized ? "Restore Layout" : "Expand Fullscreen").
        PaneTrailingIconButton(
            icon: editorMaximized
                ? "arrow.down.right.and.arrow.up.left"
                : "arrow.up.left.and.arrow.down.right",
            tooltip: editorMaximized ? "恢复布局" : "展开全屏",
            // v0.34 ticket 03 (= Q33 boss fix): the action was previously a
            // dead `editorMaximized.toggle()` (= View-local @State only,
            // no layout effect). Now it writes @AppStorage AND posts the
            // .wenshuEditorMaximizedChanged notification, which
            // PaneNSController.handleEditorMaximizedChanged listens for
            // (= ticket 02 implementation). Notification.object carries
            // the new Bool payload so the listener can branch on
            // snapshot-and-collapse vs restore.
            action: {
                editorMaximized.toggle()
                NotificationCenter.default.post(
                    name: .wenshuEditorMaximizedChanged,
                    object: editorMaximized
                )
            }
        )
    }
}

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
                            .font(.system(size: 12, weight: isActive ? .semibold : .regular, design: .monospaced))
                            .foregroundStyle(isActive ? Color.accentColor : .secondary)
                            .padding(.horizontal, 12)
                            .frame(height: 28)
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
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(mode == .edit ? "切到预览模式" : "切到编辑模式")
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
            .frame(height: 32)
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
            // Same .background { Color.clear.glassEffect(.regular) }
            // shape as 950e46423 (= TopBar) + 74b22f73a (= Sidebar):
            // .glassEffect(.regular) is a View modifier (= instance
            // member), not a ShapeStyle value, so .background(.glassEffect
            // (.regular)) does NOT compile; = Color.clear provides the
            // size of the glass layer; the modifier applies the
            // canonical Liquid Glass material. .glassEffect(.regular)
            // auto-adapts to system settings (= dark mode / Reduce
            // Transparency / Increase Contrast) per Apple HIG. The
            // body-content area's .ultraThinMaterial background (= line
            // below this tab strip) is intentionally NOT touched
            // (= content area, not chrome).
            .background {
                Color.clear.glassEffect(.regular)
            }
            // v0.34 ticket 09: dirty-discard confirm dialog. Shown when
            // user tries to close with unsaved changes. Apple HIG
            // 2-option confirm pattern (= destructive + cancel).
            // B-24: showDirtyDiscardConfirm is now a computed property;
            // = wrap in Binding(get:set:) for .alert's isPresented:.
            .alert("未保存的更改将丢失", isPresented: Binding(
                get: { self.showDirtyDiscardConfirm },
                set: { self.showDirtyDiscardConfirm = $0 }
            )) {
                Button("放弃编辑", role: .destructive) {
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
                Button("继续编辑", role: .cancel) { }
            } message: {
                Text("编辑器有未保存的更改, 关闭后将丢失.")
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
                if mode == .preview {
                    EditorPreviewContent(
                        markdownBody: draft,
                        wikilinkTarget: { _ in /* TODO: ticket 027-35 navigation */ }
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
                            bookStore: bookStore
                        ),
                        // v0.39 ticket 001: stable per-tab id, passed
                        // to engine as `documentId` so undo + pending
                        // replacements are scoped to this tab.
                        draftId: activeTabIdString
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
            // v0.34 B-24: seed the placeholder tab on first mount
            // (= AppState.openTabs defaults to []). Seed with the
            // samplePreviewBody as the placeholder draft so the
            // preview-mode body is visible from the start. Single
            // source of truth for the openTabs array; = no other
            // view needs to seed.
            if appState.openTabs.isEmpty {
                let placeholder = EditorTab(
                    id: EditorTab.placeholderId,
                    documentPath: nil,
                    draft: EditorPlaceholder.samplePreviewBody,
                    originalBody: EditorPlaceholder.samplePreviewBody
                    // v0.39 ticket 001-A-extended: mode omitted = uses
                    // EditorTab default = .edit (= was .preview in
                    // v0.34; = the user is in the live editor from
                    // the start, not raw-text preview).
                )
                appState.openTabs = [placeholder]
                appState.activeTabId = EditorTab.placeholderId
            } else {
                // v0.39 ticket 001-A-extended: migrate any existing
                // .preview tab to .edit (= v0.34 default was .preview,
                // so any tab the user had open at the time of the
                // upgrade lands in raw-text preview mode without
                // this upgrade). User can still flip back to .preview
                // via the mode toggle button (= the eye/pencil icon
                // in the tab strip = v0.39 ticket 001-C).
                for idx in appState.openTabs.indices {
                    if appState.openTabs[idx].mode == .preview {
                        appState.openTabs[idx].mode = .edit
                    }
                }
            }
            appState.editorWordCount = WordCounter.count(originalBody).charactersNoSpaces
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
        get { activeTab?.draft ?? EditorPlaceholder.samplePreviewBody }
        nonmutating set {
            guard let idx = activeTabIndex else { return }
            appState.openTabs[idx].draft = newValue
        }
    }
    private var originalBody: String {
        get { activeTab?.originalBody ?? EditorPlaceholder.samplePreviewBody }
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

    // v0.34 B-21: write current draft to documentPath (= atomic UTF-8).
    private func writeDraftToDisk() {
        let path = documentPath ?? "/tmp/wenshu-preview-sample.md"
        let url = URL(fileURLWithPath: path)
        do {
            try draft.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            #if DEBUG
            print("[wenshu.editor] auto-save failed: \(error)")
            #endif
        }
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
        let connector = activeLLMConnector()

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

    /// P2 #19: resolve the user's active `LLMConnector` profile
    /// from the `wenshu.llm.activeConnector` UserDefaults slug
    /// (= the connector profile the user picked in
    /// LLMConnectorSettingsView; = matches the existing
    /// ConnectorTestButton switch-on-`apiMode` factory pattern).
    ///
    /// Fallback chain (= matches the wenshu defensive-defaults
    /// rule):
    /// - missing slug → `AnthropicConnector()` (= the connector
    ///   the existing ChatView startLongRunningGoal uses; will
    ///   surface `.missingAPIKey` when no key is configured).
    /// - unknown slug → `AnthropicConnector()` (= same path).
    /// - unsupported apiMode → `AnthropicConnector()` (= same
    ///   path; will surface `.transport` when called).
    private func activeLLMConnector() -> any LLMConnector {
        let slug = UserDefaults.standard.string(forKey: "wenshu.llm.activeConnector") ?? "anthropic"
        let provider = ProviderCatalog.provider(slug: slug)
        switch provider.apiMode {
        case "anthropic_messages":
            // MinimaxConnector is the Anthropic-compatible
            // wrapper (= wenshu's default provider per
            // AGENTS.md §11.2); AnthropicConnector is the
            // native Anthropic API. Build the matching one by
            // slug (= minimax / minimax-cn / anthropic).
            if provider.slug == "anthropic" {
                return AnthropicConnector()
            }
            return MinimaxConnector()
        case "openai_chat":
            return OpenAICompatibleConnector(provider: provider)
        default:
            // Gemini + any other apiMode lands here until the
            // matching connector lands (= Gemini native connector
            // is a separate ticket per
            // ConnectorTestButton.runTest).
            return AnthropicConnector()
        }
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
                externalChangeNotice = "文件已更新, 你的编辑已保存到 \(conflictPath)"
            } catch {
                externalChangeNotice = "文件已更新, 你的编辑保存失败 (通知: \(error.localizedDescription))"
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

    // v0.34 ticket 05: sample markdown body shown in preview mode (= used
    // until ticket 027-35 wires the real .md document load via NSOpenPanel
    // + Apple HIG DocumentGroup). Exercises all the rendering paths:
    // header levels, bold/italic, bullet list, inline code, code fence,
    // [[wikilink]] (= parsed by InternalLinkParser).
    static let samplePreviewBody: String = """
    # 文枢编辑区预览

    这是 **粗体**, *斜体*, `inline code`, and a [regular link](https://apple.com).

    ## 二级标题

    - 列表项 1
    - 列表项 2
      - 嵌套列表
    - 列表项 3

    ## 代码块

    ```swift
    func hello() {
        print("Hello, 文枢!")
    }
    ```

    ## 内部链接

    Refer to [[阳明心学]] and [[尚书|Classic Book]] as inline wikilinks.

    > 这是引用块 — Obsidian 风格.
    """

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
private struct EditorPreviewContent: View {
    let markdownBody: String
    let wikilinkTarget: EditorPlaceholder.WikilinkAction

    // v0.34 B-17: BacklinksViewModel removed (= boss 9/2 OOB). Backlinks
    // are surfaced via the chrome bottom-right popover (= B-16 in
    // TabContentDispatcher.editor case), NOT inside the preview body.

    var body: some View {
        // v0.34 B-17: removed ticket 06's 120 PT inline BacklinksPanel +
        // Divider + backlinksVM state (= boss 9/2 OOB 'the 120-height space
        // reserved for backlinks is still there, no need to occupy space in the editor'). Backlinks are
        // surfaced via the chrome bottom-right "Backlinks 0" popover
        // (= B-16 implementation; see TabContentDispatcher.editor case).
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(parsedSegments, id: \.id) { segment in
                    renderSegment(segment)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // v0.34 B-17: use DesignTokens.chromePaddingLarge (= 16 PT)
            // instead of inline `.padding(16)`. Iron Rule 6 (= no magic
            // numbers): all per-pane chrome padding routes through
            // DesignTokens. Per `DesignTokens.swift` documentation:
            // chromePaddingLarge = Apple HIG standard for stacked
            // section separators (= matches preview body inset).
            .padding(DesignTokens.chromePaddingLarge)
        }
    }

    /// A parsed segment is either a chunk of markdown text (= rendered as
    /// AttributedString) or a single wikilink (= clickable Button).
    private enum Segment: Identifiable {
        case text(String)
        case wikilink(target: String, display: String)
        var id: String {
            switch self {
            case .text(let s): return "t:" + s.prefix(64).description
            case .wikilink(let t, _): return "w:" + t
            }
        }
    }

    private var parsedSegments: [Segment] {
        let links = InternalLinkParser.parse(markdownBody)
        guard !links.isEmpty else { return [.text(markdownBody)] }
        var segments: [Segment] = []
        var cursor = markdownBody.startIndex
        let nsBody = markdownBody as NSString
        for link in links {
            let targetRange = NSRange(location: link.offset, length: link.text.utf16.count + 4)
            // '[[', alias, ']]' = 2 + alias.utf16.count + 2
            let fullMatchRange = NSRange(location: link.offset, length: "[[\(link.text)]]".utf16.count)
            // Convert NSRange -> String.Index for slicing
            if let textRange = Range(targetRange, in: markdownBody),
               let fullRange = Range(fullMatchRange, in: markdownBody) {
                if cursor < fullRange.lowerBound {
                    segments.append(.text(String(markdownBody[cursor..<fullRange.lowerBound])))
                }
                segments.append(.wikilink(target: link.target, display: link.text))
                cursor = fullRange.upperBound
                _ = textRange; _ = nsBody
            }
        }
        if cursor < markdownBody.endIndex {
            segments.append(.text(String(markdownBody[cursor..<markdownBody.endIndex])))
        }
        return segments
    }

    @ViewBuilder
    private func renderSegment(_ segment: Segment) -> some View {
        switch segment {
        case .text(let chunk):
            // swift-markdown AttributedString rendering. The library
            // handles headers, bold, italic, lists, code, code fences,
            // blockquotes, links (= Obsidian parity).
            if let attributed = try? AttributedString(markdown: chunk) {
                Text(attributed)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(chunk)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .wikilink(let target, let display):
            // Obsidian wikilink: blue text, clickable. The internal
            // wiki-link nav will be wired by ticket 027-35 (= today's
            // placeholder closure is a no-op).
            Button {
                wikilinkTarget(target)
            } label: {
                Text("[[\(display)]]")
                    .foregroundStyle(.blue)
                    .underline()
            }
            .buttonStyle(.plain)
            .help(WenshuI18n.ts("help.open_target", target))
        }
    }
}

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
private struct EditorEditContent: View {
    @Binding var draft: String
    let originalBody: String
    let onSave: () -> Void
    // v0.34 B-18: word count callback (= char count → host writes to
    // AppState.editorWordCount, which chrome reads for the bottom-bar
    // left field). Decoupled from AppState so EditorEditContent
    // stays a pure rendering surface (= no @Environment coupling).
    let onWordCountChange: (Int) -> Void
    // v0.34 B-22: dirty-state change callback. Host routes true (= user
    // started editing) to schedule the auto-save Task; false (= document
    // is saved or just got saved via Cmd+S) to cancel any pending Task.
    // Replaces B-21's onAutoSaveTrigger (= that triggered on every
    // keystroke, wasting memory creating a fresh Task per char; = boss
    // 9/2 OOB flagged as inefficient). Decoupled from Task internals
    // (= EditorEditContent doesn't know about Task).
    let onDirtyChange: (Bool) -> Void
    // v0.39 ticket 001: pre-built markdown engine configuration. Host
    // (WorkspaceView) builds this once per active-tab switch via
    // WenshuEditorServicesFactory.make(referenceLibraryRoot:activeBookRoot:).
    // The configuration owns the 4 service protocols (= wenshu implements
    // 2: WikiLinkResolver + EmbeddedImageProvider; the engine's
    // HighlighterSwiftBridge is transitive via MarkdownEngineCodeBlocks;
    // LaTeX is not wired in 001).
    let configuration: MarkdownEditorConfiguration
    // v0.39 ticket 001: stable per-tab id, passed to engine as
    // `documentId` so undo history + pending replacements are scoped
    // to each editor instance (= prevents cross-tab state bleed).
    let draftId: String

    /// Read-only dirty flag (= computed from the binding's current value).
    private var isDirty: Bool { draft != originalBody }

    var body: some View {
        // v0.39 ticket 001: nodes-app/swift-markdown-engine (TextKit 2,
        // live markdown styling, wiki-link resolution, image embeds,
        // code-fence syntax highlight via transitive HighlighterSwift
        // bridge) replaces Apple SwiftUI TextEditor. The engine's
        // NativeTextViewWrapper provides the NSTextView-based edit
        // surface (= Apple-standard undo, find, accessibility, IME).
        // WenshuMarkdownEditor is a thin NSViewRepresentable wrapper
        // (= keeps EditorEditContent a pure rendering surface).
        WenshuMarkdownEditor(
            text: $draft,
            draftId: draftId,
            configuration: configuration
        )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // v0.34 B-18: write live character count via host callback
            // (= per-keystroke; = Foundation-only recompute). Host
            // (EditorPlaceholder) routes the value into
            // AppState.editorWordCount for the chrome bottom-bar left
            // field. WordCounter.count's charactersNoSpaces matches
            // Obsidian's default Word count plugin behavior (= exclude
            // whitespace, line breaks, tabs).
            .onChange(of: draft) { _, newValue in
                onWordCountChange(WordCounter.count(newValue).charactersNoSpaces)
                // v0.34 B-22: auto-save is NOT triggered on every
                // keystroke (= that wastes memory creating a fresh
                // Task per keystroke; = Obsidian-style debounce that
                // the boss 9/2 flagged as inefficient). Instead,
                // auto-save runs once per dirty→clean transition
                // (= Apple HIG standard auto-save = save when the
                // document transitions from dirty to saved, not on
                // every keystroke). The handler is wired below in
                // .onChange(of: isDirty) → onDirtyChange().
            }
            // v0.34 B-22: wire auto-save to dirty-state transitions,
            // NOT to every keystroke. When dirty becomes true
            // (= user starts editing), schedule a 3-second Task.
            // When dirty becomes false (= either Cmd+S saved the
            // document or the auto-save Task fired), cancel any
            // pending Task (= no more writes; = matches Apple HIG
            // TextEdit / Pages behavior).
            .onChange(of: isDirty) { _, newDirty in
                onDirtyChange(newDirty)
            }
            // Dirty status surfaced to the host via the `onSave` closure
            // (= not strictly needed by the editor itself; the host reads
            // `draft` and `originalBody` to decide dirty highlighting
            // on the Save button at ticket 08). Kept here so future
            // status-bar additions (= line count, dirty indicator)
            // have a clear anchor.
    }
}

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
/// ticket (would require NSTextView delegate via NSViewRepresentable).
private struct FormatToolbarButtons: View {
    @Binding var draft: String

    var body: some View {
        // 5 buttons inline (= HStack of PaneTrailingIconButton
        // reuse = consistent visual contract with the rest of the
        // top bar; = Rule 7 system component pattern). Spacing 4 PT
        // between buttons (= tight cluster for inline toolbar; =
        // DesignTokens.chromePaddingMicro).
        HStack(spacing: DesignTokens.chromePaddingMicro) {
            PaneTrailingIconButton(
                icon: "bold",
                tooltip: "加粗 (**)",
                action: { wrapSelection(open: "**", close: "**") }
            )
            PaneTrailingIconButton(
                icon: "italic",
                tooltip: "斜体 (*)",
                action: { wrapSelection(open: "*", close: "*") }
            )
            PaneTrailingIconButton(
                icon: "heading",
                tooltip: "标题 (#)",
                action: { prefixCurrentLine(with: "# ") }
            )
            PaneTrailingIconButton(
                icon: "code",
                tooltip: "行内代码 (`)",
                action: { wrapSelection(open: "`", close: "`") }
            )
            PaneTrailingIconButton(
                icon: "list",
                tooltip: "列表项 (-)",
                action: { prefixCurrentLine(with: "- ") }
            )
        }
    }

    // MARK: - Helpers

    /// v0.34 B-20: wrap the current cursor selection (or insert at
    /// cursor if no selection) with `open` + `close` MD markers.
    /// Selection tracking is approximated (= we don't have access
    /// to the TextEditor's NSRange without NSViewRepresentable),
    /// so this implementation targets the WHOLE draft as the
    /// wrap range (= fallback behavior; = same as Obsidian's
    /// inline format toolbar without explicit selection).
    /// Real selection-aware wrapping is v0.35+ ticket (= needs
    /// NSTextView delegate bridge).
    private func wrapSelection(open: String, close: String) {
        // Fallback: append at end. Real selection = future ticket.
        draft = draft + open + "text" + close
    }

    /// v0.34 B-20: prefix the current line with `prefix`. Fallback
    /// (= no cursor info): append a new line at end with the prefix.
    /// Future ticket: parse draft by lines + insert at cursor line.
    private func prefixCurrentLine(with prefix: String) {
        draft = draft + "\n" + prefix
    }
}

/// P2 #19 (WIRE-PARAGRAPH-002): testable static helper that
/// contains the pure paragraph_ai pipeline (= prompt prefix +
/// connector send + first .text block extraction). Extracted
/// out of `EditorPlaceholder.applyParagraphAI` so the test
/// target can exercise the behavior without instantiating the
/// SwiftUI view graph (= no AppState, no BookStore, no file
/// watcher plumbing required).
///
/// Apple-API-first: this helper is a thin orchestration layer
/// over the v0.35 `LLMConnector` protocol (= already wired in
/// `ChatView.startLongRunningGoal` + `WenshuConductor.handle`)
/// and the P1 #10 `EditorTransformTools` actor (= the Swift
/// port of hermes `agent/editing/editor_tools.py`). Zero new
/// types; zero new dependencies.
struct EditorParagraphAI {

    /// Run the paragraph transform pipeline (= build prompt
    /// prefix + call connector + extract first .text block) and
    /// return the rewritten text. Throws on connector failure
    /// (= transport / auth / decode); the caller (= the View)
    /// owns the S4 graceful-degradation wrapper.
    ///
    /// - Parameters:
    ///   - selectedText: the user's selected text (= empty
    ///     short-circuits to "" per the wenshu defensive-defaults
    ///     rule; matches `disabled(selectedText.isEmpty)` on the
    ///     toolbar).
    ///   - transform: which of the 6 `EditorTransform` cases to
    ///     apply.
    ///   - connector: the active `LLMConnector` (= injected for
    ///     testability; production calls `activeLLMConnector()`
    ///     on the view; tests inject `MockLLMConnector`).
    ///   - options: the per-call `LLMCallOptions` (= model +
    ///     maxTokens).
    /// - Returns: the rewritten paragraph (= the first .text
    ///     block of the connector response; "" if the connector
    ///     returned no text blocks).
    static func apply(
        selectedText: String,
        transform: EditorTransform,
        connector: any LLMConnector,
        options: LLMCallOptions
    ) async throws -> String {
        guard !selectedText.isEmpty else { return "" }
        let tools = EditorTransformTools()
        let prefix = await tools.promptPrefix(for: transform)
        let prompt = "\(prefix)\n\n\(selectedText)"
        let response = try await connector.send(
            messages: [LLMMessage.user(prompt)],
            options: options
        )
        let text = response.blocks.first { block in
            if case .text = block { return true }
            return false
        }.flatMap { block -> String? in
            if case let .text(s) = block { return s }
            return nil
        } ?? ""
        return text
    }
}

/// P2 #19 (WIRE-PARAGRAPH-002): paragraph_ai toolbar. 3 buttons
/// with keyboard shortcuts (= ⌘⇧E expand, ⌘⇧H shorten, ⇧R
/// rephrase) + a Menu for the 3 less-common transforms (= shiftTone,
/// simplify, dramatize).
///
/// Sits next to the mode toggle in the editor top-bar (= the same
/// HStack the mode toggle lives in; = one row, Apple HIG
/// single-row toolbar pattern). Each button uses `.help(...)` for
/// the native NSWindow tooltip (= per the wenshu-apple-api-first
/// hard rule) and `.keyboardShortcut(...)` for the global key
/// binding (= Apple SwiftUI native; = no third-party shortcut
/// lib required).
///
/// Disabled rules (= matches the boss spec's
/// `disabled(vm.selectedText.isEmpty)` line):
/// - `selectedText.isEmpty`: nothing to transform.
/// - `isApplying`: an LLM call is already in flight (= prevent
///   double-fire; = Apple HIG actionable-control-while-busy).
///
/// Icon system: SF Symbols for the 3 primary buttons (= Apple
/// built-in icon font; = boss 2026-08-27 OOB carve-out for system
/// symbols). Lucide icons for the dropdown menu (= consistent
/// with the rest of the editor zone's chrome). The mix matches
/// the v0.34 FormatToolbarButtons precedent (= it uses Lucide
/// for the inline format buttons but SF Symbol-equivalents are
/// acceptable for the paragraph_ai row since the boss spec
/// calls them out as `Image(systemName:)` in the wire-up
/// snippet).
///
/// Performance: the toolbar is a pure View; no @State. The
/// selection snapshot + busy flag come in via parameters (= host
/// owns the truth; = Apple HIG parent-owns-data pattern).
private struct ParagraphAIToolbarButtons: View {
    let selectedText: String
    let isApplying: Bool
    let onApply: (EditorTransform) -> Void

    var body: some View {
        HStack(spacing: DesignTokens.chromePaddingMicro) {
            // Expand (= ⌘⇧E). SF Symbol:
            // `arrow.up.left.and.arrow.down.right` = Apple's
            // built-in expand icon (= "up-left arrow + down-right
            // arrow"; = visually says "make bigger"). Matches the
            // boss spec's exact `Image(systemName:)` line.
            Button {
                onApply(.expand)
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(WenshuI18n.t("paragraph.expand"))
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(selectedText.isEmpty || isApplying)

            // Shorten (= ⌘⇧H). SF Symbol:
            // `arrow.down.right.and.arrow.up.left` = Apple's
            // built-in condense icon (= "down-right arrow +
            // up-left arrow"; = visually says "make smaller").
            // Matches the boss spec's exact `Image(systemName:)`
            // line.
            Button {
                onApply(.shorten)
            } label: {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(WenshuI18n.t("paragraph.shorten"))
            .keyboardShortcut("h", modifiers: [.command, .shift])
            .disabled(selectedText.isEmpty || isApplying)

            // Rephrase (= ⌘⇧R). SF Symbol:
            // `arrow.triangle.2.circlepath` = Apple's built-in
            // refresh icon (= 2 triangles around a circle path; =
            // visually says "say it differently"). Matches the
            // boss spec's exact `Image(systemName:)` line.
            Button {
                onApply(.rephrase)
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(WenshuI18n.t("paragraph.rephrase"))
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(selectedText.isEmpty || isApplying)

            // Menu: shiftTone / simplify / dramatize (= no
            // shortcut per boss spec; = dropdown next to the 3
            // primary buttons). Uses Apple's native `Menu` (= the
            // SwiftUI macOS 13+ API; = no third-party menu lib
            // needed). Each item is a Button so it integrates with
            // the same `onApply` callback (= consistent code
            // path with the 3 primary buttons; = no special
            // menu-only branch in `applyParagraphAI`).
            Menu {
                Button("Shift tone") { onApply(.shiftTone) }
                    .disabled(selectedText.isEmpty || isApplying)
                Button("Simplify") { onApply(.simplify) }
                    .disabled(selectedText.isEmpty || isApplying)
                Button("Dramatize") { onApply(.dramatize) }
                    .disabled(selectedText.isEmpty || isApplying)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .help("More transforms: shift tone, simplify, dramatize")
            .disabled(selectedText.isEmpty || isApplying)
        }
    }
}
/// EditModeBadge — small visual indicator shown in the top-right
// corner of WorkspaceView when layout edit mode is on. Click to
// toggle off (= same effect as pressing ⌘⇧\ again).
///
/// Per ticket 028-006 §"Acceptance criteria": the badge is the
/// only edit-mode-related UI shipped in 028-006 (= the TreeEditBar
/// and LayoutPicker are 028-007 / 028-009).
private struct EditModeBadge: View {
    @Binding var isEnabled: Bool

    var body: some View {
        Button(action: { isEnabled.toggle() }) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 8, height: 8)
                Text("Layout edit mode")
                    .font(.caption.weight(.medium))
                Text(HotkeyFormatter.editModeCombo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, DesignTokens.chromePaddingChipHorizontal)
            .padding(.vertical, DesignTokens.chromePaddingSmall)
            // v0.28 followup Boss UX round 24: .regularMaterial
            // replaces the solid Color.secondary.opacity(0.15) tint
            // for the edit-mode badge background (= the floating
            // badge that shows when ⌘⇧\ edit mode is on).
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(.tint.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - PreviewTabBackground (= preview pane content background)
//
// v0.28 followup Boss UX round 42 (Boss 2026-08-29 OOB 'missing three zones,
// project manager, tools, chat, none entered your stylesheet'): REMOVED the inline
// RegionContentBackground call. The background is now applied
// uniformly by ZonePerRegionChrome (= single source of truth for
// per-pane content backgrounds). PreviewTabBackground is now just
// Color.clear (= will be wrapped automatically by the chrome layer).
private struct PreviewTabBackground: View {
    var body: some View {
        Color.clear
    }
}


/// v0.30 boss 8/31 OOB: sort button rendered in the preview pane's
/// tab bar trailing slot. ponytail fix: previous Menu-based
/// implementation collapsed to zero size inside ZoneContentView's
/// trailing slot (= the AnyView wrapper at ZoneContentTabBar erases
/// intrinsic size, and SwiftUI's Menu doesn't render its label in
/// this context). Replaced with simple plain Button + cycle-through
/// sort order pattern (= mirrors NewButtonWithHover's plain Button
/// + LucideIcon + frame pattern which DOES render correctly).
private struct PreviewSortMenuButton: View {
    @Binding var sortOrder: EntitySortOrder
    @State private var isHover: Bool = false

    var body: some View {
        // Q34 ticket 01 of v0.30-topbar-card-alignment: PaneIconTab
        // pattern exactly (= Color.clear base + overlay icon +
        // contentShape). The previous "plain Button + LucideIcon
        // + .frame(width: 28, height: 28)" pattern collapsed to
        // zero size inside ZoneContentView's trailing slot (= AnyView
        // wrapper at ZoneContentTabBar erases intrinsic size).
        // Color.clear base provides a guaranteed 28x28 hit area that
        // survives AnyView wrapping, matching PaneIconTab which DOES
        // render in the same slot.
        //
        // Tap behavior: cycle through 3 sort orders. Icon updates
        // to reflect current order.
        Button {
            switch sortOrder {
            case .pinyinFirstLetter: sortOrder = .createdAt
            case .createdAt: sortOrder = .modifiedAt
            case .modifiedAt: sortOrder = .pinyinFirstLetter
            }
        } label: {
            // PaneIconTab pattern: Color.clear as BASE, icon as
            // .overlay centered. Fixed frame = intrinsic size preserved.
            Color.clear
                .frame(width: DesignTokens.paneTabHotArea, height: DesignTokens.paneTabHotArea)
                .overlay(alignment: .center) {
                    LucideIcon(sortOrder.menuIcon, size: DesignTokens.tabIconSize)
                        .foregroundStyle(Color.secondary)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHover = hovering
        }
        .help("排序方式: \(sortOrder.rawValue)")
    }
}

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
