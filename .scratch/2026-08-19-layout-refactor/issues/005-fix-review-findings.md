# 005 修 v0.15 code-review 两轴 findings

> 依赖: v0.15 commit 871c1b6 + 两轴 review (Standards / Spec)
> 老板 2026-08-19 拍板: 全修, 修好老板验

## 优先级 P0 (必修)

### P0-1: 编辑器 4 PT inset 改错

**Bug**: `ZoneModule.content` `.editor` case 当前是 `Color.white.opacity(0.55).padding(editorInset)` = 全 4 方向,破 spec §3.2 故意两层设计(背景 y=60~884, 正文 y=64~882 = 上下 4 PT inset, 左右 flush).

**修法**: `Color.white.opacity(0.55).padding([.top, .bottom], editorInset)`(只垂直方向)

**验证**: screencapture -l 真截图看编辑器内层左右边到 zone 边缘

## 优先级 P1 (死代码 + 误 comment)

### P1-1: 删 LayoutTokens 死常量

- `LayoutTokens.titleBarHeight` (L53, ticket 001 step 6 明确要求)
- `LayoutTokens.titleRatio` (L52, stale "省一栏" comment)
- `LayoutTokens.editorInsetRatio` (L75, 仍被 ZoneModule 用 → **保留**,但 spec §3.2 inset 改回垂直方向后改名为 `editorVerticalInsetRatio`)
- `LayoutTokens.horizontalSplitterRatio` (L59, NativeSplitter 自己管 thickness,没人用)
- `LayoutTokens.bottomLeading / bottomTrailing / placeholderIconSize` (L83-87, 仍被 ZoneBottomToolbar 用 → **保留**)

### P1-2: 删 LibraryOutlineViewContent.libraryHeader 死代码 + 改 comment

### P1-3: 改 LowerBandZone comment "2 拖拽线-竖" → "1 拖拽线-竖"

### P1-4: 删 App.swift L244 残留 `// MARK: - 6 个 NativeSplitter NSView overlay` 注释

## 优先级 P2 (响应式)

### P2-1: 删 LayoutShellView 外层 `.frame(width: designW, height: designH)` fixed

让 GeometryReader 拿真窗口尺寸, 比例算子 × 实 PT 自适应

### P2-2: 删 `max(proxy.size.height, designH)` floor

真用 `proxy.size.height`

### P2-3: `bandH` 走 `contentH * LayoutTokens.bandRatio`

不走 `vm.upperBandH` (resize 时不响应)

### P2-4: 删外层 `.background(.windowBackgroundColor)` 冗余

ZoneModule 内部已有

## 优先级 P3 (ADR + smell)

### P3-1: 写 ADR-0007 supersede ADR-0003

- ADR-0003 mandate "NSView + NSEvent.delta", 被 v0.14 NativeSplitter(view) + v0.15 LayoutShellView HStack 范式替代
- 新范式: Apple HIG HStack + 自写 NativeSplitter (HSplitView divider 颜色改不了, 公开已知限制)
- 标题栏: macOS .windowStyle(.titleBar) 52 PT unified chrome (取代 v0.14.1 Canvas 重画 + 自写 TitleBarZone)

### P3-2: 改 App.swift L206 引文 "Apple HIG Split Views" → 改真值原因

"HSplitView divider 颜色改不了 (公开已知限制), 改 HStack + 自写 NativeSplitter(view)"

### P3-3: 表驱动 adjust (Shotgun Surgery smell)

VM 已有 `adjust(_ index: Int, delta:totalWidth:)`, LayoutShellView 调表驱动

### P3-4: ZoneModule.content switch 抽 slot-keyed theming

(可选, 老板拍)

## 验收 (Q22 audit gate)

1. swift build clean
2. swift run + Quartz screencapture -l 真截图
3. vision_analyze:
   - 编辑器内层左右边到 zone 边缘 (P0 修)
   - 标题栏 macOS chrome 单层 (已有)
   - 6 区 + 6 拖拽线 + SF Symbol (回归验)
4. resize 窗口测试 (P2 响应式修):
   - 缩小窗口 layout 跟着缩
   - 拖拽线宽度自适应
5. 拖拽测试 (回归验):
   - hover 4 PT accent 蓝光晕
   - drag 跟手不抖动
   - D_h 可拖 (撤销 50/50 锁定)
6. code-review 再跑 (确认 findings 全清)

## 风险

- P0 修编辑器 inset 改回垂直方向 → 真值 spec §3.2 拍板方向
- P2 删 fixed frame + contentH 真实 → resize 行为要回归验
- P3-3 表驱动 adjust 重构 → 5 个回调签名变, 所有调用方都要跟

## 老板新令

"全修, 修好我让我验" → 老板亲自验
