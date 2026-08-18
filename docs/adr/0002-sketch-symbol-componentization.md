# ADR-0002: Sketch 6 master 组件化 1:1 落 SwiftUI

> Status: accepted
> Date: 2026-08-18
> Decision-maker(s): 老板 (8/18)

## Context

老板 8/18 拍 Sketch SymbolInstance 组件化设计稿 = 6 master + 13 instance 真值, 不是 v0.07 那种"按 group frame 拍"散装 layout. SwiftUI 落地直接对应每个 master 写一个子组件, 每个 instance 用子组件 + .frame(width:height:) 1:1 落 PT 真值.

## Decision

6 个 SwiftUI 子组件 (1:1 对应 6 master):
- `TitleBarZone` (1920×39)
- `ZoneTopToolbar` (758×30)
- `ZoneBottomToolbar` (200×30)
- `ZoneModule` (200×472, 主容器, 接受 6 个 slot)
- `VerticalDragSplitter` (1×472, 居中 1 PT 视觉线, 6 PT hit area)
- `HorizontalDragSplitter` (1920×1)

`ZoneModule` 用 `ZoneSlot` enum 6 case 复用同个 master, 每个 slot 切换内容层.

## Consequences

- 任何 zone 改动只影响 ZoneModule 一个 switch case
- Splitter 改动只影响 NativeSplitter.swift 一个文件
- 屏缩放时 ZoneModule 内部 30 + 412 + 30 = 472 PT 硬编码, 改屏需重新算 spec

## Alternatives considered

- HSplitView / VSplitView — 拒绝, 不暴露 cursor / hover / divider 颜色 hook
- NSSplitView (NSViewRepresentable) — 拒绝, hit area + visual line 都要手画, 跟直接手画 NSView 等价
- SwiftUI Layout 协议 (custom) — 拒绝, 过度设计, 6 个 master 简单 case 不需
