# Editor tab strip: the column width belongs to the writer

Date: 2026-10-22
Branch: `main`
Commits: `443202f8b` (width + scrolling), `939494461` (hide the indicator)

## The complaint

After opening several books the editor column stopped responding to the
mouse. The tab strip kept its full width, the column could not be pulled
narrower, and the tabs past the column's right edge were drawn underneath
the tools panel on the right.

Two requests: the writer chooses the column's width, and the tab strip
scrolls left and right inside whatever width the writer chose.

## What was actually wrong

The column was never the constraint. The tab strip was.

Measured on the running app (2026-10-22, read-only accessibility census,
9 documents open, window 1165 PT):

| Fact | Value |
| ---- | ----- |
| Tab segments | 9, each 131.5 PT |
| Tab strip extent | 818 .. 2001.5 = 1183.5 PT |
| Hosting column | 817 .. 1271.5 = 454.5 PT |
| Strip overflow past its column | 730 PT |
| Strip overflow past the window | 836.5 PT |

The decisive A/B: the window was resized and the same two numbers were
re-read. The column tracks the window; the strip does not move.

| Window | Hosting column | Strip width |
| ------ | -------------- | ----------- |
| 1400 | 689.5 | 1183.5 |
| 1165 | 454.5 | 1183.5 |
| 1000 | 289.5 | 1183.5 |

So dragging the divider narrowed the column and the strip simply reached
further across the neighbouring column. The strip's own width was the
floor.

That floor is per-segment, not per-control. An offscreen AppKit probe of
`NSSegmentedControl` with the app's exact configuration (`.fillEqually`,
`.roundRect`, `.large`, the app's titles) measured the minimum width
growing linearly with the segment count: 1 segment 54 PT, 3 = 395,
5 = 658, 8 = 1052, 12 = 1578, 20 = 2630. The per-segment floor is
131.5 PT, and 9 x 131.5 = 1183.5, which is the measured strip width.

A reproduction of the app's real structure (NavigationSplitView -> detail
column hosting an `NSSplitViewController` -> editor pane hosting the
strip) showed the detail column's own minimum stays at 441 PT whatever
the segment count. The column was free the whole time.

## The fix

`NSSegmentedControl` with `.fillEqually` claims an equal share of its
whole track, so the track's width is a floor. The strip now takes one
share of the measured column width per segment (`EditorTabStrip` already
measured that width and did not use it), and the strip lives in a
horizontal scroll container that clips it to the column and makes the
overflow reachable by scrolling. Selecting a tab that has scrolled out of
view brings it back.

`LabelSegmentedControl` gained the per-segment path its own doc comment
had always described but never applied: a caller-supplied segment width
switches the control to `.fit` and `setWidth(_:forSegment:)`, while the
caller that supplies none (the inspector's page strip) keeps the
equal-share track.

The horizontal scroll indicator is hidden, because Apple's own tab bars
scroll the overflow without one.

## After

| | Before | After |
| ---- | ------ | ----- |
| Tab strip extent | 792 .. 1976 | 638 .. 1430 (the window edge) |
| Per-segment width | 132 PT | 88 PT (the readable floor) |
| Overflow past the window | 434 PT | 0 |
| Hosting column (window 1395 -> 1000) | - | 685 -> 289 |
| Horizontal scroll bar | x=637, 19 PT tall | gone |

The strip's geometry is otherwise unchanged by the indicator change: 9
segments, 88 PT each, extent 638 .. 1430, before and after.

## What this cost

Nothing in the column's own constraints changed, and the strip's visual
design did not change: it is still the macOS 27 native segmented control
with `role = .valueSelection` and `segmentStyle = .roundRect`, and the
selected segment still paints its title.

## Notes for the next session

Two environment faults cost time on 2026-10-22 and are NOT in the code:

- The `wenshu-dev` profile's default model (`MiniMax-M3.1`) is not
  available on the `minimax-cn` provider, so a card spawned with it dies
  immediately with `HTTP 400: unknown model 'minimax-m3.1'`. Pin a
  listed model on the card (`hermes kanban set-model <id> MiniMax-M3
  --provider minimax-cn`).
- A board worker running `Scripts/build-app.sh` terminated the shared
  checkout's running instance. Every build ships the same executable
  basename, so a loose `pkill -f` matches every tree. Anchor kills to
  the tree's absolute path.
