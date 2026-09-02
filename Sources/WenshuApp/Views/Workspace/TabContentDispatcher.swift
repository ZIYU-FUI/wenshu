// TabContentDispatcher.swift · Wenshu (文枢) · v0.28 ticket 028-004
//
// Extracted from PaneRenderer.swift on 2026-09-01 (= when the
// legacy PaneRenderer/PaneSplitRenderer/NativeSplitter/PaneSplitter
// were deleted as dead code per boss OOB "既然新代码已经完整复刻
// 了代码, 那旧代码就可以不要了"). The TabContentDispatcher struct
// itself is still alive (= used by PaneNSController to host each
// pane's SwiftUI content via NSHostingController), so it moved to its
// own file instead of being deleted.
//
// Per ticket 028-004: dispatches a TabKind (= .projectSidebar /
// .projectPreview / .editor / .specializedTools / .aiChat /
// .aiDynamic) to the correct zone view. Reads AppState + BookStore
// from @Environment (= no @Binding chain; per v0.30 boss 8/31 OOB
// "option A for cross-zone communication").
///
/// Per ticket 028-004 §"Out of scope", the recursive PaneRenderer
/// dispatches tabs through this shim; future tickets (= 028-007
/// tab-drag, 028-008 ZoneEditor) can introduce a more sophisticated
/// registry if needed.

import SwiftUI


struct TabContentDispatcher: View {
    let kind: TabKind
    let title: String

    /// v0.30 boss 8/31 OOB '各区域之间的联动' (= option A =
    /// global @Observable store). TabContentDispatcher reads
    /// AppState directly via @Environment (= no @Binding chain).

    // v0.30 boss 8/31 OOB (sidebar feedback bundle #3): bottom status
    // '书架: N / 书: N' was hardcoded to 0. Now reads live counts
    // from BookStore (= the Environment value already propagated
    // from App.swift via .environment(bookStore)).
    @Environment(BookStore.self) private var bookStore

    /// v0.30 boss 8/31 OOB '各区域之间的联动' (= option A = global
    /// @Observable store). TabContentDispatcher reads sidebar
    /// selection directly from AppState (= no @Binding chain).
    @Environment(AppState.self) private var appState

    var body: some View {
        switch kind {
        case .projectSidebar:
            // v0.28 followup Boss UX round 14 (Boss 2026-08-29 OOB
            // '检查各区的顶栏个底栏, 配合截图看, 有的实现了两层, 解
            // 决一下'): No outer ZonePerRegionChrome (= the old
            // ZoneTopToolbar outer 30 PT) — the internal
            // ZoneContentTabBar (= 1 tab 书架 + trailing 新建/入驻
            // buttons) IS the top chrome. Otherwise we'd have 2 layers
            // (= 30 PT outer + 28 PT inner ZoneContentTabBar = 58 PT
            // per-pane chrome = ugly).
            //
            // The bottom status text (= 书架: N / 书: N) still comes
            // from a single ZoneBottomStatus (= no duplicate with the
            // internal ZoneContentView).
            ZonePerRegionChrome(
                topActions: [],  // empty (= no outer top toolbar)
                // v0.30 boss 8/31 OOB: count books by enumerating shelf
                // directories on disk (= wenshu has no flat books
                // array; each shelf dir contains a 'books/' subdir
                // with one subdir per book).
                bottomStatus: projectSidebarChrome(
                    shelfCount: bookStore.shelves.count,
                    bookCount: bookStore.shelves.reduce(0) { acc, shelfItem in
                        let shelfBooksDir = bookStore.stores.shelvesRoot
                            .appendingPathComponent(shelfItem.directoryName, isDirectory: true)
                            .appendingPathComponent("books", isDirectory: true)
                        let bookCount = (try? FileManager.default.contentsOfDirectory(
                            at: shelfBooksDir,
                            includingPropertiesForKeys: [.isDirectoryKey],
                            options: [.skipsHiddenFiles]
                        ).filter { url in
                            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                        }.count) ?? 0
                        return acc + bookCount
                    }
                ).bottom,
                topSkip: true,  // ← skip outer top, use internal ZoneContentTabBar only
                // v0.32 boss 2026-09-02 OOB: sidebar = chrome tier
                // (= .controlBackgroundColor per Apple HIG "large
                // controls" = sidebar / inspector / table view).
                zone: .projectSidebar
            ) {
                ZoneModuleView(zoneSlot: .projectSidebar)
            }
        case .projectPreview:
            // Same: no outer top toolbar (= internal ZoneContentTabBar
            // for 预览 / 图 tabs IS the top chrome). Just the bottom
            // status text.
            ZonePerRegionChrome(
                topActions: [],
                bottomStatus: projectPreviewChrome(chapterCount: 0).bottom,
                topSkip: true,
                // v0.32 boss 2026-09-02 OOB: preview = content tier
                // (= .windowBackgroundColor per Apple HIG "the area
                // beneath your window's views" = content area;
                // inset 1 tier darker than chrome in dark mode =
                // matches FCP viewer depth).
                zone: .projectPreview
            ) {
                ZoneModuleView(zoneSlot: .projectPreview)
            }
        case .editor:
            // No outer top (= internal ZoneContentTabBar for 编辑 /
            // 大纲 / 反链 IS the top chrome). Bottom status = 字数 / N%.
            ZonePerRegionChrome(
                topActions: [],
                bottomStatus: editorChrome(wordCount: 0, progress: 0.0).bottom,
                topSkip: true,
                // v0.32 boss 2026-09-02 OOB: editor = content tier
                // (= .windowBackgroundColor = matches Xcode editor
                // and Pages document inset depth).
                zone: .editor
            ) {
                ZoneModuleView(zoneSlot: .editor)
            }
        case .specializedTools:
            // No outer top (= internal ZoneContentTabBar for 画布 /
            // 数据库 IS the top chrome). Bottom status = 工具就绪.
            ZonePerRegionChrome(
                topActions: [],
                bottomStatus: specializedToolsChrome().bottom,
                topSkip: true,
                // v0.32 boss 2026-09-02 OOB: tools = chrome tier
                // (= .controlBackgroundColor = matches Xcode
                // inspector / FCP inspector depth).
                zone: .specializedTools
            ) {
                ZoneModuleView(zoneSlot: .specializedTools)
            }
        case .aiChat:
            // v0.28 followup Boss UX round 16 (Boss 2026-08-29 OOB
            // '聊天区的顶栏消失了' = restoring the chat top tab bar.
            // Old 6区 had ChatZoneTabBar (= 3 tabs: 对话 / 搜索 / 设置
            // + archive button on right). The new ChatView doesn't
            // have an internal tab bar. Restore it via ChatZoneTopChrome
            // (= simple inline HStack with bot icon + archive icon +
            // selected underline, matches the Apple HIG canonical
            // per-pane tab bar style used in 4 general zones).
            // NO outer ZonePerRegionChrome (= ChatZoneTopChrome IS
            // the top chrome, single layer).
            ZonePerRegionChrome(
                topActions: [],
                bottomStatus: aiChatChrome().bottom,
                topSkip: true,  // skip outer (= ChatZoneTopChrome IS the top)
                bottomSkip: true,  // chat uses internal ChatBottomToolbar per v0.21 ticket 10
                // v0.32 boss 2026-09-02 OOB: chat = content tier
                // (= .windowBackgroundColor = matches Mail message
                // list / Messages conversation depth).
                zone: .aiChat
            ) {
                ChatView()
                    .safeAreaInset(edge: .top, spacing: 0) {
                        // safeAreaInset adds a view above the ChatView
                        // (= the top chrome) without ChatView needing to
                        // know about it. Matches macOS 26 Tahoe pattern
                        // (= content area + small top inset for tab bar).
                        ChatZoneTopChrome()
                    }
            }
        case .aiDynamic:
            // No outer top (= internal DynamicZoneTabBar for 进度 /
            // 待办 / 搜索 IS the top chrome). Just the bottom 看板
            // status text.
            ZonePerRegionChrome(
                topActions: [],
                bottomStatus: aiDynamicChrome().bottom,
                topSkip: true,
                // v0.32 boss 2026-09-02 OOB: dynamic / kanban =
                // content tier (= .windowBackgroundColor = matches
                // Xcode issue navigator depth).
                zone: .aiDynamic
            ) {
                ZoneModuleView(zoneSlot: .aiDynamic)
            }
        }
    }
}

// MARK: - Environment value for the tab dispatcher (kept for future use)
//
// We previously carried the dispatcher as an environment-injected
// closure (= see git history of this file); Swift 6's concurrency
// checker rejected it because AnyView is not Sendable. The current
// implementation switches on TabKind directly inside the view. If
// future tickets need pluggable view resolution (= e.g. for tests
// or alternate renderers), they can reintroduce a Sendable wrapper
// here — for now, the direct switch is sufficient and matches the
// WorkspaceView.renderTabByKind behavior 1:1.

// MARK: - Group tab strip

/// GroupTabStrip — horizontal strip of tab labels for a group with
/// > 1 pane (= the FCP Browser / VS Code pattern). Selecting a tab
/// front-s it (= sets `active` on the owning group).
///
/// Per ticket 028-004b2: each tab is `.draggable` (= String payload
/// = the PaneID UUID string), so the user can drag a tab from one
/// group to another (= or to the same group to reorder). The drop
/// target is the pane host (= see paneHost(.dropDestination)).
///
/// Per ticket 028-004b3: each tab has a close button (= X glyph)
/// that calls `onClose` (= dispatches to WorkspaceStore.removePane
/// per the hermes pane-close semantics).
private struct GroupTabStrip: View {
    let panes: [PaneID]
    let activePaneID: PaneID
    let tabs: [TabSpec]
    /// Per-pane label lookup (= paneID → title). Provided by the
    /// caller (= PaneRenderer) because the strip itself doesn't have
    /// access to WorkspaceState.
    let paneLabels: [PaneID: String]
    let onSelect: (PaneID) -> Void
    let onClose: (PaneID) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(panes, id: \.self) { paneID in
                let label = paneLabels[paneID] ?? "面板"
                HStack(spacing: 4) {
                    Button(action: { onSelect(paneID) }) {
                        Text(label)
                            .font(.system(size: 11))
                            .lineLimit(1)
                            .padding(.horizontal, LayoutTokens.chromePaddingLarge)
                            .padding(.vertical, LayoutTokens.chromePaddingSmall)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    // Drag handle: drag a tab to drop it into another
                    // pane (= ticket 028-004b2). String payload = the
                    // PaneID's UUID string (= the receiver parses it back
                    // into a PaneID in the dropDestination closure).
                    .draggable(paneID.raw.uuidString) {
                        // Drag preview: a small grey rectangle (= the
                        // standard Apple pattern; full tab preview lands
                        // in 028-007 when we have a tab icon asset).
                        Text(label)
                            .font(.system(size: 11))
                            .padding(.horizontal, LayoutTokens.chromePaddingLarge)
                            .padding(.vertical, LayoutTokens.chromePaddingSmall)
                            .background(Color.accentColor.opacity(0.25))
                    }
                    // Close button (= ticket 028-004b3): per
                    // VSCode / FCP Browser convention, a small X
                    // glyph at the tab's right edge. Hidden if the
                    // group has only 1 pane left (= can't close
                    // the last pane — would empty the workspace).
                    if panes.count > 1 {
                        Button(action: { onClose(paneID) }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(width: 14, height: 14)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(paneID == activePaneID ? Color.accentColor.opacity(0.15) : Color.clear)
                // Bottom 1 PT separator.
                // v0.28 followup Boss UX round 26: Apple HierarchicalShapeStyle
                // .separator (= canonical Liquid Glass separator, macOS 26 Tahoe)
                // replaces Color.secondary.opacity(0.3) (= solid muted gray)
                // for the group header bottom border.
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(.separator),
                    alignment: .bottom
                )
            }
        }
        // v0.28 followup Boss UX round 24: .regularMaterial replaces
        // Color.secondary.opacity(0.08) for the group tab bar
        // background (= the floating group header inside a ZoneContentView
        // that has multiple groups of panes).
        .background(.regularMaterial)
    }
}
// MARK: - ChatZoneTopChrome (= chat zone top tab bar)
//
// v0.28 followup Boss UX round 16 (Boss 2026-08-29 OOB '聊天区的顶栏
// 消失了'): restore the chat zone top chrome (= old 6区 had
// ChatZoneTabBar with 3 tabs + archive button). New ChatView
// doesn't have an internal tab bar. ChatZoneTopChrome provides the
// single top tab bar (= matches Apple HIG canonical per-pane
// tab bar style used in 4 general zones via ZoneContentView's
// ZoneContentTabBar). 1 chat zone = 1 single chrome layer.
//
// Visual: HStack with 1 active tab icon (bot = 对话 tab per old
// 6区) on the left + 1 archive icon on the right, with selected
// underline accent color (= matches the ZoneContentTabBar style).
// 28 PT height (= matches DesignTokens.paneTabHotArea for
// consistency with the old 6区).

@MainActor
struct ChatZoneTopChrome: View {
    @State private var showingArchiveConfirm: Bool = false
    @State private var isArchiveHover: Bool = false
    @Namespace private var tabBarNamespace

    var body: some View {
        // v0.28 followup Boss UX round A (Phase 3 of refactor): ChatZoneTopChrome
        // body now delegates to `PaneTabBar` generic component (= ComponentIndex.md
        // Level 3.2). Was 74 LOC, now ~25 LOC. Behavior preserved 1:1.
        //
        // Boss 2026-09-01 OOB: removed the trailing button's local
        // `.padding(.trailing, ...)` modifier (= was double-padding
        // the icon: PaneTabBar now applies a single 18 PT trailing
        // padding to the whole bar, so the local button padding
        // pushed the icon 64 PT from the right edge instead of 18).
        PaneTabBar(
            items: [
                PaneTabItem(id: "chat", icon: "bot", label: "对话"),
            ],
            selection: .constant("chat"),
            namespace: tabBarNamespace,
            namespaceID: "chatTabUnderline",
            trailing: {
                // Right: archive icon (= matches old 6区 right-side inbox icon).
                //
                // Boss 2026-09-01 OOB: added .onHover tint
                // (= PaneIconTab's hover behaviour for consistency
                // with the leading tabs). Without it, the archive
                // button was the only chrome button that did not
                // visually respond to mouse hover (= users had no
                // feedback that the icon was clickable).
                Button {
                    showingArchiveConfirm = true
                } label: {
                    Color.clear
                        .frame(width: DesignTokens.paneTabHotArea, height: DesignTokens.paneTabHotArea)
                        .overlay(alignment: .center) {
                            LucideIconSystemFallback("inbox", size: DesignTokens.tabIconSize)
                                .foregroundStyle(isArchiveHover ? Color.accentColor : Color.secondary)
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    isArchiveHover = hovering
                }
                .help("归档本次会话")
            }
        )
    }
}
