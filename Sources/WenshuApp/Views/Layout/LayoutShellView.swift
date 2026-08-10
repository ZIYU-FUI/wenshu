// LayoutShellView.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-01 → LT-01-fix9 → V0-fix-5
//
// 5-zone shell — the root of the macOS window in v0.02.0.
//
// Geometry (AGENTS.md §8.1):
//
//   ┌────────────────────────────────────────────────────────────────┐
//   │ (native macOS title bar — traffic lights only)                  │
//   ├──────────┬───────────────────────────┬──────────────────────────┤
//   │ 项目管理   │ 文档内容浏览器               │ inspector                 │
//   │ topLeft  │ topCenter (editor area)   │ topRight                  │
//   ├──────────┴───────────────────────────┴──────────────────────────┤
//   │ 聊天区 (bottomLeft)               │ 状态 (bottomRight)            │
//   └────────────────────────────────────┴────────────────────────────┘
//
// LT-01-fix3 (装机 user 8/7 实机验 + macOS HIG): the in-window toolbar
// row is GONE — the app version moved to 文枢 → 关于文枢, "重置布局"
// moved to 显示 → 重置布局, and the 4 per-panel chevrons were replaced by
// View → 项目管理/文档/检视/聊天/状态 (Cmd+1…5). Panel chrome now carries
// no controls at all, matching Final Cut Pro / Pages / Numbers.
//
// LT-01-fix9 (装机 user 8/7 实机拍 "全部原生"): 4 个 `PanelSplitter` 替换为
// `NativeSplitter` (= NSSplitView divider 风格 NSView, 1pt 细线 +
// NSCursor 自动设 + NSEvent 原生 drag). Drop-in 替换, 调用接口一致
// (`orientation` + `onDrag` closure), LayoutShellView 的 VStack/HStack
// 结构不变。 见 docs/wenshu/LAYOUT-APPKIT-INVENTORY.md §1.1-1.2。
//
// V0-fix-5 (8/10 17:35 CUA 自验拍 V0-fix-4 commit 41646b01 漏修): 5
// tab Picker 从 ProjectListView 内部搬到 LayoutShellView.topLeftHeaderBar
// 跨全宽 header bar 内, 与 + 按钮平级 (同 38pt 高, + 按钮在左, 5 tab
// 在右) — 拍板真值沿用 V0-fix-4 designer (1a09cd550) §5 + AGENTS
// §8.1 + FCP 范式 "5 tab 与 + 按钮平级"。 topLeftHeaderBar 改持
// `@State activeTab: ProjectManagementTab` + Picker.segmented, 共享
// binding 给 panel(.topLeft) 调的 ProjectListView — ProjectListView
// 改 `@Binding activeTab`, 内部不再有 Picker。
//
// Splitters (see LayoutShellViewModel for delta math):
//   - 2 vertical in upper row (between topLeft↔topCenter, topCenter↔topRight)
//   - 1 horizontal between upper and lower bands
//   - 1 vertical in lower row (between bottomLeft↔bottomRight)
//   → 4 functional splitters. AGENTS §8.1 says "共 5 个"; the geometry
//     only fits 4. ACCEPTANCE-v0.02.0-LT-01.md documents the discrepancy.
//   A splitter is only rendered when both of its neighbours are visible.
//
// Widths/heights come from `LayoutMetrics` (pure, unit-tested) fed by
// `vm.snapshot.ratios` + `vm.snapshot.collapsed` + `vm.visibility`.
//
// Persistence: the View Model handles .ws read/write via
// `WenshuStoreActor` (see LayoutShellViewModel). The View only mutates
// the model through View Model methods.

import SwiftUI

struct LayoutShellView: View {
    // LT-01-fix3: shared instance so the macOS menu bar commands in
    // App.swift drive the same state (a @StateObject here would be
    // unreachable from a CommandMenu).
    @ObservedObject private var vm = LayoutShellViewModel.shared

    // V0-fix-4 Fix 3: + 按钮 push AppRoute.createProject 用的 NavigationPath
    // 顶层 state。 ProjectListView 共享同一 binding,避免双 navPath 不同步。
    @State private var navPath = NavigationPath()

    // V0-fix-4 Fix 2: topLeft 5 tab 容器 (ProjectListView) 需要的项目列表
    // — 后续 WenshuStoreActor 接 .ws 后,这里换成 vm 持有 + onChange 同步。
    @State private var projects: [ProjectSnapshot] = []

    // V0-fix-5: 5 tab Picker state 升到 LayoutShellView 顶层, 由
    // topLeftHeaderBar (跨全宽 38pt bar) 持 Picker.segmented, 与 + 按钮
    // 平级。 ProjectListView 接 @Binding activeTab, 共享同一 state。
    @State private var activeTab: ProjectManagementTab = .projects

    var body: some View {
        NavigationStack(path: $navPath) {
            geometryBody
                .frame(minWidth: 900, minHeight: 600)
                .navigationDestination(for: AppRoute.self) { route in
                    destinationView(for: route)
                }
                .task {
                    await vm.load()
                }
        }
    }

    // MARK: - Navigation destinations

    @ViewBuilder
    private func destinationView(for route: AppRoute) -> some View {
        switch route {
        case .createProject:
            ProjectCreateView(
                onCreate: { newProject in
                    projects.append(newProject)
                    navPath.removeLast()
                },
                onCancel: {
                    navPath.removeLast()
                }
            )
        case .chat:
            // V0-fix-4 范围不接 chat push — chat 实装在下半 ChatPanelView,
            // 这里走 placeholder 避免 ChatViewModel.shared 不存在导致编译失败。
            VStack(spacing: 10) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(.secondary)
                Text("请在底部聊天区继续创作")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        case .characterWorld:
            // V0-fix-4 范围不接 characterWorld push — 留 v0.04.0 长篇工具
            // 工单实装, 这里走 placeholder 兜底。
            VStack(spacing: 10) {
                Image(systemName: "person.2.crop.square.stack")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(.secondary)
                Text("人物世界 — v0.04.0 实现")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 5-zone body

    private var geometryBody: some View {
        GeometryReader { geo in
            let lowerHeight = LayoutMetrics.lowerBandHeight(
                totalHeight: geo.size.height,
                ratios: vm.snapshot.ratios,
                visibility: vm.visibility
            )
            // V0-fix-4 Fix 1: 顶部跨全宽 38pt header bar (替换 v0.02.0 顶部
            // "文枢" 标题文字 — 由 AIF 16:40 拍板升到 NativeSplitter 上方,
            // 跟 macOS 原生 title bar 双层 FCP 风格)。 上半 upperBand 高度
            // 同步减 38pt,保持 5-zone 比例不变。
            let topHeaderHeight: CGFloat = 38
            let upperHeight = max(0, geo.size.height - lowerHeight - topHeaderHeight)
            VStack(spacing: 0) {
                if upperBandVisible || lowerBandVisible {
                    topLeftHeaderBar
                }
                if upperBandVisible {
                    upperBand(in: geo.size.width)
                        .frame(height: upperHeight)
                }
                if upperBandVisible && lowerBandVisible {
                    // LT-01-fix13: VM 的 `adjustXxx` 返回 Bool (= applied,
                    // clamp 没截断), 但 NativeSplitter 的 `onDrag` 是
                    // `(CGFloat) -> Void`, 把 Bool 透传给 caller 也无用
                    // (NativeSplitterView 内部没用返回值 — fix14 后
                    // `lastReported` 字段已删, 没东西可 reset)。 直接
                    // discardableResult 调, 跟 NativeSplitter 接口契约
                    // 对齐。
                    NativeSplitter(orientation: .vertical) { delta in
                        vm.adjustBottomHeight(
                            delta: delta,
                            totalHeight: geo.size.height
                        )
                    }
                }
                if lowerBandVisible {
                    lowerBand(in: geo.size.width)
                        .frame(height: lowerHeight)
                }
            }
        }
    }

    // MARK: - Top header bar (V0-fix-4 Fix 1 + Fix 3 → V0-fix-5 5 tab Picker 升 header)

    /// 顶部跨全宽 38pt 标题栏 (AIF 16:40 拍板 — 替换 v0.02.0 顶部"文枢"标
    /// 题文字,FCP toolbar 风格: 红黄绿 traffic lights 后接 + 按钮 + 5 tab
    /// Picker + Spacer)。 + 按钮接 NavigationStack push → AppRoute.
    /// createProject (V0-fix-4 Fix 3 — 沿 v0.01.0 WO-010 拍板主路由 push)。
    ///
    /// V0-fix-5 拍板: 5 tab Picker (项目 / 章节 / 设定 / 资料 / 看板) 从
    /// ProjectListView 内部搬到这里 — 与 + 按钮平级 (同 38pt 高, + 按钮
    /// 在左, 5 tab Picker 在右) — 视觉对齐 FCP toolbar 范式 + 拍板真值
    /// (1a09cd550) §5。 ProjectListView 改接 `@Binding activeTab` 共享同一
    /// state。 Picker 走 `.pickerStyle(.segmented)` 文字标签, 跟 chat /
    /// inspector tab 风格刻意区分 (沿 V0-fix-3 Fix J 拍板)。
    private var topLeftHeaderBar: some View {
        HStack(spacing: 12) {
            // V0-fix-4 Fix 3: + 按钮接 NavigationStack push 到
            // AppRoute.createProject (沿 v0.01.0 WO-010 拍板)。
            Button {
                navPath.append(AppRoute.createProject)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("新建项目")

            // V0-fix-5: 5 tab Picker (项目 / 章节 / 设定 / 资料 / 看板)
            // 升到 header bar 内, 与 + 按钮平级 — 拍板真值见本函数 doc
            // comment 头部。 文字标签 + Picker.segmented 跟 chat /
            // inspector tab 风格刻意区分 (沿 V0-fix-3 Fix J 拍板)。
            Picker("", selection: $activeTab) {
                ForEach(ProjectManagementTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()

            Spacer(minLength: 0)
        }
        .frame(height: 38)
        .padding(.horizontal, 12)
    }

    private var upperBandVisible: Bool {
        vm.isVisible(.topLeft) || vm.isVisible(.topCenter) || vm.isVisible(.topRight)
    }

    private var lowerBandVisible: Bool {
        vm.isVisible(.bottomLeft) || vm.isVisible(.bottomRight)
    }

    // MARK: - Upper row: 3 columns

    private func upperBand(in totalWidth: CGFloat) -> some View {
        let split = LayoutMetrics.upperWidths(
            totalWidth: totalWidth,
            ratios: vm.snapshot.ratios,
            collapsed: vm.snapshot.collapsed,
            visibility: vm.visibility
        )
        return HStack(spacing: 0) {
            panel(.topLeft, width: split.0)
            if vm.isVisible(.topLeft) && vm.isVisible(.topCenter) {
                // LT-01-fix13: 同上 — VM 返回 Bool 但 NativeSplitter
                // `(CGFloat) -> Void` 不消费, discardableResult 调用。
                NativeSplitter(orientation: .horizontal) { delta in
                    vm.adjustUpperColumn(
                        splitterIndex: 0,
                        delta: delta,
                        totalWidth: totalWidth
                    )
                }
            }
            panel(.topCenter, width: split.1)
            if vm.isVisible(.topCenter) && vm.isVisible(.topRight) {
                NativeSplitter(orientation: .horizontal) { delta in
                    vm.adjustUpperColumn(
                        splitterIndex: 1,
                        delta: delta,
                        totalWidth: totalWidth
                    )
                }
            }
            panel(.topRight, width: split.2)
        }
    }

    // MARK: - Lower row: 2 areas

    private func lowerBand(in totalWidth: CGFloat) -> some View {
        let split = LayoutMetrics.lowerWidths(
            totalWidth: totalWidth,
            ratios: vm.snapshot.ratios,
            collapsed: vm.snapshot.collapsed,
            visibility: vm.visibility
        )
        return HStack(spacing: 0) {
            panel(.bottomLeft, width: split.0)
            if vm.isVisible(.bottomLeft) && vm.isVisible(.bottomRight) {
                // LT-01-fix13: 同上 — discardableResult 调用。
                NativeSplitter(orientation: .horizontal) { delta in
                    vm.adjustLowerColumn(
                        delta: delta,
                        totalWidth: totalWidth
                    )
                }
            }
            panel(.bottomRight, width: split.1)
        }
    }

    // MARK: - One panel slot

    /// Hidden panels render nothing at all (no gutter, no header) — the
    /// only way back is the View menu. Collapsed panels keep their
    /// header/gutter chrome, which LT-01-fix3 leaves reachable only via
    /// persisted state (no chevron).
    @ViewBuilder
    private func panel(_ id: PanelID, width: CGFloat) -> some View {
        if !vm.isVisible(id) {
            EmptyView()
        } else if isCollapsed(id) {
            CollapsedGutter(panelID: id)
                .frame(width: width)
        } else {
            PanelContainer(panelID: id) {
                if id == .bottomLeft {
                    ChatPanelView()
                } else if id == .topRight {
                    // WO-LT-02-v2: inspector 2 tab 嵌入 (伏笔真读
                    // CDForeshadow + 修订 mock 3 条)。 InspectorView
                    // 是 InspectorViewModel.shared 的 @ObservedObject
                    // consumer — inspector 状态 (折叠 / 选 tab /
                    // 拉伏笔列表) 跟左 / 中半 layout 完全解耦, 拖
                    // topRight 改宽不影响其他 panel。 严禁在这里走
                    // sheet / NavigationStack push — 见 AGENTS §6。
                    InspectorView()
                } else if id == .topLeft {
                    // V0-fix-5: ProjectListView 容器跨 header bar + panel(.topLeft)
                    // 双区 — 5 tab Picker 在 header bar (topLeftHeaderBar),
                    // tab 内容 (项目列表 / 章节树 / 设定 / 资料 / 看板) 在
                    // panel 内, 共享 activeTab binding (顶层 LayoutShellView
                    // @State, header bar 持有 Picker, panel 内 ProjectListView
                    // 接 binding)。
                    ProjectListView(
                        projects: $projects,
                        navPath: $navPath,
                        activeTab: $activeTab
                    )
                } else {
                    PlaceholderContent(panel: id)
                }
            }
            .frame(width: width)
        }
    }

    private func isCollapsed(_ id: PanelID) -> Bool {
        switch id {
        case .topLeft: return vm.snapshot.collapsed.topLeft
        case .topCenter: return vm.snapshot.collapsed.topCenter
        case .topRight: return vm.snapshot.collapsed.topRight
        case .bottomLeft: return vm.snapshot.collapsed.bottomLeft
        case .bottomRight: return vm.snapshot.collapsed.bottomRight
        }
    }
}
