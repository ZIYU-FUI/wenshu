# The chat zone's session bar fills its column, = and follows the tree

Date: 2026-11-12. Branch: `wt/chatbar-fullwidth` @ `18ac06e8d4`
(= one commit on top of `main` @ `521fadca71`).

Scope: two requirements the boss named together, = with one screenshot:

> 目录树新建书籍，编辑器的 teb 栏没有同步新建会话。编辑器的 teb 栏，自动拉宽至编辑器全宽。

(= "A book the writer creates in the directory tree does not get a
conversation in the editor's tab bar. The editor's tab bar widens itself
to the editor's full width.")

The chat zone's top bar (= the session tab bar) lists the conversations
the writer can switch to: = the repository conversation, = one per
ordinary book, = and the reference-library conversation.

## 0. THE TWO REQUIREMENTS, = AND WHERE EACH ONE ALREADY STOOD

| # | Requirement | State when the scope opened | Where the work went |
| --- | --- | --- | --- |
| 1 | a book the writer creates in the directory tree gets a page in the bar | **already fixed on `main`** (= `72c3f5eb3d`, = an ancestor of `main`'s tip, = committed 2026-11-12 03:00:39) | the proof (= §2), = not the source |
| 2 | the bar widens to the editor's full width | **not implemented** (= the bar passed `fixedSegmentWidth: 0`, = so the control took its own fitting width) | the source (= §3) |

**⇒ THE SCOPE'S REAL WORK IS REQUIREMENT 2, = AND REQUIREMENT 1'S PROOF.**
The two are one ticket because they are one bar, = and because the bar's
page list (= requirement 1) and the bar's width (= requirement 2) are
read off the SAME control.

## 1. REQUIREMENT 1'S ROOT CAUSE (= the build, = not the source)

The screenshot's app instance was launched at **2026-11-11 20:53**, = and
the fix landed at **2026-11-12 03:00:39**. = ⇒ The screenshot was of a
binary that predates the fix.

The two shapes of `createBook`, = read from the tree itself:

| Commit | `createBook` writes the shared list? |
| --- | --- |
| `8840d384f42b` (= 2026-11-11 20:27:11) | **no** (= `SidebarServiceMutation.swift` carries no `sidebarRecordBook` call) |
| `970c631adbd8` (= 2026-11-11 21:20:50) | yes (= and this sha is **not** an ancestor of `main`) |
| `72c3f5eb3d` (= 2026-11-12 03:00:39) | yes (= and this sha **is** an ancestor of `main`) |
| `main` @ `521fadca71` | yes |

The shape that produces the screenshot's symptom (= the book reaches the
DISK, = so the tree shows it, = and not the shared list, = so the bar
shows no page) is `8840d384f42b`.

**⇒ AND THE CHAIN IS ONE INSTANCE, = NOT TWO.** The sidebar and the chat
zone read the SAME `BookStore`: = `LibraryRootView` creates it and
injects it into the environment, = `AppleSidebarView` reads it back from
the environment, = and `EditorChatSplitHost` carries the same instance
across the AppKit boundary into the editor column's chat zone
(`EditorChatEnvironment.bookStore`). = ⇒ A book the writer creates
reaches the bar because there is only ONE book list.

**⇒ AND THE MUTATION NOTIFICATION IS NOT THE GAP.** The shared list is
mutated in place (`books.append` + `books.sort`), = and a probe on the
app's own `@Observable` store measured all three mutations as notifying
(`append` = true, = `sort` = true, = subscript = true).

## 2. REQUIREMENT 1'S PROOF (= the production door, = and the real app)

**⇒ THE TEST DRIVES THE USER'S OWN DOOR.** `ChatZoneTabBarTests`
creates a book through `SidebarService.createBook` (= the one the tree's
"new book here" menu opens), = then hosts the REAL bar in a real
`NSHostingView` and reads the `NSSegmentedControl` the bar draws. = ⇒
The assertion is on the DRAWN labels (= `["Wenshu", "My Novel",
"Reference Library"]`), = not on a page list.

**⇒ AND IT IS RED AGAINST THE BROKEN SHAPE.** With
`bookStore?.sidebarRecordBook(book)` removed from `createBook` (= the
`8840d384f42b` shape), = the test fails (= and `SidebarBookListSyncTests`
fails with it).

**⇒ AND THE REAL APP SHOWS IT.** Both builds were launched against the
same throwaway library (= six books on disk, = a seeded shelf, = the
bookmark in a throwaway bundle id's own preferences domain, = so the
user's own library and preferences were never read or written). = The
**base** build (= `main` @ `521fadca71`, = which carries the fix) paints
the books as bar pages, = which is the runtime proof that requirement 1
holds on `main` today.

## 3. REQUIREMENT 2 (= the width rule, = and its one owner)

The bar passed `fixedSegmentWidth: 0` to the house's
`LabelSegmentedControl`, = so the control took its own fitting width and
the bar hugged the left edge of the column. = The editor's OWN document
strip (= the row above it in the same column) already divides the column
it was given.

**⇒ THE RULE NOW HAS ONE OWNER.** The two strips ask one question of one
control (= what width does a segment take when the strip fills the
column it was given?), = so the answer lives in
`Shared/UI/PaneTabStripWidth` and both call it. = A rule that lives in
each door separately is a rule that drifts.

**⇒ AND THE FLOOR IS MEASURED, NOT GUESSED.** MEASURED on the app's own
control (= a real `NSSegmentedControl` at the `.large` control size, = in
a real offscreen window): = a four-character Chinese title claims
**50 PT** of ink and **80 PT** of the control's fitting width, = and a
six-character title claims **75.5 PT** of ink. = ⇒ 88 PT keeps a
four-character name whole. = The floor is unchanged from the number the
editor's strip already used (= the sibling's own value is now a forwarder
to the shared owner).

**⇒ AND THE MEASURED BEFORE / AFTER, ON THE REAL APP.** Two builds, = the
same library, = the same window size, = the bar's own painted pixels
measured against the column's own edges:

| Build | the bar's extent | the bar's share of the column | the gap to the right |
| --- | --- | --- | --- |
| base (`521fadca71`) | x = 1081 .. 1721 (640 px) | **54.3%** | **538 px** |
| tip (`18ac06e8d4`) | x = 1081 .. 2259 (1178 px) | **100.0%** | **0 px** |

(= the editor column measures x = 1081 .. 2259 = 1178 px in both
captures, = so the two numbers are the same window, = the same column, =
and the same measurement.)

## 4. THE TESTS (= and that they are not vacuous)

`Tests/WenshuAppTests/Chat/View/ChatZoneTabBarTests.swift` (= 339 lines)
hosts the REAL bar in a REAL `NSHostingView` at a REAL column width and
walks the AppKit view tree to the `NSSegmentedControl`. = A property
assertion could not prove either claim (= the defect was a rendering
behaviour, = and a control that holds the right labels can still paint
them at the wrong width).

| Test | What it holds |
| --- | --- |
| the bar's pages divide the column it is given | at 600 PT with three pages the control claims 600 PT and each segment takes 200 PT |
| a narrow column still shows a page name | at 200 PT each segment still takes at least 88 PT |
| more pages than the column holds scroll | twelve pages in a 300 PT column sit in a clipping container whose content is wider than the column, = and every segment keeps the 88 PT floor |
| the bar's segment widths follow the column | at 300, = 600 and = 900 PT the bar's claim tracks the column |
| a book the user creates in the tree shows up in the bar | the production door adds a page the bar's own control draws |

**⇒ AND THE MUTATION CHECK.** The suite is RED against both broken
shapes:

| Mutation | Result |
| --- | --- |
| `PaneTabStripWidth.segmentWidth` returns 0 (= the bar stops dividing its column) | the suite fails (= 11 issues, = every width claim) |
| `createBook` stops writing the shared list (= the `8840d384f42b` shape) | "A book the user creates in the tree shows up in the bar" fails, = and `SidebarBookListSyncTests` fails with it |

## 5. THE GATES, = AND WHAT EACH ONE SAID

| Gate | Result |
| --- | --- |
| `swift build --target WenshuApp` | exit 0 (= "Build complete!") |
| `swift test --filter "ChatZoneTabBarTests"` | 5 tests in 1 suite passed |
| `swift test --filter "ChatZoneTabBarTests\|SidebarBookListSyncTests"` | 10 tests in 2 suites passed |
| `swift test --filter "LabelSegmentedControlShapeTests\|LabelSegmentedControlSelectionTests\|EditorTabStripOverflowTests\|SectionTitleBaselineTests"` | 20 tests in 4 suites passed (= the shared control's shape, = its selection semantics, = the sibling strip's overflow geometry and = the column-top baseline) |
| the same four, = plus `ChatScopeTests` and `SidebarBookListSyncTests` | 42 tests in 6 suites passed (= and the scope model's page list and = the tree door's shared-list write) |
| the 23 design-sweep suites | 86 tests in 23 suites passed |
| `verify-dead.py` | DEAD stays 0 (= 3 files ALIVE) |
| `design-sweep.sh` | "design sweep clean" (= the four changed Swift files) |
| `ci_change_gate.py --check formatting` | "the change adds no unformatted line" (= 11 unformatted lines in the NEW test file were the first reading, = and the repository's own `swiftformat` fixed them) |
| `ci_change_gate.py --check pollution` | "the change adds no forbidden vocabulary" |
| `nfi-loc-check.py --base main` | every added row carries its own count (= 37 and 341) |
| `ticket_tier.py --body` | T3, = kind review, = the title carries the tier |

**⇒ THE BASELINE IS RED, = AND THE FAILURE SET MOVES BETWEEN RUNS.** Five
complete whole-suite runs (= three on the base, = two on the tip, = each
carrying its own main summary line) share **seven** failing sites (= four
`FileToolsTests` path-permission cases, = `AsyncDelegationRegistryTests`,
= `ChatViewHistoryShortcutTests` and = `EditorTabTitleTests`), = and every
run adds one or two more.

**⇒ AND EVERY EXTRA IS A WALL-CLOCK ASSERTION, = AND EACH ONE ALSO APPEARS
ON THE OTHER TREE:**

| Run | the extras beyond the seven |
| --- | --- |
| base, run 1 | `EditorPersistenceTests.swift:253:9`, = `WenshuReplicatedKanbanEndToEndTests.swift:460:9` |
| base, run 2 | `EditorPersistenceTests.swift:253:9` |
| base, run 3 (= solo) | `HermesTodoStoreConcurrencyTests.swift:268:9`, = `StreamBufferChainTests.swift:199:9` |
| tip, run 1 | `EditorPersistenceTests.swift:253:9`, = `HermesTodoStoreConcurrencyTests.swift:268:9` |
| tip, run 2 (= solo) | `EditorPersistenceTests.swift:253:9`, = `EditorPersistenceTests.swift:259:9` |

**⇒ SO A ONE-PAIR VERDICT IS A COIN FLIP, = AND `swift_test_compare.py`'s
OWN VERDICT CHANGES WITH THE PAIR.** The tool names
`HermesTodoStoreConcurrencyTests.swift:268:9` as tip-only on one pair, = and
the BASE tree's third run (= the same tree, = the same command, = the same
machine) produced that exact failure. = ⇒ The claim that survives is not
"the tool says no new failure" but the pooled one: = **the seven are
identical across all five runs, = and every extra is a timing assertion
that also fails on the other tree.**

**⇒ AND THE EXTRAS PASS IN ISOLATION ON BOTH TREES:**
`swift test --filter "HermesTodoStoreConcurrencyTests"` = 5 tests in 1
suite passed on the tip and on the base; = `swift test --filter
"WenshuReplicatedKanbanEndToEndTests"` = 10 tests in 1 suite passed on the
base. = ⇒ The tip's change (= a view's width, = a width helper, = a test
file) = is in none of those code paths.

## 6. THE OPEN ITEMS, = AND WHO OWNS THEM

| Item | Owner |
| --- | --- |
| the boss's own look on the running build (= rule 7.7) | the boss (= the build is `18ac06e8d4`, = and the screen capture in §3 is the same build; = the amended sha `bc3251fce` differs from it by the test file's formatting alone) |
| the tree-door click path itself (= right-click the shelf row → "new book here" → the sheet) was not driven by the GUI | this scope's proof is the production door (= §2) = plus the app-level capture; = the GUI click was left alone because the CUA input needed the operator's approval and it did not arrive |
| the tree's RED baseline (= seven failing sites on every run) | the tree's baseline (= not this scope's) |
| the load-sensitive extras (= a 5-second budget, = a 3-second auto-save wait) = which move between runs on BOTH trees | the tree's baseline (= not this scope's) |

## 7. THE LESSONS, = AND WHERE EACH ONE NOW LIVES

1. **A screenshot's symptom can be a stale build.** The bar's missing
   page was the pre-fix binary, = and the source had been fixed six hours
   before the screenshot. = ⇒ Read the RUNNING instance's start time
   against the fix's commit time before believing a defect is in the
   source. = ⇒ The lesson lives in this closeout and in the card body
   (= the reviewer reads the same two shas).
2. **A seed that does not decode is not a seed.** The first library the
   proof built wrote `createdAt` as an ISO-8601 string, = and `Book`'s
   `Codable` reads `deferredToDate` (= a number), = so every book was
   skipped in silence and the bar showed no pages at all. = ⇒ A proof
   fixture that produces an EMPTY result is a broken fixture, = not a
   broken app; = check the fixture's own decoder before blaming the app.
3. **A geometry claim is measured in pixels, = and the two builds are
   measured the same way.** The before / after numbers in §3 come from
   one script over two captures of the same window, = so the comparison
   is the claim and not an impression.
4. **A TRUNCATED LOG MAKES A COMPARISON TOOL PROVE NOTHING, = AND NOTHING
   SAYS THE LOG IS TRUNCATED.** The first whole-suite run's log held 138
   suites that started and never finished, = and no main summary line, = so
   `swift_test_compare.py` compared a complete base against a partial tip
   and reported "NO new failure" (= the tip's missing results are not
   failures). = ⇒ **⇒ SO A LOG IS COMPLETE ONLY IF IT CARRIES ITS MAIN
   SUMMARY LINE** (= "Test run with N tests in M suites failed after …"),
   = and a comparison reads that line before it reads the verdict. = The
   reviewer caught this one (= it named the defect F1, = non-blocking, = the
   claim true and the proof invalid).
5. **⇒ ⇒ ⇒ AND A RED BASELINE'S FAILURE SET IS NOT REPRODUCIBLE, = SO
   "NO NEW FAILURE" IS NOT A CLAIM A SINGLE PAIR OF LOGS CAN CARRY.** Five
   complete runs (= three base, = two tip) share seven failures and float
   one or two more, = and the tool's own verdict changes with the pair
   (= it named a tip-only failure that the base's next run produced). = ⇒
   The claim that survives is the POOLED one (= §5), = and the extras are
   proven unrelated by running them in isolation on BOTH trees.
6. **⇒ ⇒ ⇒ AND A NEW FILE IS CHARGED EVERY LINE BY THE FORMATTING GATE, =
   = SO THE FORMATTER RUNS BEFORE THE COMMIT, = NOT AFTER THE REVIEW.**
   The new test file carried 11 unformatted lines, = and the first reading
   of the gate charged all of them (= a new file is an added file), = so
   the commit was amended (= the production sources byte-identical, = the
   test file's formatting and = the registry's own count) and re-reviewed.
   ⇒ **⇒ AND AN AMEND CHANGES THE CHANGE IDENTITY, = = SO IT COSTS A NEW
   VERDICT** (= the gate matches the CHANGE, = not the commit id), = even
   when the delta is formatting alone.
