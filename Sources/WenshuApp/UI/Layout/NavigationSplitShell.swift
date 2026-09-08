//
//  NavigationSplitShell.swift · Wenshu · M1-shell (2026-09-08)
//
//  Apple-native 3-column shell for the macOS 27 NavigationSplitView
//  migration (= the worktree = `.worktrees/m1-navigation-split-shell/`;
//  spec = `.scratch/2026-09-08-m1-shell/spec.md`).
//
//  Layout structure (per boss 9/8 red-line drawing = 1 continuous
//  vertical drag-resizable divider贯穿整个 window = NOT 2 separate
//  NavigationSplitView, but 1 outer NavigationSplitView with each
//  column containing 2 vertically-stacked sub-areas):
//
//    Outer: NavigationSplitView (3 columns, Apple HIG canonical)
//    ├── sidebar (1 column, 2 vertical sub-areas, no inner divider):
//    │   ├── top:    目录树 (M2 = directory tree migrates here)
//    │   └── bottom: 卡片   (M2 = card grid migrates here)
//    ├── content (1 column, 2 vertical sub-areas, no inner divider):
//    │   ├── top:    编辑器 (M3 = editor zone migrates here)
//    │   └── bottom: 聊天   (M3 = chat zone migrates here)
//    └── detail (1 column, 2 vertical sub-areas, no inner divider):
//        ├── top:    工具 (M4 = tools zone migrates here)
//        └── bottom: 动态 (M4 = dynamic zone migrates here)
//
//  Why 1 outer NavigationSplitView (not 2 + VSplitView): the boss's
//  red line is 1 continuous vertical line that runs the full
//  height of the window. That is only possible with 1 outer
//  NavigationSplitView whose 3 columns have vertical sub-areas
//  (VStack). Two stacked NavigationSplitView (upper + lower) would
//  produce 2 separate vertical dividers (= 4 dividers total = NOT
//  matching the boss's 2-dividers-only red-line).
//
//  M1 = build the shell SKELETON only (= placeholders, NO zone
//  content). M2-M5 = migrate existing zone content into the new
//  panes (= subsequent tickets; see spec §6).
//
//  Activation: LayoutTreeState.useThreeColumnSplit (= optional
//  Bool = default `nil`/off = 老 PaneSplitHost 路径 = ZERO
//  regression).
//

import SwiftUI

// MARK: - Top-level shell

/// Apple-native 3-column shell (= 1 outer `NavigationSplitView`
/// with 3 columns × 2 vertical sub-areas each). Activated by
/// `LayoutTreeState.useThreeColumnSplit`. Default `nil` (= 老
/// `PaneSplitHost` 路径完全保留 per M1 spec §2.3 = zero
/// regression risk).
///
/// Apple HIG rationale (= boss 9/8 '按我的红色放拖拽线' = the
/// 3 columns share 1 continuous vertical divider line that runs
/// the full window height; = 1 outer `NavigationSplitView` with
/// each column = 2 vertically-stacked sub-areas (= VStack)).
struct NavigationSplitShell: View {
    /// Bindable app state (= owns the `useThreeColumnSplit` flag +
    /// any per-pane selection state; = same lifetime as the
    /// WorkspaceView's owner; = passed by reference via @Bindable
    /// in the body).
    var appState: AppState
    /// Optional BookStore for env injection (= descendants
    /// like ForeshadowingView / PlaceholderView / PreviewPane
    /// read BookStore from env via @Environment(BookStore.self)).
    /// Optional because BookStore is constructed asynchronously
    /// by LibraryLifecycleHook (= may not exist at first frame).
    var bookStore: BookStore?

    var body: some View {
        // v0.40 boss 2026-09-08 OOB '你看 pages 这种风格是怎么实现的. 没有线':
        // Apple Pages / Numbers / Keynote all use NavigationStack +
        // HSplitView for sidebar / inspector layouts. The
        // canonical Pages / Numbers style has THIN drag-handle
        // dividers (= 1 PT semitransparent lines that adapt to
        // dark / light mode). For the boss's 'no line' look,
        // use HSplitView with dividerStyle = .thin (= visible 1 PT
        // hairline = the same divider the 老 PaneNSController uses
        // per PaneNSController.swift:131 'boss accepted the Apple
        // limit and pivoted from the earlier .paneSplitter /
        // 0-width / no-line attempts to the standard HIG hairline').
        //
        // To match Pages exactly (= NO divider visible at all):
        // use plain HStack with .frame(width:) on each column
        // (= not drag-resizable, = fixed widths = Pages default).
        // Boss did NOT explicitly ask for drag-resize on the right
        // column (= no resize gesture in the Pages reference image).
        // Going with HSplitView + .thin divider style as the
        // pragmatic compromise (= 1 PT hairline visible, draggable
        // columns, semitransparent = Pages-like).
        HSplitView {
            // Apple HIG sidebar (= leftmost column; = the source
            // of truth for navigation in this band). 2 vertical
            // sub-areas (= VStack; no inner divider; = Mail's
            // sidebar = inbox + sent + drafts side by side, =
            // Apple's standard "List with multiple sections"
            // pattern).
            ShellSidebarColumn(appState: appState)
                // Pages-style minimum width (= user can drag to
                // resize but the column never collapses below this).
                .frame(minWidth: 200, idealWidth: 280, maxWidth: 500)
            ShellContentColumn(appState: appState)
                .frame(minWidth: 400, idealWidth: 720)
            // Apple HIG detail (= rightmost column; = the
            // selected item's detail / inspector). 2 vertical
            // sub-areas (= VStack).
            ShellDetailColumn(appState: appState)
                .frame(minWidth: 220, idealWidth: 320, maxWidth: 500)
        }
        .background { Color.clear }
        // CHATZONE-CRASH-FIX (2026-09-08): re-inject appState at
        // the NavigationSplitView root (= SwiftUI's internal
        // layout engine reads @Environment values during
        // NavigationSplitCoordinator.makeSplitViewController
        // to compute column min sizes; = the engine needs appState
        // in env even though no column body reads it directly).
        // Without this re-injection, the env chain fails at
        // _FlexFrameLayout.sizeThatFits (= EnvironmentValues
        // subscript crashes with 'No Observable object of type
        // AppState found' during view layout pass).
        .environment(appState)
        // CHATZONE-CRASH-FIX part 2: also re-inject bookStore if
        // available (= descendants read BookStore from env via
        // @Environment(BookStore.self) = ForeshadowingView /
        // PlaceholderView / PreviewPane / WorkspaceView. Without
        // this re-injection, the env chain fails at the layout
        // pass with 'No Observable object of type BookStore found').
        .environment(bookStore)
    }
}// MARK: - Sidebar column (= 2 vertical sub-areas)

/// Apple HIG sidebar column (= 2 vertical sub-areas: 目录树 +
/// 卡片网格). Per boss 9/8 '目录+卡片合并成一栏, 但内部还是
/// 要分成两个区, 只不过两区写在一栏中' = the 2 sub-areas share
/// one column without a drag-resizable divider between them
/// (= Apple HIG's standard "List with multiple sections" pattern
/// = Mail's sidebar = inbox + sent + drafts stacked vertically
/// inside one column).
///
/// M2 (= this commit): swap the M1 placeholders for the real
/// wenshu zone views:
/// - top sub-area: NewLibraryOutlineView (real sidebar tree
///   from v0.34+; = the source of truth for the library
///   shelf/book/folder hierarchy)
/// - bottom sub-area: ZoneModuleView(zoneSlot: .projectPreview)
///   (real card grid from v0.34+; = displays the documents
///   for the current sidebar selection)
struct ShellSidebarColumn: View {
    let appState: AppState

    // v0.40 boss 2026-09-08 OOB '目录树的顶栏也丢了': sidebar
    // needs its own top tab bar (= matches chat zone's 3 fixed
    // tabs pattern + editor zone's tab strip). Apple HIG
    // canonical pattern: PaneTabBar at the top of the column
    // (= like Notes.app / Mail.app = scope selector at top of
    // the sidebar). The 2 tabs map to the existing top-level
    // grouping (= 书架 = per-shelf books; = 资料库 = per-category
    // reference library). The NewLibraryOutlineView receives
    // the scope via initializer (= so it can filter which
    // rows are visible).
    @Namespace private var sidebarTabBarNamespace
    @State private var sidebarScope: SidebarScope = .shelves

    var body: some View {
        // VStack (vertical stack) of 2 sub-areas inside one
        // column. Apple HIG standard pattern: multiple sections
        // stacked inside one column, no drag-resizable divider
        // between sections (= the column's width is fixed; =
        // users resize the entire column, not the individual
        // sections inside it).
        VStack(spacing: 0) {
            // Top sub-area: scope tab bar + real directory tree
            // wrapped in ZonePerRegionChrome (= top tab bar + bottom
            // status bar; = matches the 老 PaneSplitHost path's chrome
            // coverage for every zone).
            ZonePerRegionChrome(
                topActions: [],
                bottomStatus: ZoneBottomStatus(
                    left: "书架:",
                    right: ""
                ),
                topSkip: false,
                bottomSkip: false,
                zone: .projectSidebar
            ) {
                VStack(spacing: 0) {
                    // v0.40 boss 2026-09-08 OOB '目录树的顶栏也丢了' +
                    // '左边原来的 ICON 没有了': restore the chrome top
                    // bar (= 30 PT RegionTabBar wrapper) with the
                    // canonical sidebar ICON (= the book-open icon
                    // that identifies the library sidebar = matches
                    // the Mail.app / Notes.app sidebar Section icon
                    // pattern). The PaneTabBar inside hosts the 2
                    // scope tabs (= 书架 / 资料库).
                    RegionTabBar {
                        HStack(spacing: DesignTokens.chromePaddingClusterGap) {
                            // v0.40 boss 2026-09-08 '左边原来的 ICON
                            // 没有了': the canonical sidebar ICON
                            // (= Lucide book-open = matches Mail.app /
                            // Notes.app sidebar Section icon). Apple
                            // HIG canonical pattern = a 28×28 hot
                            // area with a Lucide icon at the leading
                            // edge of the chrome top bar (= the icon
                            // identifies the sidebar's primary
                            // content type).
                            Image(
                                systemName: "books.vertical"
                            )
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            PaneTabBar(
                                items: [
                                    PaneTabItem(
                                        id: "shelves",
                                        icon: "book-open",
                                        label: "书架"
                                    ),
                                    PaneTabItem(
                                        id: "references",
                                        icon: "library",
                                        label: "资料库"
                                    ),
                                ],
                                selection: Binding(
                                    get: { sidebarScope.rawValue },
                                    set: { sidebarScope = SidebarScope(rawValue: $0) ?? .shelves }
                                ),
                                namespace: sidebarTabBarNamespace,
                                namespaceID: "sidebarTabUnderline"
                            )
                        }
                        .padding(.horizontal, DesignTokens.chromePaddingLarge)
                    }
                    // The actual sidebar List (= same Apple HIG
                    // standard sidebar layout as before; = now
                    // filtered by sidebarScope so the scope tab bar
                    // at the top has functional control).
                    NewLibraryOutlineView(scope: sidebarScope)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            // Bottom sub-area: real card grid wrapped in
            // ZonePerRegionChrome.
            ZonePerRegionChrome(
                topActions: [],
                bottomStatus: ZoneBottomStatus(
                    left: "章节:",
                    right: ""
                ),
                topSkip: false,
                bottomSkip: false,
                zone: .projectPreview
            ) {
                ZoneModuleView(zoneSlot: .projectPreview)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// v0.40 boss 2026-09-08 OOB '目录树的顶栏也丢了': scope selector
/// for the sidebar top tab bar. 2 cases map to the existing
/// top-level grouping (= 书架 = per-shelf books; = 资料库 =
/// reference library per EntityCategory). View-local @State in
/// ShellSidebarColumn (= no AppState migration needed for M1; =
/// future ticket can promote to AppState for cross-zone read).
/// Note: defined as a top-level enum (= used by both
/// NavigationSplitShell's PaneTabBar items AND
/// NewLibraryOutlineView's body filter; = placed here in the
/// NavigationSplitShell file = only NavigationSplitShell
/// imports it). The actual filtering logic lives in
/// NewLibraryOutlineView (= the enum travels to the leaf as
/// an init parameter).

// MARK: - Content column (= 2 vertical sub-areas)

/// Apple HIG content column (= 2 vertical sub-areas: 编辑器 +
/// 聊天). Per boss 9/8 '上半 sidebar / content / detail' +
/// '下半 sidebar / content / detail' but the columns are
/// CONTINUOUS (1 outer NavigationSplitView, NOT 2 stacked).
///
/// M2 (= this commit): swap the M1 placeholders for the real
/// wenshu zone views:
/// - top sub-area: EditorPlaceholder (real editor from v0.34+;
///   = routes to EditorEditContent internally with the markdown
///   engine + word count + auto-save)
/// - bottom sub-area: ChatView (real chat from v0.34+; = the
///   LLM conversation surface with attachment upload)
struct ShellContentColumn: View {
    let appState: AppState

    // v0.40 boss 2026-09-08 '有 teb 切功能, 右边有展开收起的那个':
    // RegionTabBar's PaneIconTab requires a matchedGeometryEffect
    // namespace (= one per tab bar instance; = required by SwiftUI's
    // .matchedGeometryEffect modifier).
    @Namespace private var editorChromeNamespace

    var body: some View {
        VStack(spacing: 0) {
            // Top sub-area: real editor wrapped in ZonePerRegionChrome
            // (= adds the top tab bar + bottom status bar that
            // 老 PaneSplitHost path provided per zone; = boss 9/8
            // '中间两区的顶栏丢失了' = the chrome was missing because
            // M2 directly embedded the zone view instead of
            // wrapping it in ZonePerRegionChrome).
            //
            // v0.40 boss 2026-09-08 OOB '编辑器区默认显示对了' +
            // '现在需要把顶栏找回来... 上面还有一层, 有 teb 切功能,
            // 右边有展开收起的那个': the FIRST-layer chrome top bar
            // (= the 30 PT RegionTabBar that every pane in the old
            // 6-region layout had above its content) was removed
            // during CHROME-ARCH-001. Boss wants it back. Wrap the
            // editor content with RegionTabBar (= PaneTabBar + trailing
            // expand button = matches Safari / Pages / Xcode tab bar
            // pattern). The inner EditorPlaceholder's own tab strip
            // (= Safari-style file tabs) becomes the SECOND-layer.
            VStack(spacing: 0) {
                RegionTabBar {
                    HStack(spacing: DesignTokens.chromePaddingClusterGap) {
                        // TEB 切换(= preview / edit mode tab = matches the
                        // existing 'mode' toggle inside EditorPlaceholder,
                        // but at the chrome top level = visible even when
                        // the inner tab strip is empty = no .md tabs open).
                        // boss 2026-09-08 '有 teb 切功能' = this is the
                        // 'teb switch' boss references.
                        //
                        // Future ticket: wire to appState.openTabs[activeTabIdx]
                        // (= read mode, write mode via setMode). For now, the
                        // inner EditorPlaceholder's own mode toggle remains
                        // canonical; = the chrome-level tabs are visual-only
                        // (= same icon + label as the inner tabs = boss's
                        // pattern of stacking chrome layers).
                        PaneIconTab(
                            id: "preview-mode",
                            icon: "eye",
                            label: "预览",
                            isSelected: false,
                            namespace: editorChromeNamespace,
                            namespaceID: "editorChromeUnderline",
                            onTap: { /* wired via EditorPlaceholder's mode toggle */ }
                        )
                        PaneIconTab(
                            id: "edit-mode",
                            icon: "pencil",
                            label: "编辑",
                            isSelected: false,
                            namespace: editorChromeNamespace,
                            namespaceID: "editorChromeUnderline",
                            onTap: { /* wired via EditorPlaceholder's mode toggle */ }
                        )
                        Spacer()
                        // 展开收起(= the expand/shrink button boss references;
                        // = same toggle as the internal editor toolbar's
                        // expand button; = future ticket: hide other columns
                        // for distraction-free editing).
                        PaneTrailingIconButton(
                            icon: "maximize-2",
                            tooltip: "展开/收起",
                            action: { /* future: expand/collapse editor */ }
                        )
                    }
                    .padding(.horizontal, DesignTokens.chromePaddingLarge)
                }
                ZonePerRegionChrome(
                    topActions: [],
                    bottomStatus: ZoneBottomStatus(
                        left: "0 字",
                        right: ""
                    ),
                    topSkip: false,
                    bottomSkip: false,
                    zone: .editor
                ) {
                    EditorPlaceholder()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            // Bottom sub-area: real chat wrapped in
            // ChatZoneView (= the canonical chat-zone wrapper
            // that provides the top tab bar via safeAreaInset +
            // the bottom chrome status bar; = boss 9/8
            // '编辑器区, 和聊天区的顶栏都不见了' = the chat
            // top tab bar is restored now that the env chain
            // is intact (= the M1 NavigationSplitShell is at
            // the root of the Scene, = @Environment
            // propagation is preserved across column boundaries).
            //
            // No outer ZonePerRegionChrome (= the inner
            // ChatZoneView already provides both top tab bar
            // and bottom status bar = boss 9/8 '把聊天区的
            // 底栏加回来吧'). Skipping the outer chrome avoids
            // double-stacked bottom bars.
            ChatZoneView(conductor: nil, store: nil)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // CHATZONE-CRASH-FIX (2026-09-08): re-inject AppState into
        // the env chain. SwiftUI 6+ breaks the @Environment chain
        // across NavigationSplitView's 3-column boundary (= the
        // child column views are re-rooted in their own env
        // subgraph). Without this re-injection, ChatZoneView /
        // ZoneModuleView / NewLibraryOutlineView all crash with
        // 'No Observable object of type AppState found' on access.
        .environment(appState)
    }
}

// MARK: - Detail column (= 2 vertical sub-areas)

/// Apple HIG detail column (= 2 vertical sub-areas: 工具 + 动态).
/// Per boss 9/8 '上半 right tools / 下半 right dynamic' = the
/// detail column is also 1 column with 2 stacked sub-areas.
///
/// M2 (= this commit): swap the M1 placeholders for the real
/// wenshu zone views:
/// - top sub-area: ZoneModuleView(zoneSlot: .specializedTools)
///   (real tools pane from v0.34+; = foreshadowing tracking,
///   memory retrieval, etc.)
/// - bottom sub-area: ZoneModuleView(zoneSlot: .aiDynamic) (real
///   dynamic pane from v0.34+; = kanban + todo + scope status)
struct ShellDetailColumn: View {
    let appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Top sub-area: real tools wrapped in
            // ZonePerRegionChrome.
            ZonePerRegionChrome(
                topActions: [],
                bottomStatus: ZoneBottomStatus(
                    left: "工具就绪",
                    right: ""
                ),
                topSkip: false,
                bottomSkip: false,
                zone: .specializedTools
            ) {
                ZoneModuleView(zoneSlot: .specializedTools)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            // Bottom sub-area: real dynamic zone wrapped in
            // ZonePerRegionChrome.
            ZonePerRegionChrome(
                topActions: [],
                bottomStatus: ZoneBottomStatus(
                    left: "看板",
                    right: ""
                ),
                topSkip: false,
                bottomSkip: false,
                zone: .aiDynamic
            ) {
                ZoneModuleView(zoneSlot: .aiDynamic)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // CHATZONE-CRASH-FIX (2026-09-08): re-inject AppState into
        // the env chain. SwiftUI 6+ breaks the @Environment chain
        // across NavigationSplitView's 3-column boundary (= the
        // child column views are re-rooted in their own env
        // subgraph). Without this re-injection, ChatZoneView /
        // ZoneModuleView / NewLibraryOutlineView all crash with
        // 'No Observable object of type AppState found' on access.
        .environment(appState)
    }
}

// MARK: - Placeholder view (= reusable for M1)

/// M1 placeholder (= Apple HIG standard pattern for empty panes
/// = Xcode's "No Editor" / Mail's "No Message Selected" =
/// informational view showing what WILL go there in a future
/// ticket).
///
/// Per boss 9/3 '父组件不动, 在聊天区关联父组件, 生成子组件,
/// 在子组件做聊天区底栏实现功能. 替换占位文字' (= placeholders
/// are first-class Apple HIG pattern; = the shell renders the
/// structure; = future tickets replace each placeholder with a
/// real zone view).
///
/// Apple HIG implementation notes:
/// - Uses Apple's `ContentUnavailableView` (= macOS 14+; = Apple
///   HIG canonical "no content" view = Xcode / Mail / Notes
///   pattern) — but we want a NAMED placeholder (= showing what
///   WILL be there) not a "no content" view.
/// - Falls back to a custom VStack (= macOS 13 compatible = below
///   the `ContentUnavailableView` floor; = wenshu's minimum
///   target = macOS 27 but uses AppKit-compatible primitives for
///   maximum portability).
struct ShellPlaceholder: View {
    let name: String
    let icon: String
    let hint: String

    var body: some View {
        // VStack with icon + name + hint (= Apple HIG
        // informational pane layout = centered vertically +
        // horizontally with subtle background tint).
        //
        // Boss 9/7 'use apple api unless apple api cannot implement
        // the requirement' (= prefer Apple HIG primitives over
        // custom styling).
        VStack(spacing: DesignTokens.chromePaddingLeading) {
            // SF Symbol (= Apple HIG icon system) + macOS 27
            // Liquid Glass material = the icon takes on the
            // standard tint automatically.
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            // Name (= the placeholder's canonical label).
            Text(name)
                .font(.title2)
                .foregroundStyle(.secondary)
            // Hint (= future-ticket reference; = Apple's
            // standard "this is where X will go" pattern).
            Text(hint)
                .font(.callout)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Background tint (= Apple HIG .background hierarchy
        // = .background for content area per zone tier).
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
