# v0.05.0 Zone wrapper 协议 — DESIGN-Zone.md

> **报告 ID**: DESIGN-Zone-2026-08-12
> **拍板源**: AIF 拍板真值 `DECISION-5ZONE-2026-08-12.md` (t_89f925da) §4.2 5 项执行约束 + §6 备注"由 designer 在 DESIGN-Zone.md 细化"
> **作者**: designer (本卡 t_b7d1fa55)
> **前置真值**: ARCH-5ZONE §1-3 (PM-direct 调研 t_781e1607) + REVIEW-ARCH-5ZONE §2-7 (reviewer 验收 t_5ac32075)
> **范围**: Zone protocol 签名 + ZoneContext binding 表 + PanelContainer 接口 + ProjectListView 14 ref 处理范式
> **边界 (designer 红线)**: 不写代码 / 不测像素 / 不跑 swift build / 不选 ICON 库 / 不写 Python 脚本 / 不 commit / 不实装 bottomRight 内容 / 不加持久层协议 / 不拆 SPM

---

## 1. 背景

AIF 拍板真值 `DECISION-5ZONE-2026-08-12.md` §4.1 = **选 B 方案 (Zone/ 目录法, 2-3 人天渐进)**, §4.2 列 5 项执行约束,§6 第 6 段写明"ZoneContext binding 4 个 + activeTab + panelID ... 由 designer 在 DESIGN-Zone.md 细化 (是否需 projectStoreReader, 沿 4.3 红线不加)"。reviewer §5 4 项回归风险点中 3 项需 designer 决策:
- 风险点 2: PanelContainer / Zone.swift 接口签名拍走样 → View 取不出来
- 风险点 3: ZoneContext binding 集中 → 变 god object
- 风险点 4: ProjectListView init 14 ref 散点 → Zone wrapper 改 init 较散

本设计稿细化 DECISION §4.2 #2 (协议签名) / §4.2 #3 (panel 改 switch) / §4.2 #4 (ViewModel 收口) / §6 (binding 表) + reviewer §5 风险点 2/3/4 决 wrapper 形式。

on-disk 调研结论 (沿 DECISION §3 6 项偏差校正后):

| 真值项 | 数据 |
|--------|------|
| swift 文件总数 | 23 (非 47) |
| panel() 实际分支 | 5 个具体 if-else + PlaceholderContent fallback (topLeft/topCenter/topRight/bottomLeft 4 个 + 1 fallback) |
| ProjectListView 引 LayoutShellView | 14 次 (binding 形式, 非 import) |
| Project/{ProjectDetailView,ChapterTreeView} 引 LayoutShellView | 5 次 |
| EditorView 引 LayoutShellView | 2 次 (注释) |
| LayoutShellView 顶层 @State | 6 个 (`navPath` / `projects` / `activeTab` / `selectedProjectID` / `selectedChapterID` / `showCreateProject`) |
| EditorViewModel `isFullScreen` | 当前是 `@State` (EditorView.swift:30),**未升 ViewModel**;DESIGN-LT-N3 §4 预过 ViewModel 但 v0.04.0 没实装 |
| InspectorViewModel `selectedTab` | `@Published` 未 `private(set)` (line 72) |

---

## 2. 三套方案对照 (沿 DECISION §2)

| 维度 | A (SPM 拆) | **B (Zone/ 目录) ← 拍板** | C (B + 持久层协议) |
|------|-----------|------------------------|---------------------|
| 迁移人天 | 5-7 | **2-3** | 3-4 |
| 后续迭代收益 | 高 | 中 | 中+ |
| 跨区通信复杂度 | 高 (ZoneContext god object) | 中 (4-5 binding 集中) | 中 (同 B) |
| 构建时间 | +30-60% | **0** | 0 |
| 风险 | 高 (god object / 协议漏) | **低 (渐进, 任步独立 PR)** | 低 (over-engineering) |
| 老板要求满足度 | ✅ 完全 | ⚠️ 部分 (Zone/ + 必要 switch case) | ⚠️ 部分 (同 B) |

沿 DECISION §2 拍板 = **B 方案**,理由全沿 DECISION §4.1 + §5。本设计稿全表抄录,不复述选 B 理由 (沿 AGENTS §13.3 第 4 条反仪式措辞)。

---

## 3. 拍板结论 (细化为本设计稿可执行)

DECISION §4.2 列 5 项约束,本设计稿对每项给出**可执行的协议层细节**:

| DECISION §4.2 约束 | 本设计稿细化 |
|-------------------|------------|
| #1 物理目录重命名 (ZoneTopLeft / ZoneTopCenter / ZoneTopRight / ZoneBottomLeft / ZoneBottomRight) | ✓ 接受 ARCH-5ZONE §5.1 + DECISION BUG-1 校正(ProjectListView 在 root, 不在 `Project/` 子目录) |
| #2 Zone.swift 协议 wrapper (associatedtype Body + context: ZoneContext) | 本稿 §4 |
| #3 panel() 改 switch 5 case + ZoneContext 注入 | 本稿 §5 |
| #4 ViewModel 收口 (EditorViewModel `isFullScreen` 改 `private(set)` + InspectorViewModel 加 `@MainActor private(set)`) | 本稿 §7 (校 on-disk 真值,见 §7.3 修正) |
| #5 bottomRight 占位 View 留 v0.03.0+ | ✓ 沿 PlaceholderContent fallback |

DECISION §6 第 6 段"ZoneContext binding 由 designer 细化 (是否需 projectStoreReader)" → 本稿 §6 (结论 = **不加 store/actor reader, 沿 DECISION §4.3 红线 #2**)。

DECISION §4.3 红线:
- **不拆 SPM** ✓ 本稿不涉及
- **不加 ProjectStoreReader / StoreActorReader** ✓ 本稿 §6 显式不注入 store

---

## 4. Zone protocol 完整签名

### 4.1 ZoneContext 结构 (binding 集中点)

```swift
// 文件落点: Sources/WenshuApp/Views/Zone/Zone.swift (新加, 6 文件共享 1 份协议)

struct ZoneContext {
    let panelID: PanelID                                      // 5 区身份 (沿 PanelID enum, LayoutShellViewModel.swift:362)

    // 4 binding (沿 DECISION §6 + ARCH-5ZONE §2.2 共享物表真值)
    let selectedProjectID: Binding<UUID?>                     // 顶层 @State (LayoutShellView.swift:168)
    let selectedChapterID: Binding<String?>                   // 顶层 @State (LayoutShellView.swift:176)
    let navPath: Binding<[AppRoute]>                          // 顶层 @State (LayoutShellView.swift:152)
    let projects: Binding<[ProjectSnapshot]>                  // 顶层 @State (LayoutShellView.swift:156)

    // 1 binding (DECISION §6 "由 designer 细化" → 加)
    let activeTab: Binding<ProjectManagementTab>              // 顶层 @State (LayoutShellView.swift:161), 仅 topLeft 用
    // 注: activeTab 是 ProjectManagementTab (5 tab Picker 在 LayoutShellView.topLeftHeaderBar),
    //     不是 ChatPanelTab (后者在 ChatPanelView 内 @State 局部持有, 不跨区)
}
```

**字段数 = 6** (panelID + 5 binding, 其中 activeTab 仅 topLeft 接收)。

**为何 6 字段而非 5**: DECISION §6 第 6 段注释明确"是否需 projectStoreReader",本稿决 = 不加 store reader,但 activeTab 必须加。理由:
- activeTab 是 LayoutShellView 顶层 @State, 跨 topLeftHeaderBar (5 tab Picker) + ProjectListView (tab content 切) 双区持有, 跟 selectedProjectID / navPath 同级 (沿 ARCH-5ZONE §2.2 "activeTab: 否 (topLeft 区内)" 标记错, 实则跨 topLeft header + content)
- 缺 activeTab → Zone wrapper 改 ProjectListView init 时丢失 tab 状态, 必须加
- 其它 4 binding (selectedProjectID / selectedChapterID / navPath / projects) 沿 DECISION §6 真值

**ZoneContext 不注入 store / actor** (沿 DECISION §4.3 红线 #2):
- Zone 内部需要持久层 → 走已有模式 (`@EnvironmentObject` / `@StateObject` 在各自 View 内)
- ChatViewModel 已在 App.swift init 注入 env obj, ChatPanelView 接 `@EnvironmentObject`, 不走 ZoneContext
- WenshuProjectStore.shared / WenshuStoreActor.shared 由各 View 内部取, ZoneContext 不暴露

### 4.2 ZoneRenderer 协议 (沿 ARCH-5ZONE §5.1)

```swift
protocol ZoneRenderer: View {
    associatedtype Body: View
    var context: ZoneContext { get }
    @ViewBuilder func body() -> Self.Body
}
```

**关键差异 (vs ARCH-5ZONE §5.1 初版)**:

1. **不加 ViewModel 关联类型**: ARCH §4.1 方案 A 提 `associatedtype ViewModel: ObservableObject`, 本稿 (沿 DECISION §4.2 #2 "不拆 SPM" 红线) **不加** ViewModel 关联类型。理由:
   - ViewModel 仍由各 Zone 内部持有 (e.g. InspectorViewModel.shared 单例 / ChatViewModel env obj), Zone 协议不约束 ViewModel 类型
   - 加 ViewModel 关联类型 → Zone 必须有 init(context: ZoneContext, viewModel: VM) → god object 风险升级 (沿 reviewer §5 风险点 3)

2. **protocol 不可知具体 View 类型**: 协议只约束 `context` 字段 + body 渲染, 不约束具体 View 子类 (e.g. 不写 `init(context:)`)

### 4.3 5 Zone 入口 View (各 Zone/ 目录内)

```swift
// Sources/WenshuApp/Views/ZoneTopLeft/Zone.swift
struct TopLeftZone: ZoneRenderer {
    let context: ZoneContext
    func body() -> some View {
        ProjectListView(
            projects: context.projects,
            navPath: context.navPath,
            activeTab: context.activeTab,
            selectedProjectID: context.selectedProjectID
        )
    }
}

// Sources/WenshuApp/Views/ZoneTopCenter/Zone.swift
struct TopCenterZone: ZoneRenderer {
    let context: ZoneContext
    func body() -> some View {
        EditorView(
            selectedProjectID: context.selectedProjectID,
            selectedChapterID: context.selectedChapterID
        )
    }
}

// Sources/WenshuApp/Views/ZoneTopRight/Zone.swift (Zone 入口, ViewModel 由 InspectorView 内部接)
struct TopRightZone: ZoneRenderer {
    let context: ZoneContext
    func body() -> some View { InspectorView() }   // 现有 InspectorView 接 InspectorViewModel.shared @ObservedObject 不动
}

// Sources/WenshuApp/Views/ZoneBottomLeft/Zone.swift (ChatViewModel 由 ChatPanelView env obj 接)
struct BottomLeftZone: ZoneRenderer {
    let context: ZoneContext
    func body() -> some View { ChatPanelView() }
}

// Sources/WenshuApp/Views/ZoneBottomRight/Zone.swift (占位, v0.03.0+ 实装)
struct BottomRightZone: ZoneRenderer {
    let context: ZoneContext
    func body() -> some View { PlaceholderContent(panel: .bottomRight) }
}
```

**ZoneContext 字段接收率** (binding 实际使用, 校 god object 风险):
- TopLeftZone: 用 4 binding (projects/navPath/activeTab/selectedProjectID), 不用 selectedChapterID
- TopCenterZone: 用 2 binding (selectedProjectID/selectedChapterID), 不用 projects/navPath/activeTab
- TopRightZone: 0 binding, 走 InspectorViewModel.shared 单例
- BottomLeftZone: 0 binding, 走 ChatViewModel env obj
- BottomRightZone: 0 binding, 占位

→ 5 Zone binding 接收**非均匀分布**, reviewer §5 风险点 3 "god object" 缓解: ZoneContext 字段多但**实际使用分散**, 不构成 god object (god object = 多数 View 都用全部字段)。CC 实施时 reviewer 核 binding 接收图。

---

## 5. PanelContainer 接口

**沿用现有 `PanelContainer` 签名, 不改接口** (沿 DECISION §4.2 #2 "Zone.swift 协议 wrapper", PanelContainer 是 Zone 容器, 不是 Zone 协议本身):

```swift
// 现有签名 (PanelContainer.swift:33) 不动
struct PanelContainer<Content: View>: View {
    let panelID: PanelID
    @ViewBuilder var content: () -> Content
    var body: some View { content()... }
}
```

`PanelContainer` 是 **Zone 的容器 (chrome = 背景 + border)**, 不是 Zone 协议本身。Zone 协议在 `Zone.swift`,PanelContainer 在 `Views/Layout/PanelContainer.swift` 不动。

**CollapsedGutter / CollapsedHeader 不动** (沿 Q2 折叠态 t_c6f48f43 + DESIGN-Q2-panel-collapse.md 拍板,本卡不改)。

### 5.1 LayoutShellView.panel(_:width:) 改 switch (沿 DECISION §4.2 #3)

```swift
// 当前实现: LayoutShellView.swift:658-728 (5 if/else)
// 新实现 (CC 写, designer 不写代码, 此处仅给伪码):

private func panel(_ id: PanelID, width: CGFloat) -> some View {
    if !vm.isVisible(id) { return AnyView(EmptyView()) }
    if isCollapsed(id) {
        return AnyView(/* 折叠态分支, 沿 CollapsedGutter / CollapsedHeader 现有逻辑 */)
    }
    let context = ZoneContext(
        panelID: id,
        selectedProjectID: $selectedProjectID,
        selectedChapterID: $selectedChapterID,
        navPath: $navPath,
        projects: $projects,
        activeTab: $activeTab
    )
    return AnyView(PanelContainer(panelID: id) {
        switch id {
        case .topLeft:    TopLeftZone(context: context)
        case .topCenter:  TopCenterZone(context: context)
        case .topRight:   TopRightZone(context: context)
        case .bottomLeft: BottomLeftZone(context: context)
        case .bottomRight: BottomRightZone(context: context)
        }
    }
    .frame(width: width))
}
```

**改 switch 的关键变化**:
- 折叠态分支保留 (Q2 折叠态不动, 沿 t_c6f48f43)
- 5 if-else + PlaceholderContent fallback → switch 5 case (无 fallback, 加新区 = 加 1 case)
- `AnyView(...)` 包 switch 是因为 switch 在 `@ViewBuilder` 闭包内做 case 返回 `some View` 类型擦除 (沿 SwiftUI 范式, AnyView 性能成本 = 5 个, v0.05 阶段门可接受)

---

## 6. ZoneContext binding 表 (细化 DECISION §6)

| binding | 顶层 @State 来源 | 接收 Zone | 备注 |
|---------|----------------|---------|------|
| `selectedProjectID: Binding<UUID?>` | LayoutShellView.swift:168 | TopLeftZone / TopCenterZone | 跨 topLeft + topCenter 双区 (沿 LT-N1-merge §3 + LT-N3 §5.1) |
| `selectedChapterID: Binding<String?>` | LayoutShellView.swift:176 | TopCenterZone (ChapterTreeView row click → EditorView 加载) | 跨 topLeft (push 路由) + topCenter (双 binding) |
| `navPath: Binding<[AppRoute]>` | LayoutShellView.swift:152 | TopLeftZone (ProjectListView 章节 tab push) | 沿 LT-N1-merge §3 (NavigationStack 在 LayoutShellView 顶层, push 覆盖整 layout) |
| `projects: Binding<[ProjectSnapshot]>` | LayoutShellView.swift:156 | TopLeftZone (ProjectListView.projectList) | topLeft 区 + topLeft + 按钮 modal (ProjectCreateView) |
| `activeTab: Binding<ProjectManagementTab>` | LayoutShellView.swift:161 | TopLeftZone (ProjectListView tabContent) | 跨 topLeftHeaderBar (5 tab Picker) + topLeft panel (tab content) |

**5 binding 真值** (沿 ARCH-5ZONE §2.2 共享物表 + 本稿调研 on-disk 校正):
- ARCH §2.2 报告 4 binding + activeTab 标记"否 (topLeft 区内)" — **本稿校正**: activeTab 实则跨 topLeft header bar + panel 内, **是跨区 binding** (跨 2 子组件, 但同 1 个 Zone 内)
- ARCH §2.2 报告 `showCreateProject` 未列 — 顶层 @State 之一 (LayoutShellView.swift:183), 沿 V0-fix-7 BUG 1 修真 sheet 显隐, **不入 ZoneContext** (本 Zone 协议不约束 modal 状态, 由 LayoutShellView 顶层 sheet 显隐控制, modal 不属于 5 Zone)

**不注入 ZoneContext 的字段**:
- `showCreateProject: Bool` (顶层 modal sheet 显隐, 不属于 5 Zone 内容)
- `WenshuProjectStore.shared` / `WenshuStoreActor.shared` (沿 DECISION §4.3 红线 #2)
- 持久层协议 `ProjectStoreReader` / `StoreActorReader` (沿 DECISION §4.3 红线 #2, v0.06+ 视增长再拍)

---

## 7. ProjectListView 14 ref 处理范式 (沿 reviewer §5 风险点 4)

### 7.1 现状真值

- `Sources/WenshuApp/Views/ProjectListView.swift` (root, 224 行, 沿 DECISION §3.1 BUG-1 校正)
- 引 LayoutShellView 14 次 (沿 reviewer §2.1 校正后 on-disk 真值)
- 当前 init: `@Binding var projects: [ProjectSnapshot]` / `@Binding var navPath: [AppRoute]` / `@Binding var activeTab: ProjectManagementTab` / `@Binding var selectedProjectID: UUID?` (4 binding)
- 14 ref 散点分布: 注释引用 (LayoutShellView 顶层 @State 起源解释) + binding 引用 (4 个 @Binding 字段) + body / onChange 引用

### 7.2 处理范式 = 整体改接 ZoneContext 单 ref (沿 DECISION §4.2 #2)

**关键决: 整体改接 ZoneContext 单 ref, 不保留 4 binding init**。

理由:
1. **改 init 4 binding → 改 init 1 ZoneContext**: TopLeftZone 已经是 1 个 context 字段, ProjectListView 同步改 1 个 context 字段 (ZoneContext 类型), 4 binding 集中改 1 处, **不是 4 处**
2. **DESIGN-LT-N3.md §4 路径一致**: EditorView 已接 2 binding (沿 LT-N3 §5.3), 但 v0.05 拍 Zone/ 时一并改 = TopCenterZone 也接 context.selectedProjectID / context.selectedChapterID (2 binding 变 2 context.field 引用, 改 1 处)
3. **reviewer §5 风险点 4 缓解**: "Zone wrapper 改 init 时 ProjectListView 14 ref 散点需逐一处理" → 14 ref 中, **真正需要改的** = 4 binding field + 内部使用点 (4 field 已合并到 1 context field); **注释引用** (10 次) 不改 (注释解释 LayoutShellView 顶层 @State 起源, 拍 Zone/ 后起源 = ZoneContext 字段, 注释可以更新但不改语义)。CC 实施时:
   - 改 4 binding → 1 context field (ProjectListView.swift:104/109/113/120)
   - 改内部使用点: `projects.isEmpty` → `context.projects.isEmpty` / `navPath.append(...)` → `context.navPath.append(...)` / `activeTab` → `context.activeTab` / `selectedProjectID` → `context.selectedProjectID`
   - 注释引用: 10 处解释 LayoutShellView 起源 → 改 ZoneContext 起源 (更新注释, 不删注释, 留设计史)

### 7.3 on-disk 校正 (DECISION §4.2 #4 真值漂移)

**DECISION §4.2 #4 原文**:
> EditorViewModel `@Published var isFullScreen` 改 `private(set)`, InspectorViewModel 加 `@MainActor private(set)` 收口。

**on-disk 真值校正**:
- EditorView.swift:30 = `@State private var isFullScreen: Bool = false` (在 EditorView 内, **不在 EditorViewModel**)
- EditorViewModel 不存在独立类 (DESIGN-LT-N3.md §4 预过 ViewModel 但 v0.04.0 没实装, 沿 8/12 LT-N3 verdict §X)
- InspectorViewModel.swift line 72 = `@Published var selectedTab: Tab = .foreshadow` (未 `private(set)`)
- InspectorViewModel 已 `@MainActor` (line 34)

**CC 实施时校正**:
- `isFullScreen` 当前在 EditorView `@State` → 拍 Zone/ 时**升级**为独立 EditorViewModel 类 (沿 DESIGN-LT-N3.md §4 预过路径), `@Published private(set) var isFullScreen`, EditorView 改 `@StateObject private var vm = EditorViewModel()`, 把 isFullScreen 改 `vm.isFullScreen`, toggle 改 `vm.isFullScreen.toggle()`
- InspectorViewModel line 72 `@Published var selectedTab` → 加 `private(set)`, write access 收口到 VM 内部 method (`selectTab(_ tab:)`), InspectorView 接 `.environmentObject` / `.observedObject` 调 `vm.selectTab(.revision)` 而非 `vm.selectedTab = .revision`

**本稿不写 ViewModel 代码** (designer 红线),只标 on-disk 真值校正。

---

## 8. 风险 (沿 DECISION §7 + reviewer §5)

| 风险点 | 概率 | 缓解 (designer 决) |
|--------|------|---------------------|
| ZoneContext 6 字段 → god object 风险 | 中 | 校 binding 接收率 (§4.3), 实际使用分散, 5 Zone 中只有 TopLeftZone 用 4 binding / TopCenterZone 用 2 binding, 其它 3 Zone 0 binding |
| Zone protocol 加 ViewModel 关联类型 → 类型耦合 | 中 | **本稿决 = 不加** (§4.2 关键差异 #1) |
| ProjectListView 14 ref 散点改 init 较散 | 中 | 整体改接 ZoneContext 单 ref (§7.2), 注释引用 10 处保留设计史, 真改 4 binding → 1 context field + 4 内部使用点 |
| EditorViewModel 不存在, `isFullScreen` 还在 @State | 中 | CC 实施时按 §7.3 校正, 升级为 EditorViewModel 类 |
| InspectorViewModel `selectedTab` 未 `private(set)` | 低 | §7.3 收口校正 |
| bottomRight 占位 View 与未来实装接口签名不一致 | 低 | BottomRightZone 走 ZoneRenderer 协议 (§4.2), v0.03.0+ 实装 = 改 body() 内容, 协议不动 |
| SPM 单 module 保留 → 真要拆时仍需二次重构 | 中 | 沿 DECISION §4.3 红线 #1, v0.06+ 视增长再拍 A |
| CC tech-review 卡 t_2b06d349 未出报告 | 中 | 沿 reviewer §6 Q2 不阻塞本拍板, designer 出稿后 CC 实施时 reviewer 核 |

---

## 9. 回退 (沿 DECISION §8)

| 触发条件 | 回退动作 |
|---------|---------|
| designer 出稿时发现 B 方案某边界无法满足 (e.g. Zone wrapper 改 init 涉及 14 ref 散点实际 > 2-3 人天) | AIF 重拍 A 或 C, 派修正卡给 PM-direct CC reviewer 原 owner |
| §14.9 老板预验不通过 | AIF 沿 §3.9 + §4 段 12 b 不合 main, 派修正卡回 PM-direct CC reviewer 原 owner |
| CC 实施时 swift build 失败 (e.g. ZoneRenderer protocol 类型擦除错误) | reviewer 派修卡, designer 不写代码, 沿 CC 红线 |

---

## 10. 签字 + STATE.md 落点

| 字段 | 真值 |
|------|------|
| 设计稿 ID | DESIGN-Zone-2026-08-12 |
| 设计稿作者 | designer (本卡 t_b7d1fa55) |
| 拍板真值源 | AIF DECISION-5ZONE-2026-08-12.md (t_89f925da §4.2 5 约束 + §6 6 binding) |
| 调研真值源 | ARCH-5ZONE §1-3 (t_781e1607) + REVIEW-ARCH-5ZONE §2-7 (t_5ac32075) |
| 派生下游 | CC (cc-runner 沿 §3.8 v0.04.0 CC-直通, t_8fc5c872) 实施 B 方案 + 5 约束 + 本稿细化 |
| 备份路径 | designer 卡 → CC 实施卡 → reviewer 核 → AIF §14.9 老板预验 → my-pm §4 段 12 b 合 main |
| **STATE.md 落档** (1 行 ≤ 30 字) | 沿 AGENTS §13.1 真值 `.hermes/STATE.md` (本卡由 AIF 阶段门聚合时拉 kanban_comment 落) |
| 红线确认 | 不拆 SPM ✓ / 不加 ProjectStoreReader / StoreActorReader ✓ / 不实装 bottomRight ✓ / 不写代码 ✓ |

— designer 出稿, 2026-08-12 23:00 (沿 t_b7d1fa55 §3.2 + DECISION §4.2 + §6, 派生 CC 卡 t_8fc5c872 实施)