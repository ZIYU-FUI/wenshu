# 03 — cursor 切上下 / 左右箭头 (SwiftUI .pointerStyle 退回, 老板 2026-08-19 拍)

**What to build:**
老板 2026-08-19 反馈 "鼠标没变" 反复. 真因报告 v2 实证: NSHostingView 不 override resetCursorRects, ticket 03 + ticket 06 范式错 (AppKit cursor rects 范式不该 work 在 SwiftUI WindowGroup 上下文).
老板 2026-08-19 19:30 Q28 拍 "cursor 必须切 + 业务语言描述, 不动底层框架代码".

业务语言描述 (老板懂):
- 之前为了 cursor 加的 "NSResponder + NSTrackingArea + hit test" 底层补丁 (WenshuCursorController 整个类 + contentView.hitTest 等) 都是底层框架代码, 这些是错误的尝试
- 改用 SwiftUI 官方 cursor 切换 API: `.pointerStyle(.columnResize() / .rowResize())` 挂到拖拽线最外层 (老板 v0.14 失灵真因是挂错位置, 不是 API bug)
- Pages / Numbers / Xcode 用的就是这套 (Apple HIG macOS 15+ 标准)
- 拖拽线代码 100% 不动 (visual + hover + drag + hit area 全保持)
- 只加 1 行 SwiftUI cursor 修饰 + 删底层补丁代码 (WenshuCursorController + findSplitter)

**Blocked by:** None

**Status:** ready-for-agent → impl done → 等老板验

## Acceptance criteria

- [ ] NativeSplitter body ZStack 加 `.pointerStyle(orientation == .vertical ? .columnResize() : .rowResize())` 挂到最外层 (Rectangle + SplitterHitAreaRepresentable 的 ZStack 父级)
- [ ] 鼠标移上 D_h 拖拽线 → cursor 变 ↕ 上下箭头 (NSCursor.rowResize / SwiftUI .rowResize 真值)
- [ ] 鼠标移上 D_v 5 竖拖拽线 → cursor 变 ↔ 左右箭头 (NSCursor.columnResize / SwiftUI .columnResize 真值)
- [ ] 鼠标离开拖拽线 → cursor 还原
- [ ] 拖拽线拖动 / hover 蓝光 / hit area / 1 PT fill 视觉 全保持
- [ ] 删除 WenshuCursorController NSResponder 整个类 (App.swift L249-321 整块)
- [ ] 删除 WenshuAppDelegate.cursorController 属性 + applicationDidFinishLaunching 里 cursorController = WenshuCursorController(window: window) (App.swift L224-237 整块)
- [ ] 删除 NativeSplitter.resetCursorRects (NSView 屏蔽 cursor rects, 真因报告 v2 实证)
- [ ] 删 cursorController + WenshuCursorController 后 swift build exit 0
- [ ] 不动 macOS chrome 52 PT / LayoutTokens / bandH / toolbar 宽度
- [ ] 不动菜单栏 (backlog 07 待拍)

## 真因 (cursor-investigation-report-v2.md)

- NSHostingView (macOS 27 SDK swiftinterface 实证) 不 override `resetCursorRects()`, 同时 override `hitTest` / `mouseMoved` / `cursorUpdate`
- 这屏蔽 AppKit cursor rects 范式在 SwiftUI 子树内的工作 (ticket 03 + ticket 06 范式错, 不是代码 bug)
- 推荐: 退回 SwiftUI `.pointerStyle` 不走 NSViewRepresentable (Apple HIG macOS 15+ 标准)

## 业务语言描述修法 (老板懂)

- 拖拽线加 1 行 SwiftUI 官方 cursor 切换 (跟 Pages / Numbers 一样)
- 删之前为了 cursor 加的底层补丁代码 (WenshuCursorController 等)
- 拖拽线视觉 / hover 蓝光 / 拖动响应 / hit area 100% 不动

## Implementation Decisions

- NativeSplitter body L153 `.frame(width: outerWidth, height: outerHeight)` 链最后加 `.pointerStyle(...)`
- orientation == .vertical → `.columnResize()`, 否则 → `.rowResize()`
- macOS 15+ API (PointerStyle.columnResize(directions:) / .rowResize(directions:))
- WenshuApp.swift 删 WenshuCursorController 类 + WenshuAppDelegate.cursorController 相关 5 行
- NativeSplitter.swift 删 SplitterHitArea.resetCursorRects 整块 (L86-90)
- 保留 SplitterHitArea mouseDown/mouseDragged/mouseUp/mouseEntered/mouseExited (拖拽 + hover 蓝光用)

## Testing Decisions

- 仅 `swift build clean` (exit 0), 老板自己启 app 验
- 验证: 鼠标移上 D_h 切 ↕, 移上 D_v 切 ↔

## Out of Scope

- 不重写拖拽线视觉 (Rectangle + 1 PT fill + Apple 系统色保留)
- 不动 macOS chrome / LayoutTokens / bandH / toolbar 宽度
- 不动菜单栏 (backlog 07 待查文档)
- 不重写 SplitterHitArea NSView (拖拽 + hover 蓝光保留)

## Further Notes

- 老板 v0.14 失灵真因是挂错位置 (gesture chain), 这次挂到 ZStack 最外层 (Rectangle + NSViewRepresentable 父级)
- cursor-investigation-report-v2.md 推荐方案 A
- 跟 ticket 06 (commit 096b9cb) 撤回大部分 (WenshuCursorController 整个删)
- 跟 ticket 03 (commit de0f6ec) 撤回 resetCursorRects 整块