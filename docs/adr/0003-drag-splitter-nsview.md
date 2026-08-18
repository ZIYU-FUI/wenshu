# ADR-0003: 拖拽线走 NSView + NSEvent.delta 增量

> Status: accepted
> Date: 2026-08-18
> Decision-maker(s): 老板 (8/18)

## Context

老板 8/18 拍 "拖拽线少两根没有落地". v0.07 之前 5 拖拽线 (Library/Editor/Inspector/Chat/Console/Status) 用 SwiftUI NSSplitView, 但 Apple 不暴露 divider 颜色 / hit area 厚度 / cursor hook, 跟老板设计稿 1 PT 细线不符.

## Decision

6 拖拽线 (5 竖 + 1 横) 全部手画 NSView, 桥接 SwiftUI:
- `NativeSplitterView: NSView` (Public AppKit, macOS 27.0 验证) — 完整 mouseDown / mouseDragged / mouseUp + NSCursor.resize* + draw 1 PT 黑线
- `NativeSplitter: NSViewRepresentable` — SwiftUI 桥
- `VerticalDragSplitter` / `HorizontalDragSplitter` — 用例 wrapper, 接受 height / width 走 .frame 落 PT 真值

拖拽回调走 `NSEvent.deltaX` / `NSEvent.deltaY` 增量, 不累积 (= 不会漂移). v0.08 阶段 onDrag 空 closure (VM 拖拽状态未持久化), 等 v0.09 接 VM 时再补.

## Consequences

- 6 拖拽线 1:1 落, hit area 6 PT, 视觉线 1 PT, 老板可拖
- VM 拖拽状态 v0.09 之前不持久化, 拖动视觉会回弹
- 不可拖拽分割线 (StaticDivider) 走 SwiftUI Divider / Color.frame, 不与拖拽线耦合

## Alternatives considered

- HSplitView / VSplitView (SwiftUI) — 拒绝, 不暴露 hook
- NSSplitView (AppKit) — 拒绝, hit area / divider 颜色不能改
- SwiftUI DragGesture — 拒绝, 跨 SwiftUI render 拖拽会闪烁
