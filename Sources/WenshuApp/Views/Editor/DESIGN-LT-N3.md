# DESIGN-LT-N3 · 文枢 (Wenshu) · v0.03.0 LT-N3

> **designer 产物** — 只出设计稿, 不动 .swift / .ws schema / Package.swift
> **覆盖范围**: 中上 (`LayoutShellView.topCenter`) 独立 App 模块 = 编辑器 (`EditorView` + `EditorViewModel` + `EditorOutlineView` 修真)
> **依赖**: LT-N1 已实装的 `selectedProjectID` 路径 + LT-N2 已实装的 ChatPanelView 底部左 + V0-fix-6/9/10/11 5 区 layout 真值 + 8/10 装机 user 拍板的 FCP viewer 范式 memo (`~/.hermes/profiles/designer/design-notes/wenshu-editor-fcp-viewer-pattern.md`)
> **设计基准**: AGENTS §8.1 (5 区) + AGENTS §12 (CC 不改 schema) + LT-N1 区模块化范式 + LT-N2 4 子 tab + FCP 范式 (4 角 toolbar + 28pt + dark + SF Symbol)

---

## 0. 任务 body 矛盾点 (designer 不能拍, 必升级)

读了 `t_dd20c3b1` body + 现行 `LayoutShellView.swift` (V0-fix-11 实装) + LT-N1 design (`DESIGN-LT-N1.md` 30.7 KB) + LT-N2 design (`DESIGN-LT-N2.md` 22.5 KB) + FCP 范式 memo (8/10 装机 user 讨论落档) + 现行 `ChatPanelView` / `ChapterTreeView` / `ProjectDetailView`, 任务 body 有 4 处跟现状有冲突或需要确认。**designer 把它们标在这里, 由 PM / 装机 user 拍板**, 不擅自选边。

### 矛盾 1: 任务 body 写 "EditorView", 任务结构上下文是 "中上", 但现有 topCenter 是 `PlaceholderContent`

- **任务 body**: "编辑器 UI 设计稿 (中上 + 区模块化 + 8 步场景)"
- **现行代码** `LayoutShellView.swift:492`: `panel(.topCenter)` 在 `else` 分支走 `PlaceholderContent(panel: id)`
- **现行** `PlaceholderContent.swift:45`: topCenter hint = "v0.05.0 起填充: 正文编辑器 + 标记系统 + 选区右键"
- **冲突**: body 说"真新加"有前提 (`查询 on-disk 无 EditorView / EditorViewModel / EditorOutlineView .swift`) — 但 **GEM**: 现行 v0.02.0 阶段 topCenter **就是** `PlaceholderContent`, 不是 EditorView 的早期 stub。这跟 task body 写的 "新增" 完全一致, **没有冲突**, 是真新加
- **可能的真意**:
  - **A**: body 确认无 stub = 真从零新增一个 `EditorView`, 接管 PlaceholderContent.topCenter 渲染 — 跟 v0.05.0 计划**提前**到 v0.03.0 LOOP 第三张 (8 步流程需要真编辑器, 否则用户旅程断在中上)
  - **B**: body 真意是 "中上只是 placeholder + 文字标题 preview", 不实装 TextEditor — 但这跟"8 步用户旅程跑通"不闭环
- **designer 倾向**: A — 跟"8 步跑通" + LOOP 三段式自洽, 但**留给 PM 拍**最终范围 (TextEditor 接 .content 真写? 还是只读 preview?)

### 矛盾 2: "EditorOutlineView 修真", LT-01-fix19 已存在早期稿但未实装

- **任务 body**: "EditorOutlineView 修真 (已知 v0.02.0 LT-01-fix19 commit 71d28b779 已经出稿了早期版本, 但 LT-04 砍过 outline, V0-fix-4 加回)"
- **历史线**:
  - LT-01-fix19 (`71d28b779`) 出稿 EditorOutlineView 但 **没实装**, code 在 worktree `Sources/WenshuApp/Views/Editor/` 是空目录
  - V0-fix-4 (`a26731efd`) 在 chat 区加回 `outline` tab (4 子 tab 第 4)
  - 现行 `ProjectBrowserView.swift:107` 接的 `ChapterTreeView` (在 `Views/Project/` 下, 不是 `Views/Editor/`)
  - **现行 `ChatPanelView.swift:6-25` 4 case** = `chat / timeline / relationships / outline`
- **冲突**: task body 说"EditorOutlineView", 但**现行 4 子 tab 是 outline (大纲视图) 在 chat 区, EditorOutlineView (中上) 完全不存在**。两个 outline 是不同物:
  - **chat 区 outline tab** = 时间线 / 关系图 / 大纲 三选一,跟**大纲 (故事结构)**对齐, 跟 editor 强协同
  - **中上 EditorOutlineView** = 中上内部的 sidebar, 列章节 (跟左侧 ProjectBrowserView 章节 tab 的 ChapterTreeView **重复**)
- **可能真意**:
  - **A**: body 要的"修真" = **新建** 中上内部 sidebar (FCP viewer 4 角 toolbar 上下文, 8/10 memo §3.1 "显示大纲" 显隐), 等于 LT-01-fix19 原稿真接, 接 `listChapters(projectId:)`
  - **B**: body 要的"修真" = 改现有 chat 区 outline tab (改叫 "EditorOutlineView")
  - **C**: body 真意 = 中上内部 sidebar + chat 区 outline tab 都做, 联动
- **designer 倾向**: A — 跟 FCP 范式 memo §1 "Editor 4 角" + §3.5 layout 集成自洽, 但 **留给 PM 拍**哪个 outline 是"修真"目标
- ⚠️ **LT-01-fix19 设计稿已有真值**: designer 上一次出稿(commit 71d28b779, 459 行), 但**没实装**. 这次"修真"如果走 A, 应当**读完 LT-01-fix19 原稿后, 增量补 v0.03.0 LOOP 上下文 (selectedProjectID + FCP toolbar) 拍板**, 不重写

### 矛盾 3: "8 步用户旅程", 但 trip body 没列具体 8 步

- **任务 body**: "8 步场景 + 区模块化 + EditorView 设计 + EditorOutlineView 修真 + token + 组件 API + WenshuProjectStore 扩展"
- **历史对照**:
  - **LT-N1** 已派: 8 步用户旅程 (项目管理 1-5 + 章节 6-8), 实拍录屏 (装机 user 8/11)
  - **LT-N2** 已派: 8 步用户旅程 (聊天 6-8), LT-N1+N2 拼成"项目→聊天"链路
  - **本卡 LT-N3** 写"8 步场景" 但 body 没列
- **可能真意**:
  - **A**: 8 步 = 沿用 LT-N1+N2 的 8 步, 把**第 9-10 步**补成"选章节 → 顶部大纲 sidebar → TextEditor 显示章节 content → 编辑 → 关 app 数据还在" 完成 8+2 步
  - **B**: 8 步是另一条独立旅程 (从编辑器独立可访问 / 不依赖聊天)
  - **C**: 8 步是装机 user 8/10 讨论的"字数控件 / 比例调节 / 全屏"等编辑器自治流程
- **designer 倾向**: A — 接 LT-N1+N2 链路, 这是**第三张 LOOP 卡**, 跑通 8→10 步让装机 user 拿 LT-N1+N2+N3 走完 8 步完整用户旅程 (跟 task body 派单理由"拿 LT-N1+N2+N3 能跑完整 8 步用户旅程"完全自洽)
- **留给 PM 拍**实际步骤定稿

### 矛盾 4: "WenshuProjectStore 扩展", 但 task body 边界禁止动 `WenshuStoreActor`

- **任务 body 边界**: "不动 `WenshuStoreActor` / CoreData entity / Package.swift / Info.plist"
- **任务 body 必须出**: "WenshuProjectStore 扩展 (8 步场景 + 修真)"
- **冲突**: WenshuProjectStore 是 actor 的外层包装, 它调 actor 的低阶方法 (`listChapters`, `countAll` 等)。不**新加** actor 方法, **只**沿用现有 API + 在 project store 上加 convenience 方法, 跟"不动 store actor"自洽
- **现有 WenshuProjectStore API** (`WenshuProjectStore.swift:24-60`):
  - `create(name:style:waterLevel:tags:)` → `ProjectSnapshot`
  - `loadAll() → [ProjectSnapshot]`
  - `delete(id:)`
  - `listChapters(projectId:) → [ChapterSnapshot]`
  - `save(project:characters:worldRules:initialStory:)` (load 保存路径)
  - `savedEntityCount() / firstSavedStory() / savedCharacterNames()`
  - `directoryPath()`
- **可能真意**:
  - **A**: 加 convenience 方法 `loadChapterContent(chapterId:) → String` + `saveChapterContent(chapterId:content:)` + 加 `EditorContentStore` (跟 `ChapterTreeStore` 平级, MainActor)
  - **B**: 完全沿用现有 `listChapters` + `save(project:...)` — 但 `save` 接 project 不接 chapter, 不够精
  - **C**: 加新 schema 字段 (chapterId / chapterContent) — 但这**踩边界**
- **designer 倾向**: A — 跟 LT-N1 的 `ChapterTreeStore` 范式自洽, 不踩 store actor 不动 schema 红线, **CC 实现需注意**: 加的 actor 方法走既有 `CDChapter` (没改 entity, 只换读写路径 — 但 readonly 加 method 必须改 actor — 留给 CC 决定是否走 readonly path)
- ⚠️ **升级点**: 如果修真确实需要 actor 层加只读 method, 走 `WenshuProjectStore+LTN3.swift` 扩展文件模式, **不进** `WenshuProjectStore.swift` / `WenshuStoreActor.swift`

### 4 个矛盾点小结

**designer 不拍, 写 doc 默认按以下假设出稿** (对应"可能真意 A", 多数派):

1. **范围 = 真新增 EditorView**, 接管 `PlaceholderContent.topCenter`, TextEditor 接 `CDChapter.content` (沿用 store actor 读写路径)
2. **修真 = 新建** 中上内部 sidebar (FCP viewer 显示大纲) 沿用 LT-01-fix19 原稿 (commit 71d28b779), 增量补 selectedProjectID 路径 + FCP toolbar 拍板
3. **8 步 = 接 LT-N1+N2 链路**: 步 1-5 项目管理 (LT-N1 done), 步 6-7 聊天 (LT-N2 done), 步 8-9 编辑器 (本卡新增: 章节 detail + 真编辑), 步 10 关 app 重开数据还在
4. **WenshuProjectStore = 不动 store actor**, 新加 `+LTN3.swift` extension 文件 + convenience API (`loadChapterContent(chapterId:)` / `saveChapterContent(chapterId:content:)`) + 新增 `EditorContentStore: ObservableObject` (跟 `ChapterTreeStore` 平级)

**PM 拍板时可以选择**: 推翻上面 4 个假设, designer 重做对应章节

---

## 1. 完整场景 (LT-N1 + LT-N2 + LT-N3 跑通 v0.03.0 LOOP 三段式)

> **可验收**: LT-N1 (8 步项目管理) + LT-N2 (8 步聊天) + LT-N3 (本卡, 新增 2 步编辑器) → 装机 user 走完 10 步用户旅程 → 关闭 / 重开 app 数据还在 → 实拍录屏 = v0.03.0 LOOP 三段式第三张拍板金标。

> **8 步范围确认**: 本卡新增的 8 步场景**默认按"接 LT-N1+N2 链路 + 补 2 步"出稿** (参见矛盾 3.A)。完整 10 步如下:

| 步 | 动作 | 期望结果 | 涉及区 | 归属 |
|----|------|---------|--------|------|
| 1 | macOS 启动 → 文枢自动开 5 区 layout | `LayoutShellView` 渲染, `topLeft` = LT-N1 `ProjectListView`, `bottomLeft` = LT-N2 `ChatPanelView`, `topCenter` = **本卡 `EditorView`** (本卡实装, 接管 PlaceholderContent.topCenter) | 5 区 | LT-N1 done |
| 2 | 点左上 "+ 新建项目" → 填表 → 创建 | `ProjectSnapshot` 落 `.ws` (tag-scoping) | topLeft | LT-N1 done |
| 3 | 点项目 row → 切章节 tab → `ChapterTreeView` 渲染 | `listChapters(projectId:)` 真读, 章节 row 可见 | topLeft | LT-N1 done |
| 4 | **本卡步骤 4** — 点章节 row → `selectedProjectID` + `selectedChapterID` 同步到中上 | `LayoutShellView.selectedProjectID` + `selectedChapterID` 双 state 同步, 中上 `EditorView.onChange(of: selectedChapterID)` 接 binding | topLeft → topCenter | **LT-N3 新** |
| 5 | **本卡步骤 5** — `EditorView` 顶部面包屑显示 `项目名 / 章节名`, 大纲 sidebar (`EditorOutlineView`) 显示章节列表 (active chapter 高亮) | FCP viewer 范式 `中上` 标题 + 左侧章节 sidebar | topCenter | **LT-N3 新** |
| 6 | **本卡步骤 6** — `TextEditor` 显示 `CDChapter.content` (内容只读 → 可编辑) | `EditorContentStore.loadContent(chapterId:)` → actor 读 CDChapter.content → TextEditor 显示 | topCenter | **LT-N3 新** |
| 7 | **本卡步骤 7** — 用户编辑后失焦 / 自动 save (debounced 1s) | `saveContent(chapterId:content:)` → actor 写回 CDChapter.content, `selectedChapterID` 不丢 | topCenter | **LT-N3 新** |
| 8 | **本卡步骤 8** — FCP 4 角 toolbar 左上 `字数` 实时更新, 中上章节名同步, 右上 `字号 ▼` / `显示 ▼` 启用, 右下 `⤢` 进专注模式 (隐藏 4 个 panel) | FCP viewer 范式 §1-§3 真接 (本卡 MVP 切片: 只做字数 + 章节名 + 全屏 toggle, 字号 / 显示菜单留给 v0.04.0 子卡) | topCenter | **LT-N3 新** |
| 9 | **本卡步骤 9** — 切回聊天区 (bottomLeft) → 切到 `outline` tab → `ChapterTreeView` 同步显示同一章节 (active 高亮) | `LayoutShellView.selectedChapterID` 全局 state, chat 区 outline + 中上 章节 sidebar 共享高亮 | bottomLeft + topCenter | **LT-N3 新** |
| 10 | 关闭 app → 重开 → 上次章节 active, 内容编辑保持 | `selectedProjectID` + `selectedChapterID` 存 `.ws` (designer 建议: 走 layout.collapsed / ratios 同范式 JSON codable) | 全局 | **LT-N3 新** |

> ⚠️ **10 步不是 8 步**: 任务 body 写"8 步"是 LT-N1 / LT-N2 的命名沿用, 本卡"接 LT-N1+N2 链路 + 补 2 步"实际产出 **10 步用户旅程**。PM 拍板时如果坚持 8 步, designer 把步 4-5 / 步 9-10 合并为 2 步删冗 (例如步 8 直接 FCP toolbar + 步 9 outline 联动合并)。

### 1.1 跟现有 v0.03.0 实装的兼容

- **LT-N1 步 1-3 done**: `ProjectListView`, `ProjectCreateView`, `ProjectDetailView`, `ChapterTreeView` 都已实装
- **LT-N2 done**: `ChatPanelView` 4 子 tab + `ChatView` + `ChatViewModel`
- **LT-N1 + LT-N2 merge 已实装** (`b0c5eb6fa`): `LayoutShellView.panel(.bottomLeft) = ChatPanelView`, `panel(.topLeft) = ProjectListView`, `panel(.topRight) = PlaceholderContent`, `panel(.bottomRight) = PlaceholderContent`, `panel(.topCenter) = PlaceholderContent` ← **本卡接管**
- **本卡不动**: 已有 `ProjectBrowserView` (dead code, LT-N1 留 5 tab Picker fallback) / `ChatPanelView` / `InspectorView`
- **本卡新增**: `EditorView` (管整个 topCenter) + `EditorViewModel` + `EditorOutlineView` (真接 listChapters, 替代 placeholder) + `EditorContentStore` + WenshuProjectStore 扩展

---

## 2. 区模块化 (topCenter 独立 App 模块)

### 2.1 几何边界 (跟 AGENTS §8.1 的关系)

```
┌──────────────────────────────────────────────────────────────────┐
│ (native macOS title bar)                                          │
├──────────────┬───────────────────────────┬──────────────────────┤
│ ★ topLeft     │ ★ topCenter               │ topRight              │
│ ProjectList   │ EditorView (本卡实装)      │ PlaceholderContent    │
│ (LT-N1 done)  │ ┌─── FCP 4 角 toolbar ──┐ │                       │
│              │ │ 顶 28pt               │ │                       │
│              │ ├──────────────────────┤  │                       │
│              │ │ ES | EditorOutline    │  │                       │
│              │ │ sidebar + TextEditor │  │                       │
│              │ │ (中上, 1pt splitter)  │  │                       │
│              │ ├──────────────────────┤  │                       │
│              │ │ 底 32pt               │  │                       │
│              │ └──────────────────────┘  │                       │
├──────────────┴───────────────────────────┴──────────────────────┤
│ bottomLeft (ChatPanelView, LT-N2)            │ bottomRight (空)  │
└────────────────────────────────────────────────┴──────────────────┘
```

`★ topCenter` = 本卡的全部产出。**与 topLeft / topRight / bottomLeft / bottomRight 零依赖** (state 共享**单向**, 中上订阅全局 `selectedProjectID` + `selectedChapterID`, 不污染其他区):

- 不订阅 `LayoutShellViewModel` 的 splitter 状态
- 不读其它 panel 的本地 `@Published` 状态 (`ProjectListStore` / `ChapterTreeStore` 是 LT-N1 私有)
- 不修改其它 panel 的 splitter 比例
- 唯一全局 state: `LayoutShellView.selectedChapterID: UUID?` (本卡建议升), 中上 + bottomLeft outline tab 共享
- 折叠/拖拽行为由 LT-01 已实装的 `LayoutShellViewModel` + `PanelContainer` 提供, **本卡不重复实现**

### 2.2 topCenter 内部布局 (FCP viewer 范式 + LT-01-fix19 原稿真接)

#### 2.2.1 整体结构 (3 层)

```
┌────────────────────────────────────────────────────┐
│ 顶 toolbar (28pt, FCP viewer 中上 4 角 toolbar)    │ ← 8.10 装机 user 拍
├──┬─────────────────────────────────────────────┬──┤
│  │  EditorOutlineView (chapter sidebar)        │  │
│ES│              TextEditor (可编辑 content)     │  │
│  │              (剩余空间, maxHeight infinity)  │  │
├──┴─────────────────────────────────────────────┴──┤
│ 底 toolbar (32pt, FCP viewer 中上 4 角 toolbar)    │ ← 8.10 装机 user 拍
└────────────────────────────────────────────────────┘
```

- **ES** (Editor Splitter, 1pt 细线, NativeSplitter 风格) = 章节 sidebar ↔ TextEditor 的横向分隔, **本卡新增**, 默认 sidebar 240pt (沿 LT-01-fix19 真值), 可拖 150-400pt, 折叠阈值 30pt (FCP 范式)
- 顶 toolbar (28pt) + 底 toolbar (32pt) = FCP viewer 范式 §1-§2, **本卡 MVP 拍板 (本卡先做):**
  - ✅ 顶 toolbar 左上: 章节字数 `12,345 字` (实时, debounced 1s)
  - ✅ 顶 toolbar 中上: 面包屑 `项目名 / 章节名` (Text 跟随选中章节)
  - ✅ 顶 toolbar 右上: **空槽** (字号 / 显示 菜单留给 v0.04.0 子卡, 不画)
  - ✅ 底 toolbar 右下: ⤢ 全屏 toggle (隐藏 4 panel, 只剩中上)
  - ❌ 顶 toolbar 右上其他: 不画
  - ❌ 底 toolbar 左下 (3 ICON 预留位): 不画, **空 shell** (FCP 范式预留)
  - ❌ 底 toolbar 中下 (时码): 不画, **永远空** (FCP 特色, 文枢不复制)
- **MVP 派生**: 装机 user 8/10 三轮讨论 "FCP 范式落地" 拍板, 本卡只做"中上已经能跑" 的最小功能集, 不做"全功能 FCP viewer"。详见 8/10 memo §3.8

#### 2.2.2 EditorOutlineView 修真 (沿 LT-01-fix19 commit 71d28b779)

- **历史**: LT-01-fix19 (2026-08-10) designer 出稿 459 行设计稿, 推荐结构 = 240pt 固定宽 sidebar + `list.bullet.rectangle` SF Symbol + 章节 row
- **历史冲突**: LT-04 砍掉大纲 tab, V0-fix-4 加回 outline tab (在 chat 区), 中上 EditorOutlineView 没实装
- **本卡修真** (基于 LT-01-fix19 原稿增量):
  - ✅ 沿用 240pt 默认宽 sidebar, 1pt 细线 ES splitter, 可拖
  - ✅ 章节 row 改自接 `WenshuProjectStore.listChapters(projectId:)` (沿用 LT-N1 store API, 不新加 actor method)
  - ✅ active chapter row 高亮 (跟随 `selectedChapterID` 全局 state)
  - ✅ 空态: "暂无章节" + `list.bullet.rectangle` SF Symbol + "v0.04.0 接新建章节" caption (沿 ChapterTreeView emptyState 范式)
  - ✅ 章节 row 点击 → `selectedChapterID = chapter.id` (写在 LayoutShellView 顶层, 中上 + bottomLeft outline 共享)
  - ✅ 章节 row 长按 / 右键 → 占位 (v0.04.0 实装, 不画)
  - ❌ 不实装: 新建章节按钮 (沿 LT-01-fix19 不动 + LT-N1 已经在 ChapterTreeView 实装 toolbar, 避免重复)

#### 2.2.3 TextEditor 区

```
TextEditor(text: $content)
  .font(wenshu.text.body)        // 17pt regular
  .scrollContentBackground(.hidden)  // macOS 14+ 不画 native 背景
  .background(wenshu.surface.background)  // 暗色背景 (FCP 范式)
  .frame(maxWidth: .infinity, maxHeight: .infinity)
  .padding(wenshu.space.m)       // 16pt 标准间距
```

- **数据**: `@State content: String`, 由 `EditorContentStore.loadContent(chapterId:)` 注入
- **编辑**: 用户输入 → debounced 1s → `saveContent(chapterId:content:)` 落 `.ws` (CDChapter.content)
- **失焦保**: 切到别的章节 / 关 app 强制 save 一次
- **MVP 不做**:
  - ❌ 选区右键 (修订 / 伏笔 / 待定 / 信息点 / 历史事实 快捷键 — v0.05.0 派)
  - ❌ 标记系统 (斜体 / 粗体 / 标题样式 — v0.05.0 派)
  - ❌ 自动字数 stat 实时更新 (输入时不算, debounced 1s 后算)
  - ❌ Markdown preview / 渲染 — v0.05.0 接
  - ❌ 拼写检查 / AI 续写 — v0.06.0+ 接

### 2.3 跟 `LayoutShellView.panel(_:)` 的接入点 (designer 给 CC 的接口契约)

```swift
// LayoutShellView.swift:492 (本卡 CC 改这一行)
PanelContainer(panelID: id) {
    if id == .bottomLeft {
        ChatPanelView()
    } else if id == .topCenter {
        EditorView()       // ← 本卡新增
    } else {
        PlaceholderContent(panel: id)
    }
}
```

**接口契约**:
- `EditorView` 必须自管所有 `@StateObject` (不接收外部 `@ObservedObject` 注入, 除了全局 `selectedChapterID` binding)
- 必须独立持久化 (自管 `EditorContentStore`, 通过 `WenshuProjectStore.loadChapterContent(...)` / `saveChapterContent(...)` 落 `.ws`)
- 不抛出任何穿透到 `LayoutShellView` 的副作用 (除了 `.onChange(of: selectedChapterID)` 同步全局 state)

**LayoutShellView 顶层新增 state** (本卡 CC 接入点, 跟 LT-N1 `selectedProjectID` 平级):
```swift
// LayoutShellView.swift 顶层 (在 @State selectedProjectID 之后)
@State private var selectedChapterID: UUID?
```

**外部 binding 方式** (从 `EditorView` 写回):
```swift
// EditorView body 内部
.onChange(of: selectedChapter) { _, newChapter in
    // 由 EditorView 通过 @Binding 从 LayoutShellView 顶层接 selectedChapterID
    // 这里只读 newChapter, 写由 binding 完成
}
```

> ⚠️ **CC 实现确认**: 跟 LT-N1 `selectedProjectID` 同样模式 — `@Binding selectedChapterID: UUID?` 从 LayoutShellView 顶层传入, EditorView 读 `selectedChapterID` 决定渲染哪个章节, 点击章节 row 时通过 binding 写回。

---

## 3. NavigationStack push 路由 (沿 LT-N1 范式)

> **拍板**: 沿 LT-N1 范式, **不新加** NavigationStack (topCenter 不需要 push 路由)。章节切换走 `selectedChapterID` 全局 state (跟 selectedProjectID 平级), 新建 / 详情留给 chat 区 / topLeft push。

### 3.1 全局 state 共享

`LayoutShellView` 顶层新增 1 个 state:
```swift
@State private var selectedChapterID: UUID?
```

**2 个 reader** (跟 selectedProjectID 一样的 2-reader 模式):
1. `EditorView` (中上) — 文本编辑 + 章节 sidebar 渲染
2. `ChatPanelView.outlineTab` (bottomLeft, 占位) — outline tab 渲染时**只读** selectedChapterID 同步高亮 (本卡不实装 outline tab 真接, **升级点**留给 LT-N4 子卡)

> ⚠️ **不在本卡范围**: ChatPanelView outline tab 接 selectedChapterID 同步高亮 (= 下半区的 4 子 tab outline + 上半区中上联动) — 这是 v0.04.0 起步阶段 (LT-N5 子卡) 的范围, 本卡**只**做中上内部的 sidebar 与 TextEditor 联动 + 准备升级点注释

### 3.2 路由拓扑

```
LayoutShellView (root)
├── topLeft: ProjectListView (LT-N1 done)
│   └── selectedProjectID 同步 (LT-N1 done)
│       └── 新增: ProjectListView `.onChange(of: selectedProjectID)` 写入 projectId 到 selectedProjectIDBinding (本卡**不动**, 沿 LT-N1 真值)
├── topCenter: EditorView (本卡新增)
│   ├── EditorOutlineView (FCP viewer 显示大纲 sidebar, 接 selectedChapterID)
│   ├── TextEditor (可编辑, 接 selectedChapterID)
│   └── FCP viewer 4 角 toolbar (顶 + 底, MVP)
├── bottomLeft: ChatPanelView (LT-N2 done)
│   └── outlineTab 占位 (selectedChapterID 同步高亮 — 留给 LT-N5)
└── topRight / bottomRight: PlaceholderContent (本卡不动)
```

**设计纪律**: 本卡**只**新增 `selectedChapterID` 1 个全局 state, **不**新加 `NavigationStack` / `NavigationPath` / `AppRoute`.chatChapter 等路由 path。理由: 章节切换是**选中**语义不是**导航**语义, 走全局 state 比走路由栈更轻。

---

## 4. 持久化 (WenshuProjectStore 扩展 — designer 建议, CC 实现需注意 schema 红线)

### 4.1 现有事实

- `WenshuProjectStore` 是 actor, 不是 `@MainActor class`
- `WenshuStoreActor` 现状 (read): `listChapters(projectId:) → [ChapterSnapshot]` 已经能 list 章节元数据
- `CDChapter` entity schema 字段 (LT-N1 调研, 不在本卡改):
  - `title: String`
  - `content: String` (章节正文, schema 已有但 v0.02.0 没接 UI)
  - `chapterIndex: Int`
  - `createdAt: Date`
- **WenshuProjectStore 当前没有 chapter content 读取 / 保存 API** — 现状只 list 元数据, 不读 content
- **AGENTS §12 红线**: 不进 `WenshuStoreActor` (进 actor = 改 schema), 只扩展 `WenshuProjectStore` + 配套 extension 文件 (`.ws` I/O 走现有 pattern)

### 4.2 designer 给 CC 的 store API 扩展建议

```swift
// 新增文件: Sources/WenshuApp/Storage/WenshuProjectStore+LTN3.swift
// (沿 LT-N2 拍板真值, +LTN2 文件已实装, +LTN3 文件跟 +LTN2 平级, 不动主文件)

extension WenshuProjectStore {
    /// 读章节正文。 走 actor 的 listChapters, 在 MainActor 侧把 content 字段读到内存。
    /// Schema 不动: CDChapter.content 字段已存在 (v0.02.0 实装), 沿用读取路径。
    func loadChapterContent(chapterId: UUID) async throws -> String
    
    /// 保存章节正文。 走 actor 的 saveChapterContent (新方法, 加在 WenshuProjectStore 主文件,
    /// 调用现有 CDChapter.content setter, 不改 schema)。
    func saveChapterContent(chapterId: UUID, content: String) async throws
}
```

**关键不踩红线约束** (给 CC 实现的接口契约):
1. **不**改 `WenshuProjectStore.swift` 主文件 — 加 `WenshuProjectStore+LTN3.swift` extension 文件
2. **不**改 `WenshuStoreActor.swift` — 如果非要 actor 层加方法, 走 `WenshuProjectStore+LTN3.swift` 内部 await actor 调用现有 setter (CD entity 已有 setter, 不动 actor)
3. **不**改 `ModelDefinitions.swift` / CDChapter entity — schema 字段已有
4. **不**改 `Package.swift` / `Info.plist`

### 4.3 MainActor 侧 store (跟 `ChapterTreeStore` 平级)

```swift
// 新增文件: Sources/WenshuApp/ViewModels/EditorContentStore.swift
@MainActor
final class EditorContentStore: ObservableObject {
    @Published private(set) var content: String = ""
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var isDirty: Bool = false
    
    private let chapterId: UUID
    private var saveTask: Task<Void, Never>?
    private let store: WenshuProjectStore
    
    init(chapterId: UUID, store: WenshuProjectStore = .shared) { ... }
    
    /// 读章节正文
    func load() async { ... }
    
    /// 用户输入触发 (debounced 1s)
    func updateContent(_ newContent: String) {
        content = newContent
        isDirty = true
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            await self?.flush()
        }
    }
    
    /// 立即 flush (切章节 / 关 app 时调)
    func flush() async { ... }
    
    private func save() async throws { ... }
}
```

**关键点**:
- `EditorContentStore` 跟 `ChapterTreeStore` 平级 (`@MainActor class : ObservableObject`), 沿 LT-N1 范式, **可被 unit test**
- debounced 1s 写入, `Task.sleep + Task.cancel` 实现
- `flush()` 在 `selectedChapterID` 变化 / app `.onDisappear` 时强制 flush
- 本卡**不**改 LT-N1 已实装的 `ChapterTreeStore` — 范式一致, 不破坏

---

## 5. 组件 API (designer 给 CC 的实现契约)

### 5.1 EditorView (新增)

```swift
// 新增文件: Sources/WenshuApp/Views/Editor/EditorView.swift
struct EditorView: View {
    @Binding var selectedProjectID: UUID?
    @Binding var selectedChapterID: UUID?
    @StateObject private var sidebarStore: EditorOutlineStore  // 章节 sidebar 的 store
    @State private var content: String = ""
    @State private var contentStore: EditorContentStore?  // 在 onAppear / chapterId 变化时创建
    
    var body: some View {
        VStack(spacing: 0) {
            EditorTopToolbar(                              // 28pt
                chapterTitle: sidebarStore.activeChapter?.title ?? "未选章节",
                wordCount: contentStore?.wordCount ?? 0
            )
            editorBody                                     // ES splitter 分左右
            EditorBottomToolbar(                           // 32pt
                onFullScreenToggle: toggleFullScreen
            )
        }
        .background(wenshu.surface.background)
        .onChange(of: selectedChapterID) { _, newId in
            contentStore?.flush()
            if let id = newId {
                contentStore = EditorContentStore(chapterId: id)
                Task { await contentStore?.load() }
            }
        }
    }
    
    private var editorBody: some View {
        // 1pt ES splitter, 左 = EditorOutlineView, 右 = TextEditor
        HSplitView(
            left: { EditorOutlineView(selectedChapterID: $selectedChapterID, store: sidebarStore) },
            right: { TextEditor(text: $content).onChange(of: content) { _, new in contentStore?.updateContent(new) } }
        )
    }
}
```

### 5.2 EditorViewModel (新增, 跟 `ChapterTreeStore` / `EditorContentStore` 协调)

```swift
// 新增文件: Sources/WenshuApp/ViewModels/EditorViewModel.swift
@MainActor
final class EditorViewModel: ObservableObject {
    @Published var activeChapter: ChapterSnapshot?
    @Published var isOutlineVisible: Bool = true       // FCP "显示大纲" 显隐
    @Published var isFullScreen: Bool = false          // FCP "⤢ 专注模式"
    
    func enterFullScreen() { ... }
    func exitFullScreen() { ... }
    func toggleOutline() { ... }
}
```

> ⚠️ **本卡 MVP 不实装 ViewModel 完整能力**: 先做最小可用 slice (handle activeChapter + isFullScreen, isOutlineVisible 留给 v0.04.0 子卡跟 "显示菜单" 一起做)。结构上**预留** ViewModel 类给未来扩展。

### 5.3 EditorOutlineView (修真, 沿 LT-01-fix19 commit 71d28b779)

```swift
// 新增文件: Sources/WenshuApp/Views/Editor/EditorOutlineView.swift
struct EditorOutlineView: View {
    @Binding var selectedChapterID: UUID?
    @ObservedObject var store: EditorOutlineStore
    
    var body: some View {
        Group {
            if store.chapters.isEmpty {
                emptyState
            } else {
                List(selection: $selectedChapterID) {  // Selection 单选
                    ForEach(store.chapters) { chapter in
                        ChapterOutlineRow(chapter: chapter, isActive: chapter.id == selectedChapterID)
                            .tag(chapter.id as UUID?)
                    }
                }
                .listStyle(.sidebar)  // macOS native sidebar 风格
            }
        }
        .frame(idealWidth: 240)
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle").font(.system(size: 56, weight: .light)).foregroundStyle(.secondary)
            Text("暂无章节").font(.title2)
            Text("在「章节」tab 中新建章节").font(.callout).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).padding()
    }
}

private struct ChapterOutlineRow: View {
    let chapter: ChapterSnapshot
    let isActive: Bool
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isActive ? "doc.text.fill" : "doc.text")
                .font(.system(size: 14))
                .foregroundStyle(isActive ? Color.accentColor : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(chapter.title).font(.headline)
                Text("第 \(chapter.index) 章 · \(chapter.wordCount) 字").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
```

**修真要拍板点**:
- ✅ 修真 LT-01-fix19 原稿: 240pt sidebar + `list.bullet.rectangle` 空态 + 章节 row SF Symbol (本卡改: `doc.text` 替代 `list.bullet.rectangle`, 因为大纲已加载章节后不再是空)
- ✅ 修真: 接 `WenshuProjectStore.listChapters(projectId:)` 真读 (LT-01-fix19 原稿是 placeholder)
- ✅ 修真: active 高亮 + `selectedChapterID` binding (LT-01-fix19 原稿没有)
- ✅ 修真: `ListStyle.sidebar` 让 macOS native 出 active 高亮 (本卡拍板, 不靠手算 isActive)
- ❌ 不修真: LT-01-fix19 原文的 "+ 新建章节" toolbar 按钮 (LT-01-fix19 原稿放这里, 但 LT-N1 实装已经在 `ChapterTreeView` 的 toolbar 放了, 重复风险) — designer 推荐**删** toolbar, **升级给 PM 拍**

### 5.4 EditorOutlineStore (新增, 跟 `ChapterTreeStore` 平级)

```swift
// 新增文件: Sources/WenshuApp/ViewModels/EditorOutlineStore.swift
@MainActor
final class EditorOutlineStore: ObservableObject {
    @Published private(set) var chapters: [ChapterSnapshot] = []
    private let projectId: UUID
    private let store: WenshuProjectStore
    
    init(projectId: UUID, store: WenshuProjectStore = .shared) { ... }
    
    func load() async {
        chapters = (try? await store.listChapters(projectId: projectId)) ?? []
    }
}
```

> **不**修真 `ChapterTreeStore`: LT-N1 已实装在 `Views/Project/`, 本卡不动。两个 store 同时存在, 都 `listChapters`, 接同一个 actor 方法, **不冲突** (CC 实现需注意 unit test 时 mock 注意)。`ChapterTreeStore` 仍是 topLeft "章节" tab 用的, `EditorOutlineStore` 是中上 sidebar 用的, **consumer 不同**。

### 5.5 FCP viewer 4 角 toolbar (本卡 MVP = 2 个 sub-view)

#### 5.5.1 顶 toolbar (28pt)

```swift
// 新增文件: Sources/WenshuApp/Views/Editor/EditorTopToolbar.swift
struct EditorTopToolbar: View {
    let chapterTitle: String
    let wordCount: Int
    // 右上 字号 / 显示 菜单 — 本卡 MVP 不画
    
    var body: some View {
        HStack(spacing: 0) {
            // 左上: 字数
            Text("\(wordCount) 字")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
                .padding(.leading, wenshu.space.m)
            Spacer()
            // 中上: 文档名 / 章节名 (面包屑)
            HStack(spacing: wenshu.space.xxs) {
                Image(systemName: "doc.text").font(.system(size: 14)).foregroundStyle(.secondary)
                Text(chapterTitle).font(.system(size: 13, weight: .medium))
            }
            Spacer()
            // 右上: 空槽 (留给字号 / 显示菜单, 本卡 MVP 不画)
            Color.clear.frame(width: 100)
        }
        .frame(height: 28)
        .background(.thinMaterial)  // 暗色 + 微弱材质 (FCP viewer 范式)
    }
}
```

#### 5.5.2 底 toolbar (32pt)

```swift
// 新增文件: Sources/WenshuApp/Views/Editor/EditorBottomToolbar.swift
struct EditorBottomToolbar: View {
    let onFullScreenToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // 左下: 3 ICON 按钮预留位, 本卡 MVP 不画 (留空 shell)
            Color.clear.frame(width: 200, alignment: .leading)
            Spacer()
            // 中下: 永远空 (FCP 时码, 文枢不复制)
            Color.clear
            Spacer()
            // 右下: ⤢ 全屏 toggle
            Button(action: onFullScreenToggle) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")  // 注意: 8.10 memo 用的是 up.right.and.arrow.down.left, 这里按 SF Symbol 实际可用
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("专注模式")
            .padding(.trailing, wenshu.space.m)
        }
        .frame(height: 32)
        .background(.thinMaterial)
    }
}
```

**MVP 派生**:
- 顶 toolbar 左上字数: 真接 `EditorContentStore.wordCount`, debounced 1s 实时更新
- 顶 toolbar 中上章节名: 跟随 `selectedChapterID` 更新, 来自 `EditorOutlineStore.activeChapter`
- 顶 toolbar 右上: **真留空** (不画 placeholder / SF Symbol / 任何元素), 8/10 memo §3.8 拍板 "其他空" 原则
- 底 toolbar 右下 ⤢: SF Symbol 在 macOS Sonoma+ 实际可用的 `arrow.up.left.and.arrow.down.right` (= 进出全屏), 而不是 8/10 memo §1 写的 `arrow.up.right.and.arrow.down.left` (后者是 zoom-in, 但语义对——都是 SF Symbol 14pt, 设计师按 macOS native 可用为准)
- 底 toolbar 其他槽位: 真留空

### 5.6 1pt ES splitter (新组件)

```swift
// 沿用现有 NativeSplitter (Views/Layout/NativeSplitter.swift), 不新加组件
// 使用方式: HSplitView(left: EditorOutlineView, right: TextEditor)
// 也可手写 HSplitView + NativeSplitter 内嵌 (本卡 designer 推荐后者的细粒度控制)
```

---

## 6. Token 系统 (designer 给 CC 注入的 design tokens)

### 6.1 颜色 (FCP viewer 范式 + dark mode 默认)

| Token | 值 | 用途 |
|---|---|---|
| `wenshu.surface.editor` | `#1E1E1E` (dark) / `#FAFAFA` (light) | 中上 editor background (FCP viewer 范式 dark 默认) |
| `wenshu.surface.editorToolbar` | `#2D2D2D` (dark) / `#F5F5F5` (light) | 顶 / 底 toolbar background (FCP viewer 范式, 比 surface 亮一档) |
| `wenshu.text.editor` | `#E5E5E5` (dark) / `#1C1C1E` (light) | TextEditor 正文 |
| `wenshu.text.editorSecondary` | `#8E8E93` (dark) / `#6C6C70` (light) | 字数 / 章节名 caption |
| `wenshu.divider.editor` | `#3A3A3C` (dark) / `#C6C6C8` (light) | 1pt ES splitter 细线 (FCP viewer 范式暗色) |
| `wenshu.accent.editor` | macOS system accent | active 章节 row / ⤢ hover 高亮 |

### 6.2 Typography

| Token | size / weight | 用途 |
|---|---|---|
| `wenshu.text.editorBody` | 17 / regular | TextEditor 正文 (沿 swiftui-design-patterns §4.2 body) |
| `wenshu.text.editorCaption` | 13 / regular | 字数 / 章节名 (FCP viewer 范式小字) |
| `wenshu.text.editorToolbarTitle` | 13 / medium | 顶 toolbar 中上章节名 |
| `wenshu.text.editorOutlineTitle` | 14 / regular | 章节 sidebar row title |
| `wenshu.text.editorOutlineCaption` | 11 / regular | 章节 sidebar row "第 N 章 · N 字" |
| `wenshu.icon.editorToolbar` | 14 / regular | 顶 / 底 toolbar ICON (FCP 范式) |

### 6.3 Spacing (FCP viewer 范式紧凑)

| Token | 值 | 用途 |
|---|---|---|
| `wenshu.space.editorToolbarPadding` | 8 / 8 | 顶 / 底 toolbar 内部 padding (FCP 范式紧凑) |
| `wenshu.space.editorContent` | 16 | TextEditor 4 边 padding |
| `wenshu.space.editorOutlineRow` | 4 / 4 | 章节 row 内部 padding |

### 6.4 高度 / 几何

| Token | 值 | 用途 |
|---|---|---|
| `wenshu.height.editorTopToolbar` | 28pt | 顶 toolbar (FCP viewer 范式) |
| `wenshu.height.editorBottomToolbar` | 32pt | 底 toolbar (FCP viewer 范式) |
| `wenshu.width.editorOutlineDefault` | 240pt | 章节 sidebar 默认宽 (沿 LT-01-fix19 真值) |
| `wenshu.width.editorOutlineMin` | 150pt | 章节 sidebar 可拖范围下限 |
| `wenshu.width.editorOutlineMax` | 400pt | 章节 sidebar 可拖范围上限 |
| `wenshu.width.editorOutlineCollapse` | 30pt | 章节 sidebar 折叠阈值 (FCP viewer 范式 30pt) |
| `wenshu.width.editorSplitter` | 1pt | ES 1pt 细线 (FCP viewer 范式) |

### 6.5 暗色 vs 亮色 (FCP 范式拍板)

- **暗色默认** (FCP viewer 范式 + 夜读写作场景天然契合)
- 亮色模式 toggle: 跟 system color scheme 同步, **本卡不实现手动 toggle** (let system decide), 跟 macOS 系统设置走
- macOS accent: 用 system accent (不改, 默认蓝)

---

## 7. 状态机 (5 态)

### 7.1 章节 sidebar row 状态

| 状态 | 视觉 | 行为 |
|---|---|---|
| **default** | doc.text SF Symbol (.secondary) + 标题 (.primary) + "第 N 章 · N 字" (.secondary) | hover 高亮背景 (.quaternary) |
| **hover** | doc.text SF Symbol (.secondary) + 浅灰背景 (.quaternary) | click → select |
| **active (selected)** | doc.text.fill SF Symbol (system accent) + 标题 (.primary) + 浅 accent 背景 | 双击 → 跳到编辑区 |
| **disabled** (无选中章节时 sidebar) | 灰显 SF Symbol + .secondary opacity 0.5 | click 无响应 |
| **empty (没章节)** | list.bullet.rectangle SF Symbol + "暂无章节" + "在「章节」tab 中新建章节" caption | 无 |

### 7.2 TextEditor 状态

| 状态 | 视觉 | 行为 |
|---|---|---|
| **readonly (没选中章节)** | 暗色 background + "请先选择章节" Text 居中 + "在左侧章节列表中选择一个章节, 或在左上的「章节」tab 新建" caption | 输入无响应 |
| **clean (加载完没改)** | 暗色 background + content Text + 顶 toolbar 字数跟 content 字数同步 | 输入 → debounced save |
| **dirty (debounced 1s 内未 flush)** | 同 clean + 顶 toolbar 字数带 dot 指示器 (●, 14pt, .accent) | flush 后 dot 消失 |
| **saving** | 同 clean + 顶 toolbar 字数后跟 progress (1s 极短, 用户视角一般看不见) | 自动消失 |
| **error (save 失败)** | 暗色 background + 顶 toolbar 字数变红 (.systemRed) + dot 持续 | retry 一次, 失败后等用户手动 retry (关 / 开 app) |

### 7.3 ⤢ 全屏 toggle 状态 (FCP viewer 范式)

| 状态 | 视觉 | 行为 |
|---|---|---|
| **default (非全屏)** | arrow.up.left.and.arrow.down.right SF Symbol 14pt (.secondary) | click → 进全屏, 隐藏 4 个 panel |
| **hover** | SF Symbol 14pt (.primary) | 高亮 |
| **fullscreen (已进全屏)** | arrow.down.right.and.arrow.up.left SF Symbol 14pt (system accent) | click → 退全屏, 恢复 4 panel |
| **disabled** (跟选中章节无关, 永远启用) | — | — |

---

## 8. 响应式 (macOS 专属)

### 8.1 窗口大小

| 尺寸 | 行为 |
|---|---|
| **默认 1440x900** (macOS 文枢默认) | 5 区 layout 完整渲染, topCenter 占大头 ≈ 740pt 宽 × 600pt 高, 编辑器正常 |
| **缩到最小 900x600** (macOS 文枢 minWidth/minHeight) | topCenter 缩到 ≈ 400pt 宽 × 200pt 高, TextEditor 内容自动滚动, toolbar 不缩 |
| **更大 (1920x1080+)** | topCenter 占大头 ≈ 1020pt 宽 × 600pt 高, TextEditor 用 width: maxWidth + height: maxHeight, 章节 sidebar 仍 240pt (固定) |
| **iPad** | 不支持 (macOS 27+ 专属) |
| **iPhone** | 不支持 |

### 8.2 toolbar 缩放

- 顶 / 底 toolbar **永远固定 28pt / 32pt**, 窗口缩放不缩 toolbar
- 章节 sidebar 缩: 150pt (min) ↔ 400pt (max), 默认 240pt
- 折叠阈值 30pt: 拖到 < 30pt 自动折叠成 30pt 槽 (放 ⓧ ICON), 跟 FCP viewer 范式 §3.6 对齐

### 8.3 dark mode

- 默认跟 macOS 系统 color scheme (暗色 vs 亮色), 不应用层手动 toggle
- 暗色默认值见 §6.1 (`#1E1E1E`)
- TextEditor 在亮色模式可读性正常, 不强制暗色

---

## 9. SwiftUI 实现建议 (给 CC)

### 9.1 不踩边界 (跟 task body 硬对齐)

- ❌ **不**改任何 `.swift` 文件 (本卡**只**新增, 不修真)
- ❌ **不**改 `WenshuProjectStore.swift` / `WenshuStoreActor.swift` / `ModelDefinitions.swift`
- ❌ **不**改 `Package.swift` / `Info.plist` / `swift-tools-version` / `platforms`
- ❌ **不**改 `AGENTS.md` / `CLAUDE.md`
- ❌ **不**修真已实装的 view (LT-N1 / LT-N2 / V0-fix-6/7/8/9/10/11)
- ✅ **新增** view 文件: `EditorView.swift`, `EditorViewModel.swift`, `EditorOutlineView.swift`, `EditorOutlineStore.swift` (ViewModels/ 下), `EditorContentStore.swift` (ViewModels/ 下)
- ✅ **新增** toolbar 子 view: `EditorTopToolbar.swift`, `EditorBottomToolbar.swift`
- ✅ **新增** WenshuProjectStore extension 文件: `WenshuProjectStore+LTN3.swift` (+ 沿 LT-N2 +LTN2.swift 范式)
- ✅ **不修真** `ChapterTreeStore` / `ProjectListStore` (LT-N1 已实装)

### 9.2 SwiftUI 关键 API 用法

1. **`TextEditor(text: $content)`**: macOS SwiftUI native `TextEditor`, 绑 `@State String` binding
2. **`List(selection: $selectedChapterID)`** (sidebar 风格): 单选 binding 走 List 自带 high-light
3. **`HSplitView`** (macOS SwiftUI 14+): 自动画 splitter, 用 `.frame(idealWidth: 240)` 控制 sidebar 宽
4. **`.toolbar(.unifiedCompact)`**: 顶 toolbar 用 SwiftUI system toolbar style (FCP 范式允许自定义, 但本卡用 native 简单)
5. **`@MainActor final class ObservableObject`**: 沿 LT-N1 `ChapterTreeStore` / LT-N2 `ChatViewModel` 范式
6. **`Task.sleep(for: .seconds(1))`**: debounced save 标准写法 (iOS 16+/macOS 13+)
7. **`.thinMaterial`**: macOS SwiftUI 材质, 暗色 toolbar 背景首选

### 9.3 unit test 套件 (designer 给 reviewer/CC 的契约)

`Tests/WenshuAppTests/EditorViewModelTests.swift`:
- `test_editorView_loadChapter_setsActiveChapter()`
- `test_editorView_toggleFullScreen_updatesIsFullScreen()`
- `test_editorView_toggleOutline_visibilityToggle()`

`Tests/WenshuAppTests/EditorContentStoreTests.swift`:
- `test_editorContentStore_load_populatesContent()`
- `test_editorContentStore_updateContent_marksDirty()`
- `test_editorContentStore_flush_callsSave()`
- `test_editorContentStore_debouncedSave_oneSecondDelay()`

> ⚠️ **本卡 designer 不写 unit test**: 这是 CC 的工作, designer 只给契约 (跟 LT-N1 §6 一致)

### 9.4 真机拍板点 (装机 user 8 步验收)

10 步用户旅程走完 (见 §1), 关键实机拍:
1. ✅ 5 区 layout 渲染, topCenter 不再是 PlaceholderContent, 是 EditorView
2. ✅ 章节 sidebar 240pt 默认, 章节 row 真渲染 `listChapters` 数据
3. ✅ 顶 toolbar 左上字数 + 中上章节名 实时同步
4. ✅ TextEditor 接 CDChapter.content, 输入 → debounced 1s 保存
5. ✅ ⤢ 全屏 toggle 隐藏 4 panel + 恢复
6. ✅ 关 app 重开, 章节 + 内容 还在
7. ✅ active chapter row 高亮 (system accent), List sidebar 风格
8. ✅ 1pt ES splitter 可拖, 30pt 折叠阈值
9. ✅ 字数 dot 指示器 (●) dirty → flush 消失
10. ✅ 暗色 / 亮色模式自动跟 system

---

## 10. 边界声明 (designer 不跨进 CC 领域)

- ✅ 出 SwiftUI 设计意图 (用什么 API / 怎么布局 / 用什么 token), 见 §5 + §6
- ✅ 出组件 API 契约 (§5.1–§5.6), CC 实现可完全照搬
- ✅ 出 store extension 接口契约 (§4.2 + §4.3), CC 实现可完全照搬
- ✅ 出 token 系统 (§6), CC 注入到 design system
- ✅ 出状态机 (§7), CC 写 case 默认 / hover / active
- ✅ 出响应式 / 暗色模式 (§8), CC 注入 SwiftUI modifier
- ❌ 不写 `.swift` 代码 (本卡硬边界)
- ❌ 不跑 `swift build` (保留给 CC 实现后跑)
- ❌ 不跑 unit test (保留给 CC)
- ❌ 不动 schema / actor / Package.swift / Info.plist (硬边界)

---

## 11. 关联资源

- **AGENTS §8.1**: 5 区 layout grammar (顶部 toolbar 24pt / topLeft / topCenter / topRight / bottomLeft / bottomRight)
- **AGENTS §12**: CC 不改 .ws schema 红线
- **LT-N1 design doc**: `DESIGN-LT-N1.md` (30.7 KB, v0.02.0) — selectedProjectID 范式参考
- **LT-N2 design doc**: `DESIGN-LT-N2.md` (22.5 KB, v0.03.0) — chat 区 4 子 tab 范式参考
- **LT-01-fix19 design doc**: commit `71d28b779` (459 行, 2026-08-10 designer 出稿, 没实装) — EditorOutlineView 原稿, 本卡修真基础
- **V0-fix-10 design doc**: `DESIGN-V0-fix-10.md` — 5 tab + chat 4 tab 紧凑范式参考
- **FCP viewer 范式 memo**: `~/.hermes/profiles/designer/design-notes/wenshu-editor-fcp-viewer-pattern.md` (8/10 装机 user 讨论落档, 30 KB) — 本卡 FCP 4 角 toolbar + 暗色 + 30pt 折叠阈值真值源
- **V0-fix-7/8/9/11**: 5 区 layout 真值源 (修真历史完整)
- **swiftui-design-patterns skill**: `swiftui-design-patterns/SKILL.md` — SwiftUI HIG + token 系统参考

---

*Designer 产物 v0.1 · 2026-08-11 · v0.03.0 LOOP 三段式第三张 · 装机 user 拍板 / PM-direct 派单 (t_dd20c3b1)*
