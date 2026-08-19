# Spec — 区域模块顶/底栏尺寸修正

> Date: 2026-08-19
> 真值源: Sketch `AF7B1C87-ADDD-41ED-8208-7CA5549070E2` (page 文枢-组件化, Artboard 首页)
> Spec 走 po `to-spec` skill 7 段模板

## Problem Statement

老板 2026-08-19 反馈: 区域模块(Sketch `区域模块-*` 6 个 instance)的顶部 / 底部工具栏画穿了 splitter,溢出到隔壁 zone。这违反了 Sketch master 真值 — 每个 `区域模块` instance 是独立的容器,内部顶/底栏应该跟 zone 自己的实际宽度走,不应该用父 band 总宽。

从老板视角,拖拽 D_v / D_h 改 zone 尺寸时,顶/底栏应该跟着 zone 缩放(宽 + 高),而不是固定的父 band 全宽矩形。

## Solution

区域模块顶/底栏的尺寸计算改为:
- **宽度**: 用 zone 自己的真实宽度(从 SwiftUI layout 系统拿,不是父 band `totalW`)
- **高度**: 30 PT 写死不动(v0.15 ticket 008 老板拍板的死原则)
- **toolbar 内内容**: ICON 18 PT / 占位文字 13 PT 1:1 硬编码不动

每个区域模块独立按 zone 真实宽度 / 高度 30 PT 渲染顶/底栏,不再画穿 splitter。

## User Stories

1. As 老板, I want 区域模块顶/底栏用 zone 自己的真实宽度渲染, so that toolbar 不画穿 splitter 到隔壁 zone
2. As 老板, I want 拖 D_v 改 zone 宽度时顶/底栏跟着缩窄, so that toolbar 永远跟 zone 边界对齐
3. As 老板, I want 拖 D_h 改 zone 高度时顶/底栏内的内容跟着 zone 高度缩放(高度本身 30 PT 不动), so that zone 高度变化时 toolbar 内部布局合理
4. As 老板, I want 顶栏的 3 个 ICON(book.closed / magnifyingglass / slider.horizontal.3)保持 18 PT 1:1 硬编码, so that ICON 不被 toolbar 高度变化拉伸
5. As 老板, I want 顶栏右上的"占位文字"和底栏左右各一"占位文字"保持 13 PT 1:1 硬编码, so that 占位文字字体不被 zone 缩放影响
6. As 老板, I want 顶/底栏底/顶分割线保持 2 PT 写死, so that 分割线视觉跟 Sketch master 真值 1:1 对齐
7. As 老板, I want 顶/底栏在 6 个区域模块独立正确渲染, so that 6 个 zone 各自 toolbar 不溢出到隔壁 zone
8. As 老板, I want `swift build` 改完 clean (exit code 0), so that 我可以自己启 app 验

## Implementation Decisions

- **算 zone 实际宽度的实现层选择**: 待 implement 阶段决定(SwiftUI GeometryReader 拿 zone.frame.width / 改 .frame(maxWidth: .infinity) / 显式传 width 进 ZoneModule)。to-spec 不定实现细节。
- **保持 toolbar 高度 30 PT 写死**: 不推翻 v0.15 ticket 008 死原则,toolbar 高度写死是 Sketch master 真值。
- **保持 toolbar 内 ICON / 占位文字 1:1 PT**: 不引入新比例算子,18 PT ICON / 13 PT 占位文字 / 2 PT 分割线 全保持硬编码。
- **不引入新组件**: 优先复用现有 ZoneModule / ZoneTopToolbar / ZoneBottomToolbar,只改它们内部的尺寸计算逻辑。

## Testing Decisions

- **测试范围**: 仅 build clean (exit code 0),不跑 unit test(本会话无 unit test 覆盖这层)。
- **真值验证**: 老板自己启 `swift run WenshuApp` + 肉眼对照 Sketch 真值。Agent 不跑 Q22 screencapture -l(当前 Hermes TUI shell session 没有 Screen Recording TCC 授权)。
- **Acceptance 标准**:
  - `swift build` exit 0
  - 改完后顶层 .commands 菜单 / NotificationCenter 桥 / Library 数据层不破

## Out of Scope

- **不**改 macOS chrome 52 PT(走 .windowStyle(.titleBar))
- **不**改 LayoutTokens.designW / designH(1600×980 ticket 024 已对)
- **不**改 bandH 比例算子(ticket 021 已对)
- **不**改 D_v / D_h 拖拽线本身(只改 toolbar 怎么算尺寸,不碰 splitter)
- **不**改 Sketch master 对应 1:1 PT 真值(30 / 18 / 13 / 2)
- **不**改 v0.15 ticket 008 死原则(30 PT toolbar 高度)
- **不**跑 Q22 audit gate(Screen Recording TCC 未授权)
- **不**改 ADR(v0.15 ticket 008 已写 ADR,本次不引入新架构决策,只调整 toolbar 宽度算法)

## Further Notes

- 这是 v0.15 收尾后的第一个 v0.16 ticket,目的是修正区域模块内 toolbar 尺寸算法。
- 老板已 Q5 答"只跑 build + 老板自己验",所以 agent 不跑真截图,只跑 build clean + code-review 两轴。
- 老板已 Q1-Q6 全部答完,frontier 已空,可直接走 to-tickets → implement。