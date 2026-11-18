# Session closeout: the inspector's card pages, the materials column's one list, and the .md trailing-newline gate

= = = Date: 2026-11-18 (= = the session that began 2026-11-17 20:06).
= = = The scope's base: `41b82a8fa` (= = the App Store editorial-card scope's landing).
= = = The reader gets the tip with `git rev-parse main` and
`git ls-remote <remote> main`; this record states ANCESTRY (= = every commit
below is an ancestor of `main` on BOTH remotes, checked after reading each
remote back), because a tip stops being true while this document is written.

## WHAT THE SESSION CLOSED

The boss's request (2026-11-18): = = "merge what is already done and already
reviewed". = = Three scopes were done and reviewed but had no closure record
of their own; this document is that record.

| # | The requirement | Its carrier | The verdict that cleared it |
| --- | --- | --- | --- |
| 1 | The trailing inspector column's three card pages must cost only what is on screen | `9776b4dc7` (+ `10b8706d6`) | card `t_084d80bc` = = approved (round 3; round 1 = = card `t_0273877a`) |
| 2 | The materials column's whole-library scope must show ONE list (= the library's own documents, = = then book 1, = = then book 2) and walk the library once | `9225b9941` (+ `b53dfcdbb`, `757cc688b`) | card `t_8f99ae51` = = approved (round 2; round 1 = = card `t_46dbb52f`) |
| 3 | (= = THE ENGINEERING DEPTH AROUND (1) AND (2)) A change must not drop a changed `.md`'s trailing newline, because the house's own merge driver compares that byte | `bae8d6b8c` (+ `e83df48e6`, `e8c2d393e`) | card `t_149b9753` = = approved (round 3; rounds 1 and 2 = = cards `t_1d32a427`, `t_fe5d2130`) |

= = = The requirement's direct functional scope is (1) and (2). = = (3) is the
depth around them: = = it exists because (1) and (2) had to add rows to the
registry, = = and the registry is the one file the house's key-level merge
driver compares byte for byte. = = ⇒ (1) and (2) closed at 100 percent, = =
and (3) is the engineering depth that made them landable at all.

## (1) THE INSPECTOR'S CARD PAGES = = THEIR BODY PASSES PAY ONLY FOR WHAT IS ON SCREEN

**The symptom.** = = The trailing column's three card pages paid their whole
list's cost on every body pass, = = and the board paid it again for every
task's body. = = On the user's own library (563 tasks, 511 of them carrying
a body), = = one body pass built 563 card bodies and parsed 511 markdown
bodies; = = the status page rebuilt all eight of its cards once a second.

**The root cause.** = = Three shapes, each paid on every pass: = = the
status page wrapped its whole scroll content in a 1 Hz `TimelineView` and
handed every card the current date (= = every card rebuilt once a second,
including the cards that show no time at all); = = the todo page drew its
cards in an eager `VStack` (= = one body pass built every card in the
plan); = = the board drew its card column in an eager `VStack` and each card
parsed its task's markdown inside its body (= = 511 parses per pass).

**The fix.** = = The clock moved into the elapsed label (= = only the one
card that shows a running time ticks, = = and the house's elapsed format is
unchanged); = = the todo page's cards sit in a `LazyVStack`; = = the board's
card column sits in a `LazyVStack`, = = the cards are bucketed by status at
the load, = = and a task's body is parsed once there (= = the rendered text
is the same parser's output, = = so it is unchanged).

**The measured before/after** (= = the probe `inspector_card_load_cost`,
= = whose eight production fragments it reproduces are checked against the
live source before it reports a number; = = the record is in
`Tools/wenshu-devtool/probe-index.md`):

```
[A] the board's markdown parse
    parses per body pass: BEFORE 511 (= one per card) | AFTER 0 (= parsed at the load)
    the corpus parsed once (= the load's one-shot cost)  min 2601.459 us | median 2681.500 us | p95 2973.708 us
[B] the card bodies built per body pass
    BEFORE: eager card column            563
    AFTER:  lazy card column             21
[C] the status page's card rebuilds over ten clock ticks
    BEFORE: the page-level 1 Hz clock    80
    AFTER:  the clock on the elapsed label alone   0
```

= = = The counts are the shape's own numbers, = = not a timing: = = 563 is
every card on the user's board, = = 21 is what a 320x600 column builds on
screen, = = and 80 is the eight cards on the status page rebuilt once a
second (= = 8 x 10 ticks).

**The second commit.** = = `10b8706d6` = = "the two registries keep their
trailing newline". = = The scope's registry rows had dropped that byte, = =
and (3) below exists because of it.

## (2) THE MATERIALS COLUMN = = ONE LIST, = = AND THE LIBRARY IS WALKED ONCE

**The symptom.** = = The boss's rule (2026-11-17): = = the materials
column's whole-library scope shows its documents in ONE list (= = the
the library's own documents first, = = then book 1, = = then book 2), = = not
as two stacked grids (= = the "upper-and-lower" arrangement). = = And that scope paid its
whole-library walk on every body pass: = = SwiftUI re-evaluates a view's
body on every observation tick, = = the old shape walked the whole library
TWICE per pass (= = the grid walked it, = = and the chrome's card count
walked it again), = = and each walk read every `.md`'s FULL body.

**The root cause.** = = The list was drawn from the view's body (= = so it
was rebuilt per pass), = = the chrome's count walked the library a second
time, = = and the shelf roots were looked up for every book.

**The fix.** = = One `LazyVGrid` in one `ScrollView` (= = the ONE list);
= = the list is walked ONCE per library change (= = not once per body pass)
and ONCE for the whole library; = = each `.md` is read at its HEAD (= = 8
KB, = = not its whole body, = = the title, the chip tag and the summary all
live there, = = and the body is read when the document is OPENED); = = the
chrome's card count reads the SAME list the grid draws; = = the scope shows a
progress indicator while the list loads (= = not the empty state).

**The one interpretive call.** = = The requirement names both the order and
the sort, = = and a global pinyin sort would break the order. = = ⇒ The sort
applies WITHIN each group, = = and the groups keep the requirement's order.

**The measured before/after** (= = the probe `card_surfaces_load_cost`, = =
whose production fragments are checked against the live source before it
reports a number; = = the record is in `Tools/wenshu-devtool/probe-index.md`):

```
A1 full-body walk (= the OLD door)         min 434.9 us | median 479.1 us | p95 537.2 us
A2 card-head-only walk (= the NEW door)    min 228.8 us | median 248.0 us | p95 259.5 us
A walks per body pass: BEFORE = 2 (= the grid walked the library AND the chrome count walked it again)
A walks per body pass: AFTER  = 0 (= the list is walked once per library change, = = and the chrome count reads it)
A bytes read per walk: BEFORE = 61927 (= every .md's FULL body) | AFTER = 61927 (= each .md's HEAD)
C cards a plain VStack builds per body pass = 560 | a LazyVStack = ~15 (= the visible window)
D markdown parses per body pass = 497 (= inside the card body) | AFTER = 0 (= parsed at the load, = = by (1))
```

= = = ON THIS LIBRARY the head read reads the same bytes (= = the `.md`
files are smaller than the 8 KB head), = = so the saving is NOT bytes: = =
it is the two whole-library walks per body pass that are gone.

**The two fixes the review forced.** = = `b53dfcdbb`: = = the head read
kept a partial CJK character (= = an 8 KB cut inside a multi-byte
character threw the character away, = = and the card's title and summary
were then wrong); = = the head is now trimmed at a character boundary and
the head holds a complete H1 and at least 200 characters of body, = = or the
whole file is read. = = `757cc688b`: = = the editor's save announces the
library change when it lands INSIDE the library (= = so the material zone's
ONE list refreshes and an edited chapter's card shows its new summary), = =
and announces nothing for a write OUTSIDE every library root.

## (3) THE .MD TRAILING-NEWLINE GATE (= = THE DEPTH AROUND (1) AND (2))

**The symptom.** = = Nothing in the tree checked a Markdown file's last
byte, = = and that byte is the one the house's key-level merge driver
compares. = = `Scripts/merge-nfi-registry.py`'s `split_rows()` puts
everything after the last table row into a TAIL, = = and `text.split("\n")`
leaves a final empty string on a newline-terminated file and not on a file
without one. = = ⇒ The tail differs, = = and the driver reports
`conflicted keys: <the file's tail>` against the next card that appends a
row.

**The root cause, measured.** = = A scope that dropped the byte from both
registries cost a review round to find; = = and the house's own merge-tree
gate measured a CONFLICT against a `main` carrying one concurrent sibling
card's registry row (= = while the identical tree with the newline restored
merges CLEAN through the SAME gate). = = ⇒ The fix was two bytes, = = and it
cost a review round.

**The fix.** = = A third check on the repository's own change gate,
`--check markdown-newline`: = = it compares the file's blob at the
MERGE-BASE with its blob at HEAD (= = from the git OBJECT), = = it resolves
a RENAME's source before calling a path new, = = and it reports only what
THIS change did. = = `.github/workflows/ci.yml` runs it next to the
pollution gate (= = a check the CI never runs is not a gate).

**The three rounds the review forced, = = each one a real defect.**

1. = = Round 1's gate was a STATE check (= = "does the file on disk end
   with a newline?"), = = and it false-reds on the tree's own history: = =
   over main's last 300 COMMITS it reds 13, = = 11 of them false. = = ⇒ The
   check became a DELTA (= = 2 reds over that window, = = both genuine).
2. = = Round 2's suite could not fail: = = its drift fixture ADDED the
   trailing newline, = = so the state rule and the delta rule agreed on it
   (= = the case never reached the property its own name claims). = = ⇒ The
   fixture keeps the drift, = = and the suite now FAILS against round 1's
   gate (= = 17/19, = = exit 1).
3. = = Round 2's rule false-reds a RENAME of a byte-less `.md` (= = the
   merge-base blob is absent for a renamed path, = = so the rule concluded
   "the file is NEW"). = = ⇒ The path's RENAME SOURCE is resolved first and
   compared against the source's merge-base blob. = = Measured over main's
   last 1430 `.md`-touching commits: = = 578 reds without the rename
   handling, = = 560 with it = = ⇒ the fix removes exactly 18 (= = the 18
   renamed byte-less `.md` files across 3 commits).

**The calibration, with its window named** (= = the review's note: = = the
window is part of the number).

```
A. main's last 300 COMMITS:            DELTA REDs 2 (= cc69371c3, 9776b4dc7 = = both genuine) | STATE REDs 13 (= 11 false)
B. main's last 300 .md-TOUCHING COMMITS: DELTA REDs 3 (= all three genuine)                      | STATE REDs 20 (= 17 false)
```

## THE TESTS, EACH NUMBER WITH ITS OWNER

| The gate | The command | The count | The card that holds it |
| --- | --- | --- | --- |
| The materials column's ONE list | `swift test --filter LibraryDocumentListTests` | 8 tests in 1 suite | `t_8f99ae51` (round 2) |
| The editor's save announces the library change | `swift test --filter EditorPersistenceAnnouncementTests` | 2 tests in 1 suite | `t_8f99ae51` (round 2) |
| The trailing-newline gate | `python3 Tools/wenshu-devtool/tests/test_ci_change_gate.py` | 19/19 cases | `t_149b9753` (round 3) |
| The whole tree | `swift test` | 494 XCTest tests (= = 1 skipped, = = 0 failures) + 359 swift-testing tests in 58 suites (= = 6 failed) | the merged tree (= = the failure analysis below) |

= = = The first two suites' counts are the counts those suites own; = = the
filter names the population the number was drawn from, = = because a filter
that selects nothing reports "0 failures" and exits 0 (= = the vacuous
green).

## §7 = = THE GATES ON THE MERGED TREE (= = on `main`, = = not on the branch that was measured before the merge)

```
7.1  swift build                                    Build complete! (2.26 s)
7.2  swift test                                     the XCTest half: 494 tests, 1 skipped, 0 failures (= = the skip carries its reason); = = the swift-testing half: 151 tests in 34 suites + 208 tests in 24 suites, = = 6 failed. = = ⇒ THE EXIT CODE WAS 0, = = so see the failures section below
7.3  the design sweep, on the session's changed view files   clean (= = 1 hit, = = a FALSE POSITIVE, = = see the open items)
7.5  the CJK comment audit                          the session's commits add CJK only in the product's own Chinese terms (the library's and the app's own names) and in the test fixtures' Chinese content (= = the measured subject); = = the tree already carries 43441 CJK comment lines, = = so this is the house's practice, = = not a new class of defect
7.6  verify-dead.py                                 ALIVE 130 | PARTIAL 4 | DEAD 0 (= = the session's base carries the SAME 4, = = so the session added none)
7.7  the boss's look                                IN PERSON, = = on the build named below
7.8  commit hygiene                                 one ticket per commit, = = conventional prefixes, = = English subjects and bodies that say WHY
7.9  the verdict field                              all three cards carry review_outcome=approved in the run's metadata
7.10 the named narrow gate                          each card's body names its own filtered suite
```

= = = The change gate's own three checks on the merged tree:
`formatting` = = green (= = 0 changed Swift files), = = `pollution` = =
green, = = `markdown-newline` = = green (= = 0 changed `.md` files). = = The
registry's own gates: = = `nfi-loc-check` = = "every rewritten file's row
carries its own count (12 row(s) checked)", = = `nfi-split` = = 0.

## THE FAILURES AT THE MERGED TIP, AND WHAT THEY ARE NOT

= = The merged tree's full run reports **six** failed swift-testing tests
(= = and the run's EXIT CODE IS 0, = = because the XCTest half's exit code
does not carry the swift-testing half's verdict). = = ⇒ ⇒ ⇒ So the exit
code is not the verdict here, = = and the failures were measured against
the tree BEFORE this session's work (= = the session's base, = = `41b82a8fa`,
= = in its own detached worktree) ✓:

| the failure | at the base | at the tip | what this session's diff does |
| --- | --- | --- | --- |
| `ChatViewHistoryShortcutTests.swift:35` (= = the log block carries `totalTokens`) | FAIL | FAIL | the chat's history path is NOT touched by the diff |
| `EditorTabTitleTests.swift:60` (= = the tab's title) | FAIL | FAIL | `EditorTab` is NOT touched by the diff |
| `AsyncDelegationRegistryTests.swift:104` (= = the @-mention registered) | FAIL | FAIL | the delegation path is NOT touched by the diff |
| `EditorPersistenceTests.swift:253` (= = the 3-second auto-save) | pass | FAIL | the diff's only change to `EditorPersistence` is the announcement, = = and `announceLibraryChange` returns on a `nil` bookStore (= = the test passes `bookStore: nil`), = = so the path the test exercises is not changed; = = the test's own comment documents it as failing when the main actor's queue is long |
| `LongRunningGoalButtonTests.swift:98` | pass | FAIL | the goal button's path is NOT touched by the diff |
| `HermesTodoStoreConcurrencyTests.swift:268` (= = the call must finish in 5 s) | pass | FAIL | the todo store's path is NOT touched by the diff |

⇒ ⇒ ⇒ ⇒ ⇒ **⇒ THIS SESSION'S DIFF EXPLAINS NONE OF THE SIX.** = = Three
are identical at the base (= = pre-existing); = = the fourth is on the
editor's save path, = = where the session's only change returns early on a
nil library; = = and the last two are in the agent/chat area, = = which the
session's diff does not touch.

⇒ ⇒ ⇒ ⇒ ⇒ ⇒ AND THE BASE MEASUREMENT IS ITS OWN ROW, = = NOT A CLEAN
BILL: = = the base ran in ITS OWN worktree, = = and a worktree's path
changes the failure set (= = the house's own rule, = = `FileTools.pathDenied`
denies any path containing `/.hermes/`), = = so the base's run is not
path-identical to the tip's run in the shared checkout. = = ⇒ The
comparison above is therefore corroborated by the FILE evidence (= = the
diff touches none of the six suites' areas, = = except the editor's save,
= = where the change returns early) = = and not by the path alone.

⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ AND THE PRE-EXISTING SET HAS NO OWNER HERE: = = the three
failures that are identical at the base belong to no card of this session,
= = and the house's rule for a defect found while closing out is a ROW in
the report, = = not a new ticket.

## §7.7 = = THE BOSS'S OWN LOOK

- = = WHICH BUILD: = = `/Volumes/ANAN/Engineering/wenshu/build/Wenshu.app`,
= = rebuilt from the tree that carries `3e4c1da82` (= = the last commit that
touched `Sources/`), = = ad-hoc signed (= = `Identifier=com.wenshu.app`,
= = `Signature=adhoc`), = = launched with a PLAIN `open -g` (= = background,
= = no focus steal; = = never `open -n`, = = a second instance of the same
bundle id aborts both).
- = = THAT THE BUNDLE'S OWN BYTES CARRY THE CHANGE: = = `nm -a` on the
bundle's binary counts `LibraryDocumentList` 58 times (= = the one list the
scope added), = = with `WenshuApp` = = 123240 as the known-present control
(= = because a count of 0 and a tool that selects nothing look the same).
- = = THE BOSS'S VERDICT: = = **GIVEN** (= = 2026-11-18, = = in his own
words, = = rendered here in the doc's language): = = the code is right, = = and
the requirement is right.
- = = AND THE APP WAS LEFT RUNNING: = = **yes** (= = pid 71781, = = the AX
census reads one standard window at `(295,39)`, = = `1330x966`; = = no
crash report carries this binary's uuid = = `888492CC-D17B-3300-9F51-9598781D0D83`).
= = ⇒ AND IT WAS KILLED AFTERWARDS, = = NOT CRASHED: = = every tree's
executable is named `WenshuApp`, = = so a sibling session's loose-name
`pkill` reached it (= = the process vanished with NO crash report carrying
its uuid). = = ⇒ The durable fix is a unique executable name (= = the
isolated copy's `CFBundleExecutable`), = = and the command below brings the
build back.

= = = AND THE HONEST DETAIL ABOUT WHICH WINDOW THE VERDICT IS ABOUT: = = the
instance that was on screen when the boss first spoke was NOT this tree's
(= = a sibling session's instance, = = built from
`.worktrees/editor-status-band-material`, = = a 02:02 binary, = = 0
`LibraryDocumentList` symbols) = = so the boss's first remark (= = the
material zone's sections are still there) = = was about THAT build. = = ⇒ The bundle was rebuilt and relaunched
(= = pid 71781) and the verdict above is the boss's on the rebuilt bundle.

## THE COMMITS THIS SESSION WROTE, AND THE ONES IT DID NOT

The session's own (all ancestors of `main` on both remotes):
`9776b4dc7`, `cc69371c3`, `10b8706d6` (= = the inspector scope); = =
`9225b9941`, `82279609c`, `b53dfcdbb`, `aa732496a`, `757cc688b`,
`89b8f3f6f` (= = the materials scope); = = `bae8d6b8c`, `e83df48e6`,
`e8c2d393e` (= = the newline gate); = = `a83ca1b11`, `1d86bb915`,
`1aaec896c`, `e35dfedac`, `b1b6f4c25` (= = the App Store scope's closeout and
the selected-segment scope's closeout); = = `e2e7dafcc`, `e44e34efe`,
`6c499ab1d`, `fb8eeea67`, `321197105` (= = the selected-segment scope's
probe).

= = = On `main` inside the session's range, and NOT written by this session
(= = pushed as maintenance of the shared server state, = = not authorship):

- = = `73244ba4c` (= = "the tree opens the row a conversation names") = = a
sibling's sidebar scope (= = its card `t_c8abe108`), = = landed on `main`
while this session waited for the review lane.
- = = `8ea2727be` (= = "the zone opens on the conversation the restored
selection names") = = a prior session's chat fix, = = and the BASE the
selected-segment scope's branch was cut from.
- = = `7b8003625` (= = "the trace names the requirements and the landing") = =
a prior session's record, = = committed before this session began.

= = = The commit AUTHORS on those commits are the shared checkout's
configured identity, = = not the owner: = = the ownership above comes from
the wave and from the cards that name each sha.

## THE OPEN ITEMS LEFT BEHIND (= = each one names its owner; = = none of them is a blocker on (1), (2) or (3))

1. = = The tree's 28 pre-existing `.md` files that lack the trailing
newline. = = Only `docs/agents/nfi.md` carries merge-driver weight; = = the
rest belong to the tree-hygiene card. = = NOT FIXED HERE (= = this scope
guards the byte, = = it does not sweep the tree).
2. = = A `.md` truncated to EMPTY drops the byte, = = and the gate calls it
clean. = = Inherited from round 1, = = no merge-driver consequence (= = the
registry's tail is gone with the whole file). = = The tree-hygiene card's.
3. = = `verify-dead.py` reports 4 PARTIAL dead declarations. = = The
session's base carries the SAME 4, = = so the session added none; = =
they are pre-existing and unowned here.
4. = = The design sweep's one hit on the session's changed files is a FALSE
POSITIVE: = = `Sources/WenshuApp/Features/Library/View/SidebarRowView.swift`
line 308 is a COMMENT that quotes the blocked form
(`// naked `Image(systemName:)` is the blocked form)`), = = and that file is
the sibling sidebar scope's, = = not this session's.
5. = = A sibling's card `t_1005d790` (= = "the chat transcript's guards
measure the production path") was in review when this session closed. = = It
is not this session's card, = = it moves on its own, = = and it is named here
rather than touched.
6. = = Two app instances were killed by an EXTERNAL signal during the
launch (= = the processes vanished with no crash report carrying their uuid,
= = and a sibling's session was running `pkill`-style cleanup at the time).
= = The app was relaunched and survived; = = the durable hazard is that every
tree's executable is named `WenshuApp`, = = so a loose-name kill reaches a
sibling's app.

## THE ONE COMMAND THAT COMPLETES THE LOOK

```bash
open -g /Volumes/ANAN/Engineering/wenshu/build/Wenshu.app
```

= = = and what to look at: = = the materials column's whole-library scope
draws ONE list (= = the library's own documents, = = then book 1, = = then
book 2), = =
and the inspector's board column builds only the cards on screen.
