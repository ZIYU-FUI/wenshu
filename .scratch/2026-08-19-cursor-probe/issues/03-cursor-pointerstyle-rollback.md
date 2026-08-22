# 03 — cursor switches up/down / left/right arrows (SwiftUI .pointerStyle fallback, 老板 2026-08-19 拍)

**What to build:**
老板 2026-08-19 repeatedly reported "mouse doesn't change". Root-cause report v2 confirms: NSHostingView does not override resetCursorRects, ticket 03 + ticket 06 paradigm is wrong (AppKit cursor rects paradigm should not work in SwiftUI WindowGroup context).
老板 2026-08-19 19:30 Q28 拍 "cursor must switch + describe in business language, do not touch low-level framework code".

Business-language description (老板 understands):
- All the low-level patches added earlier for cursor (NSResponder + NSTrackingArea + hit test — the entire `WenshuCursorController` class + `contentView.hitTest` etc.) are low-level framework code; these were wrong attempts
- Switch to SwiftUI's official cursor API: `.pointerStyle(.columnResize() / .rowResize())` attached to the outermost layer of the splitter (the v0.14 root cause was wrong attachment location, not an API bug)
- Pages / Numbers / Xcode use this exact set (Apple HIG macOS 15+ standard)
- Splitter code 100% unchanged (visual + hover + drag + hit area all preserved)
- Only add 1 line of SwiftUI cursor modifier + delete low-level patch code (`WenshuCursorController` + `findSplitter`)

**Blocked by:** None
**Status:** ready-for-agent → impl done → waiting for 老板 verify

## Acceptance criteria

- [ ] NativeSplitter body ZStack add `.pointerStyle(orientation == .vertical ? .columnResize() : .rowResize())` attached to the outermost layer (parent of ZStack containing Rectangle + SplitterHitAreaRepresentable)
- [ ] Mouse over D_h splitter → cursor changes to ↕ up-down arrows (NSCursor.rowResize / SwiftUI .rowResize truth value)
- [ ] Mouse over D_v 5 vertical splitters → cursor changes to ↔ left-right arrows (NSCursor.columnResize / SwiftUI .columnResize truth value)
- [ ] Mouse leaves splitter → cursor restored
- [ ] Splitter drag / hover blue glow / hit area / 1 PT fill visuals all preserved
- [ ] Delete entire `WenshuCursorController` NSResponder class (App.swift L249-321 whole block)
- [ ] Delete `WenshuAppDelegate.cursorController` property + `cursorController = WenshuCursorController(window: window)` inside `applicationDidFinishLaunching` (App.swift L224-237 whole block)
- [ ] Delete `NativeSplitter.resetCursorRects` (NSView shields cursor rects, confirmed by root-cause report v2)
- [ ] After deleting `cursorController` + `WenshuCursorController`, `swift build` exit 0
- [ ] Do not touch macOS chrome 52 PT / LayoutTokens / bandH / toolbar width
- [ ] Do not touch menu bar (backlog 07 pending)

## Root cause (cursor-investigation-report-v2.md)

- NSHostingView (macOS 27 SDK swiftinterface confirmed) does not override `resetCursorRects()`, but does override `hitTest` / `mouseMoved` / `cursorUpdate`
- This blocks the AppKit cursor rects paradigm from working inside SwiftUI subtrees (ticket 03 + ticket 06 paradigm wrong, not a code bug)
- Recommended: fall back to SwiftUI `.pointerStyle`, skip NSViewRepresentable (Apple HIG macOS 15+ standard)

## Business-language fix description (老板 understands)

- Add 1 line of SwiftUI official cursor switch to the splitter (same as Pages / Numbers)
- Delete the low-level patch code added earlier for cursor (`WenshuCursorController` etc.)
- Splitter visuals / hover blue glow / drag response / hit area 100% unchanged

## Implementation Decisions

- NativeSplitter body L153 `.frame(width: outerWidth, height: outerHeight)` chain finally add `.pointerStyle(...)`
- `orientation == .vertical` → `.columnResize()`, otherwise → `.rowResize()`
- macOS 15+ API (`PointerStyle.columnResize(directions:)` / `.rowResize(directions:)`)
- WenshuApp.swift delete `WenshuCursorController` class + 5 lines related to `WenshuAppDelegate.cursorController`
- NativeSplitter.swift delete `SplitterHitArea.resetCursorRects` whole block (L86-90)
- Keep `SplitterHitArea` mouseDown/mouseDragged/mouseUp/mouseEntered/mouseExited (used by drag + hover blue glow)

## Testing Decisions

- Only `swift build clean` (exit 0), 老板 self-launches app to verify
- Verify: mouse over D_h switches ↕, mouse over D_v switches ↔

## Out of Scope

- Do not rewrite splitter visuals (Rectangle + 1 PT fill + Apple system color preserved)
- Do not touch macOS chrome / LayoutTokens / bandH / toolbar width
- Do not touch menu bar (backlog 07 pending doc check)
- Do not rewrite `SplitterHitArea` NSView (drag + hover blue glow preserved)

## Further Notes

- 老板 v0.14 root cause was wrong attachment location (gesture chain); this time attach to outermost ZStack (parent of Rectangle + NSViewRepresentable)
- `cursor-investigation-report-v2.md` recommended Plan A
- Reverts most of ticket 06 (commit `096b9cb`) (entire `WenshuCursorController` deleted)
- Reverts entire `resetCursorRects` block from ticket 03 (commit `de0f6ec`)