# ADR-0007: Layout shell 范式 — HStack + 自写 NativeSplitter(view)

> Status: accepted
> Date: 2026-08-19
> Decision-maker(s): 老板 (2026-08-19 ticket 005 拍板)
> Supersedes: ADR-0003 (drag-splitter-nsview)

## Context

v0.10 ~ v0.14 LayoutShellView 用 Canvas 重画 (TimelineView(.animation) 60 fps GPU 渲染) + 6 个 NSView overlay 透明 hit area 接 drag 事件 (v0.10 NativeSplitterView NSView 路线, ADR-0003 mandate)。

v0.14 引入 `NativeSplitter.swift` (View 组件, DragGesture + .pointerStyle + hover 4 PT accent capsule, Apple HIG 官方 API), 但 v0.14.1 退回去 Canvas + NSView overlay, 把 hover/drag 视觉全丢了 (老板 2026-08-19 反馈)。

老板 2026-08-19 拍板: 改回 Apple HIG 真值范式 — HStack + 自写 NativeSplitter(view)。理由:
1. **HSplitView / VSplitView** divider 颜色改不了 (公开已知限制, StackOverflow 长期已知)
2. **NavigationSplitView** 是 3 列导航范式, 跟 Sketch 6 区布局不对应
3. **Canvas + NSView overlay** 在 SwiftUI 顶层 window 有 cursor 跨边界 + drag 闪烁问题 (Canvas 不响应 hover, NSView cursor 不透到 SwiftUI), v0.14.1 翻车链根因

## Decision

6 区 layout 用 Apple HIG HStack 范式:

```
VStack(spacing: 0) {
    UpperBandZone()  // HStack(spacing: 0) { 4 zone + 3 NativeSplitter(view) }
    NativeSplitter(orientation: .horizontal, ...)  // D_h 横拖拽线
    LowerBandZone()  // HStack(spacing: 0) { 2 zone + 1 NativeSplitter(view) }
}
```

- 标题栏 = macOS `.windowStyle(.titleBar)` 52 PT unified chrome (取代 v0.14.1 Canvas 重画 + 自写 TitleBarZone, 老板 2026-08-19 拍)
- 区域组件 = SwiftUI view tree (ZoneModule = VStack { ZoneTopToolbar; content; ZoneBottomToolbar }), 不用 Canvas 重画
- 拖拽线 = `NativeSplitter.swift` v0.14 完整版 (1 组件 + `SplitterOrientation` enum), 改 1 处 = 6 拖拽线全改

## Consequences

- 改 1 处 = 6 拖拽线全响应 (NativeSplitter 1 组件 + orientation 参数)
- hover/drag/cursor 视觉全恢复 (v0.14.1 丢的 hover 4 PT accent capsule + DragGesture + .pointerStyle)
- 标题栏双层消失 (Canvas 重画 + macOS chrome 双层 → macOS chrome 单层)
- 响应式 = GeometryReader × 比例算子 × 实 PT (LayoutTokens.bandRatio / toolbarRatio / editorVerticalInsetRatio), 任何窗口大小 1:1 自适应
- Apple HIG 真值: PointerStyle.columnResize / .rowResize (macOS 15+) + DragGesture + .drawingGroup() + .clipShape(.capsule) + .shadow(color:opacity:radius:)

## Alternatives considered (历史)

- **HSplitView / VSplitView** (Apple 官方 macOS 10.15+ Split Views) — 拒绝, divider 颜色改不了
- **NavigationSplitView** (Apple 官方 macOS 13+) — 拒绝, 3 列导航范式跟 Sketch 6 区不对应
- **Canvas + NSView overlay** (v0.14.1 路线) — 拒绝, cursor 跨边界 + drag 闪烁 + hover 全丢
- **NSView + NSEvent.mouseDragged** (v0.10 路线) — 拒绝, 跟直接 Canvas + NSView overlay 等价问题
- **SwiftUI Layout 协议 (custom)** — 拒绝, 过度设计, 6 master 简单 case 不需
