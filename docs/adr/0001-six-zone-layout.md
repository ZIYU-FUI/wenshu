# ADR-0001: 6 区 layout (Z-TITLE / Z-NOVEL / Z-CHAT)

> Status: accepted
> Date: 2026-08-18
> Decision-maker(s): 老板 (8/18)

## Context

老板 8/18 拍板 wenshu 首页 layout = 6 区真值, 数据源 Sketch `AF7B1C87-ADDD-41ED-8208-7CA5549070E2` Artboard `首页` (1920×984 PT, 1 PT = 1 PX macOS 27 1x). 不再走 v0.07 之前的 5 区 (Library/Editor/Inspector/Chat/Console/Status) 临时 layout.

## Decision

首页 = 标题栏 (1 zone) + 小说管理区 + 聊天管理区 = 6 个子 zone:
- Z-TITLE (1920×39)
- Z-NOVEL: 项目管理 / 编辑器 / 专用工具
- Z-CHAT: 聊天管理 / 动态区

每个 band 内 3 列布局, 5 竖向拖拽线 + 1 横向拖拽线 = 6 splitter. Zone 内容走 SwiftUI 子组件 1:1 落 Sketch SymbolInstance.

## Consequences

- 5 区 layout v0.07 之前的版本作为历史保留, 不再 active
- LayoutShellView / UpperBandZone / LowerBandZone / ZoneModule 等是 6 区落地的固定命名
- 任何 "5 区" / "7 区" 提案需新 ADR 重新拍板

## Alternatives considered

- v0.07 5 区 (Library/Editor/Inspector/Chat/Console/Status) — 拒绝, FCP-measured 不真
- 9 区 / 7 区 — 拒绝, 老板拍 6 区
- 旧 v0.05.x 7-zone (FCP-inspired) — 拒绝, 不是 Apple HIG 标准
