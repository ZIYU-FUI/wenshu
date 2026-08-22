# 001 Delete LayoutShellView Canvas redraw + NSView hit area + TitleBarZone

> 老板 2026-08-19 拍板: LayoutShellView change Canvas → change to Apple HIG paradigm HStack + ZoneModule + NativeSplitter
> Dependency: spec.md

## Scope

`Sources/WenshuApp/App.swift`:
1. Delete `struct TitleBarZone` (L555-567)
2. Delete `Canvas { drawLayout }` whole block in `LayoutShellView` (L229-241)
3. Delete `private func drawLayout / drawZone / drawSplitterLine` (L249-384)
4. Delete `struct SplitterHitAreas + NativeSplitterHitArea NSView wrapper` (L387-493)
5. Delete `struct ZoneBottomToolbarsOverlay` (L427-472)
6. `LayoutTokens.titleBarHeight` change to 0 (or delete, leave to macOS chrome)
7. Rewrite `LayoutShellView.body` = `VStack(spacing: 0) { UpperBandZone; D_h; LowerBandZone }` with `.frame(width: totalW, height: totalH)`
8. App.swift L158 `.windowStyle(.titleBar)` preserved (老板 8/18 拍 macOS chrome = custom top bar visual unity)

## Untouched

- `NativeSplitter.swift` (v0.14 complete version, only called)
- `ZoneModule / ZoneTopToolbar / ZoneBottomToolbar / ZoneSlot / ZoneIcon` (all components exist, only called)
- `LayoutShellViewModel` (drag offset accumulation already correct)
- `LayoutTokens` ratio operator

## Acceptance

- `swift build` clean
- `swift run WenshuApp` runs, Quartz windowID screencapture -l true screenshot
- Visual: macOS titleBar single layer + 6 zones + 6 splitters 1 PT black static + top bar 3 SF Symbol + bottom bar placeholder text + editor 4 PT inset double layer

## Risk

- Canvas deleted, TimelineView(.animation) also deleted (originally for Canvas 60 fps follow-hand, after switching to HStack + DragGesture native follow-hand, not needed)
- Is TitleBarZone dead code being referenced? grep verify