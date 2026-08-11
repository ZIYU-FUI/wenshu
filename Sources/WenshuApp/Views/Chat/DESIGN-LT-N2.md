# DESIGN-LT-N2 · 聊天区 UI 设计稿(下左 + 区模块化)

> **任务**:[V0.03.0 LT-N2-designer] 聊天区 UI 设计稿(下左 + 区模块化, AIF LT-N1~N5 第二张)
> **拍板真值**:AGENTS.md §3 (场景驱动 / 区块模块化 / 迭代可独立运行) + §8.1 (5 区 layout · 下左 = 4 子 tab) + §5 (CC 写代码边界)
> **designer**:出 SwiftUI UI 设计意图 + token + 组件 API 建议 + WenshuProjectStore 增强 API 建议。**不写代码**。
> **落盘路径**:`Sources/WenshuApp/Views/Chat/DESIGN-LT-N2.md`
> **拍板真值**:2026-08-10 AGENTS.md §3 + §8.1 (v0.02.0 LT-04 + v0.03.0 V0-fix-4 + V0-fix-6 合并后)

---

## 0. 任务边界矛盾点(designer 不能拍, 必升级)

读了 `Sources/WenshuApp/Views/Chat/ChatPanelView.swift`(115 行全,v0.02.0 LT-04 + V0-fix-4 + V0-fix-6 合并稿)+ `ChatView.swift`(153 行全,v0.01.0 WO-004)+ `WenshuProjectStore.swift`(142 行全)+ `ChatViewModel.swift`(252 行全)+ `ExpandOptionsView.swift`(99 行全)+ `Layout/LayoutShellView.swift`(line 102, 223, 272, 301-302, 337 — 跟 ChatPanelView 集成相关)+ `ProjectListView.swift`(26-44 — ProjectManagementTab enum)+ AGENTS §8.1 + V0-fix-4 commit `a26731efd` + V0-fix-6 commit `b33ece371` + fix19 commit `2dc04ee58`,发现**任务 body 跟现状有 5 处冲突 / 模糊点**。designer 把它们标在这里,**等 PM / 装机 user 拍板**,不擅自选边。

### 矛盾 1: 任务 §1.3 "4 子 tab = chat / timeline / relationships / kanban" 跟 v0.03.0 当前 on-disk 真值不一致

- **任务 body** §1.3:`chat` / `timeline` / `relationships` / `kanban`,4 子 tab 全部居左 ICON。
- **AGENTS §8.1**("v0.02.0 子任务 LT-04"):"4 子 tab(聊天实装 + 时间线/关系图/大纲 disabled 占位)"— 第 4 个 tab 是 **outline**(大纲),不是 kanban。
- **当前 on-disk 真值**(`ChatPanelView.swift:17-22`, V0-fix-6 最新):`chat` / `timeline` / `relationships` / **`outline`**,第 4 个 tab 是 `list.bullet.indent` SF Symbol。
- **`kanban` 真值在哪儿**(`ProjectListView.swift:31`, V0-fix-5 最新):`ProjectManagementTab.kanban` = `rectangle.split.3x1`,在**左上区 5 tab**(项目 / 章节 / 设定 / 资料 / 看板),不在下左聊天区。
- **冲突根源**:任务 body 的"kanban"沿用 v0.02.0 早期规划(kanban 在下左),但 v0.03.0 V0-fix-3/4/5 把 kanban 移到了左上区(5 tab),同时把 `outline` 留在下左(沿 v0.02.0 LT-04)。**任务 body 拍板时未对齐 v0.03.0 真值**。
- **可能的真意**:
  - 读法 A:任务 body 拍板时按 v0.02.0 早期规划,期望"kanban 在下左",LT-N2 designer 出的设计稿该把第 4 tab 改成 kanban。
  - 读法 B:任务 body 是 typo 或调度遗留,LT-N2 designer 按 v0.03.0 当前真值出设计稿(4 tab = chat / timeline / relationships / **outline**),`kanban` 在左上区,不在下左。
- **建议**:designer 推荐**读法 B**。理由:(1) 不破坏 V0-fix-4/5/6 已落地的 layout 真值(推翻需要重测 + 装机 user 再拍);(2) 当前 on-disk 6/6 V0Fix6 测试 + 5/5 V0Fix4 测试依赖当前 tab 结构,改 tab 名 = 改测试 + 装机 user 再次验收,成本高;(3) `outline` 在下左有 v0.04.0 大纲工具的实装路径(跟章节树关联),`kanban` 已经在左上区有了 V0-fix-5 实装入口。**⚠️ 等 PM-direct / 装机 user 拍**。

### 矛盾 2: 任务 §1.3 "ChatTabIconButton fix19 沿用" 跟 V0-fix-4 真值不一致

- **任务 body** §1.3:"全部居左 ICON(ChatTabIconButton fix19 沿用)"。
- **fix19 历史真值**(commit `2dc04ee58`,2026-08-10):聊天区从 4 tab → **3 tab**(砍 outline),新建组件 `ChatTabIconButton`(ICON-only SF Symbol + hover tooltip + 28pt hit area + 居左无文字),把 outline 移到编辑器(topCenter)为 `EditorOutlineView`。
- **V0-fix-4 真值**(commit `a26731efd`,2026-08-10):**回滚了 fix19 的 3 tab 化** + **回滚了 ChatTabIconButton 组件** — 改回 4 tab(包括 outline)+ Picker `.pickerStyle(.iconOnly)` + `.padding(.leading, 12)` + Spacer 居左。V0-fix-6 又加 `.frame(maxWidth: .infinity, alignment: .center)` 让 tab 内容居中。
- **当前 on-disk 真值**:`ChatPanelView` 用 `Picker` + `.pickerStyle(.iconOnly)`,**没有 ChatTabIconButton 组件**(项目里搜不到)。
- **冲突根源**:任务 body 派单时引用了 fix19 的"3 tab + ChatTabIconButton",但 V0-fix-4 已经回滚。任务 body §1.2 自己也承认"跟 fix19 冲突:fix19 把 outline 移出聊天,v0.03.0 拍板时不知道"。
- **建议**:designer 推荐**沿用 V0-fix-4/6 on-disk 真值**(`Picker` + `.iconOnly`,**不复活 ChatTabIconButton**)。理由:(1) on-disk 6 测试已锁定 Picker `.iconOnly` 字面量,改回 ChatTabIconButton = 改测试 + 装机 user 再验收;(2) ChatTabIconButton 在 V0-fix-4 拍板时已被废弃,组件本身没合并进 main,没有"沿用"基础。**⚠️ 等 PM-direct 拍**。

### 矛盾 3: 任务 §1.5 "SkeletonOption" 跟 on-disk 真值名称不一致

- **任务 body** §1.5 + §3:`generateSkeletonOptions / applySkeletonChoice` API 名字 + `SkeletonOption` 数据类型名。
- **当前 on-disk 真值**(`ChatViewModel.swift:33-34` + `ExpandOptionsView.swift:14` + `MockLLMResponse.swift:45-62`):`expandOptions: [ExpandOption]` + 4 类固定顺序 `["核心冲突", "主角延伸", "世界观缺口", "发展方向"]`(走 `ExpandOptionsView`,非 SkeletonOption)。
- **冲突根源**:任务 body 引用了早期 v0.01.0 规划的 "skeleton" 命名(生成人物/世界骨架前的"骨架候选"),但 v0.01.0 WO-004 实际命名是 `ExpandOption`(举一反三选项,4 类)。**v0.01.0 已经跑通 8 步用户旅程**(WO-004 → WO-005 → v0.02.0),`ExpandOption` 是产品术语真值。
- **建议**:designer 推荐**沿用 `ExpandOption` 命名**。理由:(1) on-disk 代码 + 测试 + 8 步用户旅程已锁定;(2) "skeleton" 在 AGENTS / 设计稿里没有出处,改名 = 越界(改 entity 名 = §12 红线"改 .ws schema")。designer 在 §4 + §6 用 `ExpandOption` 命名,在 §0 标注命名差异等 PM-direct 拍。**⚠️ 等 PM-direct 拍**。

### 矛盾 4: 任务 §1.5 暗示"AI 回复完 → 4 类候选项 + 章节树生成" — 但章节树生成 = LT-N1 范围, 不在 LT-N2

- **任务 body** §1.1 步骤 8:"AI 回复完 → 4 类候选项 + **章节树生成**"。
- **LT-N1 范围**(`DESIGN-LT-N1` v0.1 + commit `e80220aca` / `db269c247`):LT-N1 = 项目管理 = 左上 5 tab 实装 + `ChapterTreeView` 入口(由 LT-N2 触发 push 进去)。
- **冲突根源**:任务 body §1.1 步骤 8 把"章节树生成"放进 LT-N2 范围,但 LT-N1 已经把章节树列为 LT-N2 的下游消费者。**章节树数据生成**(`applySkeletonChoice → [CDChapter]`)属于 LT-N2 范围,**章节树 UI 渲染**(`ChapterTreeView` push)属于 LT-N1 范围。
- **建议**:designer 在 §4 + §5 明确切分:**LT-N2** 负责"AI 流式回复 → ExpandOption 列表 → 用户选 → 生成 CDChapter 数组(写 .ws)→ 触发 nav.push(ChapterTreeView)";"ChapterTreeView 渲染"是 LT-N1 责任,LT-N2 不实现 UI。**不擅自越界**。

### 矛盾 5: 任务 §1.4 "流式打字 (SSE) 沿用 v0.01.0 + minimax cn Anthropic 兼容" 跟任务范围有微妙错位

- **任务 body** §1.4:"流式打字 (SSE) 沿用 v0.01.0 + minimax cn Anthropic 兼容"。
- **当前 on-disk 真值**(`ChatViewModel.swift:199-243`):**流式复用两层** — (a) Mock 流(`MockLLMResponse.streamingChunks` + `Task.sleep` 假打字机),(b) 真 LLM 流(`LLMService.streamChat` 走 `MinimaxProvider`,Anthropic 兼容)。FeatureFlag `useRealLLM` 切 mock vs 真。**两层都已在 v0.01.0 WO-004 + WO-005 跑通**。
- **冲突根源**:任务 body 说"沿用 v0.01.0",实际上 v0.02.0 LT-04 已经把 ChatPanelView 包了一层 `NavigationStack`(per `ChatPanelView.swift:89-91`),**下左 ChatPanelView → ChatView 的视图结构已经变过**,不是 v0.01.0 直接复用。
- **建议**:designer 在 §4 明确"复用 v0.01.0 ChatView 的 `messageScroll` + `bubble` + `inputBar` 子视图 + `ChatViewModel.sendInitialStory / selectDirections / expandOptions` 数据流",**不实现新的流式逻辑**。流式打字沿用 `LLMService.streamChat`(MinimaxProvider,Anthropic 兼容),不写新 SSE parser。**⚠️ 等 PM-direct 拍**(如果 PM-direct 觉得"沿用"意味着"重构",那是 CC 责任,designer 不重写)。

---

## 1. 完整场景(装机 user 8 步, LT-N1 + LT-N2 跑通)

按 AGENTS §3「迭代可独立运行」,LT-N2 跟 LT-N1 协同,让装机 user 拿到两个迭代后能跑通"创建 → 进项目 → 跟 AI 聊天 → 生成章节树"完整动作。8 步:

1. **macOS 启动** → 看 5 区 layout(LT-01 已实现)— toolbar + 左上 5 tab + 中上 placeholder + 右上 inspector + 下左 ChatPanelView + 下右 placeholder
2. **点左上 + 新建项目** → push `ProjectCreateView`(V0-fix-6 改 modal sheet)— 弹窗化新建(LT-N1 已实现)
3. **输入项目名 + 文体风格 + 注水量 + 标签** → 创建 → 写入 .ws(LT-N1 的 `WenshuProjectStore.createFromSnapshot` 反查方案)
4. **返回项目列表** → 新项目名出现在 `projects` 列表顶部(LT-N1 已实现)
5. **点新项目行** → `navPath.append(AppRoute.chat(project))` 走 `NavigationStack` push → 进 `ChatPanelView`(当前 `chatVM.currentProject = project`,LT-N2 的 §4 接)
6. **下左 ChatPanelView 自动选中 chat tab**(`activeTab = .chat`)→ 显示 `ChatView(vm: chatVM, project: project)` → 顶部 nav title 显示项目名,subtitle "Chat · 阶段:想法"
7. **输入 "一句话故事"**(例如:"一个被流放的王子回到故国发现王位被一个会魔法的女人占据,他必须证明自己的血统才能夺回王位")→ 回车 → 用户气泡出现 → AI 气泡开始流式打字(`LLMService.streamChat` 走 minimax cn Anthropic 兼容 SSE,或 mock 兜底)
8. **AI 流式打完** → `ExpandOptionsView` 自动出现(在 message list 和 input bar 之间),显示 4 类(核心冲突 / 主角延伸 / 世界观缺口 / 发展方向),每类 1-3 个候选项,checkbox 选中 → 点"确认选择" → AI 再次流式确认 → `characters` + `worldRules` 填充 → **`navPath.append(ChapterTreeView)`**(LT-N1 接)→ 章节树渲染显示自动生成的大纲

> **关键**:LT-N1 + LT-N2 完成后,装机 user 能跑通 v0.01.0 8 步用户旅程的前半段(创建 → 进项目 → 跟 AI 聊天 → 生成章节树),不依赖 LT-N3~N5。LT-N3 设定 / LT-N4 资料 / LT-N5 看板 完成后,装机 user 还能跑通后半段(章节树 → 选定方向 → 写正文)。

---

## 2. 区块模块化(下左区当独立 App 模块)

按 AGENTS §3「区块模块化」,**下左 = 独立 App 模块**。设计师要给出"这个模块的边界":

### 2.1 模块边界

| 维度 | 下左聊天区 |
|------|------|
| **入口** | `LayoutShellView.swift:301-302` 的 `bottomLeft` panel 容器(`ChatPanelView()`) |
| **出口** | 当前选中 project 的 `id` → 给中上(文档编辑器 / 章节树)+ 右上(inspector)消费 |
| **数据所有权** | `ChatViewModel`(`@StateObject` 在 `App.swift:96`,`@MainActor` `@ObservableObject`)管 messages + expandOptions + characters + worldRules + currentProject |
| **流式 LLM 调用** | `LLMService.shared.streamChat`(`MinimaxProvider`,Anthropic 兼容)或 `MockLLMResponse.streamingChunks` 兜底 |
| **持久化** | 走 `WenshuProjectStore.save` + 后续 `sendChatMessage / loadChatHistory / generateSkeletonOptions / applySkeletonChoice`(本卡 §5 建议新增,不动 .ws schema) |
| **路由** | 内部 `NavigationStack`(per `ChatPanelView.swift:89-91`)+ push `ChapterTreeView`(LT-N1 责任)— 不依赖 MainView 的外部 navPath |

### 2.2 模块对外接口(designer 建议, 等 PM-direct 拍)

```swift
// ChatView (下左, 接 projectId)
struct ChatView: View {
    @ObservedObject var vm: ChatViewModel
    let project: ProjectSnapshot
    @Binding var navPath: NavigationPath
    // 内部 @State: inputText (沿用 v0.01.0 ChatView.swift:19)
}

// ChatPanelView (下左容器, 4 子 tab)
struct ChatPanelView: View {
    @EnvironmentObject private var chatVM: ChatViewModel
    @State private var activeTab: ChatPanelTab = .chat
    @State private var navPath = NavigationPath()
    // 内部 enum ChatPanelTab (沿用 ChatPanelView.swift:17-22,见矛盾 1)
}
```

### 2.3 模块对外通信协议

- **进**:从左上 `ProjectListView` push `AppRoute.chat(project)` → `MainView.swift:24` → `LayoutShellView.bottomLeft` 接 → `ChatPanelView` 拿 `project` 设 `chatVM.currentProject`(per `ChatView.swift:31-38` `onAppear`)
- **出**:chat 流式打完 + 用户确认选择 → `ChatViewModel.pendingNavigation = .chapterTree`(本卡 §4 + §5 新增,需 PM-direct 拍 enum case)→ `ChatView.onChange(of: pendingNavigation)` push 进 `ChapterTreeView`(LT-N1 接)
- **不依赖**:中上 / 右上 / 下右 / toolbar 任何状态。5 区独立。

---

## 3. 路由(NavigationStack 内嵌)

按 AGENTS §3「区块模块化」 + 「路由独立」,下左区内部有自己 `NavigationStack`,**不**依赖 `MainView` 的外部 navPath(虽然当前 on-disk `ChatPanelView.swift:89-91` 的 `NavigationStack` 是 local `@State navPath`,但 §4 会接入 `LayoutShellView` 共享 navPath — 见矛盾 6)。

### 3.1 路由树

```
下左 ChatPanelView (NavigationStack root)
├── ChatView (chat tab)
│   ├── message list (v0.01.0 ChatView.swift:49-71 复用)
│   ├── ExpandOptionsView (v0.01.0 ChatView.swift:25 复用)
│   ├── input bar (v0.01.0 ChatView.swift:118-136 复用)
│   └── (push) ChapterTreeView ← LT-N1 接, ChatViewModel.pendingNavigation 触发
├── TimelineView (timeline tab, disabled 占位, v0.04.0 长篇工具实装)
├── RelationshipsView (relationships tab, disabled 占位, v0.04.0 长篇工具实装)
└── OutlineView (outline tab, disabled 占位, v0.04.0 长篇工具实装)
    注:tab 名沿用矛盾 1 读法 B = on-disk 真值 (outline);任务 body §1.3 = kanban 等 PM-direct 拍
```

### 3.2 路由约定

- `AppRoute` enum(per `MainView.swift:23-28`)扩展 1 个 case:`case chapterTree(ProjectSnapshot)`(本卡 §4 + §5 建议新增,需 PM-direct 拍 enum case)
- `ChatPanelView` 内部 `navPath` 接 push → `.chapterTree(project)`
- `ChapterTreeView` 的 `navigationDestination` 由 LT-N1 出(LT-N1 责任,LT-N2 不实现)

---

## 4. ChatView 设计(v0.01.0 复用)

按任务 body §1.4"ChatView 设计 (v0.01.0 复用)",**LT-N2 不重写 ChatView**,只接 `projectId` 上下文(从 `ProjectDetailView` → `ChatPanelView` → `ChatView` 传下来)— 当前 on-disk 已经实现(`ChatView.swift:16` `let project: ProjectSnapshot`),LT-N2 不动。

### 4.1 复用清单(不动)

| 子视图 | 路径 | 行数 | 复用范围 |
|------|------|------|------|
| `messageScroll` | `ChatView.swift:49-71` | 23 行 | ✅ 全复用 |
| `emptyHint` | `ChatView.swift:73-84` | 12 行 | ✅ 全复用 |
| `messageRow` | `ChatView.swift:86-102` | 17 行 | ✅ 全复用 |
| `bubble` | `ChatView.swift:104-116` | 13 行 | ✅ 全复用 |
| `inputBar` | `ChatView.swift:118-136` | 19 行 | ✅ 全复用 |
| `scrollToBottom` | `ChatView.swift:140-145` | 6 行 | ✅ 全复用 |
| `send` | `ChatView.swift:147-152` | 6 行 | ✅ 全复用 |

### 4.2 改动清单(本卡新增)

| 改动 | 路径 | 行数 | 说明 |
|------|------|------|------|
| `ChatViewModel.pendingNavigation` 加 `.chapterTree` case | `ChatViewModel.swift:47` + `MainView.swift:23-28` | ~3 行 | LT-N2 新增,需 PM-direct 拍 enum case |
| `ChatViewModel.applySkeletonChoice(...)` 新方法 | `ChatViewModel.swift` 末尾 | ~25 行 | 写 CDChapter(走 .ws),触发 `pendingNavigation = .chapterTree`,需 PM-direct 拍 .ws schema 边界 |
| `ChatView.onChange(of: pendingNavigation)` 接 `.chapterTree` | `ChatView.swift:39-44` | ~5 行 | 复用现有 onChange 模式 |

> **不重写 ChatView 子视图**。本卡是 designer,只设计意图 + API 建议,实际写代码 = CC。

### 4.3 流式打字

沿用 §0 矛盾 5 拍板 — 复用 v0.01.0 + v0.02.0 LT-04 已落地的两层流式(`LLMService.streamChat` 走 minimax cn Anthropic 兼容 + `MockLLMResponse.streamingChunks` 兜底),**不写新 SSE parser,不重写 LLMService / MinimaxProvider / SSEParser**。

---

## 5. WenshuProjectStore 增强 API(designer 建议, 等 PM-direct 拍 §12 红线)

任务 §1.5 列出 4 个新方法:`sendChatMessage / loadChatHistory / generateSkeletonOptions / applySkeletonChoice`。designer 跟 §0 矛盾 3 一致 — 命名沿用 on-disk `ExpandOption`,不写 `SkeletonOption`。

### 5.1 API 草图(给 CC)

```swift
// 沿用 WenshuProjectStore.swift actor 模式 + 不动 .ws schema 边界
extension WenshuProjectStore {
    /// 5.1.1 发送聊天消息 + 流式回复(走 LLMService 或 mock, 由 FeatureFlag + Keychain 切)
    /// - Parameters:
    ///   - projectId: 当前 chat 所属 project(用于打 tag-scope,沿 v0.01.0 CDNote.tags = "project-uuid" 反查)
    ///   - message: 用户一句话故事(或后续多轮对话)
    /// - Returns: AsyncThrowingStream<String, Error> — 流式 chunk(String)
    /// - Throws: LLMError.missingAPIKey / network / parse
    /// - Note: 流式逻辑在 ChatViewModel.streamFromRealLLM / streamFromMock 内(已实现),store 只负责封装 + 持久化触发
    func sendChatMessage(projectId: UUID, message: String) async throws -> AsyncThrowingStream<String, Error>

    /// 5.1.2 加载聊天历史(走 .ws 反查 CDNote.tags = "project-\(projectId)")
    /// - Parameters:
    ///   - projectId: 当前 chat 所属 project
    /// - Returns: [ChatMessage] — 按 createdAt 升序,role=("user"/"assistant")同 ChatViewModel
    /// - Note: 5.1.2 + 5.1.1 是 LT-N2 持久化的核心 — v0.01.0 当前 chat history 不持久化,关 App 后丢
    func loadChatHistory(projectId: UUID) async throws -> [ChatMessage]

    /// 5.1.3 生成 4 类举一反三候选项(走 LLM 或 mock)
    /// - Parameters:
    ///   - projectId: 当前 chat 所属 project
    ///   - message: 用户一句话故事
    /// - Returns: [ExpandOption] — 4 类("核心冲突"/"主角延伸"/"世界观缺口"/"发展方向"),沿用 on-disk 命名
    /// - Note: 当前在 ChatViewModel.sendInitialStory 内调 MockLLMResponse.expandOptions(),store 版本是它的持久化版
    func generateSkeletonOptions(projectId: UUID, message: String) async throws -> [ExpandOption]

    /// 5.1.4 应用候选项 → 生成章节树
    /// - Parameters:
    ///   - projectId: 当前 chat 所属 project
    ///   - choice: 用户从 ExpandOptionsView 选中的 ExpandOption 数组(可多选,沿 v0.01.0 selectedDirectionIDs: Set<UUID>)
    /// - Returns: [CDChapter] — 自动生成的章节列表(每章 = 一个 ExpandOption 展开,章节名 = option.title)
    /// - Throws: .ws schema 错误(走反查方案,不动 .ws schema,见矛盾 1 读法 B)
    /// - Note: 写 CDChapter 走反查方案 — 用现有 CDChapter entity(已存在,per WenshuStoreActor.swift:99),不新建 entity
    func applySkeletonChoice(projectId: UUID, choice: [ExpandOption]) async throws -> [CDChapter]
}
```

### 5.2 .ws schema 边界(§12 红线)

- **不新建 entity**:5.1.1~5.1.4 全部沿用现有 CDNote / CDChapter / CDCharacter / CDWorldRule(per `WenshuStoreActor.swift:99` `countAll()` 枚举列表)
- **不修改字段类型**:仅使用现有 `text / tags / createdAt / name / role / backstory / rule / category`(沿用 v0.01.0 save() 方法的字面 keys)
- **tag-scoping**:沿用 v0.01.0 `"project-\(projectId.uuidString)"` 字符串 tag 反查方案(per `WenshuProjectStore.swift:92`),不动 .ws schema
- **chat history 持久化**:用现有 CDNote entity(`text` 存消息内容,`tags` 存 `"project-uuid" + "role-user"/"role-assistant"` 双 tag,`createdAt` 存时间)— **不**新建 `CDChatMessage` entity(§12 红线)

### 5.3 与 v0.01.0 WenshuProjectStore.save() 的关系

- v0.01.0 `save()`(per `WenshuProjectStore.swift:82-112`):**整批一次性**写 CDNote(initialStory)+ N × CDCharacter + N × CDWorldRule,在 `CharacterWorldView` 返回项目列表时调用
- LT-N2 `save()`(5.1.1):**增量流式**写 CDNote(每个 user/assistant message 一条),在 `ChatViewModel.appendStreamingMessage` 末尾 + 每条 user 消息 push 后调用
- **并存关系**:v0.01.0 save() 仍可用(初始化骨架数据),LT-N2 save() 补 chat history 持久化;**两个 save 互不干扰**(不同 tags 区分 — `"project-uuid" + "role-initial-story"` vs `"project-uuid" + "role-user"`/`"role-assistant"`)
- **不破坏向后兼容**:旧 .ws 文件加载时不报错(走 CoreData automatic migration,per `WenshuStoreActor.swift:20`)

---

## 6. SwiftUI 设计 token(给 CC 实施)

### 6.1 4 子 tab 拍板真值(任务 §1.3 + 矛盾 1 + 矛盾 2)

| Tab | SF Symbol | 沿用文件 / 行 | 拍板 |
|------|------|------|------|
| chat | `bubble.left.and.bubble.right`(沿用 V0-fix-6 on-disk `ChatPanelView.swift:27`) | V0-fix-4/6 拍 | ✅ 实装 + 流式 |
| timeline | `clock.arrow.circlepath`(`ChatPanelView.swift:28`) | V0-fix-4 沿用 fix19 | ⚠️ disabled 占位, v0.04.0 长篇工具实装 |
| relationships | `person.2`(`ChatPanelView.swift:29`) | V0-fix-4 沿用 fix19 | ⚠️ disabled 占位, v0.04.0 长篇工具实装 |
| outline | `list.bullet.indent`(`ChatPanelView.swift:30`) | V0-fix-4 拍(回滚 fix19 砍 tab 决定) | ⚠️ disabled 占位, v0.04.0 长篇工具实装 |
| **(任务 body §1.3 替代名: kanban)** | (`rectangle.split.3x1`) | (任务 body, 跟 on-disk 真值冲突) | ⚠️ 矛盾 1,等 PM-direct 拍 |

> **designer 沿用 on-disk 真值(outline)**,矛盾 1 §0 等 PM-direct / 装机 user 拍板。

### 6.2 样式 token(沿用 V0-fix-4/6 + fix19 + LT-04)

| Token | 值 | 来源 |
|------|------|------|
| tab bar 高 | `auto`(38pt 沿 toolbar HStack,per V0-fix-4 Fix 1 `LayoutShellView.swift:topLeftHeaderBar`) | V0-fix-4 |
| tab padding | `.padding(.leading, 12)` + `.padding(.vertical, 8)` + Spacer(minLength: 0) | V0-fix-4 Fix 6 |
| tab a11y label | `""`(空字符串,图标 + tooltip 已表达语义) | V0-fix-4 |
| tab 风格 | `Picker` + `.pickerStyle(.iconOnly)`(沿用 V0-fix-4,**不**复活 fix19 ChatTabIconButton) | V0-fix-4 |
| tab ICON size | 16pt(沿 fix19 + V0-fix-4 hit area,sf symbol 默认 + font body) | fix19 |
| tab 居左对齐 | Picker 自适应宽度 + Spacer 推右留白 | V0-fix-4 Fix 6 |
| tabContent 居中 | `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)` | V0-fix-6 Fix 4 |
| disabled tab 视觉 | SF Symbol 30pt light + `.foregroundStyle(.tertiary)` + "v0.04.0 实现" + `.disabled(true)` | V0-fix-4 沿用 LT-04 |
| Color | `Color.accentColor` / `Color.secondary` / `.tertiary`(沿 v0.01.0 ChatView.swift:112-115) | v0.01.0 |
| 字体 | `.body` / `.callout` / `.headline` / `.subheadline` / `.caption`(沿 v0.01.0 ExpandOptionsView.swift 全文) | v0.01.0 |
| 快捷键 | ❌ 不带快捷键(沿 fix19 + V0-fix-4,留 v0.09.0 统一处理) | AGENTS §8.1 |

### 6.3 hover tooltip

- tab ICON 加 `.help(tab.rawValue)`(per `ChatPanelView.swift:56`),macOS native tooltip,hover 0.5s 后弹出
- 不写自定义 hover overlay(那会增加代码 + 测试成本)

---

## 7. 组件 API 建议(给 CC)

```swift
// ChatView (下左, 接 project) — 完全沿用 v0.01.0 ChatView.swift, 本卡不动
struct ChatView: View {
    @ObservedObject var vm: ChatViewModel
    let project: ProjectSnapshot
    @Binding var navPath: NavigationPath
    @State private var inputText: String = ""
    // body: VStack { messageScroll; Divider; ExpandOptionsView(vm); Divider; inputBar }
    //       .navigationTitle(project.name)
    //       .navigationSubtitle("Chat · 阶段:想法")
    //       .onAppear { vm.currentProject = project }
    //       .onChange(of: vm.pendingNavigation) { _, newValue in
    //           if let route = newValue { navPath.append(route); vm.pendingNavigation = nil }
    //       }
}

// ChatPanelView (下左容器, 4 子 tab) — 沿用 ChatPanelView.swift, 本卡不动
struct ChatPanelView: View {
    @EnvironmentObject private var chatVM: ChatViewModel
    @State private var activeTab: ChatPanelTab = .chat
    @State private var navPath = NavigationPath()
    // body: VStack { HStack { Picker + Spacer }; Divider; tabContent.frame(center) }
    // tabContent: chat → NavigationStack { ChatView }; outline/timeline/relationships → disabledContent
}

// ChatPanelTab enum — 沿用 ChatPanelView.swift:17-22 (outline 不改, 见矛盾 1)
enum ChatPanelTab: String, CaseIterable, Identifiable {
    case chat = "聊天"
    case timeline = "时间线"
    case relationships = "关系图"
    case outline = "大纲"
    // 注: 任务 body §1.3 拍"kanban" 跟 on-disk "outline" 冲突, 设计师沿 on-disk 真值, 等 PM-direct 拍
}

// ChatViewModel 扩展(本卡新增, 等 PM-direct 拍 §5 .ws schema 边界)
@MainActor
final class ChatViewModel: ObservableObject {
    // ... 沿用现有字段 ...
    @Published var pendingNavigation: AppRoute? = nil

    /// LT-N2 新增: 应用候选项 → 生成章节树 → 触发 chapterTree push
    func applySkeletonChoice(_ choices: [ExpandOption]) async throws -> [CDChapter] {
        // 1. 写 CDChapter 数组(走 WenshuProjectStore.applySkeletonChoice, 5.1.4)
        // 2. 走 chatVM.persist() 写 CDNote(初始骨架 tag)
        // 3. pendingNavigation = .chapterTree(currentProject)
        // 4. onChange 在 ChatView 触发 navPath.append(ChapterTreeView)
    }
}

// AppRoute 扩展(MainView.swift:23-28)
enum AppRoute: Hashable {
    case chat(ProjectSnapshot)
    case characterWorld
    case createProject
    /// LT-N2 新增: 章节树 push 路由(由 ChatPanelView 内部 navPath 接)
    case chapterTree(ProjectSnapshot)
}
```

### 7.1 ChapterTreeView(由 LT-N1 出)

LT-N2 **不**实现 ChapterTreeView,只触发 `navPath.append(.chapterTree(project))`。LT-N1 责任 = `navigationDestination(for: AppRoute.self) { case .chapterTree(let project) in ChapterTreeView(project:) }`。

---

## 8. 状态管理

### 8.1 ChatViewModel 状态机(沿用 v0.01.0 + 增量)

| 状态 | @Published | 类型 | 来源 |
|------|------|------|------|
| 聊天消息列表 | `messages: [ChatMessage]` | Identifiable array | v0.01.0 WO-004 |
| 4 类候选项 | `expandOptions: [ExpandOption]` | Identifiable array | v0.01.0 WO-004 |
| 用户选中 IDs | `selectedDirectionIDs: Set<UUID>` | Set | v0.01.0 WO-004 |
| 生成中 | `isGenerating: Bool` | Bool | v0.01.0 WO-004 |
| 自动生成人物 | `characters: [CharacterSnapshot]` | Identifiable array | v0.01.0 WO-004 |
| 自动生成世界规则 | `worldRules: [WorldRuleSnapshot]` | Identifiable array | v0.01.0 WO-004 |
| 当前 project | `currentProject: ProjectSnapshot?` | Optional | v0.01.0 WO-005 |
| push 路由信号 | `pendingNavigation: AppRoute?` | Optional | v0.01.0 WO-004,LT-N2 扩展 case |

### 8.2 LT-N2 新增状态(本卡建议, 等 PM-direct 拍)

| 状态 | @Published | 类型 | 说明 |
|------|------|------|------|
| chat history 加载中 | `isLoadingHistory: Bool` | Bool | 5.1.2 loadChatHistory 时显示 progress |
| chat history 加载错误 | `historyLoadError: String?` | Optional<String> | .ws schema 错误或 tag 反查失败,显示一行 inline error |
| 生成章节中 | `isGeneratingChapters: Bool` | Bool | 5.1.4 applySkeletonChoice 时 disable "确认选择" 按钮 |
| 生成章节错误 | `chapterGenError: String?` | Optional<String> | 同上 |

### 8.3 ChatPanelView 状态(沿用 V0-fix-4/6 on-disk)

| 状态 | @State | 类型 | 说明 |
|------|------|------|------|
| 当前选中 tab | `activeTab: ChatPanelTab` | Enum | V0-fix-6: `.chat` 默认 |
| 内部 navPath | `navPath: NavigationPath` | NavigationPath | V0-fix-6: 走 ChatView push |

---

## 9. 响应式(macOS 优先, iPad/iPhone 留后续)

### 9.1 macOS(本卡唯一目标)

- **下左区最小尺寸**:200 × 200(沿 LT-01 PanelContainer 默认最小)
- **下左区最大尺寸**:无限(下半 50% 总高 × 100% 总宽,沿 AGENTS §8.1)
- **折叠态**:沿用 AGENTS §8.1 — 折叠到只剩标题栏(高 ≈ 30px,沿 V0-fix-6 bottomLeft collapse)
- **拖拽**:沿用 LT-01 NativeSplitter(上 / 下 + 下左 / 下右 2 个垂直 splitter,1 个水平 splitter)
- **chat 流式打字**:`vm.messages.last?.content` 变化触发 `scrollToBottom(proxy:)`(per `ChatView.swift:67-69`)

### 9.2 iPad / iPhone(本卡不实现, 留 v0.06.0)

- AGENTS §8 v0.06.0 = iPhone 端,本卡不预设 iOS 适配
- 不写 `UIKit` interop(本卡纯 SwiftUI)
- 下左 chat 在 iPhone 上可能变全屏 + tab bar 沉底(SwiftUI NavigationStack 自动处理),本卡不预设

---

## 10. 拍板真值核对(必须显式核对 AGENTS §3 + §8.1 + §12)

| 拍板 | 本卡是否遵守 | 怎么遵守 |
|------|------|------|
| §3 场景驱动排序 | ✅ | LT-N2 = 下左 chat = 装机 user 进项目后第一个能交互的区 |
| §3 区块模块化 | ✅ | 下左 = 独立 App 模块,内嵌 NavigationStack,不依赖外部路由 |
| §3 迭代可独立运行 | ✅ | LT-N1 + LT-N2 完成后,装机 user 能跑通 v0.01.0 8 步前半段(创建 → 进项目 → 跟 AI 聊天 → 生成章节树) |
| §8.1 5 区 layout | ✅ | 下左 panel 容器是 `PanelContainer(.bottomLeft)`,不放 layout 逻辑 |
| §8.1 折叠 + 拖拽 | ✅ | 沿用 LayoutShellView 的折叠 + NativeSplitter,本卡不新增 splitter |
| §8.1 4 子 tab(聊天实装 + 3 占位) | ✅(with 矛盾 1) | 沿用 V0-fix-4/6 on-disk = chat / timeline / relationships / **outline**(任务 body §1.3 拍 kanban 跟 on-disk 冲突,等 PM-direct 拍) |
| §8.1 状态存 .ws | ✅(with 矛盾 1 读法 B) | chat history + 章节树走 .ws 反查方案,不动 schema |
| §5 CC 写代码边界 | ✅ | 本卡只 designer 出设计意图, CC 实现 |
| §7 数据资产硬约束 | ✅ | 跨设备靠复制 .ws / iCloud / Git, 文枢不参与 |
| §12 红线 — 不改 .ws schema | ✅ | 走反查方案(矛盾 1 读法 B + 5.2 schema 边界) |
| §12 红线 — 不改 LLM provider 签名 | ✅ | 本卡不涉及 LLM 改动(沿用 v0.01.0 LLMService / MinimaxProvider) |
| §12 红线 — 不替用户拍产品需求 | ✅ | 5 个矛盾点都列出来等拍, 不擅自选边 |
| §12 红线 — 不调任何外部 AI 平台 | ✅ | minimax cn 是 LLM provider,不是外部 AI 平台 |
| §12 红线 — CC 不替 PM 派工单 | ✅ | 本卡 designer 出设计稿,派工单 = PM-direct 责任 |

---

## 11. SwiftUI 实现建议(给 CC)

按 `swiftui-design-patterns` skill §2 出 SwiftUI API 选择建议。**designer 出建议, CC 实施**:

### 11.1 ChatPanelView(沿用 V0-fix-6 on-disk, 本卡不动)

- `VStack(spacing: 0)` 装 tab bar + Divider + tabContent
- tab bar 用 `HStack(spacing: 0) { Picker("", selection: $activeTab) { ForEach { Image + .tag + .help + .disabled } } + Spacer }`
- `.pickerStyle(.iconOnly)` 走 V0-fix-4 PickerStyle+IconOnly 别名(macOS 14+ SegmentedPickerStyle 配合 Image-only content 自动隐藏文字标签)
- `.padding(.leading, 12)` + `.padding(.vertical, 8)` + Spacer(minLength: 0)
- tabContent 加 `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)`

### 11.2 ChatView(完全沿用 v0.01.0 ChatView.swift, 本卡不动)

- `VStack(spacing: 0) { messageScroll; Divider; ExpandOptionsView(vm); Divider; inputBar }`
- messageScroll 用 `ScrollViewReader { proxy in ScrollView { LazyVStack(alignment: .leading, spacing: 12) { ForEach(vm.messages) { messageRow } } } }`
- bubble 用 `Text(display).font(.body).textSelection(.enabled).padding(.horizontal, 12).padding(.vertical, 8).background(...).clipShape(RoundedRectangle(cornerRadius: 12))`
- inputBar 用 `HStack(spacing: 8) { TextField("写一句话故事…", text: $inputText, axis: .vertical).textFieldStyle(.roundedBorder).lineLimit(1...4).disabled(vm.isGenerating).onSubmit { Task { await send() } } + Button { Label("发送", systemImage: "paperplane.fill") }.keyboardShortcut(.return, modifiers: [.command]) }`

### 11.3 ChatViewModel 扩展(本卡新增)

- `applySkeletonChoice(_ choices: [ExpandOption]) async throws -> [CDChapter]` 走 `WenshuProjectStore.applySkeletonChoice`
- 触发 `pendingNavigation = .chapterTree(currentProject)` 由 `ChatView.onChange(of: pendingNavigation)` 监听 + push
- 错误展示:`chapterGenError: String?` 在 input bar 上方显示一行 inline error(类似 Apple Mail 错误条)

### 11.4 ExpandOptionsView(完全沿用 v0.01.0 ExpandOptionsView.swift, 本卡不动)

- `VStack(alignment: .leading, spacing: 8) { header; ForEach(categoryOrder) { categorySection }; confirmBar }`
- categoryOrder = `["核心冲突", "主角延伸", "世界观缺口", "发展方向"]`(per `ExpandOptionsView.swift:14`)

### 11.5 状态机

- `vm.state` 不引入新 enum(沿用 v0.01.0 多个独立 @Published)
- 新增字段按 §8.2 列,各自 @Published + @MainActor(沿 v0.01.0 ChatViewModel 全文模式)
- View 用 `@ObservedObject var vm: ChatViewModel` 接收 + 直接读 `vm.messages / vm.expandOptions / vm.isGenerating`(SwiftUI 自动重渲染)

### 11.6 错误展示

- chat history 加载失败:`isLoadingHistory = false` + `historyLoadError = "..."` → input bar 上方一行红字
- 章节生成失败:`isGeneratingChapters = false` + `chapterGenError = "..."` → 同上
- LLM 流式失败:沿 v0.01.0 `streamFromRealLLM` 的 catch 兜底走 mock(`ChatViewModel.swift:223-231`)

### 11.7 测试建议(给 CC)

- LT02ChatPanelTests 已有(per V0-fix-4 commit `a26731efd` + V0-fix-6 commit `b33ece371` 6/6 test)
- LT-N2 不新增 test(designer 不写 test),由 CC 在实施时按 §4 + §5 + §11 出新 test:
  - `testChatViewModel_applySkeletonChoice_persistsChapters`
  - `testChatViewModel_applySkeletonChoice_triggersPendingNavigation`
  - `testWenshuProjectStore_loadChatHistory_filtersByTag`
  - `testWenshuProjectStore_applySkeletonChoice_writesCDChapter`

---

## 12. 边界(designer 不做的事)

- ❌ 不写任何 `.swift` 代码(designer 只出设计意图)
- ❌ 不改 `ChatPanelView.swift`(那已经 V0-fix-4/6 拍板,改 = 越界)
- ❌ 不改 `ChatView.swift`(那已经 v0.01.0 WO-004 拍板,改 = 越界)
- ❌ 不改 `ChatViewModel.swift` 的现有方法(只新增 `applySkeletonChoice` + 扩展 `pendingNavigation` case,不改 `sendInitialStory / selectDirections / toggleSelection / reset / persist`)
- ❌ 不改 `WenshuProjectStore.swift` 的现有方法签名(只增 `sendChatMessage / loadChatHistory / generateSkeletonOptions / applySkeletonChoice`,不改 `save / firstSavedStory / savedCharacterNames`)
- ❌ 不改 `LayoutShellView.swift`(那已经 LT-01 + fix17 + V0-fix-4/5/6 拍板,改 = 越界)
- ❌ 不改 `WenshuStoreActor.swift`(改 schema = §12 红线,等 PM-direct 拍)
- ❌ 不改 `LLMService.swift` / `MinimaxProvider.swift` / `SSEParser.swift`(改 LLM provider 签名 = §12 红线)
- ❌ 不改 `ExpandOptionsView.swift`(v0.01.0 WO-004 拍板,改 = 越界)
- ❌ 不改 `MainView.swift` 的现有 `AppRoute` case(只扩展 `case chapterTree(ProjectSnapshot)`,不改 `chat / characterWorld / createProject`)
- ❌ 不调 `swift build`(那是 CC 责任)— designer 写完 markdown 后,CC 实施时跑 build 验证
- ❌ 不调 `swift test`(那是 CC 责任)
- ❌ 不删 `ChatPanelView.swift` / `ChatView.swift` / `ChatViewModel.swift` / `WenshuProjectStore.swift` / `ExpandOptionsView.swift` 的现有文件(designer 只设计,改文件 = CC 责任)
- ❌ 不实现 `ChapterTreeView` UI(LT-N1 责任,LT-N2 只触发 push)
- ❌ 不实现 `timeline / relationships / outline / kanban` 4 tab 的实装 UI(都是 v0.04.0 长篇工具工单,本卡只出 disabled 占位)
- ❌ 不实现 chat 多轮对话(本卡只支持 v0.01.0 单轮:一句话故事 → AI 流式 → 4 类候选项 → 用户选 → 章节生成)
- ❌ 不实现 chat history 持久化的 UI(只出 API 建议,UI 由 CC 在实施时按 §4 + §5 出)
- ❌ 不实现 chat history 跨设备同步(AGENTS §7 — 文枢不参与,跨设备靠你)
- ❌ 不实现 chat 内的 @ 语法(那是 v0.01.0+ 后续迭代,本卡 scope 外)
- ❌ 不实现 chat 内的修订候选 / 标记系统(那是 v0.05.0,本卡 scope 外)
- ❌ 不带快捷键(AGENTS §8.1 — 留 v0.09.0 统一处理)

---

## 13. 配套资源

- **本卡依赖**:
  - AGENTS.md §3 + §5 + §7 + §8.1 + §12
  - `Sources/WenshuApp/Views/Chat/ChatPanelView.swift` (V0-fix-6 最新, 115 行)
  - `Sources/WenshuApp/Views/ChatView.swift` (v0.01.0 WO-004, 153 行)
  - `Sources/WenshuApp/ViewModels/ChatViewModel.swift` (v0.01.0 WO-004 → WO-005, 252 行)
  - `Sources/WenshuApp/Views/ExpandOptionsView.swift` (v0.01.0 WO-004, 99 行)
  - `Sources/WenshuApp/Storage/WenshuProjectStore.swift` (v0.01.0 WO-005, 142 行)
  - `Sources/WenshuApp/Persistence/WenshuStoreActor.swift` (entity 列表, 第 99 行)
  - `Sources/WenshuApp/MainView.swift` (AppRoute enum, 23-28 行)
  - `Sources/WenshuApp/Views/ProjectListView.swift` (ProjectManagementTab 5 tab 含 kanban, 26-44 行) — 矛盾 1 拍板参考
  - `Sources/WenshuApp/PickerStyle+IconOnly.swift` (V0-fix-4 别名)
  - `Sources/WenshuApp/Views/Layout/LayoutShellView.swift` (下左 panel 集成, line 102, 223, 272, 301-302, 337)
  - `swiftui-design-patterns` skill §2 (SwiftUI API) + §4 (token) + §5 (state)
  - V0-fix-4 commit `a26731efd` + V0-fix-6 commit `b33ece371` + fix19 commit `2dc04ee58`
- **本卡被依赖**:
  - LT-N1 (`ChapterTreeView` 接 `pendingNavigation = .chapterTree` push)
  - v0.04.0 长篇工具(`timeline / relationships / outline` 3 tab 实装 — 本卡只占位)
  - v0.05.0 标记系统(chat 内 @ 语法 + 选区右键)
- **本卡拍板**(见 §0):5 个矛盾点等 PM-direct / 装机 user 拍板
- **本卡验收**:装机 user 拿到 LT-N1 + LT-N2 后能跑通 §1 的 8 步(v0.01.0 8 步前半段 — 创建 → 进项目 → 跟 AI 聊天 → 生成章节树 → push 进 ChapterTreeView)

---

*DESIGN-LT-N2 v0.1 · designer · 2026-08-11 · 等 PM-direct / 装机 user 拍 §0 5 个矛盾点 + §5 .ws schema 边界 + §7 AppRoute 扩展*
