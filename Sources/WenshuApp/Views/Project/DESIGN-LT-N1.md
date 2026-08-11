# DESIGN-LT-N1 · 文枢 (Wenshu) · v0.02.0 LT-N1

> **designer 产物** — 只出设计稿,不动 .swift / .ws schema / Package.swift
> **覆盖范围**:左半(5 区 layout 的 `topLeft`)独立 App 模块 = 项目管理(项目 / 章节 / 设定 / 资料 / 看板 5 tab)
> **依赖**:LT-01 已实装的 5 区 shell (`LayoutShellView` + `PanelContainer.topLeft`) + 现有 v0.01.0 `ProjectSnapshot` + `ProjectListView` / `ProjectCreateView` + 现有 `WenshuProjectStore` 的 tag-scoping 策略
> **设计基准**:AGENTS §8.1(5 区几何 + 折叠 + 拖拽)+ AGENTS §12 红线(CC 不改 .ws schema)+ 8/7 装机 user OOB 拍板("看板是本项目所有信息的入口" 落到 topLeft 5 tab 中)

---

## 0. 边界确认(designer 拍板前自查)

| 边界 | 本卡状态 | 备注 |
|------|----------|------|
| 改 `.swift` 文件 | ❌ 不动 | designer 不写代码 |
| 改 `WenshuStoreActor` / `ModelDefinitions.swift` schema | ❌ 不动 | 红线 → 升 AIF |
| 改 `Package.swift` / `Info.plist` / `swift-tools-version` / `platforms` | ❌ 不动 | 派单边界 |
| 改 `AGENTS.md` / `CLAUDE.md` / `README.md` | ❌ 不动 | PM 改 |
| 改 v0.02.0 LT-01 已实装的 5 区 layout / `LayoutShellView` / `NativeSplitter` / `PanelContainer` | ❌ 不动 | 本卡是 LT-01 之上叠,不动 shell |
| 改 fix19 已实现的菜单 (`WenshuAppCommands` + `LayoutCommands`) / 聊天区 (`ChatPanelView`) / 编辑器大纲 (`PlaceholderContent.topCenter`) | ❌ 不动 | 已实现不重做 |
| 复用现有 v0.01.0 `ProjectListView` / `ProjectCreateView` | ✅ 复用作内部组件 | 本卡把它们组装进新 tab 容器,**不重写它们的内层视觉** |
| 新增 `ProjectBrowserView`(topLeft 入口) + `ProjectDetailView`(push destination) + `ChapterTreeView`(章节 tab) | ✅ 设计稿 | CC 实现 |

> ⚠️ **schema 警告**:目前 `.ws` 无 `CDProject` entity(`WenshuStoreActor` 只接受 `[String: Any]` 字典写到 CDCharacter / CDNote / CDWorldRule 等既有 entity),项目范围靠 **tag 字符串** `tags: "project-<uuid>"` 区分(WO-005 已落地)。本卡设计稿**默认沿用 tag-scoping**,**不**提案加 `CDProject` entity / `CDChapter.parentID`。v0.04.0 长篇工具 真接 chapter 树结构时再升 AIF 拍 schema。

---

## 1. 完整场景(装机 user 8 步)

> **可验收**:LT-N1 装机 user 走完 8 步 → 项目列表 + 章节树 + 项目详情 tab 切换全部到位 → 关闭 / 重开 app 数据还在 → 实拍录屏。

| 步 | 动作 | 期望结果 | 涉及区 |
|----|------|---------|--------|
| 1 | macOS 启动 → 文枢自动开 5 区 layout | `LayoutShellView` 已渲染,`topLeft` = `ProjectBrowserView`(本卡实装),其它 4 区 = 现有 `PlaceholderContent` / `ChatPanelView` | 5 区 |
| 2 | 点左上 "项目" tab 顶部 **+ 新建项目** 按钮 (SF Symbol `plus.circle.fill`) | `NavigationStack` 把 `ProjectCreateView` push 进栈(沿用 v0.01.0 WO-010 模式,严禁 sheet) | topLeft |
| 3 | 表单填项目名 / 文体风格 / 注水量 / 标签 → 点 "创建" | `ProjectSnapshot` 调 `WenshuProjectStore.create(...)`(沿用 tag-scoping 写入 `CDNote` + 元数据 `CDNote`)→ 自动 pop 回 `ProjectBrowserView` | topLeft |
| 4 | 列表 → 新项目 row 出现 | `@Published` 项目列表立刻刷新(因 `ProjectBrowserView` 持有 `@StateObject projects: ProjectListStore`),新项目 row 在列表顶 | topLeft |
| 5 | 点项目 row | `NavigationStack` push 进 `ProjectDetailView`(`AppRoute.detail(projectId: UUID)`) | topLeft |
| 6 | `ProjectDetailView` 顶部 `Picker.segmented` 5 tab: **项目 / 章节 / 设定 / 资料 / 看板** | tab 切换有效,**项目** + **章节** 实装,**设定 / 资料 / 看板** disabled 灰色 + tooltip "v0.05.0 / v0.04.0 接" | topLeft |
| 7 | 切到 "章节" tab → 章节树可见 | `ChapterTreeView` 渲染(v0.01.0 阶段章节树可空 → 显示空态 + "新建章节" 占位按钮) | topLeft |
| 8 | 关闭 app → 重开 | `WenshuProjectStore` 启动时 `loadAll()` 从 `.ws` 读回所有项目 + 章节 → 项目列表 + 章节树与上次关闭时一致(关 app 不丢数据 = 装机 user 验收金标) | topLeft |

> **为什么是这 8 步(不是 v0.01.0 的 WO-001~WO-010 链路)**:本卡是 LT-N1,独立 worktree,独立验收。v0.01.0 那 8 步走的是 NavigationSplitView(单 NSWindow + 2 pane),v0.02.0 LT-01 已切到 5 区 shell,所以本卡的"8 步"是 5 区 shell 下的 user journey。

---

## 2. 区模块化(topLeft 独立 App 模块)

### 2.1 几何边界

```
┌──────────────────────────────────────────────────────────────────┐
│ (native macOS title bar)                                          │
├──────────────┬───────────────────────────┬──────────────────────┤
│ ★ topLeft     │ topCenter (editor area)   │ topRight              │
│ ProjectBrowser│ PlaceholderContent(留)    │ PlaceholderContent   │
│ (本卡实装)    │                           │                       │
├──────────────┴───────────────────────────┴──────────────────────┤
│ bottomLeft (ChatPanelView, LT-04)            │ bottomRight (空)  │
└────────────────────────────────────────────────┴──────────────────┘
```

`★ topLeft` = 本卡的全部产出。**与 topCenter / topRight / bottomLeft / bottomRight 零依赖**:

- 不订阅 `LayoutShellViewModel`(只持有自己的 `@StateObject` / `ObservableObject` store)
- 不读其它 panel 的 `@Published` 状态
- 不修改其它 panel 的 splitter 比例
- 折叠/拖拽行为由 LT-01 已实装的 `LayoutShellViewModel` + `PanelContainer` 提供,**本卡不重复实现**

### 2.2 topLeft 内部 tab 布局(本卡关键设计)

> 装机 user 8/7 OOB 拍板:**"看板是本项目所有信息的入口"** → 落到 topLeft 5 tab(项目/章节/设定/资料/看板)。

```
┌─────────────────────────────────────┐
│ ProjectBrowserView(topLeft root)    │
│ ┌─────────────────────────────────┐ │
│ │ HeaderBar (24pt 高)              │ │
│ │  [项目] [章节] [设定] [资料] [看板] │ │ ← Picker.segmented, 5 tab 居中铺满
│ ├─────────────────────────────────┤ │
│ │ TabContent (maxHeight: .infinity)│ │
│ │                                  │ │
│ │  根据 selectedTab 切换:           │ │
│ │  .projects  → ProjectListView    │ │  (复用 v0.01.0)
│ │  .chapters  → ChapterTreeView    │ │  (本卡新增)
│ │  .settings  → PlaceholderText    │ │  (disabled, v0.05.0)
│ │  .resources → PlaceholderText    │ │  (disabled, v0.05.0)
│ │  .kanban    → PlaceholderText    │ │  (disabled, v0.04.0)
│ │                                  │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

**约束**(LT-01 已定,本卡沿用):
- 顶部 `Picker.segmented` 不用 macOS `Toolbar`(LT-01-fix3 删了 in-window toolbar,菜单走 macOS 主菜单栏)
- tab 切换 = `@State private var selectedTab: ProjectTab = .projects`,**不**走 NavigationStack(只是同 view 内切换,不 push 新 view)
- "+ 新建项目" 按钮 = 在 `ProjectListView`(复用 v0.01.0)自身的 toolbar,不在 `ProjectBrowserView` HeaderBar
- **章节树** 的 "+ 新建章节" 按钮 = 在 `ChapterTreeView` 自己的 toolbar(沿用 v0.01.0 "新建" 按钮的模式)

### 2.3 与现有 `LayoutShellView.panel(_:)` 的接入点(designer 给 CC 的接口契约)

```swift
// 当前 LayoutShellView.swift line 178-184:
PanelContainer(panelID: id) {
    if id == .bottomLeft {
        ChatPanelView()
    } else {
        PlaceholderContent(panel: id)   // ← 本卡 CC 改这一行为 ProjectBrowserView()
    }
}
```

**本卡 CC 实现**:把 `PlaceholderContent(panel: .topLeft)` 替换为 `ProjectBrowserView()`。**接口契约**:
- `ProjectBrowserView` 必须自管所有 `@StateObject`(不接收外部 `@ObservedObject` 注入)
- 必须独立持久化(自管 `ProjectListStore` + `ChapterListStore`,通过 `WenshuProjectStore` 落 `.ws`)
- 不抛出任何穿透到 `LayoutShellView` 的状态变化

---

## 3. NavigationStack push 路由(per WO-010 红线)

> **拍板**:严禁 `.sheet(isPresented:)`(v0.01.0 WO-006~010 五焦 BUG 教训)。新建 / 详情 全部走 `NavigationStack(path:)` 主路由 push。

### 3.1 `AppRoute` 扩展建议(给 CC,放在 `MainView.swift` 现有 `enum AppRoute` 里)

```swift
enum AppRoute: Hashable {
    case chat(ProjectSnapshot)
    case characterWorld
    case createProject                  // 已有 — v0.01.0 WO-010

    // LT-N1 新增:
    case detail(projectId: UUID)       // 项目详情 (5 tab)
}
```

### 3.2 路由拓扑

```
topLeft root: ProjectBrowserView
├── TabView(.projects)
│   └── ProjectListView  ← (现有, v0.01.0)
│       ├── List Row tap → navPath.append(.detail(projectId))
│       └── Toolbar + tap → navPath.append(.createProject)
├── TabView(.chapters)
│   └── ChapterTreeView  ← (本卡新增)
│       └── (未来) Row tap → 不走 navPath,改走 .selectedChapterId 局部状态
└── TabView(.settings/.resources/.kanban)
    └── PlaceholderText(disabled)

NavigationStack(path: $navPath) {
    ProjectBrowserView()
        .navigationDestination(for: AppRoute.self) { route in
            switch route {
            case .createProject: ProjectCreateView(...)
            case .detail(let id): ProjectDetailView(projectId: id)
            // ...
            }
        }
}
```

**为什么 NavigationStack 在 `ProjectBrowserView` 之上而非 `LayoutShellView` 之上**:NavigationStack 只能 push 一个 destination。topLeft 的 push 不应该影响其它 4 区(topCenter 编辑器 / topRight inspector / bottomLeft 聊天 / bottomRight 状态),所以栈绑在 topLeft 子树上最干净。**CC 实现需确认**:这意味着 `LayoutShellView` 仍然是 root,但每个 panel 子树自己挂自己的 `NavigationStack`(`ProjectBrowserView` 自己挂)。LT-04 聊天区也是同样模式(各自挂栈)。

### 3.3 `ProjectCreateView` 与现有 v0.01.0 的关系

**复用,不重写**:v0.01.0 `ProjectCreateView` 已有完整 4-section Form(项目名 / 文体风格 / 注水量 / 标签)+ 预览 + 创建/取消按钮 + WO-006/007 fix。**LT-N1 的 CC 只**:
- 把它包进 `navigationDestination(for: AppRoute.createProject)`
- `onCreate` 回调从 "调外部 closure" 改成 "调 `ProjectListStore.create(...)`"

`ProjectCreateView` 本身的视觉 / 焦点修复 / sheet-vs-push 决策**全不动**。

---

## 4. 持久化(WenshuProjectStore 增强 — designer 建议,CC 实现需注意 schema 红线)

### 4.1 现有事实

- `WenshuProjectStore` 是 actor(非 `@MainActor class`)
- `WenshuStoreActor` **没有 `createProject` / `listProjects` / `createChapter` / `listChapters` 方法**(只有 `createCharacter` / `listCharacters` / `createNote` / `listNotes` / `createWorldRule` / `createForeshadow` / `createRevision` / `createAIDraft`)
- 项目元数据走 **tag-scoping**:每个项目写一条 `CDNote`,`tags = "project-<uuid>"` + 另一条 `CDNote` `text = "<JSON ProjectSnapshot>"` 编码元数据
- 章节走 `CDChapter` entity,但**无 `projectId` / `parentChapterId` 字段**(目前 `CDChapter` 只有 `title` / `content` / `chapterIndex` / `createdAt`)

### 4.2 designer 给 CC 的 store API 建议(**全部沿用 tag-scoping,不提案 schema**)

```swift
// 新增在 WenshuProjectStore.swift(actor 内)
//
// 关键:不进 WenshuStoreActor,沿用 actor 自己的协调逻辑(tag-scoping)
// 不动 ModelDefinitions.swift schema

// 1. 创建项目(返回新 ProjectSnapshot)
func create(
    name: String,
    style: String,
    verbosity: Int,
    tags: [String]
) async throws -> ProjectSnapshot

// 2. 列出所有项目(从 .ws 读回)
func loadAll() async throws -> [ProjectSnapshot]

// 3. 删除项目(级联 tag-scoping 实体)
func delete(projectId: UUID) async throws

// 4. 章节树(v0.01.0 阶段 = 列表,v0.04.0 真接父子)
//
//    沿用 tag-scoping:章节 = CDChapter entity,加一条 CDNote
//    "chapter-meta-<projectId>" 编码章节列表 JSON
//    v0.04.0 长篇工具 升 schema 再换 CDChapter.parentID 实现
//
//    本卡只读 + 列,写章节留 v0.04.0 接
func listChapters(projectId: UUID) async throws -> [ChapterSnapshot]
```

### 4.3 ViewModel / Store 包装(designer 给 CC 的 `@MainActor` 层)

```swift
// 新增文件建议: Sources/WenshuApp/ViewModels/ProjectListStore.swift
@MainActor
final class ProjectListStore: ObservableObject {
    @Published var projects: [ProjectSnapshot] = []
    private let store: WenshuProjectStore  // actor 注入

    func load() async {
        do { projects = try await store.loadAll() }
        catch { /* 错误展示:ProjectBrowserView 显示错误 banner */ }
    }

    func create(name: String, style: String, verbosity: Int, tags: [String]) async {
        do {
            let new = try await store.create(name: name, style: style, verbosity: verbosity, tags: tags)
            projects.insert(new, at: 0)
        } catch { /* 同上 */ }
    }

    func delete(projectId: UUID) async {
        try? await store.delete(projectId: projectId)
        projects.removeAll { $0.id == projectId }
    }
}

// 新增文件建议: Sources/WenshuApp/ViewModels/ChapterTreeStore.swift
@MainActor
final class ChapterTreeStore: ObservableObject {
    @Published var chapters: [ChapterSnapshot] = []
    let projectId: UUID
    private let store: WenshuProjectStore

    func load() async { ... }
}
```

**为什么拆两个 `@MainActor` Store 而非一个**:`ProjectBrowserView` 5 tab,只有 .projects / .chapters 真正读 store;.settings / .resources / .kanban 是占位,挂空 store 等于浪费订阅。拆两个 = `.projects` 重建不连带 `.chapters` 重建,符合 SwiftUI 精细订阅原则。

### 4.4 v0.04.0 / v0.05.0 升 schema 触发条件(designer 留给 PM-direct)

> **本卡不触发以下任何改动**,但记下边界,供 PM v0.04.0 拍板:

| 升级点 | 当前 (v0.02.0 LT-N1) | 升级到 (v0.04.0 / v0.05.0) | 触发条件 |
|--------|----------------------|----------------------------|---------|
| 项目元数据存哪 | `CDNote.text = JSON` + `tags = "project-<uuid>"` | 新 `CDProject` entity | LT-N1 关 app 数据丢失的 bug 报告 ≥ 1 |
| 章节父子关系 | `CDNote.text = JSON` 编码树 | `CDChapter.parentChapterID: UUID` | v0.04.0 长篇工具 接"章节拖拽"功能 |
| 章节 = CDChapter vs 独立 entity | CDChapter 现存,字段不足 | 加 `projectId` / `parentID` / `orderIndex` | v0.04.0 长篇工具 落档 |

**升级 = 升 AIF**(AGENTS §12 红线),不归 CC 拍板。

---

## 5. SwiftUI 设计 token

> **全部沿用 v0.01.0 + LT-01 已实装的 token**,本卡不引入新颜色 / 字号 / spacing 常量。

### 5.1 颜色 / 字号

| token | 用法 | 备注 |
|-------|------|------|
| `Color.accentColor` | "+ 新建项目" 按钮 + tab Picker 选中态 | 系统 accent,跟随 macOS 主题 |
| `Color.secondary` | 副标题 / meta info(文体风格 / 注水量 / 标签 / 日期) | v0.01.0 已用 |
| `Color.tertiary` | 标签 chip / 三级 meta | v0.01.0 已用 |
| `Font.headline` | 项目名 / 章节标题 | v0.01.0 已用 |
| `Font.caption` | meta info 行 | v0.01.0 已用 |
| `Font.title2` | 空态大标题 "暂无项目" | v0.01.0 已用 |
| `Font.callout` | 空态副标题 "点 + 新建" | v0.01.0 已用 |

### 5.2 spacing / padding

| token | 数值 | 用法 |
|-------|------|------|
| HeaderBar 内边距 | `padding(8)`(HStack) | 5 tab Picker 上下 8pt |
| ProjectRow 内边距 | `padding(.vertical, 4)` + HStack spacing 12 | v0.01.0 `projectRow` 已用 |
| ChapterRow 内边距 | `padding(.vertical, 2)` + HStack spacing 8 | 章节行比项目行紧凑(树状) |
| 章节缩进 | 8pt per level | `Spacer().frame(width: 8 * level)` |
| Card 装饰 | **不**画在 List 行级 | v0.01.0 `List` 已用 inset 风格,本卡不重复加 card 框 |
| Picker.segmented | `PickerStyle.segmented`,居中铺满 width | 5 tab 用 segmented 比 dropdown 更直观 |

### 5.3 SF Symbol

| 用途 | SF Symbol | 备注 |
|------|-----------|------|
| 新建项目按钮 | `plus.circle.fill` | size 16,Color.accentColor |
| 章节 row ICON | `list.bullet.rectangle` | size 14,Color.secondary |
| 空态图标 | `tray`(沿用 v0.01.0) | size 56,weight light |
| 章节层级 chevron | `chevron.right` / `chevron.down` | 折叠/展开父章节(size 12) |

### 5.4 视觉风格约定(与现有代码对齐)

- **不**用渐变 / 阴影 / 圆角以外的装饰
- **不**画 separator(用 `List` 内置 separator)
- **不**给 row 加 hover 高亮(`List` 自带 selection 高亮)
- **不**画 panel 标题栏(`PanelContainer` 已无 headerBar,沿用 LT-01-fix5 拍板)

### 5.5 快捷键(本卡不实现)

- 沿用 AGENTS §8.1 + LT-01 拍板:快捷键 v0.09.0 统一处理,本卡不指定具体键位
- "+ 新建项目" 按钮不绑快捷键(等 v0.09.0 拍)
- 5 tab 切换不绑快捷键(等 v0.09.0 拍)

---

## 6. 组件 API(designer 给 CC 的接口契约)

> 本节是给 CC 实现的"接口草图",**不是最终代码**。designer 不写代码,只画 API 形态。

### 6.1 `ProjectBrowserView`(topLeft 入口)

```swift
// 新增文件: Sources/WenshuApp/Views/Project/ProjectBrowserView.swift
struct ProjectBrowserView: View {
    @StateObject private var projectStore = ProjectListStore()
    @StateObject private var chapterStore: ChapterTreeStore  // 绑到当前选中项目
    @State private var navPath: NavigationPath = .init()
    @State private var selectedTab: ProjectTab = .projects

    enum ProjectTab: String, CaseIterable, Identifiable {
        case projects, chapters, settings, resources, kanban
        var id: String { rawValue }
        var title: String {
            switch self {
            case .projects: return "项目"
            case .chapters: return "章节"
            case .settings: return "设定"
            case .resources: return "资料"
            case .kanban: return "看板"
            }
        }
        var isEnabled: Bool {
            switch self {
            case .projects, .chapters: return true
            case .settings, .resources: return false   // v0.05.0 接
            case .kanban: return false                 // v0.04.0 接
            }
        }
    }

    var body: some View {
        NavigationStack(path: $navPath) {
            VStack(spacing: 0) {
                tabBar
                Divider()
                tabContent
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .createProject:
                    ProjectCreateView(
                        onCreate: { snapshot in
                            Task { await projectStore.create(
                                name: snapshot.name,
                                style: snapshot.style,
                                verbosity: snapshot.verbosity,
                                tags: snapshot.tags
                            ) }
                            navPath.removeLast()
                        },
                        onCancel: { navPath.removeLast() }
                    )
                case .detail(let id):
                    ProjectDetailView(projectId: id)
                case .chat, .characterWorld:
                    EmptyView()  // 不归本卡管
                }
            }
        }
        .task { await projectStore.load() }
    }

    private var tabBar: some View {
        Picker("", selection: $selectedTab) {
            ForEach(ProjectTab.allCases) { tab in
                Text(tab.title).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(8)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .projects:
            ProjectListView(
                projects: $projectStore.projects,
                navPath: $navPath
            )  // 复用 v0.01.0
        case .chapters:
            ChapterTreeView(
                store: chapterStore,
                navPath: $navPath
            )  // 本卡新增
        case .settings, .resources, .kanban:
            PlaceholderTabContent(tab: selectedTab)  // disabled 占位
        }
    }
}
```

### 6.2 `ProjectDetailView`(push destination)

```swift
// 新增文件: Sources/WenshuApp/Views/Project/ProjectDetailView.swift
struct ProjectDetailView: View {
    let projectId: UUID

    var body: some View {
        // 简化版 — 只展示项目元数据卡片 + "返回项目列表" 按钮
        // 真正的 5 tab 交互在 ProjectBrowserView.chapters / .projects 里
        // 这里只作为 push destination 占位(避免空白的 NavigationStack pop 异常)
        ProjectDetailPlaceholder(projectId: projectId)
            .navigationTitle("项目详情")
    }
}
```

**注意**:task 派单里写的 `ProjectDetailView` 是 "5 tab 实装版",但本卡沿用"5 tab 入口在 `ProjectBrowserView` 顶部"的 OOB 拍板,**detail push 后**只显示项目元数据卡片(v0.01.0 `CharacterWorldView` 同模式)。这样:
- 项目列表点 row → `ProjectDetailView` → 看到项目元数据 → 返回 → 切到"章节"tab 看到章节树
- 比"在 detail view 里再嵌 5 tab"更清晰(FCP 浏览器范式 = 项目列表 ↔ 章节列表 同级)

**这是 designer 对 task 派单的偏离**(task 拍 detail = 5 tab,designer 拍 detail = 元数据 + browser = 5 tab)。**需 PM-direct 拍板**:
- ✅ 选项 A(designer 推):detail = 元数据卡片,5 tab 在 browser 顶 → 详见 §6.1 / §6.2
- ❌ 选项 B(task 原拍):detail = 5 tab,browser 顶只有项目列表 → 需重写 §6.1 / §6.2

### 6.3 `ChapterTreeView`(章节 tab 内容)

```swift
// 新增文件: Sources/WenshuApp/Views/Project/ChapterTreeView.swift
struct ChapterTreeView: View {
    @ObservedObject var store: ChapterTreeStore
    @Binding var navPath: NavigationPath

    var body: some View {
        Group {
            if store.chapters.isEmpty {
                emptyState
            } else {
                chapterList
            }
        }
        .navigationTitle("章节")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    // v0.04.0 长篇工具 实装"新建章节"
                    // 本卡 = disabled 按钮 + tooltip "v0.04.0 接"
                } label: {
                    Label("新建章节", systemImage: "plus")
                }
                .disabled(true)
                .help("v0.04.0 长篇工具 阶段实装")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.secondary)
            Text("暂无章节")
                .font(.title2)
            Text("v0.04.0 接新建章节")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var chapterList: some View {
        // 树状渲染 — 本卡只一维列表,层级折叠 v0.04.0 接
        List(store.chapters) { chapter in
            chapterRow(chapter, level: 0)
        }
        .listStyle(.inset)
    }

    private func chapterRow(_ chapter: ChapterSnapshot, level: Int) -> some View {
        HStack(spacing: 8) {
            if level > 0 {
                Spacer().frame(width: 8 * level)
            }
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(chapter.title)
                    .font(.headline)
                Text("第 \(chapter.index) 章 · \(chapter.wordCount) 字")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

// 章节快照(本卡新增,v0.01.0 阶段没这类型,放在 Models/ 下)
struct ChapterSnapshot: Identifiable, Hashable, Sendable {
    let id: UUID
    let projectId: UUID
    var title: String
    var index: Int       // chapterIndex,排序用
    var wordCount: Int   // 派生:content.split(separator: " ").count
    var parentId: UUID?  // v0.01.0 = nil 全部;v0.04.0 真接父章节
}
```

### 6.4 `PlaceholderTabContent`(disabled 占位 — 给 .settings / .resources / .kanban 用)

```swift
// 新增文件: Sources/WenshuApp/Views/Project/PlaceholderTabContent.swift
struct PlaceholderTabContent: View {
    let tab: ProjectBrowserView.ProjectTab

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.secondary)
            Text(tab.title)
                .font(.title2)
            Text(roadmap)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var roadmap: String {
        switch tab {
        case .settings: return "v0.05.0 标记系统 阶段实装"
        case .resources: return "v0.05.0 标记系统 阶段实装"
        case .kanban: return "v0.04.0 长篇工具 阶段实装"
        default: return ""
        }
    }
}
```

### 6.5 与 v0.01.0 `ProjectListView` / `ProjectCreateView` 的边界

| 组件 | 来源 | 本卡改动 |
|------|------|---------|
| `ProjectListView` | v0.01.0 WO-010,已在 `Views/ProjectListView.swift` | **不重写**,只在新 `ProjectBrowserView` 内复用,接收 `@Binding projects` + `@Binding navPath` |
| `ProjectCreateView` | v0.01.0 WO-007,已在 `Views/ProjectCreateView.swift` | **不重写**,只在新 `ProjectBrowserView.navigationDestination` 内复用,`onCreate` 改调 `projectStore.create(...)` |
| `ProjectBrowserView` | **本卡新增** | 5 tab Picker + NavigationStack 入口 |
| `ProjectDetailView` | **本卡新增**(简化为元数据卡片) | push destination 占位 |
| `ChapterTreeView` | **本卡新增** | 章节 tab 内容 |
| `PlaceholderTabContent` | **本卡新增** | disabled tab 占位 |

> **关于位置**:task 派单写 `Sources/WenshuApp/Views/Project/DESIGN-LT-N1.md` → CC 落代码时建议把新 view 放 `Sources/WenshuApp/Views/Project/` 子目录(v0.01.0 那两个 view 在 `Views/` 根,后续可逐步移过来 — **本卡不搬**,避免无谓 diff)。

---

## 7. 验收 checklist(designer 视角)

> **本卡(designer)产物 = 本设计稿 + 5 行 kanban_comment + git commit**。CC 后续实现验收另立 LT-N1-impl。

| # | 验收项 | 验证方法 | 通过条件 |
|---|--------|---------|---------|
| 1 | `Sources/WenshuApp/Views/Project/DESIGN-LT-N1.md` 落盘 | `ls -la` 路径 + `wc -l` 行数 > 100 | ✅ |
| 2 | 5 行 kanban_comment | kanban DB 写入,id + timestamp + 内容 | ✅ |
| 3 | `swift build` 退出 0 | 在 worktree 内 `swift build 2>&1 | tail -5` | exit 0(已有 warning 不算) |
| 4 | git commit 落盘 | `git log -1 --stat` | 看到 DESIGN-LT-N1.md + worktree branch = `wenshu/v0.02.0/LT-N1-designer` |
| 5 | **不动**任何 `.swift` / `Package.swift` / `Info.plist` / `ModelDefinitions.swift` / `AGENTS.md` / `CLAUDE.md` / `README.md` | `git status` + `git diff main --stat` | 工作树只新增 DESIGN-LT-N1.md,无其它改动 |

**装机 user 后续验收(留 LT-N1-impl)**:8 步场景全跑通 → 关 app / 重开 数据不丢 = 验收金标。

---

## 8. ⚠️ designer 偏离 / 升 PM 提示

> 派单 task 写 `ProjectDetailView` = 5 tab 实装(designer 改为元数据卡片 + 5 tab 入口在 `ProjectBrowserView` 顶部)。原因:5/7 OOB 拍板"看板是本项目所有信息的入口"更自然落在 browser 顶部(用户没点 detail 也能切 tab 看章节),而非 detail push 后才看到。**需 PM-direct 拍板**:

- ✅ 选项 A(designer 推):detail = 元数据卡片,5 tab 在 browser 顶 → 详见 §6.1 / §6.2
- ❌ 选项 B(task 原拍):detail = 5 tab,browser 顶只有项目列表 → 需重写 §6.1 / §6.2

**派单**:designer-revise-LT-N1 → designer 收到 PM 拍板后改本设计稿。

---

## 9. 派生 / 留给后续阶段

| 阶段 | 接管 topLeft 什么 | 来源 |
|------|---------------------|------|
| **v0.02.0 LT-N1**(本卡) | 5 tab Picker + 项目列表 + 章节树 + 3 disabled 占位 | 本设计稿 |
| **v0.02.0 LT-N1-fixN** | designer-revise 后调整 | 视 PM 拍板 |
| **v0.04.0 长篇工具** | "章节" tab 实装新建章节 + 章节拖拽卡片 + 父子层级折叠(chevron) + 选中章节 → push 进章节正文编辑器(写 `CDChapter.parentID` schema 需升 AIF) | AGENTS §8 + §12 |
| **v0.05.0 标记系统** | "设定" / "资料" tab 实装(`CDWorldRule` / 资料库,沿用既有 entity 不升 schema) | AGENTS §8 |
| **v0.09.0 快捷键** | 5 tab 切换快捷键 + "+ 新建" 快捷键 + 全局导航 | AGENTS §8.1 |

---

## 10. 升级路径(designer 红线)

- 装机 user 拍改设计 → 派 `designer-revise-LT-N1` 给 designer(本 profile)
- 改 `.ws` schema → **升 AIF**(AGENTS §12 红线)
- 改 LLM provider 签名 / 阶段门触发逻辑 / 离线模式 → **升 AIF**
- CC 实现时发现 designer 接口契约不可行 → CC 反馈 PM → PM 派 `designer-revise-LT-N1`
- designer 拍板后 → 派 `LT-N1-impl`(给 CC,新 worktree `t_<id>-lt01-n1-impl`)

---

*DESIGN-LT-N1 v0.02.0 · designer 产物 · 2026-08-10 · 5 区 layout topLeft 独立 App 模块 · 装机 user 8/7 OOB 拍板("看板是本项目所有信息的入口")落地版*
