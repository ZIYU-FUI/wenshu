// WorkspaceView.swift · Wenshu (文枢) · v0.27 ticket 027-34
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

/// WorkspaceView — the customizable-layout root (= the Xcode-paradigm
/// replacement for LayoutShellView). Boss 2026-08-27 grill D1 chose
/// this paradigm over the FCP / Hermes alternatives.
///
/// Boss 2026-08-27 standing goal: '重构落地'. This view is the
/// production (= only) rendering path since v0.30. The v0.27
/// LayoutShellView legacy path was removed in v0.30 (= 1310 lines
/// deleted per boss 8/31 OOB '老六区没有用了，数据无用已经过期的代码，
/// 去人无误后，可以清干净').
struct WorkspaceView: View {
    @ObservedObject var store: WorkspaceStore

    /// v0.30 boss OOB: 实体分类在目录树里是最后一层, 点击后, 实体文档
    /// 要用随心记的卡片流样式显示在素材管理区 (= projectPreview).
    /// Tracks which entity category is currently selected in the sidebar
    /// (= nil = overview mode showing all entities).
    @State private var selectedEntityCategory: EntityCategory? = nil

    /// v0.30: tracks which entity card is currently being viewed in
    /// detail mode (= single card with full .md body).
    @State private var selectedEntity: Reference? = nil

    /// v0.30 boss 8/31 OOB '各区域之间的联动' (= option A = global
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
            // maps to emptyState(message: "选中书查看文档") in
            // PreviewPane.shelfScopeView.) Previously this mapped
            // to .empty (= "请选择左侧目录查看文档") which the spec
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
            // v0.30 boss 2026-09-01 OOB fix: the View menu's "恢复默认
            // 布局" item (= ⌘⇧R; both the SwiftUI Commands entry
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
            // '看一下项目管理区的位置, Y 轴位置和素材管理区好像没对齐'
            // = sidebar's top chrome (= "书架" tab + 新建/入驻 buttons
            // inside NewLibraryOutlineView) was at a different Y than
            // Preview/Editor/Tools (= which use ZoneContentView with
            // RegionTabBar = 30 PT tall)). Fix = wrap NewLibraryOutlineView
            // in ZoneContentView (= 1 "书架" tab + trailing 新建/入驻
            // buttons via zoneHeaderButtons). Now sidebar uses the same
            // canonical 30 PT RegionTabBar as the other 3 general
            // panes (= identical Y position for all 4 top tab bars).
            //
            // NewLibraryOutlineView still needs to be inside the tab
            // content slot (not above/around the tab bar) so its tree
            // outline is the "书架" tab's content.
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
            // '顶栏底栏都对不齐' = Preview/Tools were using old
            // ZoneModuleView (= renders BOTH outer ZoneTopToolbar 30 PT
            // + internal ZoneContentView tab bar 30 PT = DOUBLE chrome
            // = 60 PT total, while Sidebar/Editor use only ZoneContentView
            // = 30 PT SINGLE chrome). Y 错位 = 30 PT difference.
            // Fix = convert Preview/Tools to use ZoneContentView directly
            // (= single 30 PT chrome layer = matches Sidebar/Editor).
            //
            // The Preview/Tools' ZoneContentView uses tabs from
            // projectPreviewChrome/specializedToolsChrome (= top actions
            // list), with the actual content view (CanvasView/BaseView
            // for Tools, GraphView for Preview) as the tab's body.
            //
            // v0.30 boss 8/31 OOB '点 sidebar row → 右边素材区正常显示
            // 目录下的文档，控制目录范围': PreviewPane is wired here
            // (= the active WorkspaceView body) with the computed
            // `previewScope` (= driven by sidebarSelection). The tab
            // "图" stays on GraphView placeholder for future graph
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
                    onEntityDoubleClick: { entity in
                        // v0.30 Ticket 3 hook: open in editor.
                        // For now: just print; Ticket 3 will wire this
                        // to editor zone + replace EditorContentPlaceholder.
                        NSLog("WorkspaceView.PreviewPane: double-click entity %@", entity.title)
                    },
                    previewSortOrder: $previewSortOrder
                ))),
                ("图", "waypoints", AnyView(GraphView())),
            ], trailingButton: AnyView(
                // v0.30 boss 8/31 OOB: '排序 ICON 放到顶栏里, 居右,
                // ▼ 替换成 list-ordered icon'. The sort menu button
                // shows [sort rule text (dim)] + [list-ordered icon
                // (tint)] = icon居右 within the trailing button.
                PreviewSortMenuButton(sortOrder: $previewSortOrder)
            ))
        case .editor:
            // v0.28 followup Boss UX round 43: switch from
            // EditorPlaceholder (= text-only) to real ZoneContentView
            // (= 3 tabs 编辑/大纲/反链 + trailing expand/shrink).
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
            // v0.29 boss 2026-08-30 OOB '替换, 用伏笔替换第一个 teb,
            // 用占位替换第二个 teb. 现在的画布功能以后实现':
            // - Replaced tab 1 '画布' (scribble) with '伏笔'
            //   (git-fork = matches the 伏笔 folder icon in sidebar).
            // - Replaced tab 2 '数据库' (tablecells) with '占位符'
            //   (square-dashed = matches the 占位符 folder icon in sidebar).
            // - Both new tabs use placeholder views (= ForeshadowingView +
            //   PlaceholderView) = actual content lands in v0.30+
            //   (per the v0.28 batch 2 ticket 04 M4 ForeshadowingGraph
            //   service + M4 placeholder scanner).
            // - CanvasView + BaseView files KEPT (= not deleted, just
            //   not wired into tools pane) per ComponentIndex.md
            //   'unused components' pattern (= ready to be re-wired
            //   later when boss implements the canvas feature).
            ZoneContentView(zoneSlug: "specializedTools", tabs: [
                ("伏笔", "git-fork", AnyView(ForeshadowingView())),
                ("占位符", "square-dashed", AnyView(PlaceholderView())),
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
// App.swift:2060-2220). The OLD 6区 had a 3-layer chrome per zone:
// 1. ZoneTopToolbar (30 PT) with zone actions (Graph / Search / expand
//    trailing etc.). This layer is now an outer RegionPerRegionChrome.
// 2. ZoneContentView (internal tab bar with ZoneContentTabBar)
//    — Apple HIG canonical tab bar (= 28×28 hot area + Lucide icon +
//    selected indicator underline + matchedGeometryEffect animation).
//    Each zone has 1-N internal tabs (= e.g. editor has 3: 编辑/大纲/反链).
// 3. ZoneBottomToolbar (30 PT) with per-zone status text (书架数 / 章节数
//    / 字数 / 工具就绪 / 看板). Also now an outer ZonePerRegionChrome.
//
// The v0.27 `ZoneModule` had a single case that built the full
// content view (= ZoneContentView for 4 general zones, ChatZoneView
// for chat, DynamicZoneView for dynamic). This struct re-implements
// that case-by-case dispatch using the actual ZoneContentView /
// ChatView / DynamicZoneView (= the real tabbed views, not
// placeholders). Boss 2026-08-29 OOB '原来的 teb 在当前框架下是不
// 是有默认样式' = yes — every zone has a ZoneContentTabBar with
// Lucide icons + accent underline + selected state. Per Boss
// '完全不是 1:1' OOB, this commit restores 1:1 match by replacing
// the placeholder text views with the real tabbed zone views.
//
// Per v0.27 boss 8/27 OOB #3: projectSidebar zone has `trailingButton`
// (= NewLibraryOutlineView's zoneHeaderButtons = 新建 + 入驻 icon buttons).
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

    /// v0.30 boss 8/31 OOB '各区域之间的联动' (= option A):
    /// AppState is the global @Observable source of truth.
    /// ZoneModuleView reads it directly (= no @Binding chain).
    @Environment(AppState.self) private var appState

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
            // 老 6区 projectSidebar = 1 tab (书架, with book-open icon)
            // + trailingButton (新建 + 入驻 = NewLibraryOutlineView.zoneHeaderButtons).
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
            // 老 6区 projectPreview = 2 tabs (预览 / 图).
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
                    onEntityDoubleClick: { entity in
                        // v0.30 Ticket 3 hook: open in editor.
                        // For now: just print; Ticket 3 will wire this
                        // to editor zone + replace EditorContentPlaceholder.
                        NSLog("ZoneModuleView.PreviewPane: double-click entity %@", entity.title)
                    },
                    previewSortOrder: .constant(.pinyinFirstLetter)
                ))),
                ("图", "waypoints", AnyView(GraphView())),
            ])

        case .specializedTools:
            // 老 6区 specializedTools = 2 tabs (伏笔 / 占位符 per
            // v0.29 boss 2026-08-30 OOB; was 画布 / 数据库 in v0.28).
            ZoneContentView(zoneSlug: "specializedTools", tabs: [
                ("伏笔", "git-fork", AnyView(ForeshadowingView())),
                ("占位符", "square-dashed", AnyView(PlaceholderView())),
            ])

        case .aiDynamic:
            // 老 6区 aiDynamic = DynamicZoneView (= has its own
            // DynamicZoneTabBar with 进度 / 待办 / 搜索).
            // Per v0.24 boss 8/24 OOB: external toolbar 清空 (= the
            // outer ZoneTopToolbar is empty placeholder mode).
            DynamicZoneView()

        case .aiChat:
            // 老 6区 aiChat = ChatZoneView (= has its own ChatZoneTabBar
            // with chat / search / settings). Per v0.25.1 ticket 005:
            // top icons are Bot + Inbox.
            ChatView()

        case .editor:
            // 老 6区 editor = 3 tabs (编辑 / 大纲 / 反链) + trailingButton
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
                    // v0.34 B-16: removed the "反链" tab here (= boss 9/2 OOB
                    // '反链占的区域还是要去掉的'). Backlinks are now
                    // surfaced via the chrome bottom-right "反链 0"
                    // label click → popover (= spec user stories 8 + 11).
                ],
                // v0.25.1 (= ticket 029c-trailing-button): expand/shrink
                // trailing button. Boss 8/26 OOB '他是一个按钮 不是一个
                // teb' = won't be a tab (= no selected underline), just
                // a button at the right edge of the tab bar.
                trailingButton: AnyView(
                    EditorExpandShrinkTrailingButton()
                )
            )
        }
    }
}

/// Editor main content placeholder (= replaces old DesignColor overlay).
/// Real editor content view = ticket 027-35 followup; for now we
/// render a subtle placeholder background matching the old 6区
/// "Color.white.opacity(0.55) with 4 PT vertical inset" treatment.
// v0.28 followup Boss UX round 21: .regularMaterial replaces the
/// DesignColor.zoneSurface (= solid) so the placeholder matches the
/// Liquid Glass design language used everywhere else.
// v0.28 followup Boss UX round 31 (Boss 2026-08-29 OOB '素材预览区,
// 动态区, 这个区的液态玻璃效果和其他区不一样'): uses
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
        // "编辑器因为背景是白色? 所有亮度看起来不一样"). Now the
        // editor placeholder is just empty (= the background is
        // now applied uniformly by ZonePerRegionChrome).
        Color.clear
    }
}


/// Editor expand/shrink trailing button (= old v0.25.1 ticket 029c).
/// Per boss 8/26 OOB '点击后 整个编辑器最大化 其它所有栏全都隐藏
/// 此时 ICON 变成 shrink 点击后 恢复到刚刚点击 expand 前的状态'.
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
    // BEFORE the 5 zone-hide animator calls (= Q38 boss "全状态 snapshot"
    // decision; restore-on-shrink must read this JSON).
    @AppStorage("wenshu.editorMaximized") private var editorMaximized: Bool = false
    @AppStorage("wenshu.editorExpand.snapshot") private var editorExpandSnapshotJSON: String = "{}"

    var body: some View {
        // v0.34 boss 2026-09-02 OOB '编辑器右边的 ICON, 尺寸没有遵循组件':
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
        // ChatZoneTopChrome. Replaced both with the shared
        // PaneTrailingIconButton helper. EditorExpandShrinkTrailingButton
        // now retains only the icon-toggle state (= editorMaximized) and
        // the tooltip string (= editorMaximized ? "恢复布局" : "展开全屏").
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
    /// Editor zone display mode (= spec user stories 2-4).
    /// `.preview` = rendered MD, read-only (= Obsidian preview).
    /// `.edit` = TextEditor, writeable (= Obsidian edit).
    /// v0.34 ticket 04: enum lives here; ticket 05 replaces the body
    /// content with swift-markdown rendering, ticket 07 replaces with
    /// Apple TextEditor.
    enum Mode: String, CaseIterable, Identifiable {
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

    @State private var mode: Mode = .preview

    var body: some View {
        VStack(spacing: 0) {
            // v0.34 ticket 04: top toolbar (= 28 PT = DesignTokens.paneTabHotArea).
            // v0.34 ticket 08: full layout per spec Implementation Decision E:
            //   [doc basename (left)] [mode toggle (center)] [save + expand + close (right)]
            // Tool bar persists across both preview and edit modes (= Apple HIG
            // document-window toolbar pattern; Obsidian uses the same shape).
            HStack(spacing: DesignTokens.chromePaddingClusterGap) {
                // v0.34 ticket 08: left slot = doc basename placeholder.
                // Today = static text (= preview sample name); ticket
                // 027-35 will pass the real document basename from NSOpenPanel.
                Text("preview-sample.md")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                // Center slot: mode toggle (= ticket 04 + v0.34 ticket 10
                // Cmd+E hotkey via .keyboardShortcut).
                Spacer()
                PaneTrailingIconButton(
                    icon: mode.iconName,
                    tooltip: mode.tooltip,
                    action: {
                        mode = (mode == .preview) ? .edit : .preview
                    }
                )
                .keyboardShortcut("e", modifiers: .command)  // v0.34 ticket 10
                // v0.34 ticket 08: right slot = save + expand + close.
                //   - Save button: only in .edit mode; .tint when dirty (gray otherwise).
                //   - Expand button: ticket 03 (EditorExpandShrinkTrailingButton).
                //   - Close button: ticket 09 (placeholder for now, no action).
                Spacer()
                // Save button visible only in edit mode (= Apple HIG
                // convention = no save affordance when there's nothing to save).
                if mode == .edit {
                    PaneTrailingIconButton(
                        icon: "square.and.arrow.down",
                        tooltip: isDirty ? "保存 (有未保存的修改)" : "已保存",
                        action: { saveDraft() }
                    )
                    // Apple HIG tint: when dirty, swap foreground from
                    // .secondary (= default for trailing buttons) to .tint
                    // (= Apple HIG accent color, signals action affordance).
                    .foregroundStyle(isDirty ? Color.accentColor : Color.secondary)
                    .keyboardShortcut("s", modifiers: .command)  // v0.34 ticket 10: Cmd+S
                }
                // v0.34 ticket 10: Cmd+Shift+E for editor expand toggle.
                // Routes through .wenshuEditorMaximizedChanged (= same
                // listener installed by ticket 03).
                PaneTrailingIconButton(
                    icon: "rectangle.expand.vertical",
                    tooltip: "展开/收起编辑器区",
                    action: {
                        NotificationCenter.default.post(
                            name: .wenshuEditorMaximizedChanged,
                            object: true  // ticket 03 button is one-way expand;
                                          // shrink path is the inverse toggle
                        )
                    }
                )
                .keyboardShortcut("e", modifiers: [.command, .shift])  // v0.34 ticket 10
                PaneTrailingIconButton(
                    icon: "xmark",
                    tooltip: "关闭编辑器 (Cmd+W)",
                    action: { tryClose() }
                )
                .keyboardShortcut("w", modifiers: .command)  // v0.34 ticket 10: Cmd+W
            }
            .padding(.horizontal, DesignTokens.chromePaddingLeading)
            .frame(height: DesignTokens.paneTabHotArea)
            .background(.bar)
            // v0.34 ticket 09: dirty-discard confirm dialog. Shown when
            // user tries to close with unsaved changes. Apple HIG
            // 2-option confirm pattern (= destructive + cancel).
            .alert("未保存的更改将丢失", isPresented: $showDirtyDiscardConfirm) {
                Button("放弃编辑", role: .destructive) {
                    // Discard: clear draft + reset to originalBody + close.
                    // Today = no-op beyond resetting state (= ticket 027-35
                    // wires real document close).
                    draft = originalBody
                    documentPath = nil
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
                if mode == .preview {
                    EditorPreviewContent(
                        markdownBody: Self.samplePreviewBody,
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
                    EditorEditContent(
                        draft: $draft,
                        originalBody: originalBody,
                        onSave: { saveDraft() }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // v0.28 followup Boss UX round 19 (Boss 2026-08-29 OOB '所有
            // 区域的顶栏, 底栏, 背景, 用的颜色, 可以适配液态玻璃吗'):
            // Use .ultraThinMaterial instead of Color.green.opacity(0.05)
            // (= solid green placeholder = inconsistent with the
            // Liquid Glass design language). Editor zone has no
            // wired-in content yet (= ticket 027-35 followup), so use the
            // lightest Liquid Glass material as a placeholder that
            // matches the rest of the workspace.
            .background(.ultraThinMaterial)
        }
    }

    // v0.34 ticket 07: edit-mode state owner. Both fields initialise from
    // the sample preview body (= placeholder until ticket 027-35 wires
    // the real document load). dirty = draft != originalBody (= ticket
    // 08 reads this for the Save button's .tint highlight).
    @State private var draft: String = EditorPlaceholder.samplePreviewBody
    @State private var originalBody: String = EditorPlaceholder.samplePreviewBody
    /// Computed dirty flag (= ticket 08 reads this for the Save
    /// button's .tint highlight). Plain computed (= not @State,
    // = re-evaluated on each render from draft + originalBody).
    private var isDirty: Bool { draft != originalBody }
    // v0.34 ticket 07: save action writes draft back over originalBody;
    // Cmd+S hotkey (ticket 10) calls this directly. mtime-conflict
    // detection (= v0.35+ ticket; placeholder for now).
    private func saveDraft() {
        originalBody = draft
    }
    // v0.34 ticket 09: document-loaded flag. nil = placeholder mode
    // (= "select document then expand" hint visible). Non-nil = a
    // document is open. Today = nil (= placeholder until ticket 027-35
    // wires real document load).
    @State private var documentPath: String? = nil
    // v0.34 ticket 09: alert state for dirty-confirm dialog. Shows
    // when user tries to close while isDirty. Reset on dialog dismiss.
    @State private var showDirtyDiscardConfirm: Bool = false
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
        // Divider + backlinksVM state (= boss 9/2 OOB '反链那 120
        // 高度的空间还在, 不用在编辑器里占空间'). Backlinks are
        // surfaced via the chrome bottom-right "反链 0" popover
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
            .help("Open: \(target)")
        }
    }
}

/// EditorEditContent (= ticket 07): Apple SwiftUI TextEditor wrapper for
/// edit mode. The host (EditorPlaceholder) owns the draft state + save
/// logic; this view is the rendering surface only. Apple HIG TextEditor
/// (= Rule 7 system component) provides standard macOS text editing
/// behaviors for free: undo, find, accessibility, IME.
///
/// Spec user stories covered:
///   US-6 (Edit mode = Apple SwiftUI TextEditor, HIG standard)
///   US-7 (Save button highlights when dirty, = .tint on draft != original)
///   US-8 (Close button placeholder; see ticket 09)
///   US-13 (no custom NSTextView wrapper = Apple standard)
///   US-22 (character-level dirty detection)
private struct EditorEditContent: View {
    @Binding var draft: String
    let originalBody: String
    let onSave: () -> Void

    /// Read-only dirty flag (= computed from the binding's current value).
    private var isDirty: Bool { draft != originalBody }

    var body: some View {
        // Apple HIG TextEditor (= no NSTextView wrapper per Rule 7).
        // Native font = .body (= one of Apple's 11 standard text styles
        // per Iron Rule 2; = Apple HIG default = 13 PT on macOS). User
        // enlarges system font size → text scales automatically (= Apple
        // HIG standard).
        // .padding(DesignTokens.chromePaddingMedium = 12 PT) gives
        // Apple HIG standard inner margin for bordered content rows
        // (= chat input / picker rows pattern; matches Rule 6 no-magic-
        // numbers rule by routing through DesignTokens instead of
        // inline `.padding(12)`).
        TextEditor(text: $draft)
            .font(.body)
            .padding(DesignTokens.chromePaddingMedium)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Dirty status surfaced to the host via the `onSave` closure
            // (= not strictly needed by TextEditor itself; the host reads
            // `draft` and `originalBody` to decide dirty highlighting
            // on the Save button at ticket 08). Kept here so future
            // status-bar additions (= line count, dirty indicator)
            // have a clear anchor.
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
// v0.28 followup Boss UX round 42 (Boss 2026-08-29 OOB '缺三个区,
// 项目管理, 工具, 聊天, 都没进你的样式表'): REMOVED the inline
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
