# 02 — hover blue glow stable (remove mouseMoved) + opacity 0.25 (老板 2026-08-19 拍)

**What to build:**
老板 2026-08-19 actual test D_h splitter blue glow 2 problems:
1. Blue glow occasionally does not disappear after mouse leaves (`mouseMoved` drops events when mouse moves fast on macOS 27)
2. Blue glow too solid, want to add transparency (老板 拍 from 0.5 → 0.25, more transparent so the background is visible)

**After change**:
- Remove `mouseMoved` override (Apple AppKit truth: `mouseEntered`/`mouseExited` is the standard)
- Add `mouseDragged` force-set `isHovered = true` (during drag 100% blue glow stays)
- Add `mouseUp` set `isHovered = false` (release immediately clears, no dependence on `mouseExited`)
- `mouseEntered` / `mouseExited` kept (normal hover in/out)
- Opacity 0.5 → 0.25 (老板 8/19 16:50 拍)

**Blocked by:** None — can start immediately.
**Status:** ready-for-agent → impl done → waiting for 老板 verify

## Acceptance criteria

- [ ] Remove `mouseMoved` override (Apple AppKit truth: `mouseEntered`/`mouseExited` is the standard)
- [ ] Add `mouseDragged`: set `onHoverChange(true)` (during drag force keep blue glow)
- [ ] Add `mouseUp`: set `onHoverChange(false)` (release immediately clears, no dependence on `mouseExited`)
- [ ] `mouseEntered` / `mouseExited` kept (normal hover in/out)
- [ ] Opacity: accent 0.5 → 0.25, shadow 0.3 → 0.15 (or keep 0.3 — 老板 8/19 16:50 拍)
- [ ] Static line 2 PT black unchanged
- [ ] 6 PT hit area unchanged
- [ ] Mouse leaves splitter → blue glow stably disappears (mouseExited primary, mouseUp fallback)
- [ ] D_h / D_v 5 vertical splitters all effective
- [ ] During drag → blue glow stays (mouseDragged force-set true)
- [ ] Release → blue glow disappears immediately (mouseUp force-set false)
- [ ] macOS chrome / LayoutTokens / bandH / toolbar width all unchanged
- [ ] `swift build` exit 0
- [ ] No new dependencies (built-in SwiftUI + AppKit)

## Business-language description (老板 understands)

- Blue glow sticky-on: switch to macOS system standard `mouseEntered`/`mouseExited` (remove the previously-tried `mouseMoved`, unstable). During drag force keep blue glow, release immediately clear
- Opacity: 0.25 (老板 8/19 16:50 拍, more transparent so the background is visible)

## Untouched

- macOS chrome 52 PT
- D_h visuals 2 PT static + 4 PT hover unchanged
- 6 PT hit area
- Splitter NSView + NSEvent paradigm (v0.16 ticket 03 already decided, ticket 06 handles cursor later)