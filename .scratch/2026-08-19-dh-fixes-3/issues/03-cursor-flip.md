# 03 — cursor switch up-down / left-right arrows (NSWindow subclassing + cursorUpdate, pending)

**What to build:**
老板 2026-08-19 actual test: mouse over D_h splitter does not switch to up-down arrows; over D_v splitter does not switch to left-right arrows.

**Blocked by:** ticket 02 (老板 first verifies hover fix)
**Status:** TBD — pending 老板 拍 fix direction

## Known root cause

- `NSView.resetCursorRects()` committed (ticket 03), actual test does not switch (老板 8/19)
- Guess: when NSViewRepresentable bridges, the NSView inside SwiftUI view tree is CALayer-wrapped; macOS 27 cursor rects system does not recognize
- Alternative truth: NSWindow subclassing + `cursorUpdate(with:)` (Apple HIG macOS truth, same as Pages / Numbers / Xcode)

## Pending grill

- A: NSWindow subclassing + cursorUpdate (large change, matches pseudo-Apple-official principle)
- B: NSCursor custom image (medium change, no dependence on system NSCursor)
- C: Other Apple HIG paradigms

## Acceptance criteria

- Mouse over D_h → cursor changes to up-down arrows (NSCursor.resizeUpDown / .rowResize visual)
- Mouse over D_v → cursor changes to left-right arrows (NSCursor.resizeLeftRight / .columnResize visual)
- Mouse leaves splitter → cursor restored
- During drag cursor persists (cannot reset)
- Does not break other interactions

## Out of Scope

- Do not rewrite SplitterHitArea NSView subclass (v0.16 ticket 03 already decided)
- Do not change 6 PT hit area
- Do not change hover visuals