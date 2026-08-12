# DESIGN · Q2 面板折叠态 · 文枢 (Wenshu)

> v0.04.0 Q2 折叠态 — designer 出稿 (t_0551b59c)
> 沿 t_401f6524 (reviewer PASS, 6/6 AC) + t_454e6ed5 派单 (8/12 老板 拍, reviewer 拍板"折叠态不在本卡展开 = 另派 designer")
> 工作 workspace = 主仓 main (HEAD = `2b98d6e0d` = v0.04.0 AGENTS.md §3.7/§3.8)
> 上游拍板真值 = AGENTS §8.1 layout 5 区 + §3.5 §13.6 落点机制 + V0-fix-3/5/9 真值 + FCP 范式 + 现有 LayoutState.swift/ViewModel/App.swift 实装真值

---

## 0. 任务边界矛盾点 (designer 不能拍, 必升级)

读了 AGENTS §8.1 + LayoutState.swift (line 38-58 PanelCollapsedState) + LayoutShellView.swift (line 561-630 panel/CollapsedGutter) + LayoutShellViewModel.swift (line 86-110 toggle 已存在但无 caller) + App.swift (line 263-319 LayoutCommands 仅显示隐藏, 无折叠) + fcp-viewer-pattern §0 总原则 + §3.8 MVP 切片, 发现 4 处跟现状 / 范式 / 派单描述冲突点.

### 矛盾 0.1: 派单"5 panel 折叠态" 跟 现状"toggle 已实装但无 UI 触发" 冲突

- **事实** (LayoutShellViewModel.swift line 86-110, 2026-08-12 已实装):
  ```swift
  func toggle(_ panel: PanelID) {
      var snap = snapshot
      switch panel {
      case .topLeft: snap.collapsed.topLeft.toggle()
      // ... 5 panel 同一模式
      }
      snapshot = snap
      scheduleSave()
  }
  ```
- **现状** (LayoutShellView.swift line 564 + PanelContainer.swift line 62-84): `panel(_:width:)` 已调用 `CollapsedGutter` 渲染 collapsed 视觉, `LayoutMetrics.upperWidths` / `lowerWidths` 已用 collapsed flag 算 gutter (line 488-498), `PanelStatesEnvelope` 已 JSON encode collapsed + visible 一起持久化.
- **冲突**: 派单卡 body 写"出折叠态交互设计稿" = 出折叠 / 展开交互范式. 但**实装已经完整** — collapsed flag 持久化 + 视觉渲染 + VM toggle 方法都齐了, **缺的只是 UI 触发器** (LT-01-fix3 删了 panel chevron, App.swift CommandMenu 只 toggle visibility 不 toggle collapsed). 派单"出设计稿"实际是"出触发器设计稿".
- **建议**: ✅ 派单卡 body 范围理解为 "出**触发器 + 折叠展开动画曲线**设计稿" (CC 实装 collapsed toggle UI 入口 + animation). 派单卡 body 写"5 区 panel 在 collapsed / expanded 两态切换的视觉范式"实际指 触发 → 折叠展开 整套交互范式 (触发 + 视觉 + 动画 + 持久化), 不重复实装已有的 collapsed 视觉 / 持久化真值.

### 矛盾 0.2: 派单"30px auto-collapse 阈值" 跟 LayoutSnapshot 已拍板 30pt 冲突

- **事实** (LayoutState.swift line 98-100): `static let autoCollapsePixels: Double = 30`
- **冲突**: 派单卡 body "30px auto-collapse 阈值" 跟 LayoutSnapshot 真值一致 — 没有冲突, 拍板真值**已经在 Models 里**, 缺的只是 View 层消费 (CC 卡实装).
- **建议**: ✅ 沿用 LayoutSnapshot.autoCollapsePixels = 30 真值, designer 不重定义. View 层 splitter drag handler (`NativeSplitterView.onDrag` 沿用 `adjustUpperColumn` / `adjustBottomHeight` / `adjustLowerColumn` 已有 return Bool 接口) 检测 `delta < 30` 自动 collapsed, View layer 只调 `vm.toggle(panel)` 触发状态.

### 矛盾 0.3: 派单"折叠方向 (左/右/上/下)" 跟 top/bottom 两套折叠范式冲突

- **事实** (PanelContainer.swift line 62-84 CollapsedGutter): 上半 3 panel 折叠后 = 50pt 宽垂直 gutter (VerticalCollapsedGutter, SF Symbol 居中); 下半 2 panel 折叠后 = 30pt 高水平 header bar (HorizontalCollapsedHeader, 待 CC 实装)
- **冲突**: 派单"折叠方向 (左/右/上/下)" 描述含糊. 实际 = 折叠方向**固定** (上半 panel 折叠 = 收到左/右 gutter, 50pt; 下半 panel 折叠 = 收到上/下 header bar, 30pt), **不是 4 方向任意选**.
- **建议**: ✅ 折叠方向**沿 LayoutState 真值** (line 102-106): top 3 panel = `topCollapsedPixels = 50` 垂直 gutter, bottom 2 panel = `bottomCollapsedPixels = 30` 水平 header bar. 派单"折叠方向"理解为 "折叠后 chrome 的位置方向" (上半 = 垂直侧, 下半 = 水平侧), 不是 "折叠动效滑动方向". designer 在 §3 视觉范式里固定两套 chrome.

### 矛盾 0.4: 派单"展开动画曲线 + 时长" 跟 V0-fix-8 已拍板 0.2s 冲突

- **事实** (V0-fix-8 真值沿用): FCP 范式 = 0.2s ease-in-out (modalsheet + transition 全套沿用). main HEAD `2b98d6e0d` 没有 animation 显式 modifier (现状 = SwiftUI 默认即时切换).
- **冲突**: 派单"动画曲线 + 时长" = Q2 新增, V0-fix-8 没拍过 panel 折叠动画. 0.2s ease-in-out 是 FCP 范式**通用约定**, designer 拍 = 0.2s ease-in-out (沿 FCP 范式), **不需要 PM-direct 拍** (FCP 通用范式 = 老板 8/10 拍过的 FCP Viewer 范式一致).
- **建议**: ✅ 折叠 / 展开动画 = `.animation(.easeInOut(duration: 0.2), value: vm.snapshot.collapsed)` (CC 加在 LayoutShellView 顶层). 设计师拍板, 不需 PM-direct 拍.

---

## 1. 折叠态范式拍板真值 (FCP 范式 + 现有实装 = 全套折叠交互设计稿)

### 范式 1.1: 折叠 vs 隐藏 (区分两种 chrome)

| 维度 | collapsed 折叠 | hidden 隐藏 |
|------|--------------|------------|
| 持久化 flag | `snapshot.collapsed.{panel}` (true) | `visibility.{panel}` (false) |
| 占位宽度 | gutter 50pt (top) / header 30pt (bottom) | 0pt (no chrome) |
| 视觉 | 保留 SF Symbol (CollapsedGutter) | 完全消失 |
| 邻 panel | 不吸收空间, 仍按 ratio 渲染 | 吸收空间 (redistribute) |
| 触发器 (现状) | **缺 UI 触发器** (Q2 设计稿主轴) | macOS 显示 menu (Cmd+1..5) |
| 触发器 (Q2 补) | 显示 menu 新增 "折叠 X" (Cmd+Opt+1..5) + 双击 gutter / header | 沿用现有 Cmd+1..5 |

**核心区分**: collapsed = 折叠 (留个 chrome 提醒这是哪个 panel, FCP 范式); hidden = 完全消失 (邻 panel 吸收空间, 老板 8/7 拍板的"辅助区可隐").

### 范式 1.2: 5 panel 折叠态分类

| PanelID | 标题 | 可折叠 (Q2) | 可隐藏 (现状) | 折叠后 chrome 类型 | 折叠后尺寸 | SF Symbol (gutter/header 居中) |
|---------|------|-----------|------------|------------------|-----------|----------------------------|
| `.topLeft` | 项目管理 | ✅ | ✅ | 垂直 gutter (左侧 50pt) | 50pt × full height | `folder` |
| `.topCenter` | 文档 | ❌ | ❌ | (不可折叠) | (保留占满上半) | - |
| `.topRight` | 检视 | ✅ | ✅ | 垂直 gutter (右侧 50pt) | 50pt × full height | `sidebar.right` |
| `.bottomLeft` | 聊天 | ❌ | ❌ | (不可折叠) | (保留占满下半) | - |
| `.bottomRight` | 状态 | ✅ | ✅ | 水平 header (底部 30pt) | full width × 30pt | `checklist` |

**核心区分**: 5 panel 中 3 可折叠 (topLeft / topRight / bottomRight), 2 不可折叠 (topCenter / bottomLeft, 跟"不可隐藏"同源, 老板 8/7 拍板"文档 / 聊天 是核心创作区, 必须常驻"). collapsed flag 仍持久化这 2 个, 但 UI 不暴露入口.

### 范式 1.3: 折叠触发器 (3 种, 沿 macOS HIG + FCP 范式)

**触发器 A (主推): 显示 menu 新增 "折叠 X" 子项 (Cmd+Opt+1..3)**
- 位置: `Sources/WenshuApp/App.swift` line 263-319 `LayoutMenuContent`, 在现有 Cmd+1..5 隐藏 / 显示 之后, **新增一组 Cmd+Opt+1..3 折叠 / 展开**
- 标题沿用 `vm.menuTitle(for: panel)` 但加 `collapsed` 分支: visible + expanded → "折叠 项目管理"; visible + collapsed → "展开 项目管理"; hidden → disabled (不可折叠, panel 都不在)
- `keyboardShortcut` = `panel.menuShortcut` + `modifiers: [.command, .option]` (FCP 范式 Cmd+Opt+数字 = 折叠/展开, 沿用现有 menuShortcut 1/3/5)
- 动作: `vm.toggle(panel)` (LayoutShellViewModel line 94 toggle 方法已实装, 直接调)
- 边界: topCenter / bottomLeft (不可折叠 panel) 在 menu 里**不出现** (跟现状 Cmd+1..5 中"文档/聊天 disabled"不同, **不出现** = 不可折叠就是不该有这个动作)

**触发器 B (辅助): 双击 CollapsedGutter / CollapsedHeader 反向**
- 上半 CollapsedGutter (50pt 垂直) 双击 → 展开 (vm.toggle(.topLeft) 或 .topRight)
- 下半 CollapsedHeader (30pt 水平, CC 新建 CollapsedHeader view, 沿 CollapsedGutter 范式) 双击 → 展开 (vm.toggle(.bottomRight))
- 实现: `CollapsedGutter` 套 `.onTapGesture(count: 2) { vm.toggle(panelID) }` (SwiftUI gesture, macOS HIG 标准)

**触发器 C (高级, 沿 V0-fix-8 拍板的 30pt 阈值): 拖 splitter 跨过 30pt 自动折叠**
- 沿 LayoutState.swift line 98-100 `autoCollapsePixels = 30` 真值, **CC 在 NativeSplitterView.onDrag 加**: 拖结束时检测新 ratio 对应的实际像素 < 30, 自动调 `vm.toggle(panel)` collapsed = true; 反向展开同理
- 这条**已隐含在真值里** (LayoutSnapshot.autoCollapsePixels + ViewModel 已有 toggle), Q2 设计稿**只是确认这条沿用**, CC 实装 = 在 splitter drag end handler 加自动折叠逻辑, designer 不重设计

**3 触发器优先级**: A 主推 (菜单, 跟现有 Cmd+1..5 一致); B 辅助 (直 gutter/header, 用户拖完想反向); C 隐含 (拖过头自动折叠).

### 范式 1.4: 折叠动画曲线 + 时长

```swift
// CC 实装时加在 LayoutShellView.swift body 顶层:
.animation(.easeInOut(duration: 0.2), value: vm.snapshot.collapsed)
```

- 触发时机: 每次 `vm.snapshot.collapsed.{panel}` bool 变化时, SwiftUI 自动 animate ratio → gutter 宽度过渡
- 曲线: ease-in-out (FCP 范式通用, V0-fix-8 拍板)
- 时长: 0.2s (FCP 范式, V0-fix-8 拍板)
- 影响范围: gutter/header 宽度 (50pt ↔ ratio-driven width), splitters 隐藏/出现 (邻 panel 都不 visible 时), frame 高度同步插值
- **不动**: panel 内容 (collapsed 时 panel 不显示内容, 没东西要 animate; expanded 时 gutter 收回到正常宽度, 内容淡入淡出 = SwiftUI 默认)

### 范式 1.5: 折叠态视觉 (沿现有 CollapsedGutter + 新增 CollapsedHeader)

**上半 折叠态** (现有 CollapsedGutter, PanelContainer.swift line 62-84, **不动**):
```
┌──────────┐
│ folder   │ ← SF Symbol 14pt, .secondary
│          │
│          │
│          │
└──────────┘
50pt × full height, vertical
```

**下半 折叠态** (CC 新建 CollapsedHeader view, 沿 CollapsedGutter 范式):
```
┌──────────────────────────────────────────┐
│  checklist  状态                          │ ← SF Symbol 14pt 左 + 文 11pt 右, .secondary
└──────────────────────────────────────────┘
full width × 30pt, horizontal
```

**视觉一致性**:
- 上半 / 下半 都用 `Color(NSColor.controlBackgroundColor).opacity(0.6)` 背景 + `Color.secondary.opacity(0.18)` 0.5pt strokeBorder (沿 CollapsedGutter line 78-82 真值)
- 上半 SF Symbol 14pt 居中 (垂直方向), 下半 SF Symbol 14pt 左 + title 11pt 右 (水平方向, 占位 30pt 高度允许)
- 折叠态**无展开按钮** (沿老板 8/7 拍板"标题栏全删, 用功能告诉用户", 折叠 chrome 上不画展开按钮 = 双击展开已隐含范式 1.3 触发器 B)

### 范式 1.6: 折叠态持久化 (沿现有真值, **不动**)

- `PanelCollapsedState` (LayoutState.swift line 38-58) 5 bool 字段已实装
- 持久化走 `PanelStatesEnvelope.encode(collapsed:, visible:)` (LayoutShellViewModel.swift line 439-446) JSON 字符串 → `CDLayoutState.panel_states` 列 (LayoutState.swift line 6-8 真值)
- 任何 `vm.toggle(panel)` 调用自动 debounced 250ms 落盘 (LayoutShellViewModel.swift line 286-296 scheduleSave 真值)
- cold launch 走 `PanelStatesEnvelope.decode` 还原 collapsed + visible 双态 (line 448-459)
- **Q2 设计稿不重设计持久化**, 沿用真值, CC 实装 = 触发器 + 动画, 持久化 0 修改

---

## 2. CC 实装提示 (designer 不写代码, CC 翻译)

### 文件清单 (3 文件, ≤ 80 行)

1. **`Sources/WenshuApp/App.swift`** (line 263-319 LayoutMenuContent, 新增折叠子项):
   - 在现有 `ForEach(PanelID.allCases)` 之前加 `Divider()` + 折叠子项组 (沿用 panelID.isCollapsible 新属性 — 见 §2.2)
   - 新增 `panel.isCollapsible` 扩展 (App.swift 文件内或 LayoutShellViewModel.swift line 369-377 isDismissible 旁), 沿用相同 3 个 panel = true / 2 个 = false
   - 折叠菜单项标题: 新增 `vm.menuCollapseTitle(for: panel)` (沿 `menuTitle(for:)` 模式 line 231-234, 返回"折叠 X" / "展开 X")
   - keyboardShortcut = panel.menuShortcut + modifiers [.command, .option] (panelID = topLeft/topRight/bottomRight 对应 Cmd+Opt+1/3/5)

2. **`Sources/WenshuApp/Views/Layout/PanelContainer.swift`** (line 62-84 CollapsedGutter, 新增折叠态 + 双击手势):
   - `CollapsedGutter` 加 `.onTapGesture(count: 2) { LayoutShellViewModel.shared.toggle(panelID) }` (范式 1.3 触发器 B)
   - **新建** `CollapsedHeader` view, 沿 CollapsedGutter 结构, frame `LayoutSnapshot.bottomCollapsedPixels` (30pt 高), HStack SF Symbol + title 水平居中, 加同样 onTapGesture 双击展开
   - `LayoutShellView.swift` line 565 `panel(.topLeft)` 等 5 处把 `CollapsedGutter(panelID: id)` 改成: top 3 panel 用 `CollapsedGutter`, bottom 2 panel 用 `CollapsedHeader` (topCenter/bottomLeft 不可折叠不会进来, 但代码防御性加 `else { CollapsedGutter(panelID: id) }` 兜底)

3. **`Sources/WenshuApp/Views/Layout/LayoutShellView.swift`** (新增动画 + auto-collapse):
   - body 顶层加 `.animation(.easeInOut(duration: 0.2), value: vm.snapshot.collapsed)` (范式 1.4)
   - **不动** NativeSplitterView / NativeSplitter (auto-collapse 30pt 阈值沿用现有真值, CC 若要实装"拖过头自动折叠"在 NativeSplitterView.onDrag end handler 加 toggle, 但**这条隐含且复杂**, Q2 主轴是触发器 A/B, C 可留 v0.05.0 单独派单)

### 边界 (designer 硬约束)

- 不改 `LayoutState.swift` (ratios + collapsed 5 元素 + clamp 全套已实装真值, 沿 §0 矛盾 0.1-0.4)
- 不改 `LayoutShellViewModel.swift` 的 toggle / snapshot / scheduleSave (全已实装, 加新方法 `menuCollapseTitle(for:)` 可以, 改 toggle / snapshot = 越界)
- 不改 `Package.swift` / `.ws` schema / `CDLayoutState` 列
- 不写 V0Fix LayoutTests 字符串 grep (已知 V0-fix-11 修真, v0.02.1 修真 派单)
- 不测像素 (reviewer 验)
- 不引入新 SPM 依赖 (范式 1.5 视觉沿现有 SF Symbol 真值, 加 Phosphor / 其他 icon 库 = 越界)
- 不提交 (designer 不动 git commit)

### 派单卡 4 件套 sign-off

- **目标**: Q2 折叠态交互设计稿 (DESIGN-Q2-panel-collapse.md 落盘)
- **范围**: 折叠触发器 (菜单 + 双击) + 折叠动画曲线 (0.2s ease-in-out) + 折叠态视觉 (CollapsedGutter + 新增 CollapsedHeader)
- **标准**: 沿 LayoutState / LayoutShellViewModel / CollapsedGutter / V0-fix-8 真值; 折叠 vs 隐藏 双态区分清晰; 3 触发器 (菜单 / 双击 / 拖阈值) 范式明确
- **边界**: 不改 LayoutState.swift / ViewModel toggle / Package.swift / .ws schema; 不测像素; 不提交

---

## 3. 拍板真值 (本设计稿引用的所有拍板真值, 一行一个引用)

- AGENTS §8.1 (5 区 layout grammar, 6 段) — 拍板源 = 老板 8/7 实机验 + 8/10 三轮讨论
- AGENTS §3.5 §13.6 STATE.md 落点机制 — 拍板源 = 老板 8/11 19:55+20:10+20:35
- AGENTS §3.7 §3.8 designer 卡派发硬约束 — 拍板源 = 老板 8/12 (t_ca73c613 流程中断案例)
- AGENTS §11 项目基线 — 拍板源 = 老板 8/10 v0.02.0 基线
- LayoutState.swift line 38-58 PanelCollapsedState — 实装真值 (commit 8e25b3cec / f23ec3ec0 LT-01 系列)
- LayoutState.swift line 98-106 autoCollapsePixels / topCollapsedPixels / bottomCollapsedPixels — 实装真值
- LayoutShellViewModel.swift line 86-110 toggle(panel:) — 实装真值 (无 caller, Q2 触发器补)
- LayoutShellViewModel.swift line 231-234 menuTitle(for:) — 实装真值 (范本, menuCollapseTitle 沿用同模式)
- LayoutShellViewModel.swift line 369-377 isDismissible — 实装真值 (isCollapsible 沿用同模式)
- LayoutShellView.swift line 561-630 panel(_:width:) — 实装真值
- PanelContainer.swift line 62-84 CollapsedGutter — 实装真值 (范本, CollapsedHeader 沿用同结构)
- PanelStatesEnvelope encode / decode — 实装真值 (LayoutShellViewModel.swift line 433-460)
- App.swift line 263-319 LayoutCommands + LayoutMenuContent — 实装真值 (折叠子项插入点)
- V0-fix-3 (commit 92de72bc3 / 2ba89a3f3) — 实装真值 (老板 8/7 拍板"标题栏全删, 用功能告诉用户")
- V0-fix-8 (commit 4bf21faa7) — 实装真值 (0.2s ease-in-out FCP 范式)
- V0-fix-9 (commit 758df2967 / d83f02fbf) — 实装真值 (老板 8/11 16:20 红字"按钮居左, 只留 ICON")
- fcp-viewer-pattern §0 总原则 + §3.8 MVP 切片 — 老板 8/10 三轮讨论拍板

---

## 4. sign-off (designer)

DESIGN-Q2-panel-collapse.md 落盘 (主仓 Sources/WenshuApp/Views/, 沿 V0-fix 系列 doc 范式)

目标: Q2 折叠态交互范式 — 3 触发器 (菜单 / 双击 / 拖阈值) + 折叠 vs 隐藏双态区分 + 0.2s ease-in-out 动画曲线 + 上半 50pt gutter / 下半 30pt header chrome 范式, 全部沿 LayoutState / LayoutShellViewModel / CollapsedGutter / V0-fix-8 真值.

范围: 设计稿 1 份 (本文件) — 不写代码, 不改 LayoutState.swift, 不改 ViewModel toggle, 不改 .ws schema. CC 派单 = §2 文件清单 3 文件 ≤ 80 行.

标准: 1) 折叠态 vs 隐藏态 区分清晰 (§1.1 表格); 2) 5 panel 折叠分类正确 (3 可折叠 + 2 不可折叠, §1.2); 3) 3 触发器范式明确 (菜单 / 双击 / 拖阈值, §1.3); 4) 动画曲线沿 V0-fix-8 (0.2s ease-in-out, §1.4); 5) 视觉沿 CollapsedGutter 真值 + 新增 CollapsedHeader 沿同结构 (§1.5); 6) 持久化沿 PanelStatesEnvelope 真值, 0 修改 (§1.6).

边界: workspace = 主仓 dir (沿 §3.7); skills = swiftui-design-patterns + wenshu-designer-onboarding (沿 §3.7); 不做清单 = §2 边界 5 条 (不改 LayoutState / ViewModel toggle / Package.swift / .ws schema / 不测像素 / 不提交).

拍板真值: AGENTS §8.1 + §3.5/§3.7/§3.8 + LayoutState.swift 真值 (autoCollapse 30 / topCollapsed 50 / bottomCollapsed 30) + LayoutShellViewModel toggle 已实装 + fcp-viewer-pattern §0/§3.8 + V0-fix-3/8/9 + 老板 8/10 三轮讨论 FCP 范式 + 老板 8/7 实机验"标题栏全删".

§3.5 落点 (§13.6 机制, 1 行 ≤ 30 字, kanban_comment 充数): 折叠态 UI 触发器空缺 = LayoutShellViewModel.toggle 已实装无 caller, Q2 补 App.swift menu 子项 + 双击手势即可, 不改 ViewModel/LayoutState schema (沿 §0 矛盾 0.1 锁定).