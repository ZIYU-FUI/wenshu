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

    /// v0.30 boss 8/31 OOB: forwarded sidebar selection binding
    /// from WorkspaceView. Default = .constant nil for non-workspace
    /// callers.
    @Binding var sidebarSelection: SidebarItem?

    init(
        node: LayoutNode,
        store: WorkspaceStore,
        sidebarSelection: Binding<SidebarItem?> = .constant(nil)
    ) {
        self.node = node
        self.store = store
        self._sidebarSelection = sidebarSelection
    }

    /// The minimum pane width / height (= clamps how small a child
    /// can shrink under drag-to-resize).
    private let minChildSize: CGFloat = 200

    /// v0.30 boss 8/31 OOB: weightUnit is now dynamic (= derived
    /// from the parent's available width via GeometryReader, NOT
    /// hardcoded to 100 PT). Previously the hardcoded value made
    /// the upper band render at a fixed 1000 PT (= 10 weights *
    /// 100 PT), leaving empty space on wider displays. Now the
    /// panes fill the available width proportionally.
    /// v0.30 boss 8/31 OOB: dynamic weight unit (= derived from
    /// parent size, not hardcoded 100 PT).
    private func weightUnitForTotal(_ total: CGFloat, weights: [Double]) -> CGFloat {
        let totalWeight = weights.reduce(0, +)
        guard totalWeight > 0 else { return 1 }
        return total / CGFloat(totalWeight)
    }

    /// Local weight cache during drag (= holds the in-progress
    /// weights as the user drags; cleared when drag ends and the
    /// final weights are committed to the store).
    @State private var dragCache: [String: [Double]] = [:]

    var body: some View {
        GeometryReader { geometry in
            switch node {
            case .split(let s):
                splitContainer(s, availableWidth: geometry.size.width, availableHeight: geometry.size.height)
            case .group(let g):
                groupContainer(g)
            }
        }
    }

    // MARK: - Split container

    @ViewBuilder
    private func splitContainer(
        _ split: SplitNode,
        availableWidth: CGFloat,
        availableHeight: CGFloat
    ) -> some View {
        // Resolve weights from the cache (= active drag) or the
        // stored tree (= no active drag). The cache is keyed by
        // split id so concurrent drags on different splits don't
        // interfere.
        let liveWeights = dragCache[split.id] ?? split.weights

        // v0.30 boss 8/31 OOB '新比例还是没有实现': weightUnit is
        // now derived from the parent's actual available size
        // (= fills the whole pane, not a fixed 1000 PT).
        let unit: CGFloat = split.orientation == .row
            ? weightUnitForTotal(availableWidth, weights: liveWeights)
            : weightUnitForTotal(availableHeight, weights: liveWeights)

        if split.orientation == .row {
            HStack(spacing: 0) {
                ForEach(split.children.indices, id: \.self) { i in
                    rowChild(node: split.children[i], store: store,
                             weight: liveWeights[i], unit: unit)
                    if i < split.children.count - 1 {
                        NativeSplitter(
                            orientation: .vertical,
                            length: nil,
                            onDrag: { delta in
                                // Update the local cache only (= no
                                // UserDefaults write). The store's
                                // authoritative weights stay put
                                // until drag end.
                                //
                                // v0.30 boss 8/31 OOB fix: the old
                                // formula `dW = delta / total` was
                                // unit-broken (= PT / weight = wrong).
                                // Correct: dW = delta / weightUnit
                                // (= PT per 100 PT/weight = weight
                                // delta). This makes the splitter
                                // respond to drags of any pixel size
                                // instead of clamping to minWeight on
                                // the first frame.
                                var newWeights = liveWeights
                                let minWeight = 0.05
                                let total = newWeights[i] + newWeights[i + 1]
                                guard total > 0 else { return }
                                let dW = Double(delta) / Double(unit)
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
                                // v0.30 boss 8/31 OOB: adjustSplitWeights
                                // now expects the WEIGHT delta (= not PT
                                // delta); the previous PT->weight->PT
                                // double-conversion caused 0.3% drift
                                // between the visual drag and the
                                // persisted state. The renderer already
                                // computes weight deltas via the actual
                                // unit during the drag (= liveWeights),
                                // so we just pass through.
                                if let finalWeights = dragCache[split.id] {
                                    for k in 0..<finalWeights.count {
                                        let weightDelta = finalWeights[k] - split.weights[k]
                                        if abs(weightDelta) > 0.0001 {
                                            store.adjustSplitWeights(splitID: split.id, childIndex: k, weightDelta: weightDelta)
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
                    columnChild(node: split.children[i], store: store,
                                weight: liveWeights[i], unit: unit)
                    if i < split.children.count - 1 {
                        NativeSplitter(
                            orientation: .horizontal,
                            length: nil,
                            onDrag: { delta in
                                var newWeights = liveWeights
                                let minWeight = 0.05
                                let total = newWeights[i] + newWeights[i + 1]
                                guard total > 0 else { return }
                                let dW = Double(delta) / Double(unit)
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
                                        let weightDelta = finalWeights[k] - split.weights[k]
                                        if abs(weightDelta) > 0.0001 {
                                            store.adjustSplitWeights(splitID: split.id, childIndex: k, weightDelta: weightDelta)
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

    // MARK: - Child renderers (= extracted to reduce SwiftUI
    // expression type-check complexity in the parent HStack/VStack).

    @ViewBuilder
    private func rowChild(node: LayoutNode, store: WorkspaceStore,
                          weight: Double, unit: CGFloat) -> some View {
        // v0.30 boss 8/31 OOB '上半区比例也还是不对, 编辑器吃掉因为
        // 拖拽线产生的其它宽度': pin width to the exact weighted slice
        // (= no .frame(maxWidth: .infinity, maxHeight: .infinity) =
        // prevents the editor from absorbing splitter widths or
        // rounding leftovers). Only allow vertical fill.
        let width = max(minChildSize, CGFloat(weight) * unit)
        PaneRenderer(node: node, store: store, sidebarSelection: _sidebarSelection)
            .frame(width: width)
            .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private func columnChild(node: LayoutNode, store: WorkspaceStore,
                             weight: Double, unit: CGFloat) -> some View {
        let height = max(minChildSize, CGFloat(weight) * unit)
        PaneRenderer(node: node, store: store, sidebarSelection: _sidebarSelection)
            .frame(height: height)
            .frame(maxWidth: .infinity)
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
                // The sidebarSelection binding is forwarded from
                // WorkspaceView's @State (= see the
                // TabContentDispatcher init default = .constant
                // for non-workspace callers; here we forward the
                // real binding from PaneRenderer).
                TabContentDispatcher(
                    kind: tab.kind,
                    title: tab.title,
                    sidebarSelection: $sidebarSelection
                )
            } else {
                Color.secondary.opacity(0.05)
                    .overlay(Text("空面板"))
            }
        }
        // v0.30 boss 8/31 OOB: paneHost no longer overrides the
        // split-level frame's `width` (= the per-pane `idealWidth`
        // was previously beating the split's weights, giving sidebar
        // 240 PT instead of 100 PT regardless of weights). Now only
        // `minWidth` is honored (= ensures the pane never shrinks
        // below its declared minimum).
        .frame(minWidth: pane.frame.minWidth)
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

    /// v0.30 boss 8/31 OOB '点 sidebar row → 右边素材区正常显示目录
    /// 下的文档': forwarded sidebar selection binding from
    /// WorkspaceView. ZoneModuleView (inside TabContentDispatcher)
    /// needs this to drive the PreviewPane scope. Default = .constant
    /// nil for non-workspace callers.
    @Binding var sidebarSelection: SidebarItem?

    init(
        kind: TabKind,
        title: String,
        sidebarSelection: Binding<SidebarItem?> = .constant(nil)
    ) {
        self.kind = kind
        self.title = title
        self._sidebarSelection = sidebarSelection
    }

    // v0.30 boss 8/31 OOB (sidebar feedback bundle #3): bottom status
    // '书架: N / 书: N' was hardcoded to 0. Now reads live counts
    // from BookStore (= the Environment value already propagated
    // from App.swift via .environment(bookStore)).
    @Environment(BookStore.self) private var bookStore

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
                topSkip: true  // ← skip outer top, use internal ZoneContentTabBar only
            ) {
                ZoneModuleView(
                    zoneSlot: .projectSidebar,
                    sidebarSelection: $sidebarSelection
                )
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
                ZoneModuleView(
                    zoneSlot: .projectPreview,
                    sidebarSelection: $sidebarSelection
                )
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
    @Namespace private var tabBarNamespace

    var body: some View {
        // v0.28 followup Boss UX round A (Phase 3 of refactor): ChatZoneTopChrome
        // body now delegates to `PaneTabBar` generic component (= ComponentIndex.md
        // Level 3.2). Was 74 LOC, now ~25 LOC. Behavior preserved 1:1.
        PaneTabBar(
            items: [
                PaneTabItem(id: "chat", icon: "bot", label: "对话"),
            ],
            selection: .constant("chat"),
            namespace: tabBarNamespace,
            namespaceID: "chatTabUnderline",
            trailing: {
                // Right: archive icon (= matches old 6区 right-side inbox icon).
                Button {
                    showingArchiveConfirm = true
                } label: {
                    Color.clear
                        .frame(width: DesignTokens.paneTabHotArea, height: DesignTokens.paneTabHotArea)
                        .overlay(alignment: .center) {
                            LucideIconSystemFallback("inbox", size: DesignTokens.tabIconSize)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("归档本次会话")
                .padding(.trailing, DesignTokens.chromePaddingTrailing)
            }
        )
    }
}
