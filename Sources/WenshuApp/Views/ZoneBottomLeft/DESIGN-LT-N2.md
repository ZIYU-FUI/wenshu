# DESIGN-LT-N2 · 文枢 (Wenshu) · v0.03.0 LT-N2

> **designer 产物** — 只出设计稿, 不动 .swift / .ws schema / Package.swift
> **覆盖范围**: 下左 (`LayoutShellView.bottomLeft`) 独立 App 模块 = 聊天区 (`ChatPanelView` + `ChatView` + `ChatViewModel`)
> **依赖**: V0-fix-4/5/6 已实装的 4 子 tab (timeline / relationships / outline / chat, 居左 ICON) + V0-fix-2 拍板的聊天区视图 H1 + v0.01.0 `ChatView` / `ChatViewModel` + 现有 `WenshuProjectStore` (actor, tag-scoping)
> **设计基准**: AGENTS §8.1 (5 区) + AGENTS §12 (CC 不改 schema) + N1 设计稿的区模块化范式 + 装机 user 8/10 15:50 OOB "FCP 范式" 设计系统

---

## 0. 任务 body 矛盾点 (designer 不能拍, 必升级)

读了 `t_42fd2043` body + 现行 `ChatPanelView.swift` (V0-fix-6 实装) + N1 design doc (`DESIGN-LT-N1.md` 30.7 KB), 任务 body 有 3 处跟现状冲突。**designer 把它们标在这里, 由 PM / 装机 user 拍板**, 不擅自选边。

### 矛盾 1: 4 子 tab 列表 (body 写 kanban, 现状 outline)

- **任务 body** 写: "4 子 tab 拍板 (chat / timeline / relationships / kanban, 后 3 disabled)"
- **现行 `ChatPanelView.swift:6-25`**: `ChatPanelTab` 当前 4 case = `chat / timeline / relationships / outline` (V0-fix-4 拍板, V0-fix-6 沿用)
- **历史**: LT-01-fix19 (commit `71d28b779`) 砍 `outline` → V0-fix-4 (commit `a26731efd`) 加回 → 任务 body 写 `kanban`
- **冲突**: `kanban` 不在 ChatPanelTab enum 里; `outline` 在。**body 跟现状的 tab 列表不一致**
- **可能的真意**:
  - **A**: body 误写 kanban, 实际延续 V0-fix-4 实装 (outline 留), 跟"不动 v0-fix-4 已改的 chat 4 tab" 自洽
  - **B**: body 真要换 outline → kanban, 跟 N1 拍板"看板是本项目所有信息的入口" (LT-N1 落在 topLeft 5 tab) 冲突 — 看板在 topLeft, 聊天区也放就重复
  - **C**: body 真要换 outline → kanban, 删 topLeft 的看板 tab, 集中到 chat 区 — 推翻 N1
- **designer 倾向**: A (沿用 V0-fix-4 outline) — 跟"不动"边界 + N1 拍板双自洽, 但**留给 PM 拍**

### 矛盾 2: body 内部 tab 顺序矛盾

- **任务 body 派单原则**: "chat / timeline / relationships / kanban" (timeline 排第 2)
- **任务 body 边界**: "不动 v0-fix-4 已改的 chat 4 tab (timeline / relationships / kanban / chat, 居左 ICON)" (timeline 排第 1, chat 排第 4)
- **冲突**: body 内部两处 tab 顺序不一致
- **designer 倾向**: 沿用 V0-fix-4 现行 enum 顺序 `chat / timeline / relationships / outline`(chat 在前,跟 v0.01.0 拍板自洽, 装机 user 习惯)
- **留给 PM 拍**

### 矛盾 3: "不动 v0-fix-4 已改" + "4 子 tab 拍板" 冲突

- **任务 body 边界**: "**不动** v0-fix-4 已改的 chat 4 tab (timeline / relationships / kanban / chat, 居左 ICON)"
- **任务 body 必须出**: "4 子 tab 拍板 (chat / timeline / relationships / kanban, 后 3 disabled)"
- **冲突**: 拍板等于改; 改等于踩"不动"边界
- **真实意图**:
  - **A**: "不动"指 tab 视觉 (居左 ICON / iconOnly / 24pt header bar), "拍板"指 tab 内容 (列表本身), 两者不冲突
  - **B**: "不动"指 4 tab 列表, "拍板"是误写, 实际只复用 V0-fix-4
  - **C**: 拍板 = 设计稿里第 4 tab 写几个选项, 让 PM / 装机 user 选 — 拍的是"哪个 case 进 enum"
- **designer 倾向**: A — visual 不动, 内容交给 PM 拍(SOUL.md 边界, designer 不拍内容)
- **留给 PM 拍**

### 3 个矛盾点小结

**designer 不拍, 写 doc 默认按以下假设出稿**(对应"可能真意 A", 多数派)：:

1. 4 tab 沿用 V0-fix-4 现状: `chat / timeline / relationships / outline` (chat 实装, 后 3 disabled)
2. 顺序: `chat / timeline / relationships / outline` (跟 V0-fix-4 一致)
3. "不动"指 tab 视觉, 不动 ICON / 居左 / 24pt header bar 风格

**PM 拍板时可以选择**: 推翻上面 3 个假设, designer 重做对应章节

---

## 1. 完整场景 (LT-N1 + LT-N2 跑通 v0.01.0 8 步用户旅程前半)

> **可验收**: LT-N1 装机 user 走完 8 步 (项目管理) + LT-N2 装机 user 走完 8 步 (聊天) → 8 步用户旅程 1–6 全部到位 → 关闭 / 重开 app 数据还在 → 实拍录屏。

| 步 | 动作 | 期望结果 | 涉及区 |
|----|------|---------|--------|
| 1 | LT-N1 步 1 — macOS 启动 → 文枢自动开 5 区 layout | `LayoutShellView` 渲染, `bottomLeft` = `ChatPanelView` (本卡实装, 4 子 tab) | 5 区 |
| 2 | LT-N1 步 2 — 点左上 "项目" tab 顶部 **+ 新建项目** | `NavigationStack` push `ProjectCreateView` | topLeft |
| 3 | LT-N1 步 3 — 填项目名 / 文体 / 注水量 / 标签 → 创建 | `ProjectSnapshot` 落 `.ws` (tag-scoping) | topLeft |
| 4 | LT-N1 步 4 — 列表 → 新项目 row | row 出现 | topLeft |
| 5 | LT-N1 步 5 — 点项目 row → `ProjectDetailView` | 5 tab 切换 | topLeft |
| 6 | **LT-N2 步 6 — 切到"章节" tab → 点章节 → ChatView 接管** | `ChatPanelView` 顶部 4 tab, `chat` tab active, `ChatView` 渲染 `vm.messages` (空态 / 历史) | bottomLeft |
| 7 | **LT-N2 步 7 — 输入"一句话故事" → 发送** | `vm.sendChatMessage(text)` → 调 `WenshuChat.sendMessage` (新增 API) → AI 流式回复 → UI 渲染 | bottomLeft |
| 8 | **LT-N2 步 8 — AI 回复完 → 用户选骨架 → 进入 `CharacterWorldView`** | `vm.applySkeletonChoice(choiceId)` → 落 `.ws` (记账) → `navPath.append(.characterWorld)` | bottomLeft |

**为什么是这 8 步 (LT-N1 + LT-N2 合并)**:
- LT-N1 步 1–5 = 项目管理 (已 done)
- LT-N2 步 6–8 = 聊天 (本卡)
- 跑通 = 装机 user 能从 0 到"已建立项目 + 发起聊天 + 选骨架进入角色世界"

---

## 2. 区模块化 (bottomLeft 独立 App 模块)

### 2.1 几何边界

```
┌──────────────────────────────────────────────────────────────────┐
│ (native macOS title bar)                                          │
├──────────────┬───────────────────────────┬──────────────────────┤
│ topLeft       │ topCenter (editor area)  │ topRight              │
│ ProjectBrowser│ PlaceholderContent(留)    │ PlaceholderContent   │
│ (LT-N1 done)  │                           │                       │
├──────────────┴───────────────────────────┴──────────────────────┤
│ ★ bottomLeft (ChatPanelView, 本卡)              │ bottomRight (空)  │
│ (4 子 tab header + active tab content)             │                  │
└────────────────────────────────────────────────┴──────────────────┘
```

`★ bottomLeft` = 本卡的全部产出。**与 topLeft / topCenter / topRight / bottomRight 零依赖**:
- 不订阅 `LayoutShellViewModel` (只持有自己的 `@StateObject` / `EnvironmentObject`)
- 不读其它 panel 的 `@Published` 状态
- 不修改其它 panel 的 splitter 比例
- 折叠 / 拖拽行为由 LT-01 已实装的 `LayoutShellViewModel` + `PanelContainer` 提供, **本卡不重复实现**

### 2.2 bottomLeft 内部布局 (本卡关键设计)

```
┌─────────────────────────────────────────┐
│ ChatPanelView (bottomLeft root)         │
│ ┌─────────────────────────────────────┐ │
│ │ HeaderBar (24pt 高, V0-fix-2 拍)     │ │
│ │  [💬] [⏲] [👥] [📋]                 │ │ ← Picker.iconOnly, 4 tab 居左
│ ├─────────────────────────────────────┤ │
│ │ TabContent (maxHeight: .infinity)   │ │
│ │                                      │ │
│ │  根据 activeTab 切换:                 │ │
│ │  .chat         → ChatView          │ │  (本卡实装, 沿用 v0.01.0)
│ │  .timeline     → PlaceholderText   │ │  (disabled, v0.04.0)
│ │  .relationships → PlaceholderText  │ │  (disabled, v0.04.0)
│ │  .outline      → PlaceholderText   │ │  (disabled, v0.04.0)
│ │                                      │ │
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

**约束** (V0-fix-4/5/6 已定, 本卡沿用):
- 顶部 `Picker.iconOnly` 4 tab (V0-fix-4 拍, V0-fix-6 修真生效)
- tab 切换 = `@State private var activeTab: ChatPanelTab = .chat`, **不**走 NavigationStack
- **不重做** `ChatTabIconButton` (任务 body 边界: "不动 fix19 已改的 ChatTabIconButton + 3 tab ICON 风格")
- **不重做** `ChatPanelView` 顶部 24pt header bar (V0-fix-2 拍板, V0-fix-4 升 iconOnly)
- **不重做** `ChatView` 153 行主体 (v0.01.0 已实装, 沿用)

### 2.3 与现有 `LayoutShellView.panel(_:)` 的接入点 (designer 给 CC 的接口契约)

**当前 `LayoutShellView.swift` 已挂 `ChatPanelView()`** (LT-04 done) — **本卡不需要改 LayoutShellView**, 4 子 tab header 是 ChatPanelView 内部的事。

**接口契约** (本卡 CC 实现新增):
- `ChatPanelView` 内部 `enum ChatPanelTab` 沿用 V0-fix-4 现状 (`chat / timeline / relationships / outline`)
- `ChatViewModel` 扩展 4 个公开 API (见 §5): `sendChatMessage` / `loadChatHistory` / `generateSkeletonOptions` / `applySkeletonChoice`
- `WenshuProjectStore` 扩展 1 个公开 API (见 §6): `loadChatHistory(projectId:)` (已经在的 `save` 复用)

---

## 3. 4 子 tab 拍板

> **冲突点 1 留给 PM 拍板**: 本节按 V0-fix-4 现状 `chat / timeline / relationships / outline` 出稿

### 3.1 4 tab 配置

| Tab | Case | SF Symbol | 实装状态 | 占位文案 |
|-----|------|-----------|---------|---------|
| **聊天** | `.chat` | `bubble.left.and.bubble.right` | ✅ 实装 (本卡) | — |
| **时间线** | `.timeline` | `clock.arrow.circlepath` | 🔒 disabled (v0.04.0) | "v0.04.0 实现" |
| **关系图** | `.relationships` | `person.2` | 🔒 disabled (v0.04.0) | "v0.04.0 实现" |
| **大纲** | `.outline` | `list.bullet.indent` | 🔒 disabled (v0.04.0) | "v0.04.0 实现" |

**沿用 V0-fix-4 现状, 不动 tab 视觉**。

### 3.2 ChatView 设计 (复用 v0.01.0)

**组件不动** — `ChatView` (153 行, 3 段: message scroll / expand options / input bar) / `ExpandOptionsView` / `inputBar` 全部沿用 v0.01.0 WO-004 实装。

**本卡扩展点**:
- `ChatViewModel.sendChatMessage(_ text: String)` 替换 `sendInitialStory` (alias, 内部调 `sendInitialStory`, **不改 ChatViewModel API 名字** — 沿用 v0.01.0 兼容)
- `ChatViewModel.loadChatHistory(projectId: UUID)` — **新增** (见 §5)
- `ChatViewModel.generateSkeletonOptions()` — `expandOptions = MockLLMResponse.expandOptions()` 的 alias, **名字不换**
- `ChatViewModel.applySkeletonChoice(_ choiceId: UUID)` — `selectDirections() + selectedDirectionIDs.insert(choiceId)` 的 alias, **等 `selectDirections()` 调用**

> **派单 body 要求的 4 个 API 名字 = 跟现有 ChatViewModel 现有方法 1:1 对应**:
| 任务 body API | 现有 ChatViewModel | 处理 |
|---|---|---|
| `sendChatMessage` | `sendInitialStory` | 新增 alias, 内部 delegate |
| `loadChatHistory` | (无) | **真新增** |
| `generateSkeletonOptions` | `expandOptions = MockLLMResponse.expandOptions()` (直接调) | 加薄 wrapper, 便于 task-style 调用 |
| `applySkeletonChoice` | `selectDirections` | 新增 alias, 内部 delegate |

**理由**: 不动现有 selectDirections / sendInitialStory → 不破坏 v0.01.0 已实装的 CharacterWorldView 路由 → 装机 user 8 步用户旅程不破。

---

## 4. ChatView (沿用 v0.01.0, 不动)

**不动**:
- `ChatView.swift` 153 行全部
- `ExpandOptionsView` (WO-004 实装)
- `ChatMessage` / `ExpandOption` model (WO-004 实装)
- input bar / paperplane.fill Button / bubble 渲染

**新增**:
- 只在 `ChatViewModel` 层加 4 个 alias + 1 个新方法 (见 §5)
- 不动 ChatView body

---

## 5. ChatViewModel 增强 API (designer 建议, CC 实现)

### 5.1 现有 `@Published` 状态 (沿用)

```swift
@Published var messages: [ChatMessage] = []
@Published var expandOptions: [ExpandOption] = []
@Published var selectedDirectionIDs: Set<UUID> = []
@Published var isGenerating: Bool = false
@Published var characters: [CharacterSnapshot] = []
@Published var worldRules: [WorldRuleSnapshot] = []
@Published var currentProject: ProjectSnapshot? = nil
@Published var pendingNavigation: AppRoute? = nil
```

**全部沿用, 不动 schema** (AGENTS §12 红线)。

### 5.2 新增 / alias 4 个公开 API

```swift
// MARK: - LT-N2 扩展 (alias 现有方法, 加 1 个新方法)

// 1. sendChatMessage (alias 现有 sendInitialStory, 不破 v0.01.0 CharacterWorldView 路由)
func sendChatMessage(_ text: String) async {
    await sendInitialStory(text)
}

// 2. loadChatHistory (LT-N2 真新增, 调 WenshuProjectStore.loadChatHistory)
func loadChatHistory(projectId: UUID) async {
    do {
        let history = try await WenshuProjectStore.shared.loadChatHistory(projectId: projectId)
        // 过滤 messages (只加载 user / assistant 角色)
        messages = history.compactMap { msg -> ChatMessage? in
            guard let role = msg["role"] as? String,
                  let content = msg["content"] as? String else { return nil }
            return ChatMessage(role: role, content: content)
        }
    } catch {
        FileHandle.standardError.write(Data(
            "ChatViewModel.loadChatHistory: \(error)\n".utf8
        ))
        // 加载失败: messages 保持空, 由 emptyHint 兜底
    }
}

// 3. generateSkeletonOptions (alias 现有 expandOptions 赋值, 便于 task-style 调用)
func generateSkeletonOptions() async {
    expandOptions = MockLLMResponse.expandOptions()
}

// 4. applySkeletonChoice (内部用 selectedDirectionIDs.insert + selectDirections)
func applySkeletonChoice(_ choiceId: UUID) async {
    if !selectedDirectionIDs.contains(choiceId) {
        toggleSelection(choiceId)
    }
    await selectDirections()
}
```

### 5.3 调用方 (designer 给 CC 的接口契约)

| 调用方 | 调用 | 备注 |
|--------|------|------|
| `ChatView.send()` (现有, line 147) | `await vm.sendChatMessage(text)` | 替换 `sendInitialStory` 调用, **alias 内部 delegate** |
| `ChatView.onAppear` (现有, line 31) | 加 `await vm.loadChatHistory(projectId: project.id)` | 跟 `vm.currentProject = project` 同步 |
| `ExpandOptionsView` (现有, WO-004) | 不动 | 沿用 `expandOptions` 字段 |
| `ExpandOption.onSelect` (现有, WO-004) | `await vm.applySkeletonChoice(optionId)` | 替换 `selectDirections()` 调用 |

**关键**: 沿用现有 `pendingNavigation` 机制 (`navPath.append(.characterWorld)`), 不改 AppRoute, 不改 NavigationStack 路由。

---

## 6. WenshuProjectStore 增强 API (designer 建议, CC 实现)

### 6.1 现有 API (沿用)

```swift
// 现有 save (WO-005 实装)
func save(
    project: ProjectSnapshot,
    characters: [CharacterSnapshot],
    worldRules: [WorldRuleSnapshot],
    initialStory: String
) async throws

// 现有 count
func savedEntityCount() async throws -> Int
func firstSavedStory() async throws -> String?
func savedCharacterNames() async throws -> [String]
```

**全部沿用, 不动** (AGENTS §12 红线: 不改 schema)。

### 6.2 新增 1 个公开 API

```swift
// Sources/WenshuApp/Storage/WenshuProjectStore.swift

// LT-N2 新增: 从 .ws 加载项目的聊天历史
// 沿用 tag-scoping (projectId → tag "project-<uuid>" → CDNote 过滤), 不动 schema
func loadChatHistory(projectId: UUID) async throws -> [[String: Any]] {
    let tag = "project-\(projectId.uuidString)"
    let notes = try await WenshuStoreActor.shared.listNotes()  // 全量拉
    let projectNotes = notes.filter { ($0["tags"] as? String)?.contains(tag) == true }
    // 按 .ws 中存的 "chat-history" 标签 CDNote 解析
    return projectNotes.compactMap { dict -> [String: Any]? in
        guard let text = dict["text"] as? String,
              let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return json
    }
}
```

**理由**:
- v0.01.0 `save()` 写 `CDNote` 时已用 tag-scoping (`tags = "project-<uuid>"`), 沿用同样的查询方式
- 不进 `WenshuStoreActor` schema (AGENTS §12 红线)
- 用 `listNotes()` 全量 + filter (v0.04.0 性能优化时, 再加 `listNotes(tag:)` API)

### 6.3 未来 (v0.04.0) 优化

- `WenshuStoreActor.listNotes(tag: String)` — actor 加 tag 索引, 性能提升
- `CDNote` 加 `lastModified` 字段 — schema 改动, **需 PM 拍**

---

## 7. 边界 (designer 不跨进 CC / PM 领域)

### 7.1 designer 出 (本稿范围)

- ✅ `DESIGN-LT-N2.md` 落盘 (本文件)
- ✅ ChatPanelView 4 tab 视觉不动 (沿用 V0-fix-4/6)
- ✅ ChatViewModel 4 alias + 1 新方法 API 建议
- ✅ WenshuProjectStore 1 新方法 API 建议
- ✅ LT-N1 + LT-N2 合并 8 步场景
- ✅ 区模块化 (bottomLeft 零依赖其他 panel)

### 7.2 designer 不出 (留给 CC 实现)

- ❌ 实际 `.swift` 文件代码 (本稿 §5 §6 给出参考骨架, CC 可调整实现细节, 但不能偏离设计意图)
- ❌ 单元测试代码
- ❌ git commit (CC 阶段完成代码后自己 commit, 本设计稿 commit 见 §8)
- ❌ `WenshuStoreActor` schema 改动 (AGENTS §12 红线)
- ❌ `AppRoute` 新增 (沿用 `.characterWorld`, 不加新 case)
- ❌ `NavigationStack` 根位置改动 (沿用 LT-N1 模式, 栈绑在 ChatPanelView 子树)

### 7.3 designer 不拍 (留给 PM / 装机 user)

- ⚠️ 矛盾 1: 4 tab 列表 (kanban vs outline)
- ⚠️ 矛盾 2: tab 顺序 (timeline 第几)
- ⚠️ 矛盾 3: "不动" "拍板"范围

### 7.4 留待未来迭代 (本稿不涉及)

- v0.04.0 长篇工具: 实装 `.timeline` / `.relationships` / `.outline` 3 个 disabled tab
- v0.05.0 标记系统: 在 `ChatView.messageRow` 加伏笔 / 信息点 / 历史事实 marker
- v0.06.0 iPhone 端: chat 同步 + 多端合并

---

## 8. 落盘与流程

### 8.1 文件落点

**本设计稿**: `Sources/WenshuApp/Views/Chat/DESIGN-LT-N2.md`

**CC 实现时新增的代码文件** (designer 不写, 仅声明位置):
- `Sources/WenshuApp/ViewModels/ChatViewModel+LTN2.swift` (新增, 4 alias + 1 新方法, 沿用主 class extension)
- `Sources/WenshuApp/Storage/WenshuProjectStore+LTN2.swift` (新增, 1 新方法)

**CC 实现时改的现有文件**:
- `Sources/WenshuApp/Views/ChatView.swift` (line 38 后加 `await vm.loadChatHistory(projectId: project.id)`; line 151 替换 `sendInitialStory` → `sendChatMessage`)
- `Sources/WenshuApp/Views/Chat/ChatPanelView.swift` (4 tab 列表**不动**, 沿用 V0-fix-4, **仅在矛盾 1 拍板后改**)

### 8.2 验证清单 (CC 完成后给 reviewer)

- [ ] 4 tab 居左 ICON (V0-fix-4/6 已实装, 本卡不动)
- [ ] 点 `chat` tab → ChatView 渲染
- [ ] 创建项目 → 切到 `chat` tab → 输入"一句话故事" → 发送
- [ ] AI 流式回复 (mock 或真实, 沿用 v0.01.0 FeatureFlag)
- [ ] 选 4 个骨架之一 → 跳 `CharacterWorldView`
- [ ] 关闭 app → 重开 → 进项目 → `chat` tab → 看到历史消息 (loadChatHistory 真生效)
- [ ] 4 个 layout splitter 拖动正常 (不破坏 LT-01 + fix10/13/14/16/17/18)
- [ ] `.timeline` / `.relationships` / `.outline` disabled 状态正确
- [ ] swift build exit 0
- [ ] swift test exit 0 (现有测试 + ChatViewModel alias test)

### 8.3 reviewer 审查重点

- 我的 4 个 alias **真 delegate** 到现有方法 (没改行为)
- `loadChatHistory` **真从 .ws 读** (不缓存假数据)
- ChatView 加 `onAppear` 调 `loadChatHistory` 时机**不阻塞** UI (async / actor)
- 不动 WenshuStoreActor schema (AGENTS §12 红线)
- 4 tab 视觉**完全沿用 V0-fix-4/6** (不悄悄改)

### 8.4 拍板真值核对

| 拍板 | 设计稿响应 |
|---|---|
| AGENTS §8.1 5 区几何 | ✅ 沿用, 不动 bottomLeft 边界 |
| AGENTS §12 schema 红线 | ✅ 沿用 tag-scoping, 不进 WenshuStoreActor |
| AGENTS §3 L3 三段式 | ✅ designer → CC → reviewer 三段 |
| AGENTS §3 L2 派单 (本卡) | ✅ LT-N2 = L2 (中等范围) |
| N1 §1 区模块化范式 | ✅ 沿用 (bottomLeft 跟 topLeft 同样自治) |
| V0-fix-4/6 已实装 chat 4 tab | ✅ 不动 (矛盾 1 拍板后改) |
| fix19 已改 ChatTabIconButton / 3 tab ICON | ✅ 不动 (现行 4 tab iconOnly, 沿用) |
| v0.01.0 8 步用户旅程 | ✅ 兼容 (alias 不破 CharacterWorldView 路由) |

---

## 9. 跟现有 wenshu FCP 范式的关系

- **结构 = FCP 结构**: ✅ bottomLeft 4 子 tab 居左 ICON (FCP timeline 范式)
- **功能 = 文枢功能**: 4 子 tab 内容是写作工具 (chat / timeline / relationships / outline), 跟 FCP (video clip / audio / title / transition) 占位不同
- **设计系统**: 沿用 `DESIGN-SYSTEM-INIT` (commit `bde233d42`) 12 原则 + 8 组件 + SF Symbol 映射
- **FCP 范式一致性**: 跟 v0.03.0 V0-fix-1~6 已实装的 6 处 UI FCP 化保持一致

---

## 10. 关联资源

- **任务派单**: `t_42fd2043` (8/11 09:33, assignee designer)
- **父任务**: `t_44c3f04e` (V0-fix-6 done, claude-code)
- **N1 兄弟卡设计稿**: `Sources/WenshuApp/Views/Project/DESIGN-LT-N1.md` (30.7 KB, 模式可吸收)
- **DESIGN-SYSTEM-INIT**: `bde233d42` (12 原则 + 8 组件 + SF Symbol, 5 角色共同遵守)
- **V0-fix-4/6 拍板真值**: `ChatPanelView.swift` 注释 (header bar 24pt / iconOnly / 居左)
- **v0.01.0 ChatView 源码**: `Sources/WenshuApp/Views/ChatView.swift` (153 行) + `ChatViewModel.swift` (251 行)
- **8 步用户旅程原文**: v0.01.0 WO-004 / WO-005 acceptance

---

*DESIGN-LT-N2 · designer 出稿 · 占卡 t_42fd2043 · 装机 user 派单拍板真值: 8 步场景 + 区模块化 + 4 子 tab 拍板 + ChatView 复用 + WenshuProjectStore 增强 API · 落档 `.worktrees/t_lt_n2_designer/Sources/WenshuApp/Views/Chat/DESIGN-LT-N2.md`*
