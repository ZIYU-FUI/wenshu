# 03 — cursor 切上下 / 左右箭头 (NSWindow 子类化 + cursorUpdate, 待拍)

**What to build:**
老板 2026-08-19 实测: 鼠标移上 D_h 拖拽线不变上下箭头, 移上 D_v 拖拽线不变左右箭头.

**Blocked by:** ticket 02 (老板先验 hover 修法)

**Status:** TBD — 待老板拍修法方向

## 已知真因

- `NSView.resetCursorRects()` 已 commit (ticket 03), 实测不切 (老板 8/19)
- 猜测: NSViewRepresentable 桥接时 NSView 在 SwiftUI view tree 是 CALayer 包装, macOS 27 cursor rects 系统不识别
- 替代真值: NSWindow 子类化 + `cursorUpdate(with:)` (Apple HIG macOS 真值, 跟 Pages / Numbers / Xcode 一样)

## 待 grill

- A: NSWindow 子类化 + cursorUpdate (大改动, 符合伪 Apple 官方原则)
- B: NSCursor 自定义 image (中等改动, 不依赖系统 NSCursor)
- C: 其他 Apple HIG 范式

## Acceptance criteria

- 鼠标移上 D_h → cursor 变上下箭头 (NSCursor.resizeUpDown / .rowResize 视觉)
- 鼠标移上 D_v → cursor 变左右箭头 (NSCursor.resizeLeftRight / .columnResize 视觉)
- 鼠标离开拖拽线 → cursor 还原
- 拖拽期间 cursor 保持 (不能 reset)
- 不破坏其他交互

## Out of Scope

- 不重写 SplitterHitArea NSView 子类 (v0.16 ticket 03 已拍板)
- 不改 6 PT hit area
- 不改 hover 视觉