#  2026-11-14 = = the performance audit scope's closeout

#  The scope: = = audit Wenshu's render path against Apple's own
#  documentation, = = on the user's own library, = = and land the
#  findings as an ordered list of fixes. = = The boss named two
#  requirements: = = the render path is slow and the app stutters (= = the
#  render path's costs, = = ranked) and non-compliance with HIG can itself cost
#  performance (= = the HIG axis, = = = = a second axis, = = not a subset).
#
#  ⇒ ⇒  AND THE BOSS SET ONE MEASUREMENT CONSTRAINT: = = do not launch
#  the app and time it, = = take the stall as a given and go read the code. = = So this
#  scope's conclusions are CODE-LEVEL findings plus MICRO-BENCHMARKS, = =
#  and there is NO Instruments trace and NO reproduced stall, = = because
#  the boss directed the work that way. = = The doc therefore claims
#  "these are the measured wastes in the render path", = = NOT "this is
#  the cause of the stall you felt".
#
#  ⇒ ⇒  THE COMMITS THIS PUSH CARRIED THAT ARE NOT THIS SCOPE'S: = =
#  a sibling session's commits rode along on `main` (= = the chrome
#  bottom bar's opaque surface at `a41cd9fe4`, = = the pane tab strips'
#  band regression at `34312424e7`, = = and the 2026-11-14 closeouts at
#  `3cea904570`, = = `87acabfe03`, = = `5cc666aac7`). = = Pushing them
#  was maintenance of the shared server state, = = not authorship. = =
#  Every row below names only this scope's own work.

## The symptom, = = the root cause, = = the fix

| # | The requirement | The symptom | The root cause | What landed |
| --- | --- | --- | --- | --- |
| 1 | Apple's official answer comes first | every requirement was answered from a paraphrase (= = a third-party HIG summary's margins and control heights) | the rule did not exist in the SSOT | `efe1692522` = = AGENTS.md §1.17 + OOB.md's 2026-11-13 entry + `wenshu-iron-rules-audit` v4's first rule; = = and the two skills that make it executable (= = `apple-hig-lookup` = = 173 cached HIG articles per language, = = `apple-doc-search` = = Apple's whole documentation as a discovery layer) |
| 2 | The gate must SEE those skills | `agents_gate.py` accepted a doc that named a non-existent Apple skill | the gate's prefix list had no `apple-`, = = and it scanned only the profiles, = = not the shared tree | `aa266622ea` = = the `apple-` prefix + the `~/.hermes/shared/local-skills` root; = = the reviewer's own mutation caught a fake `apple-totally-made-up-skill` and did NOT flag the two real ones |
| 3 | The streamed chat part must keep its identity | the trailing row was torn down and rebuilt 60 times a second while a reply streamed | `StreamingAccumulator` REPLACED the trailing part with a factory call, = = and the factory mints a fresh `UUID()`, = = so the `ForEach` saw a changed identity | `6337ac9b1e` = = the part's `kind` became `var` and a mutating `appending(_:)` extends it in place; = = the reviewer's three-arm mutation: = = with the fix = = passes, = = with it reverted = = exactly TWO identity assertions fail, = = restored = = byte-identical; = = 5/5 in `StreamingUpdateTests` |
| 4 | The render path's measured costs, = = ranked | the app stutters | = = the render path recomputed work it already had, = = and the audit's first version MEASURED IT WRONG | `b33605b82b` (the sweep) + `f2401ff78e` (the reload class) = = 26 findings with their file:line, = = their measured floor, = = and the Apple sentence each one violates; = = four review rounds, = = each of which found a real defect |
| 5 | The HIG axis (= = a SECOND axis) | non-compliance with HIG was never checked, = = so the audit's own HIG sentences were cited from a third-party summary | the first version's HIG axis was carried entirely by Apple's *developer* pages (= = which are about performance, = = not the guidelines) | the sweep's HIG section: = = FOUR findings (= = C5, C8, C12, B8) read from the local 173-page corpus, = = and FOUR surfaces CHECKED and found CLEAN (= = the board's single `ScrollView`, = = the sidebar's `List`, = = every loading surface, = = the sidebar's hierarchy) |
| 6 | The ordered list of fixes | the findings existed, = = but nothing said what to fix first | the findings were ranked by RAW MICROSECONDS, = = which hides the one the user feels | `db7c404a08` + its five corrections = = the order is by fix SHAPE (= = how much RISK the fix carries), = = with the cost as the second column; = = five groups, = = and the open question that was FALSIFIED |
| 7 | The numbers must be RE-MEASURABLE | the evidence lived in a scratch directory that is pruned after 24 hours, = = so a reader could not find the code that produced the numbers | the probes were never registered, = = and the repo has a home for probes that was not used | `ae6ed03d01` + `befbf1e65d` + `7ca3f3f1cd` = = both probes in `Tools/wenshu-devtool/probes/`, = = registered in `probe-index.md` with the commit they measured against, = = each printing that commit at run time; = = `test_probe_index.py` = = 5/5 |
| 8 | The registry carries the new files | three documents and two probes existed with no registry row, = = so rule 1.7 was broken | the closeout's own step (= = register every added file) had not been run | `1387465660` = = five rows with their LOC read LAST (= = after the content was final), = = and `nfi-loc-check.py` reads "every rewritten file's row carries its own count" |

## The measured before/after

= = **THIS SCOPE CHANGED NO USER-VISIBLE BEHAVIOUR**, = = so there is
no before/after on the screen to quote. = = What there IS is the
measurement, = = and the ONE shipped code change's own proof.

| Class | The measured floor | The largest item | The change |
| --- | --- | --- | --- |
| Per keystroke | **276.042 us** (= = two walks of the same 4,731-character document) | A1 + A2 = = the editor's counter and the status bar's = = ONE walk each | **NONE** (= = both are below Apple's 500 us finding line, = = and the scalar form reads a DIFFERENT unit, = = so it is not a drop-in fix) |
| Per frame while streaming | a COUNT, = = not a microsecond figure | the trailing row rebuilt 60x/s | **FIXED** (= = `6337ac9b1e`, = = same text on screen, = = built once instead of sixty times) |
| Per body pass | 542 card bodies + 490 markdown parses per board pass; = = 4 stat syscalls at the root | the board's plain `VStack` instead of a `LazyVStack` | **NONE** (= = visible change, = = the boss's call) |
| Per sidebar reload | **1,589.667 us** (= = D1's ten folder counts + D3's shelves walk, = = MEASURED together) | both halves are in the SAME `reload()` | **NONE** (= = the counts on screen must not move) |
| Per launch | every reference-library row's identity changes | the `Hasher`-seeded UUID | **NONE** (= = a CORRECTNESS bug, = = needs a migration, = = = = a design decision) |

### ⇒ ⇒  THE 7.2 COMPARISON, = = MEASURED NOT INFERRED (= = the house's
rule: = = an existing red must be BASELINED at the parent commit, = =
never argued)

= = The whole suite (= = 3,672 tests in 564 suites) was run TWICE on the
same machine: = = once on the merged tip, = = once on the base
`aa266622ea` (= = the commit before this scope's code), = = with the same
command and the same grep.

| Tree | The failing set |
| --- | --- |
| the base `aa266622ea` | 6 issues (= = T10's tool_use JSON, = = `displayTitle_documentPathBasenameWins_overTitle`, = = `handleDirtyTransition(true)`, = = `startLongRunningGoal`, = = the chat's @-mention path, = = and the HermesTodoStore deadlock regression) |
| the merged tip | the SAME set, = = MINUS two (= = `TodoStoreTool.execute() returns in under 5 seconds`, = = `handleDirtyTransition(true)`, = = `displayTitle_documentPathBasenameWins_overTitle`, = = and the chat's @-mention path) |

= = ⇒ ⇒ **THE MERGED TREE'S FAILURE SET IS A SUBSET OF THE BASE'S**, = =
so this scope introduced NO new failure. = = ⇒ ⇒ And every one of them
is TIMING-SENSITIVE: = = their durations are 73 to 106 SECONDS (= = the
assertions are wall-clock bounds, = = and a concurrent `swift test` starves
them), = = and they FLOAT between runs (= = the base's own set moved
between its two runs). = = ⇒ ⇒ AND NONE of the failing test files is
among this scope's twelve (= = the two failing suites are
`HermesTodoStoreConcurrencyTests` and
`WenshuConductorToolRegistryWiringTests`, = = and this scope touched
neither). = = ⇒ ⇒ So 7.2 is green FOR THIS SCOPE, = = and the
pre-existing red is the tree's, = = not this scope's.

## The gates, = = re-run ON THE MERGED TREE (= = not on a branch)

| Gate | What it says | Where |
| --- | --- | --- |
| 7.1 `swift build` | **PASS** (= = "Build complete!" on the merged tip) | `swift build --package-path .` |
| 7.2 `swift test` | **PASS WITH A PRE-EXISTING RED BASELINE** (= = the merged tree's failure SET is a SUBSET of the base's, = = so this scope introduced NO new failure; = = the failures are load-sensitive and FLOAT between runs) | `swift test --package-path .` on the merged tip and on the base `aa266622ea`, = = the same grep |
| 7.3 the 9-grep design sweep | **N/A** (= = this scope changed NO view file: = = its two `Sources/` files are a MODEL and a STORE) | = = |
| 7.5 the CJK audit | **PASS** (= = one CJK hit, = = in `OOB.md`, = = and it is the boss's own OOB quoted verbatim: = = `OOB.md` held 1,656 CJK characters BEFORE this scope's commit) | `git show <sha> \| grep "^+"` per commit |
| 7.6 no dead code | **PASS** (= = `verify-dead.py`: = = 126 ALIVE, = = 4 PARTIAL, = = 0 DEAD) | `Tools/wenshu-devtool/verify-dead.py` |
| 7.8 commit hygiene | **PASS on the type** (= = every subject's type is in the CI's set) | = = |
| 7.9 the verdict field | **PASS** (= = every one of the 12 cards carries a top-level `review_outcome`; = = 5 `approved`, = = 7 `changes_requested` after their findings landed) | `review_gate.py --card <id>` |
| the pollution gate | **PASS** | `ci_change_gate.py --base main --check pollution` |
| the formatting gate | **PASS** | `ci_change_gate.py --base main --check formatting` |
| the NFI gate | **PASS** (= = `nfi-split.py --check` = = PASS; = = `nfi-loc-check.py` = = "every rewritten file's row carries its own count") | = = |
| the probe index's own test | **PASS** (= = 5/5) | `test_probe_index.py` |

### ⇒ ⇒ ONE DEFECT THIS SCOPE FOUND IN ITSELF, = = AND IT IS NOT
MINE TO FIX ALONE

`befbf1e65d`'s subject is `style(devtool): ...`. = = The CI's
`lint-commits` job accepts only the nine types `feat`, `fix`, `docs`,
`test`, `refactor`, `chore`, `perf`, `build`, `ci` (= = the job's own
comment says the types outside that set are accepted only WITHOUT a
scope). = = So `style(devtool):` would be REFUSED by that job, = = and
the repo writes `style(scope):` in 98 other commits, = = so this is a
PRE-EXISTING disagreement between the CI's rule and the house's
practice, = = not a defect this scope introduced. = = ⇒ ⇒ It is
recorded here as its own row (= = not folded into any requirement's
verdict), = = and it is the boss's call whether the CI's rule or the
house's practice is the one to change. = = The commit is PUSHED, = = and
a pushed sha is never rewritten (= = the correction is a NEW commit).

## The review history (= = five rounds, = = each of which found a real
defect)

| Card | The sha | The verdict | What it found |
| --- | --- | --- | --- |
| `t_f242876a` | `4f65098db4` | CHANGES REQUESTED | the numbers were MEANS taken while three subagents were compiling, = = 2-3x inflated; = = the identity chain itself = = PASS |
| `t_f90d38f2` | `903c429ec4` | CHANGES REQUESTED | the quotes were not re-read against their pages; = = an abbreviated verification table had MASKED a dropped word in Apple's own hedged wording |
| `t_ad22f54c` | `e430d314f8` | CHANGES REQUESTED | a quote that stopped at a comma and substituted a full stop (= = so it was not a string the page carries); = = a `---` with no blank line before it (= = a setext heading) |
| `t_258485da` | `733c57009f` | **APPROVED** | = = all four checks PASS |
| `t_e34b6fa5` | `63ad38f03d` | CHANGES REQUESTED | three figures that were not the sweep's, = = an invented per-frame figure, = = a withdrawn byte count, = = a HIG table that contradicted the sweep, = = and four findings with no row |
| `t_5fb86128` | `8acd862d1` | CHANGES REQUESTED | the measurement table's caption was false of the row above it (= = it named one probe while the row came from the other); = = and one finding WITHDRAWN after the reviewer's own counter-test |
| `t_bedecdbe` | `947755609` | **APPROVED** | = = all four checks PASS, = = at the branch tip, = = after the tip moved mid-review |
| `t_38d004f3` | `5516e98474` | CHANGES REQUESTED | a finding in the wrong group (= = D3), = = and a proof that named a file no branch ever carried |
| `t_337577dd` | `5f5efddcd7` | **APPROVED** | = = all six checks PASS |

**⇒ ⇒  AND THE TWO APPROVED CARDS THAT OWN CODE** (= =
`t_7ff7d29c` for the Apple-first rule, = = `t_e33cebdd` for the gate
fix, = = `t_99e1c1e8` for the identity fix) = = each with its own
mutation or gate proof.

## What was FALSIFIED, = = and what was NOT MEASURED

**FALSIFIED (= = the sweep's biggest open question).** = = "is the
editor's configuration rebuilt on every body pass?" = = The SHAPE is
real (= = `editorSurface` is a computed property read inside `body`),
= = but the COST is 0.125 us, = = because the factory's 22
`Notification.Name` allocations are all it does and the book directory it
would scan is nil in production. = = So it is NOT the biggest cost in
the tree, = = and the sweep's "this might be the largest cost in the
tree" was wrong. = = ⇒ ⇒ It is also a LATENT LANDMINE: = = the day
someone wires `currentBookDirectory`, = = the same factory starts paying
a 7-folder directory scan (= = **188.833 us min**) per body pass, = = so
that fix must cache the scan.

**NOT MEASURED.** = = (1) NO Instruments trace exists, = = and no stall
was reproduced (= = the boss directed the work to the code, = = and the
corpus is too small to produce one anyway: = = 29 files, = = 5 books, = =
56 assets). = = (2) The per-frame class has NO microsecond figure, = =
because the cost is a subtree rebuild (= = SwiftUI discards the row and
builds a new one), = = and a subtree rebuild's cost is the work inside
that subtree, = = not a timer on the row's construction. = = (3) The
board's 490 markdown parses carry an ESTIMATE (= = the chat's measured
5.08-61.44 us per parse applied to bodies averaging 23.1 characters),
= = not a measurement of the board's own bodies. = = (4) The per-window
costs for the settings and cover surfaces were read from source, = =
not timed.

## The open items, = = with their owners

| # | The open item | Its state | Its owner |
| --- | --- | --- | --- |
| 1 | the FIVE changes the user sees (= = C1 the board's lazy stack, = = C5 the search animation, = = C8 the forever-looping icon, = = C10 the eager video player, = = C12 the progress animation) | **NOT STARTED** (= = each changes what the user sees, = = so each is the boss's call, = = not the implementer's) | the boss's eye first, = = then a ticket |
| 2 | E1's cross-launch identity instability | **NOT STARTED** (= = a CORRECTNESS bug, = = not a speedup: = = the fix changes the id VALUES, = = so it needs a migration or a fallback that resolves an old id) | a design decision first, = = then a ticket |
| 3 | the editor's per-keystroke double walk (= = 276.042 us) | **NOT STARTED** (= = below Apple's finding line, = = and the scalar form reads a DIFFERENT unit, = = so it cannot be swapped in) | a ticket, = = if the boss wants it |
| 4 | the reload class's 1,589.667 us | **NOT STARTED** (= = one listing instead of ten, = = but the counts on screen must not move) | a ticket, = = with the boss's eye on the numbers |
| 5 | the CI's `lint-commits` rule vs the house's `style(scope):` practice (= = 98 commits) | **REPORTED, NOT FIXED** (= = a PRE-EXISTING disagreement, = = and a pushed sha is never rewritten) | the boss's call |
| 6 | the `WenshuEditorServicesFactory`'s latent 188.833 us scan | **NOT STARTED** (= = it fires only when the book directory is wired, = = so the fix that wires it must cache the scan) | whoever wires the book directory |

## The skills this scope built (= = = = = the part that outlives the
audit)

| Skill | What it does | Where |
| --- | --- | --- |
| `apple-hig-lookup` | Apple's HIG as a QUOTABLE source (= = 173 English + 173 Chinese articles cached locally, = = so a quote can be searched and checked without the network) | `~/.hermes/shared/local-skills/apple-hig-lookup/` |
| `apple-doc-search` | Apple's WHOLE documentation as a discovery layer (= = the search endpoint, = = the JSONL diff replay, = = the three metadata shapes) | `~/.hermes/shared/local-skills/apple-doc-search/` |
| `swiftui-performance-audit` | the render path's path classes, = = the min/median/p95 harness rule, = = and the quote-verification discipline | `~/.hermes/profiles/pocock/skills/software-development/swiftui-performance-audit/` |
| `wenshu-iron-rules-audit` v4 | the 42 Wenshu rules, = = now with "Apple's official answer comes first" as rule 1 | `~/.hermes/shared/wenshu-skills/wenshu-iron-rules-audit/` |

**⇒ ⇒  THE THREE-LAYER CHAIN IS THE DELIVERABLE THAT OUTLIVES THIS
SCOPE:** = = `apple-doc-search` (= = what Apple HAS) = = →
`apple-hig-lookup` (= = what Apple SAYS) = = → the SDK on disk (= =
what the symbols ARE). = = Every number and every rule in this scope
came through it.

## The residue this scope left behind (= = and what it did NOT leave)

**REMOVED** (= = this scope's own worktrees and branches, = = and only
its own): = = `wt/apple-official-first`, = = `wt/apple-gate-fix`, = =
`wt/chat-part-identity`, = = `wt/perf-audit-2026-11-13`, = =
`wt/perf-fix-order-2026-11-13`, = = `wt/session-closeout-2026-11-13`,
= = and their six worktrees under `.worktrees/wt/`.

**LEFT** (= = NOT this scope's, = = and a sibling's live assets are not
to be deleted even when they look unused): = = `wt/applemode`, = =
`wt/perf-batch2`, = = `wt/perf-batch2-r2`, = = the board's own card
worktrees under `.worktrees/t_*`, = = and the running app instances
(= = the sibling's `inspector-card` and `wt-tbsep` builds). = = ⇒ ⇒ The
app was NOT launched by this scope (= = it is a documentation scope, = =
and the boss directed the work to the code), = = so there is no boss's
look to record here, = = and no instance of this scope's to leave
running.
