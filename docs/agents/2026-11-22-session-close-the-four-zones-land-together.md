# Session close 2026-11-22: the four zones' slow loads land together, and the record of why the landing was almost blocked on a sentence

Scope: the boss's instruction of 2026-11-21 (= "solve, at the root, all the slow-loading
problems in the asset column, the right column, the editor and the chat area; if one session
cannot finish it, phase it"; "keep pushing to completion, verify it yourself, I am away from the
machine"), and on 2026-11-22 his two closing instructions, recorded in English here because rule
1.1 keeps this file English: the review is finished, and the standard eight-step closeout runs
with no further review round opened.

Base both halves of the range: `origin/main` = `10ef4216be88cbaee9ec76660e4f40d1d88151c0`.
The five lanes landed onto local `main` as `3c9747b63a368cab4fa9032872eda51e1e39dee0`,
20 commits ahead of the remote, lanes landed cheapest-first, each rebased onto `main`'s
then-current tip and fast-forwarded only after its own gates.

**`main` moved again while this closeout was being measured.** A sibling session landed its
record rewrite as a merge, and the tip this doc was measured against is now `13c32282d0`,
25 ahead of the remote. The check is per push, and it is two commands:

```bash
cd /Volumes/ANAN/Engineering/wenshu
git rev-list --count origin/main..main
git log --oneline --format='%h %an %s' origin/main..main
```

The 20 commits in `3c9747b63a`'s history are this scope's. The 5 that are **not** this scope's,
and that the push will nevertheless carry, are the sibling session's record-rewrite line
(`942631a205`, `05d12262f0`, `457390fa27`, `511c1149a9`, and the merge `13c32282d0` itself).
Pushing them is maintenance of the shared server state, not authorship; they are named here so a
reader of the landing table knows which rows belong to whom.

| zone | lane | commits it contributed | range on `main` | lane head | approving card |
| --- | --- | --- | --- | --- | --- |
| chat area | stream identity | 1 | `10ef4216be..59a02f37b5` | `59a02f37b5` | none at code level |
| editor tabs | active-tab switch | 2 | `59a02f37b5..53749d9612` | `53749d9612` | `t_c1d137c5` |
| editor scroll | scroll settle | 3 | `53749d9612..a20b7284d3` | `a20b7284d3` | `t_f49ed531` |
| asset column | cover reads | 5 | `a20b7284d3..bfa90cdeab` | `bfa90cdeab` | `t_b39e2ea6` |
| right column | announce instead of poll | 9 | `bfa90cdeab..3c9747b63a` | `3c9747b63a` | `t_19781743` |

`1 + 2 + 3 + 5 + 9 = 20`, which is the count `git rev-list --count origin/main..main` prints at
the tip before this doc's commit, and it is how the table is checked rather than trusted.

## 1. The root cause the four zones share

The four zones do not have four performance bugs. The app has no "a write happened, so a view
knows" path, and each zone pays a different compensation for the missing path:

| zone | the compensation it was paying | what landed instead |
| --- | --- | --- |
| chat | every streamed token re-evaluated the whole transcript, and a collapsed thinking block re-opened whenever the row was rebuilt | one segment per part with a stable part identity; the block's openness lives on the part (`59a02f37b5`) |
| editor tabs | a tab switch wrote to `UserDefaults` inside its own frame | the write left the frame (`e22adb8151`) |
| editor scroll | each scroll tick re-ran layout from the document head | the tick settles at the viewport inside a generation-stamped band (`199b7cd0a9`, `7a6f8f5896`) |
| asset column | a card scrolling into view asked the disk for its cover, and asked which library it was drawing in, once per card, on the main thread | covers answer from memory, the covers folder resolves once per pass off the main thread, both grid doors covered (`f0d9e34f3e` … `1524aa569f`) |
| right column | two one-second polling loops | the writer announces, the reader subscribes (`333bd6076a` … `5bc1a895db`) |

Apple's own wording is the spine of all five: "An async sequence of snapshots of partially
generated content" for the stream, "Rely on previously prepared data in draw(_:), don't perform
I/O or complex calculations in this method" for the column, and "don't depend on view state for
data that needs to be kept alive after scrolling" for the collapse and the scroll tick.

## 2. What actually blocked the landing was a sentence, not a merge

Every lane rebased onto a moved `main` without a conflict, and the merged tree built and passed
its suites on the first try. What stopped the push was a claim I wrote on a card.

`review_gate.py --branch` refuses all five landed heads. I read that refusal as "this code has
never held an approving verdict", put that sentence on a decision card, and handed the boss a
three-option choice built on it. **It was wrong, and the measurement that disproves it is short:**

| lane | approving card | sha that card APPROVED | commits sitting above it inside the lane | executable lines those commits change |
| --- | --- | --- | --- | --- |
| tab switch | `t_c1d137c5` | `dc3f39e52b` | 1 (`fd4452e7a8`) | **0** (+26/−26, comment text only) |
| editor scroll | `t_f49ed531` | `28283fb39f` | 1 (`75d7b29d36`) | **0** (+9/−9) |
| cover reads | `t_b39e2ea6` | `476aaa7aba` | 1 (`8a2a6ef989`) | **0** (+80/−80) |
| right column | `t_19781743` | `7c8d3e819f` | 1 (`2c1172fd64`) | **0** (+10/−10) |
| chat stream | no approving card | round 6 `t_486d9475` at `64c8d6814e`, changes_requested | the charge it named was the comment-lineage gate | **0** — `64c8d6814e` to the landed head is +313/−341 `.swift` lines with zero non-comment lines changed |

Four lanes carry a code-level APPROVED verdict. Each sits one comment-text commit above its
landed head, and the rebase moved the sha, which is the only thing the gate looks at. The fifth
lane's open blocker was the comment-lineage charge, and the merged tree passes that gate.

**The gate answers a narrower question than the one I asked it.** `review_gate.py --branch`
reports whether a review card *names the exact sha* the branch is at. After a rebase no card can
name it, so the answer is "no" for a verdict that exists. Reading that as "no verdict exists" is
the same class of mistake as reading a usage line as a measurement, which this session committed
twice and retracted twice.

**The range that misled me, so nobody reuses it.** To ask "what does this verdict not cover", the
span is `approved sha .. that lane's own pre-rebase tip`. I first used `approved sha .. landed
head`, and a landed head carries the *earlier lanes'* commits as well, so the answer came back
with another lane's executable code (tab reported `non-comment +493`) and looked like uncovered
work. The lane-isolating span reports 1 commit and 0 executable lines.

## 3. Rebase fidelity: what the approvals still cover after two rebases

The lanes were rebased twice (once onto `437eb698bf`, once onto `10ef4216be`). For every landed
commit, the written lines of `git show` (every `+`/`-` line, context excluded) are compared with
the reviewed commit it came from:

```bash
cd /Volumes/ANAN/Engineering/wenshu
PAIR="3eea152944 f0d9e34f3e"   # the one the two rebases moved: reviewed, then landed
set -- $PAIR
diff <(git show $1 | grep -E '^[+-]' | grep -vE '^(\+\+\+|---)') \
     <(git show $2 | grep -E '^[+-]' | grep -vE '^(\+\+\+|---)') \
  && echo "written lines identical: $1 and $2"
```

Across the 21 reviewed commits in the window, 20 are byte-identical on this comparison. The one
that is not is the cover lane's lineage commit (`3eea152944` reviewed, `f0d9e34f3e` landed): its
1,285 written lines are identical and exactly 2 *context* lines differ, because `main` rewrote
the neighbouring doc comment between the two bases. Context lines are what the base supplies, so
they are the rebase working, not the edit being lost.

## 4. Gates and tests, all read on the merged tree at `3c9747b63a`

The invariant, stated instead of published as numbers: every gate below exits 0 over
`10ef4216be..main` on the tree the reader stands on, and the registry's LOC cells equal the line
counts of the files they name on that same tree.

```bash
cd /Volumes/ANAN/Engineering/wenshu
python3 Tools/wenshu-devtool/comment_lineage.py --base 10ef4216be --head main
for c in pollution formatting markdown-newline loc-cap; do
  python3 Tools/wenshu-devtool/ci_change_gate.py --base 10ef4216be --check $c
done
python3 Tools/wenshu-devtool/nfi-loc-check.py --base 10ef4216be
```

Readings taken at the tip this doc was measured against (`13c32282d0`): lineage
`offending: 0 rows / 0 files` over 2,469 added comment lines; the four change gates rc=0;
`nfi-loc-check` rc=0 over 22 rows. `swift build --build-tests` on the five-lane merge returned
`Build complete!` with rc=0 (60.04 s), and both test commands below exited 0.

The five lanes' suites, which live in two packages, and the reason a single `swift test` filter
silently under-covered them:

```bash
cd /Volumes/ANAN/Engineering/wenshu
swift test --filter 'ChatStreamIdentityTests|ActiveTabSwitchPersistenceTests|CoverDiskReadTests|CoverLibraryLookupCountingTests|CoverHotPathShapeTests|InspectorRightColumnPushTests|AsyncDelegationChangeSignalTests'
cd Vendor/MarkdownEngine && swift test --filter ScrollLayoutSettlementTests
```

`ScrollLayoutSettlementTests` is in the `Vendor/MarkdownEngine` package: a filter run from the
root package does not select it and reports success anyway. A filter that matches nothing also
reports success, so the number of suites exercised has to be read from the run's own
`Suite "…" passed` lines rather than inferred from the exit code.

## 5. The two process faults this landing produced, and what they cost

**Moving `main` under a live run.** `t_3bb0aeed`'s run 4829 started at 23:42:00 and the five
fast-forwards moved `main` at 23:45:20. My "nothing is running" check had been taken ten minutes
earlier. The check has to be re-taken at the moment of the merge, not at the moment of the
decision: `SELECT task_id FROM task_runs WHERE outcome IS NULL` joined to `tasks.status`.

**Publishing an unproven negative.** A decision card that says a thing does not exist is a claim
with the same burden as a gate output. The correct form was the span in §2, which takes one
command per lane, and which I should have run before writing the sentence rather than after.

## 6. Open items this closeout leaves, and who owns them

| item | state | owner |
| --- | --- | --- |
| the push of `main` at this tip | the boss's own step, and the one thing this scope cannot do without him | `t_781e32bb` |
| asset column cold-open: the first screenful still asks the disk inside the render body | card written, tier checked, unclaimed | `t_833e98d9` |
| four landed instruments have teeth but no committed suite | card written | `t_0cdf0000` |
| `merge-nfi-registry.py` silently drops an unbackticked-key row | card written | `t_274cdbe7` |
| the registry merge driver is declared in `.gitattributes` and not wired in this machine's `.git/config` | needs a human decision | `t_8da639db` |
| shared skill files over the 100,000-character cap | needs a human decision | `t_9a40ea5f` |

## 7. Where this round stops

This closeout lives on the board: the landing evidence is the comment on `t_872bbafb`, the
correction of §2 is the body of `t_781e32bb`, and the doc does not log its own review history.
A reader who wants the verdict reads the cards, which carry their timestamps and authorship; a
reader who wants the substance reads the table above, which is reproducible with the commands in
§2 and §4 on the tree they are standing on.
