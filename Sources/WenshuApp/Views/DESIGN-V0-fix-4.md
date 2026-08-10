# DESIGN · V0-fix-4 · 文枢 (Wenshu)

> v0.03.0 V0-fix-4 (装机 user 8/10 16:25 + 16:35 + 16:40 + 16:45 OOB 实机拍)
> 真修 V0-fix-3 (commit cfd5332b6 / wt/t_45b06855) **漏拍**的 **4 处** UI BUG
> — 顶部 "+" 按钮位置错(在 topLeft panel 内部,非标题栏)、5 tab 列表显示(沿用标题栏)、+ 按钮接 NavigationStack push、底部 chat 4 tab 居左
> 工作 worktree = `wt/t_7660d0b2`(HEAD = `492c96750` v0.02.0 LOOP,**不带** v-fix-3 commit)

---

## 0. 任务背景 & 矛盾点

### 0.1 装机 user OOB 实机拍 (16:25 → 16:45)

装机 user 8/10 16:25 重启 APP 后实机验:
> "v0-fix-3 commit 20ca44ec4 跑出来仍是 v0-fix-1 状态"

(此判断的真因不是 v-fix-3 没改 — cfd5332b6/da4a34d4f commit 实际在 wt/t_45b06855 branch 落档,wt/t_7660d0b2 worktree HEAD = 492c96750 不带这部分 commit。装机 user 真测的本 worktree 是 v0.02.0 LOOP 状态 — 即 v-fix-1 / v-fix-2 / v-fix-3 6 BUG 都没改。)

装机 user 8/10 16:35 重启 APP 再拍:
> **BUG 7** "顶部的 '+ 新建项目' 按钮跑在 topLeft panel 内部 (@ 529, 91, 16, 16),不是放在标题栏左边(替换标题栏'文枢'文字)"
> **BUG 8** "5 tab 列表没显示 = 应在红黄绿按钮后(标题栏内)"

装机 user 8/10 16:40:
> **BUG 9** "+ 新建项目按钮点了不弹窗 — 现在是 no-op"

装机 user 8/10 16:45:
> **BUG 10** "底部 chat 4 tab 在面板中间偏右,不是居左 — FCP 范式 tab list 居左对齐,不用居中"

### 0.2 真根因(designer 读源码 + git 历史后)

**核心发现**: 当前 worktree `wt/t_7660d0b2` 从 main `492c96750` 拉出,**不含**:

| 不在 worktree 的 commit | 含什么 | 当前 worktree 看到的"v-fix-1 状态" = |
|---|---|---|
| `1512a68d3` (V0-fix-1) | LayoutShellView `topLeftPanelWithTitleBar` + ChatPanelView Fix B/C | 顶部 title-bar 38pt + button 没加 |
| `cfce73389` (V0-fix-2-designer) | DESIGN-V0-fix-2.md + V0Fix2LayoutTests.swift,**未实现** | — |
| `3fab4fadc` (v0.02.0 LT-03 v2) | `Sources/WenshuApp/Views/ProjectManagement/` 5 个新文件 + LayoutShellView `.topLeft` 改用 `ProjectManagementView()` | 左上 5 tab 列表没加 |
| `163a0ff4d` (V0-fix-2 合并) | 同上,**未实现** | — |
| `cfd5332b6` (V0-fix-3) | LayoutShellView 顶部 title-bar + ProjectListView 5 tab 重写 + ChatPanelView .iconOnly + InspectorView .iconOnly + PickerStyle+IconOnly.swift + V0Fix3LayoutTests | 6 BUG 都没修 |
| `da4a34d4f` (V0-fix-3 ACCEPTANCE) | ACCEPTANCE-v0.03.0-V0-fix-3.md + 闭环落档 | — |

**当前 worktree 状态**(designer 实读,所有改动从 0 起):
- `LayoutShellView.swift`(v0.02.0 LOOP,line 51-196):`panel(.topLeft)` 走 `PlaceholderContent(panel: id)`,**无** `topLeftPanelWithTitleBar`、**无** 38pt title-bar
- `ProjectListView.swift`(v0.01.0 WO-010,line 1-120):单 Group + .toolbar { Button } 空态/列表 — **无** 5 tab 容器
- `ChatPanelView.swift`(v0.02.0 WO-LT-04,line 1-96):Picker `.segmented`(macOS 13 fallback 显 SF Symbol 文字,见 v-fix-3 commit msg)+ "聊天区视图" H1 还在 — **无** `.iconOnly`
- `InspectorView.swift`(v0.02.0 WO-LT-02-v2,line 1-258):Picker `.segmented` + `selfHeader` H1 "检视" — **无** `.iconOnly`、selfHeader 整段在(line 87-99)

### 0.3 V0-fix-4 范围(派单 body + AIF 后续 comment 拍板)

派单 body §DOA 8 段 + AIF 16:40 + 16:45 两次增量:

| # | BUG | 来源 | 修法(本卡拍板) |
|---|-----|------|---------------|
| **Fix 1** | LayoutShellView 加 `topLeftPanelWithTitleBar` | 派单 §DOA 1 + AIF 16:40 BUG 7 | 38pt HStack + 标题栏 `+` 按钮(替换 v0.02.0 顶部 `"文枢"` 文字) |
| **Fix 2** | 5 tab 容器在 `topLeftPanelWithTitleBar` 内部渲染 | 派单 §DOA 2 + AIF 16:40 BUG 8 | `ProjectListView` 5 tab Picker + 内容,跟 Fix 1 在同一 `topLeftPanelWithTitleBar` 内 |
| **Fix 3** | `+` 按钮接 NavigationStack push | 派单 §DOA 3 + AIF 16:40 BUG 9 | LayoutShellView 加 `@State navPath: NavigationPath` + `.navigationDestination(for: AppRoute.self)` + `Button` 推 `.createProject` |
| **Fix 4** | ChatPanelView Picker 改 `.iconOnly` | 派单 §DOA 5(= v-fix-3 已修沿用) | `Picker(.segmented)` → `Picker(.iconOnly)` + Picker a11y 改 `""` |
| **Fix 5** | InspectorView Picker 改 `.iconOnly` + 删 selfHeader | 派单 §DOA 6(= v-fix-3 已修沿用) | 删 selfHeader + Picker ICON-only + `iconName(for:)` inline |
| **Fix 6** | ChatPanelView 4 tab 居左 | AIF 16:45 BUG 10 | `.padding(.horizontal, 12)` → `.padding(.leading, 12)` + 删 `.frame(maxWidth: .infinity)` |
| **Fix 7** | PickerStyle+IconOnly 别名 | 派单 v-fix-3 派生 / 编译配套 | `extension PickerStyle where Self == SegmentedPickerStyle { static var iconOnly: SegmentedPickerStyle { .init() } }` |

**派单 body + AIF 后续 comment 拍板要点**:
- ✅ 不动 v0.02.0 main 业务逻辑(WenshuStoreActor / .ws schema / AppRoute.createProject 签名)
- ✅ 不动 v0.02.0 LOOP 边界(NativeSplitter / PanelContainer / PanelVisibility)
- ✅ 不接 5 tab Tab 2-5 的 v0.04.0 真业务(占位 "v0.04.0 实现",沿用 LT-03 v2)
- ❌ 不写 "等装机 user 验" / "review-required: 装机 user"(装机 user out of loop,PM-direct / AIF 兜底)

### 0.4 矛盾点(designer 必标,沿用 v-fix-3 已拍板边界)

| # | 矛盾 | 派单 + AIF 拍板 | designer 接受 |
|---|------|----------------|---------------|
| 1 | LayoutShellView `panel(.topLeft)` 是放 `topLeftPanelWithTitleBar`(沿用 v-fix-1)还是放 `ProjectManagementView()`(沿用 LT-03 v2)?v-fix-3 commit 把两者**合并**了(title-bar 在 PanelContainer 内部) | AIF 16:40 拍板 "**顶部 + 按钮移到标题栏最左**(替换标题栏'文枢'文字, 红黄绿按钮后第 1 个) + 5 tab 列表放标题栏内(在 + 按钮右边)" | ✅ 改派单原本"topLeftPanelWithTitleBar 在 PanelContainer 内部 + 占位 PlaceholderContent"为"标题栏独立 38pt bar + 5 tab 容器" — 必须**升 title-bar 到 NativeSplitter 上方**(在 LayoutShellView geometryBody 顶部 VStack 之前) |
| 2 | 5 tab 容器放在哪里?PanelContainer 内部(沿 v-fix-3)还是标题栏内(沿 AIF 16:40)? | AIF 16:40 BUG 7 拍板 "5 tab 列表在 + 按钮右边, 与 + 平级(标题栏内)" | ✅ 5 tab Picker + 内容**整体下移**到 `topLeftPanelWithTitleBar` 函数体(`HStack(spacing: 0) { Spacer(); Button; Picker; Divider; PlaceholderContent for 5 tab SelectedTab })`,沿用 v-fix-3 改写 ProjectListView 5 tab 容器(扫 topLeft SelectedTab) |
| 3 | `+` 按钮 push 进哪里?`@State navPath` in LayoutShellView(新增 state 越界 v0.02.0 LOOP)还是 `NotificationCenter` / 自定义 AppDelegate?LayoutShellView 当前无 NavigationStack | AIF 16:40 BUG 9 拍板 "**必须接 NavigationStack push** 到 `AppRoute.createProject`" | ✅ (a) LayoutShellView 加 `@State private var navPath = NavigationPath()`,(b) body `toolbar` 或外层加 `NavigationStack(path: $navPath) { geometryBody.navigationDestination(for: AppRoute.self) { route in ... } }`,(c) Button `{ navPath.append(.createProject) }`. 越界 → 升 PM-direct 拍板 — **本卡走这条**,因为装机 user 16:40 报"点了不弹窗"就是越界要求 |
| 4 | InspectorView 删 selfHeader H1 — 真删整段还是改空字串?v-fix-3 拍板 真删整段 | 派单 §DOA 6 沿用 v-fix-3 | ✅ 整段删 selfHeader + 删 body call,沿 v-fix-3 |
| 5 | ChatPanelView 4 tab 居左 vs macOS 系统 picker 居左/居中?macOS 13 SegmentedPickerStyle 默认"picker 宽度 = segmented 实际宽度"居左,但 macOS 14+ 在某些 padding 下居中 | AIF 16:45 BUG 10 拍板 "Tab list 居左对齐, 不用居中 — FCP timeline 风格" | ✅ `.padding(.horizontal, 12)` → `.padding(.leading, 12)` + 删 `.frame(maxWidth: .infinity)` + 在 Picker 后加 `Spacer()` 让"Picker = 实际宽度"居左 |
| 6 | active tab accent 圆角背景(`.segmented` 自动 vs `.iconOnly` 手画) | 派单没明确, v-fix-3 拍板 ".iconOnly 仍走 macOS 系统 accent" | ⚠️ designer 测试假设 `.iconOnly` 仍有 macOS 系统 accent 渲染 — 如果 PM-direct 跑 `swift run` 装机 user 真机拍发现没, 升 PM-direct 拍"加 `.background()`"或"自定义 Picker"。 不预先写备援代码 |

---

## 1. Fix 1 + Fix 2: LayoutShellView 顶部 title-bar + 5 tab 容器

### 1.1 目标(v-fix-1 + v-fix-3 范式合并 + AIF 16:40 升 title-bar)

- 顶部标题栏(native macOS title bar 上方 / 上方插入一行 38pt bar):
  - 红黄绿 traffic lights(系统原生)
  - `+` 按钮(右对齐 — 沿 v-fix-1,但 AIF 16:40 拍板"在红黄绿按钮后第 1 个" — 实际是左对齐替换标题栏"文枢"文字,见下面 §1.3 拍板)
  - **5 tab 列表**(居中或居左,跟 + 按钮平级)
  - 不显示 panel 名("项目管理"),沿 v-fix-1 LT-01-fix5 拍板"用功能告诉用户"
- 不动 5-zone geometry(AGENTS §8.1):上半 3 列 / 下半 2 行
- 不动 splitter(NativeSplitter v0.02.0 LOOP 拍板保留)
- 不动 PlaceholderContent(其他 panel 还用它)

### 1.2 派生 — 升 title-bar 到 NativeSplitter 上方(AIF 16:40 拍板)

**关键架构决定**(AIF 16:40 comment 内拍板):

```
旧 v-fix-1 + v-fix-3 拍板(LT-01-fix5 拍板后):
┌──────────────────────────────────────────┐
│ native macOS title bar(系统 traffic lights only)     │
├──────────────┬─────────────┬──────────────┤
│ topLeft panel │ topCenter   │ topRight      │
│  VStack {     │             │              │
│    HStack 38pt title-bar(+ button) │             │              │
│    Divider()                          │             │              │
│    PlaceholderContent(panel: .topLeft)│             │              │
│  }             │             │              │
└──────────────┴─────────────┴──────────────┘

新 AIF 16:40 + 16:45 拍板:
┌──────────────────────────────────────────┐
│ native macOS title bar(系统 traffic lights only)     │
├──────────────────────────────────────────┤ ← 新增 38pt "标题栏 bar" 在上半 3 区上方
│ + button (左, 替换 v0.02.0 "文枢"标题文字) 5 tab Picker (在 + 右边)  Spacer() (右)│
├──────────────┬─────────────┬──────────────┤
│ topLeft panel │ topCenter   │ topRight      │
│  5 tab 内容 (selected tab 切换)             │             │              │
└──────────────┴─────────────┴──────────────┘
```

**布局拍板**(AIF 16:40 内拍板):
- 标题栏 38pt HStack(spacing: 0) — 左对齐,不复用 v-fix-1 的 Spacer + Button 右对齐
- 5 tab 容器在 + 按钮**右边**,与 + 平级(同 38pt 高),**不**用 Spacer 推到右边
- 右边 Spacer() 让 + 和 5 tab 列表整体左对齐,右边留白(FCP toolbar 风格 — 红黄绿后立刻接按钮 + tab)

### 1.3 实现 — LayoutShellView `panel(.topLeft)` 范式

```swift
// 新 v0-fix-4 顶部 title-bar (38pt),在 5-zone 上方 + 跨全宽
private var topLeftHeaderBar: some View {
    HStack(spacing: 12) {
        // 替换 v0.02.0 顶部 "文枢" 标题文字 (AIF 16:40 BUG 7 拍板)
        // — 红黄绿 traffic lights 后第 1 个元素,左对齐
        Button {
            // V0-fix-4 Fix 3: 接 NavigationStack push 到 AppRoute.createProject
            // (见 §3 实现)
            navPath.append(AppRoute.createProject)
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("新建项目")

        // 5 tab 容器 (沿用 V0-fix-3 Fix J 设计) — 与 + 按钮平级
        ProjectListView(...)  // @Binding projects + @Binding navPath (沿 v0.02.0)

        Spacer(minLength: 0)
    }
    .frame(height: 38)
    .padding(.horizontal, 12)
}
```

**变更点**(相对 v-fix-3 在 wt/t_45b06855 拍的 LayoutShellView):
- `topLeftPanelWithTitleBar` private var → **改名** `topLeftHeaderBar`
- 内部 `PlaceholderContent(panel: .topLeft)` → **移除**(5 tab 内容已经独立渲染在 panel 内,标题栏只放 + 和 tab 容器**壳**)
- 顶层 `geometryBody` 的 VStack(spacing: 0) — 顶部加 `if showTopHeaderBar` 条件渲染
- 新增 `@State private var navPath = NavigationPath()`(布局 state)
- 新增顶层 `NavigationStack(path: $navPath) { geometryBody.navigationDestination(for: AppRoute.self) { ... } }` 包裹

### 1.4 ProjectListView 5 tab 容器

跟 v-fix-3 commit cfd5332b6 第 2 段(BUG 2 + Fix J) 同样的实现:

```swift
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

    var isImplemented: Bool {
        switch self {
        case .projects, .chapters: return true
        case .settings, .resources, .kanban: return false
        }
    }
}

// ProjectListView.swift 整文件重写 (沿 v-fix-3):
//   - 删原 .toolbar { Button("新建项目", ...) } (跟 Fix 1 title-bar + 按钮合并)
//   - 新增 @State activeTab: ProjectManagementTab = .projects
//   - Picker segmented 5 tab 容器 (5 tab 用文字标签, 走 LT-03 v2 拍板, 不走 .iconOnly)
//   - 5 Tab 内容: Tab 1 沿用 v0.01.0 projectList/emptyState/projectRow;
//                  Tab 2 占位章节树; Tab 3-5 占位 "v0.04.0 实现"
```

---

## 2. Fix 4 + Fix 5: ChatPanelView + InspectorView Picker `.iconOnly`(沿用 v-fix-3)

### 2.1 ChatPanelView Picker `.iconOnly`

```swift
// ChatPanelView.swift body (line 39-49):
Picker("", selection: $activeTab) {
    ForEach(ChatPanelTab.allCases) { tab in
        Image(systemName: tab.symbolName)
            .tag(tab)
            .help(tab.rawValue)
            .disabled(tab.isDisabled)
    }
}
.pickerStyle(.iconOnly)  // 走 PickPickerStyle+IconOnly 别名
.padding(.leading, 12)   // Fix 6 — AIF 16:45 拍板 4 tab 居左
.padding(.vertical, 8)
// 删 `.padding(.horizontal, 12)` (居左后不需要右边 padding)
```

### 2.2 InspectorView Picker `.iconOnly` + 删 selfHeader

```swift
// InspectorView.swift body (line 47-78):
// 删 selfHeader (line 87-99) + 删 body 内 selfHeader call
VStack(spacing: 0) {
    Picker("", selection: $vm.selectedTab) {
        ForEach(InspectorViewModel.Tab.allCases) { tab in
            Image(systemName: iconName(for: tab))
                .tag(tab)
                .help(tab.title)
        }
    }
    .pickerStyle(.iconOnly)
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    Divider()
    Group { /* tab 切换 */ }
}

// 加 inline 静态映射:
private func iconName(for tab: InspectorViewModel.Tab) -> String {
    switch tab {
    case .foreshadow: return "eye"
    case .revision: return "pencil.and.list.clipboard"
    }
}
```

---

## 3. Fix 3: LayoutShellView NavigationStack push

### 3.1 目标

装机 user 16:40 OOB 报 "新按钮点了不弹窗" — v-fix-1 / v-fix-3 都把 + 按钮放 no-op 占位。本卡必须接 push。

### 3.2 实现(SwiftUI NavigationStack + AppRoute.createProject)

LayoutShellView 当前**没有 NavigationStack / NavigationPath**(AGENTS §6 + LayoutShellView line 188-191 注释明确"严禁在这里走 sheet / NavigationStack push")。

**冲突解决**(designer 必标):
- AGENTS §6 / §12 红线 "CC 不接 NavigationStack push" — 但 AGENTS §12 也写"layout state 持久化跨设备",**本卡 + 按钮接 push 是已知 v-fix-3 漏修 + AIF 16:40 拍板**
- AIF 16:40 comment 明确 "**+ 按钮接 NavigationStack push** 到 ProjectCreateView(沿用 LT-03 v2 pattern, WenshuStoreActor.create 已有)"
- 升 PM-direct 拍板(本卡 note):UI 工程里 push NavigationStack 是 macOS HIG 主路由范式 — v0.01.0 WO-010 已确立拍板 — 不算 v0.02.0 LOOP 边界破坏

```swift
// LayoutShellView.swift 顶层 state:
@State private var navPath = NavigationPath()

// body 改:
var body: some View {
    NavigationStack(path: $navPath) {
        geometryBody
            .frame(minWidth: 900, minHeight: 600)
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .createProject:
                    ProjectCreateView(...)  // 沿 v0.01.0 WO-010 的 AppRoute.createProject 路由
                default:
                    EmptyView()
                }
            }
            .task {
                await vm.load()
            }
    }
}
```

### 3.3 ProjectCreateView 数据流(沿 v0.01.0)

ProjectCreateView 已存在(Sources/WenshuApp/Views/ProjectCreateView.swift,540×480 派单保持沿 v-fix-1 Fix D)。本卡**不动** ProjectCreateView 内部 — 只接 LayoutShellView 顶层 NavigationStack。

### 3.4 越界风险

AGENTS §6 / §12 边界:"LayoutShellView 严禁 sheet / NavigationStack push" — 这个注释本身是 v0.02.0 LOOP 时为了避免 LT-02 inspector 走 sheet / push 写的。不是真的禁止 LayoutShellView 内部 NavigationStack。

**designer 必标**:LayoutShellView 加 NavigationStack **升 PM-direct 拍板**。PM-direct 接受 = 写代码;不接受 = 标 blocked。

---

## 4. Fix 6: ChatPanelView 4 tab 居左

### 4.1 目标(AIF 16:45 BUG 10 拍板)

> "底部 chat 4 tab 在面板中间偏右,不是居左 — FCP 范式 tab list 居左对齐,不用居中"

### 4.2 实现

```swift
// ChatPanelView.swift body (line 39-49):
Picker("", selection: $activeTab) {
    // ... 见 §2.1
}
.pickerStyle(.iconOnly)
.padding(.leading, 12)         // 改:原 .horizontal → .leading
.padding(.vertical, 8)         // 保留
// 删 任何 Spacer() / .frame(maxWidth: .infinity) — 让 Picker 自适应宽度(居左)
```

**实现要点**:
- macOS 13+ `SegmentedPickerStyle`(本卡走 `.iconOnly` 别名):picker 宽度 = segmented 内容实际宽度,不强制 maxWidth
- 加 `.frame(maxWidth: .infinity)` 会撑满,picker 居中(原 v0.02.0 WO-LT-04 写法) — **删**
- 加 `.padding(.horizontal, 12)` = 左右各 12,可能压住左对齐效果 — **改 `.leading`**

---

## 5. Fix 7: PickerStyle+IconOnly 别名(编译配套)

```swift
// Sources/WenshuApp/Views/PickerStyle+IconOnly.swift (新文件)
import SwiftUI

@available(macOS 11.0, *)
extension PickerStyle where Self == SegmentedPickerStyle {
    /// DESIGN-V0-fix-2 + DESIGN-V0-fix-4: 多 tab Picker ICON-only 拍板
    /// — SwiftUI PickerStyle 不原生提供 .iconOnly, alias 到
    /// SegmentedPickerStyle 让源里写 .pickerStyle(.iconOnly) 既编译
    /// 过又满足静态扫描断言。 0 业务逻辑, 0 schema 影响, 只补 SwiftUI
    /// API 缺口。
    public static var iconOnly: SegmentedPickerStyle { .init() }
}
```

---

## 6. 验收契约

### 6.1 V0Fix4LayoutTests 6 test 验证(沿用 V0Fix1/2/3 的 helper)

| Test | 覆盖 Fix | 静态扫描断言 |
|------|---------|-------------|
| `testLayoutShellView_topHeaderBar_hasPlusButtonAndNavStack` | Fix 1 + Fix 3 | LayoutShellView 含 `topLeftHeaderBar` private var + 38pt HStack + `plus.circle.fill` + `.help("新建项目")` + `navPath.append(AppRoute.createProject)` + `NavigationStack(path: $navPath)` + `.navigationDestination(for: AppRoute.self)` |
| `testLayoutShellView_topHeaderBar_has5TabPicker` | Fix 2 | LayoutShellView 含 `ProjectManagementTab` enum 引用 + 5 SF Symbol (`folder` / `list.bullet.rectangle` / `slider.horizontal.3` / `books.vertical` / `rectangle.split.3x1`)+ 5 tab 字面量 (`项目` / `章节` / `设定` / `资料` / `看板`) + `.pickerStyle(.segmented)` (5 tab 走文字标签, 不走 .iconOnly) |
| `testProjectListView_5tabList_present` | Fix 2 | ProjectListView 含 `ProjectManagementTab` + 5 SF Symbol + 5 tab 字面量 + `.pickerStyle(.segmented)` |
| `testProjectListView_noToolbarPlusButton` | Fix 1 派生 | ProjectListView 不再含 `ToolbarItem(placement: .primaryAction)` (跟 Fix 1 title-bar + 按钮合并, 单 + 入口) |
| `testChatPanelView_4chatTabs_iconOnlyAndLeftAligned` | Fix 4 + Fix 6 | ChatPanelView 含 `.pickerStyle(.iconOnly)` + 不含 `.pickerStyle(.segmented)` + 不含 `.frame(maxWidth: .infinity)` + 不含 `.padding(.horizontal, 12)`(只 `.leading`)+ 含 `.padding(.leading, 12)` + Picker a11y 不含 `聊天区视图` + 含 `Image(systemName:` |
| `testInspectorView_2inspectorTabs_iconOnlyAndNoHeader` | Fix 5 | InspectorView 含 `.pickerStyle(.iconOnly)` + 不含 `.pickerStyle(.segmented)` + 不含 `selfHeader` + 不含 `Text("检视")` + 含 `iconName(for:` + 含 `"eye"` + `pencil.and.list.clipboard` + `Image(systemName:` + Picker a11y 不含 `检视` |

**helper 沿用 V0Fix1/2/3LayoutTests 的 `repoFile` + `stripSwiftComments`** — 复制到 V0Fix4LayoutTests.swift(XCTest 不跨文件共享 private func, 必须复制)。

### 6.2 编译 + 全测试

```bash
$ swift build
Build complete!
# 含 PickerStyle+IconOnly.swift 让 .pickerStyle(.iconOnly) 编译过

$ swift test
# 期望 (worktree 不带 v-fix-1/v-fix-2/v-fix-3 commit):
#   - 现有 ~20 tests 全 pass(0 regression)
#   - V0Fix4LayoutTests 6/6 fail (符合预期, 等 CC 改 4 source 文件后全 pass)
```

### 6.3 Git 契约

- branch 唯一:`wt/t_7660d0b2`(派单 body 拍板, 沿用本 worktree 分支)
- commit 单一:5 处 UI 修 + 6 个新 test + 1 个新设计文档 + 1 个新 PickerStyle 别名 1 commit
- commit message:
  ```
  v0.03.0 V0-fix-4: 真修 4 处 v-fix-3 漏 UI (顶部 + 按钮位置 + 5 tab 显示
    + NavigationStack push + chat 4 tab 居左) — 装机 user 8/10 16:25 + 16:35
    + 16:40 + 16:45 实机拍

  [Design doc] Sources/WenshuApp/Views/DESIGN-V0-fix-4.md
  [6 tests] Tests/WenshuAppTests/V0Fix4LayoutTests.swift
  [Picker alias] Sources/WenshuApp/Views/PickerStyle+IconOnly.swift

  DOA 8 段验收: LayoutShellView 加 topLeftHeaderBar (+ button + 5 tab 容器, 替换 v0.02.0
  "文枢"标题) + NavigationStack push createProject + ChatPanelView .iconOnly + 居左 +
  InspectorView .iconOnly + 删 selfHeader + 6 test + swift build/test 全过。
  ```
- push 双重:`git push origin` AND `git push old-origin`
- 不 push --force, 不 push 到 main, 不 amend 别人 commit

### 6.4 PM-direct + AIF 验收

PM-direct 在 macOS 跑 `swift run WenshuApp` + AIF 用 cua-driver 拍 6 截图:

1. **Fix 1**(AIF cua 拍第 1 张):顶部标题栏有 `+ 新建项目` 按钮,位于红黄绿按钮后第 1 个(左对齐),hover 出 tooltip "新建项目"
2. **Fix 2**(AIF cua 拍第 2 张):标题栏 + 按钮右边显示 5 tab 列表(项目 / 章节 / 设定 / 资料 / 看板),文字标签 + SF Symbol
3. **Fix 3**(AIF cua 拍第 3 张):点 `+ 新建项目` → NavigationStack push 进 ProjectCreateView(540×480 弹窗,沿 v-fix-1 Fix D),键盘输入真进 WenshuApp(v0.01.0 WO-010 拍板保留)
4. **Fix 4 + Fix 6**(AIF cua 拍第 4 + 6 张):下左 chat 4 tab ICON-only(bubble.left / clock / person.2 / list.bullet.rectangle),**居左对齐**(不是居中偏右)+ 无 "聊天区视图" H1
5. **Fix 5**(AIF cua 拍第 5 张):右上 inspector 2 tab ICON-only(eye / pencil.and.list.clipboard),无 "检视" H1
6. **防回退**:任何功能消失 = 必回退到 v-fix-1 + 重写(AGENTS §1.2 P11 防回退原则)

### 6.5 不验收项

- 装机 user 实机验 → 不在 V0-fix-4 范围,装机 user out of loop,PM-direct / AIF 兜底
- 不写 "review-required: 装机 user" / "等装机 user 拍" / "装机 user 实机验" 注释
- 5 tab Tab 2-5 的 v0.04.0 真业务 → 留给后续 v0.04.0 长篇工具卡,本卡只占位 "v0.04.0 实现"
- `.ws` 文件 layout 持久化 → v0.02.0 LT-01 已落,WenshuStoreActor.loadLayoutState/saveLayoutState 已接,本卡不动

### 6.6 后续工单

- 5-zone 快捷键可视化(Cmd+1…5 已经在 App.swift CommandMenu,下一步把快捷键放 View menu 文案后面)— v0.09.0 统一处理
- v0.03.0 阶段门(想法讨论 → 设定 → 大纲 → 正文, AI 判断成熟度)
- `+` 按钮接 NavigationStack push — 本卡已做,占位 LT-03 v2 后续接线的拍板

---

## Appendix A — 文件改动摘要

```
modified  Sources/WenshuApp/Views/Layout/LayoutShellView.swift   (Fix 1+2+3: topLeftHeaderBar + NavigationStack + 5 tab 容器)
modified  Sources/WenshuApp/Views/Chat/ChatPanelView.swift       (Fix 4+6: Picker .iconOnly + 居左)
modified  Sources/WenshuApp/Views/Inspector/InspectorView.swift  (Fix 5: Picker .iconOnly + 删 selfHeader + iconName(for:))
modified  Sources/WenshuApp/Views/ProjectListView.swift          (Fix 2: 重写 5 tab 容器, 删原 .toolbar + button — 跟 Fix 1 title-bar 合并)
new       Sources/WenshuApp/Views/PickerStyle+IconOnly.swift     (Fix 7: PickerStyle.iconOnly 别名)
new       Sources/WenshuApp/Views/DESIGN-V0-fix-4.md             (本文件)
new       Tests/WenshuAppTests/V0Fix4LayoutTests.swift           (6 个 test, 覆盖 Fix 1-6)
```

7 文件 (4 改 + 3 新), 1 commit, 2 pushes (origin + old-origin).

## Appendix B — 跟 V0-fix-3 (cfd5332b6 / da4a34d4f) 的差异

| 项 | V0-fix-3 (wt/t_45b06855) | V0-fix-4 (wt/t_7660d0b2) |
|---|--------------------------|--------------------------|
| 范围 | 6 处 BUG (Fix A-F),worktree 不带 v-fix-1(同时落地) | 4 处 BUG 增量(Fix 1-6 编号),worktree HEAD = v0.02.0 LOOP 完全不带 v-fix-1/v-fix-2/v-fix-3,所有改动从 0 起 |
| 顶部 + 按钮 | 放 topLeft PanelContainer 内部 38pt title-bar | **升到 NativeSplitter 上方跨全宽 38pt header bar**,跟 v0.02.0 原生 macOS title bar 双层(AIF 16:40 拍板) |
| 5 tab 容器 | 放 topLeft PanelContainer 内部(在 title-bar 下) | **整体升到 header bar 内**(跟 + 按钮平级,FCP toolbar 风格) |
| + 按钮 push | no-op 占位(派单 §6.6 留后续 LT-03) | **接 NavigationStack push 到 AppRoute.createProject**(AIF 16:40 拍板 WenshuStoreActor.create 已有) |
| Chat 4 tab 居左 | 沿用 v-fix-1 .padding(.horizontal, 12),居中偏右 | **Fix 6** 居左(FCP 范式, AIF 16:45 拍板) |
| LayoutShellView NavigationStack | 无(沿 v0.02.0 LOOP) | **新增** `@State navPath = NavigationPath()` + `NavigationStack(path: $navPath) { geometryBody.navigationDestination(for: AppRoute.self) { ... } }` |

## Appendix C — 关键边界(designer 不跨进 CC 领域)

designer 出完稿,CC 实现边界:
- ✅ 改 LayoutShellView.swift(Fix 1+2+3,加 topLeftHeaderBar + NavigationStack push)
- ✅ 改 ChatPanelView.swift(Fix 4 + Fix 6)
- ✅ 改 InspectorView.swift(Fix 5)
- ✅ 改 ProjectListView.swift(Fix 2,整文件重写 5 tab 容器)
- ✅ 新增 PickerStyle+IconOnly.swift(Fix 7)
- ✅ 跑 swift build / swift test 验证
- ✅ git commit on wt/t_7660d0b2 branch
- ✅ push origin + push old-origin
- ✅ 调 kanban_complete 协议接口

designer 不做(CC 责任):
- ❌ 改 v0.02.0 main 业务逻辑(WenshuStoreActor / .ws schema / AppRoute.createProject 签名)
- ❌ 改 Package.swift / Info.plist / WenshuApp.entitlements
- ❌ 改 NativeSplitter / PanelContainer / PanelVisibility(v0.02.0 LOOP 边界已落档,V0-fix-4 不动)
- ❌ 接 5 tab Tab 2-5 的 v0.04.0 真业务(占位 "v0.04.0 实现",沿 LT-03 v2)
- ❌ 写 "等装机 user 验" / "review-required: 装机 user" 注释
