# SPEC v0.15: LayoutShellView 重写 (Apple HIG 真值范式)

> 数据源: Sketch `AF7B1C87-ADDD-41ED-8208-7CA5549070E2` page 文枢 Artboard 首页 (47 layer frame)
> Apple HIG: Split Views (developer.apple.com/design/human-interface-guidelines/split-views)
> Apple 真值: HSplitView / VSplitView divider 颜色改不了 → 用 HStack + 自写 NativeSplitter
> 老板 2026-08-19 拍板: 改 Canvas 重写回 SwiftUI view tree 范式

## 0. 当前病灶 (老板 2026-08-19 反馈)

1. **标题栏双层**: LayoutShellView Canvas 自己画 52 PT #393939 + .windowStyle(.titleBar) 又有 macOS 52 PT chrome + 死代码 TitleBarZone
2. **区域组件混乱**: LayoutShellView Canvas 画 zone + SwiftUI overlay 画 ZoneBottomToolbarsOverlay,ZoneModule 组件死代码
3. **拖拽线 hover/drag 全丢**: Canvas 不响应 hover; NativeSplitterHitArea 透明 NSView 只接事件不画 hover/drag 视觉; NativeSplitter(view) 完整版(2 PT 黑/hover 4 PT accent capsule/DragGesture/.pointerStyle)被废

## 1. 重写范式 (Apple HIG + 老板真值)

### 1.1 标题栏
- **不写 TitleBarZone 自定义顶栏**
- 走 `WindowGroup + .windowStyle(.titleBar)` macOS 52 PT unified titlebar chrome (Apple HIG)
- 删 LayoutTokens.titleBarHeight / Canvas 标题栏矩形 / TitleBarZone struct

### 1.2 6 区 layout (Apple HIG: HStack + 自写 splitter)
- 上 band (4 区): `HStack(spacing: 0) { sidebar; NativeSplitter; preview; NativeSplitter; editor; NativeSplitter; tools }`
- 下 band (2 区): `HStack(spacing: 0) { aiChat; NativeSplitter; aiDynamic }`
- 上/下 band 垂直堆叠: `VStack(spacing: 0) { UpperBandZone; NativeSplitter(horizontal); LowerBandZone }`
- 删 Canvas drawLayout / drawZone / drawSplitterLine / SplitterHitAreas NSView overlay / ZoneBottomToolbarsOverlay
- LayoutShellView = GeometryReader × 比例算子 × HStack/VStack + ZoneModule + NativeSplitter(view)

### 1.3 区域组件 (Sketch 6 master 1:1 落)
- **ZoneModule** 已存在,直接复用:
  - `VStack(spacing: 0) { ZoneTopToolbar (30 PT, 3 SF Symbol); content (412 PT); ZoneBottomToolbar (30 PT, 占位文字+icon) }`
  - `.background(slot == .aiDynamic ? DesignColor.dynamicZoneSurface : DesignColor.zoneSurface)`
- **ZoneTopToolbar** 已存在: 3 SF Symbol (book.closed / magnifyingglass / slider.horizontal.3) + 底 1 PT 黑线
- **ZoneBottomToolbar** 已存在: 占位文字 (`.body`) + 占位 SF Symbol (questionmark.square.dashed) + 顶 1 PT 黑线
- 编辑器 4 PT inset: 已在 ZoneModule.content .editor case (`Color.white.opacity(0.55).padding(editorInset)`) 保留
- **蓝矩形 = SF Symbol 替代** (老板 2026-08-19 拍): 不画 Rectangle,用 `Image(systemName:)`,颜色 `Color.accentColor`,已实现

### 1.4 拖拽线 (Apple HIG: DragGesture + .pointerStyle)
- NativeSplitter v0.14 已完整,直接接 HStack 之间:
  - 静态 2 PT 黑色 capsule
  - hover: 4 PT `Color.accentColor.opacity(0.6)` + `.shadow(opacity: 0.4, radius: 8)`
  - drag: DragGesture(minimumDistance: 0) + withTransaction(disablesAnimations: true) 跟手
  - cursor: `.pointerStyle(.columnResize / .rowResize)`
- 删 SplitterHitAreas / NativeSplitterHitArea NSView wrapper

## 2. 数对公式守恒 (老板 8/18 真值)

```
上 band 数对: 200 + 558 + 762 + 400 = 1920 + 3 × 1 PT splitter = 1923
下 band 数对: 1519 + 400 = 1919 + 1 PT splitter = 1920
H 数对: 52 (titleBar chrome) + 465 (upper) + 1 (D_h) + 465 (lower) = 983 ≈ 984 (AppDelegate setContentSize 微调)
```

## 3. 验收 (老板 8/18 + Q22 audit gate)

1. `swift build` clean
2. `swift run WenshuApp` 后台跑,Quartz windowID screencapture -l 真截图
3. vision_analyze 看到: macOS titleBar 单层 + 上 band 4 区 + 下 band 2 区 + 6 拖拽线 + 顶栏 3 SF Symbol + 底栏占位文字 + 编辑器 4 PT inset
4. 拖拽测试: hover 拖拽线 → 4 PT accent 蓝光晕 + cursor 切换; drag → zone 宽度跟手不抖动
5. /code-review 两轴 (Standards + Spec): 不写硬编码 RGB, 不写 iOS import, 不用 UIKit, 0 死代码 (TitleBarZone / Canvas draw* / NSView hit area / ZoneBottomToolbarsOverlay 全删)

## 4. 风险

- 老板拍"标题栏双层" → 我之前 v0.14.1 加 Canvas 标题栏 + .titleBar chrome 共存就是问题. 重写 = 彻底回归 HStack/VStack 范式
- Apple HIG 推荐 HSplitView (官方 macOS 10.15+),但 divider 颜色改不了 (StackOverflow 公开已知). 跟老板 Sketch 6 区 + 自定义黑粗 hover 蓝 capsule divider 不对应 → 必须自写 NativeSplitter
- NativeSplitter v0.14 已有完整 hover/drag 代码,不需要重写,只改调用方
