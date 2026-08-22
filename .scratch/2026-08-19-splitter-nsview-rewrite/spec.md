# Spec — Splitter rewrite to NSView + NSEvent (Apple AppKit truth paradigm)

> Date: 2026-08-19
> Truth source: Apple AppKit NSView + NSEvent (Xcode / Pages / Numbers usage) + macOS 27
> Spec uses po `to-spec` skill 7-section template

## Historical problem (老板 8/19 + historical v0.14.0 commit message known)

v0.14.0 commit `dacbc9fee` 老板 拍 "splitter is 1 component", but commit message TODO at end admits:
> **TODO (actual test 3 wrong)**:
> - horizontal D_h cannot drag
> - D_v5 chat/dynamic cannot drag
> - mouse cursor doesn't change shape

These 3 bugs v0.14.0 known, v0.15 commit `871c1b6c2` LayoutShellView rewrite didn't fix, v0.16 ticket 02 commit `29711dd` only fixed cursor + range, didn't touch drag root cause. **NSLog debug evidence shows dragGesture truly triggers on D_h, but view doesn't respond** + **`.pointerStyle(.rowResize)` also doesn't switch cursor** — root cause not in SwiftUI DragGesture, but in SwiftUI view re-render chain + SwiftUI top-level window cursor system failure.

## Problem Statement

老板 2026-08-19 reported:
1. D_h horizontal splitter — **drag has no response** (upper/lower zone ratio unchanged)
2. cursor **doesn't change** (mouse hover doesn't switch to up-down arrows)
3. v0.16 ticket 02 commit fixed cursor system + range, but **drag response not fixed**
4. 老板 拍 "this software we're building, after estimation is pseudo-Apple-official App" — requires splitter implemented per Apple AppKit truth paradigm (NSView + NSEvent)

From 老板's perspective, splitter should be same as Xcode / Pages / Numbers — mouse hover cursor immediately switches (no need to click), press-drag real-time responds, release positions precisely.

## Solution

Rewrite NativeSplitter using **NSView + NSEvent** AppKit truth paradigm:

1. **`SplitterHitArea: NSView`** subclass — transparent hit-area view, receives mouseDown / mouseDragged / mouseUp + NSTrackingArea hover tracking cursor switch (`NSCursor.resizeLeftRight` / `resizeUpDown`)
2. **`SplitterHitAreaRepresentable: NSViewRepresentable`** — bridge NSView to SwiftUI layout
3. **`NativeSplitter: View`** changed — SwiftUI internally only draws Rectangle visual (2 PT black / hover 4 PT accent), hit area uses NSViewRepresentable transparent overlay
4. **Drag event callback** — NSView mouseDragged → parent LayoutShellView receives delta, `vm.adjustBandSplit` / `vm.adjust()` mutate, `@Observable` auto re-render (truth: NSView directly calls SwiftUI closure, bypasses SwiftUI gesture system, stable)
5. **Cursor switch** — NSTrackingArea + `NSCursor.push` (AppKit standard, same as Xcode)
6. **Preserve visuals** — Rectangle 2 PT black / hover 4 PT accent + shadow (Apple HIG)

### Business-language description (老板 easy-understand version)

- Splitter no longer uses SwiftUI built-in gesture detection
- Switch to AppKit system NSView transparent layer takes over mouse events (same as Pages / Numbers / Xcode)
- Mouse hover — cursor immediately switches (no need to click)
- Press-drag — real-time callback to LayoutShellView, upper/lower zone ratio changes
- Release — positions precisely, doesn't drift

## User Stories

1. As 老板, I want D_h horizontal splitter mouse hover cursor immediately switches to up-down arrows (no need to click), so that same as Xcode / Pages
2. As 老板, I want D_h press-drag real-time change upper/lower zone ratio (60 fps follow hand), so that drag experience is smooth
3. As 老板, I want D_v 5 vertical splitters behavior unchanged, so that already-implemented width drag not broken
4. As 老板, I want D_v5 chat/dynamic splitter can truly work (historical v0.14.0 TODO one, fix together with this rewrite)
5. As 老板, I want hover blue glow visual preserved (Rectangle 2 PT black / hover 4 PT accent), so that visual feedback unchanged
6. As 老板, I want hit area 6 PT preserved, so that drag precision unchanged
7. As 老板, I want `swift build` clean exit 0, so that I can self-launch app to verify
8. As 老板, I want D_h drag range unlimited (inherited from v0.16 ticket 02 拍板), so that paves way for next "zone hide" requirement

## Implementation Decisions

- **NSView subclass** `SplitterHitArea`:
  - Override `mouseDown(with:)` — record starting mouse location
  - Override `mouseDragged(with:)` — compute delta (currentLocation - lastLocation), call SwiftUI parent closure
  - Override `mouseUp(with:)` — clear state
  - `updateTrackingAreas()` — add NSTrackingArea, hover time `NSCursor.push`, mouseExited time `NSCursor.pop`
- **`NSViewRepresentable` bridge**:
  - `makeNSView(context:)` — return `SplitterHitArea` instance
  - `updateNSView(_:context:)` — set frame + inject closure
- **LayoutShellView calls NativeSplitter** — same as v0.15 ticket 006, pass `onDrag` closure
- **NativeSplitter body** — SwiftUI Rectangle visual + ZStack internal `SplitterHitAreaRepresentable` overlay (transparent)
- **Untouched**:
  - VM mutate formula `upperBandH / lowerBandH / adjust / adjustBandSplit` (ticket 014 + ticket 02 already 拍)
  - `minOffset / maxOffset` (±0.15 D_v) / `minBandOffset / maxBandOffset` (±1.0 D_h)
  - D_h visual (2 PT black / 4 PT accent)
  - 6 PT hit area thickness
  - macOS chrome / LayoutTokens / bandH ratio operator
  - v0.16 ticket 01 toolbar width algorithm

## Testing Out

- **Test scope**: Only `swift build clean` (exit 0), no unit tests
- **Truth verification**: 老板 self-launches `swift run WenshuApp` + actual test
- **Acceptance criteria**:
  - `swift build` exit 0
  - D_h / D_v5 / D_v 1-4 6 splitters all truly work (cursor switch + drag response)
  - Hover visual preserved (blue glow + shadow)
  - Drag follow hand (60 fps)
  - macOS chrome / LayoutTokens / bandH ratio operator / toolbar width all unchanged

## Out of Scope

- **Do not** change VM mutate formula
- **Do not** change range constants
- **Do not** change visual spec (2 PT / 4 PT)
- **Do not** change hit area thickness (6 PT)
- **Do not** change macOS chrome / LayoutTokens / bandH
- **Do not** implement "zone hide" (next requirement)
- **Do not** run Q22 audit gate (Screen Recording TCC unauthorized)
- **Do not** write new ADR (NSView + NSEvent paradigm already worked in v0.10.6 + v0.14.0 commits, doesn't count as new architecture decision)

## Further Notes

- This is v0.16 ticket 03, right after ticket 02 (cursor feedback + range unlimited).
- NSView + NSEvent paradigm is Apple AppKit truth standard, wenshu v0.10.6 + v0.14.0 stages already used (commit history checkable).
- v0.14.0 commit `dacbc9fee` 老板 8/18 拍 "splitter is 1 component", but commit message admits 3 TODOs: D_h can't drag / D_v5 can't drag / cursor doesn't change — these 3 bugs fix together in ticket 03.
- 老板 Q11 answered A — rewrite NativeSplitter with NSView + NSEvent.
- Historical v0.10 老板 拍 "老板 8/19 拍 splitter = NSView + NSEvent deltaX/totalW" (commit 19:00 fix), paradigm is Apple AppKit standard.
- Don't touch v0.16 ticket 01 (toolbar width) + v0.16 ticket 02 (cursor + range) already committed changes.