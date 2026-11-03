# Session close: nine files under the 600-LOC cap, and the review card's shape

Date: 2026-11-03
Scope: the LOC cap campaign's library and agent-tool files, the two record
cards (the project inventory, the comment policy), and the review-card
shape defect that would have stranded every split.

## What landed

Nine production files were over `AGENTS.md` rule 6.6's 600-LOC cap. Seven
of them are split and on `main`; one is in review; one is blocked on
another lane.

| the file | before | after | the commit |
| --- | --- | --- | --- |
| `FileSystemReferenceStore.swift` | 811 | 483 + 343 | `278e0270c8` |
| `LibraryMigrator.swift` | 678 | 194 + 500 | `83a2b120bf` |
| `AppleSidebarView.swift` | 636 | 554 + 111 | `e039fc555e` |
| `SidebarService.swift` | 605 | 349 + 278 | `b1c5d10aa1` |
| `SettingView.swift` | 884 | 450 + 457 | `906079ac0d` |
| `BookChapterTool.swift` | 760 | 449 + 325 | `853290031e` |
| `BookEntityTool.swift` | 718 | 436 + 300 | `03ac3e9684` |
| `BookOutlineTool.swift` | 648 | 381 + 288 | `10725edba9` |
| `WenshuConductorImportRouter.swift` | 616 | 530 + 101 | `96faf0eed6` |

The over-cap count at `main` went from 18 to 7 with these landings
(measured at `main` = `96faf0eed6`: 490 production files, 7 over the
cap). The seven that remain are `ConversationLoop.swift` (1109),
`ChatSessionViewModel.swift` (942), `ChatView.swift` (892),
`PreviewPaneCard.swift` (790), `LayoutTreeState.swift` (773),
`RequestHelpers.swift` (673) and `WenshuAppDelegate.swift` (655).

Two records also landed: the project inventory of record (with its
measurement script) and the comment policy's eight densest files.

## The seam rule, and what it cost

A split's seam is the file's own clusters, and the rule that decides
where a cluster goes is: **a cluster that reads the type's own `private`
state stays with the type.** A cluster that reads nothing private can
move with no promotion at all.

The promotions the compiler named, per split:

| the split | promotions | why |
| --- | --- | --- |
| the reference store | 0 | the fallback is `nonisolated static` and carries its root as a parameter |
| the sidebar view | 0 | the lookup is four `static` functions over the tree's nodes |
| the sidebar service | 0 | the classification is `static` over the reference model |
| the book entity tool | 0 | the actor's state is already the module's default |
| the book chapter tool | 2 | `currentChatBookIDProvider`, `readTiers` |
| the book outline tool | 1 | `currentChatBookIDProvider` |
| the import router | 2 | `connector`, `runToolUseLoop` |
| the setting view | 17 | 16 members and one file-scope `private struct` |
| the library migrator | 2 | `seedDefaultHelpDoc`, `helpDocUpgrade` |

The lesson that cost the most: **the promotion list must be DERIVED, not
hand-written.** On `SettingView.swift` a hand-written list named 8
members and the compiler named 17: the misses were the `@State private
var` properties (which a scan of the type's `var`/`let`/`func`
declarations does not match) and a file-scope `private struct` (= a
fileprivate type, not a member). The derivation is: every declaration
whose text carries `private` before its `var`/`let`/`func` that the
OTHER file reads. The compiler confirms the list in both directions.

The second lesson: **the JSON helpers a dispatcher calls are the
dispatcher's OWN.** They cross the seam with it and stay `private`, which
is why the chapter and outline tools needed one and two promotions
rather than thirteen and eleven.

## The move is a move, and it is checkable three ways

For every split, three independent proofs, cheapest first:

1. **GIT.** `git diff --numstat <base>..<sha> -- <the parent file>`
   shows `0 <N>` (= a pure deletion) where the seam needs no promotion,
   and every surviving line is byte-identical to the original.
2. **TOKEN.** The moved cluster's code lines and the new file's code
   lines are identical after removing exactly the promoted `private`
   keywords and the formatter's trailing comma. The multiset alone is
   not enough: the ORDER matters too, because two clusters that each
   read as a subsequence but were SWAPPED would pass a multiset check.
3. **FORMATTER.** Reconstruct the moved cluster under the new file's
   header and `extension` wrapper, run `swiftformat` on it, and diff it
   against the committed file: it must come out byte-identical except
   the promotions. This is the strongest proof, because it also proves
   the formatter's rewrites are the only changes to the moved text.

The formatter's rewrites are semantics-preserving and the commit message
names which lines it touched. The gate charges a change for every
unformatted line inside its diff HUNKS (= the hunk's new-side span,
context lines included), so the moved code must be SwiftFormat-clean
with the DEFAULT rules (= the rules the gate runs with). A gate that
ran BEFORE its commit reports a vacuous green ("0 changed Swift file(s)
checked"), so the gate is read after the commit.

## The defect that would have stranded every split

`Tools/wenshu-devtool/review_gate.py`'s `reviewed_sha(body)` reads
ONLY the first paragraph of `## WHAT TO BUILD`, and returns the first
`[0-9a-f]{7,40}` match in it (or None). The same first paragraph also
decides the card's KIND, and the KIND decides the contract check: a card
that opens with a verdict claim is `review` (= no `## REVIEW HANDOFF`
section needed); a card that opens with the task statement is `build`
and trips `contract_error`.

Ten cards of this session put the sha in a LATER paragraph ("The sha
under review: **<sha>**"). All ten read `sha=None`, so
`matching_cards` returned `[]`, so `Scripts/merge-preflight.sh <branch>`
reported "no review card names the sha this branch points at" and
exited 3: **the splits would have been UNLANDABLE even after an
approving verdict.** Three of the ten additionally tripped
`contract_error`.

The fix is one paragraph, and it is the shape the five prior approved
cards already use:

    A verdict on `<the full 40-char sha>` (branch `<the branch>`).

Every card now opens with it, and the gate's own read of each is
`not_approved` (= found, awaiting the verdict) rather than
`contract_error`. The check to run BEFORE sending a card:

    python3 Tools/wenshu-devtool/review_gate.py --card <id>

## The rebase hazard in the append-only NFI registry

`docs/agents/nfi.md` is append-only, and its key-level merge driver runs
only on a MERGE, never on the fast-forward landing the gate demands. So a
rebase onto a moving `main` does not leave the registry's tail alone:
measured, three branches ended up with another lane's seven rows ABOVE
their own (= the table reordered), and three ended up with `main`'s 26
rows MISSING (= data loss).

Every split of this session now carries exactly ONE added line in
`docs/agents/nfi.md`, and no other lane's row moved or was removed. The
proof is `git diff --numstat main..<branch> -- docs/agents/nfi.md`, and
it must read `1 0` (or nothing, for a change that adds no row).

The registry's rule that follows from it: a row goes at the table's END,
and a row that is not the last row is a defect even when the row's own
content is right (= the reference store's row was exactly that, and
`14b840d570` moved it back).

## A source-reading test follows the split

The tree's tests read some production files' SOURCE as the specification.
After a split those reads return one file's slice, and the assertions
fail. The fix is to read the type's source across ALL the split files,
joined with a newline, so a token is counted the way it was counted when
the file was one.

Two details that cost a round each:

- a section helper that truncates at the type's closing brace has to
  change with the join (= `SettingViewTests`'s `settingViewSection` cut
  the source at the first `"\n}\n"`, so the joined extension's code was
  still cut away, and five assertions failed);
- a sweep that counts slots over a file's source needs the moved file in
  its table only if the counted site moved (= `LabelIconSweepTests`'s one
  Label icon slot stayed in the view's own file, so its table was correct
  as it stood).

## The measured before/after

The inventory's own measurement, at its pinned tree `e9a85dcad9`, by the
committed script (`Tools/wenshu-devtool/inventory-measure.py`):

| the measure | the base | the tip |
| --- | --- | --- |
| malformed `// /` doc comments | 918 across 52 files | 0 |
| `rationale lines collapsed` receipts | 942 | 0 |
| boss-directive references | 254 across 97 files | 4 (the form rule 1.6 allows) |
| production files over the cap | 18 of 490 | 11 after these landings |
| files with partially-dead declarations | 35 | 35 (unchanged) |

The three comment counts are measured over the eight densest files; the
two size counts over the whole production tree. Each row names its
method, and the script prints the method next to the number.

## The gates, and what each split ran

1. `swift build --build-tests` => exit 0, no warning in any split file.
2. The owning suites => the counts in the table below.
3. `ci_change_gate.py --base main --check formatting` => exit 0, with the
   number of changed Swift files the gate actually checked.
4. `ci_change_gate.py --base main --check pollution` => exit 0.
5. `verify-dead.py` => DEAD stays 0, PARTIAL stays 4.
6. `test_nfi_registry.sh` => all tests pass; `nfi-split.py --check` => PASS.
7. `merge-preflight.sh <branch>` => CLEAN, and exit 0 once the review
   card carries an approving verdict.

| the split | the owning suites |
| --- | --- |
| the reference store | 54 tests in 13 suites |
| the library migrator | 47 tests in 17 suites |
| the sidebar view | 39 tests in 12 suites |
| the sidebar service | 114 tests in 32 suites |
| the setting view | 100 tests in 17 suites + 11 tests in 2 suites |
| the book chapter tool | 46 tests in 13 suites |
| the book entity tool | 8 tests in 4 suites + 79 tests in 15 suites |
| the book outline tool | 14 tests in 4 suites |
| the import router | 29 tests in 11 suites |

## The open items

1. **The comment policy's 98 spliced blocks** (= card `t_c5df8e21`, the
   branch `wt/comment-policy`). 152 of the 397 collapsed comment blocks
   had only their receipt deleted and no prose written, and 98 of those
   still need new prose. The branch must not land until they are written.
   The commit message now states this plainly instead of claiming every
   block was rewritten.
2. **The import router's second request** (= card `t_366060c8`): APPROVED
   and landed as `96faf0eed6`. The split itself was approved; the
   registry row's LOC cell and the commit body's line count were one
   line short, and both were corrected. The rebase that followed the
   approval reproduced the same change-id, so the verdict still bound.
3. **The inventory's sixth request** (= card `t_5ea7fc28`). One label
   said "The other seven:" over a block of eleven assertion sites.
4. **Three files of the settings card** (`PreviewPaneCard.swift`,
   `RequestHelpers.swift`, `WenshuAppDelegate.swift`) and **four of the
   chat card** (`ConversationLoop.swift`, `ChatSessionViewModel.swift`,
   `ChatView.swift`, `LayoutTreeState.swift`), the latter four waiting on
   the comment policy. Together those are the seven files still over the
   cap.
5. **`main`'s pre-existing whole-suite failures.** They are the tree's
   known set and are not this session's: the record's own partition
   (= 6 that pass alone + 5 that do not = 11 sites) is in the inventory.
   Two more sites are load-sensitive and were measured on both trees:
   `EditorPersistenceTests.swift:253` and `:259` (= the two assertions
   of one test that waits 3 seconds) fail only under the whole suite's
   load, and the suite passes ALONE on the merged tree AND on the
   pre-session base (= 11 tests in 1 suite, 3.0 s, both). The whole
   suite has no reproducible number on this machine: it hangs in Core
   Spotlight at 0% CPU even with `CSSearchableIndexSearchTests`
   skipped (= the skip does not cover the suite that indexes), and the
   sibling lane's own run has been in that state for six hours. What
   the merged tree DID produce is the first target's summary (= 143
   tests in 32 suites passed, = the baseline's number) and the five
   sites above.

## What is NOT in this session's work

The commits between this session's landings that belong to other lanes:
`5442b96f12` (the memory provider's test), `ac20eff1f2`, `37c366718e`,
`917e087b09`, `0b7bfca144`, `80282c9c65`, `7dbecde4a5` and `f224ad6f26`
(the devtool cost and skill-sync tooling), and the card board client's
own series ending in `762cc2e828`. They are on `main` because the shared
checkout is shared, and they are named here so the landing table is not
read as one session's work.
