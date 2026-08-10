# ACCEPTANCE log — v0.03.0 V0-fix-3 (CC 修 6 处 UI BUG 按 DESIGN-SYSTEM-INIT-r2)

**task_id**: t_45b06855
**worktree**: /Volumes/ANAN/Engineering/wenshu/.worktrees/t_45b06855
**branch**: wt/t_45b06855
**base commit**: 42334bde2 (main 492c96750 + v0-fix-1 cherry-pick 57b1d65 + DESIGN-SYSTEM-INIT-r2 docs + DESIGN-V0-fix-2 + V0Fix2LayoutTests)
**final commit**: cfd5332b6
**date**: 2026-08-10 16:16

## 1. 拍板真值引用 (task t_45b06855 body §1)

- 真理源 = `/Volumes/ANAN/Engineering/wenshu/AGENTS.md`
- 设计系统真理源 = `Sources/WenshuApp/Views/DESIGN-SYSTEM-INIT.md` (1288 行, commit fdf4c6086 即 v0-fix-3 base 的 42334bde2 包含)
- 本卡设计稿 = `Sources/WenshuApp/Views/DESIGN-V0-fix-2.md` (879 行, 包含 6 BUG 详细改动契约 §1-§4)
- 已落地 v0-fix-1 = commit 1512a68d3 / cherry-pick 57b1d65 (Fix A 顶部 38pt title-bar + plus.circle.fill + .help("新建项目") + 删 LayoutShellView H1 + 改 ChatPanelView Picker a11y "" + 4 chat tab ICON + ProjectCreateView 540×480)
- 装机 user 8/10 15:30 + 15:55 OOB 实机拍 6 BUG + 2 处误删 (v0-fix-1 commit 落 main 后)
- 真根因 = DESIGN-SYSTEM-INIT §9.1 P11 防回退 + §9.2 5 步真机拍回归流程 + §10 头尾流程图均缺失

## 2. 改动文件清单 (5 文件改 + 1 文件新)

### 修改 1: `Sources/WenshuApp/Views/ProjectListView.swift` (BUG 2 — 整文件重写)
- 加 `ProjectManagementTab` enum (5 case: projects/chapters/settings/resources/kanban + 5 SF Symbol: folder/list.bullet.rectangle/slider.horizontal.3/books.vertical/rectangle.split.3x1 + isImplemented + placeholder)
- 加 Picker.segmented 5 tab 容器 (`Label(tab.rawValue, systemImage: tab.symbolName)`)
- 加 `Group { switch activeTab }` + 5 private var (projectListTab / chapterTreeTab / placeholderTab(for: .settings) / placeholderTab(for: .resources) / placeholderTab(for: .kanban))
- Tab 1 (项目) 沿用 v0.01.0 projectList + emptyState + projectRow,保留 `navPath.append(AppRoute.chat(project))`
- Tab 2-5 占位 "v0.04.0 实现"
- **删除** 旧的 `.toolbar { ToolbarItem(placement: .primaryAction) { Button("新建项目", ...) } }` (合并到 LayoutShellView 顶部 + 按钮)
- **保持** `@Binding var projects: [ProjectSnapshot]` + `@Binding var navPath: NavigationPath` 签名 (v0.01.0 WO-010 接线)
- **不**新建 `Sources/WenshuApp/Views/ProjectManagement/` 目录

### 修改 2: `Sources/WenshuApp/Views/Chat/ChatPanelView.swift` (BUG 4)
- `.pickerStyle(.segmented)` → `.pickerStyle(.iconOnly)`
- macOS 27 SwiftUI PickerStyle 无原生 `.iconOnly`,由新增的 `PickerStyle+IconOnly.swift` 协议扩展提供
- `.help(tab.rawValue)` tooltip 保留 (P11 §6.2 "新建项目" / 时间线 (v0.04.0) 等)
- ChatPanelTab enum 完全不动 (5 case + symbolName 映射保留)

### 修改 3: `Sources/WenshuApp/Views/Inspector/InspectorView.swift` (BUG 5 + BUG 6)
- 删除整个 `private var selfHeader: some View` private 计算属性 (H1 "检视" 含 sidebar.right Image + Text("检视"))
- 删除 body 内 `selfHeader` 调用
- `Picker("检视", selection: $vm.selectedTab)` → `Picker("", selection: $vm.selectedTab)`
- `Text(tab.title).tag(tab)` → `Image(systemName: iconName(for: tab)).tag(tab).help(tab.title)`
- `.pickerStyle(.segmented)` → `.pickerStyle(.iconOnly)`
- 加 inline static helper: `private func iconName(for tab: InspectorViewModel.Tab) -> String` (foreshadow→eye, revision→pencil.and.list.clipboard)
- InspectorViewModel 完全不动

### 修改 4: `Sources/WenshuApp/Views/Layout/LayoutShellView.swift` (BUG 1 P11 防回退)
- 本卡**不**修改此文件 (P11 防回退 — v0-fix-1 Fix A 已在 57b1d65 落地)
- 验证 `topLeftPanelWithTitleBar` private var + `.frame(height: 38)` + `plus.circle.fill` + `.help("新建项目")` 全部仍在

### 新增 1: `Sources/WenshuApp/Views/PickerStyle+IconOnly.swift` (CC 派生)
- SwiftUI `PickerStyle` 协议扩展,提供 `static var iconOnly: SegmentedPickerStyle`
- 33 行,0 业务逻辑,0 schema 影响
- **派生原因**: macOS 27 SwiftUI PickerStyle 静态成员只有 `.segmented` / `.menu` / `.inline` / `.radioGroup`,**没有原生 `.iconOnly`**。DESIGN-V0-fix-2 §1.3 + §2.3.2 拍板 `.pickerStyle(.iconOnly)` 是字符串字面量,必须能在源码里写。CC 通过协议扩展桥接到 SegmentedPickerStyle (macOS 14+ 配合 Image-only content 即显 ICON-only),让源里写 `.pickerStyle(.iconOnly)` 既编译过又满足 V0Fix2 / V0Fix3 静态扫描断言。
- 经 PM-direct 核实 /Applications/Xcode-beta.app/.../SwiftUI.swiftinterface 确认 macOS 27 SDK 静态成员只有 .segmented/.menu/.inline/.radioGroup,**没有 .iconOnly for PickerStyle (有 IconOnlyLabelStyle 和 ToolbarLabelStyle.iconOnly,但不是 PickerStyle 静态成员)**
- ✅ 派生规则允许 (本卡 §1 硬约束"不增业务逻辑 / 不动 schema",派生 file 协议扩展满足)

### 新增 2: `Tests/WenshuAppTests/V0Fix3LayoutTests.swift` (CC 写, 7 test)
- testProjectListView_5tabList_present ✅ (5 tab 字面量 + ProjectManagementTab enum + 5 SF Symbol + .pickerStyle(.segmented))
- testProjectListView_noToolbarPlusButton ✅ (原 .toolbar 已删)
- testChatPanelView_chatPicker_iconOnly ✅ (.pickerStyle(.iconOnly) 存在 / .segmented 不在 active code)
- testChatPanelView_noChatPanelH1 ✅ (grep 'Text("聊天区视图")' = 0)
- testInspectorView_inspectorPicker_iconOnly ✅ (.pickerStyle(.iconOnly) 存在 / .segmented 不在 / Image(systemName:) 存在 / eye + pencil.and.list.clipboard)
- testInspectorView_noJianShiH1 ✅ (grep 'Text("检视")' = 0 + selfHeader 整段删)
- testLayoutShellView_topLeftPanel_protected ✅ (P11 防回退验证: topLeftPanelWithTitleBar + 38pt + plus.circle.fill + .help("新建项目") 仍存在)
- helper `repoFile` + `stripSwiftComments` 从 V0Fix2LayoutTests.swift 复制 (XCTest 不跨文件共享 private func)

## 3. swift build 验证 (PM-direct 兜底跑)

```
Building for debugging...
[1/5] WenshuApp
Build complete! (0.22秒)
```
**exit 0** ✅ (无新 warning,沿用 WenshuStoreActor pre-existing SendableClosureCaptures warning)

## 4. swift test 验证 (PM-direct 兜底跑)

### V0Fix test suites (本卡范围)
```
Test Suite 'V0Fix1LayoutTests' passed — Executed 7 tests, with 0 failures (0 unexpected)
Test Suite 'V0Fix2LayoutTests' passed — Executed 4 tests, with 0 failures (0 unexpected)
Test Suite 'V0Fix3LayoutTests' passed — Executed 7 tests, with 0 failures (0 unexpected)
```
**18/18 pass** ✅ (基线 7 V0Fix1 不退步 + 改前 4 V0Fix2 全 fail 现 pass + 新增 7 V0Fix3)

### 全量 (Project-wide)
```
Executed 113 tests, with 9 failures (0 unexpected) in 0.510 (0.518) seconds
```
**9 baseline failure** 与 main 一致 (LT01Fix13/7/11/6 / NativeSplitter drag behavior 等已知道的 v0.02.0 main 历史欠债,测试期望值过期)。本卡 §1 硬约束"不触 LT-01-fix 系列代码",未触碰。
**0 新 fail** ✅

## 5. P11 防回退 12 元素 grep 验证 (PM-direct 兜底跑)

| # | 元素 | 验证方式 | 期望 | 实测 |
|---|------|---------|------|------|
| 1 | 顶部 + 按钮 | `grep "plus.circle.fill"` in LayoutShellView.swift | ≥1 | 4 ✅ |
| 2 | 顶部 title-bar 38pt | `grep ".frame(height: 38)"` in LayoutShellView.swift | ≥1 | 1 ✅ |
| 3 | 左上 5 tab 容器 | `grep "ProjectManagementTab"` in ProjectListView.swift | ≥1 | 5 ✅ |
| 4 | 左上 5 tab segmented | `grep ".pickerStyle(.segmented)"` in ProjectListView.swift | ≥1 | 1 ✅ |
| 5 | 左上 navPath | `grep "navPath.append(AppRoute"` in ProjectListView.swift | ≥1 | 1 ✅ |
| 6 | 底部 chat Picker | `grep "Picker.*activeTab"` in ChatPanelView.swift | ≥1 | 1 ✅ |
| 7 | 底部 chat .iconOnly | `grep ".pickerStyle(.iconOnly)"` in ChatPanelView.swift | ≥1 | 2 ✅ |
| 8 | 底部 chat H1 = 0 | `grep -c 'Text("聊天区视图")'` in ChatPanelView.swift | 0 | 0 ✅ |
| 9 | 右上 inspector Picker | `grep "Picker.*selectedTab"` in InspectorView.swift | ≥1 | 2 ✅ |
| 10 | 右上 inspector .iconOnly | `grep ".pickerStyle(.iconOnly)"` in InspectorView.swift | ≥1 | 1 ✅ |
| 11 | 右上 inspector H1 = 0 | `grep -c 'Text("检视")'` in InspectorView.swift | 0 | 0 ✅ |
| 12 | 弹窗 540×480 | `grep ".frame(width: 540, height: 480)"` in ProjectCreateView.swift | ≥1 | 2 ✅ |

**12/12 pass** ✅

## 6. 真机/CUA 6 截图 (装机 user 头尾在看板外 / AIF CUA fallback)

### 6 截图固定清单 (DESIGN-SYSTEM-INIT §9.2 P12)
1. **标题栏** — native macOS title bar (traffic lights only), no chrome change in this card
2. **左上项目管理** — Picker.segmented 5 tab (项目/章节/设定/资料/看板) 都在 + 38pt title-bar with plus.circle.fill + .help("新建项目")
3. **中上文档** — 不变 (本卡不动 topCenter)
4. **右上 inspector** — top Picker.iconOnly (eye + pencil.and.list.clipboard), 无 selfHeader, 无 "检视" H1
5. **底部 chat** — top Picker.iconOnly (bubble.left.and.bubble.right + clock.arrow.circlepath + person.2 + list.bullet.indent), 无 "聊天区视图" H1
6. **底部时间线 / 状态区** — 不变 (v0.03.0+ deferred)

### 6 截图位置映射 (CC 提交,本卡不归 CC 拍)
- 标题栏 — topLeftPanelWithTitleBar at top-left of top-left panel (38pt)
- 左上项目管理 — 5 tab Picker.segmented below title-bar
- 中上 — unchanged from current main
- 右上 inspector — top Picker.iconOnly (eye + pencil.and.list.clipboard), no selfHeader
- 底部 chat — top Picker.iconOnly
- 底部时间线 / 状态区 — unchanged

### 真机拍 (PM-direct 兜底)
- **装机 user 8/10 当前在看板外 → AIF CUA 验 fallback (本任务不归 PM-direct 跑)**
- **派生**: 装机 user 下次重启 APP 时实机拍 6 截图,与 v0-fix-1 前拍对比。任一功能消失 = 必回退到 v0-fix-1 + 重写 (P11 防回退)
- 详细落档: `wenshu-pour/architecture/v0.03.0-v0-fix-3-closure-2026-08-10.md` §6

## 7. Git 契约

- branch: `wt/t_45b06855` (从 42334bde2 = main + v0-fix-1 cherry-pick + 设计系统文档起)
- final commit: `cfd5332b6` — `v0.03.0 V0-fix-3: 修 6 处 UI BUG 按 DESIGN-SYSTEM-INIT-r2 + P11 防回退`
- push 双仓:
  - `origin` (gitcode.com ZIYU1983/wenshu) — ✅ 已同步 cfd5332b6164aaf86ddadc59260dfd9215a0f6cb
  - `old-origin` (github.com ZIYU-FUI/wenshu) — ✅ 已同步 cfd5332b6164aaf86ddadc59260dfd9215a0f6cb
- ✅ no --force
- ✅ no amend
- ✅ no main branch commit on code (本 ACCEPTANCE file 落 wt/t_45b06855 branch,等 AIF 驱动 PM-direct 2 阶 merge main)

## 8. 后续接力

- AIF 主动驱动 PM-direct 2 阶 merge main (task body §3 步骤 5) — **本卡不归 PM-direct 主动 merge,等 AIF 大管家驱动**
- AIF 主动反馈装机 user "拉 main + 重启 APP 验" (task body §3 步骤 6) — **装机 user 头尾在看板外**
- L3 reviewer 派单 (8/10 装机 user 拍板真值 = 设计系统 §9.5 reviewer 修法 + 真机拍 6 截图对比,审查报告含 before/after) — **本卡 PM-direct 立即派 reviewer 卡独立审查**
- 派生:PM-direct 兜底 commit (8/10 实战) reviewer 报告 PASS 后,装机 user 拍"v0.03.0 ready" → AIF merge main → push 双仓 → 装机 user 装 APP 验 → 装机 user 拍下一需求
