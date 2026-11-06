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
3. The store's own error says the same thing.
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
| `swift build --build-tests` | clean, = and 0 new warnings (= the base and the tip report the same warning set, = file for file) |
| `swift test --filter "<the 9 reference suites>"` | 62 tests in 9 suites passed |
| `swift test` (= the whole suite) | the FAILING SET, = not a count (= a count is not reproducible: = the same tip gave 4 issue sites in one run and 6 in another, = and the base gave 4 and 7). = **⇒ What IS reproducible:** = the 3 that overlap (`ChatViewHistoryShortcutTests`, = `EditorTabTitleTests`, = `AsyncDelegationRegistryTests`) fail IDENTICALLY when run ALONE at BOTH shas, = and every tip-only site also appears in a base run. = **⇒ So this change introduces ZERO new failures.** = The base's own extra sites are `FileToolsTests`' `pathDenied` cases (= the base worktree's path, = not a code failure) + the load-sensitive `EditorPersistenceTests` |
| `ci_change_gate.py --check formatting` | exit 0 over the change's 6 commits. = Against the merge base the gate reports 267 findings, = and the PRE-FIX parent reports 271 against the same base, = so the change REMOVED 4 and added none (= the stack's own drift is not this change's) |
| `ci_change_gate.py --check pollution` | exit 0, = and the change's diff carries 0 CJK lines |
| `verify-dead.py` | DEAD stays 0 |
| `nfi-split.py --check` | PASS |
| `test_nfi_registry.sh` | **exit 0, = `nfi registry: all tests passed` (= 17 assertions), = at this tip, = at `f834261455`, = at `7fb0885196`, = and at the base `802f1b4703`.** = **⇒ AND IT FAILS WITH 5 (= rows 1b, 1c, 4, 8, 8b) at this branch's OWN `e11b554522`, `7463ed2b13`, and `dfaae87f37`.** = **⇒ The cause is the repository's own table, = not the driver's fixture rows:** = those three commits DROPPED the blank line the driver reads (= the file's tail became "the last row, = then the comment"), = and this branch's own `f834261455` restored it. = **⇒ MEASURE IT IN A THROWAWAY WORKTREE PER SHA, = AND RUN THAT SHA'S OWN COPY OF THE SCRIPT** (= the script derives its root from ITS OWN PATH, = so running the tip's copy against another sha measures the TIP's table) |
| `merge-preflight.sh feature/editor-save-truth` | CLEAN |

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
   commits between the merge base (`a3b3c09a3`) and this branch's pre-fix parent
   (`802f1b4703`). = NOT this change's.
2. **The stack's load-sensitive test failures.** = Pre-existing, = and they
   move between runs (= the failing SET differs run to run), = so they are
   worth their own card rather than a per-card note.
3. **The branch is 24 commits behind `main`.** = The landing is a rebase in
   this worktree, = then the §7 gates re-run on the REBASED tree, = then a
   fast-forward. = **⇒ NOT DONE HERE**, = because the landing needs an
   approving verdict first.
4. **The real library's 6 divergent pairs.** = The guard now refuses the
   content-differing one, = but the 5 whitespace-only ones are still divergent
   on disk. = Reconciling them is the USER's call (= it rewrites their
   documents), = and this change deliberately wrote nothing there.
