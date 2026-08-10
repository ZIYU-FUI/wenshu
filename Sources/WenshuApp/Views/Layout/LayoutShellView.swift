// LayoutShellView.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-01 → LT-01-fix9 → v0.03.0 V0-fix-6
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
// V0-fix-6 (AIF 17:35 + 装机 user 8/10 17:35+17:40 OOB 真机拍):
//   Fix 1 (B5): + 按钮走 modal sheet (`.sheet(isPresented:)`), 不用
//                NavigationStack push (改自 V0-fix-4 Fix 3 — 装机 user
//                17:35 OOB 拍"走弹窗不 push")。 sheet 关闭后 onCreate/
//                onCancel 回调走 LayoutShellView 顶层 projects +
//                showCreateProject state。
//   Fix 2 (B5): 5 tab 容器升到标题栏 (HStack 内 + 按钮右侧), iconOnly
//                Picker — 沿用 ProjectManagementTab.symbolName 5 SF
//                Symbol (folder / list.bullet.rectangle /
//                slider.horizontal.3 / books.vertical /
//                rectangle.split.3x1)。 ProjectListView 内的 5 tab
//                仍保留, v0.04.0 才下沉 (本期不动 tab 容器归属)。
//   Fix 5 (B5): 5 tab activeTab state 由 LayoutShellView 顶层持有
//                (@State), @Binding 传 ProjectListView — 保证标题栏
//                iconOnly Picker + ProjectListView segmented Picker
//                共享同一 state (FCP toolbar 范式)。
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

    // V0-fix-4 Fix 3 (V0-fix-6 保留): navPath 仍需为 chat 路由服务
    // (ProjectListView 内项目行点击 → navPath.append(AppRoute.chat(...))。
    // createProject push 已移除 — 改 sheet 走 showCreateProject state。
    @State private var navPath = NavigationPath()

    // V0-fix-4 Fix 2: topLeft 5 tab 容器 (ProjectListView) 需要的项目列表
    // — 后续 WenshuStoreActor 接 .ws 后,这里换成 vm 持有 + onChange 同步。
    @State private var projects: [ProjectSnapshot] = []

    // V0-fix-6 Fix 1: + 按钮 sheet 显隐 state (替代 V0-fix-4 navPath push)。
    @State private var showCreateProject: Bool = false

    // V0-fix-6 Fix 5: 5 tab active state 顶层持有,@Binding 同步
    // ProjectListView — 标题栏 iconOnly Picker + ProjectListView segmented
    // Picker 共享同一 state (FCP toolbar 范式)。
    @State private var projectListActiveTab: ProjectManagementTab = .projects

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
                // V0-fix-6 Fix 1: + 按钮接 modal sheet 弹窗
                // (`.sheet(isPresented:)`), 替代 V0-fix-4 Fix 3 的
                // NavigationStack push — 装机 user 8/10 17:35 OOB 拍
                // "走弹窗不 push"。 sheet content 持有独立的本地 state,
                // 关闭后 onCreate/onCancel 回调走 LayoutShellView 顶层
                // 状态 (projects + showCreateProject)。
                .sheet(isPresented: $showCreateProject) {
                    ProjectCreateView(
                        onCreate: { newProject in
                            projects.append(newProject)
                            showCreateProject = false
                        },
                        onCancel: {
                            showCreateProject = false
                        }
                    )
                }
        }
    }

    // MARK: - Navigation destinations

    @ViewBuilder
    private func destinationView(for route: AppRoute) -> some View {
        switch route {
        case .createProject:
            // V0-fix-6: + 按钮已改 sheet, 这里走 placeholder 兜底避免
            // 编译期 enum 缺失报错。 实际不再 push createProject。
            VStack(spacing: 10) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(.secondary)
                Text("请用顶部 + 按钮弹窗新建项目")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
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

    // MARK: - Top header bar (V0-fix-4 Fix 1 + Fix 2 + V0-fix-6 Fix 1 + Fix 2 + Fix 5)

    /// 顶部跨全宽 38pt 标题栏 (AIF 16:40 拍板 — 替换 v0.02.0 顶部"文枢"标
    /// 题文字, FCP toolbar 风格: 红黄绿 traffic lights 后接 + 按钮 + 5 tab
    /// iconOnly Picker + Spacer)。 + 按钮接 modal sheet
    /// (`.sheet(isPresented: $showCreateProject)`, 替代 V0-fix-4 的
    /// NavigationStack push — 装机 user 8/10 17:35 OOB 拍"走弹窗不 push")。
    /// 5 tab iconOnly Picker 复用 ProjectManagementTab.symbolName 5 SF
    /// Symbol (folder / list.bullet.rectangle / slider.horizontal.3 /
    /// books.vertical / rectangle.split.3x1), 跟 ProjectListView 内部
    /// segmented Picker 共享同一 activeTab @Binding (FCP toolbar 范式)。
    private var topLeftHeaderBar: some View {
        HStack(spacing: 12) {
            Button {
                // V0-fix-6 Fix 1: + 按钮接 modal sheet 弹窗
                // (`.sheet(isPresented: $showCreateProject)`), 替代
                // V0-fix-4 Fix 3 的 `navPath.append(AppRoute.createProject)`。
                showCreateProject = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("新建项目")

            // V0-fix-6 Fix 2: 5 tab iconOnly Picker 升到标题栏
            // (HStack 内 + 按钮右侧), .pickerStyle(.iconOnly) 走
            // PickerStyle+IconOnly alias, 强制 Image-only 渲染 (macOS
            // 13 fallback 不显 SF Symbol 名字)。 activeTab @Binding 同
            // 步 ProjectListView 内部 segmented Picker (Fix 5 共享
            // state)。 注: v0.04.0 才会把 5 tab 容器完全下沉到
            // ProjectListView 内部 (摘除标题栏版), 本期保留双 picker
            // (标题栏 iconOnly + ProjectListView segmented) 同步态。
            Picker("", selection: $projectListActiveTab) {
                ForEach(ProjectManagementTab.allCases) { tab in
                    Image(systemName: tab.symbolName)
                        .tag(tab)
                        .help(tab.rawValue)
                }
            }
            .pickerStyle(.iconOnly)
            .help("项目管理标签")

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
                    // V0-fix-4 Fix 2: topLeft panel 渲染 ProjectListView
                    // 5 tab 容器 (项目 / 章节 / 设定 / 资料 / 看板),
                    // 共享 LayoutShellView 顶层的 projects + navPath。
                    // V0-fix-6 Fix 5: 增 activeTab @Binding — 标题栏
                    // iconOnly Picker 跟 ProjectListView segmented
                    // Picker 共享 activeTab state (FCP toolbar 范式)。
                    ProjectListView(
                        projects: $projects,
                        navPath: $navPath,
                        activeTab: $projectListActiveTab
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
