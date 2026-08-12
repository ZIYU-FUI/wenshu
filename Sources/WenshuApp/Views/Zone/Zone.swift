// Zone.swift · 文枢 (Wenshu) · v0.05.0 Zone 协议 wrapper
//
// 5 区布局的协议 + context 注入点 (沿 DESIGN-Zone.md §4 + DECISION-5ZONE-2026-08-12.md §4.2 #2)。
// 单 module, 5 个 Zone 入口 View (TopLeftZone / TopCenterZone / TopRightZone / BottomLeftZone / BottomRightZone)
// + ZoneRenderer 协议 + ZoneContext 6 字段 struct (panelID + 5 binding)。
//
// 红线 (沿 DECISION §4.3 + DESIGN-Zone.md §4.2 关键差异):
//   - 不拆 SPM (单 module)
//   - 不加 ProjectStoreReader / StoreActorReader (ZoneContext 不暴露 store/actor)
//   - 不加 ViewModel 关联类型 (ZoneRenderer 只约束 context: ZoneContext)
//   - 不实装 bottomRight 内容 (BottomRightZone 仅占位)
//
// ZoneRenderer 的 associatedtype Body + context 是协议最小约束, 5 Zone 各自实现
// body() 返回具体入口 View (e.g. TopLeftZone → ProjectListView)。

import SwiftUI

// MARK: - ZoneContext

/// 5 区入口 View 共享的 binding 注入点 (沿 DESIGN-Zone.md §4.1 + §6 binding 表)。
///
/// 字段数 = 6 (panelID + 5 binding, 其中 activeTab 仅 topLeft 接收)。
///
/// 5 Zone binding 接收非均匀分布 (避免 god object):
///   - TopLeftZone:    4 binding (projects / navPath / activeTab / selectedProjectID)
///   - TopCenterZone:  2 binding (selectedProjectID / selectedChapterID)
///   - TopRightZone:   0 binding (走 InspectorViewModel.shared 单例)
///   - BottomLeftZone: 0 binding (走 ChatViewModel env obj)
///   - BottomRightZone:0 binding (占位)
struct ZoneContext {
    let panelID: PanelID                                      // 5 区身份 (沿 LayoutShellViewModel.swift PanelID enum)

    // 4 binding (沿 DECISION §6 + ARCH-5ZONE §2.2 共享物表真值)
    let selectedProjectID: Binding<UUID?>                     // 顶层 @State (LayoutShellView.swift)
    let selectedChapterID: Binding<String?>                   // 顶层 @State (LayoutShellView.swift)
    let navPath: Binding<[AppRoute]>                          // 顶层 @State (LayoutShellView.swift)
    let projects: Binding<[ProjectSnapshot]>                  // 顶层 @State (LayoutShellView.swift)

    // 1 binding (DECISION §6 "由 designer 细化" → 加)
    // 跨 topLeftHeaderBar (5 tab Picker) + topLeft panel (tab content 切) 双区持有,
    // 跟 selectedProjectID / navPath 同级, 必须加 (沿 DESIGN-Zone.md §4.1).
    let activeTab: Binding<ProjectManagementTab>              // 顶层 @State (LayoutShellView.swift), 仅 topLeft 用
}

// MARK: - ZoneRenderer 协议

/// Zone 入口 View 协议 (沿 DESIGN-Zone.md §4.2)。
///
/// 关键差异 (vs ARCH-5ZONE §5.1 初版):
///   1. 不加 ViewModel 关联类型 (沿 DECISION §4.2 #2 "不拆 SPM" 红线) — ViewModel 由
///      各 Zone 内部持有 (e.g. InspectorViewModel.shared 单例 / ChatViewModel env obj),
///      Zone 协议不约束 ViewModel 类型。
///   2. protocol 不可知具体 View 类型 — 只约束 context 字段 + render() 渲染, 不约束具体
///      View 子类 (e.g. 不写 init(context:))。
///
/// 实现约束: ZoneRenderer 不继承 View, 只约束 context + render() (不名 `body` 避免
/// 跟 SwiftUI View.body 冲突)。 每个 Zone struct 自接 View, body computed property
/// 转调 render() (沿 DESIGN-Zone.md §4.3 CC 实施时校正, 原案 `func body()` 在协议层
/// 不能满足 `View.body: some View` 的 computed property 需求)。
@MainActor
protocol ZoneRenderer {
    associatedtype Content: View
    var context: ZoneContext { get }
    @ViewBuilder func render() -> Self.Content
}

// MARK: - 5 Zone 入口 View

/// 左上 (topLeft) 区入口 — 项目列表 + 5 tab 容器 (沿 ProjectListView 224 行代码)。
struct TopLeftZone: View, ZoneRenderer {
    let context: ZoneContext
    var body: some View { render() }
    func render() -> some View {
        ProjectListView(
            projects: context.projects,
            navPath: context.navPath,
            activeTab: context.activeTab,
            selectedProjectID: context.selectedProjectID
        )
    }
}

/// 中上 (topCenter) 区入口 — 编辑器 (顶 toolbar + 章节 sidebar + TextEditor + 底 toolbar, 沿 DESIGN-LT-N3.md §5.1)。
struct TopCenterZone: View, ZoneRenderer {
    let context: ZoneContext
    var body: some View { render() }
    func render() -> some View {
        EditorView(
            selectedProjectID: context.selectedProjectID,
            selectedChapterID: context.selectedChapterID
        )
    }
}

/// 右上 (topRight) 区入口 — Inspector (伏笔 + 修订 2 tab, 沿 LT-02 v2 + V0-fix-4 + V0-fix-11)。
/// ViewModel 由 InspectorView 内部接 InspectorViewModel.shared 单例, 不走 ZoneContext。
struct TopRightZone: View, ZoneRenderer {
    let context: ZoneContext
    var body: some View { render() }
    func render() -> some View { InspectorView() }
}

/// 下左 (bottomLeft) 区入口 — 聊天区 (聊天实装 + 时间线/关系图/大纲 disabled, 沿 WO-LT-04 + V0-fix-4/6/8/11)。
/// ChatViewModel 由 ChatPanelView env obj 接, 不走 ZoneContext。
struct BottomLeftZone: View, ZoneRenderer {
    let context: ZoneContext
    var body: some View { render() }
    func render() -> some View { ChatPanelView() }
}

/// 下右 (bottomRight) 区入口 — 占位 (v0.03.0+ 实装, 沿 DESIGN-Zone.md §4.3 占位范式)。
/// 仅渲染 PlaceholderContent, 不实装内容。
struct BottomRightZone: View, ZoneRenderer {
    let context: ZoneContext
    var body: some View { render() }
    func render() -> some View { PlaceholderContent(panel: .bottomRight) }
}