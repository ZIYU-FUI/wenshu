# DESIGN-LT-N1 · 项目管理 UI 设计稿(左上区, 区块模块化)

> **任务**:[V0.02.0 LT-N1-designer] 项目管理 UI 设计稿(左半 + 区块模块化完整, AIF LT-N1~N5 第一张迭代卡)
> **拍板真值**:AGENTS.md §3 (场景驱动 / 区块模块化 / 迭代可独立运行) + §8.1 (5 区 layout) + §5 (CC 写代码边界)
> **designer**:出 SwiftUI UI 设计意图 + token + 组件 API 建议 + WenshuProjectStore 增强 API 建议。**不写代码**。
> **落盘路径**:`Sources/WenshuApp/Views/Project/DESIGN-LT-N1.md`
> **拍板真值**:2026-08-10 AGENTS.md §3 + §8.1 (v0.02.0 LT-01 + fix17/18/19 合并后)

---

## 0. 任务边界矛盾点(designer 不能拍, 必升级)

读了 `Sources/WenshuApp/Persistence/WenshuStoreActor.swift` (255 行全) + `Layout/PlaceholderContent.swift` + `Layout/LayoutShellViewModel.swift` 第 319 行 PanelID enum + AGENTS §12 红线 + fix17/18/19 commit,发现**任务 body 跟现状有 4 处冲突**。designer 把它们标在这里,**等 PM / 装机 user 拍板**,不擅自选边。

### 矛盾 1: 任务 body "WenshuProjectStore 增强 loadAll() / create() / delete()" 越界 — 需要新增 CDProject entity

- **事实**:`WenshuStoreActor.swift:98-107` `countAll()` 里枚举了 `[CDCharacter, CDChapter, CDNote, CDWorldRule, CDForeshadow, CDRevision, CDAIDraft]` — **没有 CDProject**。`WenshuProjectStore.save()` (v0.01.0 WO-005) 是把 project id 当作 `CDNote.tags` 字符串(`"project-\(uuid)"`)存,**没有独立的 project 行**。
- **任务 body**:「3. WenshuProjectStore 增强 API · loadAll() / create() / delete()」 — 这暗示 loadAll 列出所有 projects, create 创建新 project, delete 删除 project。要支持这 3 个方法,**必须有 CDProject entity**(id, name, style, verbosity, tags, createdAt)。
- **冲突**:**AGENTS §12 红线**明确「CC → 改 `.ws` schema(增删 entity/字段类型)严禁(改 = 越界, 归 PM)」。新增 CDProject entity = schema 改动,**归 PM-direct 拍, 不是 LT-N1 的范围**。
- **可能的真意**:
  - 读法 A:任务 body 暗示 LT-N1 完成时同步建 CDProject entity, PM-direct 已默认授权(违反 §12 红线的隐含授权)。
  - 读法 B:LT-N1 不动 schema, 只用现有 `CDNote.tags = "project-uuid"` 反查。先把 `WenshuProjectStore.listAll() / createFromSnapshot() / deleteByID()` 跑起来,**真正的 CDProject schema 留到 PM-direct 后续拍**。
- **建议**:designer 推荐**读法 B**。理由:(1) 不越界 §12 红线;(2) 用现有 schema 反查能立刻跑通"装机 user 8 步"(开 App → 看项目列表 → 进项目 → 回列表 → 删除),验证 LT-N1 设计;(3) PM-direct 拍 CDProject entity 时,只需把反查换成 fetch,UI 不动。**⚠️ 等 PM-direct 拍**。

### 矛盾 2: 任务 body "左上区项目管理 5 tab" 跟 "5 tab = 项目 / 章节 / 设定 / 资料 / 看板" 的口径差

- **任务 body**:「3. 组件 API 建议 · ProjectDetailView(push destination, 5 tab)」。
- **AGENTS §8.1**:左上区 = **多 tab: 项目 / 章节 / 设定 / 资料 / 看板**(5 tab)。`LayoutShellView.swift:181` 当前 placeholder 是 `PlaceholderContent` 给的"LT-03 将在此填充: 项目 / 章节 / 设定 / 资料 / 看板"。
- **冲突**:任务 body 说"项目管理"是 LT-N1 一个卡要出,**但 AGENTS §8.1 + PlaceholderContent 都暗示项目管理 = 左上整个区(包含 5 个 tab)**。两种读法:
  - 读法 A:LT-N1 = 左上整个区,**5 个 tab 都要出**(项目 + 章节 + 设定 + 资料 + 看板)。这是 AGENTS §8.1 的字面口径。
  - 读法 B:LT-N1 = 只出 **"项目"tab**(项目列表 + 新建入口),其余 4 tab(章节 / 设定 / 资料 / 看板)留 LT-N2~N5 后续卡。这是任务 body "5 tab" 跟父任务 `t_4c608c99` "AIF LT-N1~N5 第一张" 的字面口径(5 张卡 = 5 个 tab 拆开做)。
- **判断**:父任务 t_4c608c99 拍板 = "AIF LT-N1~N5 第一张迭代卡"(注释里 "LT-N1~N5" 暗示 5 张卡 = 5 个 tab 拆开),**读法 B 更合父任务拍板**。同时 AGENTS §3「迭代可独立运行」也支持拆开做。
- **建议**:designer 推荐**读法 B**。LT-N1 = 左上"项目"tab = 项目列表 + 新建按钮 + 项目详情页 5 tab 内的一个入口。LT-N2 = 章节,LT-N3 = 设定,LT-N4 = 资料,LT-N5 = 看板。**⚠️ 等 PM-direct 拍**(这是任务 body 的关键读法,装机 user 可能本来就要 A+B 综合 = LT-N1 包含整个 5 tab 壳子 + 项目 tab 实装)。

### 矛盾 3: 任务 body 不提 `ProjectListView` / `ProjectCreateView` 已存在

- **事实**:`Sources/WenshuApp/Views/ProjectListView.swift` (v0.01.0 WO-004~010, 120 行) + `ProjectCreateView.swift` (v0.01.0 WO-004~007, 160 行) 都已存在,使用 `NavigationStack` push + `@Binding<[ProjectSnapshot]>` + in-memory 状态 + `.sheet(isPresented:)`(ProjectCreateView 仍带 sheet 焦点 hack)。
- **冲突**:任务 body 让 designer「出组件 API 建议 · ProjectListView / ProjectCreateView / ProjectDetailView」 — 但这两个文件已存在且**当前不在 5 区 layout 内**(LT-01 把 MainView 换成 `LayoutShellView()`,旧的 ProjectListView 被悬空了)。
- **可能的真意**:
  - 读法 A:LT-N1 让 CC 把 ProjectListView 改成"左上区内部的内容"(5 区 layout 的 topLeft),ProjectCreateView 改成 push 进 topLeft 内的子路由。这是 §3「区块模块化」的硬要求(把左半当独立 App 模块)。
  - 读法 B:保留 ProjectListView 在原位(LT-N1 不动 layout,新写一份 ProjectListViewForLeftPanel)。
- **建议**:designer 推荐**读法 A**。理由:(1) 区块模块化要求"左上 = 独立 App 模块",不能有两个 ListView;(2) §3 派单原则「单任务单一功能」+ 「迭代可独立运行」+ 「装机 user 拿到这个迭代能跑通"创建项目 → 看章节树 → 看板入口"」,读法 A 直接达成。**⚠️ 等 PM-direct 拍**(如果读法 A 被否,需要明确写"不动 ProjectListView.swift")。

### 矛盾 4: 任务 body "持久化 (WenshuProjectStore 增强)" 没指明 schema 范围

- 同矛盾 1:任务 body 暗示持久化(读出/写入/删除要落盘),但 AGENTS §12 红线禁止 CC 改 .ws schema。如果走矛盾 1 读法 B(不建 CDProject),持久化只能:
  - (a) 用 `CDNote.tags = "project-uuid"` 反查(读出 ok,删除要级联删所有 note);
  - (b) 只在内存里持久化(@State 撑到 App 关闭就丢,这违反 §3 迭代可独立运行 — 装机 user 关 App 再开,项目列表空了)。
- **建议**:持久化方案 (a) 反查方案 + 内存缓存 + App 启动时 load。删除走"软删除"(标记 tombstone),不真删 CDNote(避免误删用户数据)。**⚠️ 等 PM-direct 拍软删除 vs 真删除**。

---

## 1. 完整场景(装机 user 8 步)

按 AGENTS §3「迭代可独立运行」,LT-N1 必须让装机 user 拿到这个迭代后**立刻能跑通一个完整动作**。8 步:

1. **开 App** → 看 5 区 layout,左上项目管理区显示当前 tab(项目 tab)+ 项目列表
2. **点 + 新建项目** → push 进 ProjectCreateView(在左上区**内**,不是 sheet,不是新 window)
3. **填表单**(项目名 / 文笔风格 / 注水量 1-9 / 标签)→ 实时预览
4. **点 创建** → 写入 .ws(走矛盾 1 读法 B 的反查方案)→ 回到项目列表,新项目出现在顶部
5. **点 项目列表项** → push 进 ProjectDetailView(左上区内,显示当前选中的项目)
6. **ProjectDetailView 显示 5 tab**:**项目**(实装,本卡范围)+ 章节 / 设定 / 资料 / 看板(4 个 disabled,等 LT-N2~N5)
7. **回项目列表** → 列表显示所有项目(含创建时间 / 文笔风格 / 注水量 / 标签)
8. **右键项目 → 删除** → 软删除(tombstone 标记)+ 列表立刻少一项 + 重启 App 后列表仍然少(走 §7 .ws 持久化)

> **关键**:LT-N1 完成后,装机 user 能跑通「创建 → 列表 → 详情 → 删除」完整循环。不依赖 LT-N2~N5。LT-N2 章节 tab 实装后,装机 user 还能跑通"详情页章节树",但 LT-N1 本身已经是一个**最小可用版本**。

---

## 2. 区块模块化(左上区当独立 App 模块)

按 AGENTS §3「区块模块化」,**左上 = 独立 App 模块**。设计师要给出"这个模块的边界":

### 2.1 模块边界

| 维度 | 左上项目管理区 |
|------|------|
| **入口** | `LayoutShellView.swift:181` 的 `topLeft` panel 容器 (`PanelContainer(panelID: .topLeft)`) |
| **出口** | 当前选中 project 的 id → 给其它 4 区消费(中上文档 / 右上 inspector / 下左聊天 / 下右状态) |
| **数据所有权** | `WenshuProjectStore`(actor,单例 `.shared`)管 project 列表 |
| **ViewModel** | `ProjectListViewModel`(新增,@MainActor,@Observable 单例,见 §6) |
| **路由** | 左上**内嵌 NavigationStack**(独立于 MainView 的任何外部 NavigationStack — §3 区块模块化硬要求) |
| **状态机** | `loading` / `loaded(projects: [ProjectSnapshot])` / `empty` / `error(String)` |
| **持久化** | `WenshuProjectStore` actor → `WenshuStoreActor` CoreData(走矛盾 1 读法 B:CDNote.tags 反查) |

### 2.2 不允许的依赖

- ❌ 左上不能直接读 `LayoutShellViewModel` 的 layout 状态(拓扑独立,各管各的)
- ❌ 左上不能直接调 ChatViewModel(那是下左聊天的事,跨区写要经 store)
- ❌ 左上不能直接改 inspector 状态(那是右上 inspector 的事)
- ❌ 左上不能直接调 LLM(只有聊天能调,见 AGENTS §12 红线 + LLM key 在 Keychain 的边界)

### 2.3 允许的依赖

- ✅ 左上可读 `LayoutShellViewModel.shared.snapshot.collapsed.topLeft`(折叠状态)
- ✅ 左上可写 `WenshuProjectStore`(actor, 单一职责)
- ✅ 左上可通过 Environment 接收"全局选中 project id"(其它区读这个 id,不改它)

---

## 3. NavigationStack push 路由(严禁 sheet)

按 v0.01.0 WO-010 拍板真值 + AGENTS §3「区块模块化」,**所有路由走 NavigationStack push**(严禁 sheet,严禁新 NSWindow)。

### 3.1 路由图

```
LayoutShellView (5 区根)
└── topLeft: PanelContainer(.topLeft)
    └── NavigationStack(path: $projectNavPath)    ← 左上内嵌 NavigationStack
        ├── root: ProjectListView                 ← 列表 + 新建按钮
        ├── /create: ProjectCreateView            ← push (不是 sheet)
        └── /detail/{id}: ProjectDetailView       ← push (不是 sheet)
            └── /detail/{id}/settings: ProjectSettingsView   ← push (后续卡,LT-N1 不出)
```

### 3.2 路由 enum(给 CC 实现用)

```swift
/// ProjectModule 内部路由。**只在左上 NavigationStack 内**,不污染主 App 路由。
enum ProjectRoute: Hashable {
    case create
    case detail(UUID)         // ProjectSnapshot.id
    case settings(UUID)       // 后续卡
}
```

### 3.3 严守 WO-010 拍板(已知焦点 bug 历史)

- ❌ 严禁 `.sheet(isPresented:)`(WO-006/007/008/009 4 次修焦点 bug 全失败)
- ❌ 严禁 `NSHostingController` + 显式 NSWindow + `makeKeyAndOrderFront`
- ❌ 严禁 `WindowActivation.forceKeyToWenshuSheet()`(那是 ProjectCreateView 当年 sheet 的 hack,本卡直接用 push 不需要)
- ✅ NavigationStack push 是 Apple HIG macOS 主路由范式,焦点自动路由,不需要 hack

### 3.4 ProjectCreateView 历史包袱清理

当前 `ProjectCreateView.swift` (160 行) 仍是 sheet 设计 + `WindowActivation.forceKeyToWenshuSheet()` + `@FocusState` auto-focus。**LT-N1 改造为 push destination**:

- 保留表单字段(name / style / verbosity / tags)
- 保留 @FocusState auto-focus(WO-006 经验 — push 也会有焦点 race,虽然概率比 sheet 低)
- **删 `WindowActivation.forceKeyToWenshuSheet()`** 和 `.onAppear` 里的强制 makeKey 调用
- **删 `onCancel` 闭包** — push 路由用 `navPath.removeLast()` 自动 dismiss
- **改 `onCreate` 为「返回 ProjectSnapshot」** — 调用方 push 后 dismiss + 写入 store

---

## 4. 持久化方案(WenshuProjectStore 增强 API)

### 4.1 走矛盾 1 读法 B(反查方案,**designer 推荐**)

不动 .ws schema,用现有 `CDNote.tags = "project-uuid"` 反查所有 projects。

### 4.2 WenshuProjectStore 增强 API(designer 出建议, CC 实现)

```swift
/// v0.02.0 LT-N1 增强 API。**actor 边界,全部 async**。
actor WenshuProjectStore {
    /// 列出所有 projects。反查 CDNote.tags 包含 "project-uuid" 的去重集。
    /// 返回排序按 createdAt 降序(最新在顶)。
    /// - Returns: projects 数组(空数组 = 还没创建过任何 project)
    /// - Throws: CoreData fetch 失败
    func loadAll() async throws -> [ProjectSnapshot]

    /// 创建新 project。写入:
    /// - 1 个 CDNote(tag = "project-meta", text = 序列化的 ProjectSnapshot JSON)
    /// - 1 个 CDNote(tag = "project-{uuid}-initial-story", text = "")
    /// **不**新增 CDProject entity(矛盾 1 读法 B)。
    /// - Parameter project: 完整 snapshot(本卡 caller 保证 name 非空)
    /// - Returns: 持久化后的 project(带正确 id 和 createdAt)
    /// - Throws: CoreData 写入失败
    func create(_ project: ProjectSnapshot) async throws -> ProjectSnapshot

    /// 软删除 project。**不**真删 CDNote,改 tags 加 "tombstone-{timestamp}"。
    /// 反查时过滤掉 tombstone 标记。
    /// 理由(矛盾 4):避免误删用户数据 + 未来 v0.05.0 标记系统可能复用 tombstone。
    /// - Parameter id: project.id
    /// - Throws: CoreData 写入失败
    func delete(_ id: UUID) async throws

    /// 加载单个 project(给 ProjectDetailView 用)。
    /// - Parameter id: project.id
    /// - Returns: 找到返回 snapshot,找不到(已删 / 不存在)返回 nil
    func load(id: UUID) async throws -> ProjectSnapshot?
}
```

### 4.3 序列化(CDNote.text 存 ProjectSnapshot JSON)

```swift
/// 内部 helper,不在 public API。
private func encodeMeta(_ snapshot: ProjectSnapshot) -> String {
    let dict: [String: Any] = [
        "id": snapshot.id.uuidString,
        "name": snapshot.name,
        "style": snapshot.style,
        "verbosity": snapshot.verbosity,
        "tags": snapshot.tags,
        "createdAt": snapshot.createdAt.timeIntervalSince1970,
        "tombstone": false  // 软删除时改 true
    ]
    return try JSONSerialization.dictionaryToString(dict)  // CC 实现细节
}

private func decodeMeta(_ json: String) -> ProjectSnapshot? {
    // 反序列化,过滤 tombstone = true
}
```

### 4.4 软删除 vs 真删除(矛盾 4 ⚠️ 等拍)

designer 推荐**软删除**(tombstone 标记)。理由:
- 防止误删(装机 user 手滑)
- v0.05.0 标记系统可能复用 tombstone 概念
- 未来 v0.03.0 阶段门需要"项目归档"功能,tombstone 是天然中间态

**⚠️ 等 PM-direct 拍**。

---

## 5. SwiftUI 设计 token(本卡新增)

按 `swiftui-design-patterns` skill §4,引用文枢 token 系统。**本卡新增 / 显式化的 token**:

### 5.1 新增按钮 token

| Token | 值 | 用途 |
|------|------|------|
| `wenshu.button.newProject.size` | 28pt SF Symbol | toolbar `+` 按钮(图标大小) |
| `wenshu.button.newProject.bg` | `.tertiary` material | push 按钮背景(不抢眼,符合 macOS HIG) |
| `wenshu.button.newProject.fg` | `.accentColor` | 蓝色 accent(系统级,非自定义) |

### 5.2 新增列表项 token

| Token | 值 | 用途 |
|------|------|------|
| `wenshu.list.rowHeight` | 56pt | 项目列表项高(两行:标题 + meta) |
| `wenshu.list.rowSpacing` | 4pt | 标题和 meta 行间距(对应 `wenshu.space.xxs`) |
| `wenshu.list.rowPadding` | 12pt | 列表项左右内边距(对应 `wenshu.space.s`) |
| `wenshu.list.rowHover` | `.quaternary` material | hover 状态背景 |
| `wenshu.list.rowSelected` | `.tint.opacity(0.15)` | selected 状态背景(macOS HIG 标准) |
| `wenshu.list.rowRadius` | 6pt | hover/selected 圆角(对应 `wenshu.radius.s` 略大) |

### 5.3 新增 tab bar token(ProjectDetailView 内)

| Token | 值 | 用途 |
|------|------|------|
| `wenshu.tabBar.height` | 36pt | 5 tab bar 高度(macOS 标准) |
| `wenshu.tabBar.activeIndicator` | `.tint` | active tab 底部 2pt 高亮条 |
| `wenshu.tabBar.disabled` | `.tertiary` foreground + `.quaternary` opacity | disabled tab 视觉 |

### 5.4 复用现有 token

- 间距:`wenshu.space.{xxs,xs,s,m,l,xl,xxl}` (4/8 baseline)
- 颜色:`wenshu.text.{primary,secondary,tertiary}` + `wenshu.divider` + `wenshu.surface.{background,elevated}`
- 字体:`wenshu.text.{headline,subhead,callout,footnote,caption}`
- 圆角:`wenshu.radius.{s,m,l,xl}`

---

## 6. 组件 API 建议(给 CC 的实现提示)

### 6.1 ProjectListViewModel(新增 @MainActor 单例)

```swift
@MainActor
@Observable
final class ProjectListViewModel {
    /// 单一状态源, View 层读这 4 个属性。
    enum State {
        case loading
        case loaded([ProjectSnapshot])
        case empty
        case error(String)
    }

    private(set) var state: State = .loading
    private(set) var selectedProjectID: UUID? = nil  // 给其它区读

    private let store: WenshuProjectStore

    init(store: WenshuProjectStore = .shared) {
        self.store = store
    }

    /// App 启动时调一次 + 创建 / 删除后调。
    func load() async {
        state = .loading
        do {
            let projects = try await store.loadAll()
            state = projects.isEmpty ? .empty : .loaded(projects)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    /// 新建 project。返回新 project 给 caller(用于 push 跳转)。
    func create(_ project: ProjectSnapshot) async throws -> ProjectSnapshot {
        let saved = try await store.create(project)
        await load()  // 重新 load, 顶部插入
        return saved
    }

    /// 软删除。
    func delete(_ id: UUID) async throws {
        try await store.delete(id)
        if selectedProjectID == id { selectedProjectID = nil }
        await load()  // 重新 load, 列表少一项
    }
}
```

### 6.2 ProjectListView(改造现有 120 行)

**位置**:`Sources/WenshuApp/Views/Project/ProjectListView.swift`(本卡改名从 `Views/ProjectListView.swift` 移过来 — 区块模块化硬要求)

**职责变化**:
- 不再接 `@Binding<[ProjectSnapshot]>` + `@Binding<NavigationPath>` — 改为接 `@State private var vm = ProjectListViewModel()` + `@State private var navPath = NavigationPath()`
- 不再依赖 MainView 的 navPath(隔离)
- 内部 wrap NavigationStack(path: $navPath)

**视觉不变**:
- toolbar `.primaryAction` 的 `+` 按钮(改 push 进 `.create` route,不是 sheet)
- 空状态(`tray` icon + "暂无项目")
- 列表项(name + style + 注水 + tags + 日期)

**新行为**:
- 点列表项 → push `.detail(project.id)`,不是 `AppRoute.chat`
- 长按 / 右键列表项 → 显示 `.contextMenu` 「删除」 + 「重命名」(删除本卡范围,重命名留后续卡)

### 6.3 ProjectCreateView(改造现有 160 行)

**位置**:`Sources/WenshuApp/Views/Project/ProjectCreateView.swift`

**接口变化**:
```swift
struct ProjectCreateView: View {
    /// push destination 调用方提供,创建成功时触发。
    var onCreate: (ProjectSnapshot) -> Void

    @State private var name: String = ""
    @State private var style: String = "严肃"
    @State private var verbosity: Double = 5
    @State private var tagsText: String = ""

    @FocusState private var nameFocused: Bool

    private let styles: [String] = ["严肃", "轻松", "诗意", "幽默", "口语"]
    // ... 表单 UI 沿用现有 ...
}
```

**删**:
- `onCancel` 闭包(改用 `@Environment(\.dismiss)`)
- `WindowActivation.forceKeyToWenshuSheet()` 调用
- `.frame(minWidth: 520, minHeight: 480)` 强制尺寸(让上层容器决定 — 区块模块化)

**保留**:
- 5 段表单(基本信息 / 文笔风格 / 注水量 / 标签 / 预览)
- 实时 preview(同步显示当前填的内容)
- @FocusState auto-focus(0.3s delay,沿用 WO-006 经验)

### 6.4 ProjectDetailView(新增)

**位置**:`Sources/WenshuApp/Views/Project/ProjectDetailView.swift`(新建)

**职责**:显示当前选中 project 的详情 + 5 tab bar

**结构**:
```swift
struct ProjectDetailView: View {
    let projectID: UUID
    @State private var selectedTab: ProjectTab = .overview

    var body: some View {
        VStack(spacing: 0) {
            // 顶部: project header (name + style + verbosity + tags + 日期)
            projectHeader
            Divider()
            // tab bar
            tabBar
            Divider()
            // tab 内容(本卡只实装 .overview)
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(navTitle)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(ProjectTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .frame(height: 36)  // wenshu.tabBar.height
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .overview:
            ProjectOverviewTab(projectID: projectID)  // 实装
        case .chapters, .settings, .materials, .board:
            // LT-N2~N5 实装,本卡 placeholder
            DisabledTabPlaceholder(title: tabTitle(selectedTab))
        }
    }
}

enum ProjectTab: String, CaseIterable, Identifiable, Hashable {
    case overview     // 项目 — 本卡实装
    case chapters     // 章节 — LT-N2
    case settings     // 设定 — LT-N3
    case materials    // 资料 — LT-N4
    case board        // 看板 — LT-N5

    var id: String { rawValue }
}
```

**ProjectOverviewTab**(本卡实装):
- 显示完整 project 信息(name / style / verbosity / tags / createdAt / 初始故事占位)
- 统计卡片:章节数(从 CDNote 聚合,tags 包含 "project-{id}-chapter")、伏笔数、修订数
- "返回项目列表"按钮(`@Environment(\.dismiss)`)

### 6.5 5 tab 命名(⚠️ 等 PM-direct 拍 + 注意命名一致)

按 AGENTS §8.1 字面口径:项目 / 章节 / 设定 / 资料 / 看板
按本卡 §3.4 的 ProjectTab enum:`overview / chapters / settings / materials / board`

designer 推荐**沿用 AGENTS §8.1 的中文显示名**(项目 / 章节 / 设定 / 资料 / 看板),enum key 用英文(方便代码)。**⚠️ 等 PM-direct 拍显示文案**。

---

## 7. 状态机(本卡覆盖的全部 view state)

| View | 状态 | 视觉表现 | 触发 |
|------|------|------|------|
| ProjectListView | `loading` | 居中 `ProgressView()` + "加载中…" | vm.state == .loading |
| ProjectListView | `empty` | 现有 64pt `tray` icon + "暂无项目" + "点 + 新建" | vm.state == .empty |
| ProjectListView | `loaded` | List 列出所有项目 | vm.state == .loaded |
| ProjectListView | `error` | 红色 `exclamationmark.triangle` + "加载失败: \(msg)" + "重试" button | vm.state == .error |
| ProjectListView row | `default` | name + meta (style / 注水 / tags / 日期) | hover 之前 |
| ProjectListView row | `hover` | 背景 `.quaternary` material + 6pt 圆角 | 鼠标 hover |
| ProjectListView row | `selected` | 背景 `.tint.opacity(0.15)` + 蓝色左边框 2pt | push 进 detail 后 |
| ProjectListView row | `contextMenu` | 右键弹出菜单: 删除(本卡) / 重命名(后续卡) | 右键 |
| ProjectCreateView name field | `default` | rounded border + placeholder "项目名(必填)" | name == "" |
| ProjectCreateView name field | `filled` | rounded border + 当前 name | name != "" |
| ProjectCreateView name field | `error` | 红色 border + 下方 "项目名必填"(trim 后空) | nameFocused lost && trimmed empty |
| ProjectCreateView 创建 button | `disabled` | `.tertiary` foreground + 不响应 click | name trimmed empty |
| ProjectCreateView 创建 button | `enabled` | `.accentColor` foreground + 响应 click | name trimmed != "" |
| ProjectDetailView tab | `active` | `.primary` foreground + 底部 2pt `.tint` 高亮 | selectedTab == self |
| ProjectDetailView tab | `default` | `.secondary` foreground | selectedTab != self |
| ProjectDetailView tab | `disabled` | `.tertiary` foreground + `cursor.notAllowed` + click 不响应 | LT-N2~N5 未实装 |

---

## 8. 响应式(macOS 优先, iPad/iPhone 留后续)

### 8.1 macOS(本卡唯一目标)

- **窗口最小尺寸**:900 × 600(沿用 LayoutShellView 的最小尺寸)
- **左上区最小宽度**:200px(项目列表至少能看一行)
- **左上区最大宽度**:400px(再宽就该拖去隔壁 panel, 项目管理不是主角)
- **折叠态**:沿用 AGENTS §8.1 — 折叠到 50px gutter(icon-only "项目"图标 + tooltip)
- **拖拽**:沿用 LT-01 的 NativeSplitter(不要新增 splitter 类型)

### 8.2 iPad / iPhone(本卡不实现,留 v0.06.0)

- AGENTS §8 v0.06.0 = iPhone 端,本卡不预设 iOS 适配
- 不写 `.navigationViewStyle(.stack)`(那是 iOS-only 兼容)
- 不写 `UIKit` interop(本卡纯 SwiftUI)

---

## 9. 拍板真值核对(必须显式核对 AGENTS §8.1 + §3)

| 拍板 | 本卡是否遵守 | 怎么遵守 |
|------|------|------|
| §3 场景驱动排序 | ✅ | LT-N1 = 项目管理 = 装机 user 创建项目后第一个能跑的模块 |
| §3 区块模块化 | ✅ | 左上区 = 独立 App 模块,内嵌 NavigationStack,不依赖外部路由 |
| §3 迭代可独立运行 | ✅ | 装机 user 拿到 LT-N1 后能跑通「创建 → 列表 → 详情 → 删除」完整 8 步,不依赖 LT-N2~N5 |
| §8.1 5 区 layout | ✅ | 左上 panel 容器是 `PanelContainer(.topLeft)`,不放 layout 逻辑 |
| §8.1 折叠 + 拖拽 | ✅ | 沿用 LayoutShellView 的折叠 + NativeSplitter,本卡不新增 splitter |
| §8.1 状态存 .ws | ✅ | WenshuProjectStore 写 CDNote(走矛盾 1 读法 B 反查方案) |
| §5 CC 写代码边界 | ✅ | 本卡只 designer 出设计意图, CC 实现 |
| §7 数据资产硬约束 | ✅ | 跨设备靠复制 .ws / iCloud / Git, 文枢不参与 |
| §12 跨边界红线 — 不改 .ws schema | ⚠️ 矛盾 1 触发 | 走读法 B(不建 CDProject entity), 等 PM-direct 拍 |
| §12 跨边界红线 — 不改 LLM provider 签名 | ✅ | 本卡不涉及 LLM |
| §12 跨边界红线 — 不替用户拍产品需求 | ✅ | 4 个矛盾点都列出来等拍, 不擅自选边 |

---

## 10. SwiftUI 实现建议(给 CC)

按 `swiftui-design-patterns` skill §2 出 SwiftUI API 选择建议。**designer 出建议, CC 实施**:

### 10.1 列表

- 用 `List` + `Section`(沿用现有 ProjectListView 写法, 不换 LazyVStack)
- 列表项用 `Button { } label: { row }` + `.buttonStyle(.plain)`(沿用现有)
- hover 状态用 `.background(.quaternary, in: RoundedRectangle(cornerRadius: 6))` + `.onHover { hovering in ... }`
- selected 状态用 `.listRowBackground(.tint.opacity(0.15))`(macOS HIG 标准)

### 10.2 表单

- 沿用现有 `Form` + `Section` + `formStyle(.grouped)` 写法
- Picker 风格 `.segmented`(5 个 style 不多)
- Slider 1-9(沿用现有)
- TextField tags 用逗号分隔(沿用现有 + 解析逻辑)

### 10.3 NavigationStack

- 内嵌 NavigationStack(path: $navPath)(**不是** MainView 的 NavigationStack)
- `NavigationLink(value: ProjectRoute.create) { }` 或 `navPath.append(.create)`
- `navigationDestination(for: ProjectRoute.self) { route in switch route { ... } }`

### 10.4 Tab bar(ProjectDetailView)

- 用 `HStack(spacing: 0)` + 自定义 tab button(不用 SwiftUI TabView,那是 root tab 切换)
- 每个 tab button 是 `Button { selectedTab = .xxx } label: { ... }`
- active 状态:底部 2pt `.tint` 高亮(`VStack { Text; Color.accentColor.frame(height: 2) }`)
- disabled 状态:`.disabled(true)` + `.foregroundStyle(.tertiary)`

### 10.5 状态机

- `vm.state` 是 `enum State`(loading / loaded / empty / error),不是 4 个独立的 `@State var`
- View 用 `switch vm.state { case .loading: ...; case .loaded(let projects): ...; ... }`
- 不要用 `@Published var isLoading: Bool` + `@Published var projects: [ProjectSnapshot]`(两个独立状态可能不一致)

---

## 11. 边界(designer 不做的事)

- ❌ 不写任何 `.swift` 代码(designer 只出设计意图)
- ❌ 不改 `LayoutShellView.swift`(那已经 LT-01 + fix17 拍板,改 = 越界)
- ❌ 不改 `WenshuStoreActor.swift`(改 schema = §12 红线,等 PM-direct 拍)
- ❌ 不改 `WenshuProjectStore.swift` 的现有方法签名(只增 `loadAll / create / delete / load(id:)`,不改 `save / firstSavedStory / savedCharacterNames`)
- ❌ 不调 `swift build`(那是 CC 责任)
- ❌ 不调 `swift test`(那是 CC 责任)
- ❌ 不删 `ProjectListView.swift` / `ProjectCreateView.swift` 的现有文件(designer 只设计, 改文件 = CC 责任)
- ❌ 不写 `.ws` schema 新 entity(走矛盾 1 读法 B)
- ❌ 不实现 5 tab 里的章节 / 设定 / 资料 / 看板 4 个(那是 LT-N2~N5)
- ❌ 不实现"重命名"功能(那是后续卡的 scope)

---

## 12. 配套资源

- **本卡依赖**:AGENTS.md §3 + §5 + §8.1 + §12,`swiftui-design-patterns` skill §4(token)+ §2(SwiftUI API)
- **本卡被依赖**:LT-N2 (章节) + LT-N3 (设定) + LT-N4 (资料) + LT-N5 (看板) 都会在 ProjectDetailView 的 tab bar 上加新 tab
- **本卡拍板**:见 §0 — 4 个矛盾点等 PM-direct / 装机 user 拍板
- **本卡验收**:装机 user 拿到后能跑通 §1 的 8 步 + 软删除后重启 App 列表仍少那一项(.ws 持久化验证)

---

*DESIGN-LT-N1 v0.1 · designer · 2026-08-10 · 等 PM-direct 拍 §0 4 个矛盾点*
