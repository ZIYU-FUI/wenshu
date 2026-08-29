// PaneRenderer.swift · Wenshu (文枢) · v0.28 ticket 028-004
//
// Recursive renderer for the WorkspaceState v2 split tree (= ticket
// 028-003 schema). Walks the LayoutNode tree depth-first; renders
// each SplitNode as an HStack/VStack of children (= with the existing
// NativeSplitter between siblings for drag-to-resize); renders each
// GroupNode as a stack of panes (= one pane per PaneID in the
// GroupNode.panes array, with the active pane front-most).
//
// Architecture (= per 028-004 ticket spec §"Architecture"):
// - `PaneRenderer` is the recursive entry point; it takes a
//   `LayoutNode` + a binding into `WorkspaceStore` (= so drag-resize
//   weight updates flow back to the store).
// - Split rendering uses HStack (= .row orientation) or VStack
//   (= .column orientation) with `.frame(idealWidth/Height:
//   weight * unit, ...)` to express the fractional weights.
// - NativeSplitter (= the existing v0.27 view from
//   Sources/WenshuApp/Views/Layout/NativeSplitter.swift) is reused
//   between siblings for drag-to-resize; the per-step delta it
//   reports flows through `WorkspaceStore.setSplitWeights(...)`.
// - Group rendering wraps each PaneNode in a host that looks up the
//   active tab (= WorkspaceState.tab(for: id)) and dispatches the
//   tab's view via the WorkspaceView's renderTab closure.
//
// Out of scope for this commit (= per ticket 028-004 §"Out of scope"
// + Q124 1-ticket-1-commit, NOT addressed here):
// - tab-drag-between-pane (= ticket 028-007 surface; needs
//   `.draggable` + `.dropDestination` macOS 14+ wiring).
// - Layout edit mode UI (= 028-006).
// - ZoneEditor (= 028-008).
// - Drag regression test (= 028-011).
//
// Atomic-coupling with WorkspaceView.swift (= same commit): the
// renderer needs WorkspaceView's renderTab closure to dispatch the
// TabKind → view mapping; shipping the renderer without that closure
// would leave every tab showing an empty pane. Per boss 8/22
// 'atomic coupling' rule.

import SwiftUI

/// PaneRenderer — recursive renderer for a single `LayoutNode`.
///
/// Uses the v2 split-tree schema from WorkspaceState.swift (ticket
/// 028-003). Each level dispatches on the node type:
///
/// - `.split` → renders an HStack (for `.row` orientation) or VStack
///   (for `.column` orientation) of its children, separated by
///   `NativeSplitter` instances for drag-to-resize.
/// - `.group` → renders a PaneStackView (= stack of PaneNode hosts
///   with the active pane front-most and a tab strip if > 1 pane).
///
/// Drag-to-resize persistence model (= ticket 028-004b1, this
/// commit): during drag, we update local `@State` weights for the
/// live preview only; on drag end, we commit the weights to
/// `WorkspaceStore.adjustSplitWeights` (= which writes UserDefaults
/// once). This avoids the UserDefaults write storm that the v0.27
/// per-frame persistence caused.
struct PaneRenderer: View {
    let node: LayoutNode
    @ObservedObject var store: WorkspaceStore

    /// The minimum pane width / height (= clamps how small a child
    /// can shrink under drag-to-resize).
    private let minChildSize: CGFloat = 200

    /// The ideal width unit (= 1 weight = 100 PT by default; can be
    /// tuned for high-DPI displays).
    private let weightUnit: CGFloat = 100

    /// Local weight cache during drag (= holds the in-progress
    /// weights as the user drags; cleared when drag ends and the
    /// final weights are committed to the store).
    @State private var dragCache: [String: [Double]] = [:]

    var body: some View {
        switch node {
        case .split(let s):
            splitContainer(s)
        case .group(let g):
            groupContainer(g)
        }
    }

    // MARK: - Split container

    @ViewBuilder
    private func splitContainer(_ split: SplitNode) -> some View {
        // Resolve weights from the cache (= active drag) or the
        // stored tree (= no active drag). The cache is keyed by
        // split id so concurrent drags on different splits don't
        // interfere.
        let liveWeights = dragCache[split.id] ?? split.weights

        if split.orientation == .row {
            HStack(spacing: 0) {
                ForEach(split.children.indices, id: \.self) { i in
                    PaneRenderer(node: split.children[i], store: store)
                        .frame(
                            minWidth: minChildSize,
                            idealWidth: max(minChildSize, CGFloat(liveWeights[i]) * weightUnit)
                        )
                    if i < split.children.count - 1 {
                        NativeSplitter(
                            orientation: .vertical,
                            length: nil,
                            onDrag: { delta in
                                // Update the local cache only (= no
                                // UserDefaults write). The store's
                                // authoritative weights stay put
                                // until drag end.
                                var newWeights = liveWeights
                                let minWeight = 0.05
                                let total = newWeights[i] + newWeights[i + 1]
                                guard total > 0 else { return }
                                let dW = Double(delta) / total
                                var newLeft = max(minWeight, min(1 - minWeight, newWeights[i] + dW))
                                let newRight = max(minWeight, total - newLeft)
                                newLeft = total - newRight
                                newWeights[i] = newLeft
                                newWeights[i + 1] = newRight
                                dragCache[split.id] = newWeights
                            },
                            onDragEnd: {
                                // Commit the cached weights to the
                                // store (= single UserDefaults write).
                                if let finalWeights = dragCache[split.id] {
                                    for k in 0..<finalWeights.count {
                                        let delta = finalWeights[k] - split.weights[k]
                                        if abs(delta) > 0.0001 {
                                            store.adjustSplitWeights(splitID: split.id, childIndex: k, delta: delta * Double(weightUnit))
                                        }
                                    }
                                    dragCache.removeValue(forKey: split.id)
                                }
                            }
                        )
                    }
                }
            }
        } else {
            VStack(spacing: 0) {
                ForEach(split.children.indices, id: \.self) { i in
                    PaneRenderer(node: split.children[i], store: store)
                        .frame(
                            minHeight: minChildSize,
                            idealHeight: max(minChildSize, CGFloat(liveWeights[i]) * weightUnit)
                        )
                    if i < split.children.count - 1 {
                        NativeSplitter(
                            orientation: .horizontal,
                            length: nil,
                            onDrag: { delta in
                                var newWeights = liveWeights
                                let minWeight = 0.05
                                let total = newWeights[i] + newWeights[i + 1]
                                guard total > 0 else { return }
                                let dW = Double(delta) / total
                                var newTop = max(minWeight, min(1 - minWeight, newWeights[i] + dW))
                                let newBottom = max(minWeight, total - newTop)
                                newTop = total - newBottom
                                newWeights[i] = newTop
                                newWeights[i + 1] = newBottom
                                dragCache[split.id] = newWeights
                            },
                            onDragEnd: {
                                if let finalWeights = dragCache[split.id] {
                                    for k in 0..<finalWeights.count {
                                        let delta = finalWeights[k] - split.weights[k]
                                        if abs(delta) > 0.0001 {
                                            store.adjustSplitWeights(splitID: split.id, childIndex: k, delta: delta * Double(weightUnit))
                                        }
                                    }
                                    dragCache.removeValue(forKey: split.id)
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Group container

    @ViewBuilder
    private func groupContainer(_ group: GroupNode) -> some View {
        let panes = group.panes.compactMap { id in store.workspace.pane(for: id) }
        VStack(spacing: 0) {
            // Tab strip (= only if > 1 pane in the group).
            if group.panes.count > 1 {
                GroupTabStrip(
                    panes: group.panes,
                    activePaneID: group.active,
                    tabs: store.workspace.tabs,
                    paneLabels: buildPaneLabels(group: group),
                    onSelect: { paneID in
                        store.setActivePaneInGroup(groupID: group.id, paneID: paneID)
                    },
                    onClose: { paneID in
                        store.removePaneFromGroup(paneID: paneID)
                    }
                )
            }
            // Active pane front-most.
            if let activePane = panes.first(where: { $0.id == group.active }) ?? panes.first {
                paneHost(for: activePane, group: group)
            } else {
                // Empty pane fallback (= should not happen post-
                // normalize, but the renderer must be total).
                Color.secondary.opacity(0.05)
                    .overlay(Text("空面板"))
            }
        }
    }

    /// Build a `[PaneID: String]` lookup of pane titles from the
    /// workspace's pane metadata + tabs (= resolves to the first
    /// tab's title for each pane; the GroupTabStrip uses this to
    /// show the right label for each tab).
    private func buildPaneLabels(group: GroupNode) -> [PaneID: String] {
        var labels: [PaneID: String] = [:]
        for paneID in group.panes {
            if let pane = store.workspace.pane(for: paneID),
               let firstTabID = pane.tabIDs.first,
               let tab = store.workspace.tab(for: firstTabID) {
                labels[paneID] = tab.title
            } else {
                labels[paneID] = "面板"
            }
        }
        return labels
    }

    /// Single pane host (= wraps the pane in a frame + hosts the
    /// active tab's content view).
    @ViewBuilder
    private func paneHost(for pane: PaneNode, group: GroupNode) -> some View {
        let activeTab = pane.tabIDs.first.flatMap { id in store.workspace.tab(for: id) }
        Group {
            if let tab = activeTab {
                // Dispatch the tab kind to the view via the
                // shared renderer (= defined in WorkspaceView.swift).
                TabContentDispatcher(kind: tab.kind, title: tab.title)
            } else {
                Color.secondary.opacity(0.05)
                    .overlay(Text("空面板"))
            }
        }
        .frame(
            minWidth: pane.frame.minWidth,
            idealWidth: pane.frame.idealWidth
        )
        // Drop target for tab drags from other panes.
        // Per ticket 028-004b2: each pane is a `.dropDestination`
        // accepting drag drops. Center drop joins the group's tab
        // list (= insertAtGroup with pos=.center); edge drops
        // split the group (= insertAtGroup with pos=.left/right).
        // For this first cut, we only handle center drops (= join
        // as tab). Edge splits land in 028-008 ZoneEditor.
        .dropDestination(for: String.self) { items, _ in
            guard let paneIDString = items.first,
                  let paneUUID = UUID(uuidString: paneIDString) else {
                return false
            }
            let draggedPaneID = PaneID(paneUUID)
            // Don't drag onto self.
            guard draggedPaneID != pane.id else { return false }
            store.movePaneWithinGroup(groupID: group.id, paneID: draggedPaneID, targetPaneID: pane.id)
            return true
        }
    }
}

/// TabContentDispatcher — maps `TabKind` to the existing wenshu
/// view (= mirrors WorkspaceView.renderTab).
///
/// Implementation note: rather than carrying an environment-injected
/// closure (= AnyView is not Sendable under Swift 6's concurrency
/// checker), this view does the TabKind -> view mapping directly
/// via an internal switch. The mapping is duplicated from
/// WorkspaceView.renderTabByKind to keep both in sync; if you
/// add a new TabKind, update both.
///
/// Per ticket 028-004 §"Out of scope", the recursive PaneRenderer
/// dispatches tabs through this shim; future tickets (= 028-007
/// tab-drag, 028-008 ZoneEditor) can introduce a more sophisticated
/// registry if needed.
struct TabContentDispatcher: View {
    let kind: TabKind
    let title: String

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
                bottomStatus: projectSidebarChrome(shelfCount: 0, bookCount: 0).bottom,
                topSkip: true  // ← skip outer top, use internal ZoneContentTabBar only
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
                topSkip: true
            ) {
                ZoneModuleView(zoneSlot: .projectPreview)
            }
        case .editor:
            // No outer top (= internal ZoneContentTabBar for 编辑 /
            // 大纲 / 反链 IS the top chrome). Bottom status = 字数 / N%.
            ZonePerRegionChrome(
                topActions: [],
                bottomStatus: editorChrome(wordCount: 0, progress: 0.0).bottom,
                topSkip: true
            ) {
                ZoneModuleView(zoneSlot: .editor)
            }
        case .specializedTools:
            // No outer top (= internal ZoneContentTabBar for 画布 /
            // 数据库 IS the top chrome). Bottom status = 工具就绪.
            ZonePerRegionChrome(
                topActions: [],
                bottomStatus: specializedToolsChrome().bottom,
                topSkip: true
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
                bottomSkip: true  // chat uses internal ChatBottomToolbar per v0.21 ticket 10
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
                topSkip: true
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
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
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
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
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
// 28 PT height (= matches LayoutTokens.chatTabHotArea for
// consistency with the old 6区).

@MainActor
struct ChatZoneTopChrome: View {
    @State private var showingArchiveConfirm: Bool = false
    @Namespace private var tabBarNamespace

    var body: some View {
        // v0.28 followup Boss UX round 30 (Boss 2026-08-29 OOB '顶栏不是
        // 一个组件吗, 你看截图, 每个区域的毛玻璃效果都不一样'):
        // wrapped in canonical `RegionTabBar` (= single source of truth
        // for all per-pane tab bars). Previously this had its own
        // .regularMaterial + .separator overlay (= inconsistent with
        // ZoneContentTabBar + DynamicZoneTabBar). Now uses the shared
        // component = identical Liquid Glass rendering everywhere.
        RegionTabBar {
            HStack(spacing: 0) {
                // Left: bot tab (= 对话, currently selected).
                // 28x28 hot area pattern (= Apple HIG canonical per the
                // v0.25.1 ticket 018 fix). Lucide-first via existing helper
                // (= falls back to SF Symbol).
                tabItem(
                    icon: "bot",
                    label: "对话",
                    isSelected: true
                )
                .padding(.leading, 18)
                Spacer(minLength: 0)
                // Right: archive icon (= matches old 6区 right-side inbox icon).
                Button {
                    showingArchiveConfirm = true
                } label: {
                    Color.clear
                        .frame(width: LayoutTokens.chatTabHotArea, height: LayoutTokens.chatTabHotArea)
                        .overlay(alignment: .center) {
                            LucideIconSystemFallback("inbox", size: LayoutTokens.iconSize)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("归档本次会话")
                .padding(.trailing, 18)
            }
        }
    }

    /// Single tab button (= Apple HIG canonical 28×28 hot area +
    /// Lucide icon + selected underline). Mirrors ZoneContentTabBar's
    /// tab pattern (= see Sources/WenshuApp/Views/Dynamic/ZoneContentView.swift).
    @ViewBuilder
    private func tabItem(icon: String, label: String, isSelected: Bool) -> some View {
        Button {
            // v0.28 followup round 16: chat has only 1 visible tab 当前,
            // so the click is a no-op. Future expansion (= multiple tabs
            // per chat zone) hooks here.
        } label: {
            Color.clear
                .frame(width: LayoutTokens.chatTabHotArea, height: LayoutTokens.chatTabHotArea)
                .overlay(alignment: .center) {
                    LucideIconSystemFallback(icon, size: LayoutTokens.iconSize)
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                }
                .contentShape(Rectangle())
                .overlay(alignment: .bottom) {
                    if isSelected {
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(height: LayoutTokens.tabUnderlineHeight)
                            .matchedGeometryEffect(id: "chatTabUnderline", in: tabBarNamespace)
                    }
                }
        }
        .buttonStyle(.plain)
        .help(label)
    }
}
