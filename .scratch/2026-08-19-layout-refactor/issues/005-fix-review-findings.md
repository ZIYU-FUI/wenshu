# 005 Fix v0.15 code-review two-axis findings

> Dependency: v0.15 commit `871c1b6` + two-axis review (Standards / Spec)
> 老板 2026-08-19 拍板: fix all, after fixing 老板 verifies

## Priority P0 (must fix)

### P0-1: Editor 4 PT inset wrong

**Bug**: `ZoneModule.content` `.editor` case currently `Color.white.opacity(0.55).padding(editorInset)` = all 4 directions, breaks spec §3.2 intentional two-layer design (background y=60~884, body y=64~882 = top/bottom 4 PT inset, left/right flush).

**Fix**: `Color.white.opacity(0.55).padding([.top, .bottom], editorInset)` (only vertical direction)

**Verification**: screencapture -l true screenshot to see editor inner layer left/right edges to zone edges

## Priority P1 (dead code + wrong comments)

### P1-1: Delete LayoutTokens dead constants

- `LayoutTokens.titleBarHeight` (L53, ticket 001 step 6 explicitly requires)
- `LayoutTokens.titleRatio` (L52, stale "省一栏" comment)
- `LayoutTokens.editorInsetRatio` (L75, still used by ZoneModule → **preserve**, but after spec §3.2 inset changes back to vertical direction, rename to `editorVerticalInsetRatio`)
- `LayoutTokens.horizontalSplitterRatio` (L59, NativeSplitter manages thickness itself, unused)
- `LayoutTokens.bottomLeading / bottomTrailing / placeholderIconSize` (L83-87, still used by ZoneBottomToolbar → **preserve**)

### P1-2: Delete LibraryOutlineViewContent.libraryHeader dead code + fix comments

### P1-3: Fix LowerBandZone comment "2 drag-line-vertical" → "1 drag-line-vertical"

### P1-4: Delete App.swift L244 leftover `// MARK: - 6 NativeSplitter NSView overlay` comment

## Priority P2 (responsive)

### P2-1: Delete LayoutShellView outer `.frame(width: designW, height: designH)` fixed

Let GeometryReader get true window size, ratio operator × real PT adaptive

### P2-2: Delete `max(proxy.size.height, designH)` floor

Really use `proxy.size.height`

### P2-3: `bandH` goes through `contentH * LayoutTokens.bandRatio`

Not through `vm.upperBandH` (not responsive on resize)

### P2-4: Delete outer `.background(.windowBackgroundColor)` redundant

ZoneModule internal already has

## Priority P3 (ADR + smell)

### P3-1: Write ADR-0007 supersede ADR-0003

- ADR-0003 mandates "NSView + NSEvent.delta", replaced by v0.14 NativeSplitter(view) + v0.15 LayoutShellView HStack paradigm
- New paradigm: Apple HIG HStack + self-written NativeSplitter (HSplitView divider color unchangeable, publicly known limitation)
- Title bar: macOS `.windowStyle(.titleBar)` 52 PT unified chrome (replacing v0.14.1 Canvas redraw + self-written TitleBarZone)

### P3-2: Fix App.swift L206 quote "Apple HIG Split Views" → fix truth reason

"HSplitView divider color unchangeable (publicly known limitation), switch to HStack + self-written NativeSplitter(view)"

### P3-3: Table-driven adjust (Shotgun Surgery smell)

VM already has `adjust(_ index: Int, delta:totalWidth:)`, LayoutShellView calls table-driven

### P3-4: ZoneModule.content switch extract slot-keyed theming

(Optional, 老板 拍)

## Acceptance (Q22 audit gate)

1. `swift build` clean
2. `swift run` + Quartz screencapture -l true screenshot
3. vision_analyze:
   - Editor inner layer left/right edges to zone edges (P0 fixed)
   - Title bar macOS chrome single layer (already)
   - 6 zones + 6 splitters + SF Symbol (regression verify)
4. Resize window test (P2 responsive fix):
   - Shrink window layout scales accordingly
   - Splitter width adaptive
5. Drag test (regression verify):
   - Hover 4 PT accent blue glow
   - Drag follows hand without jitter
   - D_h draggable (revert 50/50 lock)
6. code-review rerun (confirm findings all cleared)

## Risk

- P0 fix editor inset changes back to vertical direction → truth spec §3.2 拍板 direction
- P2 delete fixed frame + contentH real → resize behavior must regression verify
- P3-3 table-driven adjust refactor → 5 callback signatures change, all callers must follow

## 老板 new order

"Fix all, after fixing I'll have you verify" → 老板 verifies personally