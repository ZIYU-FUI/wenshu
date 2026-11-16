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

= = The whole suite was run TWICE on the merged side and TWICE on the base
`aa266622ea` (= = the commit before this scope's code, = = 3,672 tests in 564
suites), = = on the same machine, = = with the same command. = = The
merged-side size is 3,729 tests in 572 suites (= = the review lane's own
complete merged run, = = the only whole-suite run on the merged side that
finished its big target), = = and the two merged-side runs below were cut
short before the big target finished, = = so their counts are lower bounds. = = The
two merged-side runs were made in the MAIN checkout (= = each log's own
dependency warning names it, = = and the build path it records is the main
checkout's), = = and NOT on the tip under review: = = the tip's own nine
suite files are byte-identical to the base's, = = and the tip's tree differs
from either candidate main commit's by a handful of `Sources/` and `Tests/`
files (= = six against `20d2d3182`, = = five against `deff19bac4`, = = a
sibling scope's pane-tab work, = = and nothing of this scope's). = = WHICH
main commit those two runs measured is NOT recoverable from the logs (= =
they were cut short before that suite ran, = = and the checkout's reflog
was lost with the old .git), = = and it does not matter: = = what 7.2 needs
is the NINE files the isolation test runs, = = and every one of them is
byte-identical between the base and the tip (= = the same blob hash), = =
= = which is what this gate asks about. = = The
failing SITES are read out of the FULL log, = = not a tailed grep: = = the
grep is what made this section wrong the first time.

= = THE EVIDENCE IS THE COMMAND, = = AND A KEPT COPY. = = The four runs
are `swift test --package-path .`, = = once on the merged side and once on
the base, = = twice each, = = and the SITES are read out of each run's full
output (= = the two merged runs were CUT SHORT before the big target
finished, = = so their counts are lower bounds, = = and that is why the
isolation test, = = not the count, = = is the gate). = = A reader re-runs
the command and reads the sites, = = and the four logs are ALSO kept at
`~/.hermes/profiles/pocock/cache/evidence/72-compare/` (= = a directory
that is NOT the pruned scratch one, = = because a scratch directory is
pruned after 24 hours idle and = = = = a stored log in it is a promise that
expires; = = the repo's own row 7 records that defect for the probes, = =
and the probes were moved into the repo to answer it).

= = ⇒ ⇒ AND THE FIRST DRAFT OF THIS SECTION WAS WRONG IN A WAY NO
AMOUNT OF RE-RUNNING FIXES, = = SO THE SECTION IS NOW BUILT ON WHAT DOES
NOT MOVE. = = The draft claimed an INCLUSION (= = the merged tree's failing
set inside the base's), = = on the strength of ONE run per tree. = = The
four whole-suite runs above (= = two per tree) and the review lane's eight
(= = a second campaign, = = two days later) show that the whole-suite failing
SET FLOATS ON THE SAME TREE: = = the same suite is red in one run and green
in the next, = = and which one is red changes between runs. = = So no set
comparison, = = from any number of whole-suite runs, = = can decide this
gate. = = That claim is withdrawn.

What DOES NOT MOVE is the ISOLATION test: = = every failing suite is run
ALONE on both trees, = = with the same command. = = A site that fails alone
is deterministic, = = and a site that passes alone is a wall-clock bound
that only the concurrent whole-suite run starves. = = That is the
comparison this gate rests on, = = and it is reproducible on demand.

Three sites fail ALONE, = = immediately, = = on BOTH trees, = = with the
same assertion and the same count (= = the seconds are the isolation
campaign's own, = = and they are a magnitude, = = not a bound):

| Site | the base `aa266622ea` | the merged tip |
| --- | --- | --- |
| `ChatViewHistoryShortcutTests.swift:35` | fails (8 tests, 1 issue, 0.013 s) | fails (8 tests, 1 issue, 0.016 s) |
| `EditorTabTitleTests.swift:60` | fails (10 tests, 1 issue, 0.005 s) | fails (10 tests, 1 issue, 0.005 s) |
| `AsyncDelegationRegistryTests.swift:104` | fails (5 tests, 1 issue, 0.010 s) | fails (5 tests, 1 issue, 0.017 s) |

Every other site passes when its suite runs alone, = = on BOTH trees:

| Suite, and the bound inside it | the base `aa266622ea` | the merged tip |
| --- | --- | --- |
| `EditorPersistenceTests` (= = a 3 s auto-save deadline) | 11/11 pass, 3.028 s | 11/11 pass, 3.052 s |
| `HermesTodoStoreConcurrencyTests` (= = `elapsed < 5.0`) | 5/5 pass, 0.048 s | 5/5 pass, 0.044 s |
| `WenshuConductorToolRegistryWiringTests` (= = a 10 s warm-up) | 5/5 pass, 0.112 s | 5/5 pass, 0.108 s |
| `WenshuReplicatedKanbanEndToEndTests` (= = T10) | 10/10 pass, 0.105 s | 10/10 pass, 0.077 s |
| `LongRunningGoalButtonTests` | 3/3 pass, 0.388 s | 3/3 pass, 0.247 s |
| `FileToolsTests` (= = its four sites were in FOUR of the eight whole-suite runs) | 5/5 pass, 0.003 s | 5/5 pass, 0.002 s |

So 7.2 is green for this scope: = = the deterministic red is three sites,
= = the same three on either side, = = and none of the three is in a file
this scope touched (= = the scope's two `Sources/` files are a MODEL and a
STORE). = = The rest is the machine's load, = = not the change's.

= = ⇒ ⇒ AND ONE RED IS NOT THE CODE'S AT ALL. = = `SSEReaderLiveTests`
hits the LIVE provider, = = and the provider's answer is its own: = = in the
first campaign it answered **HTTP 429** (= = the quota wall, = = on both
trees), = = and in the second campaign it answered normally. = = So it is
listed here as a PROVIDER red, = = never as a code red, = = and a reader
who sees it red in one run and green in the next is seeing the provider's
mood, = = not a change.

= = ⇒ ⇒ AND THE REVIEW BEFORE THIS ONE FOUND FOUR THINGS, = = AND THIS
SECTION ANSWERS EACH OF THEM WITH ITS OWN NUMBER. = = (`t_28eeebf4`, = =
`changes_requested` on `ae92fbd3a6`.) = = (1) Its dead-code count did not
reproduce: = = it read **127 ALIVE**, = = not the 126 this document carried,
= = and 127 is what `verify-dead.py` prints at this tree. = = (2) Its 7.2 row
contradicted itself, = = and the SUBSET claim did not reproduce: = = that
claim is WITHDRAWN above, = = and the gate now rests on the isolation test.
= = (3) Its verdict split was 6 `approved` and 6 `changes_requested`, = = not
the 5/7 this document carried. = = (4) Its `98 other commits` did not
reproduce: = = the repo writes a `style(...)` subject in thirteen commits
on `main` at this tree (= = seventy across every ref, = = over nineteen
distinct scopes: = = `desktop`, = = `import`, = = `tui`, = = `devtool`, = =
and others), = = and it is `style(scope):` that does not exist at all.
= = (The count is the one THIS TREE carries, = = and `main` moves: = = a
fourteenth `style(tests):` commit landed on it after this document was
written.)
= = And the row this document's own card names, = = the 7.8 row, = = claimed
every subject's type was in the CI's set, = = while this document said one
of its own commits would be refused: = = of the nineteen subjects named here
that resolve in this tree, = = eighteen carry a type in the CI's set, = = and
the one that does not is the scope's own `style(devtool):`, = = which is
exactly the disagreement the next section records. = = (The seven names that
do not resolve are the scope's own branch commits: = = they were never on
`main`, = = and the review-history table below names them as the commits the
cards reviewed, = = not as commits of `main`.)

= = ⇒ ⇒ AND A REVIEWER'S OWN CAMPAIGN MEASURED IT AGAIN, = = AND ITS
NUMBERS MATCH THE TABLES ABOVE. = = The review lane ran the whole suite
EIGHT times (= = in SIX worktrees over FOUR commits, = = not on one
tree), = = and then ran each failing suite ALONE on both trees, = = and its
numbers MATCH the tables above: = = the same three deterministic reds with
the same counts, = = and the same six suites green alone. = = So the claim
is not this document's own reading of its own logs: = = it is what a second
pair of hands measured.

= = AND WHAT THOSE EIGHT RUNS MEASURE, = = STATED EXACTLY: = = the failing
SET ranged from FOUR sites to TEN ACROSS the eight runs, = = and the same
three deterministic reds were in EVERY one of them. = = The range is NOT one
tree's: = = the FOUR-site run and the TEN-site run measured DIFFERENT trees
(= = the base and the scope's own code commit), = = and PER TREE the sizes
were the base's 4, 6 and 7, = = the tip's 6, 7 and 9, = = the scope's code
commit's 10, = = and the code's parent's 9. = = The other sites
(= = one to seven per run) were NOT all different: = = TWO runs carried the
SAME three (= = `EditorPersistenceTests:253`, = = `EditorPersistenceTests:259`,
= = `WenshuConductorToolRegistryWiringTests:237`), = = and the rest differed.
= = The `FileToolsTests` sites (= = four of them) were in FOUR of the eight
runs, = = not one. = = And the live provider's HTTP 429 was NOT among these
eight runs at all: = = the `SSE reading against the live provider` suite
PASSED in every one of them. = = The 429 belongs to the isolation campaign
above, = = and it is recorded there.


## The gates, = = re-run ON THE MERGED TREE (= = not on a branch)

| Gate | What it says | Where |
| --- | --- | --- |
| 7.1 `swift build` | **PASS** (= = "Build complete!" on the merged tip) | `swift build --package-path .` |
| 7.2 `swift test` | **PASS WITH A PRE-EXISTING RED BASELINE** (= = the whole-suite failing SET floats on the same tree, = = so the gate rests on the ISOLATION test: = = the same THREE sites fail alone on either side, = = the six other suites that ever failed a whole-suite run pass alone on either side, = = and none of the three is in a file this scope touched; = = the provider's 429 is not a code red) | `swift test --package-path .` on the merged tip and on the base `aa266622ea`, = = the failing sites read from the FULL log, = = then each failing suite run ALONE on both |
| 7.3 the 9-grep design sweep | **N/A** (= = this scope changed NO view file: = = its two `Sources/` files are a MODEL and a STORE) | = = |
| 7.5 the CJK audit | **PASS** (= = one CJK hit, = = in `OOB.md`, = = and it is the boss's own OOB quoted verbatim: = = `OOB.md` held 1,656 CJK characters BEFORE this scope's commit) | `git show <sha> \| grep "^+"` per commit |
| 7.6 no dead code | **PASS** (= = `verify-dead.py`: = = 127 ALIVE, = = 4 PARTIAL, = = 0 DEAD) | `Tools/wenshu-devtool/verify-dead.py` |
| 7.8 commit hygiene | **PASS on the type** (= = of the subjects this document names that RESOLVE in this tree (= = nineteen of the twenty-six names, = = the other seven are the scope's own branch commits, = = which are off `main` and are named in the review-history table below), = = eighteen carry a type in the CI's set; = = the one that does not is `befbf1e65d`, = = the scope's own `style(devtool):`, = = which the CI would refuse (= = see the self-found defect below)) | = = |
| 7.9 the verdict field | **PASS** (= = twelve review cards, = = every one of them with a top-level `review_outcome`: = = 6 `approved`, = = 6 `changes_requested` after their findings landed; = = and a THIRTEENTH, = = this document's own card (`t_28eeebf4`), = = which carries a `changes_requested` of its own, = = and whose findings the section above answers) | `review_gate.py --card <id>` |
| the pollution gate | **PASS** | `ci_change_gate.py --base main --check pollution` |
| the formatting gate | **PASS** | `ci_change_gate.py --base main --check formatting` |
| the NFI gate | **PASS** (= = `nfi-split.py --check` = = PASS; = = `nfi-loc-check.py` = = "the change adds no registry row; nothing to check", = = which is the gate's own wording for a row UPDATED in place, = = so the count this change wrote into the row is held by the rule and not by the gate) | = = |
| the probe index's own test | **PASS** (= = 5/5) | `test_probe_index.py` |

### ⇒ ⇒ THE ONE DEFECT THIS SCOPE FOUND IN ITSELF, = = AND IT IS NOT
MINE TO FIX ALONE

`befbf1e65d`'s subject is `style(devtool): ...`. = = The CI's
`lint-commits` job accepts only the nine types `feat`, `fix`, `docs`,
`test`, `refactor`, `chore`, `perf`, `build`, `ci` (= = the job's own
comment says the types outside that set are accepted only WITHOUT a
scope). = = So `style(devtool):` would be REFUSED by that job, = = and
the repo writes a `style(...)` subject in 13 commits on `main` (= = 70
across every ref), = = so this is a PRE-EXISTING disagreement between the
CI's rule and the house's practice, = = not a defect this scope
introduced. = = ⇒ ⇒ It is
recorded here as its own row (= = not folded into any requirement's
verdict), = = and it is the boss's call whether the CI's rule or the
house's practice is the one to change. = = The commit is PUSHED, = = and
a pushed sha is never rewritten (= = the correction is a NEW commit).

## The review history (= = the rounds, = = each of which found a real
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

**⇒ ⇒  AND THE THREE APPROVED CARDS THAT OWN CODE** (= =
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
corpus is too small to produce one anyway: = = 2 shelves, = = 2 books, = =
7 book folders, = = 6 reference entities, = = and 26 cover stills). = = (2) The per-frame class has NO microsecond figure, = =
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
| 5 | the CI's `lint-commits` rule vs the house's `style(...)` practice (= = thirteen commits on `main` at this tree, = = seventy across every ref) | **REPORTED, NOT FIXED** (= = a PRE-EXISTING disagreement, = = and a pushed sha is never rewritten) | the boss's call |
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
