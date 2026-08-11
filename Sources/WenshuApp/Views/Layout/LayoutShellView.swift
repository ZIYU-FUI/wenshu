// LayoutShellView.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-01 → LT-01-fix9 → V0-fix-5 → LT-N1-merge → V0-fix-7 → V0-fix-9
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
// LT-N1-merge (2026-08-11): 合并 LT-N1-revise (4 P0 真修) 到 V0-fix-6 顶
// 层, 解决冲突。 沿 V0-fix-6 5 区 layout 不动 (topLeftHeaderBar 跨全宽
// header + 5 tab Picker + + 按钮 + panel(.topLeft) = ProjectListView),
// 但把 LT-N1 的 push 路由 + selectedProjectID 接入:
//   1. `navPath` 从 `NavigationPath` 改成 `[AppRoute]` (P0-2 fix:
//      NavigationPath 不公开 Sequence 接口, 我们需要 iterate 找
//      .detail(projectId:) 同步到 selectedProjectID)
//   2. 加 `@State selectedProjectID: UUID?` + `.onChange(of: navPath)`
//      同步: 从 path 中提取最后一个 `.detail(projectId:)` 写到
//      selectedProjectID, 供 panel(.topLeft) 的 ProjectListView 章节
//      tab 渲染 ChapterTreeView
//   3. `destinationView(for:)` 加 `.detail(projectId:)` case →
//      ProjectDetailView (LT-N1 P0-1 实装: Picker.segmented + 5 tab)
//   4. `panel(.topLeft)` = ProjectListView (V0-fix-6 5 tab 容器) +
//      selectedProjectID binding — 章节 tab 接 binding 渲染
//      ChapterTreeView (LT-N1 P0-2 fix: projectId 必须非可选 UUID)
//
// V0-fix-7 → V0-fix-9 修真完整历史:
//   V0-fix-7 (2026-08-11 18:05 CUA 自验拍板): 真修 V0-fix-6 被 LT-N1-merge
//     回滚的 2 处 UI BUG:
//     1. + 按钮改 modal sheet (替代 LT-N1-merge 回滚的 push)
//        - 加 `@State showCreateProject: Bool = false`
//        - + 按钮 action 改 `showCreateProject = true`
//        - NavigationStack 内顶级加 `.sheet(isPresented: $showCreateProject)`
//          弹 ProjectCreateView
//        - `navPath.append(AppRoute.createProject)` 删 (改 sheet 不 push)
//        - `destinationView(.createProject)` 改 placeholder 兜底
//        - `navPath` 仍服务 chat 路由 (项目行点击走 .detail(...))
//     2. 5 tab Picker 改 iconOnly + SF Symbol (替代 segmented Text)
//        - Picker 内容 `Text(tab.rawValue).tag(tab)` →
//          `Image(systemName: tab.symbolName).tag(tab).help(tab.rawValue)`
//        - `.pickerStyle(.segmented)` → `.pickerStyle(.iconOnly)`
//        - `.labelsHidden()` + `.fixedSize()` 删除
//        - 沿用 ProjectManagementTab.symbolName (V0-fix-4 5 SF Symbol)
//   V0-fix-8 (装机 user 8/11 16:20 真机拍 4 红字批注):
//     1. WindowGroup 删 "文枢" 字面量 (App.swift 修真), + 按钮移到 macOS
//        title bar (.toolbar ToolbarItem(.principal)) — 红字"新建按钮放在
//        这里, 替换文枢文字"
//     2. 5 tab Picker.segmented 改 HStack + 5 Button(Image) + .buttonStyle
//        (.plain) — 红字"项目、章节、设定、资料、看板改文字按钮为 ICON"
//        + 红字"所有 ICON 按钮, 只保留 ICON, 不要矩形背景, 仿 FCP"
//     3. topLeftHeaderBar 删原 + 按钮 (修真 #4 衍生 — 修真 #1 后避免
//        双 + 入口, FCP 单 + 范式) — 修真 V0-fix-7 modal sheet + 按钮
//     4. SF Symbol 沿 AIF 16:20 截图重定义: folder / doc.text /
//        gearshape / archive / square.grid.3x3 (替换 V0-fix-4 5 个)
//     5. ProjectManagementTab 新增 isEnabled 衍生 (3 disabled: settings /
//        resources / kanban — 沿 V0-fix-6 + ProjectBrowserView.ProjectTab
//        .enabled 拍板)
//   V0-fix-9 (装机 user 8/11 16:42 CUA 自验发现):
//     1. .navigationTitle("") 兜底修真 #1 完整 — WindowGroup { }
//        (修真 V0-fix-8) + .navigationTitle("") 显式覆盖 Info.plist
//        CFBundleDisplayName = "文枢" 默认 fallback, 让 macOS title bar
//        修真生效只显 + 按钮 (居中, ToolbarItem(.principal))。 红字真意
//        = "替换文枢文字", 不是共存 (装机 user 8/11 16:20 红字)。
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

    // LT-N1-merge: navPath 从 `NavigationPath` 改成 `[AppRoute]` (P0-2 fix:
    // NavigationPath 不公开 Sequence 接口, 我们需要在 .onChange 里 iterate
    // 找最近一个 `.detail(projectId:)` 同步到 selectedProjectID)。 AppRoute
    // 已 Hashable (MainView.swift), NavigationStack(path:) binding 行为不变。
    // 之前 V0-fix-4 拍 + 按钮 push AppRoute.createProject 用的也是顶层
    // state, 这里继续沿用, 仅换底层类型。
    @State private var navPath: [AppRoute] = []

    // V0-fix-4 Fix 2: topLeft 5 tab 容器 (ProjectListView) 需要的项目列表
    // — 后续 WenshuStoreActor 接 .ws 后,这里换成 vm 持有 + onChange 同步。
    @State private var projects: [ProjectSnapshot] = []

    // V0-fix-5: 5 tab Picker state 升到 LayoutShellView 顶层, 由
    // topLeftHeaderBar (跨全宽 38pt bar) 持 Picker.segmented, 与 + 按钮
    // 平级。 ProjectListView 接 @Binding activeTab, 共享同一 state。
    @State private var activeTab: ProjectManagementTab = .projects

    // LT-N1-merge: selectedProjectID 升到 LayoutShellView 顶层。 由
    // .onChange(of: navPath) 从 path 中提取最近一个 `.detail(projectId:)`
    // 写到 selectedProjectID, 供 ProjectListView 章节 tab 渲染
    // ChapterTreeView (LT-N1 P0-2 fix: ChapterTreeView.init 必须接
    // projectId: UUID 非可选)。 nil = 用户还没点项目 row。
    @State private var selectedProjectID: UUID?

    // V0-fix-7 BUG 1: + 按钮 modal sheet 显隐 state (替代 LT-N1-merge
    // 回滚的 `navPath.append(AppRoute.createProject)` push 路由)。 true
    // = sheet 弹出 (用户点 + 按钮), false = sheet 关闭 (用户点 取消 /
    // 创建 / X)。 sheet content = `ProjectCreateView`, 沿 V0-fix-6 Fix 1
    // 真值 (540x480 modal, form/focus/WindowActivation 兜底不动)。
    @State private var showCreateProject: Bool = false

    var body: some View {
        NavigationStack(path: $navPath) {
            geometryBody
                .frame(minWidth: 900, minHeight: 600)
                // V0-fix-8 修真 #1 完整生效: 显式 `.navigationTitle("")`
                // 覆盖 CFBundleDisplayName = "文枢" 默认 fallback, 让
                // macOS title bar 不显"文枢"两字 — + 按钮由 .toolbar
                // ToolbarItem(.principal) 接管 (FCP 单 + 入口范式)。
                // 红字真意 "新建按钮放在这里, 替换文枢文字" = 替换,
                // 不是共存。 沿 V0-fix-6 CFBundleName="Wenshu" 不动
                // (避免 macOS 菜单 title 副作用)。
                .navigationTitle("")
                .navigationDestination(for: AppRoute.self) { route in
                    destinationView(for: route)
                }
                // V0-fix-7 BUG 1: + 按钮 modal sheet 包裹 NavigationStack
                // 内顶级 (sheet 关联到主窗口 — FCP inspector sheet 风格,
                // 不挡 LayoutShellView, 用户透过 sheet 能看到 5 区布局)。
                // sheet content = ProjectCreateView (540x480 modal, 沿
                // V0-fix-1 Fix D 硬固定真值)。 onCreate / onCancel 闭包
                // 走 showCreateProject = false 关闭 sheet (替代 push 路由
                // 的 navPath.removeLast())。
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
                .task {
                    await vm.load()
                }
                // LT-N1-merge: navPath 变化时同步 selectedProjectID。
                // 用户在 ProjectListView 的项目 tab 点 row →
                // `navPath.append(.detail(projectId: id))` →
                // 这里提取 id → selectedProjectID → ProjectListView
                // 章节 tab 拿到 id 渲染 ChapterTreeView。
                .onChange(of: navPath) { _, newPath in
                    syncSelectedProjectID(from: newPath)
                }
                // V0-fix-8 (修真 #1): + 按钮由 .toolbar ToolbarItem
                // (.principal) 接管 (FCP 范式 单 + 入口 — 替代 macOS
                // title bar "文枢" 标题文字)。 ToolbarItem 必须挂在
                // NavigationStack 内的 view 才能渲染到 macOS title bar
                // (放 MainView / App.swift 不行 — 拿不到 navPath)。
                // 修真 #4 衍生: topLeftHeaderBar 原 + 按钮删, 避免双
                // + 入口。
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Button {
                            navPath.append(AppRoute.createProject)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("新建项目")
                    }
                }
        }
    }

    /// LT-N1-merge: 从 navPath 中提取最近一个 `.detail(projectId:)`
    /// 同步到 selectedProjectID。 走 path 倒序遍历, 拿最后一个 detail
    /// (栈顶最新的 detail)。
    private func syncSelectedProjectID(from path: [AppRoute]) {
        var lastDetail: UUID?
        for route in path {
            if case .detail(let id) = route {
                lastDetail = id
            }
        }
        if let id = lastDetail {
            selectedProjectID = id
        }
    }

    // MARK: - Navigation destinations

    @ViewBuilder
    private func destinationView(for route: AppRoute) -> some View {
        switch route {
        case .createProject:
            // V0-fix-7 BUG 1: + 按钮改 modal sheet 后, .createProject
            // 路由不再被 + 按钮消费 (sheet 是真路由)。 保留 enum case
            // 不破坏外部引用 (LT-N1-merge 真值), 这里走 placeholder
            // 兜底 — 万一外部代码还残留 push AppRoute.createProject 也
            // 不会白屏。 沿 V0-fix-6 真值。
            VStack(spacing: 10) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(.secondary)
                Text("请用顶部 + 按钮新建项目")
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
        // LT-N1-merge: 项目详情 destination (P0-1 fix: Picker.segmented
        // + 5 tab 居中铺满, 见 ProjectDetailView.swift + DESIGN-LT-N1
        // §5)。 用户在 ProjectListView 项目 tab 点 row →
        // navPath.append(.detail(projectId: id)) → 这里渲染
        // ProjectDetailView。 push 覆盖整 layout (V0-fix-6 design:
        // NavigationStack 在 LayoutShellView 顶层), 跟 ProjectBrowserView
        // 自挂 NavigationStack 的 LT-N1 原案不同 — 沿 V0-fix-6 拍板。
        case .detail(let projectId):
            ProjectDetailView(projectId: projectId)
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

    // MARK: - Top header bar (V0-fix-4 Fix 1 + Fix 3 → V0-fix-5 5 tab Picker 升 header → V0-fix-7 modal sheet + iconOnly ICON)

    /// 顶部跨全宽 38pt 标题栏 (AIF 16:40 拍板 — 替换 v0.02.0 顶部"文枢"标
    /// 题文字, FCP toolbar 风格: 红黄绿 traffic lights 后接 5 tab ICON +
    /// Spacer)。
    ///
    /// V0-fix-5 拍板: 5 tab Picker (项目 / 章节 / 设定 / 资料 / 看板) 从
    /// ProjectListView 内部搬到这里 — 与原 + 按钮平级 (同 38pt 高)。
    /// ProjectListView 改接 `@Binding activeTab` 共享同一 state。
    ///
    /// V0-fix-7 → V0-fix-9 修真完整:
    ///   - V0-fix-7: + 按钮改 modal sheet + 5 tab Picker 改 iconOnly
    ///   - V0-fix-8: 删 + 按钮 (修真 #4 衍生) + 5 tab Picker.segmented 文字
    ///     标签改 HStack + 5 Button(Image) + `.buttonStyle(.plain)` —
    ///     红字 "5 tab 改 ICON" + 红字 "所有 ICON 按钮, 只保留 ICON, 不
    ///     要矩形背景, 仿 FCP"。 SF Symbol 沿 AIF 16:20 截图重定义真值:
    ///     folder / doc.text / gearshape / archive / square.grid.3x3
    ///     (替换 V0-fix-4 的 5 个)
    ///   - V0-fix-9: disabled tab (设定 / 资料 / 看板) 走
    ///     ProjectManagementTab.isEnabled 衍生 (修真 V0-fix-8 真值, 沿
    ///     V0-fix-6 + ProjectBrowserView.ProjectTab.enabled 拍板)
    private var topLeftHeaderBar: some View {
        HStack(spacing: 4) {
            // V0-fix-9: 5 tab HStack + 5 Button(Image) + .buttonStyle(.plain)
            // (修真 V0-fix-7 Picker(.iconOnly) + 修真 V0-fix-8 修真 — 红字
            // "5 tab 改 ICON" + "不要矩形背景, 仿 FCP")
            ForEach(ProjectManagementTab.allCases) { tab in
                Button {
                    activeTab = tab
                } label: {
                    Image(systemName: tab.symbolName)
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 32, height: 24)
                        .foregroundStyle(activeTab == tab ? Color.accentColor : .secondary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(tab.rawValue)
                .disabled(!tab.isEnabled)
            }

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
                    // V0-fix-5 (沿用, LT-N1-merge 拍板保留): ProjectListView
                    // 容器跨 header bar + panel(.topLeft) 双区 — 5 tab
                    // Picker 在 header bar (topLeftHeaderBar), tab 内容
                    // (项目列表 / 章节树 / 设定 / 资料 / 看板) 在 panel
                    // 内, 共享 activeTab binding (顶层 LayoutShellView
                    // @State, header bar 持有 Picker, panel 内 ProjectListView
                    // 接 binding)。 LT-N1-merge 在此接 selectedProjectID
                    // binding, 让 ProjectListView 章节 tab 拿到 id 后
                    // 渲染 ChapterTreeView (LT-N1 P0-2 fix 真值)。
                    //
                    // 派单 LT-N1-merge 拍板: topLeft = ProjectListView
                    // (V0-fix-6 5 tab 容器), 不挂 ProjectBrowserView
                    // (LT-N1 原案是 ProjectBrowserView 自挂 NavigationStack
                    // 让 push 只影响 topLeft, 但 V0-fix-6 拍 NavigationStack
                    // 在 LayoutShellView 顶层, push 覆盖整 layout —
                    // 沿 V0-fix-6 真值)。
                    ProjectListView(
                        projects: $projects,
                        navPath: $navPath,
                        activeTab: $activeTab,
                        selectedProjectID: $selectedProjectID
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
