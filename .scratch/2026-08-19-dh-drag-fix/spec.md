# Spec — D_h horizontal splitter cursor feedback + drag response + unlimited range

> Date: 2026-08-19
> Truth source: Sketch `AF7B1C87-ADDD-41ED-8208-7CA5549070E2` (page 文枢-组件化, Artboard 首页) + Apple HIG SwiftUI 4 (macOS 27)
> Spec uses po `to-spec` skill 7-section template

## Problem Statement

老板 2026-08-19 reported: D_h horizontal splitter (the 2 PT black capsule cap line in the middle of the upper/lower zones) is visible, but mouse hover does **not switch cursor** (no up-down arrows), and drag **does not respond** (upper/lower zone ratio unchanged).

From 老板's perspective, the horizontal splitter feels "un-draggable" — visual is there but interaction feedback is missing. The current implementation (v0.15 ticket 014 drag logic + v0.15 ticket 023 cursor feedback) has both been committed, but actual testing shows 2 bugs existing simultaneously.

## Solution

Fix 2 independent bugs:
1. **Cursor feedback**: overturn v0.15 ticket 023's `.onContinuousHover` + `NSCursor.push` implementation. Use another Apple HIG SwiftUI 4 (macOS 27) API to make cursor actually switch to `.rowResize` (up-down arrows).
2. **Drag response**: investigate why v0.15 ticket 014's `adjustBandSplit` + `NativeSplitter(.horizontal)` gesture chain does not work. After fix, upper/lower zone ratio resizes with hand.

Also prepare for the next requirement "zone hide": **D_h drag range unlimited** (`bandOffset` range [-1.0, +1.0]), upper/lower zones can drag from 0% to 100%, no longer limited to ±7 PT.

## User Stories

1. As 老板, I want mouse over D_h horizontal splitter to switch cursor to up-down arrows, so that feel-wise I know it's draggable
2. As 老板, I want pressing D_h splitter to change the upper/lower zone ratio, so that I can flexibly adjust upper/lower zone size
3. As 老板, I want drag-time upper/lower zone ratio change to follow hand without jitter (60 fps), so that drag experience is smooth
4. As 老板, I want D_h drag range unlimited (can drag from 0% to 100%), so that it paves the way for the next "zone hide" requirement
5. As 老板, I want D_h hover to thicken + blue glow (consistent with D_v), so that horizontal/vertical splitter visual feedback is unified
6. As 老板, I want D_v (5 vertical splitters) behavior unchanged, so that the already-implemented width dragging is not broken
7. As 老板, I want `swift build` exit 0, so that I can self-launch app to verify

## Implementation Decisions

- **Cursor fix direction**: overturn v0.15 ticket 023 implementation, use another Apple HIG API. Specific API decided at implement phase (e.g. `NSWindow` subclassing + `resetCursorRects` / `cursorUpdate` / other macOS 27 recommended solution). to-spec does not nail down implementation details.
- **Drag response fix**: investigate `NativeSplitter(.horizontal)` gesture attachment location / `withTransaction(disablesAnimations: true)` influence / whether `vm.bandOffset` mutation triggers view re-render. Specific fix deferred to implement.
- **Drag range**: `bandOffset` accumulation range expands from [-0.15, +0.15] to [-1.0, +1.0] (`LayoutShellViewModel.minOffset / maxOffset`).
- **Do not touch D_v 5 vertical splitters**: their `offsets[0..4]` accumulation range stays at [-0.15, +0.15] unchanged.
- **Preserve visuals**: D_h static 2 PT black / hover 4 PT `Color.accentColor.opacity(0.6)` + shadow, consistent with D_v.
- **Preserve hit area**: 6 PT transparent hit area unchanged.
- **No new components**: reuse NativeSplitter + LayoutShellViewModel.

## Testing Decisions

- **Test scope**: Only `swift build clean` (exit 0). No unit tests (this session has no unit test coverage on D_h).
- **Truth verification**: 老板 self-launches `swift run WenshuApp` + actual test cursor switch + drag upper/lower zone ratio change. Agent does not run Q22 screencapture -l (current Hermes TUI shell session lacks Screen Recording TCC authorization, known fail).
- **Acceptance criteria**:
  - `swift build` exit 0
  - D_v 5 vertical splitters behavior unchanged (老板 v0.15 verified)
  - One ticket = one commit
  - CONTEXT.md domain vocabulary updated

## Out of Scope

- **Do not** implement "zone hide" requirement (老板 拍 "skip for now") — only prepare drag range for it
- **Do not** change D_v 5 vertical splitters (keep v0.15 implementation unchanged, Q20 already implemented, do not directly touch)
- **Do not** change NativeSplitter vertical branch
- **Do not** change `vm.upperBandH` / `vm.lowerBandH` formula (only touch `minOffset` / `maxOffset`)
- **Do not** change macOS chrome / LayoutTokens / bandH ratio operators
- **Do not** change v0.15 ticket 014 commit `6188d16d9` drag logic foundation; only investigate why actual test no response
- **Do not** change v0.16 ticket 01 already-fixed toolbar width algorithm
- **Do not** run Q22 audit gate (Screen Recording TCC unauthorized)
- **Do not** write new ADR (cursor fix specific API not pinned, deferred to implement phase)

## Further Notes

- This is v0.16 ticket 02, right after ticket 01 (toolbar width stretched by VStack stretch to fill zone actual width).
- D_h fix is cursor + drag response two independent bugs fixed together, not split into tickets (vertical slice on the same component).
- v0.15 ticket 023 (cursor) + v0.15 ticket 014 (drag) both committed, but actual test neither works — fix requires root-cause investigation, not just "rewrite same API".
- 老板 Q5 answered "only run build + 老板 self-verify", so agent does not run Q22, only run build clean + code-review two axes.
- 老板 Q1-Q6 all answered, frontier empty, can go directly to-tickets → implement.