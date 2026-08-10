# DESIGN · V0-fix-1 · 文枢 (Wenshu)

> v0.03.0 V0-fix-1 (装机 user 8/10 14:35 OOB)
> 6 chu UI FCP-ification fix — 标题栏 0 text / 删 2 H1 / 4 chat tab ICON / modal 540x480 / kanban tab deferred / 设计文档

---

## 1. Background & 6 BUGs reported

### 1.1 装机 user OOB context

装机 user (8/10 14:35 OOB 实机验 v0.02.0 LOOP 后 5-zone shell) 反馈:
> "5 区布局已经跑通, 但左上 / 下左 / 右上的 panel 还残留 LT-01 早期形态的痕迹 — 标题栏写了"
> panel 名 (`项目管理视图` / `聊天区视图`), chat tab 4 个子 tab 还顶着对话双方标识, modal 用"
> 520×480 软下限。 跟 FCP / Pages / Numbers 比 — 不够内行。 全部按 FCP 风格走, 不要文字标题, "
> 用 hover tooltip 兜语义。"

### 1.2 6 件拍板 (装机 user 实体拍)

| # | 摘要 | 文件 | 物理行为 |
|---|------|------|---------|
| Fix A | 左上 panel 加 38pt "title-bar", 0 text + 右对齐 `plus.circle.fill` 按钮 (FCP toolbar) | `Layout/LayoutShellView.swift` | 新 private var `topLeftPanelWithTitleBar`, 38pt 固定高度, Spacer + Button(Image + help) |
| Fix B | 删 `Picker("聊天区视图", ...)` 字符串标签 (H1 残留) + `ProjectListView` 删 `项目管理视图` H1 (若有) | `Chat/ChatPanelView.swift` + `ProjectListView.swift` | Picker 改 `""`, 不动 v0.01.0 public API, 不动 `.navigationTitle("项目")` (macOS NavigationStack title, allow) |
| Fix C | 4 个 chat tab ICON-only, SF Symbol 简化 (bubble.left / clock / person.2 / list.bullet.rectangle) | `Chat/ChatPanelView.swift` | `ChatPanelTab.symbolName` 重映射 + `Picker` 内 `Label(tab.rawValue)` 改 `Image(systemName:)` + `.help(tab.rawValue)` |
| Fix D | `ProjectCreateView` modal 尺寸 `.frame(minWidth: 520, minHeight: 480)` → `.frame(width: 540, height: 480)` | `ProjectCreateView.swift` | 锁死尺寸, 用户无法拖动 (跟 macOS HIG 标准 modal 对齐) |
| Fix E | `ProjectKanbanTab.swift` (LT-03 / v0.04.0) ICON 32pt + 短 label + `.help()` tooltip | `Sources/WenshuApp/Views/ProjectKanbanTab.swift` | **v0.02.0 暂无此文件, deferred 到 v0.04.0**, 留 LT-03 实装 |
| Fix F | 本设计文档 | 本文件 | 拍板历史 + 实装契约 + 边界 + 验收 |

### 1.3 拍板历史 (避免后续拍板变化混淆)

V0-fix-1 不引入新拍板, 是 8/10 实机最后冲刺。 沿用 AGENTS.md §8.1 layout grammar +
LT-01-fix5 优化3 ("标题栏全删, 用功能告诉用户") + LT-01-fix3 (per-panel chevron → View menu)。

跟 V0-fix-1 冲突的旧拍板 (一律作废):
- ❌ LT-01 原 5-zone H1 文字 ("项目管理视图" / "聊天区视图" / "文档内容浏览器" / "inspector" / "状态")
- ❌ `bubble.left.and.bubble.right` / `clock.arrow.circlepath` / `list.bullet.indent`
- ❌ `frame(minWidth: 520, minHeight: 480)` modal 软下限

### 1.4 关系网

```
装机 user 8/10 14:35 OOB (实体拍板)
   ├─ Fix A/B/C/D/E/F ──→ PM-direct 工单 ─→ CC ─→ branch wt/t_b41cc645
                                       │
                                       ▼
              Tests/WenshuAppTests/V0Fix1LayoutTests.swift (7 tests)
                                       │
                                       ▼
                   swift test all 7 pass + commit + push 双 origin
```

---

## 2. Fix A: 0 title text + "+" button

### 2.1 拍板 (装机 user 8/10 OOB)

> "左上 panel 的标题栏 — 全删, 不要 '项目管理' 四个字。 加一个 `+` 按钮在标题栏最右, 高度
> 38pt, hover 看到 tooltip `新建项目`。 FCP toolbar 风格。"

### 2.2 文件 + 行号契约

**唯一文件**: `Sources/WenshuApp/Views/Layout/LayoutShellView.swift`

- 新增 `private var topLeftPanelWithTitleBar: some View`
- 在 `panel(_:width:)` 的 `if id == .topLeft` 分支内嵌
- 结构:

```swift
private var topLeftPanelWithTitleBar: some View {
    VStack(spacing: 0) {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            Button {
                // Fix A placeholder — no-op. LT-03 上线后接 NavigationStack push.
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("新建项目")
        }
        .frame(height: 38)
        .padding(.horizontal, 12)

        Divider()
        PlaceholderContent(panel: .topLeft)
    }
}
```

### 2.3 关键约束

- **height 38pt 硬固定** — FCP toolbar 风格
- **0 text** — HStack 只 `Spacer` + Button, 不允许加 `Text`
- **右对齐** — `Spacer(minLength: 0)` 在前, Button 在后
- **`Image(systemName: "plus.circle.fill")` 16pt medium** — 视觉轻
- **`.buttonStyle(.plain)` + `.help("新建项目")`** — hover 不出蓝底
- **`Divider()` 在 title-bar 和 PlaceholderContent 之间** — 1pt 横线视觉分界
- **业务流 (NavigationStack push) 留 LT-03** — 当前 LayoutShellView 没 NavigationStack,
  Button tap 留空 action

### 2.4 跟 PanelContainer 的关系

`PanelContainer(panelID: id) { ... }` 是 v0.02.0 chrome 提供器 (LT-01-fix3 把 chevron
删了, 现在只提供 background + 折叠/可见性管理)。 Fix A 的 title-bar **嵌在 PanelContainer
内部** (`.topLeft` 的 content slot 里), 不动 PanelContainer 自身。

### 2.5 不变量

- 5-zone geometry 不动 (topLeft 仍 20% 总宽)
- splitter (NativeSplitter 4 个) 不动
- 不加新 panel
- 不写 LayoutMetrics — title-bar 高度固定 38pt, 不参与"上半/下半比例"算

---

## 3. Fix B: Delete 2 redundant H1s

### 3.1 拍板 (装机 user 8/10 OOB)

> "Picker 别再带字符串标签 '聊天区视图' — 这就是 LT-04 早期加的 H1 残留。 改空字符串。"
> "ProjectListView 的 H1 '项目管理视图' — 如果还在, 删了。"

### 3.2 改动契约

**文件 1**: `Sources/WenshuApp/Views/Chat/ChatPanelView.swift`

```diff
- Picker("聊天区视图", selection: $activeTab) {
+ Picker("", selection: $activeTab) {
```

仅字符串改动, body 不动。 a11y label 由每个 tab 的 `.help(tab.rawValue)` 兜底。

**文件 2**: `Sources/WenshuApp/Views/ProjectListView.swift`

- 若源码内含 `"项目管理视图"` → 删该字符串 (H1 Text 整段移除)
- 若不存在 → no-op

注意: `ProjectListView.swift` line 35 `.navigationTitle("项目")` **不动** — 这是 macOS
NavigationStack 窗口标题 (traffic light 旁边), 不是 panel 内部 H1。

### 3.3 关键约束

- **公共 API 不动** — `ProjectListView` 的 `init(projects:navPath:)` + body public
  surface (被 `MainView.swift AppRoute.createProject navigationDestination` 消费 — v0.01.0
  路由契约)
- **a11y label 改空串而非删 `Picker(_)` 第一参数** — SwiftUI Picker API 必须有
  `LocalizedStringKey`, 改 `""` 满足 API 同时砍视觉红字
- **`text` 标签允许出现在 `ChatPanelTab.rawValue`** — enum 仍用 `"聊天" / "时间线" /
  "关系图" / "大纲"`, 走 `.help()` tooltip 显示中文, 不算 H1

### 3.4 不变量

- `ChatPanelTab` enum 不动
- `ChatPanelView` body 结构不变
- 不新增 view / 改 state

---

## 4. Fix C: 4 chat tabs ICON-only

### 4.1 拍板 (装机 user 8/10 OOB)

> "4 个 chat 子 tab — 改 ICON-only。 文字 label 从 Picker 删, tooltip hover 出。"
> "SF Symbol 也精简: bubble.left (单边气泡), clock (无 arrow.circlepath 装饰), person.2 "
> "(不变), list.bullet.rectangle (替代 indent, 大纲视觉更明确)。"

### 4.2 SF Symbol 映射

```diff
  var symbolName: String {
      switch self {
-     case .chat: return "bubble.left.and.bubble.right"
-     case .timeline: return "clock.arrow.circlepath"
+     case .chat: return "bubble.left"
+     case .timeline: return "clock"
      case .relationships: return "person.2"
-     case .outline: return "list.bullet.indent"
+     case .outline: return "list.bullet.rectangle"
      }
  }
```

| tab | 旧 SF Symbol | 新 SF Symbol | 备注 |
|-----|-------------|------------|------|
| 聊天 | `bubble.left.and.bubble.right` | `bubble.left` | 单边气泡 |
| 时间线 | `clock.arrow.circlepath` | `clock` | 无装饰 |
| 关系图 | `person.2` | `person.2` | 不动 |
| 大纲 | `list.bullet.indent` | `list.bullet.rectangle` | 层级视觉明确 |

### 4.3 Picker 内 Label 改 Image + .help()

```diff
  Picker("", selection: $activeTab) {
      ForEach(ChatPanelTab.allCases) { tab in
-         Label(tab.rawValue, systemImage: tab.symbolName)
+         Image(systemName: tab.symbolName)
              .tag(tab)
+             .help(tab.rawValue)
              .disabled(tab.isDisabled)
      }
  }
  .pickerStyle(.segmented)
```

### 4.4 active tab accent background

SwiftUI `.pickerStyle(.segmented)` 在 macOS 上自动给 active segment 加 accent 背景
(`accentColor` 灰蓝色, 圆角 ≈ 6pt), 不需要手动加 `.background()` / `.foregroundStyle()`。

### 4.5 关键约束

- **不写 `Label(_, systemImage:)`** — 文字完全靠 `.help(tab.rawValue)` tooltip
- **`.help(tab.rawValue)` 不可删** — ICON-only 必须靠 hover 出中文
- **3 个 disabled tab** 仍 `.disabled(tab.isDisabled)`, hover tooltip 仍然生效

### 4.6 不变量

- 4 个 tab 顺序不变 (`[chat, timeline, relationships, outline]`)
- `activeTab: ChatPanelTab = .chat` 默认值不变
- 4 个 placeholder Text (v0.04.0 实现) 不动
- `chatContent` 分支 (`.chat`) 不动 — 走 ChatView

---

## 5. Fix D: 540x480 modal

### 5.1 拍板 (装机 user 8/10 OOB)

> "ProjectCreateView modal — 软下限 520×480 在 split view 里用户拽边界时, modal 跟主"
> "窗口一起变形, 比例失调。 锁死 540×480 硬固定, 视觉稳定, 跟 macOS HIG 标准 modal 对齐。"

### 5.2 改动契约

**唯一文件**: `Sources/WenshuApp/Views/ProjectCreateView.swift`

```diff
-         .frame(minWidth: 520, minHeight: 480)
+         // Fix D: 540x480 硬固定 (原 520x480 软下限被撤换)
+         .frame(width: 540, height: 480)
```

### 5.3 Sheet vs NavigationStack 的取舍

`ProjectCreateView` 在 v0.01.0 已被 WO-010 拍板改用 NavigationStack push (见
`MainView.swift AppRoute.createProject navigationDestination`), 不是 SwiftUI `sheet`。
"540x480 modal" 是装机 user 8/10 实机看完 NavigationStack push 表现后的口述。

NavigationStack push 进 `ProjectCreateView` 之后, `ProjectCreateView` 自己用
`.frame(width:height:)` 锁死尺寸 — 即 "modal 视觉锁死", 但路由仍是 NavigationStack
(符合 WO-010, 避免 sheet 在 swift run + macOS focus policy 下抢不到 key window 的
历史 bug)。

**不变量**: 路由路径不动 (NavigationStack push), 仅 view 自身 frame 改硬固定。

### 5.4 关键约束

- **不动 sheet focus hack (WO-007)** — `WindowActivation.forceKeyToWenshuSheet()` +
  `@FocusState + 0.3s delay` 保留
- **不动 form 结构** — 5 个 Section (基本信息 / 文笔风格 / 注水量 / 标签 / 预览) 不动
- **不动 onCreate / onCancel 闭包签名** — 公共 API 保持
- **不动 5 种 style 选项** — `["严肃", "轻松", "诗意", "幽默", "口语"]` 不动

### 5.5 不变量

- `ProjectCreateView` 公共 API (`init(onCreate:onCancel:)`) 不动
- 5 个 form section 内容不动
- 取消 / 创建 Button 的 keyboardShortcut 不动

---

## 6. Fix E: Project kanban tab 32pt + short label + tooltip

### 6.1 拍板 (装机 user 8/10 OOB)

> "Project kanban tab — LT-03 上线后, 实际渲染那个 tab 里要有 ICON 32pt, 短中文标签 "
> "(2-4 字) 跟 ICON 一行排列, hover tooltip 兜一句长描述。"

### 6.2 期望结构 (LT-03 写时参考, 不在 V0-fix-1 范围)

```swift
// 期望结构 (LT-03 / v0.04.0 实装时按这风格)
Image(systemName: "rectangle.3.group")
    .font(.system(size: 32))
    .foregroundStyle(.secondary)
Text("看板")  // 短词 2-4 字
    .font(.callout)
.help("v0.04.0 完整看板 — 拖拽 + 多列 + 状态变化")
```

### 6.3 当前状态: deferred

截至 V0-fix-1 (2026-08-10), codebase 实际状态:

```
$ ls Sources/WenshuApp/Views/
CharacterWorldView.swift
Chat/                       ← ChatPanelView.swift
ChatView.swift
ExpandOptionsView.swift
Inspector/                  ← InspectorView.swift + InspectorViewModel.swift
Layout/                     ← LayoutShellView.swift + others
ProjectCreateView.swift
ProjectListView.swift
(无 ProjectKanbanTab.swift)
```

`Sources/WenshuApp/Views/Project/` 子目录在 v0.02.0 也不存在 (项目相关 view 全在根目录)。
LT-03 工单才建子目录 + 拆 5 tab (项目 / 章节 / 设定 / 资料 / 看板)。

**V0-fix-1 Fix E 决策**: SKIP, report `no-op: ProjectKanbanTab placeholder not yet in
v0.02.0 code, defer to v0.04.0`。 留 LT-03 工单派单时一起实装。

### 6.4 拍板的 deferred 边界 (装机 user 8/10 接受)

- 装机 user 8/10 OOB 拍板时**明确知道** LT-03 / v0.04.0 还没建 ProjectKanbanTab.swift,
  拍板属于"未来实装时按这风格"的指南, 不是当前迭代的硬要求
- 推迟不破坏 design intent — 等 LT-03 / v0.04.0 一上线, ICON 32pt + 短词 + tooltip 一次
  性按 §6.2 契约落地即可
- 不在 V0-fix-1 范围 stub 一个假 ProjectKanbanTab.swift — 那是占位代码, 会误导 LT-03
  接, CC 操作边界外

### 6.5 校验

```
$ ls Sources/WenshuApp/Views/ProjectKanbanTab.swift
ls: Sources/WenshuApp/Views/ProjectKanbanTab.swift: No such file or directory
```

`Tests/WenshuAppTests/V0Fix1LayoutTests.swift::testProjectKanbanTab_deferred_to_v040` 兜底
断言状态。

### 6.6 不变量

- v0.02.0 的 5-zone 不动 (LT-03 上线后左上 panel 内部再 5 tab, 不动 layout)
- 现有 `ProjectListView` 的项目列表 / 卡片不动
- 看板业务逻辑 (v0.04.0) 不动

---

## 7. Hard constraints

V0-fix-1 是 **6 件 UI 字面量微调**, 不是产品/架构变更。 红线:

| # | 红线 | 触犯后 |
|---|------|-------|
| 1 | 不改 v0.02.0 main 业务逻辑 — 5-zone geometry / schema / splitter / token / chat tab 内容 / kanban 业务 不动 | 升级 PM |
| 2 | 不改 WenshuStoreActor / CoreData entity / Package.swift / Info.plist | 升级 PM |
| 3 | 不改 ProjectListView public API | 升级 PM |
| 4 | 不改 LLM provider — 不动 `WenshuCore/LLM/` 任何文件, 不加 model, 不改 minimax 配置 | 升级 PM |
| 5 | 不写 LLM key 进文件/log/commit | 升级 PM |
| 6 | 跨 Apple 平台, 不动 Windows/Android | 升级 PM |
| 7 | 不写 zhuang-ji user 等待 / 实体验 / review-required 注释 (装机 user is out of the loop) | 删除注释重交 |
| 8 | 不超 5-zone 边界 — 不加第 6 个 panel | 回滚代码 |
| 9 | 不在 commit message 留 blocking 标记 — 5-role flow 必须 unblocked | 重写 commit msg |
| 10 | 不改 3 文档 — `AGENTS.md` / `README.md` / `CLAUDE.md` 完全不动 (AIF 真理源) | 升级 AIF |
| 11 | 不改 `.ws` schema — 不加 entity, 不改字段类型 | 升级 PM |
| 12 | 不动 `~/.hermes/` 或 `.archive/wenshu-monorepo-fork/` 任何文件 (只读历史封存) | 升级 AIF |
| 13 | 不写 ~/.wenshu/ 任何文件 (目录已取消) | 升级 PM |
| 14 | 不写 wenshu CLI — 文枢是 Swift 桌面 app, 不是 CLI | 升级 PM |

### 7.1 跟其他工单的相互不干扰

V0-fix-1 跟以下工单都是 **平行互不依赖**:

- LT-01-fix1…fix16 — 修 splitters / chevron / 折叠 / 5-zone layout, V0-fix-1 是表面视觉
- WO-LT-02-v2 — 右上 inspector 2 tab, V0-fix-1 不动 InspectorView
- WO-LT-04 — 下左 chat 4 子 tab, V0-fix-1 在其基础上 ICON-only 化
- WO-004 / WO-006 / WO-007 — ProjectCreateView (sheet focus hack), V0-fix-1 在其基础上
  改 frame
- WO-010 — ProjectListView NavigationStack 路由, V0-fix-1 不动路由

### 7.2 不许出现的代码模式

```swift
// ❌ 红线
.frame(minWidth: 520, minHeight: 480)
Picker("聊天区视图", ...) {
Label(tab.rawValue, systemImage: ...)
"bubble.left.and.bubble.right"
"clock.arrow.circlepath"
"list.bullet.indent"
Text("项目管理")
Text("聊天区")
```

### 7.3 推荐代码模式

```swift
// ✅ 模板
.frame(width: 540, height: 480)
Picker("", selection: $activeTab) {
Image(systemName: tab.symbolName)
    .help(tab.rawValue)
"bubble.left"
"clock"
"list.bullet.rectangle"
Image(systemName: "plus.circle.fill")
    .help("新建项目")
```

---

## 8. Acceptance criteria

### 8.1 单元测试 (`Tests/WenshuAppTests/V0Fix1LayoutTests.swift`)

7 个 test 必须全 pass:

| Test | 拍板 | 断言 |
|------|------|------|
| `testLayoutShellView_topLeftPanelTitle_noH1Text` | Fix B | LayoutShellView.swift 不含 `"项目管理视图"` |
| `testLayoutShellView_bottomLeftPanelTitle_noH1Text` | Fix B | LayoutShellView.swift 不含 `"聊天区视图"` |
| `testLayoutShellView_topLeftHeaderBar_hasPlusButton` | Fix A | LayoutShellView.swift 含 `"plus.circle.fill"` + `"新建项目"` + `".frame(height: 38)"` |
| `testChatPanelView_chatTabIcons_4Icons` | Fix C | ChatPanelView.swift 含 `bubble.left`, `clock`, `person.2`, `list.bullet.rectangle`, 不含 `"Label(tab.rawValue"`, 不含 `"Picker(\"聊天区视图\""` |
| `testProjectCreateView_modalSheetSize_540x480` | Fix D | ProjectCreateView.swift (strip 注释后) 含 `".frame(width: 540, height: 480)"`, 不含 `".frame(minWidth: 520, minHeight: 480)"` |
| `testLayoutShellView_titleBar_noProjectLiteral` | Fix A 兜底 | LayoutShellView.swift (strip 注释后) 不含独立 panel 名 H1 字面量 (`"项目"`, `"项目管理"`, `"项目管理视图"`) |
| `testProjectKanbanTab_deferred_to_v040` | Fix E deferred | `Sources/WenshuApp/Views/ProjectKanbanTab.swift` 不存在, 且 `Sources/WenshuApp/Views/` 下不含 kanban 文件 |

### 8.2 编译 + 全测试

```bash
$ swift build
Build complete!

$ swift test
... (102 tests, 5 pre-existing failures on main, 0 new failure)
Test Suite 'V0Fix1LayoutTests' passed
    Executed 7 tests, with 0 failures (0 unexpected)
```

注: LT-01-fix13/fix7/PanelSplitterDragTests 这 5 个 splitter drag 失败是 main 分支已有
bug (= NativeSplitter `lastReported` reset + clamp 边界 bug), 跟 V0-fix-1 6 件 UI fix 完全
无关; LT-01 工单的修复范围, 不归 V0-fix-1 管。 V0-fix-1 commit 不得动 splitter 代码。

### 8.3 Git 契约

- branch 唯一: `wt/t_b41cc645`
- commit 单一: 6 件 + 测试 + 设计文档 一次 commit
- commit message:
  ```
  v0.03.0 V0-fix-1: 6 chu UI FCP fix (zhuang-ji user 8/10 pai —
    title-bar no text / del 2 H1 / 4 chat tab ICON / modal 540x480 /
    kanban tab 32pt+duan ci+tooltip)
  ```
  - zhuang-ji user = 装机 user
  - 8/10 pai = 8/10 拍板
  - duan ci = 短词
- push 双重: `git push origin` AND `git push old-origin`
- 不 push --force, 不 push 到 main, 不 amend 别人 commit

### 8.4 PM-direct 验收

PM-direct 在 macOS 跑 `swift run WenshuApp`:

1. **Fix A**: 左上 panel 38pt 标题栏, 只有 `+` 按钮在右边, hover 出 "新建项目"
2. **Fix B**: Picker 无 "聊天区视图" 字符串; 左上 panel 无 "项目管理" / "项目管理视图"
3. **Fix C**: chat 4 tab ICON-only (bubble.left / clock / person.2 /
   list.bullet.rectangle), 文字 hover 才出
4. **Fix D**: 点 `+` → ProjectCreateView, modal 540×480 硬固定, 拖窗口边角不变形
5. **Fix E**: 无 ProjectKanbanTab.swift 文件
6. **Fix F**: `Sources/WenshuApp/Views/DESIGN-V0-fix-1.md` 存在

### 8.5 不验收项

- 装机 user 实机验 → 不在 V0-fix-1 范围, 装机 user 出 loop, PM-direct 兜底
- 不写 "review-required: zhuang-ji user" / "等 zhuang-ji user 拍" / "zhuang-ji user
  实机验" 注释 — 装机 user is out of the loop, my-pm 跑 PM-direct

### 8.6 后续工单

- LT-03 (左上项目管理 5 tab — 项目 / 章节 / 设定 / 资料 / 看板, 包括 ProjectKanbanTab
  按 Fix E 实装)
- 5-zone 快捷键可视化 (Cmd+1…5 已经在 App.swift CommandMenu, 下一步把快捷键放 View
  menu 文案后面)

---

## Appendix A — 文件改动摘要

```
modified  Sources/WenshuApp/Views/Layout/LayoutShellView.swift
modified  Sources/WenshuApp/Views/Chat/ChatPanelView.swift
modified  Sources/WenshuApp/Views/ProjectCreateView.swift
new       Tests/WenshuAppTests/V0Fix1LayoutTests.swift
new       Sources/WenshuApp/Views/DESIGN-V0-fix-1.md
```

5 文件 (3 改 + 2 新), 1 commit, 2 pushes。

## Appendix B — 拍板历史汇总

| 日期 | 工单 | 拍板 | 文件 |
|------|------|------|------|
| 2026-08-06 | v0.00.0 | 项目基线 (Swift/SwiftUI + CoreData + minimax cn LLM) | AGENTS.md |
| 2026-08-07 | WO-LT-04 | 下左 chat 4 子 tab (1 实装 + 3 disabled) | ChatPanelView.swift |
| 2026-08-07 | LT-01-fix5 | 删 H1 标题栏, "用功能告诉用户" 拍板 | 全部 panel |
| 2026-08-07 | LT-01-fix3 | per-panel chevron 改 View menu | App.swift |
| 2026-08-07 | LT-01-fix9 | splitters 改 NativeSplitter | LayoutShellView.swift |
| 2026-08-07 | WO-010 | ProjectCreateView 改 NavigationStack push | MainView.swift + ProjectCreateView.swift |
| 2026-08-07 | WO-007 | ProjectCreateView sheet NSWindow.makeKey() | ProjectCreateView.swift |
| **2026-08-10** | **V0-fix-1** | **6 chu UI FCP-ification fix (本文件)** | **5 文件** |
