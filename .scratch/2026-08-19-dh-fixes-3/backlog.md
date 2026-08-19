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
- 实测不切 (老板 8/19 16:50 截图)
- 猜测真因: NSViewRepresentable 桥接时 NSView 在 SwiftUI view tree 是 CALayer 包装, macOS 27 cursor rects 系统不识别

**目标修法 (待拍)**:
- 选项 A: NSWindow 子类化 + cursorUpdate (Apple HIG macOS 真值, 大改动, 跟 Pages / Numbers / Xcode 一样)
- 选项 B: NSCursor 自定义 image (中等改动)
- 选项 C: 测其他 NSView 真值 (Apple 推荐 private API / 子类化)

**Acceptance criteria**:
- 鼠标移上 D_h → cursor 变上下箭头
- 鼠标移上 D_v → cursor 变左右箭头
- 鼠标离开拖拽线 → cursor 还原
- 拖拽期间 cursor 保持
- 跟 Pages / Numbers / Xcode 手感一致 (伪 Apple 官方)

**优先级**: 高 (基本交互)

**Blocked by**: 待拍修法方向

**Status**: spec 写好 (.scratch/2026-08-19-dh-fixes-3/issues/03-cursor-flip.md)