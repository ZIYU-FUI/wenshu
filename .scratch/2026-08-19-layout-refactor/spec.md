# SPEC v0.15: LayoutShellView rewrite (Apple HIG truth paradigm)

> Data source: Sketch `AF7B1C87-ADDD-41ED-8208-7CA5549070E2` page 文枢 Artboard home (47 layer frames)
> Apple HIG: Split Views (developer.apple.com/design/human-interface-guidelines/split-views)
> Apple truth: HSplitView / VSplitView divider color unchangeable → use HStack + self-written NativeSplitter
> 老板 2026-08-19 拍板: change Canvas rewrite back to SwiftUI view tree paradigm

## 0. Current pathology (老板 2026-08-19 feedback)

1. **Title bar double-layer**: LayoutShellView Canvas self-draws 52 PT #393939 + `.windowStyle(.titleBar)` also has macOS 52 PT chrome + dead-code TitleBarZone
2. **Zone components chaos**: LayoutShellView Canvas draws zone + SwiftUI overlay draws ZoneBottomToolbarsOverlay, ZoneModule component dead code
3. **Splitter hover/drag all lost**: Canvas does not respond to hover; NativeSplitterHitArea transparent NSView only receives events, doesn't draw hover/drag visuals; NativeSplitter(view) complete version (2 PT black/hover 4 PT accent capsule/DragGesture/.pointerStyle) was deprecated

## 1. Rewrite paradigm (Apple HIG + 老板 truth)

### 1.1 Title bar

- **Do not write TitleBarZone custom top bar**
- Use `WindowGroup + .windowStyle(.titleBar)` macOS 52 PT unified titlebar chrome (Apple HIG)
- Delete `LayoutTokens.titleBarHeight` / Canvas title-bar rectangle / TitleBarZone struct

### 1.2 6-zone layout (Apple HIG: HStack + self-written splitter)

- Upper band (4 zones): `HStack(spacing: 0) { sidebar; NativeSplitter; preview; NativeSplitter; editor; NativeSplitter; tools }`
- Lower band (2 zones): `HStack(spacing: 0) { aiChat; NativeSplitter; aiDynamic }`
- Upper/lower band vertical stack: `VStack(spacing: 0) { UpperBandZone; NativeSplitter(horizontal); LowerBandZone }`
- Delete Canvas drawLayout / drawZone / drawSplitterLine / SplitterHitAreas NSView overlay / ZoneBottomToolbarsOverlay
- LayoutShellView = GeometryReader × ratio operator × HStack/VStack + ZoneModule + NativeSplitter(view)

### 1.3 Zone components (Sketch 6 master 1:1 layout)

- **ZoneModule** already exists, reuse directly:
  - `VStack(spacing: 0) { ZoneTopToolbar (30 PT, 3 SF Symbol); content (412 PT); ZoneBottomToolbar (30 PT, placeholder text+icon) }`
  - `.background(slot == .aiDynamic ? DesignColor.dynamicZoneSurface : DesignColor.zoneSurface)`
- **ZoneTopToolbar** already exists: 3 SF Symbol (`book.closed` / `magnifyingglass` / `slider.horizontal.3`) + bottom 1 PT black line
- **ZoneBottomToolbar** already exists: placeholder text (`.body`) + placeholder SF Symbol (`questionmark.square.dashed`) + top 1 PT black line
- Editor 4 PT inset: already in `ZoneModule.content .editor` case (`Color.white.opacity(0.55).padding(editorInset)`) preserved
- **Blue rectangle = SF Symbol replacement** (老板 2026-08-19 拍): don't draw Rectangle, use `Image(systemName:)`, color `Color.accentColor`, already implemented

### 1.4 Splitter (Apple HIG: DragGesture + .pointerStyle)

- NativeSplitter v0.14 already complete, directly interface between HStack:
  - Static 2 PT black capsule
  - Hover: 4 PT `Color.accentColor.opacity(0.6)` + `.shadow(opacity: 0.4, radius: 8)`
  - Drag: `DragGesture(minimumDistance: 0)` + `withTransaction(disablesAnimations: true)` follow-hand
  - Cursor: `.pointerStyle(.columnResize / .rowResize)`
- Delete SplitterHitAreas / NativeSplitterHitArea NSView wrapper

## 2. Number-pair formula conservation (老板 8/18 truth)

```
Upper band number-pair: 200 + 558 + 762 + 400 = 1920 + 3 × 1 PT splitter = 1923
Lower band number-pair: 1519 + 400 = 1919 + 1 PT splitter = 1920
H number-pair: 52 (titleBar chrome) + 465 (upper) + 1 (D_h) + 465 (lower) = 983 ≈ 984 (AppDelegate setContentSize minor adjust)
```

## 3. Acceptance (老板 8/18 + Q22 audit gate)

1. `swift build` clean
2. `swift run WenshuApp` run in background, Quartz windowID screencapture -l true screenshot
3. vision_analyze sees: macOS titleBar single layer + upper band 4 zones + lower band 2 zones + 6 splitters + top bar 3 SF Symbol + bottom bar placeholder text + editor 4 PT inset
4. Drag test: hover splitter → 4 PT accent blue glow + cursor switch; drag → zone width follows hand without jitter
5. /code-review two axes (Standards + Spec): don't hard-code RGB, don't write iOS import, don't use UIKit, 0 dead code (TitleBarZone / Canvas draw* / NSView hit area / ZoneBottomToolbarsOverlay all deleted)

## 4. Risk

- 老板 拍 "title bar double-layer" → my previous v0.14.1 added Canvas title bar + .titleBar chrome coexistence is the problem. Rewrite = complete regression to HStack/VStack paradigm
- Apple HIG recommends HSplitView (official macOS 10.15+), but divider color cannot be changed (StackOverflow publicly known). Doesn't match 老板 Sketch 6 zones + custom black thick hover blue capsule divider → must self-write NativeSplitter
- NativeSplitter v0.14 already has complete hover/drag code, doesn't need rewrite, only change caller