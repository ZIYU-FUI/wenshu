# 01 — D_h horizontal splitter cursor switch + drag response + unlimited range

**What to build:**
老板 2026-08-19 reported 2 bugs on D_h horizontal splitter:
1. Cursor does not switch (mouse hover does not change to up-down arrows)
2. Drag has no response (upper/lower zone ratio unchanged)

After change:
- D_h hover-time cursor switches to up-down arrows (Apple HIG SwiftUI 4 macOS 27 API, overturn v0.15 ticket 023)
- D_h press-drag can change upper/lower zone ratio (investigate v0.15 ticket 014 actual test not-working root cause)
- D_h drag range unlimited (`bandOffset` range [-1.0, +1.0], prepare for next "zone hide" requirement)
- D_v 5 vertical splitters behavior unchanged (Q20 already implemented, do not directly touch)
- `swift build` exit 0

**Blocked by:** None — can start immediately.
**Status:** ready-for-agent

## Acceptance criteria

- [ ] D_h horizontal splitter hover-time cursor switches to up-down arrows (symmetric with D_v columnResize)
- [ ] D_h press-drag, upper/lower zone ratio changes in real time (60 fps follow hand no jitter)
- [ ] D_h drag range unlimited (bandOffset [-1.0, +1.0])
- [ ] D_v 5 vertical splitters behavior unchanged
- [ ] D_h visuals preserved (static 2 PT black + hover 4 PT accent + shadow)
- [ ] D_h hit area stays 6 PT
- [ ] `swift build` exit 0
- [ ] macOS chrome / LayoutTokens / bandH ratio operators / D_v / toolbar width algorithm (v0.16 ticket 01) all unchanged
- [ ] No new components
- [ ] Do not run Q22 (Screen Recording TCC unauthorized), 老板 self-verifies

## Implementation-layer options (拍 by 老板 when reviewing ticket)

- Cursor API: overturn `.onContinuousHover` + `NSCursor.push` (v0.15 ticket 023), use other macOS 27 SwiftUI 4 API
- Drag investigation direction: `NativeSplitter(.horizontal)` gesture attachment location / `withTransaction` influence / whether `vm.bandOffset` mutation triggers view re-render