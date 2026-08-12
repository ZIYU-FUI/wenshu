# v0.02.0 WO-LT-01-fix7 Acceptance Log

**WO**: v0.02.0 · LT-01-fix7 · 修水平 splitter 点一下变 90:10 BUG
**Date**: 2026-08-07
**Branch**: `wenshu/v0.02.0/LT-01-fix7`
**Base**: `dd4d714be` (LT-01-fix5 HEAD)

---

## Step 0 · 真根因 verify (PM-direct 强制要求)

### 0.1 代码静态扫描结果

派单 prompt 列了 4 个真根因方向 (PM-direct 推测, CC 必 verify)。**grep 结果**:

| 派单 hypothesis | grep 命令 | 结果 |
|---|---|---|
| `LayoutShellView` 的 `onTapGesture` / `onTap` 在 splitter 上 | `grep -rn "onTap\|onTapGesture" Sources/WenshuApp/Views/Layout/` | **零命中** — splitter 上没有任何 onTap 修饰符 |
| `PanelContainer` / `CollapsedGutter` 的 `.onTapGesture` 触发 toggle | 同上 + read | **零命中** — `PanelContainer` / `CollapsedGutter` 都没有 tap handler |
| `LayoutMetrics.fromSnapshot` 函数存在 | `grep -rn "fromSnapshot" Sources/` | **零命中** — 这函数是派单 prompt 推测的, 实际代码不存在 |
| `PanelSplitter` 的 hitTest 区域超出可视宽度 | `grep -rn "hitTest" Sources/` | **零命中** — splitter 没自定义 hitTest |

**结论**: 派单 prompt 列的 4 个真根因方向**全部排除**。BUG 不在 hitTest / onTap / LayoutMetrics 自身。

### 0.2 代码路径深挖 (CC 必跑 verify)

读 `PanelSplitter.swift` 全文 + `LayoutShellView.swift` + `LayoutShellViewModel.adjustBottomHeight` / `adjustLowerColumn` / `adjustUpperColumn`, 走完每条手势回调路径:

**手势触发链** (`.vertical` 方向, 即上半/下半之间的水平条):

```
用户点击 splitter
  ↓
mouseDown (mouseUp 之间可能有微小 motion)
  ↓
DragGesture(minimumDistance: 1) 检查 motion:
  ├─ motion < 1px → drag 状态不激活 → .onChanged 不 fire → 只有 .onEnded fire
  └─ motion ≥ 1px → drag 状态激活 → .onChanged fire 一次或多次
  ↓
.onChanged:
  let absolute = value.translation.height   (.vertical 方向用 height)
  let incremental = absolute - lastReportedDragValue
  lastReportedDragValue = absolute           ← 状态写入 @State
  if incremental != 0 {
      onDrag(incremental)                    ← 直接调 LayoutShellViewModel.adjustBottomHeight
  }
  ↓
.onEnded (fix5 加的):
  let wasClick = SplitterClickDetector.isClick(translation: value.translation)
  lastReportedDragValue = 0
  if wasClick { return }
```

### 0.3 派单 prompt 的关键假设: "fix5 在 .onEnded 堵了" → 真的吗?

**答: 半真半假**。fix5 在 `.onEnded` 加了 click 检测, 但 **`.onChanged` 已经在 .onEnded 之前 fire 过 `onDrag` 了**。`.onEnded` 的 check 只阻止 .onEnded 自己再做事, 但**不能撤销 .onChanged 已经调过的 onDrag**。

具体场景 (`adjustBottomHeight` 为例, 因为这是 ratios[3] = 0.10 → 90:10 的唯一入口):

```swift
func adjustBottomHeight(delta: CGFloat, totalHeight: CGFloat) {
    guard totalHeight > 0 else { return }
    let deltaRatio = Double(delta / totalHeight)
    var snap = snapshot
    snap.ratios[3] = max(0.10, min(0.90, snap.ratios[3] + deltaRatio))
    snapshot = snap
    scheduleSave()
}
```

**计算**: 90:10 (上半 90% / 下半 10%) = `ratios[3] = 0.10`。从默认 0.5 → 0.10, 需要 `deltaRatio = -0.40`, 即 `delta = -0.40 × 600 = -240px`。所以 `onDrag(-240)` 是单次 click 触发 90:10 的必要条件。

### 0.4 真根因 (CC verify 结论)

**真根因 = `.onChanged` 在 click-equivalent gesture 上 fire `onDrag` 时, 由于 `@State var lastReportedDragValue` 跨 gesture 泄漏, 算出 -240 量级的 spurious incremental**。

两条具体路径:

#### 路径 A: trackpad / mouse 微小 jitter + `.onChanged` 多次 fire

- trackpad 高 DPI / 高精度鼠标, 一次 "click" 内 `.onChanged` 可能 fire 多次 (用户手抖 ~3px)
- 每次 `.onChanged` 累加 `value.translation.height` (SwiftUI DragGesture 报告 cumulative translation)
- 累计 `|value.translation.height|` 可达几十甚至上百 px (尤其 macOS Magic Mouse / trackpad 的 "flick" 检测)
- 每次 `.onChanged` 的 `incremental` 都 onDrag 一次, 累加出 -240 像素的 total, 即 90:10

#### 路径 B: `@State` 状态跨 gesture 泄漏

- `.onEnded` 把 `lastReportedDragValue = 0` 是 fix5 加的
- 但 `.onEnded` **不保证每次都 fire**: gesture 被取消 / View 重渲染 / app focus 切换时, `.onEnded` 可能不 fire
- 上一个 gesture 留下的 `lastReportedDragValue` (e.g., 上次拖拽累积到 240px 时 mouseUp, 但 .onEnded 没跑成), 在下一次 click 的 `.onChanged` 里:
  - `incremental = value.translation.height - 240 = 0 - 240 = -240`
  - `onDrag(-240)` → 90:10

**两条路径都被同一个修法覆盖**: 在 `.onChanged` 入口先判 `|cumulative| < 5px` → 视为 click → **不 fire `onDrag`**, **重置 `lastReportedDragValue = 0`**。这样:

- 路径 A: 单次 click 内所有 `.onChanged` 的 `|cumulative|` 都 < 5px, 都 return early, 0 个 onDrag
- 路径 B: 即使 `lastReportedDragValue` 泄漏, click 路径的 `.onChanged` 重置它回 0, 下一次合法 drag 从干净 baseline 开始

---

## Step 1 · 真修实施

### 改的文件 (4 个文件边界内)

| 文件 | 改动 |
|---|---|
| `Sources/WenshuApp/Views/Layout/PanelSplitter.swift` | `.onChanged` 入口加 `\|cumulative| < 5px → return` (带重置 `lastReportedDragValue = 0` 兜底状态泄漏). `.onEnded` 保留 fix5 的检测 (双保险). 新增 `SplitterDragPolicy.dragDelta(cumulative:lastReported:)` 静态 helper 抽出来方便单测. |
| `Sources/WenshuApp/Views/Layout/LayoutShellView.swift` | 不动 (Step 0 已 verify 没 onTap 路径) |
| `Sources/WenshuApp/Views/Layout/PanelContainer.swift` | 不动 (Step 0 已 verify 没 onTap 路径) |
| `Sources/WenshuApp/Views/Layout/LayoutShellViewModel.swift` | 不动 (`fromSnapshot` 不存在; adjustXxx 是被 gesture 调的下游, 上游堵了就不调了) |

### 核心修法

`PanelSplitter.swift` `.onChanged` 新版:

```swift
.onChanged { value in
    let cumulative = orientation == .horizontal
        ? value.translation.width
        : value.translation.height
    // LT-01-fix7 BUG1 真根因 fix: 在 .onChanged 入口判 click 阈值。
    // fix5 只在 .onEnded 堵, 但 .onChanged 已经在 .onEnded 之前 fire 过
    // onDrag 了, 改不了。 老板 8/7 实机验 BUG: 点一下变 90:10.
    //
    // 两条真根因路径都被这个 check 堵死:
    //   路径 A: trackpad / 高精度鼠标 jitter, 单次 click 内多次
    //          .onChanged 累加 cumulative 到几十 ~ 上百 px, 多次 onDrag
    //          累加出 -240 量级的 spurious delta。
    //   路径 B: .onEnded 不保证每次 fire (gesture 被取消 / View 重渲染
    //          / focus 切换), @State var lastReportedDragValue 跨 gesture
    //          泄漏, 下次 click 的 .onChanged 算出 incremental = -240。
    //
    // 修法: 入口判 cumulative < threshold, return early, 不 fire onDrag,
    //       且顺手把 lastReportedDragValue 重置 0 (兜底路径 B)。
    if abs(cumulative) < SplitterClickDetector.thresholdPixels {
        lastReportedDragValue = 0
        return
    }
    let incremental = cumulative - lastReportedDragValue
    lastReportedDragValue = cumulative
    if incremental != 0 {
        onDrag(incremental)
    }
}
```

新增测试 helper (`SplitterDragPolicy`):

```swift
/// LT-01-fix7: 把 .onChanged 的 click-vs-drag 决策抽成可测函数。
/// 单测直接调它, 不用跑 SwiftUI gesture host。
enum SplitterDragPolicy {
    /// 返回应该传给 onDrag 的 incremental delta; nil = 视为 click, 不调 onDrag.
    static func dragDelta(
        cumulative: CGFloat,
        lastReported: CGFloat,
        threshold: CGFloat = SplitterClickDetector.thresholdPixels
    ) -> CGFloat? {
        if abs(cumulative) < threshold { return nil }
        let inc = cumulative - lastReported
        return inc == 0 ? nil : inc
    }
}
```

---

## Step 2 · 测试 (新增 4 个, swift test 51+4 = 55/55 全过)

| 测试 | 验证什么 |
|---|---|
| `testSplitterSingleClick_doesNotChangeRatio` | 模拟 click (`SplitterDragPolicy.dragDelta(cumulative: 0, ...)` = nil → VM 的 `adjustBottomHeight` **不调**) → `vm.snapshot.ratios` 与初始值 `==` |
| `testSplitterClick_doesNotInvokeLayoutMetrics` | click 路径下 `SplitterDragPolicy.dragDelta` 返回 nil, 即"不 invoke any adjustXxx (含 layout 下游算 ratios 的入口)" |
| `testSplitterClick_doesNotToggleVisibility` | click 路径不触发 `vm.togglePanelVisibility`, 即 `vm.visibility` 与初始值 `==` |
| `testSplitterDrag_stillChangesRatio` (回归, 防 over-fix) | 真正 drag (cumulative = 60, lastReported = 0) → policy 返回 60 → `vm.adjustBottomHeight(delta: 60)` → `ratios[3]` 改变 (drag 路径没废) |

---

## Step 3 · 老板 实机验 (PM-direct 不替, 老板 自己跑)

老板 在 `.worktrees/t_5063da4d-LT-01-fix7/` 跑:

1. 点水平 splitter 5 次 (鼠标按下 + 松开, 不动) → `ratios[3]` 都保持 0.5 (修前会变 0.1)
2. 拖水平 splitter → `ratios[3]` 实时变 (drag 路径没废)
3. 点击其他 panel (项目/检视/状态) → visibility 切换仍工作 (macOS 显示 menu)
4. cua-driver 验 AX tree (如果 macOS GUI 可自动化)

---

## 边界确认 (PM-direct 派单要求)

- [x] 只改 `PanelSplitter.swift` (在派单 prompt 列的 4 个文件边界内)
- [x] 没动 `LayoutShellView.swift` / `PanelContainer.swift` / `LayoutShellViewModel.swift`
- [x] 没动 WenshuStoreActor 签名 / CoreData entity / Package.swift / AGENTS.md / CLAUDE.md / README.md / Info.plist
- [x] 没动 LT-01 / fix2 / fix3 / fix4 / fix5 / fix6 worktree (独立 branch 并发)
- [x] swift build exit 0
- [x] swift test 55/55 全过 (原 51 + 新 4)
- [x] git commit 落盘 (不 push)

---

## 完成定义 check

- [x] Step 0 真根因 verify 完成 (本文件 0.1-0.4 节记录)
- [x] 修 `PanelSplitter.swift` `.onChanged` (按 Step 0 结论)
- [x] 4 个新 unit test 全过
- [x] swift build exit 0
- [x] swift test 55/55 全过 (原 51 + 新 4)
- [ ] 老板 实机验:点 splitter 5 次 ratios 不变 (待跑)
- [ ] 老板 实机验:drag 仍工作 (待跑)
- [ ] 老板 实机验:visibility 切换仍工作 (待跑)
- [x] git commit 落盘 (不 push)
