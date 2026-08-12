# DESIGN · Q2 折叠态实装验收 verdict · 文枢 (Wenshu)

> v0.04.0 Q2 折叠态 — designer 验收 (t_9bca27a6)
> 沿 t_c6f48f43 reviewer PASS (6/6 AC, HEAD 5e4dfe01e) 派生 §3.8 接卡
> 工作 workspace = `.worktrees/pre-merge/t_c6f48f43-cc-1` (HEAD `5e4dfe01e`, 4 commit +120/-2)
> 上游拍板真值 = DESIGN-Q2-panel-collapse.md §1.1-§1.6 + AGENTS §3.7/§3.8/§3.5(§13.1) + V0-fix-8 (0.2s ease-in-out)

---

## 0. 验收范围 (4 commit + 4 文件真值)

git show HEAD~4..HEAD 真值 (commit author `aif <aif@wenshu.local>`, 2026-08-12 18:56):

| commit | 文件 | +/- | 实装内容 |
|---|---|---|---|
| 943b36bb3 | App.swift | +18 | LayoutMenuContent 新增折叠子项 ForEach(`isCollapsible`) + Cmd+Opt+`menuShortcut` + `.disabled(!isVisible)` |
| 25067dd87 | LayoutShellViewModel.swift | +40 | `menuCollapseTitle(for:)` (显示下一动作 verb) + `isCollapsed(_:)` public 读 + `PanelID.isCollapsible` 扩展 (3 true / 2 false) |
| 8bca1b9eb | PanelContainer.swift | +44 | CollapsedGutter 加 `.onTapGesture(count: 2)` 双击展开 + 新建 CollapsedHeader view (HStack SF Symbol 14pt + title 11pt, frame 30pt, 同 background/border) |
| 5e4dfe01e | LayoutShellView.swift | +18/-2 | body 顶层加 `.animation(.easeInOut(duration: 0.2), value: vm.snapshot.collapsed)` + panel() 函数按上下半分支 CollapsedGutter / CollapsedHeader |

swift build exit 0, markdown unhandled warning 无害 (V0-fix-2 范式沿用).

---

## 1. 视觉验收 (DESIGN §1.5 对照)

### 1.1 上半折叠 chrome (CollapsedGutter) — 不动 ✅

- `frame(width: LayoutSnapshot.topCollapsedPixels)` = 50pt ✅ (LayoutState.swift line 103)
- SF Symbol `panelID.symbolName` (`folder` / `sidebar.right`) 14pt medium + `.foregroundStyle(.secondary)` ✅
- background `Color(NSColor.controlBackgroundColor).opacity(0.6)` + 0.5pt border `Color.secondary.opacity(0.18)` ✅ (沿 CollapsedGutter 真值 0 修改)

### 1.2 下半折叠 chrome (CollapsedHeader, 新建) ✅

- `frame(height: LayoutSnapshot.bottomCollapsedPixels)` = 30pt ✅ (LayoutState.swift line 106)
- HStack(spacing: 6) + SF Symbol 14pt medium `.secondary` + Text(panelID.title) 11pt `.secondary` + Spacer + padding(.horizontal, 10) ✅ (跟 design §1.5 下半范式对齐)
- background / border 跟 CollapsedGutter 完全同源 ✅ (视觉一致性 OK)
- 双击手势同 CollapsedGutter ✅ (`.onTapGesture(count: 2)`)

**微调建议 (不阻塞)**:
- CollapsedHeader 水平 padding 10pt + SF Symbol 14pt + spacing 6pt + title 11pt = 起步约 35pt 宽. 在 30pt 高度 chrome 上, 居中视觉 OK, 但若 title 偏长 (中文标题 2-4 字) 不会截断 (Spacer 收尾). 留观察项, 不阻塞合 main.

### 1.3 折叠态持久化 ✅

- `vm.toggle(panel)` 走 `scheduleSave()` → `PanelStatesEnvelope.encode(collapsed:, visible:)` → `CDLayoutState.panel_states` 列. 0 修改真值 (DESIGN §1.6 沿用).

---

## 2. 动画验收 (DESIGN §1.4 对照)

### 2.1 曲线 + 时长 ✅

`LayoutShellView.swift` line 199-205 body 顶层:

```swift
.animation(.easeInOut(duration: 0.2), value: vm.snapshot.collapsed)
```

- `value: vm.snapshot.collapsed` 触发 = 任一 panel 的 collapsed bool 变化 ✅
- `duration: 0.2` + `.easeInOut` = 沿 V0-fix-8 FCP 范式真值 ✅
- SwiftUI 自动插值 gutter/header 宽度过渡 ✅ (DESIGN §1.4 "影响范围" 对齐)

**未实装 (不影响 verdict)**:
- design §1.4 提"frame 高度同步插值" — 实装通过 SwiftUI 默认 frame animation 处理, 无显式 height 绑定, OK.

---

## 3. 触发器验收 (DESIGN §1.3 对照)

### 3.1 触发器 A — 显示 menu 折叠子项 (Cmd+Opt+1/3/5) ✅

- App.swift line 311-326: `ForEach(PanelID.allCases.filter { $0.isCollapsible })` → 3 个可折叠 panel 列出 ✅
- `keyboardShortcut(panel.menuShortcut, modifiers: [.command, .option])` = Cmd+Opt+1 (topLeft) / Cmd+Opt+3 (topRight) / Cmd+Opt+5 (bottomRight) ✅
- `menuCollapseTitle(for:)` 动态标题 = visible+expanded "折叠 X" / visible+collapsed "展开 X" ✅ (显示下一动作, FCP 范式)
- `.disabled(!vm.isVisible(panel))` = hidden 的折叠项 disabled ✅ (DESIGN §1.1 "Hidden → disabled" 范式)
- 不可折叠 panel (topCenter/bottomLeft) 走 filter 直接不出现 ✅ (跟现有 isDismissible disabled 范式区分)

### 3.2 触发器 B — 双击折叠 chrome 展开 ✅

- CollapsedGutter (上半) + CollapsedHeader (下半) 都加 `.onTapGesture(count: 2)` 调 `LayoutShellViewModel.shared.toggle(panelID)` ✅
- 折叠 chrome 上不画展开按钮 ✅ (沿 V0-fix-3 老板 拍板"标题栏全删, 用功能告诉用户")
- 双击热区 = 整 chrome (上半 50pt 宽 × full height, 下半 full width × 30pt 高) ✅ — 热区 ≥ 30×30pt, 符合 macOS HIG 双击标准

### 3.3 触发器 C — 拖 splitter 跨过 30pt 自动折叠 ❌ **未实装 (设计稿显式留 v0.05.0)**

- `LayoutSnapshot.autoCollapsePixels = 30` 真值在 Models/LayoutState.swift line 100 ✅ (实装真值)
- `NativeSplitter.onDrag` 回调 (NativeSplitter.swift line 448) 当前**只调** `vm.adjustUpperColumn` / `adjustBottomHeight` / `adjustLowerColumn` 调 ratios, **未**调 `vm.toggle(panel)` 实现 auto-collapse ❌
- DESIGN-Q2 §1.3 + §2 CC 实装提示**显式声明**: "**这条隐含且复杂**, Q2 主轴是触发器 A/B, C 可留 v0.05.0 单独派单"
- **不算 FAIL** — design 稿自己留 v0.05.0, reviewer 6/6 AC 不含 C

---

## 4. 触发器 C 决策稿 (卡体 §3.8 派生 2 字段)

### 4.1 现状

- trigger C 真值 (`autoCollapsePixels = 30`) 在 Models 层完整
- trigger C UI 实装 (NativeSplitterView.onDrag → vm.toggle) **缺**
- DESIGN-Q2 §2 已声明 "Q2 主轴 A/B, C 可留 v0.05.0"
- 当前 review PASS 6/6 AC 不含 C — Q2 卡本身不需要 C

### 4.2 选项 A — 留 v0.05.0 (推荐, 默认)

- CC 暂不动 trigger C, design 稿先存档
- 沿 DESIGN-Q2 §1.3 + §2 显式声明 "C 留 v0.05.0 单独派单"
- v0.05.0 阶段门聚合时 AIF 主动派生新 CC 卡: "Q2 trigger C 实装 — NativeSplitterView.onDrag 加 auto-collapse 30pt 阈值, 沿 LayoutSnapshot.autoCollapsePixels 真值"
- 优点: 不阻塞 Q2 合 main, trigger C 跟 v0.05.0 标记系统同步上线 (FCP 范式完整)
- 缺点: 用户拖 splitter 过头不会自动折叠, 需要走菜单 / 双击 chrome 才能收

### 4.3 选项 B — 进 v0.04.x 补丁

- 派生新 CC 卡, 沿 pre-merge worktree wt/pre-merge/t_c6f48f43 加 trigger C 实装
- 改动: NativeSplitterView.onDrag end handler 检测新 ratio 对应像素 < 30, 调 `vm.toggle(panel)` collapsed = true (反向同理)
- 优点: Q2 触发器 3 件套完整, 用户拖过头自动折叠
- 缺点: NativeSplitter drag 回调是底层 NSView, 调 vm.toggle 涉及 SwiftUI state 同步时序, 容易引入新 bug; v0.04.x 阶段门未到, 提前打补丁 = 跳 §8 阶段门

### 4.4 推荐 — 选项 A (留 v0.05.0)

理由 (1 句, 沿 v0.04.0 §aif 反废话):
- DESIGN-Q2 §1.3 + §2 已显式声明 C 留 v0.05.0, 沿用 designer 拍板 = 不跳阶段门 = 不阻塞 Q2 合 main.

---

## 5. verdict 总结

| 维度 | 实装状态 |
|------|---------|
| §1.1 折叠 vs 隐藏双态 | ✅ PASS |
| §1.2 5 panel 折叠分类 | ✅ PASS (3 可折叠 / 2 不可折叠, menu filter 正确) |
| §1.3 触发器 A (菜单 Cmd+Opt+1/3/5) | ✅ PASS |
| §1.3 触发器 B (双击 chrome) | ✅ PASS |
| §1.3 触发器 C (auto-collapse 30pt) | ⏸ DEFERRED to v0.05.0 (design 稿显式声明) |
| §1.4 0.2s ease-in-out 动画 | ✅ PASS |
| §1.5 上半 CollapsedGutter 视觉 | ✅ PASS (不动) |
| §1.5 下半 CollapsedHeader 视觉 | ✅ PASS (新建, 配色一致) |
| §1.6 折叠态持久化 | ✅ PASS (0 修改, 沿真值) |

**verdict: PASS-WITH-DEFER**

- 整体 Q2 折叠态交互设计稿实装完整, 9/9 验收项通过 (含 C 的 deferred 项)
- 微调建议: CollapsedHeader 起步宽 ≈ 35pt, 标题长时不截断 (Spacer 收尾 OK), 留观察
- 触发器 C 沿 DESIGN §1.3 + §2 留 v0.05.0, 不阻塞合 main
- 推荐: my-pm 沿选项 A 派生 v0.05.0 CC 卡补 trigger C

---

## 6. sign-off (designer)

目标: Q2 折叠态实装验收 verdict — 9/9 验收项通过, 触发器 C 沿 design 稿 deferred v0.05.0.

范围: 4 commit 4 文件 +120/-2 实装真值对照 DESIGN-Q2-panel-collapse.md §1.1-§1.6 + swift build exit 0. 不写代码, 不动 LayoutState / ViewModel toggle / .ws schema, 不测像素 (reviewer 验).

标准: 1) 折叠 vs 隐藏双态区分清晰 (App.swift menu disabled + isCollapsible filter); 2) 5 panel 折叠分类正确 (3 可折叠, 2 不可折叠); 3) 触发器 A + B 实装完整; 4) 0.2s ease-in-out 动画绑定 collapsed 沿 V0-fix-8; 5) CollapsedHeader 视觉沿 CollapsedGutter 同源; 6) 持久化 0 修改沿 PanelStatesEnvelope.

边界: workspace = worktree (沿 §3.7); skills = swiftui-design-patterns + wenshu-designer-onboarding (沿 §3.7); 不做清单 = 不写代码 / 不动 LayoutState / 不动 .ws schema / 不测像素 / 不提交 (沿 §14 自纠承诺 designer 边界).

拍板真值: DESIGN-Q2-panel-collapse.md §1.1-§1.6 + LayoutState.swift line 100-106 真值 (autoCollapse 30 / topCollapsed 50 / bottomCollapsed 30) + LayoutShellViewModel.toggle 已实装 + V0-fix-8 (0.2s ease-in-out) + V0-fix-3 (折叠 chrome 不画展开按钮) + 老板 8/7 拍板"文档/聊天 不可折叠".

---

## 7. §3.5 (沿 §13.1) STATE.md 落点 (1 行 ≤ 30 字, kanban_comment 充数)

Q2 折叠态实装 9/9 通过, trigger C 沿 DESIGN §1.3 deferred v0.05.0, 不阻塞合 main.
