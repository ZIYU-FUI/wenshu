# Spec — 拖拽线重写为 NSView + NSEvent (Apple AppKit 真值范式)

> Date: 2026-08-19
> 真值源: Apple AppKit NSView + NSEvent (Xcode / Pages / Numbers 用法) + macOS 27
> Spec 走 po `to-spec` skill 7 段模板

## 历史问题 (老板 8/19 + 历史 v0.14.0 commit message 已知)

v0.14.0 commit `dacbc9fee` 老板拍 "拖拽线是 1 组件",但 commit message 末尾 TODO 自承:

> **TODO (实测 3 件不对)**:
> - 横向 D_h 不能拖
> - D_v5 聊天/动态 不能拖
> - 鼠标光标没变形

这 3 个 bug v0.14.0 已知,v0.15 commit `871c1b6c2` LayoutShellView 重写没修,v0.16 ticket 02 commit `29711dd` 也只修 cursor + 范围,没触拖动真因。**NSLog 调试证据显示 dragGesture 在 D_h 真触发,但 view 不响应** + **`.pointerStyle(.rowResize)` 也不切 cursor** — 真因不在 SwiftUI DragGesture,在 SwiftUI view 重渲染链 + SwiftUI 顶层 window cursor 系统失效。

## Problem Statement

老板 2026-08-19 反馈:
1. D_h 横拖拽线 — **拖了没反应**(上/下区域占比不变)
2. cursor **不变**(鼠标移上去不变上下箭头)
3. v0.16 ticket 02 commit 修了 cursor 系统 + 范围,但**拖动响应未修**
4. 老板拍 "我们做的这个软件,估完了就是伪 Apple 官方 APP" — 要求拖拽线按 Apple AppKit 真值范式(NSView + NSEvent)实现

从老板视角,拖拽线应该跟 Xcode / Pages / Numbers 一样 — 鼠标移上去 cursor 立刻切(无需点一下),按下拖动实时响应,松手定位精准。

## Solution

重写 NativeSplitter 用 **NSView + NSEvent** AppKit 真值范式:

1. **`SplitterHitArea: NSView`** 子类 — 透明 hit area 视图,接 mouseDown / mouseDragged / mouseUp + NSTrackingArea hover 跟踪 cursor 切换(NSCursor.resizeLeftRight / resizeUpDown)
2. **`SplitterHitAreaRepresentable: NSViewRepresentable`** — 桥接 NSView 到 SwiftUI 布局
3. **`NativeSplitter: View`** 改 — SwiftUI 内部只画 Rectangle 视觉(2 PT 黑色 / hover 4 PT accent),hit area 用 NSViewRepresentable 透明 overlay
4. **拖拽事件回调** — NSView mouseDragged → 父 LayoutShellView 收到 delta,vm.adjustBandSplit / vm.adjust() mutate,@Observable 自动重渲染 (真值: NSView 直接调 SwiftUI closure,绕过 SwiftUI gesture 系统,稳定)
5. **cursor 切换** — NSTrackingArea + NSCursor.push (AppKit 标准, 跟 Xcode 一致)
6. **保留视觉** — Rectangle 2 PT 黑 / hover 4 PT accent + shadow(Apple HIG)

### 业务语言描述 (老板易懂版)

- 拖拽线不再用 SwiftUI 内置的手势检测
- 改用 AppKit 系统的 NSView 透明层接管鼠标事件(跟 Pages / Numbers / Xcode 一样)
- 鼠标移上去 — 立刻切 cursor(无需点)
- 按下拖动 — 实时回调到 LayoutShellView, 上/下区域比例变化
- 松手 — 定位精准, 不漂移

## User Stories

1. As 老板, I want D_h 横拖拽线鼠标移上去 cursor 立刻切到上下箭头 (无需点击), so that 跟 Xcode / Pages 一样
2. As 老板, I want D_h 按下拖动实时改变上/下区域占比 (60 fps 跟手), so that 拖动体验流畅
3. As 老板, I want D_v 5 竖拖拽线行为不变, so that 已实现的宽度拖拽不破
4. As 老板, I want D_v5 聊天/动态 拖拽线能真工作 (历史 v0.14.0 TODO 之一, 拼这次重写一并修)
5. As 老板, I want hover 蓝光视觉保留 (Rectangle 2 PT 黑 / hover 4 PT accent), so that 视觉反馈不变
6. As 老板, I want hit area 6 PT 保留, so that 拖拽精度不变
7. As 老板, I want `swift build` clean exit 0, so that 我可以自己启 app 验
8. As 老板, I want D_h 拖动范围不限 (继承 v0.16 ticket 02 拍板), so that 为下个 "区域隐藏" 需求铺路

## Implementation Decisions

- **NSView 子类** `SplitterHitArea`:
  - 重写 `mouseDown(with:)` — 记录起始 mouse location
  - 重写 `mouseDragged(with:)` — 算 delta (currentLocation - lastLocation), 调 SwiftUI 父 closure
  - 重写 `mouseUp(with:)` — 清状态
  - `updateTrackingAreas()` — 加 NSTrackingArea,hover 时 NSCursor.push, mouseExited 时 NSCursor.pop
- **`NSViewRepresentable` 桥接**:
  - `makeNSView(context:)` — 返回 SplitterHitArea 实例
  - `updateNSView(_:context:)` — 设置 frame + 注入 closure
- **LayoutShellView 调用 NativeSplitter** — 跟 v0.15 ticket 006 一样, 传 onDrag closure
- **NativeSplitter body** — SwiftUI Rectangle 视觉 + ZStack 内 SplitterHitAreaRepresentable overlay (transparent)
- **不动**:
  - VM mutate 公式 `upperBandH / lowerBandH / adjust / adjustBandSplit` (ticket 014 + ticket 02 已拍)
  - `minOffset / maxOffset` (±0.15 D_v) / `minBandOffset / maxBandOffset` (±1.0 D_h)
  - D_h 视觉 (2 PT 黑 / 4 PT accent)
  - 6 PT hit area 厚度
  - macOS chrome / LayoutTokens / bandH 比例算子
  - v0.16 ticket 01 toolbar 宽度算法

## Testing Out

- **测试范围**: 仅 `swift build clean` (exit 0), 不跑 unit test
- **真值验证**: 老板自己启 `swift run WenshuApp` + 实测
- **Acceptance 标准**:
  - `swift build` exit 0
  - D_h / D_v5 / D_v 1-4 6 根拖拽线全部真工作 (cursor 切 + 拖动响应)
  - hover 视觉保留 (蓝光 + shadow)
  - drag 跟手 (60 fps)
  - macOS chrome / LayoutTokens / bandH 比例算子 / toolbar 宽度 全不动

## Out of Scope

- **不**改 VM mutate 公式
- **不**改范围常量
- **不**改视觉规格 (2 PT / 4 PT)
- **不**改 hit area 厚度 (6 PT)
- **不**改 macOS chrome / LayoutTokens / bandH
- **不**实现 "区域隐藏" (下个需求)
- **不**跑 Q22 audit gate (Screen Recording TCC 未授权)
- **不**写新 ADR (NSView + NSEvent 范式已在 v0.10.6 + v0.14.0 commit 走通, 不算新架构决策)

## Further Notes

- 这是 v0.16 ticket 03, 紧接 ticket 02 (cursor 反馈 + 范围不限).
- NSView + NSEvent 范式是 Apple AppKit 真值标准, wenshu v0.10.6 + v0.14.0 阶段就用过 (commit history 可查).
- v0.14.0 commit `dacbc9fee` 老板 8/18 拍 "拖拽线是 1 组件", 但 commit message 自承 3 个 TODO: D_h 不能拖 / D_v5 不能拖 / cursor 没变形 — 这 3 个 bug 拼 ticket 03 一起修.
- 老板 Q11 答 A — 重写 NativeSplitter 用 NSView + NSEvent.
- 历史 v0.10 老板拍 "老板 8/19 拍 拖拽线 = NSView + NSEvent deltaX/totalW" (commit 19:00 fix), 范式是 Apple AppKit 标准.
- 不动 v0.16 ticket 01 (toolbar 宽度) + v0.16 ticket 02 (cursor + 范围) 已 commit 改动.