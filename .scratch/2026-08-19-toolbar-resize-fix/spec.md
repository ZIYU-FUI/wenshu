# Spec — Toolbar 宽度由 VStack stretch 撑 zone 实际宽度 (v0.16 ticket 01)

> Date: 2026-08-19
> 真值源: wenshu-pocock-workflow skill Q20 + macOS-only 死原则

## Problem Statement

老板 2026-08-19 拍 "区域模块组件实现的有问题, 顶栏/底栏放在区域模块内, 随区域模块尺寸变化"

现状: NativeSplitter 用父 band 全宽 `totalW` (LayoutShellView 传进), 但每个 zone 实际宽度不同 (200/400/520/794/1518/400 PT) — toolbar 画穿 splitter 溢出到隔壁 zone。

## Solution

业务语言描述:
- 顶栏 / 底栏不放固定宽度, 不传宽度参数
- 改用 macOS 系统 SwiftUI VStack 子 view 默认 stretch 全宽, 自动撑到 zone 实际宽度
- toolbar 高度仍然 30 PT 写死, ICON 18 PT / 占位文字 13 PT / 分割线 2 PT 全保持

## User Stories

1. As 老板, I want 顶栏 / 底栏在每个区域模块内独立渲染, 不画穿 splitter
2. As 老板, I want 拖拽 D_v 改 zone 宽度时, 顶栏 / 底栏跟着缩
3. As 老板, I want toolbar 视觉 (高度 / 字号 / 分割线) 全保持

## Implementation Decisions

- ZoneTopToolbar / ZoneBottomToolbar 删 `totalW: CGFloat` 参数
- 内部不 `.frame(width:)` (让 VStack 子 view 默认 stretch)
- 高度 30 PT / 18 PT ICON / 13 PT 占位文字 / 2 PT 分割线 全保持

## Implementation

- Sources/WenshuApp/App.swift: ZoneTopToolbar 改 `iconNames: [String]`, ZoneBottomToolbar 改 `var body: some View`
- Sources/WenshuApp/App.swift: LayoutShellView VStack 调用 `ZoneTopToolbar(iconNames: [...])` + `ZoneBottomToolbar()`, 不传 totalW
- Sources/WenshuApp/App.swift: UpperBandZone / LowerBandZone / ZoneModule 调用方不变 (ZoneModule 仍接 totalW 传进 toolbar)

## Testing Decisions

- 仅 `swift build clean` (exit 0), 老板自己启 app 验

## Out of Scope

- 不重写 NativeSplitter
- 不改 toolbar 高度 30 PT
- 不改 ICON 18 PT / 占位文字 13 PT / 分割线 2 PT
- 不动 macOS chrome / LayoutTokens / bandH

## Further Notes

- v0.16 ticket 01 commit ae5bbf82e + 4d9b2968e (注释清理) 已实现
- 老板 8/19 验过 pass