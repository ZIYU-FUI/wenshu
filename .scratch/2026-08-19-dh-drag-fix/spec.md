# Spec — D_h 横拖拽线 cursor 反馈 + 拖动响应 + 范围不限

> Date: 2026-08-19
> 真值源: Sketch `AF7B1C87-ADDD-41ED-8208-7CA5549070E2` (page 文枢-组件化, Artboard 首页) + Apple HIG SwiftUI 4 (macOS 27)
> Spec 走 po `to-spec` skill 7 段模板

## Problem Statement

老板 2026-08-19 反馈: D_h 横拖拽线(上下区域中间那条 2 PT 黑色胶囊端线)能看到,鼠标移上去**不切 cursor**(不变上下箭头),拖了**没反应**(上下区域占比不变)。

从老板视角,横拖拽线手感上"不可拖"——视觉在但交互反馈缺失。当前实现 (v0.15 ticket 014 拖动逻辑 + v0.15 ticket 023 cursor 反馈) 都已 commit,但实测有 2 个 bug 同时存在。

## Solution

修 2 个独立 bug:
1. **cursor 反馈**: 推翻 v0.15 ticket 023 的 `.onContinuousHover` + `NSCursor.push` 实现, 用别的 Apple HIG SwiftUI 4 (macOS 27) API 让 cursor 真正切到 `.rowResize`(上下箭头)。
2. **拖动响应**: 排查 v0.15 ticket 014 的 `adjustBandSplit` + `NativeSplitter(.horizontal)` 手势链为什么没生效。修复后上/下 band 比例跟手 resize。

同时为下个需求 "区域隐藏" 准备: **D_h 拖动范围不限**(`bandOffset` 范围 [-1.0, +1.0]), 上下区域可以从 0% 拖到 100%,不再限制 ±7 PT。

## User Stories

1. As 老板, I want 鼠标移到 D_h 横拖拽线上 cursor 切到上下箭头, so that 手感上知道是可拖的东西
2. As 老板, I want 按下 D_h 拖动线能改变上下区域占比, so that 我可以灵活调整上/下区域大小
3. As 老板, I want 拖动时上/下区域比例变化跟手不抖动 (60 fps), so that 拖动体验流畅
4. As 老板, I want D_h 拖动范围不限 (可从 0% 拖到 100%), so that 为后续 "区域隐藏" 需求铺路
5. As 老板, I want D_h hover 时变粗 + 蓝色发光 (跟 D_v 一致), so that 横竖拖拽线视觉反馈统一
6. As 老板, I want D_v (5 根竖拖拽线) 行为不变, so that 已实现的宽度拖拽不破
7. As 老板, I want `swift build` exit 0, so that 我可以自己启 app 验

## Implementation Decisions

- **cursor 修法方向**: 推翻 v0.15 ticket 023 实现, 用别的 Apple HIG API。具体 API 待 implement 阶段决定 (e.g. `NSWindow` 子类化 + `resetCursorRects` / `cursorUpdate` / 其他 macOS 27 推荐方案)。to-spec 不定实现细节。
- **拖动响应修复**: 排查 `NativeSplitter(.horizontal)` 手势挂载位置 / `withTransaction(disablesAnimations: true)` 影响 / `vm.bandOffset` mutate 是否触发 view 重渲染。具体修法待 implement。
- **拖动范围**: `bandOffset` 累加范围从 [-0.15, +0.15] 扩大到 [-1.0, +1.0] (`LayoutShellViewModel.minOffset / maxOffset`)。
- **不动 D_v 5 根竖拖拽线**: 它们的 `offsets[0..4]` 累加范围保持 [-0.15, +0.15] 不变。
- **保留视觉**: D_h 静态 2 PT 黑色 / hover 4 PT `Color.accentColor.opacity(0.6)` + shadow, 跟 D_v 一致。
- **保留 hit area**: 6 PT 透明 hit area 不变。
- **不引入新组件**: 复用 NativeSplitter + LayoutShellViewModel。

## Testing Decisions

- **测试范围**: 仅 `swift build clean` (exit 0), 不跑 unit test (本会话无 unit test 覆盖 D_h)。
- **真值验证**: 老板自己启 `swift run WenshuApp` + 实测 cursor 切 + 拖动上下区域占比变化。Agent 不跑 Q22 screencapture -l (当前 Hermes TUI shell session 没有 Screen Recording TCC 授权, 已知 fail)。
- **Acceptance 标准**:
  - `swift build` exit 0
  - D_v 5 根竖拖拽线行为不变 (老板 v0.15 已验过)
  - 改动 commit 1 ticket 1 commit
  - CONTEXT.md 域词汇更新

## Out of Scope

- **不**实现 "区域隐藏" 需求 (老板拍 "下个需求先不做") — 只为它准备拖动范围
- **不**改 D_v 5 根竖拖拽线 (保持 v0.15 实现不变, Q20 已实现不要直接动)
- **不**改 NativeSplitter vertical 分支
- **不**改 `vm.upperBandH` / `vm.lowerBandH` 公式 (只动 `minOffset` / `maxOffset`)
- **不**改 macOS chrome / LayoutTokens / bandH 比例算子
- **不**改 v0.15 ticket 014 commit `6188d16d9` 的拖动逻辑基础, 只排查为什么实测没反应
- **不**改 v0.16 ticket 01 已修的 toolbar 宽度算法
- **不**跑 Q22 audit gate (Screen Recording TCC 未授权)
- **不**写新 ADR (cursor 修法具体 API 不定, 留 implement 阶段决定)

## Further Notes

- 这是 v0.16 ticket 02, 紧接 ticket 01 (toolbar 宽度由 VStack stretch 撑 zone 实际宽度)。
- D_h 修法是 cursor + 拖动响应两个独立 bug 一起修, 不拆分 ticket (vertical slice 同一组件)。
- v0.15 ticket 023 (cursor) + v0.15 ticket 014 (拖动) 两个 commit 都在, 但实测都不工作 — 修复需要排查真因, 不能仅"重写同样 API"。
- 老板 Q5 答 "只跑 build + 老板自己验", 所以 agent 不跑 Q22, 只跑 build clean + code-review 两轴。
- 老板 Q1-Q6 全部答完, frontier 已空, 可直接走 to-tickets → implement。