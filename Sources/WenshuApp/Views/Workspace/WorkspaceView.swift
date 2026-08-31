// WorkspaceView.swift · Wenshu (文枢) · v0.27 ticket 027-34
//
// SwiftUI host for the user-customizable workspace. Wraps the
// WorkspaceStore and renders the pane tree via PaneRenderer.
//
// This file = the WorkspaceView (root container) and the renderTab
// dispatcher (= maps TabKind -> existing wenshu view). The recursive
// pane rendering lives in PaneRenderer.swift (= ticket 027-35).
//
// Atomic-coupling with PaneRenderer.swift (= ticket 027-35):
// WorkspaceView delegates the pane tree rendering to PaneRenderer;
// = without PaneRenderer, WorkspaceView has no body. Per boss 8/22
// '1 commit / 1 file; multi-file requires atomic justification':
// shipped in a single commit with PaneRenderer.

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

    /// v0.30 boss 8/31 OOB: JSON-encoded sidebar selection for
    /// AppStorage. Empty string = no selection (= first-launch state).
    @AppStorage("wenshu.sidebarSelection") private var persistedSidebarSelection: String = ""

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
        // v0.28 ticket 028-004 (= this commit): WorkspaceView now
        // delegates to PaneRenderer (= recursive split-tree renderer
        // for the v2 schema from ticket 028-003). The legacy flat-
        // array rendering (= v0.27 LayoutShellView 6-zone shape)
        // is removed; v2 = the only path. The WorkspaceView body
        // is now a thin shim that hands off to PaneRenderer.
        PaneRenderer(
            node: store.workspace.root,
            store: store
        )
            // v0.30 boss 8/31 OOB '默认 app 进来是, 选定的是退出时的
            // 目录': restore sidebar selection from AppStorage on
            // first appear (= empty storage = no selection = default
            // empty state). Done here (= WorkspaceView root) so it
            // runs once per WiredShell lifetime.
            .onAppear {
                if appState.sidebarSelection == nil,
                   !persistedSidebarSelection.isEmpty,
                   let data = persistedSidebarSelection.data(using: .utf8),
                   let item = try? JSONDecoder().decode(
                    SidebarItem.self, from: data
                   ) {
                    appState.sidebarSelection = item
                }
            }
            // v0.30 boss 8/31 OOB: every selection change writes back
            // to AppStorage (= so close + reopen restores state).
            .onChange(of: appState.sidebarSelection) { _, newValue in
                if let item = newValue,
                   let data = try? JSONEncoder().encode(item),
                   let json = String(data: data, encoding: .utf8) {
                    persistedSidebarSelection = json
                } else {
                    persistedSidebarSelection = ""
                }
            }
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
    /// `TabKind` (= PaneRenderer's TabContentDispatcher only knows
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
                ("编辑", "book-open-text", AnyView(EditorContentPlaceholder())),
                ("大纲", "puzzle", AnyView(EditorContentPlaceholder())),
                ("反链", "link", AnyView(EditorContentPlaceholder())),
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
    /// remain after the PaneRenderer refactor, but downstream
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
                    ("编辑", "book-open-text", AnyView(EditorContentPlaceholder())),
                    ("大纲", "puzzle", AnyView(OutlinePanel())),
                    ("反链", "link", AnyView(BacklinksPanel())),
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
/// State + snapshot lives in LayoutShellView (= ticket 029a).
private struct EditorExpandShrinkTrailingButton: View {
    @State private var editorMaximized: Bool = false

    var body: some View {
        Button {
            editorMaximized.toggle()
        } label: {
            Color.clear
                .frame(width: LayoutTokens.chatTabHotArea, height: LayoutTokens.chatTabHotArea)
                .overlay(alignment: .center) {
                    // Lucide icon swap: 'expand' when not maximized,
                    // 'shrink' when maximized (= per boss spec).
                    if let lucide = Lucide(editorMaximized ? "shrink" : "expand") {
                        lucide
                            .aspectRatio(contentMode: .fit)
                            .frame(width: LayoutTokens.iconSize, height: LayoutTokens.iconSize)
                            .foregroundStyle(Color.secondary)
                    } else {
                        Image(systemName: editorMaximized ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .aspectRatio(contentMode: .fit)
                            .frame(width: LayoutTokens.iconSize, height: LayoutTokens.iconSize)
                            .foregroundStyle(Color.secondary)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(editorMaximized ? "恢复 (shrink)" : "展开 (expand)")
    }
}

/// EditorPlaceholder — temporary view for the editor zone (= the real
/// EditorView integration is ticket 027-35 followup).
struct EditorPlaceholder: View {
    var body: some View {
        VStack {
            Text("编辑器").font(.headline)
            Text("Editor zone (= v0.27 zone; = ticket 027-35 integration pending)")
                .font(.caption).foregroundStyle(.secondary)
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
                    .font(.system(size: 11, weight: .medium))
                Text(HotkeyFormatter.editModeCombo)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
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
                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
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


/// v0.30 boss 8/31 OOB: sort menu button rendered in the preview
/// pane's tab bar trailing slot. Layout = [sort rule text dim] +
/// [list-ordered icon tint] (= icon居右 within the button). No
/// chevron-down (= the icon IS the dropdown affordance).
private struct PreviewSortMenuButton: View {
    @Binding var sortOrder: EntitySortOrder

    var body: some View {
        Menu {
            ForEach(EntitySortOrder.allCases) { order in
                Button {
                    sortOrder = order
                } label: {
                    Label {
                        Text(order.rawValue)
                    } icon: {
                        LucideIcon(order.menuIcon, size: 14)
                    }
                    if order == sortOrder {
                        Image(systemName: "checkmark")
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(sortOrder.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LucideIcon(sortOrder.menuIcon, size: 16)
                    .foregroundStyle(.tint)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.accentColor.opacity(0.08))
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .help("排序方式: \(sortOrder.rawValue)")
    }
}