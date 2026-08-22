# 01 — Rewrite NativeSplitter with NSView + NSEvent (Apple AppKit truth paradigm)

**What to build:**
老板 2026-08-19 拍 "pseudo-Apple-official App" + historical v0.14.0 commit message TODO (D_h can't drag / D_v5 can't drag / cursor doesn't change) — rewrite NativeSplitter with NSView + NSEvent AppKit paradigm (same as Xcode / Pages / Numbers).

After change:
- D_h / D_v5 / D_v 1-4 total 6 splitters mouseDown/mouseDragged/mouseUp through NSView truth AppKit event flow
- Cursor switch (mouse hover `NSCursor.push` resizeLeftRight / resizeUpDown, no need to click)
- Drag follow hand 60 fps (bypass SwiftUI gesture system, use `NSEvent.delta` directly callback to `vm.adjust` / `vm.adjustBandSplit`)
- Hover blue glow visual preserved (SwiftUI Rectangle inside NativeSplitter body, NSViewRepresentable transparent hit area overlay)
- Range / formula / visual / hit area thickness all unchanged (inherited from v0.16 ticket 02 + v0.15 ticket 014 拍板)

**Blocked by:** None — can start immediately.
**Status:** ready-for-agent

## Acceptance criteria

- [ ] `SplitterHitArea`: NSView subclass (transparent hit area, mouseDown/Down/Up + NSTrackingArea hover)
- [ ] `SplitterHitAreaRepresentable`: NSViewRepresentable bridge (makeNSView + updateNSView)
- [ ] `NativeSplitter`: SwiftUI Rectangle visual + ZStack internal `SplitterHitAreaRepresentable` transparent overlay
- [ ] D_h horizontal splitter mouseDragged → callback to LayoutShellView → `vm.adjustBandSplit` mutate → `@Observable` re-render → upper/lower zone ratio real-time change
- [ ] D_v 5 vertical splitters (including D_v5 chat/dynamic) mouseDragged → callback → `vm.adjust` mutate → zone width change
- [ ] 6 splitters cursor switch normal (vertical = resizeLeftRight, horizontal = resizeUpDown)
- [ ] Hover visual preserved (Rectangle 2 PT black → 4 PT accent + shadow)
- [ ] Hit area thickness 6 PT unchanged
- [ ] Range / formula / VM unchanged (inherited from v0.16 ticket 02 + v0.15 ticket 014)
- [ ] macOS chrome / LayoutTokens / bandH ratio operator / toolbar width all unchanged
- [ ] No new dependencies (use built-in SwiftUI + AppKit NSView / NSEvent / NSCursor / NSTrackingArea)
- [ ] `swift build` exit 0
- [ ] Don't run Q22 (老板 self-verifies)