// LAYOUT-APPKIT-INVENTORY.md · 文枢 (Wenshu) · v0.02.0 LT-01-fix9
//
// 老板 8/7 实机拍 "全部原生, 能不自己写的都不自己写".
// CC 必跑 30 分钟 macOS AppKit 调研, 评估 15 个 layout 相关原生 API:
//   - 适用 → 推荐替代哪个自写 SwiftUI view
//   - 不适用 → 标 "沿用 SwiftUI"
//
// 调研范围: 文枢 v0.02.0 layout shell = 1 个主窗口 + 5 区(左上/中上/右上/
// 下左/下右) + 4 条可拖动分隔条 + 折叠态 + macOS 菜单栏 + 标题栏。
//
// 每个 API 评估的依据: 是否能解决 8/7 实机验发现的 3 个症状?
//   (1) 分割线粗 (自写 SwiftUI 6px rect)
//   (2) 拖动闪动 + 不顺滑 (自写 DragGesture 每次 fire 重 render)
//   (3) 光标不变 (自写 PanelSplitter 没设 NSCursor)
// +
//   (4) macOS 全原生需求 (FCP / Pages / Numbers 风格)

# LAYOUT-APPKIT-INVENTORY · 文枢 (Wenshu)

> **v0.02.0 LT-01-fix9 · 老板 8/7 实机拍**:
> "全部原生, 能不自己写的都不自己写. 有人都做好了, 我们再费劲图啥"
>
> CC 必跑 30 分钟 macOS AppKit 调研, 列出 layout shell 相关所有原生 API,
> 每个评估"适用 → 推荐替代 / 不适用 → 沿用 SwiftUI"。

---

## 评估结果速览

| # | API | 适用度 | 替代目标 | fix9 动作 |
|---|-----|--------|---------|----------|
| 1 | NSSplitView | ✅ 高 | PanelSplitter + 上/下半 HStack/VStack | **采用** |
| 2 | NSSplitViewController | ⚠️ 中 | LayoutShellView 主 layout | **不采用** (ViewModel 重写风险) |
| 3 | NSToolbar | ❌ 低 | (无 — LT-01-fix3 已删 in-window toolbar) | **不采用** |
| 4 | NSWindow / NSWindowController / NSTitlebarAccessoryViewController | ⚠️ 中 | SwiftUI WindowGroup (已原生) | **沿用 SwiftUI** |
| 5 | NSTabView / NSTabViewController | ❌ 低 | (panel 内容 tab 留 LT-02/03/04) | **不采用** (本卡范围外) |
| 6 | NSCollectionView | ❌ 低 | (无 list 需求) | **不采用** |
| 7 | NSOutlineView | ❌ 低 | (章节树 v0.04.x 才来) | **不采用** |
| 8 | NSSearchToolbarItem / NSSearchField | ❌ 低 | (无搜索框需求) | **不采用** |
| 9 | NSPopUpButton / NSMenu | ❌ 低 | (无下拉) | **不采用** |
| 10 | NSScrollView / NSScroller | ⚠️ 中 | SwiftUI ScrollView (已原生) | **沿用 SwiftUI** |
| 11 | NSDocument / NSDocumentController | ❌ 低 | (.ws 是单文件, 不是 NSDocument 架构) | **不采用** |
| 12 | NSToolbarItem | ❌ 低 | (同 NSToolbar) | **不采用** |
| 13 | NSTouchBar | ❌ 低 | (macOS 27 Touch Bar 移除) | **不采用** |
| 14 | NSSegmentedControl | ❌ 低 | (无分段控件需求) | **不采用** |
| 15 | NSVisualEffectView | ⚠️ 中 | PanelContainer 自写 chrome | **不采用本卡** (风险收益不匹配) |
| 16 | NSAlert | ⚠️ 中 | (About panel 已用 `NSApp.orderFrontStandardAboutPanel`) | **沿用** |

**结论**: fix9 真正采用的就是 **#1 NSSplitView**。其余 14 个评估后**沿用 SwiftUI / 不采用 / 范围外**。

---

## 1. NSSplitView / NSSplitViewController — 重点评估

### 1.1 NSSplitView(✅ 采用)

**API 概览** (`developer.apple.com/documentation/appkit/nssplitview`):

- `NSSplitView` 是 AppKit 的多 pane 容器, 内置分隔条 + 拖动 + 光标。
- `dividerStyle` 枚举:
  - `.thin` — 1pt 细线 (我们目标)
  - `.thick` — 默认 9pt 粗 rect (= 自写实现的现状, 老板 不满)
  - `.paneSplitter` — FCP 风格 pane splitter
  - `.automatic` — 系统选
- 内置 drag — AppKit 渲染管线优化, 拖动时不重 render sibling view,
  不闪烁。 老板 实机验"拖动闪动 + 不顺滑"症状的根治。
- 内置 cursor — `mouseEntered` 自动设 `NSCursor.resizeLeftRight` /
  `.resizeUpDown`, 不需自写 NSCursor 管理。
- `NSSplitViewItem` — 每个 pane 包装成 `NSSplitViewItem`:
  - `isCollapsed` — 折叠态 (= 我们 LayoutShellView 的 collapsed state)
  - `canCollapse` — 是否可折叠
  - `minimumThickness` / `maximumThickness` — 最小/最大尺寸
  - `holdingPriority` — 拖动时谁先让步 (= FCP 的 spring system)

**适用 vs 不适用**:

- ✅ 适用 — 分割条 + 拖动 + cursor: 完全替代 `PanelSplitter`
  (3 个症状一次性根治)
- ✅ 适用 — 折叠态: `NSSplitViewItem.isCollapsed` 等价于我们
  `PanelCollapsedState` 的 bool
- ⚠️ 部分 — layout 状态持久化: NSSplitView 有 `autosaveName`
  (默认走 UserDefaults), 但我们**要走 .ws 文件**, 不能用 autosaveName。
  修法: `NSSplitViewDelegate.splitViewDidResizeSubviews(_:)` 回调里
  读 NSSplitView 的 frame → 转成 ratios → 调 ViewModel
  `adjustXxx(...)` → ViewModel 写 .ws (debounced 250ms)。
- ⚠️ 部分 — 拖动 threshold: NSSplitView 的内置 drag **没有**
  `minimumDistance` 概念 (= 我们 `DragGesture(minimumDistance: 1)`
  + 5px click threshold 的根因 fix7 复杂度)。 但 NSSplitView 的内置
  drag 是"鼠标按住 + 拖"才动, 单击不会动 — 90:10 BUG 在
  NSSplitView 上不复现。**这个对比说明 fix7 那套 5px threshold
  全是绕路: 直接用 NSSplitView 就没这问题**。

**fix9 行动**:

- 用 `NSSplitView` 包装成 `NSViewRepresentable` (`NativeSplitter`)
- 替代 `PanelSplitter` 的拖动回调接口 (= `onDrag: (CGFloat) -> Void`)
- dividerStyle = `.thin` (1pt, 不是 6px)
- 不动 LayoutShellViewModel 的 `adjustXxx` API (drag delta 还是
  pixel-level, ViewModel 负责转 ratio + clamp + persist)
- `SplitterDragPolicy` / `SplitterClickDetector` 5px threshold —
  **保留作防御性兜底**: 即便 NSSplitView 不该有这问题, View 层
  在 delta < 5px 时仍不调 `onDrag` (= fix9 留 safety net,
  不破坏 fix7 测试 contract)

### 1.2 NSSplitViewController(⚠️ 不采用本卡)

**API 概览** (`developer.apple.com/documentation/appkit/nssplitviewcontroller`):

- `NSSplitViewController` 是 `NSSplitView` + 自动管理的 viewController
  子类。 每个 pane 是个独立 `NSViewController`, 自动 life cycle。
- macOS 14+ 新增 `toggleSidebar(_:)` 等方法 (跟 SwiftUI
  `.commands` 集成)。

**不采用原因**:

- 完全重写 LayoutShellView → NSSplitViewController → 5 个 NSViewController
  (每个 pane) → 每个 pane 里再嵌 NSHostingController 包 SwiftUI。
  这是 v0.02.0 LT-01 整个 layout shell 的**架构重写**。
- ViewModel 与 NSSplitView 双向同步更复杂: ViewModel 改 ratios
  → 需要把 ratio 算成 NSSplitViewItem 宽度 → setPosition,
  而 NSSplitView 拖动又会改 setPosition → delegate 回调又改 ratios。
  这种**双向绑定容易出循环依赖** (= fix7 类 BUG 重现风险)。
- 派单 prompt 列的 fix9 边界"会有改 LayoutShellView.swift"已经
  标"会有", 不是必改。 主 layout 走 NSSplitViewController
  是**LT-01-fix10+ 的大重构**, 不是 fix9 这一卡的范围。
- fix9 的真值是"用 NSSplitView 解决 3 个症状", 不是"重写 layout
  shell 架构"。

**fix9 行动**:

- LayoutShellView 的 VStack/HStack 结构**保留**(几何算法在
  LayoutMetrics 已写好, 不动)
- 只替换 4 个 `PanelSplitter(...)` → `NativeSplitter(...)`
  (drop-in 替换, onDrag 回调接口一致)
- 装机器 user 实机验看到的效果: 分割线细细一条 / 拖动丝滑 /
  光标变 resize。 跟 NSSplitViewController 重写**视觉效果一样**,
  但代码改动量小一个数量级。

---

## 2. NSToolbar — 不采用

**API 概览**: macOS 原生顶部 toolbar 容器, 自动集成 window chrome,
支持 `NSToolbarItem` + 系统图标 + 自动本地化。

**不采用原因**:

- LT-01-fix3 已经把 in-window toolbar **删了** (老板 8/7 实机验
  + macOS HIG: toolbar 是窗口内动作栏, layout 控制走菜单栏 — 跟
  Pages / Numbers / Xcode / Final Cut 一致)。
- 我们没有 "新建项目 / 保存 / 导出" 这类 in-window toolbar 按钮
  (都在菜单栏 — File 菜单)。 NSToolbar 现在没东西可放。
- 如果未来加 action (e.g. "新建项目" 按钮), 走 NSToolbar 是对的
  (那时再评估, 不在本卡)。

**fix9 行动**: 无。 验证 `App.swift` 不含 `NSToolbar` 引用
(本来就是 0 引用, LT-01-fix3 已删)。

---

## 3. NSWindow / NSWindowController / NSTitlebarAccessoryViewController

**API 概览**: 原生窗口类, 标题栏 / traffic light / 标题栏附件区。

**评估**:

- SwiftUI `WindowGroup` + `.windowStyle(.titleBar)` 已经把
  traffic light + 标题栏全部交回 AppKit — 我们**已经是**原生
  标题栏, 不用再换。
- `NSTitlebarAccessoryViewController` 可以让 toolbar 嵌进标题栏
  (Pages / Numbers 的右上 toolbar 在标题栏), 但我们 toolbar
  已删, 没用。

**fix9 行动**: 沿用 SwiftUI `WindowGroup` + `.windowStyle(.titleBar)`。

---

## 4. NSTabView / NSTabViewController

**API 概览**: 原生 tab view, 每个 pane 一个 tab。

**评估**:

- 5 个 panel 内部各有自己的 tab (LT-02 inspector 2 tab / LT-03
  项目管理 5 tab / LT-04 聊天区 4 子 tab), 由后续子卡实装。
- LT-01 这一卡的范围只是 layout shell chrome, 不进 panel 内部。
- SwiftUI `TabView` 写起来短, 真要换 NSTabView 得每个 panel
  嵌 NSViewController, 工作量比 SwiftUI TabView 大几倍。
- v0.02.0 阶段 SwiftUI TabView 是合适的 (= LT-02/03/04 沿用
  SwiftUI 是派单边界)。

**fix9 行动**: 不采用本卡。 留 LT-02/03/04 评估。

---

## 5. NSCollectionView / NSOutlineView

**API 概览**: 原生列表 / 树形视图, 数据驱动 + 复用 cell。

**评估**:

- 文枢 v0.02.0 没有 list / 树形内容 (项目列表留 v0.01.0 re-import
  或 LT-03 实装)。
- v0.04.x 长篇工具才有关系图 / 时间线 = NSCollectionView /
  NSOutlineView 候选。

**fix9 行动**: 不采用。

---

## 6. NSSearchToolbarItem / NSSearchField

**API 概览**: 原生搜索框。

**评估**: 无搜索框需求。

**fix9 行动**: 不采用。

---

## 7. NSPopUpButton / NSMenu

**API 概览**: 原生下拉 / 菜单。

**评估**: 我们菜单走 SwiftUI `CommandMenu` (`App.swift` `WenshuAppCommands` /
`LayoutCommands`), 已经是 macOS 原生菜单栏 (= `NSMenu` 等价)。
无下拉需求。

**fix9 行动**: 不采用。

---

## 8. NSScrollView / NSScroller

**API 概览**: 原生滚动视图。

**评估**: SwiftUI `ScrollView` 在 macOS 上就是包装 `NSScrollView`,
**已经是原生**。 无需替换。

**fix9 行动**: 沿用 SwiftUI ScrollView (已经原生)。

---

## 9. NSDocument / NSDocumentController

**API 概览**: macOS 文档模型, 多窗口 + 自动 dirty / save / 版本。

**评估**:

- 文枢 = `.ws` 单文件 + 你自管跨设备 (AGENTS §7 数据资产硬约束)。
- NSDocument 架构会引入"自动保存 + 版本分支 + iCloud 集成", 这些
  **违反** AGENTS §7 的"文枢不依赖云端服务 / 不上传你的作品"。
- NSDocumentController 多窗口也不需要 — 文枢 v0.02.0 单窗口
  (主进程 + iPad/iPhone 端独立进程, 不在 v0.02.0 范围)。

**fix9 行动**: 不采用。 沿用 `WenshuStoreActor` 自己管理 .ws
(已经写好)。

---

## 10. NSToolbarItem

**API 概览**: toolbar 单项。

**评估**: 同 NSToolbar (无 toolbar 需求)。

**fix9 行动**: 不采用。

---

## 11. NSTouchBar

**API 概览**: MacBook Pro Touch Bar (2016-2024 时代, macOS 27
已移除支持)。

**评估**: macOS 27 不再支持 Touch Bar, 此 API 等于历史。

**fix9 行动**: 不采用。

---

## 12. NSSegmentedControl

**API 概览**: 分段按钮组。

**评估**: v0.02.0 无分段控件需求 (5 个 panel 的"显示 / 隐藏"
走 CommandMenu, 不是分段按钮)。

**fix9 行动**: 不采用。

---

## 13. NSVisualEffectView

**API 概览**: macOS 原生毛玻璃材质 (`NSVisualEffectMaterial.sidebar`
/ `.headerView` / `.contentBackground` 等)。

**评估**:

- PanelContainer 的 chrome 是 `Color(NSColor.windowBackgroundColor)
  .opacity(0.4)` + 0.5pt border — 自写半透明 + border, 跟
  系统 sidebar 比起来不够"macOS 标准"。
- 换 NSVisualEffectView 收益: 真 macOS sidebar 毛玻璃
  (= Finder sidebar / System Settings sidebar / Pages inspector)。
- 风险: 5 个 panel 全用 NSVisualEffectView, 视觉重量会有过重
  (FCP 风格: 仅 inspector 用 sidebar material, content 用纯背景)。
- 评估认为此改造**收益不够覆盖风险**: 这是视觉打磨, 不解决
  老板 报的 3 个症状 (分割线粗 / 拖动闪 / 光标不变)。

**fix9 行动**: 不采用本卡。 留 LT-01-fix10+ 视觉打磨评估。

---

## 14. NSAlert

**API 概览**: 原生对话框。

**评估**:

- `App.swift` `WenshuAppCommands.showAboutPanel()` 已经用
  `NSApp.orderFrontStandardAboutPanel(options:)` — 系统原生
  about panel, 不需要 `NSAlert`。
- v0.02.0 没有需要 NSAlert 的"确定 / 取消"场景。

**fix9 行动**: 沿用 (已经原生)。

---

## 决策总结

**fix9 真正改的就是 #1 NSSplitView** — 通过 `NativeSplitter`
(NSViewRepresentable 包装) 替代自写 `PanelSplitter`:

1. **分割线细细一条** — `dividerStyle = .thin` (1pt, 不再 6px)
2. **拖动丝滑无闪动** — NSSplitView 内置 AppKit 渲染管线
3. **光标自动变** — NSSplitView mouseEntered 自动设
   `NSCursor.resizeLeftRight` / `.resizeUpDown`

其余 14 个评估结论 = **沿用 SwiftUI / 不采用 / 范围外**, 不动。

**为什么不直接 NSSplitViewController 全重写**:

- ViewModel 双向同步风险高 (= fix7 类 BUG 重现风险)
- 派单边界"会有改 LayoutShellView.swift"已标"会有", 不是必改
- 主 layout 走 NSSplitViewController 是 **LT-01-fix10+ 大重构**,
  不是 fix9 这一卡的范围
- fix9 真值是"解决 3 个症状", 不是"重写 layout 架构"
- 视觉效果一样, 代码改动量小一个数量级

---

*LAYOUT-APPKIT-INVENTORY v0.02.0 · 2026-08-07 LT-01-fix9 CC AppKit 调研*
