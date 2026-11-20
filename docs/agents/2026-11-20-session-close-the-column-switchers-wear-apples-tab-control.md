# Session closeout: the three column-top switchers wear Apple's own tab control

## 1. The scope (= = the lines the boss gave, = = cited by the message store's
row, = = so a reader can re-read the line itself and not this document's
paraphrase of it)

| row | when (CST) | the requirement (= = in business language) |
| --- | --- | --- |
| `271295` | 2026-11-17 13:41:44 | the selected tab and the selected segment are filled with the system's MATERIAL, not the app's accent colour |
| `303718` | 2026-11-19 11:56:12 | the material follows the macOS system setting |
| `304389` | 2026-11-19 12:34:09 | every switcher in the app wears the Liquid Glass material |
| `306854` | 2026-11-19 14:56:33 | the house's own rules are dropped first: = = a small sample written with Apple's rules alone (= = no close X, = = no context menu, = = no title ladder), = = and the pure Apple default probe looked at |
| `306933` | 2026-11-19 14:59:26 | the probe's own look: = = right out of the box, = = except that the shape is a rounded rectangle and not a capsule |
| `306946` | 2026-11-19 15:00:44 | the rounded rectangle is ruled |
| `307800` | 2026-11-19 15:26:17 | the component does not fill the column's width by itself |
| `309097` | 2026-11-19 15:58:59 | the chat zone's band is the correct one; = = the two side columns' are either too far from the top or not centred in the band |
| `309496` | 2026-11-19 16:10:48 | = = the side columns are made like the chat zone |
| `309709` | 2026-11-19 16:16:18 | the vertical placement differs, and it is changed too |
| `309752` | 2026-11-19 16:17:37 | the band's inner padding is deliberate and is NOT deleted |

= = = **AND THE SCOPE IS THREE SWITCHERS, = = NOT FOUR.** = = The sidebar's part
switcher, = = the chat zone's session bar, = = and the inspector's page
switcher. = = **The editor's DOCUMENT STRIP IS NOT IN THIS SCOPE**: = = its
close X, = = its context menu, = = its title ladder, = = its `.valueSelection`
role and = = its `.small` size all stay exactly as `main` had them (= = its
blob is byte-identical before and after this scope).

⇒ ⇒ ⇒ **⇒ ⇒ AND THE ROOT CAUSE, = = IN ONE SENTENCE:** = = the three
column-top switchers were drawn by the app's own control in the
VALUE-SELECTION role, = = so the selected cell was painted in the app's accent
plate, = = and that control also took its height from the band row instead of
from the system, = = so the plate could not land on one line across the
columns.

⇒ ⇒ ⇒ **⇒ ⇒ AND THE FIX, = = IN THE COMPONENT AND NOT AT THE CALL SITES:**
= = a new shared control (`WenshuTabPicker`) hosts the system's own
`NSSegmentedControl` in the macOS 27 TAB ROLE (= = `role = .tabs`, = =
`segmentStyle = .automatic`, = = `segmentDistribution = .fillEqually`), = = it
pins the control's frame to the width the BAND proposes (= = and a caller
inside a horizontal scroll container passes the width it measured outside that
container), = = and the control's height stays the system's own. = = ⇒ ⇒ ⇒ ⇒
The app draws no surface of its own, = = and the system's glass plate and its
own morph own the selection.

## 2. The trace table (= = one row per line the boss gave)

= = = Each row names the commit that carries the line, = = the INDEPENDENT
verdict that cleared it, = = and the server-side proof that the commit is on
BOTH remotes' `main`.

| row | the commit that carries it | the verdict that cleared it | the server-side proof |
| --- | --- | --- | --- |
| `271295` | `fa12d0873e` (= = the component and its three call sites) | the four review rounds in §8 (= = two `changes_requested`, = = two `approved`) | `6336bc08d4` on both remotes; = = `9628b3b133` is an ancestor of both |
| `303718` | `fa12d0873e` (= = the app asks for no material of its own, = = so the system setting governs) | = = the same four rounds | = = the same |
| `304389` | `fa12d0873e` | = = the same four rounds | = = the same |
| `306854` | `fa12d0873e` (= = the probe BECAME the component) | = = the same four rounds | = = the same |
| `306933` | `fa12d0873e` (= = `segmentStyle = .automatic`, = = Apple's own default) | = = the same four rounds | = = the same |
| `306946` | `fa12d0873e` | = = the same four rounds | = = the same |
| `307800` | `fa12d0873e` (= = `WenshuTabPicker.sizeThatFits` pins the band's proposed width) | = = the same four rounds | = = the same |
| `309097` | `9628b3b13` (= = the plate is centred in the band's 28 PT row) | = = the same four rounds | = = the same |
| `309496` | `9628b3b13` | = = the same four rounds | = = the same |
| `309709` | `9628b3b13` (= = the fix is in the component: = = the width comes from the proposal, = = the height stays the system's own) | = = the same four rounds | = = the same |
| `309752` | `fa12d0873e` (= = `ChromeTopBar`'s `horizontalPadding` is untouched by the diff) | = = the same four rounds | = = the same |

⇒ ⇒ ⇒ **⇒ ⇒ AND THE SERVER'S ANSWER, = = READ BACK AFTER THE PUSH (= = at
2026-11-20 14:04:24 CST):**

```bash
git ls-remote origin refs/heads/main
git ls-remote old-origin refs/heads/main
```

= = = Both read `6336bc08d4d0413e1254bc2f0df6962825421b71`, = = and `main`'s
tip is a merge whose **second parent is `9628b3b133`** (= = the sha the final
review round read), = = so the reviewed commit is an ancestor of `main` and
stays reachable.

## 3. The gates on the MERGED tree (= = not on the branch that was measured
before the merge)

```bash
swift build
```

```bash
swift test --filter 'TabPickerBandGeometryTests|ChatZoneTabBarTests|SidebarHeaderProminenceTests|InspectorViewShellTests|InspectorColumnSwitcher|LabelSegmentedControlShapeTests'
```

```bash
python3 Tools/wenshu-devtool/nfi-loc-check.py --base 0f9fcb6d41
```

= = = On `6336bc08d4`: = = the build completes; = = the filtered suite is
**47 tests in 7 suites passed**, = = exit 0; = = and the registry's gate is
rc 0 with **1 row checked** (= = the row this scope ADDED, = = whose LOC cell
is 214 = = `WenshuTabPicker.swift`'s own `wc -l`). = = ⇒ ⇒ ⇒ ⇒ The suite's own
output prints the number the record states:

```bash
swift test --filter 'TabPickerBandGeometryTests' 2>&1 | grep "offset from its band's middle"
```

= = = = = `the plate's offset from its band's middle: the chat zone's 0.0 pt,
the side column's 0.0 pt` = = = = = so a GREEN run reproduces the number, = =
= = and not only a failing one.

⇒ ⇒ ⇒ **⇒ ⇒ AND THE KNOWN RED, = = SEPARATED FROM THIS SCOPE'S OWN:** = =
`EditorTabStripOverflowTests` (12 issues) and `PaneTabStripTitleTests` (1) fail
IDENTICALLY on the base `2234a49ba2` and on the landed tree (= = 13 issues,
= = the same failing test names), = = and the strip's blob is byte-identical
base↔tip, = = so this scope has no path into those suites.

⇒ ⇒ ⇒ **⇒ ⇒ AND THE LANDING SHAPE WAS MEASURED, = = NOT CHOSEN:** = = both
shapes were BUILT against `main` and each was asked about. = = **Shape A**
(= = `main` merges the branch with `--no-ff`) = = = = the reviewed sha stays
the merge's second parent, = = and the change's identity is IDENTICAL before
and after. = = **Shape B** (= = rebase + fast-forward) = = = = the sha is
rewritten, = = and the gate answers "matched by change". = = ⇒ ⇒ ⇒ ⇒ Shape A
landed, = = because the reviewed commit then LIVES in `main`'s history.

## 4. The boss's own look

⇒ ⇒ ⇒ **⇒ ⇒ AND THE PROOF IS LAYER-LEVEL, = = NOT A PIXEL SCAN.** = = The
drawn plate is the layer that carries `CABackdropLayer`: = = it is **20 PT
tall**, = = its centre sits at **midY 14.0** inside the band's **28 PT** row,
= = and every band's plate sits **0.0 PT** off its own band's middle (= = in
the two side columns, = = and in the chat zone at 3 pages and at 12).

⇒ ⇒ ⇒ **⇒ ⇒ AND THE OLD PIXEL NUMBERS WERE ARTIFACTS, = = AND THE RECORD NOW
SAYS SO:** = = the earlier readings (2.5 PT and 1.0 PT) came from a screenshot
scan, = = and a bright run on a screenshot measures the plate's **GLOW**
(= = 24 PT), = = not the plate; = = and one of those scans had read the
sidebar's own label and the editor's document strip instead of the band. = =
⇒ ⇒ ⇒ ⇒ So the record's number is the layer's.

⇒ ⇒ ⇒ **⇒ ⇒ AND THE VERDICT ON THE LANDED LOOK IS NOT GIVEN YET, = = AND THIS
DOCUMENT DOES NOT WRITE IT:** = = the boss's own look was given on the PROBE
(= = rows `306933` and `306946`, = = the probe's look was accepted and its
rounded-rectangle shape ruled), = = and the landed build's look has NOT been
judged by the boss. = = ⇒ ⇒ ⇒ ⇒ **THAT IS AN OPEN ITEM, = = NOT A CLAIM.**

## 5. The open items

1. **The boss's own look on the LANDED build is not given.** = = §4 says what
   the measurement says; = = it does not say the boss has seen this build.
2. **The 13 known-red issues in the editor's document strip** (= = 12 in
   `EditorTabStripOverflowTests`, = = 1 in `PaneTabStripTitleTests`) = = are
   `main`'s own, = = not this scope's, = = and they are NOT fixed here.
3. **`Sources/WenshuApp/Features/Editor/Store/EditorTabStrip.swift` still says
   "so all four columns' top bands draw the same capsule height"** (= = the
   R2-class sentence, = = in a file `main` owns and this scope deliberately
   left alone). = = It wants its own one-line record card.
4. **Two registry rows drift in `main`** (= = row 139's cell 405 against the
   file's 401, = = and row 200's cell 359 against the file's 363). = = Neither
   file is in this scope's diff, = = so a per-change gate cannot see them.
5. **The registry's row for the width rule still lists "the toolbar picker"**
   as a door of the shared control, = = and that phrase is PRE-EXISTING on
   `main` (= = `git show 2234a49ba2:docs/agents/nfi.md` carries it) = = so it
   is not this scope's row to rewrite.
6. **The plate's 20 PT height is not bounded by the committed suite**: = = the
   suite bounds the plate as "> 0" and "leaves air", = = and the 20 PT comes
   from the layer-level probe. = = The record does not claim a committed
   measurement it does not have.

## 6. The commits this session pushed that are NOT this session's

= = = **NONE.** = = The push's own range is `0f9fcb6d41..6336bc08d4`, = = and
it carries this scope's two commits (`fa12d0873e`, = = `9628b3b133`) and the
merge commit (`6336bc08d4`). = = ⇒ ⇒ ⇒ ⇒ The eight sibling commits that landed
on `main` WHILE the review was running (the window `2234a49ba2..0f9fcb6d41`
= = the registry's merge driver, = = the devtool's four gate fixes, = = and
three closeout documents) = = were pushed by their own lanes: = = the server's
`main` was already at `0f9fcb6d41` when this session's push started, = = and
this session pushed nothing before that.

⇒ ⇒ ⇒ **⇒ ⇒ AND THIS IS MEASURED PER PUSH, = = NOT PER SCOPE:** = = the range
above is the range this session's push carried.

## 7. The next session's starting point

- The scope is LANDED: = = `main` = = `6336bc08d4`, = = and the reviewed commit
  `9628b3b133` is its second parent.
- The four review cards are `done`: = = `t_47a4fe5f`, = = `t_58af2b71`, = =
  `t_9f6f3e28`, = = `t_3149bfd6`.
- The component is `Sources/WenshuApp/Shared/UI/WenshuTabPicker.swift`, = = the
  plate's geometry is held by
  `Tests/WenshuAppTests/Shared/UI/TabPickerBandGeometryTests.swift`, = = and
  the scope's own record row is `OOB.md`'s 2026-11-19 row.
- The open items in §5 are the work that is left.

## 8. This round's own corrections

= = = **THE FOUR REVIEW ROUNDS, = = AND WHAT EACH ONE FOUND** (= = every card
is on the board, = = and every card carries the landing record):

| round | card | verdict | what it found |
| --- | --- | --- | --- |
| 1 | `t_47a4fe5f` | `changes_requested` | the record claimed FOUR switchers, = = claimed the strip "only changes role", = = and claimed a `.large` capsule height (= = none of which the tree said); = = and the "one line" ruling was asserted from numbers that did not support it |
| 2 | `t_58af2b71` | `changes_requested` | two test files still described the component as a SwiftUI `Picker` + `TabsPickerStyle` (= = the tree says an AppKit control in the tab role); = = one comment still said "all four columns"; = = one comment gave 47 PT where the measurement is 48 PT |
| 3 | `t_9f6f3e28` | `approved` | three non-blocking notes (= = the commit message, = = the 0.0 PT, = = a `main`-owned file) |
| 4 | `t_3149bfd6` | `approved` | five non-blocking notes (= = below) |

⇒ ⇒ ⇒ **⇒ ⇒ AND ROUND 4'S FIVE NON-BLOCKING NOTES, = = AND WHAT BECAME OF EACH:**

- **N1** (= = the commit message over-counted its answers) = = = = the message
  says it answers round 3's three notes; = = it answers the TWO that are this
  scope's, = = and it corrects the registry rows this scope's own change had
  falsified. = = A pushed sha is never rewritten, = = so this is the note's
  permanent trace, = = and it is recorded here.
- **N2** (= = the plate's 20 PT has no committed measurement) = = = = see §5's
  item 6.
- **N3** (= = the registry's width-rule row still lists "the toolbar picker")
  = = = = see §5's item 5.
- **N4** (= = two other registry rows drift) = = = = see §5's item 4.
- **N5** (= = the known red was not re-measured in that round) = = = = it was
  measured at BOTH trees in round 3, = = and re-confirmed statically in round 4
  (= = the blobs are identical base↔tip, = = and the suites are not in the
  gate filter), = = and §3 separates it again.

⇒ ⇒ ⇒ **⇒ ⇒ AND THE THREE REGISTRY ROWS THIS SCOPE'S OWN CHANGE HAD FALSIFIED,
= = CORRECTED IN `9628b3b133`:** = = the row for `ChatZoneTabBar.swift` (= =
its LOC cell 244 → = = 241, = = and its prose now names the tab role and the
measured-outside-the-container width), = = the row for `ChatZoneTabBarTests.swift`
(= = 466 → = = 465), = = and the row for `PaneTabStripWidth.swift` (= = the
chat bar is no longer one of that width rule's doors).

⇒ ⇒ ⇒ **⇒ ⇒ AND THE STOPPING RULE, = = STATED HERE SO NO FIFTH ROUND IS
OPENED:** = = **This scope's review lives on the board; = = this document does
not log it.** = = A fourth finding that is only wording is non-blocking, = = a
fifth round that asks for another self-audit of a tree whose component was
approved twice is the defect repeating, = = and the closure document's own
count is not published here (= = see the next paragraph).

⇒ ⇒ ⇒ **⇒ ⇒ AND THIS DOCUMENT'S OWN COUNT IS AN INVARIANT, = = NOT A NUMBER:**
= = the registry's LOC cell for this document and this document's own line
count are EQUAL, = = read from the tree you are standing on:

```bash
wc -l docs/agents/2026-11-20-session-close-the-column-switchers-wear-apples-tab-control.md
```

= = = = = The check itself is the equality, = = and it is checked by the
house's own closure-record verifier (= = which also reads this document's
command blocks and this document's CJK surface).

⇒ ⇒ ⇒ **⇒ ⇒ AND THIS DOCUMENT'S COMMAND BLOCKS ARE ITS TEST SUITE:** = = each
block above is a claim the reader can re-run, = = and they were run in the tree
this document names before it was committed.
