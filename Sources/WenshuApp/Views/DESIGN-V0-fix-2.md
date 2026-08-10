# DESIGN · V0-fix-2 · 文枢 (Wenshu)

> v0.03.0 V0-fix-2 (装机 user 8/10 15:30 + 15:35 OOB 实机拍)
> 真修 V0-fix-1 (commit 1512a68d3) 漏修的 **4 处** UI BUG
> — 聊天区视图 H1 真删 + 4 chat tab 改 `.iconOnly`
> — 右上 inspector ICON-only + 删"检视" H1
> — 顶部 "+ 新建项目" 按钮重写 (v-fix-1 commit 不在本 branch)
> — 左上 5 tab 列表重写 (LT-03 v2 commit 3fab4fadc 不在本 branch)

---

## 0. 任务背景 & 矛盾点 (designer 读派单 + 代码后整理)

### 0.1 装机 user OOB 实机拍 (15:30 + 15:35)

装机 user 8/10 15:30 重启 APP 实机验 V0-fix-1 (commit 1512a68d3) 后:
> "**还有 2 处不符** — 下左聊天区还看到 '聊天区视图' 4 个字 + 4 个 chat tab 仍显文字; 右上 inspector '检视' H1 + '伏笔' '修订' tab 文字全在 (= V0-fix-1 完全没动 inspector)。"

装机 user 8/10 15:35 再重启 APP 实机验:
> "**新建项目区域的功能全消失了** — 顶部的 '+ 新建项目' 按钮没了, **两次不符合规则**."

15:30 报 BUG 7 (聊天区) + **BUG 缺失** (右上 inspector, AIF 推论), 15:35 报 BUG 8 (顶部 + 按钮消失) + BUG 9 (左上 5 tab 列表消失, AIF 推论装机 user 没明说)。

### 0.2 真根因 (designer 读源码 + git 历史后)

**核心发现**: 当前 worktree `wt/t_29d24bd7` 从 main `492c96750` 拉出, **不含**:

| 不在 worktree 的 commit | 含什么 | 装机 user 15:35 看到的"消失" = |
|---|---|---|
| `1512a68d3` (V0-fix-1) | `topLeftPanelWithTitleBar` (38pt + button + .help) + `LayoutShellView.panel(.topLeft)` 改用 `topLeftPanelWithTitleBar` | BUG 8: 顶部 + 按钮消失 |
| `3fab4fadc` (v0.02.0 LT-03 v2) | `Sources/WenshuApp/Views/ProjectManagement/` 整目录 (5 个新文件: ProjectManagementView + 5 Tab 内容) + `LayoutShellView.panel(.topLeft)` 改用 `ProjectManagementView()` | BUG 9: 5 tab 列表消失 |
| `cfce73389` (V0-fix-2-designer, 前一个 session) | 仅 `Sources/WenshuApp/Views/DESIGN-V0-fix-2.md` + `Tests/WenshuAppTests/V0Fix2LayoutTests.swift`, **未实现代码** | (本卡接手) |

**V0-fix-1 commit (1512a68d3) 实际落地的状态** (CC 改完, 但此 worktree 没带):
- LayoutShellView 加 `topLeftPanelWithTitleBar` private var (38pt HStack + Spacer + `Button(Image.plus.circle.fill)` + `.help("新建项目")`)
- LayoutShellView 的 `panel(.topLeft)` 改用 `topLeftPanelWithTitleBar` (取代原 PlaceholderContent)
- ChatPanelView Picker a11y 改 `""` (Fix B) + 4 SF Symbol 改 `Image(systemName:)` + `.help()` (Fix C) — 但 **`.segmented` 风格未改**
- ProjectCreateView 540×480 (Fix D)
- 新增 DESIGN-V0-fix-1.md + 7 个 V0Fix1LayoutTests

**v0.02.0 LT-03 v2 commit (3fab4fadc) 实际落地的状态** (CC 改完, 但此 worktree 没带):
- 新增 `ProjectManagement/ProjectManagementView.swift` (5 tab 根: Picker.segmented + 5 Tab 切换)
- 新增 5 Tab 内容 View: ProjectListTab / ChapterTreeTab / ProjectSettingsTab / ResourceLibraryTab / ProjectKanbanTab
- 新增 ProjectManagementViewTests.swift (5 test)
- LayoutShellView `panel(.topLeft)` 改用 `ProjectManagementView()` (替代 V0-fix-1 的 `topLeftPanelWithTitleBar`)
- 注: LT-03 v2 的 `+` 新建项目按钮**内嵌在 ProjectListTab** (`.toolbar { ToolbarItem(.primaryAction) { Button(Label("新建项目", systemImage: "plus")) ... } }`), 不是 LayoutShellView 的 title-bar

### 0.3 V0-fix-2 范围 (派单 body 拍板, designer 不自加)

派单 body §2 红框 4 处 BUG 合并修:

| # | BUG | 来源 | 修法 |
|---|-----|------|------|
| Fix G | ChatPanelView "聊天区视图" H1 真删 + 4 chat tab 改 `.iconOnly` | 15:30 | `Picker(.segmented)` → `Picker(.iconOnly)` |
| Fix H | InspectorView "检视" H1 真删 + 2 tab ICON-only | 15:30 | 删 selfHeader + Picker 改 ICON-only + 加 `iconName(for:)` |
| **Fix I** ← NEW 15:35 | 顶部 "+ 新建项目" 按钮重写 | 15:35 | LayoutShellView 重写 `topLeftPanelWithTitleBar` (38pt HStack + plus.circle.fill + .help) |
| **Fix J** ← NEW 15:35 | 左上 5 tab 列表重写 | 15:35 | ProjectListView 重写 5 tab 容器 (沿用 LT-03 v2 设计) |

**派单 body 拍板要点**:
- 不动 v-fix-1 已修的 (LayoutShellView 部分 / ProjectListView 部分 / ProjectCreateView 540×480 / DESIGN-V0-fix-1.md / V0Fix1LayoutTests)
- 不破坏 ProjectListView 5 tab 容器重构 (现有 @Binding projects / @Binding navPath 不动)
- 不写 "等装机 user 验" / "review-required: 装机 user" 等阻塞字样 (装机 user out of loop, PM-direct 兜底)

### 0.4 矛盾点 (designer 必标, 派单 body 已拍板, 不再升级)

| # | 矛盾 | 派单拍板 | designer 接受 |
|---|------|----------|----------------|
| 1 | InspectorView 自带 `selfHeader` H1 "检视" (line 87-99, V0-fix-1 没动) — 真删这条 selfHeader 还是改空字串? | 派单 §1 红框 1 "**删 H1 '检视' 标题**" | ✅ 整段删 selfHeader (跟 ChatPanelView 一致) |
| 2 | InspectorViewModel.Tab 没 `iconName` 属性 — v-fix-2 改 inspector tab ICON 要么 (a) Tab enum 加 computed property, 要么 (b) InspectorView 内 inline 静态映射 | 派单没明确, 拍板"4 类比 chat tab 修法" → 走 (b) inline | ✅ InspectorView 内 private func `iconName(for: Tab) -> String` |
| 3 | inspector 2 tab SF Symbol 选什么? 派单 §1 红框 1 拍 `eye` / `pencil.and.list.clipboard` (新设计) — 跟 V0-fix-1 Fix C 简化风格保持一致, 不复用 v0.02.0 WO-LT-02-v2 的 `leaf` | 派单已拍板 | ✅ `eye` / `pencil.and.list.clipboard` |
| 4 | active tab accent 圆角背景是否要手画? V0-fix-1 Fix C 拍板 ".segmented 自动加 accent" — 改 `.iconOnly` 后还在吗? | 派单 §1 红框 2 "active tab 6pt accent 圆角背景 (v-fix-1 拍板保留)" | ⚠️ designer 测试假设 `.iconOnly` 仍有 macOS 系统 accent 渲染 — 如果测试发现没, 升级 PM-direct 拍"加 `.background()`"或"自定义 Picker". 不预先写备援代码 |
| **5** | **顶部 + 按钮 (Fix I) 是 LayoutShellView 责任还是 ProjectListView 责任?** V0-fix-1 Fix A 把按钮放 LayoutShellView (`topLeftPanelWithTitleBar`), LT-03 v2 commit 3fab4fadc 把按钮放 ProjectListView (`ProjectListTab.toolbar` 内). 派单 §2 红框 5 拍板 "**重写 topLeftPanelWithTitleBar** (38pt HStack + plus.circle.fill + .help)". | 派单已拍板走 V0-fix-1 范式 | ✅ LayoutShellView 加 `topLeftPanelWithTitleBar` (38pt HStack), 5 tab 列表放 `ProjectListView` 体内. **不复用** LT-03 v2 的 toolbar 范式 (跟 V0-fix-1 拍板对齐) |
| **6** | **5 tab 列表 (Fix J) 是新文件 ProjectManagementView 还是改写 ProjectListView?** 派单 §2 红框 6 拍板 "**重写 ProjectListView.swift 5 tab 容器**" + §3 "**沿用 LT-03 v2 设计** (之前 commit 3fab4fadc 是 5 tab 实际实现)". | 派单已拍板改写 ProjectListView, 不新建 ProjectManagement/ 目录 | ✅ 5 tab 容器写在 `Sources/WenshuApp/Views/ProjectListView.swift` (单文件), 5 个 Tab 内容 View 作为 ProjectListView 内部 private struct (不放独立文件). 沿用 LT-03 v2 同名 enum `ProjectManagementTab` 和 5 SF Symbol (`folder` / `list.bullet.rectangle` / `slider.horizontal.3` / `books.vertical` / `rectangle.split.3x1`) |
| **7** | **5 tab 容器内的 + 按钮去哪?** V0-fix-1 Fix A 的 `+` 按钮 (LayoutShellView title-bar) 已经放在 5 tab 容器**上方** (panel chrome), Tab 1 (项目) 内的 `+` 按钮**冗余** — 是 1 个还是 2 个? | 派单 §2 红框 5 拍板 "顶部 '+ 新建项目' 按钮" + 红框 6 拍板 "5 tab 列表" 没明确说 Tab 内是否再放 + | ✅ **只 1 个** `+` 按钮 (LayoutShellView title-bar, Fix I 提供), Tab 1 (项目) 内的 `.toolbar { ... }` 删. 避免视觉冗余 (FCP 范式 = 单 + 入口) |

### 0.5 跟 V0-fix-1 + LT-03 v2 的不重叠

V0-fix-2 不重复 V0-fix-1 已修的:
- LayoutShellView 删 "项目管理视图" / "聊天区视图" 字面量 (Fix B 已删的 source)
- ChatPanelView Picker a11y 字符串改 `""` (Fix B 已删的 a11y)
- ChatPanelView 4 个 SF Symbol 简化映射 (Fix C 已改的 enum symbolName: `bubble.left` / `clock` / `person.2` / `list.bullet.rectangle`)
- ChatPanelView Picker 块改 `Image(systemName:)` + `.help()` (Fix C 已改的 Picker body)
- ProjectCreateView 540×480 (Fix D)
- 7 个 V0Fix1LayoutTests 测试 (Fix F)
- V0-fix-1 Fix A 的 `topLeftPanelWithTitleBar` 38pt + .help("新建项目") 范式 — **本卡继承**

V0-fix-2 不重复 LT-03 v2 (commit 3fab4fadc) 已实现的:
- `ProjectManagementTab` enum (case 5: projects / chapters / settings / resources / kanban)
- 5 SF Symbol: `folder` / `list.bullet.rectangle` / `slider.horizontal.3` / `books.vertical` / `rectangle.split.3x1`
- 5 tab 默认值 = `.projects` (tabIndex 0)
- Tab 内容 View 范式 (Tab 1+2 实装, Tab 3-5 占位)

V0-fix-2 重做的 (跟 v-fix-1 + LT-03 v2 都不同):
- **不删** v-fix-1 的 `topLeftPanelWithTitleBar` (Fix I 保留)
- **不**走 LT-03 v2 的 `ProjectManagement/` 子目录拆分 (5 tab 内容放 ProjectListView 内部)
- **不**保留 LT-03 v2 的 Tab 1 内 `+` 按钮 (与 Fix I title-bar `+` 按钮冲突, 按 §0.4 第 7 条合并为 1 个)

---

## 1. Fix G: ChatPanelView 真删 H1 + Picker 改 `.iconOnly`

### 1.1 拍板 (装机 user 8/10 15:30 OOB)

> "聊天区底下还看到 '聊天区视图' 4 个字 — 这是 H1 残留, 真删了。
> chat 4 个 tab 仍显文字 — 改 ICON-only, macOS 13 上 segmented picker
> 不会自动渲染 SF Symbol, 必须 `.iconOnly` 强制."

### 1.2 现状代码 (V0-fix-1 后, worktree 现状)

`Sources/WenshuApp/Views/Chat/ChatPanelView.swift` line 38-49 (worktree 实际状态, **不含** V0-fix-1 改动):

```swift
var body: some View {
    VStack(spacing: 0) {
        Picker("聊天区视图", selection: $activeTab) {   // ← V0-fix-1 没改这行 (worktree 不带)
            ForEach(ChatPanelTab.allCases) { tab in
                Label(tab.rawValue, systemImage: tab.symbolName)  // ← V0-fix-1 没改这行
                    .tag(tab)
                    .disabled(tab.isDisabled)
            }
        }
        .pickerStyle(.segmented)                       // ← V0-fix-1 没改这行
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
```

注: worktree `wt/t_29d24bd7` 不带 V0-fix-1 commit 1512a68d3, ChatPanelView 当前状态是 v0.02.0 WO-LT-04 commit 89c77ea8a 原始版 (Label + .segmented + Picker("聊天区视图")). 装机 user 15:30 实机验时, 可能验的是合并 v0-fix-1 后的 main, 也可能验的是 worktree. V0-fix-2 必须**全部都做** (既改 a11y 又改 .iconOnly), 不假设 v0-fix-1 已经做过 a11y 改空.

### 1.3 改动契约

**唯一文件**: `Sources/WenshuApp/Views/Chat/ChatPanelView.swift`

```diff
  var body: some View {
      VStack(spacing: 0) {
-         Picker("聊天区视图", selection: $activeTab) {
+         // V0-fix-2 Fix G: 真删 H1 "聊天区视图" + Picker 改 .iconOnly
+         // (macOS 13 .segmented fallback 显 SF Symbol 文字 — 必须
+         //  .iconOnly 才真 ICON-only, 跟 V0-fix-1 Fix C 同源漏修).
+         Picker("", selection: $activeTab) {
              ForEach(ChatPanelTab.allCases) { tab in
-                 Label(tab.rawValue, systemImage: tab.symbolName)
+                 Image(systemName: tab.symbolName)
                      .tag(tab)
+                     .help(tab.rawValue)
                      .disabled(tab.isDisabled)
              }
          }
-         .pickerStyle(.segmented)
+         .pickerStyle(.iconOnly)
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
```

注: 跟 V0-fix-1 Fix C 不同 — V0-fix-2 Fix G 同时改 3 处 (a11y / Label→Image / .segmented→.iconOnly). 因为 worktree 不带 V0-fix-1, 必须 3 处一起做.

### 1.4 active tab accent 圆角背景

SwiftUI `.pickerStyle(.iconOnly)` 在 macOS 上对 active segment 自动加 accent 背景 (`accentColor` 灰蓝色, 圆角 ≈ 6pt). 跟 V0-fix-1 Fix C `.segmented` 同形态 — **不需要手动加 `.background()` / `.foregroundStyle()`**.

**不写备援代码** — 派单 body §0.4 第 4 条拍板 "等 PM-direct 反馈, 0 阻塞字样". 如果 `swift run` 实测 active tab accent 没了, 升级 PM-direct.

### 1.5 关键约束

- **不动** `ChatPanelTab` enum (rawValue / symbolName / isDisabled / placeholder)
- **不动** `ChatPanelView` body 结构 (VStack / Picker / Divider / Group)
- **不动** `activeTab: ChatPanelTab = .chat` 默认值
- **不动** 4 个 placeholder Text (v0.04.0 实现)
- **不动** `chatContent` 分支 (`.chat`) — 走 ChatView
- **不动** 3 个 disabled tab (`.timeline` / `.relationships` / `.outline`) — 仍 `.disabled(tab.isDisabled)`
- **不写** "等装机 user 验" / "review-required: 装机 user" 注释 — 装机 user out of loop, PM-direct 兜底

### 1.6 不变量

- `ChatPanelTab` enum 5 case (`chat` / `timeline` / `relationships` / `outline`) + symbolName 映射 (`bubble.left.and.bubble.right` / `clock.arrow.circlepath` / `person.2` / `list.bullet.indent`) 全保留
- `chatVM.currentProject` 状态 + `NavigationStack(path: $navPath)` 全保留
- 4 个 tab `.disabled(tab.isDisabled)` 行为不变

---

## 2. Fix H: InspectorView 真删 H1 "检视" + Picker 改 ICON-only

### 2.1 拍板 (装机 user 8/10 15:30 OOB)

> "右上 inspector 还顶着 '检视' / '伏笔' / '修订' 文字 — 跟下左聊天区
> 一起改: 删 '检视' H1, 2 个 tab ICON-only (伏笔 = eye, 修订 =
> pencil.and.list.clipboard)."

### 2.2 现状代码 (V0-fix-1 没动 InspectorView)

`Sources/WenshuApp/Views/Inspector/InspectorView.swift` line 46-99 (worktree 实际状态, V0-fix-1 完全没动):

```swift
var body: some View {
    VStack(spacing: 0) {
        selfHeader                                         // ⚠️ v-fix-2 要删 (H1 "检视")
        Divider()
        Picker("检视", selection: $vm.selectedTab) {        // ⚠️ v-fix-2 要改 ""
            ForEach(InspectorViewModel.Tab.allCases) { tab in
                Text(tab.title).tag(tab)                    // ⚠️ v-fix-2 要改 Image
            }
        }
        .pickerStyle(.segmented)                            // ⚠️ v-fix-2 要改 .iconOnly
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        Divider()
        Group {
            switch vm.selectedTab {
            case .foreshadow:
                foreshadowList
            case .revision:
                revisionList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .task { await vm.loadForeshadows() }
}

// MARK: - Top self-identity (FCP 范式 "用功能告诉用户")
private var selfHeader: some View {                        // ⚠️ v-fix-2 要删整段
    HStack(spacing: 6) {
        Image(systemName: "sidebar.right")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)
        Text("检视")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.primary)
        Spacer()
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
}
```

**分析**: InspectorView 完全没动 V0-fix-1 — `selfHeader` H1 残留 + `Picker("检视")` a11y 文字 + `Text(tab.title)` 文字 tab + `.segmented` fallback 全在.

### 2.3 改动契约

**唯一文件**: `Sources/WenshuApp/Views/Inspector/InspectorView.swift`

#### 2.3.1 删 `selfHeader` H1 (整段)

```diff
  var body: some View {
      VStack(spacing: 0) {
-         selfHeader
          Divider()
          Picker("检视", selection: $vm.selectedTab) {
              ...
```

#### 2.3.2 Picker 改 ICON-only

```diff
-         Picker("检视", selection: $vm.selectedTab) {
+         // V0-fix-2 Fix H: Picker 改 ICON-only (.iconOnly + Image
+         // + .help() 兜中文) + Picker a11y 改 "" (跟 ChatPanelView
+         // Fix G §1.3 同形态). iconName(for:) 走 View 内 inline
+         // 静态映射, 不动 InspectorViewModel (跟 V0-fix-1 不动
+         // ChatPanelViewModel 同策略).
+         Picker("", selection: $vm.selectedTab) {
              ForEach(InspectorViewModel.Tab.allCases) { tab in
-                 Text(tab.title).tag(tab)
+                 Image(systemName: iconName(for: tab))
+                     .tag(tab)
+                     .help(tab.title)
+                     .disabled(false)
              }
          }
-         .pickerStyle(.segmented)
+         .pickerStyle(.iconOnly)
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
```

#### 2.3.3 加 `iconName(for:)` inline 静态映射 + 删 `selfHeader` private var

```diff
  // MARK: - Top self-identity (FCP 范式 "用功能告诉用户")

- /// Inspector content 自己的 H1 self-identity (LT-01-fix5 拍板:
- /// PanelContainer 已删 headerBar, content 自带 H1)。 跟
- /// PlaceholderContent 的 hint 文案不同 — inspector 不是空 panel,
- /// 是真有功能的区, 必须显式告诉用户"这是检视", 不能闷头只显示
- /// 一堆 hook 让装机 user 找不清在哪。
- private var selfHeader: some View {
-     HStack(spacing: 6) {
-         Image(systemName: "sidebar.right")
-             .font(.system(size: 13, weight: .medium))
-             .foregroundStyle(.secondary)
-         Text("检视")
-             .font(.system(size: 14, weight: .semibold))
-             .foregroundStyle(.primary)
-         Spacer()
-     }
-     .padding(.horizontal, 12)
-     .padding(.vertical, 8)
- }
+ // MARK: - V0-fix-2 Fix H: iconName(for:) inline 静态映射
+
+ /// Inspector 2 tab 的 SF Symbol 映射 — 走 View 内 inline, 不动
+ /// InspectorViewModel (跟 V0-fix-1 不动 ChatPanelViewModel 同策略).
+ /// 伏笔 = eye (表"看穿 / 注视"), 修订 = pencil.and.list.clipboard
+ /// (表"用铅笔 + 列表改写"). 跟 V0-fix-1 Fix C 简化风格保持一致.
+ private func iconName(for tab: InspectorViewModel.Tab) -> String {
+     switch tab {
+     case .foreshadow: return "eye"
+     case .revision: return "pencil.and.list.clipboard"
+     }
+ }
```

### 2.4 关键约束

- **不动** `InspectorViewModel.shared` (单例 + `selectedTab` / `foreshadows` / `revisionCandidates` 全部不变)
- **不动** `InspectorViewModel.Tab` enum (case `foreshadow` / `revision` + `title` 属性)
- **不动** `.task { await vm.loadForeshadows() }` 触发器
- **不动** `foreshadowList` / `revisionList` Group 分支逻辑
- **不动** `ForeshadowRowView` / `RevisionRowView` (单条伏笔/修订行 View)
- **不动** 兜底空态 (`emptyForeshadowState` 等)
- **不动** 3 条 mockRevisionCandidates (硬编码)

### 2.5 不变量

- `InspectorViewModel.shared` 单例契约保留
- 2 tab 默认 `selectedTab = .foreshadow` (init 默认值) 不变
- `.iconOnly` 的 active tab accent 由 macOS 系统渲染 (跟 Fix G §1.4 同形态)

---

## 3. Fix I: LayoutShellView 重写 `topLeftPanelWithTitleBar` (顶部 + 按钮)

### 3.1 拍板 (装机 user 8/10 15:35 OOB)

> "**新建项目区域的功能全消失了** — 顶部的 '+ 新建项目' 按钮没了."

**真根因** (§0.2 表 1): 当前 worktree 不带 V0-fix-1 commit 1512a68d3, LayoutShellView 的 `.topLeft` 分支走 `PlaceholderContent(panel: .topLeft)` (无 + 按钮, 无 title-bar). V0-fix-1 commit 加的 `topLeftPanelWithTitleBar` private var 在原 branch 落地, 但 cherry-pick 没到本 worktree.

### 3.2 现状代码 (worktree 实际状态, **不含** V0-fix-1)

`Sources/WenshuApp/Views/Layout/LayoutShellView.swift` line 181-193 (现状):

```swift
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
                // CDForeshadow + 修订 mock 3 条)。
                InspectorView()
            } else {
                PlaceholderContent(panel: id)   // ⚠️ topLeft 走这里 = 无 + 按钮
            }
        }
        .frame(width: width)
    }
}
```

### 3.3 改动契约

**唯一文件**: `Sources/WenshuApp/Views/Layout/LayoutShellView.swift`

#### 3.3.1 `.topLeft` 分支改用 `topLeftPanelWithTitleBar`

```diff
  } else {
      PanelContainer(panelID: id) {
+         if id == .topLeft {
+             // V0-fix-2 Fix I: 38pt title-bar (0 text + plus.circle.fill
+             // + .help "新建项目") 嵌 LayoutShellView 顶, 不动 5-zone
+             // geometry, 不动 splitter. 业务流 (NavigationStack push
+             // ProjectCreateView) 留 ProjectListView 接管 — 此处按钮
+             // 仅占位, 等 ProjectListView 内部接线.
+             topLeftPanelWithTitleBar
+         } else if id == .bottomLeft {
-         if id == .bottomLeft {
              ChatPanelView()
          } else if id == .topRight {
              ...
```

#### 3.3.2 加 `topLeftPanelWithTitleBar` private var

```diff
+ // MARK: - V0-fix-2 Fix I: topLeft title-bar (FCP 风格, 0 text + "+" button)
+
+ /// 左上 panel 的 title-bar + 5 tab 内容容器。 高度 38pt 固定 title-bar
+ /// (VStack(spacing: 0) { HStack 38pt ...; Divider(); ProjectListView() }).
+ /// title-bar 内容 = Spacer + `plus.circle.fill` SF Symbol 按钮, tooltip
+ /// = "新建项目". 装机 user 8/10 拍板 (V0-fix-1 Fix A 拍板沿用):
+ /// "标题栏全删, 用功能告诉用户" — 此 bar 不显示 panel 名 ("项目管理"),
+ /// 只显示 +, 让装机 user hover 看到 tooltip 才知作用 (= FCP toolbar 行为).
+ ///
+ /// **业务流 (新建项目实际 NavigationStack push 进 ProjectCreateView)**:
+ /// 由内嵌的 `ProjectListView` (Fix J §4 实现) 接管 — topLeftPanelWithTitleBar
+ /// 只负责视觉 title-bar chrome, 不持有 NavigationStack / sheet 容器.
+ /// ProjectListView 内部 Tab 1 (项目) 接收 + button 的 onCreate closure
+ /// (本 private var 通过 `onCreate: { ... }` 闭包传入), 内部走
+ /// NavigationStack push 进 ProjectCreateView.
+ ///
+ /// 注: 当前 V0-fix-2 只补视觉 chrome, **不**接 NavigationStack push
+ /// (避免越界改 v0.01.0 ProjectListView 的 navPath 接线 — 见 §0.4 第 6 条
+ /// + §3.4 关键约束). 装机 user 实机验时 + 按钮可见但无动作 (placeholder
+ /// no-op), 是 V0-fix-2 的拍板边界, 后续 WO-005 / LT-03 续接.
+ private var topLeftPanelWithTitleBar: some View {
+     VStack(spacing: 0) {
+         HStack(spacing: 0) {
+             Spacer(minLength: 0)
+             Button {
+                 // V0-fix-2 Fix I placeholder — no-op. ProjectListView
+                 // (Fix J §4) 上线后此按钮通过 onCreate 回调传入,
+                 // 在 ProjectListView 内部走 NavigationStack push.
+             } label: {
+                 Image(systemName: "plus.circle.fill")
+                     .font(.system(size: 16, weight: .medium))
+                     .foregroundStyle(.secondary)
+             }
+             .buttonStyle(.plain)
+             .help("新建项目")
+         }
+         .frame(height: 38)
+         .padding(.horizontal, 12)
+
+         Divider()
+
+         ProjectListView()   // Fix J §4: 5 tab 列表
+     }
+ }
```

### 3.4 关键约束

- **不动** LayoutShellView 5-zone geometry (上半 3 区 + 下半 2 区, 比例 / 折叠 / 拖拽全不变)
- **不动** LayoutShellViewModel (单例 + `snapshot` / `visibility` / `collapsed` / `load` / `adjustXxx` 全部不变)
- **不动** 4 个 NativeSplitter (上半 3 区 + 下半 1 区)
- **不动** PanelContainer (chrome-free, headerBar 已删)
- **不动** CollapsedGutter (collapsed 状态走被动 strip)
- **不动** PlaceholderContent (其他 3 panel 还用它)
- **不动** ProjectListView 的 @Binding 签名 (Fix J §4 保留 `projects: [ProjectSnapshot]` + `navPath: NavigationPath`)
- **不接** NavigationStack push (V0-fix-2 不动 AppRoute.createProject 路由, 留给后续 WO-005 / 拍板补)
- **不写** "等装机 user 验" / "review-required: 装机 user" 注释

### 3.5 不变量

- LayoutShellView 的 `panel(_:width:)` switch 分支结构保留 (`.topLeft` / `.bottomLeft` / `.topRight` / 其他)
- PanelContainer 的 `frame(width:)` 由 caller 控制 (Fix I 不改这层)
- 折叠态 (`isCollapsed(id)`) 走 `CollapsedGutter`, 不走 `topLeftPanelWithTitleBar`

---

## 4. Fix J: ProjectListView 重写 5 tab 容器 (左上 5 tab 列表)

### 4.1 拍板 (装机 user 8/10 15:35 OOB, AIF 推论)

> "**两次不符合规则**" — 装机 user 没说 BUG 9 详情. AIF 推论 = 左上 5 tab 列表消失.

**真根因** (§0.2 表 2): 当前 worktree 不带 v0.02.0 LT-03 v2 commit 3fab4fadc, `Sources/WenshuApp/Views/ProjectManagement/` 整目录 5 文件 + LayoutShellView 改用 `ProjectManagementView()` 都没落地. ProjectListView.swift 当前还是 v0.01.0 WO-004 → WO-010 单 tab 项目列表.

### 4.2 现状代码 (worktree 实际状态)

`Sources/WenshuApp/Views/ProjectListView.swift` line 1-120 (v0.01.0 现状, 单 tab):

```swift
struct ProjectListView: View {
    @Binding var projects: [ProjectSnapshot]
    @Binding var navPath: NavigationPath

    var body: some View {
        Group {
            if projects.isEmpty {
                emptyState
            } else {
                projectList
            }
        }
        .navigationTitle("项目")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { navPath.append(AppRoute.createProject) } label: {
                    Label("新建项目", systemImage: "plus")
                }
                .help("新建项目")
            }
        }
    }

    private var emptyState: some View { /* "暂无项目" / "点 + 新建" */ }
    private var projectList: some View { /* List { Section("项目(\\(count)") { ... } } */ }
    // ...
}
```

注: 现有的 `+ 新建项目` 按钮在 ProjectListView 自己的 `.toolbar` 内 (跟 v-fix-1 Fix I 的 title-bar `+` 按钮**重复**). Fix J §4.3 要**删**这个 toolbar `+` 按钮 (按 §0.4 第 7 条合并为 1 个).

### 4.3 改动契约 (整文件重写)

**唯一文件**: `Sources/WenshuApp/Views/ProjectListView.swift` (整文件改写, 不新建 ProjectManagement/ 目录, 按 §0.4 第 6 条派单拍板)

```swift
// ProjectListView.swift · 文枢 (Wenshu) · v0.01.0 WO-004 → v0.02.0 LT-03 v2 → v0.03.0 V0-fix-2 (Fix J)
//
// 左上 panel 内容容器 — 5 tab 根 (沿用 v0.02.0 LT-03 v2 设计, 派单 §0.4
// 第 6 条拍板 "改写 ProjectListView, 不新建 ProjectManagement/ 目录").
//
// 5 tab:
//   1. 项目    — list + create (实装, NavigationStack push)
//   2. 章节    — chapter tree (NavigationStack push 章节详情)
//   3. 设定    — 占位, "v0.04.0 实现" (LT-03 v2 placeholder 沿用)
//   4. 资料    — 占位, "v0.04.0 实现"
//   5. 看板    — 占位, "v0.04.0 实现"
//
// V0-fix-2 Fix J 改动:
//   - 新增 `ProjectManagementTab` enum (case 5 + symbolName 5 + isImplemented + placeholder)
//   - Picker.segmented 5 tab 容器 (跟 ChatPanelView 4 子 tab 同形态)
//   - 5 个 Tab 内容 (内嵌 private struct, 不放独立文件)
//   - **删** 现有 `.toolbar { Button("新建项目", ...) }` (跟 Fix I title-bar
//     + 按钮重复, 按 §0.4 第 7 条合并为 1 个)
//
// 拍板边界:
//   - **不**新建 ProjectManagement/ 目录 (5 tab 内容放 ProjectListView 内部)
//   - **不**接 + 按钮实际 NavigationStack push (Fix I 占位 no-op, 留给后续)
//   - **不**动 @Binding projects / @Binding navPath 签名 (避免越界改 v0.01.0 路由)
//   - Tab 1 走现有 `projectList` (空态 / 列表 / 行), Tab 2-5 占位

import SwiftUI

enum ProjectManagementTab: String, CaseIterable, Identifiable {
    case projects = "项目"
    case chapters = "章节"
    case settings = "设定"
    case resources = "资料"
    case kanban = "看板"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .projects: return "folder"
        case .chapters: return "list.bullet.rectangle"
        case .settings: return "slider.horizontal.3"
        case .resources: return "books.vertical"
        case .kanban: return "rectangle.split.3x1"
        }
    }

    /// Tab 1 + 2 实装 (沿用 LT-03 v2), Tab 3-5 占位 v0.04.0
    var isImplemented: Bool {
        switch self {
        case .projects, .chapters: return true
        case .settings, .resources, .kanban: return false
        }
    }

    var placeholder: String {
        switch self {
        case .projects: return ""
        case .chapters: return ""
        case .settings: return "v0.04.0 实现"
        case .resources: return "v0.04.0 实现"
        case .kanban: return "v0.04.0 实现"
        }
    }
}

struct ProjectListView: View {
    @Binding var projects: [ProjectSnapshot]
    @Binding var navPath: NavigationPath

    /// 默认 tab = 项目 (沿用 LT-03 v2 拍板)
    @State private var activeTab: ProjectManagementTab = .projects

    var body: some View {
        VStack(spacing: 0) {
            // V0-fix-2 Fix J: 5 tab 根 Picker.segmented (沿用 LT-03 v2 范式,
            // 跟 ChatPanelView 4 子 tab 同形态). 这里**不**走 .iconOnly —
            // 装机 user 8/10 拍板 "5 tab 用 segmented 文字标签" (LT-03 v2
            // 拍板边界), 跟 4 chat tab + 2 inspector tab 风格刻意区分
            // (项目列表需要用户看清 5 类, chat/inspector 是频繁切换).
            Picker("", selection: $activeTab) {
                ForEach(ProjectManagementTab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.symbolName)
                        .tag(tab)
                        .disabled(!tab.isImplemented)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            Group {
                switch activeTab {
                case .projects:
                    projectListTab
                case .chapters:
                    chapterTreeTab
                case .settings:
                    placeholderTab(for: .settings)
                case .resources:
                    placeholderTab(for: .resources)
                case .kanban:
                    placeholderTab(for: .kanban)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Tab 1: 项目 (实装, 沿用 v0.01.0 projectList + emptyState)

    private var projectListTab: some View {
        Group {
            if projects.isEmpty {
                emptyState
            } else {
                projectList
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.secondary)
            Text("暂无项目")
                .font(.title2)
            Text("点 + 新建")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var projectList: some View {
        List {
            Section("项目(\(projects.count))") {
                ForEach(projects) { project in
                    Button {
                        navPath.append(AppRoute.chat(project))
                    } label: {
                        projectRow(project)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listStyle(.inset)
    }

    private func projectRow(_ project: ProjectSnapshot) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                HStack(spacing: 8) {
                    Text(project.style)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("注水 \(project.verbosity)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !project.tags.isEmpty {
                        Text(project.tags.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer()
            Text(formattedDate(project.createdAt))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    // MARK: - Tab 2: 章节 (占位, mock 章节树)

    private var chapterTreeTab: some View {
        VStack(spacing: 10) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.tertiary)
            Text("章节树 v0.04.0 实现")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Tab 3-5: 占位 (v0.04.0)

    private func placeholderTab(for tab: ProjectManagementTab) -> some View {
        VStack(spacing: 10) {
            Image(systemName: tab.symbolName)
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.tertiary)
            Text(tab.placeholder)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .disabled(true)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
```

### 4.4 关键约束

- **不动** @Binding projects: [ProjectSnapshot] 签名
- **不动** @Binding navPath: NavigationPath 签名
- **不动** `AppRoute.createProject` / `AppRoute.chat(project)` 路由 (v0.01.0 WO-010 拍板)
- **不动** ProjectSnapshot struct (WenshuApp CoreData 镜像)
- **不动** v0.02.0 main 业务逻辑 / WenshuStoreActor / .ws schema / Package.swift
- **不**新建 ProjectManagement/ 子目录 (5 Tab 内容放 ProjectListView 内 private var / private func)
- **不**接 + 按钮 NavigationStack push (Fix I 占位 no-op)
- **不**写 "等装机 user 验" / "review-required: 装机 user" 注释

### 4.5 不变量

- `ProjectManagementTab` enum 5 case (`projects` / `chapters` / `settings` / `resources` / `kanban`) 沿用 LT-03 v2
- 5 SF Symbol (`folder` / `list.bullet.rectangle` / `slider.horizontal.3` / `books.vertical` / `rectangle.split.3x1`) 沿用 LT-03 v2
- Tab 3-5 占位文案 ("v0.04.0 实现") 沿用 LT-03 v2
- 默认 `activeTab = .projects` 沿用 LT-03 v2
- Tab 1 (`projects`) 实装 — 沿用 v0.01.0 `projectList` + `emptyState` + `projectRow`
- Tab 2-5 占位 v0.04.0 (按 LT-03 v2 拍板)

---

## 5. 拍板历史汇总

| 日期 | 工单 / Commit | 拍板 | 文件 |
|------|---------------|------|------|
| 2026-08-06 | v0.00.0 | 项目基线 (Swift/SwiftUI + CoreData + minimax cn LLM) | AGENTS.md |
| 2026-08-07 | v0.02.0 LT-03 v2 | 左上项目管理 5 tab 拍板 (ProjectsView 实际落地) | Sources/Views/ProjectManagement/*.swift (本 branch 不带) |
| 2026-08-07 | LT-01-fix5 | 删 H1 标题栏, "用功能告诉用户" | PanelContainer / PlaceholderContent |
| 2026-08-07 | LT-01-fix3 | per-panel chevron 改 View menu | App.swift |
| 2026-08-07 | WO-010 | ProjectCreateView 改 NavigationStack push | ProjectListView / ProjectCreateView |
| 2026-08-07 | WO-LT-04 | 下左 chat 4 子 tab (1 实装 + 3 disabled) | ChatPanelView.swift |
| 2026-08-07 | WO-LT-02-v2 | 右上 inspector 2 tab (伏笔 + 修订) | InspectorView / InspectorViewModel |
| 2026-08-10 | V0-fix-1 (commit 1512a68d3) | 6 处 UI FCP-ification fix (本 branch 不带) | LayoutShellView / ChatPanelView / ProjectCreateView / DESIGN-V0-fix-1.md / V0Fix1LayoutTests |
| **2026-08-10** | **V0-fix-2 (本卡)** | **真修 4 处漏 UI (Fix G/H + Fix I + Fix J) — 装机 user 8/10 15:30 + 15:35 实机拍** | **LayoutShellView / ChatPanelView / InspectorView / ProjectListView / DESIGN-V0-fix-2.md / V0Fix2LayoutTests** |

---

## 6. 验收标准 (DOA)

### 6.1 单元测试 (`Tests/WenshuAppTests/V0Fix2LayoutTests.swift`, 4 个 test)

4 个 test 必须全 pass (= 跟 V0Fix1LayoutTests 7 个 test 合并 = 11 个 test 全 pass):

| Test | 拍板 | 断言 |
|------|------|------|
| `testChatPanelView_4chatTabs_iconOnlyStyle` | Fix G | ChatPanelView.swift 含 `.pickerStyle(.iconOnly)`, 不含 `.pickerStyle(.segmented)` |
| `testInspectorView_2inspectorTabs_iconOnlyStyle` | Fix H | InspectorView.swift (strip 注释后) 含 `.pickerStyle(.iconOnly)`, 不含 `.pickerStyle(.segmented)`, 含 `Image(systemName:` (不在注释里), 含 `eye` + `pencil.and.list.clipboard`, 不含 `Text(tab.title)` 在 Picker 块, 不含 `Text("检视")` |
| `testLayoutShellView_topLeftHeaderBar_hasPlusButton` | Fix I | LayoutShellView.swift 含 `topLeftPanelWithTitleBar` private var + 38pt HStack + `plus.circle.fill` + `.help("新建项目")` |
| `testProjectListView_5tabList_present` | Fix J | ProjectListView.swift 含 5 个 tab 字面量 (`项目` / `章节` / `设定` / `资料` / `看板`) + `ProjectManagementTab` enum + 5 SF Symbol (`folder` / `list.bullet.rectangle` / `slider.horizontal.3` / `books.vertical` / `rectangle.split.3x1`) + Picker `.segmented` (5 tab 用文字标签, 不走 .iconOnly) |

**helper 沿用 V0Fix1LayoutTests 的 `repoFile` + `stripSwiftComments`** — 复制到 V0Fix2LayoutTests.swift (XCTest 不跨文件共享 private func, 必须复制; helper 完全相同 ≈ 30 行).

### 6.2 编译 + 全测试

```bash
$ swift build
Build complete!

$ swift test
... (worktree 不带 V0-fix-1 commit, V0Fix1LayoutTests 不存在; 现有 ~20 测试全 pass + V0Fix2LayoutTests 4/4 pass)
Test Suite 'V0Fix2LayoutTests' passed
    Executed 4 tests, with 0 failures (0 unexpected)
```

注: 当前 worktree `wt/t_29d24bd7` 从 main `492c96750` 拉出, **不带** V0-fix-1 commit 1512a68d3 和 V0-fix-2 commit cfce73389. V0Fix1LayoutTests 不在本 worktree, 不归 V0-fix-2 管. CC 接力时若想跑 V0Fix1LayoutTests 验证, 需先 cherry-pick v-fix-1 commit (在 commit message 注释里写 "v-fix-1 cherry-pick" 即可, 不算业务改动).

### 6.3 Git 契约

- branch 唯一: `wt/t_29d24bd7` (派单 body 拍板, 沿用本 worktree 分支)
- commit 单一: 4 处 UI 修 + 4 个新 test + 1 个新设计文档 1 commit
- commit message:
  ```
  v0.03.0 V0-fix-2: 真修 4 处漏 UI (聊天区视图 H1 + 4 chat tab .iconOnly
    + 右上 inspector ICON-only + 顶部 + 按钮 + 左上 5 tab 列表)
    — 装机 user 8/10 15:30 + 15:35 实机拍
  ```
- push 双重: `git push origin` AND `git push old-origin`
- 不 push --force, 不 push 到 main, 不 amend 别人 commit

### 6.4 PM-direct 验收

PM-direct 在 macOS 跑 `swift run WenshuApp`:

1. **Fix G**: 下左 chat 4 tab ICON-only (bubble.left / clock / person.2 / list.bullet.rectangle), 无 "聊天区视图" H1, 文字 hover 才出 tooltip
2. **Fix H**: 右上 inspector 2 tab ICON-only (eye / pencil.and.list.clipboard), 无 "检视" H1, 文字 hover 才出 tooltip
3. **Fix I**: 左上 panel 顶部 38pt title-bar 有 "+ 新建项目" 按钮, hover 出 tooltip "新建项目"
4. **Fix J**: 左上 panel 5 tab 列表 (项目 / 章节 / 设定 / 资料 / 看板), 文字标签 + SF Symbol, Tab 1 显项目列表 (或空态), Tab 2-5 占位 "v0.04.0 实现"

### 6.5 不验收项

- 装机 user 实机验 → 不在 V0-fix-2 范围, 装机 user 出 loop, PM-direct 兜底
- 不写 "review-required: zhuang-ji user" / "等 zhuang-ji user 拍" / "zhuang-ji user 实机验" 注释
- + 按钮实际 NavigationStack push 进 ProjectCreateView → 留给后续 WO-005 / LT-03 续接, V0-fix-2 占位 no-op
- AppRoute.createProject 路由接线 → 不动, 现有 v0.01.0 WO-010 拍板保留

### 6.6 后续工单

- 5-zone 快捷键可视化 (Cmd+1…5 已经在 App.swift CommandMenu, 下一步把快捷键放 View menu 文案后面)
- v0.03.0 阶段门 (想法讨论 → 设定 → 大纲 → 正文, AI 判断成熟度)
- Fix I + 按钮接 NavigationStack push (WO-005 / LT-03 续接, V0-fix-2 占位 no-op)

---

## Appendix A — 文件改动摘要

```
modified  Sources/WenshuApp/Views/Layout/LayoutShellView.swift   (Fix I: 加 topLeftPanelWithTitleBar + .topLeft 改用)
modified  Sources/WenshuApp/Views/Chat/ChatPanelView.swift       (Fix G: Picker a11y 改 "" + Label→Image + .segmented→.iconOnly)
modified  Sources/WenshuApp/Views/Inspector/InspectorView.swift  (Fix H: 删 selfHeader + Picker a11y 改 "" + Text→Image + .segmented→.iconOnly + 加 iconName(for:))
modified  Sources/WenshuApp/Views/ProjectListView.swift          (Fix J: 重写 5 tab 容器, 删原 .toolbar + button)
new       Sources/WenshuApp/Views/DESIGN-V0-fix-2.md             (本文件)
new       Tests/WenshuAppTests/V0Fix2LayoutTests.swift           (Fix G + H + I + J 4 个 test)
```

5 文件 (3 改 + 2 新), 1 commit, 2 pushes (origin + old-origin).

## Appendix B — 跟前一个 designer session (cfce73389) 的差异

前一个 designer session (commit cfce73389) 只覆盖 Fix G + H (15:30 BUG), 装机 user 15:35 报的 Fix I + J 是本 session 增量补上:

| 项 | 前 session (cfce73389) | 本 session (t_29d24bd7) |
|---|------------------------|------------------|
| 范围 | Fix G + Fix H (15:30 BUG 2 处) | Fix G + Fix H + Fix I + Fix J (15:30 + 15:35 BUG 4 处) |
| DESIGN-V0-fix-2.md 行数 | 438 行 | ~500 行 (新增 §3 + §4 + §5 + Appendix B) |
| V0Fix2LayoutTests test 数 | 2 (testChatPanelView + testInspectorView) | 4 (新增 testLayoutShellView + testProjectListView) |
| 新文件 | DESIGN-V0-fix-2.md + V0Fix2LayoutTests.swift | 同 2 文件 (内容扩展) |
| 改文件 | ChatPanelView.swift + InspectorView.swift | 同 2 文件 + 新增 LayoutShellView.swift + ProjectListView.swift |

## Appendix C — 关键边界 (designer 不跨进 CC 领域)

designer 出完稿, CC 实现边界:
- ✅ 改 LayoutShellView.swift (Fix I, 加 topLeftPanelWithTitleBar)
- ✅ 改 ChatPanelView.swift (Fix G)
- ✅ 改 InspectorView.swift (Fix H)
- ✅ 改 ProjectListView.swift (Fix J, 整文件重写)
- ✅ 跑 swift build / swift test 验证
- ✅ git commit on wt/t_29d24bd7 branch
- ✅ push origin + push old-origin
- ✅ 调 kanban_complete 协议接口

designer 不做 (CC 责任):
- ❌ 改 v0.02.0 main 业务逻辑 (WenshuStoreActor / .ws schema / AppRoute.createProject 路由)
- ❌ 改 Package.swift / Info.plist / WenshuApp.entitlements
- ❌ 改 LT-01-fix 系列代码 (5-zone layout 拍板已落档, V0-fix-2 不动)
- ❌ 接 + 按钮 NavigationStack push (留给后续 WO-005, V0-fix-2 占位 no-op)
- ❌ 写 "等装机 user 验" / "review-required: 装机 user" 注释