# Spec — 3 个 D_h 拖拽线细节修法 (老板 2026-08-19 实测)

> Date: 2026-08-19
> Spec 走 po `to-spec` skill 7 段模板

## Problem Statement

老板 2026-08-19 实测 D_h 拖拽线 (commit de0f6ec 后) 发现 3 个细节问题:

1. **windows 底部多一块空白** (~50 PT) — 上半区 + D_h + 下半区 总高 882,留 50 PT 空白在底
2. **hover 蓝光持续亮不消失** — 鼠标移开拖拽线后蓝光不消失 (mouseExited 没触发)
3. **鼠标 cursor 没变两个箭头** — `resetCursorRects` 实现没真生效
4. **蓝光太实** — 透明度太高 (0.6),老板建议轻微透明 (0.5) 看见背后

老板拍 "效果优先, 不因工作量打折, 一切以伪 Apple 官方 APP 为原则", 修法按工作量从小到大:
1. 下半区空白 (1 行改)
2. 蓝光透明度 + 持续亮 (中等改)
3. cursor 不变 (大改, NSWindow 子类化)

## Solution (3 个独立 ticket)

### Ticket 04: LayoutShellView contentH 重复扣 chrome (已 commit b4f2021)

- **症状**: windows 底部多一块空白 (~50 PT)
- **真因**: `proxy.size.height` = 932 (NSWindow.contentRect, 已扣 macOS chrome 52 PT), 但 LayoutShellView 用 `contentH - 52` 重复扣
- **修法**: `contentH - 52` → `contentH - 2` (contentH 已扣 chrome, -2 留给 D_h 拖拽线)
- **数据**: 932 - 2 = 930, bandH = 465 × 2 + D_h 2 = 932 ✓
- **结果**: 上半:下半 = 1:1, 无空白

### Ticket 05: hover 蓝光松开消失 + 透明度 0.5 (本次 commit)

- **症状 2a**: 蓝光松开不消失 (mouseExited 没触发)
- **真因**: macOS 27 NSTrackingArea `.mouseEnteredAndExited` 不稳定, NSViewRepresentable 桥接时尤其
- **修法**: 加 `.mouseMoved` option + override `mouseMoved` 实时算 `bounds.contains(convert(event.locationInWindow, from: nil))`,自己设 isHovered (不走 mouseEntered/Exited)
- **症状 2b**: 蓝光太实
- **修法**: hover 时 accent opacity 0.6 → 0.5, shadow opacity 0.4 → 0.3 (老板拍 A)

### Ticket 06: cursor 切上下箭头 (待拍)

- **症状**: 鼠标移上拖拽线不变 cursor
- **真因猜测**: `resetCursorRects` 在 NSViewRepresentable 桥接时不被 macOS cursor 系统识别 (NSView 在 SwiftUI view tree 中是 CALayer 包装,macOS 27 cursor rects 不识别)
- **可能修法**: NSWindow 子类化 + `cursorUpdate(with:)` (Apple HIG macOS 真值, 跟 Pages / Numbers 一样)
- **工作量**: 大 (待 grill 拍板)

## User Stories

1. As 老板, I want windows 底部无空白, 上半:下半 = 50:50, so that 6 区 layout 跟 Sketch AF7B1C87 1:1
2. As 老板, I want hover 蓝光鼠标移开后立刻消失, so that 拖拽线视觉反馈干净
3. As 老板, I want hover 蓝光透明度 0.5, so that 轻微看见背后 (Apple HIG 视觉风格)
4. As 老板, I want cursor 切到上下箭头 (D_h) / 左右箭头 (D_v), so that 跟 Xcode / Pages 一样手感

## Implementation Decisions

- **ticket 04**: LayoutShellView VStack `contentH - 52` → `contentH - 2`. 已 commit b4f2021.
- **ticket 05**: NSTrackingArea 加 `.mouseMoved` + `mouseMoved` override + `bounds.contains` 实时算. accent 0.6 → 0.5 + shadow 0.4 → 0.3.
- **ticket 06**: NSWindow 子类化 + `cursorUpdate(with:)` (待 grill 拍).

## Testing Decisions

- 仅 `swift build clean` (exit 0), 老板自己启 app 验.
- 不跑 Q22 (Screen Recording TCC 未授权).

## Out of Scope

- macOS chrome 52 PT 不动 (.windowStyle(.titleBar))
- D_h 视觉 2 PT 静态 + 4 PT hover 不动
- 6 PT hit area 不动
- 范围 / 公式 / LayoutTokens 不动
- D_v 5 竖拖拽线行为不变

## Further Notes

- 老板拍 "效果优先, 不因工作量打折, 一切以伪 Apple 官方 APP 为原则" — 后续修法按这个原则
- ticket 06 (cursor) 工作量大, 待 grill 拍修法方向
- 3 个 ticket 串行, 按工作量从小到大, 每 ticket build clean + 老板验 pass 才下一个