# Backlog — 拖拽线/分割线视觉细节 (老板 2026-08-19 拍)

> 此文件记录老板拍过但当前 ticket 不动 / 等排期的需求.

## Backlog 01 — 取消"圆头"设计 (Rectangle .clipShape(.capsule))

**来源**: 老板 2026-08-19 16:50 拍板

**原话**: "取消早期实的拖拽线, 分割先圆头的要求"

**当前实现**:
- NativeSplitter.swift: `Rectangle().fill(...).frame(...).clipShape(.capsule)` — 矩形 + capsule 圆角 = 视觉圆头
- StaticDividerHorizontal / StaticDividerVertical: 同样 `Rectangle().clipShape(.capsule)`

**真值源 (Sketch AF7B1C87)**: 待 mcp__sketch__run_code 确认 Sketch master 是否为圆角或直角

**目标修法 (待拍)**:
- 选项 A: 删 `.clipShape(.capsule)` → 普通矩形 (Apple HIG 标准 divider 风格)
- 选项 B: 保留 `.clipShape(.capsule)` 但老板拍板 (override 真值)
- 选项 C: 其他 (待老板画图)

**Acceptance criteria** (待 grill 拍板):
- 6 根拖拽线 + 静态分割线 (StaticDividerHorizontal / Vertical) 视觉一致
- 1:1 落 Sketch master
- 不破已实现的拖拽交互
- swift build exit 0

**优先级**: 中 (视觉风格, 非功能)

**Blocked by**: 老板画图 / mcp__sketch__run_code 确认

**Status**: backlog

## Backlog 02 — cursor 不变 (v0.16 ticket 03 + 03.2 + ticket 06 都未真切)

**来源**: 老板 2026-08-19 反复反馈

**当前实现**:
- NativeSplitter.resetCursorRects() 已 commit (v0.16 ticket 03)
- WenshuCursorController NSResponder + NSTrackingArea.mouseMoved + hit test (ticket 06 commit 096b9cb)
- 实测不切 (老板 8/19 18:14 反馈, 整个 wenshu window 边/角也不切, NSHostingView 完全屏蔽 AppKit cursor 系统)
- 老板 8/19 18:15 提议: 查 macOS 27 SwiftUI + AppKit integration cursor 真值 (deleg_6ea687d8 后台查文档中)

**目标修法 (待真因 + 拍板)**:
- 选项 A: 不用 NSViewRepresentable, 全部用 SwiftUI + .onContinuousHover + custom drag (大改动, ticket 03 实测 SwiftUI DragGesture 失灵, 不走)
- 选项 B: NSWindow 子类化 (Q15 拍 A 但 SwiftUI WindowGroup 创建的 window 是 private class 不可改 type, 不可行)
- 选项 C: 待 deleg_6ea687d8 Apple 真值文档查证结果决定

**Acceptance criteria**:
- 鼠标移上 D_h → cursor 变上下箭头
- 鼠标移上 D_v → cursor 变左右箭头
- 鼠标离开拖拽线 → cursor 还原
- 拖拽期间 cursor 保持
- 跟 Pages / Numbers / Xcode 手感一致 (伪 Apple 官方)
- wenshu window 边/角 resize cursor 也要 work (整体 AppKit cursor 系统恢复)

**优先级**: 高 (基本交互, wenshu 整个 cursor 系统失灵)

**Blocked by**: deleg_6ea687d8 Apple 真值文档查证

**Status**: 查文档中, 等结果

## Backlog 03 — 拖拽线静态色 Color.black → Color(nsColor: .separatorColor)

**来源**: 老板 2026-08-19 18:15 macOS 系统设置截图触发, 我提议

**当前实现**:
- NativeSplitter.swift: `Rectangle().fill(isHovered ? Color.accentColor.opacity(0.25) : Color.black)` — 静态线纯黑
- StaticDividerHorizontal / Vertical: 同样 `Color.black`

**修法方向 (待老板拍)**:
- 改 `Color.black` → `Color(nsColor: .separatorColor)` (Apple HIG 系统 divider 色, dark / light 自动适配)
- Apple HIG 8/19 老板 8/18 拍 "wenshu design baseline 全部 Apple semantic API" (Color.accentColor, .secondary, .background, .tertiary 等)
- 0 RGB 硬编码, 0 opacity 硬编码 (AGENTS.md §11 项目基线)

**Acceptance criteria**:
- 6 根拖拽线 + 静态分割线 视觉一致
- macOS 切 dark / light mode 自动适配
- 1:1 落 Sketch master
- 不破已实现的拖拽交互 + hover 蓝光
- swift build exit 0

**优先级**: 低 (视觉细节, 非功能, 但符合原则 1 伪 Apple 官方)

**Blocked by**: 老板拍

**Status**: backlog

## Backlog 04 — 其他 wenshu 静态 Color 走 NSColor semantic 审计

**来源**: 老板 2026-08-19 18:15 macOS 系统设置截图触发

**当前实现** (App.swift grep):
- L39: `Color(red: 0x1e / 255, green: 0x1e / 255, blue: 0x1e / 255)` (dynamicZoneSurface RGB 硬编码, 老板 8/18 拍 "保留设计图色值" 保护, 不动)
- L43: `Color(nsColor: .windowBackgroundColor)` ✓ Apple semantic
- L44: `Color(nsColor: .controlBackgroundColor)` ✓ Apple semantic
- L52: `Color(nsColor: .black)` (splitterLine, 应该改 .separatorColor, 见 backlog 03)

**修法方向**:
- 大部分 Color 已走 Apple semantic (✓)
- dynamicZoneSurface RGB 硬编码 (老板 8/18 拍保留, 不动)
- splitterLine Color.black (backlog 03 涵盖)

**Acceptance criteria**:
- 所有 Color 走 Apple semantic, 0 RGB 硬编码 (除老板 8/18 拍保留的 dynamicZoneSurface)
- dark / light mode 自动适配

**优先级**: 低 (审计, 多数已合规)

**Blocked by**: backlog 03 修

**Status**: backlog (合并 backlog 03 / 04 一起修)