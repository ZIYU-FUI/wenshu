# Backlog — Splitters / dividers / menu bar (老板 2026-08-19 拍)

> This file records requirements that 老板 拍-ed but the current ticket does not touch / awaiting scheduling.

## Backlog 01 — Remove "rounded cap" design (Rectangle .clipShape(.capsule))

**Status**: ✅ done — commit `c047afc9` (v0.17 ticket 08)

## Backlog 02 — Cursor not changing

**Status**: ✅ done — commit `f65bb329` (v0.17 ticket 03 cursor fallback to .pointerStyle)
- Root-cause report: `cursor-investigation-report-v2.md` (552 lines, 39 KB)
- Root cause: NSHostingView does not override resetCursorRects but overrides hitTest, blocking AppKit cursor rects paradigm
- Fix: fallback to SwiftUI `.pointerStyle(.columnResize / .rowResize)` attached to outermost ZStack (Apple HIG macOS 15+ standard)
- Delete `WenshuCursorController` NSResponder + `WenshuAppDelegate.cursorController` + `SplitterHitArea.resetCursorRects` (previously wrong paradigm)
- Splitter visuals / hover blue glow / drag response / hit area / 1 PT fill all preserved
- Awaiting 老板 verify cursor switch ↕ / ↔

## Backlog 03 — Splitter static color `Color.black` → `Color(nsColor: .separatorColor)`

**Status**: ✅ done — commit `c047afc9` (v0.17 ticket 08)

## Backlog 04 — Other wenshu static Color → NSColor semantic audit

**Status**: ✅ done — commit `c047afc9` (v0.17 ticket 08, DesignColor.accentBlue / splitterLine changed)

## Backlog 05 — Splitter not reaching edge (off by 1 pixel)

**Status**: ✅ done — commit `e359e27` (v0.17 ticket 02 reach edge)
- NativeSplitter lineThickness 2 → 1
- NativeSplitter hoveredThickness 4 → 3
- NativeSplitter hitAreaThickness 6 → 1

## Backlog 06 — Divider not reaching edge (off by 1 pixel)

**Status**: ✅ done — commit `e359e27`
- StaticDividerHorizontal Rectangle `frame(height: 2)` → `frame(height: 1)`
- StaticDividerVertical Rectangle `frame(width: 2)` → `frame(width: 1)`

## Backlog 05 (old) — Splitter not reaching edge (off by 1 pixel)

**Source**: 老板 2026-08-19 19:00 拍

**Current implementation**:
- NativeSplitter body Rectangle L155 `.fill(...) .frame(width: lineFrame.width, height: lineFrame.height)`
- `outerWidth` = `hitAreaThickness` (6 PT) for vertical, length for horizontal
- Rectangle frame = 2 PT (static) / 4 PT (hover)
- Visual: splitter 2 PT centered, 2 PT blank each side ((6 - 2) / 2)

**Root-cause guess**:
- Rectangle frame is `lineFrame.width` (2 PT centered), hit area is 6 PT
- Hit area is transparent NSView overlay; visual Rectangle is centered inside hit area
- 老板 sees "off by 1 pixel" = visual Rectangle does not 100% occupy hit area width, with 1-2 PT blank top/bottom or left/right
- Possible: Rectangle frame should be `hitAreaThickness` (6 PT) visually filling hit area, leaving top/bottom blank to transparent hit-area region

**Truth source (Sketch AF7B1C87)**:
- D_h truth: x:0, y:517, w:1920, h:2 (spans full window width, 1920 PT 1:1)
- D_v truth: x:200 / 720 / 1244, y:52, w:2, h:465 (full band height, 2 PT wide, fills hit area)

**Target fix (pending)**:
- Option A: Rectangle frame change to `hitAreaThickness` (6 PT) visually filling hit area, making Rectangle "appear to" reach the edge
- Option B: Rectangle frame keep 2 PT but NSTrackingArea bounds exactly equal Rectangle visual area
- Option C: 1 PT tweak (e.g. Rectangle frame +1 PT = 3 PT visual) to resolve off-by-1-pixel

**Acceptance criteria**:
- Splitter visual reaches edge (off by 0 pixel)
- D_h spans full window width
- D_v fills zone height
- Does not break implemented drag interaction + hover blue glow
- 1:1 match Sketch AF7B1C87
- `swift build` exit 0

**Priority**: medium (visual detail, already commit-verified, but off-by-1-pixel affects 1:1 Sketch truth)
**Blocked by**: 老板 拍 option
**Status**: backlog

## Backlog 06 — Divider not reaching edge (off by 1 pixel)

**Source**: 老板 2026-08-19 19:00 拍 ("divider is the same, handle together")

**Current implementation**:
- StaticDividerHorizontal: Rectangle `frame(width: w, height: 2)`
- StaticDividerVertical: Rectangle `frame(width: 2, height: height)`
- Same problem as D_h / D_v (Rectangle frame centered, hit area not centered)

**Target fix**:
- Fix together with backlog 05, Rectangle frame fills entire split region

**Acceptance criteria**:
- Divider visual reaches edge (off by 0 pixel)
- Does not break implemented visuals
- `swift build` exit 0
**Priority**: medium (scheduled with backlog 05)
**Blocked by**: backlog 05 option 拍
**Status**: backlog (merged with backlog 05)

## Backlog 07 — Menu bar invisible root cause (deleg_a9c4fde9 doc-check done)

**Status**: ✅ root cause + fix — commit pending (deleg_a9c4fde9 47 min, 120 tool calls)

**Root cause (P0)**:
- vdhamer/Photo-Club-Hub-HTML#248 (open since 2026-08-13) public record: `CommandGroup(replacing: X) { }` does not delete group — it replaces with empty group, each empty group still contributes a separator, SwiftUI-layer API cannot clean up what it itself left behind
- Confirmed mechanism: WenshuAppDelegate touched NSWindow before SwiftUI finished main menu, + macOS 27 beta lazy menu populate = the entire top menu bar never installed

**URL truth references**:
- https://github.com/vdhamer/Photo-Club-Hub-HTML/issues/248
- https://developer.apple.com/documentation/swiftui/app/commands (sosumi.ai mirror)
- https://developer.apple.com/documentation/swiftui/commandmenu
- https://developer.apple.com/documentation/swiftui/commandgroup
- https://developer.apple.com/documentation/swiftui/commandgroupplacement

**Target fix (pending 老板 拍)**:
- Option A: comment out WenshuAppDelegate (let SwiftUI install menu itself, do not touch before NSWindow)
- Option B: add `NSApp.mainMenu?.items.forEach { $0.submenu?.update() }` at end of applicationDidFinishLaunching to force install
- Option C: use `.commandsReplaced` to force install
- Option D: fallback to AppKit (`NSApplicationMain` + manual NSMenu)

**Acceptance criteria**:
- macOS top menu bar visible
- Under top-level "文枢" you can see "Settings..." (same as Pages / Numbers / Xcode)
- Shortcut ⌘, works
- Click opens settings dialog
- Does not break other functions (cursor switch / drag / hover)

**Priority**: high (basic UI)
**Blocked by**: 老板 拍 option + cursor ticket 03 verification passed

**Status**: ⚠️ fix A implemented (commit `464d4f34`), awaiting 老板 verify screenshot
- commit `464d4f34` deletes `WenshuAppDelegate.applicationDidFinishLaunching` `setContentSize`/`center`/`guards` code that touched NSWindow early
- Keep SelfScreenshot call
- SwiftUI WindowGroup + `.defaultSize` + `.windowStyle(.titleBar)` manage size + chrome itself
- ⚠️ did not add `.commandsReplaced` (Apple truth API call method uncertain, 8/15 bug debugging rule do not guess)
- Pending: 老板 launches app + screenshots to verify whether menu bar is visible + 拍 next step (if menu bar still invisible, go option B/C/D)