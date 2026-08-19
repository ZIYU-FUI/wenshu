# 01 — 重写 NativeSplitter 用 NSView + NSEvent (Apple AppKit 真值范式)

**What to build:**
老板 2026-08-19 拍 "伪 Apple 官方 APP" + 历史 v0.14.0 commit message TODO (D_h 不能拖 / D_v5 不能拖 / cursor 不变形) — 重写 NativeSplitter 用 NSView + NSEvent AppKit 范式 (跟 Xcode / Pages / Numbers 一致).

改完:
- D_h / D_v5 / D_v 1-4 共 6 根拖拽线 mouseDown/mouseDragged/mouseUp 走 NSView 真值 AppKit 事件流
- cursor 切 (鼠标移上去 NSCursor.push resizeLeftRight / resizeUpDown, 不需点击)
- 拖动跟手 60 fps (绕过 SwiftUI gesture 系统, 走 NSEvent.delta 直接回调 vm.adjust / vm.adjustBandSplit)
- hover 蓝光视觉保留 (SwiftUI Rectangle 在 NativeSplitter body 内, NSViewRepresentable 透明 hit area overlay)
- 范围 / 公式 / 视觉 / hit area 厚度 全不变 (继承 v0.16 ticket 02 + v0.15 ticket 014 拍板)

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

## Acceptance criteria

- [ ] SplitterHitArea: NSView 子类 (透明 hit area, mouseDown/Down/Up + NSTrackingArea hover)
- [ ] SplitterHitAreaRepresentable: NSViewRepresentable 桥接 (makeNSView + updateNSView)
- [ ] NativeSplitter: SwiftUI Rectangle 视觉 + ZStack 内 SplitterHitAreaRepresentable 透明 overlay
- [ ] D_h 横拖拽线 mouseDragged → callback 到 LayoutShellView → vm.adjustBandSplit mutate → @Observable 重渲染 → 上/下区域比例实时变化
- [ ] D_v 5 竖拖拽线 (含 D_v5 聊天/动态) mouseDragged → callback → vm.adjust mutate → zone 宽度变化
- [ ] 6 根拖拽线 cursor 切换正常 (vertical = resizeLeftRight, horizontal = resizeUpDown)
- [ ] hover 视觉保留 (Rectangle 2 PT 黑 → 4 PT accent + shadow)
- [ ] hit area 厚度 6 PT 不变
- [ ] 范围 / 公式 / VM 不变 (继承 v0.16 ticket 02 + v0.15 ticket 014)
- [ ] macOS chrome / LayoutTokens / bandH 比例算子 / toolbar 宽度 全不动
- [ ] 不引入新依赖 (用 SwiftUI + AppKit 内置 NSView / NSEvent / NSCursor / NSTrackingArea)
- [ ] `swift build` exit 0
- [ ] 不跑 Q22 (老板自己验)