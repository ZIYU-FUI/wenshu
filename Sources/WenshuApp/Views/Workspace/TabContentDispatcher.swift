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

    /// v0.30 boss 8/31 OOB '各区域之间的联动' (= option A =
    /// global @Observable store). TabContentDispatcher reads sidebar
    /// selection directly from AppState (= no @Binding chain).
    @Environment(AppState.self) private var appState

    // v0.34 boss 2026-09-02 OOB (B-02 multi-layer audit followup):
    // ChatZoneTopChrome wrapper was deleted. The state and namespace
    // it owned (= archive-confirm dialog state + per-instance
    // SwiftUI namespace for the matchedGeometryEffect underline) are
    // now owned by TabContentDispatcher directly (= single source of
    // truth for chat zone top chrome). Migration path: see PaneTabBar
    // documentation in commit dcde7cff5's "top-bar chrome flattening"
    // section.
    @State private var showingArchiveConfirm: Bool = false
    @Namespace private var chatTabBarNamespace

    // v0.34 B-15 (= boss 9/2 OOB follow-up to B-14): the chrome bottom
    // status now reads "字数: 0 / 反链 N" (= replaces the legacy "N%"
    // progress placeholder). BacklinksViewModel lives here too (= own
    // loader for the chrome status; EditorPlaceholder holds its own
    // copy for the popover content. Slight redundancy vs single source
    // of truth, but matches the existing zone-level loader pattern
    // and avoids threading the popover's @State through the chrome
    // hierarchy. The two loaders read the same BacklinkResolver, so
    // backlinks.count stays in sync).
    @State private var backlinksVM = BacklinksViewModel()
    @State private var backlinksCount: Int = 0
    // B-16: popover state for the chrome bottom-right "反链 0" button.
    // When the user taps the chrome bottom right text (= rendered as a
    // clickable Button by PaneStatusBar when rightOnTap is non-nil),
    // showBacklinksPopover flips true and a .popover with the full
    // BacklinksPanel renders anchored at the chrome bottom edge.
    @State private var showBacklinksPopover: Bool = false

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
            // 大纲 / 反链 IS the top chrome). Bottom status = 字数 / 反链
            // (= boss 9/2 OOB replaces the legacy "N%" progress text
            // with backlinks count; = spec spec v0.34 B-15).
            ZonePerRegionChrome(
                topActions: [],
                bottomStatus: ZoneBottomStatus(
                    // v0.34 B-18: chrome bottom left = live word count.
                    // AppState.editorWordCount is written by
                    // EditorEditContent's .onChange(of: draft) handler
                    // (= single source of truth shared with any
                    // future editor-zone status widget).
                    left: "字数: \(appState.editorWordCount)",
                    right: "反链 \(backlinksCount)",
                    // B-16: chrome bottom right text is clickable
                    // (= tap triggers BacklinksPanel popover).
                    rightOnTap: { showBacklinksPopover.toggle() }
                ),
                topSkip: true,
                // v0.32 boss 2026-09-02 OOB: editor = content tier
                // (= .windowBackgroundColor = matches Xcode editor
                // and Pages document inset depth).
                zone: .editor
            ) {
                ZoneModuleView(zoneSlot: .editor)
            }
            // v0.34 B-15: trigger backlinks load on first appear.
            // .task runs once when the editor zone is mounted (= won't
            // re-fetch on every re-render; = Apple HIG async task lifecycle).
            .task {
                await backlinksVM.load(docId: "preview-sample")
                backlinksCount = backlinksVM.backlinks.count
            }
            // B-16: BacklinksPanel popover, anchored to the chrome
            // bottom-right (= the "反链 0" button). Apple HIG
            // non-modal popover for contextual reference info.
            // 320x280 PT = standard inspector popover footprint.
            .popover(isPresented: $showBacklinksPopover, arrowEdge: .bottom) {
                BacklinksPanel(viewModel: backlinksVM)
                    .frame(width: 320, height: 280)
                    .padding(8)
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
            // '聊天区的顶栏消失了') = restoring the chat top tab bar.
            // Old 6区 had ChatZoneTabBar (= 3 tabs: 对话 / 搜索 / 设置
            // + archive button on right). The new ChatView doesn't
            // have an internal tab bar.
            // v0.34 boss 2026-09-02 OOB (B-02 multi-layer audit):
            // the inline ChatZoneTopChrome wrapper was deleted; the
            // PaneTabBar call now lives directly in this dispatch branch
            // (= state + namespace held by TabContentDispatcher above).
            // Single source of truth for chat top chrome.
            // NO outer ZonePerRegionChrome (= this PaneTabBar IS the top chrome).
            ZonePerRegionChrome(
                topActions: [],
                bottomStatus: aiChatChrome().bottom,
                topSkip: true,
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
                        //
                        // v0.34 boss 2026-09-02 OOB: use PaneTabBar directly
                        // (= no ChatZoneTopChrome wrapper layer). Single
                        // hard-coded chat tab item + archive trailing button
                        // (= migrated to PaneTrailingIconButton helper from
                        // commit dcde7cff5). namespaceID stays as
                        // "chatTabUnderline" so the matchedGeometryEffect
                        // anchor remains unique across the workspace.
                        PaneTabBar(
                            items: [PaneTabItem(id: "chat", icon: "bot", label: "对话")],
                            selection: .constant("chat"),
                            namespace: chatTabBarNamespace,
                            namespaceID: "chatTabUnderline",
                            trailing: {
                                PaneTrailingIconButton(
                                    icon: "inbox",
                                    tooltip: "归档本次会话",
                                    action: { showingArchiveConfirm = true }
                                )
                            }
                        )
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
                            .font(.caption)
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
                            .font(.caption)
                            .padding(.horizontal, LayoutTokens.chromePaddingLarge)
                            .padding(.vertical, LayoutTokens.chromePaddingSmall)
                            .background(.tint.opacity(0.25))
                    }
                    // Close button (= ticket 028-004b3): per
                    // VSCode / FCP Browser convention, a small X
                    // glyph at the tab's right edge. Hidden if the
                    // group has only 1 pane left (= can't close
                    // the last pane — would empty the workspace).
                    if panes.count > 1 {
                        Button(action: { onClose(paneID) }) {
                            LucideIconSystemFallback("xmark", size: 10)
                                .foregroundStyle(.secondary)
                                .frame(width: 14, height: 14)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(paneID == activePaneID ? AnyShapeStyle(.tint.opacity(0.15)) : AnyShapeStyle(Color.clear))
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
