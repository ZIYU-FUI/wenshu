# 001 删 LayoutShellView Canvas 重画 + NSView hit area + TitleBarZone

> 老板 2026-08-19 拍板: LayoutShellView 改 Canvas → 改 Apple HIG 范式 HStack + ZoneModule + NativeSplitter
> 依赖: spec.md

## 范围

`Sources/WenshuApp/App.swift`:
1. 删 `struct TitleBarZone`(L555-567)
2. 删 `LayoutShellView` 内 `Canvas { drawLayout }` 整块(L229-241)
3. 删 `private func drawLayout / drawZone / drawSplitterLine`(L249-384)
4. 删 `struct SplitterHitAreas + NativeSplitterHitArea NSView wrapper`(L387-493)
5. 删 `struct ZoneBottomToolbarsOverlay`(L427-472)
6. `LayoutTokens.titleBarHeight` 改 0(或删,留给 macOS chrome)
7. 重写 `LayoutShellView.body` = `VStack(spacing: 0) { UpperBandZone; D_h; LowerBandZone }` 调 .frame(width: totalW, height: totalH)
8. App.swift L158 `.windowStyle(.titleBar)` 保留(老板 8/18 拍 macOS chrome = 自定义顶栏视觉合一)

## 不动

- `NativeSplitter.swift`(v0.14 完整版,只被调用)
- `ZoneModule / ZoneTopToolbar / ZoneBottomToolbar / ZoneSlot / ZoneIcon`(全组件已存在,只被调用)
- `LayoutShellViewModel`(拖拽 offset 累加已对)
- `LayoutTokens` ratio 算子

## 验收

- `swift build` clean
- `swift run WenshuApp` 跑,Quartz windowID screencapture -l 真截图
- 视觉: macOS titleBar 单层 + 6 区 + 6 拖拽线 1 PT 黑静态 + 顶栏 3 SF Symbol + 底栏占位文字 + 编辑器 4 PT inset 双层

## 风险

- Canvas 删了,TimelineView(.animation) 也删(本来给 Canvas 60 fps 跟手用,改 HStack + DragGesture native 跟手后不需要)
- TitleBarZone 是死代码被引用吗?grep 验
