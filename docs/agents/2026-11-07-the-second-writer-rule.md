# The corpus has one truth, and the user's write wins

Closure doc for the second-writer defect: = the branch that made the agent a
second writer of the user's own text, = and the rule that stops it.

Date: 2026-11-07. Branch: `feature/editor-save-truth`.

## The symptom

The corpus keeps ONE body per document (= `<ws>/references/<uuid>.md`, = the
"truth"), = and TWO writers reach it: = the editor's save (= the user) = and
the agent (= the librarian's create / update / extend / upsert / import).

The branch's own change made the agent write the TRUTH (= previously it wrote
only the layer copy, = and the reader preferred the truth, = so the agent's
write was invisible). = **⇒ And it gave the agent NO comparison.** = So an
agent write replaced whatever the truth held, = including text the user had
typed in the editor.

Measured on the user's real library (= `~/Documents/anbaiqiang.ws`, = six
documents): = six truth/mirror pairs, = five differing by a leading newline
only, = and ONE (= `A9D67320-55B1-49FD-B9D3-0261FB4BEA98.md`) differing in
CONTENT = = the user's own edit.

**⇒ And it is unrecoverable:** = the corpus root has no `.git`, = and
`backups/` holds 0 `.md` files.

## The root cause

The earlier review's prescription (= restore the comparison basis to the
mirror) = **went stale at this tip**, = and the reason is the finding that
matters: = commit `49cc0315e6` made the editor's save write the MIRROR too.
So after a user edit BOTH locations hold the user's text, = and the mirror no
longer distinguishes "the agent re-imported the same body" from "the user
edited".

**⇒ So the mirror cannot be the witness.** = The same review measured that the
corpus index row's `updatedAt` is agent-only in production, = and that an
mtime is second-precision: = so a user edit in the SAME SECOND as the agent's
own write is invisible to any clock.

**⇒ And the diff-check's comparison basis alone does not reach the librarian's
real tool path** (`upsertReference` -> the same-title update branch), = which
wrote the truth with NO comparison at all. = So a user edit was destroyed on
BOTH agent write paths.

## The fix (= the second-writer rule)

**THE USER'S WRITE WINS.** = The agent may REPLACE the agent's own text, =
may ADD to the user's text, = and may never REPLACE any of the user's text.
= A write that would replace the user's text is REFUSED, = and the refusal is
REPORTED (= the LLM reads a named error that says what to do next).

The witness is a record per document
(= `<ws>/reference-library/.write-records/<uuid>.json`): = both writers record
themselves, = so the record names the owner AND hashes the text. = No clock is
involved. = A document written before the rule existed falls back to the
corpus copy as its witness.

Where the rule lives:

| Piece | Where |
| --- | --- |
| The rule, stated in the code | `ReferenceWriteGuard.swift`'s FILE HEADER docblock (= the block that opens the file, = where the rule is written out in full) = and the `Ownership` enum's `.agent` / `.user` cases |
| The gate (= the one chokepoint every agent path reaches) | `ReferenceBodyStore.write` |
| The user's write recorded | `FileSystemReferenceStore.replaceReferenceByID` (= the editor's write-through) |
| The record removed on a delete | `FileSystemReferenceStore.deleteReference` |
| The refusal, as a named error | `ReferenceStoreError.userOwnsTheTruth` -> `ReferenceLibraryError.userEditedReference` |

**⇒ AND THE RULE IS ALSO IN `assertWritable`'s OWN DOCBLOCK**, = so the function
that answers "may the agent write?" = says what the answer MEANS: = its
`- Throws:` line names `ReferenceStoreError.userOwnsTheTruth` = = "the truth
holds the user's text, = and this write would replace it".

**⇒ The write order is truth -> ownership record -> mirror.** = A mirror that
AGREES with the truth while no record exists would read as "the agent wrote
this", = so the record is written first, = and the mirror only when the record
landed. = A mirror left stale is the safe direction.

**⇒ The editor is never blocked.** = The editor writes the truth itself (= it
does not come through `ReferenceBodyStore.write`), = and the store's
write-through RECORDS the truth as the user's. = So the next agent write is
the one that gets refused.

## Measured before / after

| Measurement | Before | After |
| --- | --- | --- |
| The truth's comparison on an agent write | NONE (= the upsert path had no comparison) | the gate asks who owns the truth |
| A user edit, then an agent write | the user's text is destroyed | the write is REFUSED, = the user's text survives |
| The refusal reaching the LLM | (= no refusal existed) | a named error with a message that says what to do |
| The editor's own save | (= not blocked) | still not blocked (= it is not the user's write that is gated) |
| Two agent writes in a row | (= both landed) | both land (= the rule does not refuse the agent's own text) |
| A write that ADDS to the user's text | (= replaced it) | it lands, = and the user's text stays |
| A document written before the rule | (= no witness) | the corpus copy is the witness |
| The real library's 6 documents | (= one differing in content) | read-only check: = that one is REFUSED, = the 5 whitespace-only ones are allowed |

## The tests

`Tests/WenshuAppTests/Library/ReferenceWriteGuardTests.swift` = 9 tests, = all
on the WRITE side (= the read side was already pinned by
`ReferenceBodyStoreTests`):

1. A user edit, THEN an agent write (= through the librarian's REAL upsert
   path) = = the write is refused, = and the user's text is still in the truth.
2. The refusal reaches the LLM as a NAMED error, = with a message that says
   what to do.
3. The store's own error says the same thing (= the assertion is written in the
   hoisted form, = so it bites: = mutating the store's error message turns the
   suite RED).
4. Two agent writes in a row = = the second one lands.
5. A write that ADDS to the user's text lands, = and the user's text stays.
6. A document with no record = = the corpus copy is the witness.
7. A document with no record whose truth AGREES with the corpus copy = = the
   write lands.
8. A delete takes the record with it.
9. The record is bookkeeping, = and the readers never see it.

## The gates, and what they measured

| Gate | Result |
| --- | --- |
| `swift build --build-tests` | clean, = and **0 new warnings**: = a FRESH build (= not an incremental one, = which hides them) in a throwaway worktree at each sha, = counting the distinct warning lines, = gives **74 at this change's TRUE pre-fix parent (`cf574b0e07`), = 74 at this tip, = and the two lists are IDENTICAL**. = **⇒ AND THE FIX THAT MADE IT TRUE:** = one of this change's own assertions was VACUOUS (= `#expect((caught?.errorDescription ?? "").contains("refused"))` = discards the `contains` result, = so it never failed) = and it was the only occurrence of that shape in the repo's `Tests/`. = Before the fix the tip carried **76** (= the base's 74 = plus 2 for that line). = The `??` is now HOISTED OUT of the macro's argument, = which makes the assertion bite (= a mutation of the store's error message turns the suite RED) = and clears the 2 warnings it caused |
| `swift test --filter "<the 9 reference suites>"` | 62 tests in 9 suites passed |
| `swift test` (= the whole suite) | the FAILING SET, = not a count (= a count is not reproducible: = the same tip gave 4 issue sites in one run and 6 in another, = and the base gave 4 and 7). = **⇒ What IS reproducible:** = the 3 that overlap (`ChatViewHistoryShortcutTests`, = `EditorTabTitleTests`, = `AsyncDelegationRegistryTests`) fail IDENTICALLY when run ALONE at BOTH shas, = and every tip-only site also appears in a base run. = **⇒ So this change introduces ZERO new failures.** = The base's own extra sites are `FileToolsTests`' `pathDenied` cases (= the base worktree's path, = not a code failure) + the load-sensitive `EditorPersistenceTests` |
| `ci_change_gate.py --check formatting` | exit 0 over the change's 7 Swift files, = measured against this change's TRUE pre-fix parent (`cf574b0e07`). = Against the merge base the gate reports 267 findings, = and the PRE-FIX parent reports 271 against the same base, = so the change REMOVED 4 and added none (= the stack's own drift is not this change's) |
| `ci_change_gate.py --check pollution` | exit 0, = and the change's diff carries **0 CJK lines**. = **⇒ AND ONE CJK HIT IN THE MERGED DIFF IS NOT MINE:** = the range the landing card's base named (`b93b0ae57c..b44cf64325`) = carries ONE CJK character, = in `LibraryCorpusReader.swift`'s comment = = and that commit (`cf574b0e07`) = is the REBASED FORM of the stack's own `802f1b4703` (= a sibling's commit, = and this branch's PRE-FIX PARENT), = so the CJK was already in the tree before this change existed. = Measured against `cf574b0e07`, = the CJK hits in the ADDED lines = **0** |
| `verify-dead.py` | DEAD stays 0 |
| `nfi-split.py --check` | PASS |
| `test_nfi_registry.sh` | **exit 0, = `nfi registry: all tests passed` (= 17 assertions), = at EVERY sha of this branch.** = **⇒ AND BEFORE THE LANDING REBASE IT FAILED WITH 5 (= rows 1b, 1c, 4, 8, 8b) at this branch's OWN `e11b554522`, `7463ed2b13`, and `dfaae87f37`.** = **⇒ The cause is the repository's own table, = not the driver's fixture rows:** = those three commits DROPPED the blank line the driver reads (= the file's tail became "the last row, = then the comment"), = and this branch's own `f834261455` restored it. = **⇒ AND THE LANDING REBASE FIXED IT FOR GOOD:** = the rebase's 12 registry conflicts were each resolved with the driver's own merge, = and every rebased commit now carries the blank line (= measured: = the script passes at all 8 of this branch's rebased shas). = **⇒ MEASURE IT IN A THROWAWAY WORKTREE PER SHA, = AND RUN THAT SHA'S OWN COPY OF THE SCRIPT** (= the script derives its root from ITS OWN PATH, = so running the tip's copy against another sha measures the TIP's table) |
| `merge-preflight.sh feature/editor-save-truth` | CLEAN |

## The range this change is, = and what the rebase left alone

**⇒ AND THIS CHANGE IS SIX COMMITS, = not seven.** = The landing card named
`bb18d4be07..b44cf64325` (= seven), = but its BASE (`b93b0ae57c`) = the commit
BEFORE the pre-fix parent = = so the range it named swept in one commit that is
not this change's. = The six are `bb18d4be07`, `948ff2485f`, `401ae41305`,
`68639e0bce`, `8aa643b519`, `b44cf64325`.

**⇒ AND THE EDIT IS UNCHANGED BY THE REBASE.** = The pre-rebase diff
(`802f1b4703..5fb9030a6e`) and the rebased diff (`cf574b0e07..b44cf64325`)
differ in **21 changed content lines, = and every one of them is this doc's own
text.**

**⇒ AND THE METHOD THAT PRODUCES THE NUMBER, = so the next reader
reproduces it:** = the two diffs' `+`/`-` lines (= = excluding the `---` /
`+++` file headers and the `index` / `@@` lines), = compared with each other:

```bash
python3 - <<'PY'
import subprocess, difflib
def content(t):
    return [l for l in t.splitlines()
            if (l.startswith('+') or l.startswith('-'))
            and not l.startswith('+++') and not l.startswith('---')]
a = content(subprocess.run(['git', 'diff', '802f1b4703..5fb9030a6e'],
                        capture_output=True, text=True).stdout)
b = content(subprocess.run(['git', 'diff', 'cf574b0e07..b44cf64325'],
                        capture_output=True, text=True).stdout)
d = list(difflib.unified_diff(a, b, lineterm='', n=0))
print(sum(1 for l in d
          if (l.startswith('+') or l.startswith('-'))
          and not l.startswith('+++') and not l.startswith('---')))
PY
```

= **⇒ 21**, = and all 21 are in this doc. = **⇒ AND THE RAW DIFF-OF-DIFFS
reads 47 lines, = and two of its hunks are `docs/agents/nfi.md`'s** (= its
`index` line, = and the rows `main` added between the two bases, = which are
CONTEXT for this change, = not its content). = So the change-content reading
is the one that answers the question, = and the raw one is not.

## The registry's blank line (= a real lesson, and it cost a commit)

The registry's tail (= the blank line + the trailing comment that says where to
append) belongs to the FILE, = and the merge driver compares the two sides'
tails: = two sides with DIFFERENT tails disagree the way two rows disagree.

**⇒ So moving the rows up WITH the blank line made this side's tail differ
from main's, = and the merge reported a conflict on the file even though every
row merged.** = The blank line goes back where the driver expects it: = between
the last table row and the trailing comment.

## OPEN ITEMS (= left behind, and owned)

1. **The stack's 267 formatting findings against the merge base.** = The 36
   commits between `main` and this branch's pre-fix parent. = NOT this change's.
2. **The stack's load-sensitive test failures.** = Pre-existing, = and they
   move between runs (= the failing SET differs run to run), = so they are
   worth their own card rather than a per-card note.
3. **The landing.** = **⇒ DONE, = and it is what this branch's last commit
   records:** = the rebase in this worktree (= 12 registry conflicts, = each
   resolved with the driver's own merge and each checked for a lost row), = then
   the §7 gates re-run on the REBASED tree, = then the fast-forward into
   `main`. = **⇒ The rebase moved the merge-base, = and the gate's
   `change_id` = the diff from where the branch left `main` = = moved with it,
   = so the verdict that covers the tree that LANDS is re-issued against the
   rebased tip.** = The gates on the rebased tree: = the 9 reference suites =
   62 tests in 9 suites passed, = the formatting and pollution gates = exit 0
   (= 0 findings) against the rebased pre-fix parent, = `verify-dead` = DEAD 0,
   = `nfi-split` = PASS, = and the registry's own script = all tests passed at
   every one of this branch's 8 rebased shas.
4. **The real library's 6 divergent pairs.** = The guard now refuses the
   content-differing one, = but the 5 whitespace-only ones are still divergent
   on disk. = Reconciling them is the USER's call (= it rewrites their
   documents), = and this change deliberately wrote nothing there.
