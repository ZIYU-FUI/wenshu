# 2026-11-02 — The project inventory: what is left over

The state of the tree and the board at `main` = `e9a85dcad9`, measured.

## Headline

**Two CI steps could not go red, and one of them is the step that decides
whether the tree's tests pass.** That is the finding that matters; the rest
is drift the tree already knows about.

The CI's test step read `grep "Test run" log | tail -1` and asked whether
THAT line said "failed". The package has three test targets, each printing
its own summary, and the failing one is not the last:

```
Test run with 143 tests in 32 suites passed            <- WenshuDataTests
Test run with 3219 tests in 513 suites failed ... with 11 issues  <- WenshuAppTests
Test run with 208 tests in 24 suites passed            <- WenshuAgentTests
```

**How each block's target is attributed** (= the method, so the reader can
re-derive it): every "Test run with" block is one Swift Testing TARGET's
suites, and the tree's three targets declare 32, 513 and 24 `@Suite`s
respectively:

  WenshuDataTests   `Sources/WenshuData/Tests`  = 32 `@Suite`   -> the 143/32 block
  WenshuAppTests    `Tests/WenshuAppTests`       = 513 `@Suite`  -> the 3219/513 block
  WenshuAgentTests  `Sources/WenshuAgent/Tests`  = 24 `@Suite`   -> the 208/24 block

(the declaration count is one-to-one with the reported suite count in all
three cases, so the attribution is exact and needs no caveat).

The declaration count is the number of lines whose trimmed text starts
with `@Suite` (`git grep -h -E '^[[:space:]]*@Suite' <tree> -- <the
target's path> | wc -l`), NOT the number of occurrences of the token:
the app target's 520 occurrences include 7 that sit in comments, and
counting those would report a target the run never ran).

Replayed against this repository's own log on `main`: the old logic exits 0
(green, with 11 failing assertions), the new logic exits 1 and names the
target. The same log with the failures removed stays green, so the fix does
not false-red.

The build step had the second half of the same hole. `swift build 2>&1 | tee
log` reports tee's exit code, and a workflow step that does not name a shell
runs under `bash -e {0}` (= `-e`, no `-o pipefail`); naming `shell: bash`
runs `bash --noprofile --norc -eo pipefail {0}`. GitHub's own "supported
shells" table lists the two as different commands. Measured with one failing
command: `bash -e` gives the step exit 0, `bash -eo pipefail` gives exit 1.

Fixed on `wt/ci-gates-can-fail` (`d282931b4`), review card `t_69aeee62`.

## What the tree's own gates say

| gate | result |
| --- | --- |
| `agents_gate.py --file AGENTS.md` | loadable and true, headroom 480051 |
| `agents_gate.py --file Mobile/AGENTS.md` | loadable and true, headroom 480212 |
| `verify-dead.py` (= its default scope: the view directories) | DEAD = 0, PARTIAL = 4 files |
| `ci_change_gate.py --check formatting` | exit 0 |
| `ci_change_gate.py --check pollution` | exit 0 |
| `Tools/wenshu-devtool/tests/` (16 python suites) | 16 passed, 0 failed |
| `swift build --build-tests` (clean) | exit 0, 386 deduped warnings |
| `swift test` (whole suite) | 3219 tests / 513 suites, 11 issues |
| `Mobile/` build | Build complete |
| board | 258 done, 70 archived, 2 running, 1 ready; 0 done-but-unlanded |

## The whole-suite failures (11)

All 11 are pre-existing (= they failed on `main` before this session's four
landings, which removed a band of 12 to 15 and added 0; the band is a band
because the base tree's own flakiness moves the count between runs, and the
ADDED count is 0 in every run). Four of them are the tool registration
timeout, now owned by card `t_afdbbfd5`. All eleven assertion sites, by file:

```
AsyncDelegationRegistryTests.swift:104
ChatViewHistoryShortcutTests.swift:35
EditorTabTitleTests.swift:52 / :79 / :107
KanbanToolsTests.swift:118
ToolRegistryEndToEndTests.swift:153 / :172 / :211
ToolRegistryProductionTriggerTests.swift:63
WSMemoryProviderTests.swift:61
```

**Six of them pass when their suite runs alone on `main`. Five do not, in
three suites.** `EditorTabTitleTests` fails 3 of 3 on its own, with 3 issues,
and they are NOT a flake. One commit changed `EditorTab.displayTitle` twice
and the test was never updated:

- **`:52` (the precedence) is a REAL SOURCE BUG.** The source returns the
  entity title first and the path basename second. The boss's 2026-09-12
  OOB ("the tab title goes by the document name") asks for the basename
  first, and `OOB.md:103` (2026-10-19) records that the source is against
  that directive, that the failing tests are a real source bug, and that
  the boss asked for the problems to be cleared WITHOUT changing the
  behaviour, so it was left as a ticket. The fix is a functional change
  the boss deferred, so it needs a ruling and it is not this session's to
  take.
- **`:79` and `:107` (the placeholder) are STALE TEST EXPECTATIONS.** The
  same commit replaced the literal `preview-sample` with
  `NSLocalizedString("preview.tab.placeholder")`, whose value in the String
  Catalog is "Preview" (en) and a zh-Hans translation. The production
  behaviour is the intended localization work; the test still asserts the
  literal that the code stopped returning.

- **`AsyncDelegationRegistryTests.swift:104` fails in ISOLATION, every
  time, on both trees** (the run reports 5 tests in 1 suite with 1 issue:
  `Expectation failed: mentionsReported`). It is pre-existing, and it is
  deterministic, so it is NOT concurrency.
- **`ChatViewHistoryShortcutTests.swift:35` fails in ISOLATION, every time,
  on both trees** (8 tests in 1 suite with 1 issue:
  `Expectation failed: block.contains("totalTokens")`). It is pre-existing,
  and it is deterministic, so it is NOT concurrency.

So the "everything else is concurrency" shape is wrong for THREE suites: two
of `EditorTabTitleTests`'s three are a test that was not updated, one is a
deferred source-vs-directive conflict, and the other two suites fail alone
on both trees. All five belong to their own cards, and the partition above
closes: 6 + 5 = 11.

## The compiler's warnings (386, of which 7 are in production)

Captured with `swift build --build-tests > log 2>&1` (the stderr AFTER the
stdout redirect), OSC hyperlink escapes and CSI colour stripped, deduped on
(file, line, column). The paths are then made relative to the repository
root BEFORE the split, because the log carries absolute paths and a filter
that expects relative ones finds nothing.

| bucket | diagnostics | files |
| --- | --- | --- |
| the root `Tests/` tree | 369 | 96 |
| the package-local tests under `Sources/*/Tests/` | 10 | 8 |
| production (`Sources/`, minus `*/Tests/`) | **7** | **6** |
| the total | **386** | |

Seven diagnostics at six files: `ChatSessionViewModel.swift:400` raises two
(the mutation and the nonisolated autoclosure), and the other five files
raise one each.

| site | diagnostic | reading |
| --- | --- | --- |
| `ChatSessionViewModel.swift:400` | main-actor-isolated `conductor` mutated from a Sendable closure | the compiler cannot prove the NotificationCenter observer runs on the main actor; it does only because `queue: .main` is passed. A future edit to that argument turns this into a data race. |
| `ToolCatalogue.swift:93` | `presets` computed then discarded | the `settings.visibleTools` path ignores the presets the other overload passes. |
| `ContextEngine.swift:33` | module self-import | the project forbids importing your own module. |
| `AppleSidebarView.swift:183` | `service` defined but never used | dead binding. |
| `SidebarService.swift:480` | `??` right side never used | `summary` is not optional; the fallback is dead. |
| `CardCoverService.swift:405` | `withLock` result unused | benign (= the closure runs; the removed value is not wanted). |

## Comment policy drift (the largest cluster)

Every number below is produced by `Tools/wenshu-devtool/inventory-measure.py`,
which prints the method it used next to the number. Run it against any
commit:

```
python3 Tools/wenshu-devtool/inventory-measure.py --base e9a85dcad9
```

The population is every `.swift` under `Sources/`, minus the package-local
`*/Tests/` (= 490 files at this commit).

| measure | method | count |
| --- | --- | --- |
| malformed doc comments | a production comment line whose trimmed text starts with `// /` | **918** across 52 files |
| collapse receipts | a production comment line containing `rationale lines collapsed` | **942** (`A112` x 651, `A115` x 291; the sum is 942) |
| CJK in `///` doc comments | a production comment line containing a Han character (`\u4e00-\u9fff`) | **360** across 48 files |
| CJK in `//` line comments | as above, on the `//` lines | **389** across 81 files |
| boss-directive references | occurrences of the literal `OOB.md` in a production comment line | **254** across 97 files |
| ticket ids | `\b[A-Z]{1,3}\d{2,4}\b` in a production comment line | **1475** occurrences, 284 distinct |

`// /` is not a doc comment, so those 918 lines document nothing in Quick
Help or DocC. They are also where the receipts live, so the file reads as
"= 21 rationale lines collapsed" instead of the reason.

**The CJK counts cover comment LINES, and that is the distinction the fix
card depends on.** A comment line that quotes a Chinese novel template
still counts, because the line is a comment. Remove the string literals'
contents from each line first and the counts are **273** doc comments and
**229** line comments (= 502), which is the count of lines whose CJK is
really in the comment rather than in a quoted literal.

Rule 1.1 says English-only in comments; rule 1.5 forbids boss directive
text and ticket ids in comments; rule 1.6 allows only "(see OOB.md
#YYYY-MM-DD)", so the 254 is an UPPER BOUND (= it counts the permitted
form too). Rule 7.5 says comment-level CJK is manual, and the CI's
`lint-commits` job reads the commit SUBJECT only, so nothing enforces it.

## Size and coverage

| measure | count | its method |
| --- | --- | --- |
| production files over the 600-LOC cap | **18** of 490 | the production .swift files' line counts at the pinned tree |
| largest | `EditorChatNSController.swift` at 1509 (2.5x the cap) | the same line counts, sorted |
| median / p90 LOC | 150.5 / 470 | the same line counts, sorted |
| files with partially-dead declarations | **35** | `verify-dead.py` over ALL 490 production files (= the full-file run, NOT the tool's default scan of the view directories) |
| fully-dead files | 0 | the same run |
| production files whose basename never appears in any test's text | **91** | a name-based probe (= NOT coverage: no tool in this tree computes coverage) |
| production files carrying TODO | **10** | a production file whose text contains `TODO` |

The dead-declaration count needs its scope named, because the tool's
default run and a full run differ: `verify-dead.py` with no arguments
scans only the view directories and reports PARTIAL = 4, while the same
tool over all 490 production files reports PARTIAL = 35.
`DesignTokens.swift` alone carries 24 dead declarations out of its 104.
The TODO count is 7 when only a COMMENT's TODO counts, and 11 when the
package-local test files are included (= `Sources/*/Tests/`), so the
number given here is the production files' own.

## Housekeeping

- `.worktrees/` holds **38 GB** across 22 worktrees. About 15.5 GB is
  reclaimable: the worktrees whose cards are done and whose branches are
  already on `main`.
- `Mobile/AGENTS.md` rule 6.9 says a change to a gate "lands in both repos
  in the same ticket". There is ONE repo now (= the client at `Mobile/`
  inside it), and one copy of the gate scripts (= the root's).
- `Package.swift` declares `highlighterswift`, which no target imports
  directly (= it arrives transitively), so SwiftPM prints "dependency not
  used by any target" on every build. The tree pins it deliberately
  (`UnusedSpmDepRemovalTests.testHighlighterHasConsumer`), so this is
  noise, not a dead dependency.
- `Tests/.../Fixtures/cover-clip.mp4` is an unhandled file (= SwiftPM warns
  on every build), and `LoopingCoverViewStillTests` resolves it through
  `#filePath` and `guard let ... else { return }`, so the test silently
  PASSES when the fixture is not where it looks.

## The board

No card is done-but-unlanded. Four branches carry no card, and all four are
already on `main` (= harmless leftovers of finished review cards). The two
cards in flight belong to other work.

## What a reader should check, and how

The five claims that carry weight. Each is re-derivable from the tree.

1. **The two CI gates could not fail.** Take `main`'s own `swift test` log
   and run both the old and the new step logic against it. The old must
   exit 0 (green, with 11 failing assertions) and the new must exit 1 (red,
   naming the target). The build half: run one failing command under
   `bash -e` and under `bash --noprofile --norc -eo pipefail`; the first
   gives the step exit 0 and the second gives exit 1.
2. **The eleven whole-suite failures are pre-existing.** Run the same
   whole-suite command on `main` and on the tree before this session's four
   landings, and diff the two assertion lists. The claim is 0 ADDED, and a
   band of 12 to 15 removed.
3. **Seven of the 386 compiler warnings are in production.** Take a clean
   build's log, strip the OSC and CSI escapes, dedupe on (file, line,
   column), make the paths relative, and split `Tests/` from `Sources/`.
   The split is 369 + 10 + 7 = 386, and the seven are the six files named
   above.
4. **The comment drift counts.** Run `inventory-measure.py`; it prints each
   number with the method that produced it. The numbers to expect are in
   the table above.
5. **The registry row.** It is appended at the END of the table and edits no
   row the change does not own. `bash Tools/wenshu-devtool/tests/test_nfi_registry.sh`
   must pass.

## What this session did with the inventory

| finding | action |
| --- | --- |
| the CI's build and test steps cannot fail | FIXED on `wt/ci-gates-can-fail` (`d282931b4`), review card `t_69aeee62` |
| the tool registration's verdict depends on the machine's load | FIXED on `wt/tool-registration-barrier` (`d904cada7`), review card `t_88c21809` |
| the 7 production compiler warnings | FIXED on `wt/prod-warnings` (`8656d56fc`), review card `t_ead9f6ad` |
| the comment policy drift (918 + 749 CJK + 254 boss refs) | card `t_c5df8e21` (T3, `pocock`) |
| the 18 files over the 600-LOC cap | card `t_6820aaaf` (T3, `pocock`) |
| the 3 deterministic `EditorTabTitleTests` failures | card raised in this session (T2, `pocock`) |
| the reclaimable worktrees | pruned in this session |
