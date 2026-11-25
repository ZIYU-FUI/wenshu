# session close: retrieval W2 and W3, and the reader that kept their approvals

Two waves of the retrieval ground landed, and one defect of the landing machinery
itself was found and fixed while landing them. This record states what each wave
was for, what carries each requirement now, what was wrong with the record and
what it cost, and what is still open.

**The server-side proof, per remote** (a tip is stale within minutes, so the
durable fact is ancestry, read back on both remotes):

| scope | commit | `origin/main` (gitcode) | `old-origin/main` (github) |
| --- | --- | --- | --- |
| W2 = the app's own ranking weighs a term by its rarity | `1ca6aba9a45627d5845c40a65c921c3cc3f3e2d4` | ancestor | ancestor |
| W3 = the agent's corpus retrieval, and the merge that fuses both halves | `2bf085aae64ed68e414a23867162deb702084e59` | ancestor | ancestor |
| the reader that binds a lane's approval across a rebase | `6b4c780a641c8218ca0b70897ccde7fa441f8284` | ancestor | ancestor |

Each commit was approved by `wenshu-review` on its own card, and each verdict is
in the field every reader parses: `Tools/wenshu-devtool/review_gate.py` prints
`verdict: approved by wenshu-review` for the card that names the sha.

⇒ **`main` kept moving while this record was under review** (= = three commits landed after the
`1c1b019c2c` this record first named), so the reader is an **ancestor** on both remotes and no
longer the tip. That is the point of the column: **ancestry is the durable fact, a tip is stale
within minutes** — and **the COUNT of the moves is not a fact this record can fix**, because it
re-stales on every amend. Every number below is measured at a NAMED tree, and where the tree is
not this record's own tip, the record says which tree it is.

## The traceability table

Every line is one requirement that was actually asked for, the thing that carries
it now, the independent verdict that cleared it, and the one command that
re-checks it. Nothing here is a plan item restated as a done item.

| requirement, as it was asked | where it lives now | the verdict that cleared it | the command that re-checks it | what it printed |
| --- | --- | --- | --- | --- |
| W2: a term must be weighed by how rare it is, and a document must not be charged for its length | `Sources/WenshuApp/Features/Library/Service/SearchRanking.swift` (`TokenOverlapRanking.corpusStatistics`, `score`) | `t_da4299c4` approved at `1ca6aba9a4` | `swift test --filter RetrievalQualityTests` | library recall@3 `0.83 -> 0.92`, recall@5 `0.92 -> 1.00`, mirror bridge@1 `0.67 -> 1.00` |
| W3: the system index must have a reader, not only a writer | `Sources/WenshuApp/Features/Library/Service/ReferenceCorpusSearch.swift`, the agent's `reference_library` `search` action | `t_6b304a75` approved at `2bf085aae6` (= = and the rounds before it: `t_13225f46` and `t_d86ba9fb` REFUSED it; `t_a3bed0e7` delivered its approval in the field no reader parses (= = item 3 below); `t_37d02f01` approved at `c0959d3bb8`) | `swift test --filter ReferenceLibraryToolSearchTests` | 8 tests in 1 suite, passed |
| W3: the merge must not cost the agent a hit one half already had | `Sources/WenshuApp/Features/Library/Service/ReferenceRankFusion.swift` (it reads RANKS, not scores) | `t_6b304a75` approved at `2bf085aae6` | `swift test --filter RetrievalQualityTests` | union `0.83 / 1.00 / 1.00 / 1.00` against library `0.75 / 0.92 / 1.00 / 0.67` |
| a floor of `0.0` gates nothing, so the floors must hold what the merge measured | `Tests/WenshuAppTests/Library/Search/RetrievalQualityRankers.swift` (`unionBaselineRecallAt1/3/5`) | `t_6b304a75` approved at `2bf085aae6` | the same suite, plus the corpus-first teeth arm | floors are 10/12, 12/12, 12/12; the teeth arm went red on @1 and @3 |
| the row must be its own order, not one half's copy | `Tests/WenshuAppTests/Library/Search/RetrievalQualityTests.swift` (`the union is neither half's order`) | `t_6b304a75` approved at `2bf085aae6` | the same suite | 0 of 12 questions equal either half's order |
| the harness must measure the shape the app runs | `RankerTable.mergeOrders` cuts the index half to `defaultLimit` | `t_6b304a75` approved at `2bf085aae6` | `grep -n 'defaultLimit' Tests/WenshuAppTests/Library/Search/RetrievalQualityRankers.swift` | the cut is in the merge's input; the mirror row keeps its own length |
| the glue list must reach the app's own language, not only English | `ReferenceCorpusSearch.commonCharacters` (48 function characters) | `t_6b304a75` approved at `2bf085aae6` | `swift test --filter ReferenceLibraryToolSearchTests`, both Chinese cases | red at `:167` before the list existed, green with it |
| a term must be held by the tokenizer the ranking scored, not by a substring | `ReferenceSentenceExcerpt.termsHeld` | `t_6b304a75` approved at `2bf085aae6` | the same suite; the table stayed put under the glue arm | `terms.intersection(TokenOverlapRanking.tokenize(text))` |
| every file the wave added must be registered | `docs/agents/nfi.md` rows 740-744 (= = the rows naming the wave's five added paths in THIS tree; = = row 740 names the actor file that hosts one of them) | `t_6b304a75` approved at `2bf085aae6` | `python3 Tools/wenshu-devtool/nfi-loc-check.py --base <the lane's own parent>` | **9 rows checked (5 added + 4 rewritten)**, exit 0 — read in the W3 lane's OWN tree at `c0959d3bb8` against **its own parent `e4818545d7`**. **The base is part of the reading, and so is the tree** (= = the seven pairs under this table) |
| a registry cell must agree with its file, in BOTH cells | `docs/agents/nfi.md` row 704 (prose 305, LOC 573) | `t_6b304a75` approved at `2bf085aae6` | the prose sweep in `wenshu-review-proof/references/gate-blind-spots.md`, over the COMMITTED blobs | 68 rows carry a `(now N LOC` count in their first column; of those, 5 name a short form the tree cannot open (= unmeasured, not clean) and **19 are stale** against the committed tree — **none of them in this change's files** (= = this change's two files are not among the 68, and the row it adds carries no prose count). The 19 belong to other lanes and are left alone here |
| the recall table must say what it does not cover | `docs/adr/0034-the-search-layer-s-split.md`, its last two amendments | `t_6b304a75` approved at `2bf085aae6` | `grep -cn 'own language\|retracted here' docs/adr/0034-the-search-layer-s-split.md` | both present: the fixture is Chinese (59 documents, 12 questions), and the English claim is retracted where it was made |
| **a lane that writes the registry must keep its approval when a rebase moves the registry's rows** | `Tools/wenshu-devtool/review_gate.py` (`lane_edit_id`, `matching_cards_detailed`, `match_lines`) | `t_eb90165d` approved at `6b4c780a64` (round 1 `t_8c54391d` refused it; round 2 `t_e22d6b40` approved) | `python3 Tools/wenshu-devtool/review_gate.py --branch wt/retrieval-w3-agent-corpus-2026-11-24 --sha 2bf085aae6 --main 814d357415` | `t_37d02f01` approved, `matched by relocation` (= the rule that binds it) |
| every match must name the sha it was asked about, the sha it approved, and the rule that bound them | `review_gate.py`'s `match_lines` (three rule lines: `sha`, `change`, `relocated`) | `t_eb90165d` approved at `6b4c780a64` | the same command, and `swift test` free of it | every card carries `matched sha:`, `approved sha:` and exactly one rule line |

**The seven pairs of row 37's reading**, each measured in a clean detached checkout of that tree
with `cd` INTO it (= = the gate resolves its repo from its own working directory, so a run from
another directory measures THAT tree):

| tree | base | what it prints |
| --- | --- | --- |
| `c0959d3bb8` | `e4818545d7` (= = its own parent) | **9 rows** (= 5 added, 4 rewritten) |
| `c0959d3bb8` | `814d357415` | **9 rows** (= 5 added, 4 rewritten) |
| `c0959d3bb8` | `bbc2434997` | 12 rows (= 7 added, 5 rewritten) |
| `2bf085aae6` | `814d357415` (= = its own parent) | **9 rows** (= 5 added, 4 rewritten) |
| `2bf085aae6` | `e4818545d7` | 27 rows (= 14 added, 13 rewritten) |
| `2bf085aae6` | `bbc2434997` | 30 rows (= 16 added, 14 rewritten) |
| this record's OWN tree (at whatever tip it carries) | `origin/main` | 1 row (= 1 added, 0 rewritten) |

⇒ **The reading is the lane's OWN commit against its OWN parent**, and the wider windows carry other
lanes' commits (`bbc2434997` is 3 and 13 commits back, so it swallows the sidebar lane's).

⇒ **⇒ AND THE RULE THIS RECORD NOW CARRIES AS A RULE: a table inside a table renders as junk, so
the record's tables are one table each** (= = the matrix above is its own table, under the
traceability table, and not inside it).

## What the waves got wrong, and what the wrongness cost

Six things, and they are not all the same kind: **two were defects of the code** (the merge
that was a copy of one half, certified by a floor of zero; and the rule whose unit was a line),
**three were defects of the record** (the number read from the wrong file; the verdict
delivered in a field no reader parses; the card body that quoted stale readings), and **one was
a defect of an instrument** (the gate that was never called, whose green could be a null). Each
of them cost a review round. **What cost the W3 lane its approval once already was NOT one of
the six: it was the reader's own whole-diff matching, which is the next section.**
⇒ **The counts in that classification are the author's, not a measurement, and a reader should
check the six items, not the tally.**

1. **A merge that was a copy of one half, certified by a floor of zero.** The union row
   printed the library row's numbers to the digit and every gate stayed green, because the
   floor was a placeholder. A floor that cannot be crossed is not a gate.
2. **A number read from the wrong file.** W3's own ADR said the harness's fixture is
   English, from a grep of the ranker file, which holds models and a table and no corpus at
   all. The fixture is Chinese. The claim reached a card, two digests, a handoff comment,
   and a note in which the reviewer agreed with it, because the assertion was the author's
   about his own measurement. The retraction is in `ADR-0034`; the rule it broke — read the
   file that produces the number — is in `wenshu-retrieval-foundation`.
3. **A verdict delivered in a field no reader parses.** Round 3 recorded `metadata.outcome =
   "approved"` where all five readers require `metadata.review_outcome`, so a sha whose every
   claim an independent reviewer had ticked read `UNREVIEWED` to the landing path. The five
   readers and their line numbers are in `wenshu-review-proof/references/gate-blind-spots.md`.
4. **A card body that quoted two tool readings that were already stale, a number with no
   ruler, and an under-named attribution.** Round 5 found all three. The corrections are
   recorded in true form on card `t_6b304a75` so no later card copies the false readings.
5. **A rule whose unit was a line, applied to files whose records are not lines.** The
   reader's third way to cover a branch drops a keyed table's row movement before comparing
   two edits, so it was written for a table whose records ARE one line each. The string
   catalog is merged by key too, but a record there is a nested object whose value sits on
   a line of its own: trading two values moves those two lines byte-identically, the pair
   cancels, and a TRADED catalog reads as the same edit. The first review round caught it
   (`t_8c54391d`), and it was right: the scope is now the drivers whose records are one-line
   rows (`('nfi-registry',)`), the catalog is out of it, and a case pins the shape so the
   constant cannot be widened silently. **⇒ A rule's unit decides where it may be applied,
   and "merges by key" is not the same question as "the record is a line".**
6. **The gate that was never called, and the null that read as green.** `pre_review_gate.py`
   runs three `ci_change_gate` checks and never invokes `nfi-loc-check.py`, so a stale
   registry cell passed a review round (round 2 blocked on exactly that, from a hand-run
   gate). That gate also measures `os.getcwd()`, so a caller who invokes the right script
   from the wrong tree gets the other tree's green. Its card was `t_67674cf7` (= = **now
   retired**: no such task is in the live board database, so the card no longer names the
   defect); the tree facts behind it still hold (= = `grep -c 'nfi-loc-check'
   Tools/wenshu-devtool/pre_review_gate.py` = 0, and `REPO = os.getcwd()` at
   `nfi-loc-check.py:118` and `pre_review_gate.py:68`). The fix is NOT in this record, and it
   is not in the tree.

## The defect the waves found in the landing machinery

W3's approval was real, and the reader could not read it. The reader matches a branch by
its **change**, and the change was the WHOLE diff. A rebase onto a main that reordered the
registry table left two of main's own rows behind as byte-identical add/remove pairs inside
the lane's diff, so the written lines moved (+4 on either ruler) and the whole-diff hash
moved with them (`bd5fca4aca24` -> `c472c76f02ea`). The lane's own rows were untouched:
14 of its 15 files are byte-identical blobs between the approved sha and the landed one.

⇒ **⇒ ⇒ ANY LANE THAT WRITES THE REGISTRY LOSES ITS APPROVAL ON EVERY REBASE THAT
TOUCHES THAT TABLE.**

The fix adds a third way to cover a branch, and it is deliberately narrow: it drops a
keyed table's row movement, and only there. The strict path is unchanged — `change_id`
still hashes the whole diff verbatim, and the review lane re-derived that against the base
module with 0 mismatches over the branch tips it measured, and found 0 of the local branches'
verdicts moved (= = 0 of 139 at the time of that review). **⇒ The number of local heads is NOT
a number this record can fix**: it moves with every lane (= = 142 when round 5 measured it on
2026-11-25, 145 and 146 later the same morning), so the count that
matters is the one the review measured, and it is dated.

## Open items, carried

- `t_67674cf7` (= = **retired**: the task is no longer in the board database) — the registry's
  row gate is never called by the aggregate battery, and it measures the shell's `cwd` rather
  than the tree that holds it, so a green can be a null. The tree facts still hold; the card
  that named them does not, so the defect is carried here instead.
- **A floor that sits exactly on its measured value.** `RetrievalQualityTests`'s
  "the index half's documents reach the answer" requires the answer to hold a document the
  corpus half's first eight did not, on at least 10 of the fixture's 12 questions, and the
  measured number IS 10. **⇒ A floor that equals its measured value has NO margin: one
  question's worth of difference in the answer's first eight is the difference between green
  and red.** Measured on 2026-11-25, same assertion (`RetrievalQualityTests.swift:224`,
  `questionsWithAnIndexOnlyDocument >= 10`), same tree family, two trees:

  | tree | the single test alone | the three suites together |
  | --- | --- | --- |
  | the merged tree at `6b4c780a64` (= = = 0 files differ under `Sources`/`Tests`; = = the arm ran in THIS closeout worktree, which is what `floor2_mergedA`'s build paths name) | 20 green of 20 | **4 red of 60** |
  | W3's approved sha `c0959d3bb8` | 20 green of 20 | **4 red of 40** |

  ⇒ **The rates quoted are the review's, because a log survives behind them: the review's own
  hardened sampler wrote one line per run to `/tmp/floor2_mergedA/results.txt` (80 lines = 20
  alone + 60 combo) and `/tmp/floor2_approvedB/results.txt` (60 lines = 20 alone + 40 combo), and
  counting the `floor_assertion=yes` lines in those two files gives 0 of 20 and 4 of 60 at the
  merged tree, 0 of 20 and 4 of 40 at the approved sha.** ⇒ **⇒ AND THE LOGS SURVIVE WHERE THE
  TREES DID NOT: the tree that arm actually ran in — the review's own scratch checkout at
  `/Volumes/ANAN/.hermes/profiles/wenshu-review/cache/scratch/t-f30a4741/w3-approved` — is gone,
  so re-deriving that row needs a FRESH detached checkout of `c0959d3bb8`** (= = which is what a
  later review did, and it got 4 red of 20 at that sha = = the same kind of number, a smaller
  sample). The log is the evidence; the tree it was run in is not. **⇒ AND THE W3 LANE'S OWN
  WORKTREE IS NOT GONE**: `.worktrees/retrieval-w3-agent-corpus-2026-11-24` still stands at
  `2bf085aae6`, clean, and clean detached checkouts of `c0959d3bb8` exist — so it is the scratch
  tree that vanished, not the lane.
  An earlier round's rates (= = 3 of 43 and 3 of 42) are **not** quoted, because they do
  not reconcile with the logs that survive; a rate whose denominator cannot be re-derived
  from a log is not a rate. This record's own, smaller, author-only sample agreed in kind
  (= = 2 red of 8 and 1 red of 8) but kept no log, so it is not quoted either.
  The review's detector was calibrated by a PLANTED red (= = raising the floor to 11 makes
  every run red — **6 of 6 (3 alone + 3 combo) red**, logged at
  `/tmp/floor2_planted/results.txt` (6 lines) — so the detector is proved to catch a red
  rather than merely report one), and its forced-print arm measured the count itself
  moving between 9 and 10.

  ⇒ **⇒ ⇒ IT FAILS AT BOTH TREES, so it is NOT caused by the reader change (= = which
  touches no Swift file at all, and **no file under `Sources`/`Tests` has changed since
  `2bf085aae6`** (= = a probe file under `Tools/` was deleted by a commit that landed on
  `main`, so the unbounded "no `.swift` differs" would be false = = the argument needs the
  bounded form, and the bounded form is the one that is true).** It is a
  pre-existing condition of the W3 lane's own floor, and it is red on `main` today: the
  perturbation is the answer's own first eight differing by one document between runs, and
  the floor has no room for that. It wants a card of its own (a floor with margin, or a
  measurement that does not sit exactly on its own floor).

  **⇒ CLOSED** on `wt/retrieval-floor-margin-2026-11-25` (card `t_88ed3915`). = The floor reads
  the index half's own documents now, = and it has margin: = three readings, = = "the answer holds
  a document the index half ranked in its own first eight" (= at least 10 of the fixture's 12
  questions), = = "the answer holds a document the index half named that the corpus half did not
  rank in its own first six" (= at least 10 of the 12 questions; = = a merge that keeps the corpus
  half's order reads 9), = = and "at least 82 of the fixture's 96 answer slots hold a document the
  index half named" (= measured 87; = = a corpus-order merge reads 76).

  **⇒ AND THE PERTURBATION'S CAUSE IS MEASURED, = = AND IT IS NOT THIS CARD'S TO FIX.** = The
  corpus half's own order is not the same in every process: = its seventh and eighth slots swap
  between runs (= the fixture's two documents of nearly equal score), = because the score is summed over a
  `Set`'s iteration order, = and Swift gives every process its own hash seed. = The old
  measurement's boundary sat exactly on that swap. = **⇒ The score's own accumulation is
  production code, = = and the card that reads the index half does not touch it, = = so the order
  that moves between processes is the next open item below.**
- **An order that is not the same in every process.** = The library's own ranking sums a document's
  score over the iteration order of a `Set` of query tokens, = and Swift gives every process its
  own hash seed, = so two documents of nearly equal score can swap places between two launches of
  the app. = Measured 2026-11-25 in the retrieval fixture: = the corpus half's seventh and eighth
  slots swap (= the fixture's two documents of nearly equal score), = while the index half's own order does not move. = **⇒
  ⇒ ⇒ THE USER SEES THE LIST SHUFFLE**, = = and the ranking's own tie-break (= the title) never
  fires, = = because the scores differ in their last bits before the tie-break is reached. = It
  wants a card of its own, = = and the floor's card did not write it.
- A Chinese fixture arm for the fragment step: the harness measures the ranking and never calls
  `ReferenceCorpusSearch.search`, so the glue list and the held-term rule are held only by the two
  Chinese cases in the tool's own suite.
- The recall the real system index adds (documents the app indexed in an earlier session) is
  unmeasured, because the harness reads no system index. The lane says so rather than implying it.

## Gate set, at the merged tree (`6b4c780a64`)

`swift build --build-tests` rc 0. `ReferenceLibrarySearchTests` 12,
`ReferenceLibraryToolSearchTests` 8, `RetrievalQualityTests` 17, and the run recorded above is
**NOT all green**: `/tmp/closeout-measure.log` prints `Test run with 37 tests in 3 suites failed
after 0.662 seconds with 1 issue` — the one issue is `the index half's documents reach the answer`
(= = the floor of the open item below), so **36 of 37 passed and the failing suite is the very
suite whose table this section pastes**. The harness still printed its own table (= = copied from
print, `/tmp/closeout-measure.log`; the digits are the claim, and **all 9 of the table's
lines are byte-equal to the log's**):

```
  retrieval quality over 59 documents (19 answering, 40 noise) and 12 questions

  ranker                  recall@1  recall@3  recall@5  bridge@1 bridge@3
  wenshu-library          0.75  0.92  1.00  0.67  1.00
  wenshu-mirror           0.83  1.00  1.00  1.00  1.00
  wenshu-union            0.83  1.00  1.00  1.00  1.00
  bm25-character          0.83  0.92  0.92  1.00  1.00
  bm25-bigram             0.83  0.92  0.92  1.00  1.00
  bm25-apple-word         0.92  1.00  1.00  1.00  1.00
  bm25-bigram+title       0.83  0.92  0.92  1.00  1.00
  bm25-apple-word+expander  0.42  0.67  0.75  0.00  0.33
```

The reader's own suite: **182 cases**, the nineteen `R:` cases among them, `every case passed`.
⇒ The count was read in the reader's own worktree at the landed tip `6b4c780a64` (= = the same
182 and 19 come out of the suite at this closeout's tip, because the reader's two files are
byte-identical between them). `ci_change_gate --check formatting|pollution|loc-cap|markdown-newline`
rc 0; `nfi-loc-check` rc 0 (1 row checked = this file's own count). **The comment-lineage gate
printed `0 offending rows / 0 files` on this change, and that green is NOT a pass on the rule:
it says so itself (= = "nothing was measured, so this is not a pass on the rule"), because a
docs-only window adds no comment line for it to judge.**
