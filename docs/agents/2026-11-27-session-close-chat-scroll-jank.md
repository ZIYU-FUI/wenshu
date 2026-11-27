# Session close: the chat scroll jank, measured and attributed (2026-11-27)

## What this scope was

The boss scrolls the chat column and it reads busy, while the bundle he
actually launches does not. This session was asked to find out whether the
Apple scroll gate (`ab648fbde4`) is the fix, and if not, where the cost is.

No app source changed. The deliverable is a measurement, an instrument that
re-takes it, and this record. The candidate next ticket is filed as text and
not dispatched, because the boss stopped the measuring mid-flight.

## The state the tree is in (dated 2026-11-27)

- One commit carries this record, two probes, and the registry rows that
  describe them: `docs/agents/nfi.md` and
  `Tools/wenshu-devtool/probe-index.md`.
- It sits on `docs/chat-scroll-jank-closeout-2026-11-27`, branched from
  `ba2415ab86`, which was `origin/main`'s tip when the measurement ran.
  `main` has moved past it three times (= `5ceda8cfb1`, the chat
  scroll-position fix; `6343dc09f1`, the sidebar disclosure-mark fix; and
  `c782aa5fa1`, that lane's closeout), and this branch has been REBASED onto
  the newest, so it is one commit ahead of `main` and fast-forwards. A rebase
  rewrites the sha and not the edit, so the diff a reader must check is the
  tip's own: `git show --stat HEAD` at the tip this record's card names.
- `5ceda8cfb1` matters to this record's own open item 2: it deleted 15 lines
  of model-side scroll state out of `ChatViewModel.swift` and moved the
  reader's scroll position into the view. That is one of the candidate
  per-frame writers this record lists, removed AFTER the 34.1 ms reading was
  taken. So the reading describes `ba2415ab86` and NOT today's `main`, and the
  bisect in open item 1 must start from `c782aa5fa1`, not from this base.
- The gate's own commit `ab648fbde4` IS on `main` and on `origin/main`.
- Landing is PENDING. Round 1 (`t_378f0417`) returned CHANGES_REQUESTED
  against the earlier tip `0740c9881a`: the material band was cleared with
  numbers the probe does not print, the open item still described
  `onScrollPhaseChange` as absent while the tree calls it, and the record
  published cost figures no shipped instrument printed. This commit answers
  all three, and the next verdict is requested on THIS tip, so the sha the
  reviewer reads is the sha that lands.
- Nothing in `Sources/` moved, so no build and no UI verdict belongs to this
  scope, and none is claimed.

## The four numbers, each with its base and its window

Every reading names the tree it ran against (`ba2415ab86`), the arm it
belongs to, and the denominator. LOAD / SCROLL / STEADY are the idle window
before the scroll, the window the momentum replay covers, and the idle
window after it.

### 1. The gate is not the fix (a controlled A/B, one session, one driver)

One source tree, one build recipe, one bundle skeleton, one app container,
one transcript, one Instruments template, one scroll point, one 1200-event
momentum replay, the layout pinned to the boss's own column widths
(sidebar 200 / middle 240 / chat 441 to 958), so both arms opened the same
688 pt chat column. The arms differ in `ab648fbde4` alone.

| arm | LOAD hitches/s | SCROLL hitches/s | STEADY hitches/s | render median | renders over one frame |
| --- | --- | --- | --- | --- | --- |
| gate ON | 3.8 | 17.3 | 13.1 | 34.1 ms | 1025 of 1124 (91.2%) |
| gate OFF | 12.8 | 15.1 | 16.4 | 32.2 ms | 1918 of 1918 (100%) |

The last two columns are printed by the probe `chat_scroll_render_cost.py`
(`Tools/wenshu-devtool/probes/`), one run per arm, against that arm's own
`renders.xml`. The hitches columns are the same arm's `hitches.xml`, counted
per whole second inside each window (= rows whose `start-time` falls in the
window, over the window's seconds); that binning is done by the A/B script
`ab2/compare.py` on the data disk, which is NOT in this tree, so those three
columns are the record's own reading of a named export and not a probe
printing. The render rows are read WITH the export's duration `ref` chains
resolved, which is the difference between 1124 rows and the 611 a reader gets
from the cell's inline text alone (= the same export, 45.6% of it invisible to
a parser that stops at inline text).

The gate is a real improvement: it quiets the idle window (12.8 to 3.8) and
halves the render count (1918 to 1124). It is not the fix: a render costs
32 to 34 ms either way against a 16.7 ms frame, so every draw blows the
budget with the gate or without it.

### 2. The difference against the boss's bundle is the per-render cost

`build/Wenshu.app`, 38031600 bytes, built Nov 25 12:51, 60 s recording.

| | the boss's bundle | main today, gate ON |
| --- | --- | --- |
| a render costs | 14.5 ms (fits a frame) | 34.1 ms (over two frames) |
| renders over one frame | 374 of 3840 = 9.7% | 1025 of 1124 = 91.2% |

Both rows come from the same probe, run against the bundle's own
`renders.xml` with its recording length given: `14.54 ms` and `374 of 3840`
and `64.0` renders per second for the boss's bundle, `34.10 ms`, `1025 of
1124` and `26.8` renders per second for main.

The recordings differ in length (60 s against 42 s), so the raw render
COUNTS are not comparable across builds. The median and the over-one-frame
fraction are, and both point the same way. The boss's app is not quiet: it
re-renders 64 times a second and burns 95% of a core, and its scroll window
hitches too. What it does not do is blow the frame budget, so the display
keeps up. Main does LESS work per second (26.8 renders) and burns slightly
less CPU (87.3%), and reads far worse. The regression is the cost of one
draw, not how often it runs.

### 3. Where the cost actually is: the leaf frame's owning binary

The pinned gate-ON arm recorded its own `time-profile` table in the SAME run
that produced the 34.1 ms median. 5161 rows, of which 5100 are Main Thread,
spanning 00:11.762 to 00:40.793. Attributed to the binary that declares the
LEAF frame (= where the CPU was), not summed over the stack:

| the leaf frame's owner | samples | share |
| --- | --- | --- |
| the Swift / ObjC runtime | 1965 | 38.5% |
| SwiftUI's own machinery | 1709 | 33.5% |
| Foundation / CoreFoundation | 378 | 7.4% |
| no binary names the leaf | 255 | 5.0% |
| AppKit / the hosting bridge | 217 | 4.3% |
| no frames at all | 209 | 4.1% |
| the graphics stack | 107 | 2.1% |
| the system libraries | 102 | 2.0% |
| another binary (DesignLibrary) | 59 | 1.2% |
| the text engine | 44 | 0.9% |
| THE APP'S OWN BINARY | 24 | 0.5% |
| the render server | 15 | 0.3% |
| another binary (libswiftObservation.dylib) | 11 | 0.2% |
| another binary (libhvf.dylib) | 5 | 0.1% |

The table sums to 5100, the Main Thread row count, by construction. The app
binary is the throwaway A/B executable (`JankGateOn`), not the shipped
`WenshuApp`.

The same rows read by leaf SYMBOL name put SwiftUI's attribute graph at 551
(10.8%) and name the top leaves: `AG::Graph::UpdateStack::update()` 139,
`AG::Graph::propagate_dirty(AG::AttributeID)` 101, `AG::Subgraph::update`
44, `find(_:key:filter:)` 177 with its `closure #6` 100, `objc_msgSend` 106.

### 4. The material and the text engine are not the hot spot

The band under suspicion was `ContentAreaMaterial.surface`, an
`NSVisualEffectView` with `.withinWindow` blending
(`Shared/UI/ContentAreaMaterial.swift:78-79`). Measured on the same 5100
rows, against the class the probe names once and prints both ways
(`material / glass / the backing store` = a paint, composit, material,
glass or backing word): the class is MENTIONED anywhere in the stack in
4199 rows (82.3%), and the class IS the LEAF in 28 rows (0.5%). The
text engine's leaf bucket is 23 (0.5%), and the largest individual
material symbol accounts for 5 leaf rows (`CA::Layer::retain_parent`),
with `-[CALayer retain]` next at 4. 82.3% is what a stack-wide roll-up
prints; 0.5% is what the CPU was doing. The suspect is cleared.

Both numbers are printed by the probe itself, in its `the material class,
measured two ways` section, so this record publishes nothing the
instrument does not print.

## The correction this record carries

An earlier board comment on `t_eb1825b0` (= comment 3185) published three
figures from the same export that this record does NOT repeat, because they
came from a parser that resolved a row's `<binary ref=` through the name
attribute only and so lost the owner of most leaf frames:

| published then | re-taken now | why it moved |
| --- | --- | --- |
| the runtime at 770 / 15.1% | 1965 / 38.5% by owner, 1267 / 24.8% by leaf name | the earlier count was a leaf-NAME bucket; the owner bucket needs the `ref` chain |
| SwiftUI graph plus tracking at 30.3% | 551 / 10.8% by leaf name, 1709 / 33.5% by owner | 30.3% is not producible from any denominator in the export |
| the app's own frames at 2 of 5100 (0.04%) | 24 of 5100 (0.5%) | a `Chat*` name match, against the binary that owns the frame |

The earlier reading also said 4047 leaf samples where the row count is 5100,
and 63.7% of rows as unnamed, which was the parser's gap and not a fact
about the app. The conclusion it argued (= the repetition, not one expensive
view) survives and is the stronger half of the record; its percentages do
not. Read section 3 instead.

## The instrument

Two probes carry this record, and every number in the tables above is one of
them printing.

`Tools/wenshu-devtool/probes/chat_scroll_render_cost.py` prints the cost
columns: a render's median, its p90, the count of renders that exceed one
frame, and the renders per second, from an `xctrace export` of a frame table.
Its whole reason to exist is the export's `ref` encoding: a repeated duration
is written ONCE and referenced thereafter, so a reader that only takes a
cell's inline text loses 45.6% of the gate-ON table (= 611 rows of 1124) and
reports 512 frames over budget instead of 1025. The probe prints both readings
side by side, so the trap is visible in its own output.

`Tools/wenshu-devtool/probes/chat_scroll_leaf_attribution.py` prints both
attribution tables above from an `xctrace export` of a `time-profile` table.
It encodes three facts the export hides: the backtrace is LEAF-FIRST, every
name and every binary arrives by `ref=` to an earlier declaration, and a
frame's binary is its CHILD element, so a referenced frame keeps the binary
its own declaration carries. It also prints how many rows it could NOT name,
because a bucket that swallows most of the table is a parser gap, not a
finding.

```bash
python3 Tools/wenshu-devtool/probes/chat_scroll_leaf_attribution.py \
  /Volumes/ANAN/wenshu-jank-traces/ab2/run-on/tp.xml \
  'gate-ON (the pinned arm, its own run)' JankGateOn
```

The export lives on the data disk (11 MB, kept out of git), next to the two
`.trace` bundles and the A/B driver scripts. If it has been released, the
block above fails with a missing-file error and the tables in this record
stand as dated readings.

```bash
# SKIP: re-exporting needs the recorded bundle and takes minutes of
# Instruments merge; the export above is the artifact this record measured.
xctrace export --input /Volumes/ANAN/wenshu-jank-traces/ab2/run-on/hitches-on.trace \
  --xpath '/trace-toc/run[@number="1"]/data/table[@schema="time-profile"]' \
  --output /Volumes/ANAN/wenshu-jank-traces/ab2/run-on/tp.xml
```

## What this scope changed, and what it did not

- No file under `Sources/` changed. The scroll gate stays shipped at
  `ab648fbde4`, on the evidence that it is directionally right and cheap.
  It is not proven to fix the jank, and section 1 is the measurement that
  says so.
  The gate is not a flag: it is Apple's own two answers,
  `onScrollPhaseChange` (`ChatView.swift:294`) and
  `onScrollTargetVisibilityChange` (`ChatView.swift:303`), which replaced
  the tree's own arithmetic over `ScrollGeometry` (the deleted
  `distanceFromBottom`, `atBottomBand`, `isAtBottom`). There is no
  runtime switch to turn it off, so the A/B's OFF arm is that one commit
  REVERTED, not a setting changed.
  (The OFF arm's own binary proves the arms differ: `distanceFromBottom`
  occurs 0 times in the gate-ON binary and once in the gate-OFF one.)
- The candidate next ticket (= a flat surface for the user's band, which
  removes one AppKit bridge crossing per user message) is written up but not
  dispatched. Its body carries the figures above, not the corrected-away
  ones.
- The real fix is still unwritten. What this scope bought is a narrowed
  question: which per-frame write makes SwiftUI re-evaluate the transcript
  26.8 times a second at 34 ms a draw, when the same app on Nov 25 drew the
  same column in 14.5 ms.

## Open items, and how to pick this up

1. Bisect the per-render cost between the Nov 25 bundle (`14.5 ms`) and
   `ba2415ab86` (`34.1 ms`) on the SAME pinned layout. This is the one
   experiment that turns a description into a cause, and it was not run.
2. Name the per-frame writer. The candidates are the transcript's
   scroll-coupled writes (a `scrollPosition(id:)` binding that writes back to
   an `@Observable` model, an `onScrollGeometryChange` writing a `@State`, an
   `onChange` calling into the model) and the context meter
   (`b943733a9b`, `c94c384db7`). `onScrollPhaseChange` (macOS 15+) is the
   Apple API that separates the gesture from the momentum tail, and the tree
   already calls it and `onScrollTargetVisibilityChange`
   (`ChatView.swift:294` and `:303`), so the open question is which writer
   those two hand their events to, not whether to add the API.
3. Read the leaf attribution against a gate-OFF run, to see whether the
   runtime's 38.5% is the gate's own work or the tree's.
4. The machine is a confound. Readings taken while sibling sessions compile
   move by 2 to 3 times. Report the minimum, never the mean, and record what
   else was running.

## The eight steps, and which are pending

| step | state |
| --- | --- |
| 1. §7 gates on the merged tree | PENDING THE LANDING, (= no merge happened, (= so no merged tree exists to run in). The change-scoped gates ran on the branch tip and are logged under `.gate-logs/`. |
| 2. the verdict on the board | DONE on `t_eb1825b0` (= comments 3182 to 3185), AND corrected by this record's correction section, (= which is what step 2's numbers now point at). |
| 3. this doc, git-tracked, English, committed | DONE, in this commit. |
| 4. durable lessons into the skills | DONE, in `wenshu-visual-audit/references/measuring-a-scroll-jank-on-the-real-device.md` (= a new section on leaf attribution, and the shared tree's copy synced forward so the reviewer profile reads it too). |
| 5. clean only own residue | DONE for this session's own processes and scratch; the `.trace` bundles, the exports and the driver scripts were KEPT on the data disk on purpose, because they are what makes this record re-takable. |
| 6. re-check the final state and report | DONE, the state above was read from the tree (= branch, worktree, registry) and not from recall. |
| 7. sweep the board's open columns | DONE. Re-read after the fact: 8 open cards = 2 blocked, 3 running (all reviews, all with alive workers), 3 ready. None is this scope's. `t_f24c09b7`, the review this record named earlier as the blocker, has since CLOSED with `changes_requested`, and its round 2 (`t_0911b927`) approved at `5ceda8cfb1` = today's `main`, so THAT lane's code is merged and pushed. Three other review cards are live instead, which is why step 8 still does not fire. |
| 8. land the card this scope dispatched | NOT APPLICABLE, this scope dispatched no card. This record's own branch is not merged, for the reason in the state section. |

## The gates that ran on this change

```bash
python3 Tools/wenshu-devtool/probes/chat_scroll_render_cost.py \
    /Volumes/ANAN/wenshu-jank-traces/ab2/run-on/renders.xml gate-ON 42
python3 Tools/wenshu-devtool/nfi-loc-check.py --base HEAD~1
python3 Tools/wenshu-devtool/ci_change_gate.py --base HEAD~1 --check markdown-newline
python3 Tools/wenshu-devtool/ci_change_gate.py --base HEAD~1 --check loc-cap
```
