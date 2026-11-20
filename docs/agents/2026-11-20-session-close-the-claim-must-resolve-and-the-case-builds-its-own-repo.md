# Session close 2026-11-20 (part two): the eight-step closeout's derived lines, a claim that has to resolve, and a test that stopped borrowing a repository

This document closes the SECOND half of the session: the eight-step closeout of the
style-table / custom-preset stack, and the three lines of work that closeout spawned after
its own document had already been reviewed and landed. It ships zero Swift bytes, so the Swift
build and suite are out of scope by AGENTS.md §1.3 and are stated as out of scope rather than
run and quoted empty.

## 1. The scope

Six commits, all on `main` now, all verified by `git merge-base --is-ancestor <sha> main`
returning rc 0:

| line | landed as | what it was |
|---|---|---|
| the landing gate's scope | `5cd1037d13` | the gate read a card's sha from its claim, not from one heading |
| the gate's own comments | `38d656a52c` | the gate's docstring keeps the invariant and lets the card keep the count |
| the doc's self-count and its fence | `4afeb8e41d` | the closeout doc's registry count and the red case for its third rule |
| the claim guard (the belt) | `0f9fcb6d41` | a card's stated sha must resolve as a commit before it may govern one |
| the pin clause | `81b617925b` | the doc's sweep sentence scoped to the one subject that needs a pin |
| the ordering case's own fixture | `8b75e70306` | a test case stopped reading `git rev-parse HEAD` from wherever the suite was launched |

The first four were the closeout itself; the last two are what the closeout's review rounds
spawned, and they are the reason this second document exists: a closeout record can be
approved and still leave a defect class in the tools it describes.

## 2. The trace table (= one line of the boss's own words per row)

The boss's lines are translated; the tracked artifact stays English per AGENTS.md §1.1.

| what was asked | what it became | the commit that carries it | the independent verdict | the server proof |
|---|---|---|---|---|
| "run the eight-step closeout" | the closeout doc plus its own review round | `4afeb8e41d` | `t_c87eb0cc` approved, round 4 | `ls-remote` read `4afeb8e41d` on both remotes at landing |
| "the record's count has to be its own, not a guess" | count and registry row changed in one commit, plus the fence that prints a red case | `4afeb8e41d` | the same verdict, bound by `change_id 626e2987d655...` | re-read at the replayed tip |
| "the sentences that call something `main` were really calling a moment" | the pin clause and the two dated phrases | `81b617925b` | `t_7307ebaf` approved, bound by `change_id 9eb479edd3d2...` | both remotes read `81b617925b` |
| "does a card's stated sha have to be a real commit?" (found by the reviewer, not asked) | the claim guard in the authority path | `0f9fcb6d41` | `t_b8761941` approved, bound by `change_id c691e10bd153...` | both remotes read `0f9fcb6d41` |
| "then the test that borrows a commit from the directory it was launched in" | the ordering case's own temporary repository | `8b75e70306` | `t_d4599c53` approved | both remotes read `8b75e70306` |
| "I looked at it, that is fine" (the body text centred between the two dashed separators) | the open item closed as accepted | no commit; acceptance of what `9628b3b133` shipped | the boss's eyes are the gate here, AGENTS.md §7.7 | recorded in §5 below |
| "have you actually finished the eight steps?" | this document, and the gates re-run on the merged tree | this commit | this doc's own card | recorded after landing |

## 3. The identities, because shas move

A rebase rewrites the sha and not the edit, so every landing above is bound to content, not to
the literal sha the reviewer named. Read them back with:

```bash
cd "$(git rev-parse --show-toplevel)"
for pair in 0f9fcb6d41:4afeb8e41d 81b617925b:6336bc08d4 \
            8b75e70306:90f31ed413 4afeb8e41d:38d656a52c; do
  s=${pair%%:*}; b=${pair##*:}
  both=$(/usr/bin/python3 -c "
import importlib.util, sys
from pathlib import Path
spec = importlib.util.spec_from_file_location('rg', Path('Tools/wenshu-devtool/review_gate.py'))
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
sha, base = sys.argv[1], sys.argv[2]
print(m.change_id(sha, base), m.change_id(sha))" "$s" "$b")
  named=${both%% *}; dflt=${both##* }
  printf '%s  base=%s -> %s\n      same sha, base=main -> %s\n      patch-id=%s\n' \
    "$s" "$b" "$named" "$dflt" \
    "$(git diff "$b".."$s" | git patch-id --stable | cut -d' ' -f1)"
done
```

The base is printed beside every value because the value IS a function of it. The second line of
each row above is the same command with the base left out, and it answers `None` for all four:
`Tools/wenshu-devtool/review_gate.py:325` declares `change_id(sha, main="main")`, `:355` takes
`base = _merge_base(main, sha)`, and for a sha that has already landed that merge base IS the
sha, so `git diff base..sha` is empty and `:363` returns `None` - the function's own docstring
states it ("None when the sha carries no change at all"). This section's first draft published a
fence built exactly that way, and the reviewer's run read `change_id=None` three times against
the table below. The table's values were real and had been measured against the then-`main`, so
the fix was the command and not the numbers, and the row that names the base for
`4afeb8e41d` is the proof that naming it is not cosmetic: with its literal parent `c4d2c45d34`
the same function answers `5a89b98d1cb03bd0a8c1b0780727ec6a418d49d9013c8cddd34dc4509b4170cc`, a
different identity for the same landing, because the branch had been rebased onto another lane
before it landed.

| landing | the base the identity was taken against | `change_id` | `git patch-id --stable` over that range |
|---|---|---|---|
| the claim guard | `4afeb8e41d` | `c691e10bd1532d7c3db7f99212e82239b0038484b417508ce56508b9982d5038` | `b747ee60af6d508ba26b92a3cc35950972eb4d4d` |
| the pin clause | `6336bc08d4` | `9eb479edd3d25ff7f44231c5af683a3fb1ccc8bfa5e0897cde4e018d9834ff48` | `ff916f0f3fee2e227be3774bd287219ec2456533` |
| the ordering case | `90f31ed413` | `aa922e68f571551bf88c24d3a9c8905e98c63ff5f1119a1e4a4cee8cd1743bf8` | `f0ba983bf3ea76377c2d16924f88eb4d27f3f64b` |
| the doc's self-count round | `38d656a52c` | `626e2987d6552d8b8d360397baac0fc18971fbd8d52cfdb2db8b67ca57de0043` | `401db914d1b94fb1168b6b6b782662100e6dbcf2` |

`change_id` is a sha256 over the change body and NOTHING else: the diff is taken with `-U0`, the
hunk headers are dropped so line numbers cannot count, the text-file `index` lines are dropped,
and the +/- lines are kept verbatim (`Tools/wenshu-devtool/review_gate.py:336-370`; the encoding
back to bytes happens at `:369`). No message of any kind enters it - neither the subject nor the
body. The first draft of this section claimed the opposite ("folds the patch-id and the commit's
SUBJECT line, so a subject rewrite voids the verdict"), and that sentence was tested false by the
reviewer and re-tested false here. Measured in a scratch `--no-local` clone of `main`, with the
known control asserted first and the scratch removed afterwards:

```bash
C=$(mktemp -d)/clone
git clone -q --no-local --single-branch --branch main . "$C"
git -C "$C" checkout -q -b arm 8b75e70306
cid() { ( cd "$1" && /usr/bin/python3 -c "
import importlib.util
from pathlib import Path
spec = importlib.util.spec_from_file_location('rg', Path('Tools/wenshu-devtool/review_gate.py'))
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
print(m.change_id('HEAD', 'HEAD^'))" ); }
pid() { git -C "$1" show HEAD | git patch-id --stable | cut -d' ' -f1; }
echo "control (arm 8b75e70306) : $(cid "$C")  $(pid "$C")  sha $(git -C "$C" rev-parse --short HEAD)"
git -C "$C" commit -q --amend -m "$(git -C "$C" log -1 --format=%s | tr 'a' 'A')"
echo "arm A subject re-cased   : $(cid "$C")  $(pid "$C")  sha $(git -C "$C" rev-parse --short HEAD)"
git -C "$C" commit -q --amend -m "$(git -C "$C" log -1 --format=%s)" \
    -m "$(git -C "$C" log -1 --format=%b)
A line appended to the message BODY only."
echo "arm B body appended      : $(cid "$C")  $(pid "$C")  sha $(git -C "$C" rev-parse --short HEAD)"
rm -rf "$(dirname "$C")"
```

All three rows print the same `change_id` (`aa922e68f571…`) and the same patch-id
(`f0ba983bf3ea…`), and the `sha` column is what moves: a subject-only amend and an amend that
touches only the message body both re-stamp the commit while leaving the bound identity alone. The
shas are deliberately not written down as literals - every re-run re-stamps them, so a literal in
prose is a value no reader can match (that was round 2's minor red). So a message-body fix and a
subject rewrite are both safe against a bound verdict; what voids a verdict is editing an added or
removed line. **The mutation that makes this block red: change one `+` line of the change and
re-run it** - the identity moves, and the arm that cannot fail to move it is not testing the
identity.

**The subjects the reviewers named are pre-rebase, and a fresh clone cannot read them.**
`1e8589b22f`, `b2f6ec4b9f`, `7c8cd1f5f6` and `1376a8de3d` resolve in this clone only because it
holds `review/*` pins; a clean clone of `main` answers rc 128. That is not a defect and this
document does not ask the reader to take that on trust:

```bash
git for-each-ref --format='%(refname:short)' refs/heads/review | wc -l
D=$(mktemp -d); git clone -q --no-local --single-branch --branch main . "$D"
git -C "$D" for-each-ref refs/heads/review | wc -l
git -C "$D" cat-file -e 1e8589b22f^{commit} 2>/dev/null; echo "pre-rebase subject rc=$?"
git -C "$D" cat-file -e 0f9fcb6d41^{commit}; echo "landed subject rc=$?"
```

The second answer is 0 refs, the third is rc 128, the fourth is rc 0. **The mutation that makes
this block red: run it in a clone made WITHOUT `--no-local`.** A local-path clone copies the
object store whatever the link flag says, so the pre-rebase subject reads rc 0 there and the
block's whole point disappears.

## 4. The gates, on the tree this document names

No Swift file and no test-of-the-app file is in this scope, so §7.1 and §7.2 are not run and
are not quoted: AGENTS.md §1.3 exempts a one-file `.md` or `.py` ticket that ships no Swift
bytes, and says the reason belongs in the commit message. What was run, and what it answered:

| command | answer |
|---|---|
| `python3 Tools/wenshu-devtool/ci_change_gate.py --base main --check pollution` | exit 0, no forbidden vocabulary |
| `... --check formatting` | exit 0, `0 changed Swift file(s)` |
| `... --check markdown-newline` | exit 0 |
| `python3 Tools/wenshu-devtool/nfi-loc-check.py --base main` | run on the COMMITTED range at this tip it answers `every added or rewritten file's row carries its own count (1 row(s) checked: = 1 the change added, = 0 whose named file the change rewrote and did not add)` and exits 0 - that one row is this document's. Run the same command BEFORE the commit exists, with the row sitting in the working tree, and it answers `the change adds no registry row and rewrites no registered file; nothing to check` and exits 0 anyway (measured at `b96d3f7cb5` in a scratch `--no-local` clone, `:203`), because the row set is read with `git show HEAD:docs/agents/nfi.md` against the base's blob (`nfi-loc-check.py:97-103`). The count itself is read from the file ON DISK (`:173-175`) while the row is read from HEAD, so the two agree only on a clean tree - which is why §10's invariant is checked after the commit and from the tree you stand on |
| `python3 Tools/wenshu-devtool/review_gate.py --card <this doc's card>` | must read `approved` (exit 0) before the merge. `--branch <branch>` answers a DIFFERENT question and does not carry the verdict: it exits 0 whenever some review card names the tip, whatever that card decided, and 3 only when nothing names it (§9 publishes both paths, measured) |
| `bash Scripts/merge-preflight.sh <branch>` | must read `CLEAN`, and it prints on its own that a rebase rewrites the sha but not the edit |
| the three tool suites: `test_review_gate.py`, `test_card_sha.py`, `test_pre_review_gate.py` | `review_gate: every case passed`, `ok: 14 cases passed`, `22/22 cases passed` |

Every one of those was read out of the command's own printed line, not out of a pipeline
status. The discipline that produced this row is the reason the last two lines exist: the
reviewer of the claim guard re-ran his mutation arms and reported **163** case names at the
base and **163** at the tip, which is a count of the witnesses rather than a green status.

## 5. The boss's own look

The open item left by part one of this session was a visual claim: the body text sits
vertically centred between the two dashed separators in the style page. The boss looked at the
running app and answered that it is fine. That is the gate AGENTS.md §7.7 asks for, and it is
recorded here as accepted.

What was actually on screen, as far as this session can prove: `build/Wenshu.app` was running
as pid 81467 for 50 minutes at the time of the verdict, and the binary's mtime is
`2026-11-20 15:34:40`. The newest commit at that moment was `90f31ed413` (15:26:15), so the
build is consistent with carrying the whole style-table and tab-control scope. This is an
inference from mtime, NOT a provenance proof: the bundle carries no embedded 40-hex string
(`strings -a .../WenshuApp | grep -E '^[0-9a-f]{40}$'` prints nothing), so nothing on the running
app names the commit it came from. That gap is an open item in §7 rather than a claim here.

## 6. What this round got wrong, in the order it was caught

1. **A published command that no clone can run.** The closeout doc's §9 sweep took its subjects
   from pre-rebase commits. The fix (`81b617925b`) names the pin in prose rather than softening
   the command: a sweep that skips a subject it cannot read is a decoration, and the loud
   `blob not read` death is what the section argues for.
2. **A test that read the environment.** The claim guard needed a real commit in its ordering
   case and took one from `git rev-parse HEAD` in the current working directory, so the case's
   verdict depended on where the suite was launched (measured: rc 1 with exactly three named
   failures from a directory inside no repository, rc 0 inside a worktree). Fixed in
   `8b75e70306` by the file's own idiom - a temporary repository, one commit, `os.chdir` in and
   out - and re-armed afterwards: deleting the guard still reddens exactly one case, and
   re-dating `_verdict_time` from all runs still reddens exactly the two ordering checks with
   the same got/want values as before the rewrite.
3. **A false claim about an artifact, made by this session.** The note said a published probe
   script no longer matched its published hash. `stat` and `shasum` answered the opposite: the
   file was untouched, its mtime was nine minutes BEFORE the landing, and the reviewer had
   verified the very bytes. What had been edited was a scratch copy with a similar name. The
   rule that came out of it: before publishing that an artifact drifted, `stat` it and hash it
   in the same turn.
4. **A citation the tree cannot answer, invented in a card body.** The body told the reviewer to
   run "RULES 1-10 (`Tools/wenshu-devtool/DESIGN_RULES.md`)". Nothing by that name exists: not
   tracked, never added by any commit, and the string appears in no tracked file and no skill
   file. The ten gates are AGENTS.md §7.1-§7.10. Because a dispatched card body cannot be
   edited, the phantom could only be corrected by the reviewer.
5. **Arms run after the push instead of before it.** The verdict asked for the outside-cwd arm
   and both mutation arms to be re-run on the replayed tip. The identity was checked, the merge
   and push happened, and only then was that sentence read. The arms matched, so nothing broke,
   but identity equality proves the edit survived a replay; the arms are what prove the replayed
   tree still contains its witnesses.
6. **A filtered push that hid a failed push.** `git push old-origin main` was piped through a
   `grep`, which swallowed both the output and the failure; `git ls-remote` read the old sha.
   Re-pushed unfiltered, read back: the remote moved. The read-back is the proof, the output
   line is a hint. Each item above carries what the measurement said, because a list of mistakes
   without readings is a confession rather than a record.
7. **This document's own read-back fence could not read back** - caught by the review of this
   document, in the section whose whole job is the read-back. `change_id` was called without its
   base, and the default base is `main`, so against a landed sha the range is empty and the answer
   is `None`: the fence printed `None` three times next to a table of real values. The general
   shape of the defect is not git-specific: **a published command inherits its arguments from a
   moving ref, so running it is only a read-back if the moving part is pinned in the command
   itself.** §3 now prints the base beside every identity and shows the default-base arm beside it.
8. **A mechanism sentence stated from memory instead of from the code.** It said `change_id` folds
   the patch-id and the subject line, which would have licensed the rule "never rewrite a commit's
   subject after a verdict". The function hashes only the `-U0` change body, so that rule is false
   and the real rule is narrower: edit a `+` or `-` line and the verdict is void, change the
   message however you like and it is not. Both arms are published as a runnable fence in §3 now,
   with the control asserted before the mutation. The same round also caught §9's starting-point
   fence carrying a literal `<branch>` placeholder, which exited 2 the moment it was executed as
   written: a fence with a hole in it is prose, not a command, and this document has no business
   making that argument about other people's artifacts while committing it itself.

## 7. Open items this round left behind

- **`_same_sha` is still symmetric.** An honest full claim still answers a query that is that
  claim plus trailing junk. Ruled non-blocking by the reviewer of `0f9fcb6d41`: the landing path
  cannot produce such a query. It is open, not dismissed.
- **`nfi-loc-check.py` read only the rows the range ADDS. That is closed, and not by this lane.**
  The sibling lane landed it while round 2 was under review (`a7e900d0b1` through `b96d3f7cb5`, card
  `t_12126d87`, board status `done`), so the gate now reads added keys UNION the keys whose named
  file the change rewrote (`nfi-loc-check.py:97-148`), and the rewrite half is measured with a
  THREE-DOT diff so a branch sitting behind `main` is not charged for a row `main` itself corrected.
  Two facts the new tool owes its reader, both read off the code and not off its summary line: the
  row set comes from `git show HEAD:docs/agents/nfi.md` against the base's blob (`:99-102`), so a row
  that lives only in the working tree is still invisible to it - the vacuity §4 publishes is about
  exactly that; and the file's own count is read from DISK (`:173-175`) while the row is read from
  HEAD, so the two can only agree on a clean tree. The stale-by-design rows its docstring counts
  (**92** today) remain nobody's check, and that is correct by definition: the registry header
  declares the column a snapshot at the tree the row was written on.
- **The app binary carries no commit provenance** (§5). A `--version`-style stamp that
  `strings` can read would turn the §7.7 provenance sentence from inference into fact.
- **Worktree residue.** `git worktree list | wc -l` is a published count only as a command to
  run, never a number here, because the number changes with every sibling lane. Removing them is
  a decision the boss has not made, and none of it is safe to sweep with a wildcard: only a
  worktree whose branch is merged AND whose card is done should ever be pruned, and `git
  worktree prune` fixes the registry, not the disk.
- **`wenshu-review-proof/SKILL.md` is over the `skill_manage` 100,000-character ceiling**, so any
  patch to that one file fails and ROLLS BACK every other write in the same batch. Read it with
  `wc -m <path>`; the consequence is that this skill's lessons can only be written into its
  `references/` files until that file is split.
- **`hermes kanban dispatch` still reports `Spawned: 0` for a fresh card** and the gateway's own
  dispatcher picks it up; `dispatch_in_gateway` is true in the root config and false in the
  pocock profile, and the effective value is frozen at gateway start. A restart has not happened.

## 8. The commits this session pushed that are NOT this session's

`main` moved under this work twice over. These are sibling lanes, and this session touched none of
their files:

| sha | what it is |
|---|---|
| `6336bc08d4` | the column switchers' own tab control (a merge) |
| `f0cfb871dd` | that scope's closeout doc |
| `fa6b66db5f` | the registry's merge driver, the TAIL three-way |
| `c50ca68943` | swiftformat-clean on two files that scope added |
| `90f31ed413` | a merge of that style fix |
| `a7e900d0b1` … `b96d3f7cb5` | nine commits of the LOC-gate and blast-radius lane (card `t_12126d87`), landed while round 2 was under review |

Any number written against that list is a timestamp, because `main` keeps moving: the round that
wrote "three times" had five sibling shas and this sentence has six rows. The command that
regenerates the list is the thing to read, and it is the only part of this section that can be
re-run:

```bash
cd /Volumes/ANAN/Engineering/wenshu
git log --format='%h %s' 8b75e70306..main | cat
```

To separate the sibling lanes from this session's own work: `git log --format='%h %an %s' main` and
read the subject - this session's subjects are in §1's table and nothing else on that list belongs
here.

## 9. Where the next session starts

```bash
cd /Volumes/ANAN/Engineering/wenshu
git fetch --all -q; git rev-parse main origin/main old-origin/main
/usr/bin/python3 Tools/wenshu-devtool/review_gate.py --branch project/closeout-derived-claims
```

What that fence answers, and what each line means. The three refs are not three copies of one
thing: `origin` is the gitcode remote and `old-origin` is the GitHub one, and this repo's landing
rule is that BOTH carry `main` (the earlier closeout document states it and §6's item 6 is a landing
that skipped a push and only noticed when `git ls-remote` was read). So `main` and `origin/main`
must agree, and a third sha that trails them means a landing has not been mirrored to GitHub - which
is a defect in that landing, not in this command, and not a stalled merge. The way to tell "landed"
from "not landed" is the ancestry test, not the equality of three refs:
`git merge-base --is-ancestor <reviewed tip> main; echo $?` reading 0. Measured here at the start of
this round: `main` and `origin/main` both `b96d3f7cb5`, `old-origin/main` still `8b75e70306` - the
nine sibling commits between them are another lane's landings, and this lane rebased onto `main`
because of them.

The `review_gate` line must print a `CARD <id>` row. **Its exit code is not the verdict.** The
`--branch` path ends in `return 0 if found else 3` (`review_gate.py:1575`), where FOUND means "some
review card names this tip" - so it reads 0 for an approved tip and 0 for a refused one, and the
verdict is only in the printed `verdict:` line. Round 2 stated the opposite from memory, in this
same section, and that is the defect class §6.8 exists to end. Measured here with the rc captured
before anything else ran:

```bash
cd /Volumes/ANAN/Engineering/wenshu
/usr/bin/python3 Tools/wenshu-devtool/review_gate.py --branch review/b24e363f17; echo "rc=$?"
/usr/bin/python3 Tools/wenshu-devtool/review_gate.py --branch review/b24e363f17 --sha 00000000000000000000000000000000000000aa; echo "rc=$?"
/usr/bin/python3 Tools/wenshu-devtool/review_gate.py --branch project/no-such-branch-anymore; echo "rc=$?"
/usr/bin/python3 Tools/wenshu-devtool/review_gate.py --card t_9a29eafd; echo "rc=$?"
/usr/bin/python3 Tools/wenshu-devtool/review_gate.py --card t_ffffffff; echo "rc=$?"
```

Row 1 is the refutation: it printed `CARD t_9a29eafd` / `verdict: changes_requested` at **rc 0** - a
refused verdict, exit code 0. Row 2 printed `NO REVIEW CARD names the sha …` at rc 3 and row 3
`NO REVIEW CARD: branch … has no resolvable tip` at rc 3, the two miss shapes. Rows 4 and 5 are the
verdict's own ladder: `t_9a29eafd changes_requested` at rc 3, `t_ffffffff card_absent` at rc 4.

The first three rows are measured against `review/b24e363f17` - a round-2 tip pinned as a branch, so
the sha and the card naming it can never move again and these five lines read the same in a year.
Against the live branch the same command reads rc 3 for as long as no card names the tip, which is
the ordinary state of an amended branch between rounds, and it is why the starting fence above names
`review_gate`'s printed `CARD` line as the thing to look at. Full `--card` ladder
(`:1511-1536`): 0 approved, 3 for not_approved / changes_requested / no_handoff / no_reviewer_named /
self_review, 4 card_absent, 1 contract_error, 2 board_unreadable. `--branch` reserves 2 for an
unreadable board (`:1554-1559`).

If the reviewed tip is not an ancestor of `main`, the landing did not happen and this document is
describing a branch, not `main`. Two board facts to carry: the claim guard's arms and the ordering case are
the only witnesses that a padded token governs nothing, and they are in
`Tools/wenshu-devtool/tests/test_review_gate.py` - a gate change that reddens them is
legitimate, a change that SILENCES them is the regression this round was about.

## 10. How this document gets reviewed, and where it stops

This section is the last one, and a card that asks for another is a defect, not a follow-up: a
closeout record cannot keep growing sections to describe the review of the section that
described the previous review. The stop rule is the one AGENTS.md §8 already states, and the
number this file publishes about itself is deliberately an invariant rather than a value.

```bash
cd "$(git rev-parse --show-toplevel)"
DOC=$(git ls-files 'docs/agents/*session-close-the-claim*')
awk -F'|' -v d="$DOC" '$2 ~ d {gsub(/ /,"",$4); print "registry row LOC=" $4}' docs/agents/nfi.md
grep -c "" "$DOC" | sed 's/^/wc -l=/; s/^/ /'
```

**The registry row's LOC cell and the file's own line count are read from the tree you are
standing on, and the row is right only if the two answers are EQUAL.** It is not published as a
number here because every correction round lengthens the sentences that carry the numbers, which
is the defect class this section exists to end. **The mutation that makes this block red: write
the row with the count from a previous round and run the two commands** - they print different
values, and that difference is the whole reason the row is written last.
