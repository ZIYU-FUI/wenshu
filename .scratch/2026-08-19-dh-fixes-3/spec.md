# Spec — 3 D_h splitter detail fixes (老板 2026-08-19 actual test)

> Date: 2026-08-19
> Spec uses po `to-spec` skill 7-section template

## Problem Statement

老板 2026-08-19 actual test D_h splitter (after commit `de0f6ec`) found 3 detail problems:

1. **Blank space at window bottom** (~50 PT) — upper + D_h + lower total height 882, leaves 50 PT blank at bottom
2. **Hover blue glow stays on, does not disappear** — blue glow does not fade after mouse leaves splitter (mouseExited not triggered)
3. **Mouse cursor does not change to two arrows** — `resetCursorRects` implementation does not actually take effect
4. **Blue glow too solid** — opacity too high (0.6); 老板 suggests slightly transparent (0.5) so the background is visible

老板 拍 "effect first, do not compromise for workload, follow the pseudo-Apple-official-App principle". Fix order by workload small to large:
1. Lower-zone blank (1-line change)
2. Blue glow opacity + sticky-on (medium change)
3. Cursor not changing (large change, NSWindow subclassing)

## Solution (3 independent tickets)

### Ticket 04: LayoutShellView contentH double-deducts chrome (committed `b4f2021`)

- **Symptom**: Blank space at window bottom (~50 PT)
- **Root cause**: `proxy.size.height` = 932 (NSWindow.contentRect, already deducts macOS chrome 52 PT), but LayoutShellView uses `contentH - 52` and double-deducts
- **Fix**: `contentH - 52` → `contentH - 2` (contentH already deducts chrome, -2 reserved for D_h splitter)
- **Data**: 932 - 2 = 930, bandH = 465 × 2 + D_h 2 = 932 ✓
- **Result**: upper:lower = 1:1, no blank

### Ticket 05: hover blue glow fades on release + opacity 0.5 (this commit)

- **Symptom 2a**: Blue glow sticky on, not fading (mouseExited not triggered)
- **Root cause**: macOS 27 NSTrackingArea `.mouseEnteredAndExited` unstable, especially when NSViewRepresentable bridges
- **Fix**: Add `.mouseMoved` option + override `mouseMoved` to compute `bounds.contains(convert(event.locationInWindow, from: nil))` in real time, set isHovered ourselves (do not go through mouseEntered/Exited)
- **Symptom 2b**: Blue glow too solid
- **Fix**: hover-time accent opacity 0.6 → 0.5, shadow opacity 0.4 → 0.3 (老板 拍 A)

### Ticket 06: cursor switch to up-down arrows (pending)

- **Symptom**: mouse over splitter does not change cursor
- **Root-cause guess**: `resetCursorRects` not recognized by macOS cursor system when NSViewRepresentable bridges (NSView inside SwiftUI view tree is CALayer-wrapped, macOS 27 cursor rects does not recognize)
- **Possible fix**: NSWindow subclassing + `cursorUpdate(with:)` (Apple HIG macOS truth value, same as Pages / Numbers)
- **Workload**: large (pending grill 拍板)

## User Stories

1. As 老板, I want no blank at window bottom, upper:lower = 50:50, so that 6-zone layout matches Sketch `AF7B1C87` 1:1
2. As 老板, I want hover blue glow to disappear immediately when mouse leaves, so that splitter visual feedback is clean
3. As 老板, I want hover blue glow opacity 0.5, so that the background is slightly visible (Apple HIG visual style)
4. As 老板, I want cursor to switch to up-down arrows (D_h) / left-right arrows (D_v), so that feel matches Xcode / Pages

## Implementation Decisions

- **ticket 04**: LayoutShellView VStack `contentH - 52` → `contentH - 2`. Already committed `b4f2021`.
- **ticket 05**: NSTrackingArea add `.mouseMoved` + `mouseMoved` override + `bounds.contains` real-time compute. accent 0.6 → 0.5 + shadow 0.4 → 0.3.
- **ticket 06**: NSWindow subclassing + `cursorUpdate(with:)` (pending grill 拍).

## Testing Decisions

- Only `swift build clean` (exit 0), 老板 self-launches app to verify.
- Do not run Q22 (Screen Recording TCC unauthorized).

## Out of Scope

- macOS chrome 52 PT unchanged (`.windowStyle(.titleBar)`)
- D_h visuals 2 PT static + 4 PT hover unchanged
- 6 PT hit area unchanged
- Range / formula / LayoutTokens unchanged
- D_v 5 vertical splitters behavior unchanged

## Further Notes

- 老板 拍 "effect first, do not compromise for workload, follow pseudo-Apple-official-App principle" — subsequent fixes follow this principle
- ticket 06 (cursor) large workload, pending grill 拍 fix direction
- 3 tickets serial, ordered by workload small to large, each ticket build clean + 老板 verify pass before next