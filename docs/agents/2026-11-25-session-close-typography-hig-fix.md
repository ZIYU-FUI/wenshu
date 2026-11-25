# The typography HIG fixes land as one branch (typography-hig-fix, 2026-11-24)

This is the session closeout of record for the scope `2026-11-24-typography-hig-fix`:
seven typography faults an Apple-HIG audit named, fixed on one branch, reviewed twice,
merged into `main`, and re-measured here on a tree that holds the merge.

It is a reading, not a holding: every figure below names the tree or the log file it was
taken from, because `main` moves under a record like this. A reader who re-runs a block
on a newer `main` may print a different count for the moving quantities; that is the
block working, not the record being wrong. The moving quantities are marked.

## 0. The tree this record measures

| Name | SHA | What it is |
| --- | --- | --- |
| scope base | `e4818545d7f99156576db131081271f6ae11c05f` | the commit the branch was cut from |
| scope tip | `b18bcefd745e303d24f41c7eafac924316bcaf51` | the ninth and last commit of the change |
| merged tree | `bb107e8c1e3fb374b38279e36ba89e75cc0f4ce9` | `main` this record was measured on |

```bash
git rev-parse e4818545d7f99156576db131081271f6ae11c05f \
              b18bcefd745e303d24f41c7eafac924316bcaf51 \
              bb107e8c1e3fb374b38279e36ba89e75cc0f4ce9
git log -1 --format='%H %s' bb107e8c1e3fb374b38279e36ba89e75cc0f4ce9
```

The scope tip sits on `main`'s FIRST-PARENT chain, at position 14 below the tip that was
current when this record was written (= `grep -n` prints it, `grep -c` proves it appears
once), so the branch was landed by a fast-forward and no merge commit hides it. Position is
a moving quantity: every landing above it adds one.

```bash
git merge-base --is-ancestor b18bcefd745e303d24f41c7eafac924316bcaf51 main && echo ANCESTOR_OF_MAIN
git log --oneline --first-parent main | grep -c b18bcefd74
git log --oneline --first-parent main | grep -n b18bcefd74 | head -1
git log --oneline --reverse e4818545d7f99156576db131081271f6ae11c05f..b18bcefd745e303d24f41c7eafac924316bcaf51 | cat
```

The nine commits, each one ticket or one review blocker:

| SHA | Subject | The ticket it answers |
| --- | --- | --- |
| `ea00bb94ac68b66950ae6c6cb5e3620a81d61be5` | feat(design): a symbol beside text wears that text's own style | 002 |
| `944d47633f2955f77e2a7135ce2060fccfebf8cb` | fix(chat): the plan card's title outranks its chrome | 003 |
| `73d5ce6b7ec6396e4f348e9da548e99de1afaeb0` | fix(chat): the plan header stops crowding one row | 004 |
| `d967932b6384d7bb6b03a18616130612ef8ead03` | fix(onboarding): the welcome blurb reads left-aligned | 007 |
| `5787fab850fe84da6e9826bd49f3402b9311f632` | fix(design): a comment states only what the tree can check | 005 |
| `7c50a443dc994ed4e68dd0e9d381f37b18af706b` | fix(design): the app keeps no size table for Apple's text roles | 006 |
| `eddcd43b3958236bf47cab5f82cf0e97fdbff2e0` | fix(library): a chapter's PDF export pays for the whole chapter | 001 |
| `5500b471bcf0e4b45f5a0535f38ceb22f4867c79` | test(chat): the icon sweeps read the pairing the footer names | round-1 follow-up |
| `b18bcefd745e303d24f41c7eafac924316bcaf51` | docs(agents): the resolver's row carries its file's own count | round-1 blocker F1 |

## 1. Re-run the section 7 gates on the MERGED tree

The authoritative battery ran in the checkout that holds the merge
(`.worktrees/closeout-typography-hig-2026-11-25`, HEAD = `bb107e8c1e`), through
`Scripts/gate_run.sh`, so every figure below is a held log line and not a claim. Label:
`2026-11-24-typography-hig-fix_merged4`, thirteen logs, `exit 0` on the run.

| # | Gate | Held log | Reading |
| --- | --- | --- | --- |
| 1 | tree identity | `..._merged4_1.log` | `bb107e8c1e3fb374b38279e36ba89e75cc0f4ce9` |
| 2 | parent identity | `..._merged4_2.log` | `7de223281a50f3da779ded7a0cd81773e1ecda39` |
| 3 | `swift build` | `..._merged4_3.log` | `Build complete!` |
| 4 | the scope's 30 suites | `..._merged4_4.log` | `Test run with 143 tests in 30 suites passed after 6.508 seconds.` |
| 5 | NFI registry LOC | `..._merged4_5.log` | `39 row(s) checked: = 21 the change added, = 18 whose named file the change rewrote and did not add` |
| 6 | comment lineage | `..._merged4_6.log` | `added comment lines: 545` / `offending: 0 rows / 0 files (P0=0, P1=0)` |
| 7 | files the merge carries | `..._merged4_7.log` | `85` |
| 8 | files the scope does not own | `..._merged4_8.log` | `40` |
| 9 | commit count | `..._merged4_9.log` | `9` |
| 10 | ancestry | `..._merged4_10.log` | `SCOPE_TIP_IS_ANCESTOR_OF_MAIN` |
| 11 | `origin` main | `..._merged4_11.log` | `bb107e8c1e3fb374b38279e36ba89e75cc0f4ce9 refs/heads/main` |
| 12 | `old-origin` main | `..._merged4_12.log` | `7de223281a50f3da779ded7a0cd81773e1ecda39 refs/heads/main` |
| 13 | `old-origin` re-read | `..._merged4_13.log` | `7de223281a50f3da779ded7a0cd81773e1ecda39 refs/heads/main` |

The battery itself is not re-runnable inside a verification pass (= it builds, writes
logs, and reads the network), so its command is published for the reader who wants the
numbers regenerated:

```bash
SKIP: this block builds the package, writes into .gate-logs and contacts two remotes; a
      reader who wants these numbers regenerated runs it and reads the new logs.
cd /Volumes/ANAN/Engineering/wenshu
LOGDIR=/Volumes/ANAN/Engineering/wenshu/.gate-logs PER_CMD_TIMEOUT=1200 \
  bash Scripts/gate_run.sh \
    /Volumes/ANAN/Engineering/wenshu/.worktrees/closeout-typography-hig-2026-11-25 \
    2026-11-24-typography-hig-fix_merged4 \
    'git rev-parse HEAD' 'git rev-parse main^' \
    'swift build 2>&1 | tail -3' \
    "swift test --skip-build --disable-sandbox --filter '$(cat /Volumes/ANAN/.hermes/profiles/pocock/cache/scratch/typo-closeout/scope_filter.txt | tr -d '\n')' 2>&1 | tail -4" \
    'python3 Tools/wenshu-devtool/nfi-loc-check.py --base e4818545d7f99156576db131081271f6ae11c05f' \
    'python3 Tools/wenshu-devtool/comment_lineage.py --base e4818545d7f99156576db131081271f6ae11c05f --head b18bcefd745e303d24f41c7eafac924316bcaf51 --repo . --report | tail -4' \
    'git diff --name-only e4818545d7f99156576db131081271f6ae11c05f..main -- Sources Tests | wc -l' \
    'git diff --name-only b18bcefd745e303d24f41c7eafac924316bcaf51..main -- Sources Tests | wc -l' \
    'git rev-list --count e4818545d7f99156576db131081271f6ae11c05f..b18bcefd745e303d24f41c7eafac924316bcaf51' \
    'git merge-base --is-ancestor b18bcefd745e303d24f41c7eafac924316bcaf51 main && echo SCOPE_TIP_IS_ANCESTOR_OF_MAIN' \
    'git ls-remote origin refs/heads/main' \
    'git ls-remote old-origin refs/heads/main' \
    'git ls-remote old-origin refs/heads/main'
```

What the reader CAN re-check in seconds, without the logs:

```bash
python3 Tools/wenshu-devtool/nfi-loc-check.py --base e4818545d7f99156576db131081271f6ae11c05f
python3 Tools/wenshu-devtool/comment_lineage.py \
  --base e4818545d7f99156576db131081271f6ae11c05f \
  --head b18bcefd745e303d24f41c7eafac924316bcaf51 --repo . | tail -3
git rev-list --count e4818545d7f99156576db131081271f6ae11c05f..b18bcefd745e303d24f41c7eafac924316bcaf51
git rev-list --count old-origin/main..origin/main
git rev-list --count origin/main..old-origin/main
```

### The pre-existing red, witnessed on the base and not argued

Four suites are red on the merged tree. They are red because they were red BEFORE this
scope: the same selector, run on the base worktree at `e4818545d7`, prints the same
counts. Two held logs:

| Tree | Held log | Reading |
| --- | --- | --- |
| base `e4818545d7` | `2026-11-24-typography-hig-fix_reds_base_1.log` | `Test run with 41 tests in 4 suites failed` / `15 issues` |
| merged `bb107e8c1e` | `2026-11-24-typography-hig-fix_reds_merged_1.log` | `Test run with 41 tests in 4 suites failed` / `15 issues` |

The two logs are NOT byte-identical (18,555 and 18,560 bytes: the header names the tree)
and their suite-name SETS are identical, which is the comparison that carries the claim:

```bash
L=/Volumes/ANAN/Engineering/wenshu/.gate-logs
diff <(grep -oE 'Suite "[^"]+" failed after' "$L/2026-11-24-typography-hig-fix_reds_base_1.log" \
        | sed 's/ failed after//' | sort -u) \
     <(grep -oE 'Suite "[^"]+" failed after' "$L/2026-11-24-typography-hig-fix_reds_merged_1.log" \
        | sed 's/ failed after//' | sort -u) && echo SAME_SUITE_SET
wc -c "$L/2026-11-24-typography-hig-fix_reds_base_1.log" \
      "$L/2026-11-24-typography-hig-fix_reds_merged_1.log"
```

The four red suites, printed exactly as swift-testing names them: `ChatView history
shortcut (T92)`, `Editor tab strip - the strip divides the column it was given`, `The
pane tab strip's title rule`, `v0.71 P1 — EditorTab.displayTitle (tab title fallback
chain)`. None of them touches a file this scope changed. They belong to the editor and
chat tab strips and stay open as somebody else's work.

## 2. Record the verdict on the board

Both cards live on board `wenshu-par` and both are terminal. The column named
`task_runs.outcome` only says the run finished (= `completed` for both); the verdict lives in
`task_runs.metadata.review_outcome`, and flattening those two is how a reader mistakes a
finished review for an approving one.

| Card | Run | `metadata.review_outcome` | What it decided |
| --- | --- | --- | --- |
| `t_d0b32896` | 5008 | `changes_requested` | round 1, read at `25a39ee02f3c6adc6c21f8b59994f8c3e6e670f6`; blocker F1: the registry's row for `ChapterResolver.swift` carried 376 where the file carries 208 |
| `t_a5854855` | 5011 | `approved` | round 2, read at the tip `b18bcefd745e303d24f41c7eafac924316bcaf51`; F1 closed by `b18bcefd74`, and the reviewer proved its own discrimination (= two diffs that must differ printed equal bytes only when the tree was equal) |

```bash
sqlite3 /Users/anbaiqiang/.hermes/kanban/boards/wenshu-par/kanban.db \
  "select task_id, id, outcome, json_extract(metadata,'$.review_outcome'), \
          json_extract(metadata,'$.review_round'), json_extract(metadata,'$.reviewed_sha') \
   from task_runs where task_id in ('t_d0b32896','t_a5854855') order by id"
sqlite3 /Users/anbaiqiang/.hermes/kanban/boards/wenshu-par/kanban.db \
  "select id, status from tasks where id in ('t_d0b32896','t_a5854855')"
```

The closeout's board comment (= which commit landed, which gate printed what) is a write,
so it is published rather than executed here:

```bash
SKIP: writing to the board is a state change; the comment this step posts names the merged
      tree, the merged4 log set, and the four red suites, and it does not repeat the
      reviewer's own verdict text.
```

## 3. Write the closure doc (= this file)

`AGENTS.md` 1.7 requires every added file to carry a row in `docs/agents/nfi.md` whose LOC
cell is that file's own line count. This record owns exactly one such row, added in the
same commit as the file, and the row is the LAST thing edited, because the doc's line
count moves when a figure is corrected:

```bash
grep -c '' docs/agents/2026-11-25-session-close-typography-hig-fix.md
python3 Tools/wenshu-devtool/nfi-loc-check.py --base b18bcefd745e303d24f41c7eafac924316bcaf51
```

The first prints the line count, the second exits non-zero unless `docs/agents/nfi.md`'s
LOC cell for every file this change added or rewrote (= this document among them) equals
the count the file itself carries. This record therefore publishes no line count of
itself anywhere in its prose: a correction round lengthens the sentences that would carry
it, and the invariant above is what keeps the row honest.

## 4. Persist the durable lessons into the SKILLS

The class-level skill is `apple-ui-craft`, section 4 (Typography), rule T7, in the SHARED
skill tree at `/Volumes/ANAN/.hermes/shared/wenshu-skills/apple-ui-craft/SKILL.md` (= the
copy every related profile loads; there is no per-profile copy of this skill).

What the old sentence promised, and what the tree disproved: T7 read that SF Symbols
"automatically align with text in all weights and sizes" and that weight matching is
therefore achieved *for free*. It is not free. Apple's two HIG sentences are two
different claims (= L136-138 say symbols ship an equivalent weight axis so a match is
REACHABLE; L139-142 say a symbol integrates with the SYSTEM font). Once the app composes
its own `Font` (= a text style built from a size and a weight, which is what
`WenshuTextStyle` does), an icon rendered without instructions keeps its own traits and
sits beside text at a different weight and size. Issue 002 was exactly this defect. Its
acceptance names eleven rendered symbols in eight files (= the count is the ticket's, held in
the ignored plan of record at `.scratch/2026-11-24-typography-hig-fix/issues/002-a-symbol-wears-the-text-it-sits-beside.md`,
and the tree count that belongs to it is the nine files `ea00bb94ac` changed: seven views, the
token, and the test that pairs them).

The fix the branch carries is explicit: `SFIcon` takes the neighbour's text style and
applies its font (= `matchingText:`, resolving to `.font(style.font)` in
`Sources/WenshuApp/Shared/UI/IconStyles.swift`), and the sweeps assert the PAIR (symbol
plus its neighbour's style), never the symbol alone.

```bash
git grep -c 'matchingText' bb107e8c1e3fb374b38279e36ba89e75cc0f4ce9 -- Sources Tests | wc -l
git grep -ohE 'matchingText' bb107e8c1e3fb374b38279e36ba89e75cc0f4ce9 -- Sources Tests | wc -l
git grep -n 'AnyView(plainImage.font' b18bcefd745e303d24f41c7eafac924316bcaf51 -- Sources/WenshuApp/Shared/UI/IconStyles.swift | head -2
grep -n 'T7 Symbols are type' /Volumes/ANAN/.hermes/shared/wenshu-skills/apple-ui-craft/SKILL.md
```

The shared file carries another session's uncommitted work in two other hunks. This step
replaced exactly one line, and the hunk census is the proof that nothing else moved:

```bash
git -C /Volumes/ANAN/.hermes/shared/wenshu-skills diff -U0 -- apple-ui-craft/SKILL.md \
  | grep -c '^@@'
git -C /Volumes/ANAN/.hermes/shared/wenshu-skills diff --numstat -- apple-ui-craft/SKILL.md
```

Three hunks: this edit at line 73, the other session's two at 144 and 178. This step
therefore does NOT commit the shared skill file (= a commit here would land that session's
30 unreviewed insertions under this scope's message); the edit sits in the working tree of
the shared tree, and the commit belongs to whoever owns that diff. The pre-edit copy is
held at `/Volumes/ANAN/.hermes/profiles/pocock/cache/scratch/typo-closeout/apple-ui-craft-SKILL.md.pre-typography-closeout`
and the other session's diff at `apple-ui-craft-sibling.diff` beside it. The three untracked
reference files in that directory are not claimed.

## 5. Clean up YOUR OWN residue

Only this scope's artifacts, and only after the SHA they hold is reachable from a ref that
survives them:

```bash
git for-each-ref 'refs/keep/typography*' --format='%(refname) %(objectname)'
test "$(git rev-parse refs/keep/typography-hig-fix-a1)" = b18bcefd745e303d24f41c7eafac924316bcaf51 && echo A1_PARKED
```

```bash
SKIP: deleting a worktree or a branch is irreversible for anyone who still holds it; the
      parking commands that must run FIRST are the pair below, and each is proven by the
      rev-parse equality above before anything is removed.
cd /Volumes/ANAN/Engineering/wenshu
git update-ref refs/keep/typography-hig-fix-a1 b18bcefd745e303d24f41c7eafac924316bcaf51
git worktree remove .worktrees/typography-hig-fix-2026-11-24
git worktree remove .worktrees/typo-closeout-base-2026-11-25
git branch -D wt/typography-hig-fix-2026-11-24
```

```bash
git check-ignore -v .gate-logs/probe.log .scratch/probe.md .worktrees/probe
```

Held on purpose, and named so the next reader knows what is left:

- the thirteen `..._merged4_*.log` files and the two red witnesses: local evidence under
  `.gate-logs/`, which `.gitignore` line 126 ignores, so they are readable in the primary
  checkout and are not tracked artifacts;
- the plan of record under `.scratch/2026-11-24-typography-hig-fix/`: ignored by design,
  and the index's seven branch cells still name `wt/typography-hig-fix-2026-11-24`, which
  is why the branch's SHA is parked rather than left dangling;
- the closeout worktree itself, removed only once this record has landed.

## 6. Re-check the final state and report it

### The landing table, one row per original requirement

| Requirement | The commit that carries it | The verdict that cleared it | The server-side proof |
| --- | --- | --- | --- |
| 001 the PDF export pays for the whole chapter | `eddcd43b3958236bf47cab5f82cf0e97fdbff2e0` | `t_a5854855` run 5011 `approved` | in `main`'s first-parent chain; both remotes' `refs/heads/main` are descendants (= section 1, logs 11-13) |
| 002 a symbol wears the text it sits beside | `ea00bb94ac68b66950ae6c6cb5e3620a81d61be5` + `5500b471bcf0e4b45f5a0535f38ceb22f4867c79` | `t_a5854855` run 5011 `approved` | same |
| 003 the plan card's title outranks its chrome | `944d47633f2955f77e2a7135ce2060fccfebf8cb` | `t_a5854855` run 5011 `approved` | same |
| 004 the plan header stops crowding one row | `73d5ce6b7ec6396e4f348e9da548e99de1afaeb0` | `t_a5854855` run 5011 `approved` | same |
| 005 comments state what the tree can disprove | `5787fab850fe84da6e9826bd49f3402b9311f632` | `t_a5854855` run 5011 `approved` | same |
| 006 no number table nobody reads | `7c50a443dc994ed4e68dd0e9d381f37b18af706b` | `t_a5854855` run 5011 `approved` | same |
| 007 the onboarding blurb reads left-aligned | `d967932b6384d7bb6b03a18616130612ef8ead03` | `t_a5854855` run 5011 `approved` | same |
| round-1 blocker F1, the registry row's own count | `b18bcefd745e303d24f41c7eafac924316bcaf51` | `t_a5854855` run 5011 `approved` | same |

The proof column is deliberately the ancestry, not a landing card: this scope reached
`main` without a landing card of its own. That is a gap in the board's record, not in the
code, and the honest reading of it is in section 9. Each row's SHA is on `main`'s
first-parent chain and therefore on both remotes:

```bash
for s in eddcd43b3958236bf47cab5f82cf0e97fdbff2e0 ea00bb94ac68b66950ae6c6cb5e3620a81d61be5 \
         5500b471bcf0e4b45f5a0535f38ceb22f4867c79 944d47633f2955f77e2a7135ce2060fccfebf8cb \
         73d5ce6b7ec6396e4f348e9da548e99de1afaeb0 5787fab850fe84da6e9826bd49f3402b9311f632 \
         7c50a443dc994ed4e68dd0e9d381f37b18af706b d967932b6384d7bb6b03a18616130612ef8ead03 \
         b18bcefd745e303d24f41c7eafac924316bcaf51; do
  git merge-base --is-ancestor "$s" origin/main || echo "MISSING_FROM_ORIGIN $s"
done; echo ORIGIN_CARRIES_ALL_NINE
git merge-base --is-ancestor b18bcefd745e303d24f41c7eafac924316bcaf51 old-origin/main && echo OLD_ORIGIN_CARRIES_THE_TIP
```

### What changed in the source, measured before and after

Every pair below is `base e4818545d7` against `merged bb107e8c1e`, counted with the exact
command that follows the table. Values the merge alone produced are marked stable (= the
same at the scope tip); values other lanes moved afterwards are marked moving.

| Quantity | Base | Merged | Owner |
| --- | --- | --- | --- |
| `matchingText` occurrences in Sources and Tests | 0 | 34 | stable at 34 from the scope tip |
| files carrying `matchingText` | 0 | 15 | stable |
| `pointSize` occurrences in Sources and Tests | 71 | 58 | stable |
| files carrying `pointSize` | 10 | 9 | stable |
| `pointSize` in `WenshuTextStyle.swift` | 1 | 0 | stable |
| lines of `WenshuTextStyle.swift` | 119 | 82 | stable |
| lines of `ChatPlanPartView.swift` | 199 | 185 | stable |
| `headline` in `ChatPlanPartView.swift` | 0 | 3 | stable |
| `caption2` in `ChatPlanPartView.swift` | 5 | 6 | stable |
| lines of `BookExportEngine.swift` | 366 | 349 | stable |
| lines of `BookPDFTypesetter.swift` | absent | 247 | stable |
| lines of `LibraryRootView.swift` | 536 | 539 | stable |
| `multilineTextAlignment(.center)` in `LibraryRootView.swift` | 1 | 0 | stable |
| `multilineTextAlignment(.leading)` in `LibraryRootView.swift` | 0 | 1 | stable |
| lines of `IconStylesTests.swift` | 279 | 417 | stable |
| lines of `docs/agents/nfi.md` | 732 | 753 | moving (every lane appends) |

```bash
B=e4818545d7f99156576db131081271f6ae11c05f; M=bb107e8c1e3fb374b38279e36ba89e75cc0f4ce9
for pat in matchingText pointSize; do
  printf '%s occurrences: %s -> %s\n' "$pat" \
    "$(git grep -ohE "$pat" $B -- Sources Tests | wc -l | tr -d ' ')" \
    "$(git grep -ohE "$pat" $M -- Sources Tests | wc -l | tr -d ' ')"
  printf '%s files: %s -> %s\n' "$pat" \
    "$(git grep -lE "$pat" $B -- Sources Tests | wc -l | tr -d ' ')" \
    "$(git grep -lE "$pat" $M -- Sources Tests | wc -l | tr -d ' ')"
done
for p in Sources/WenshuApp/Shared/UI/WenshuTextStyle.swift \
         Sources/WenshuApp/Features/Chat/View/ChatPlanPartView.swift \
         Sources/WenshuApp/Features/Library/Service/BookExportEngine.swift \
         Sources/WenshuApp/Shared/UI/LibraryRootView.swift \
         Tests/WenshuAppTests/UI/DesignSystem/IconStylesTests.swift; do
  printf '%s lines: %s -> %s\n' "$p" \
    "$(git show $B:$p 2>/dev/null | wc -l | tr -d ' ')" "$(git show $M:$p | wc -l | tr -d ' ')"
done
printf 'typesetter lines now: %s (absent at base: %s)\n' \
  "$(git show $M:Sources/WenshuApp/Features/Library/Service/BookPDFTypesetter.swift | wc -l | tr -d ' ')" \
  "$(git cat-file -e $B:Sources/WenshuApp/Features/Library/Service/BookPDFTypesetter.swift 2>&1 | head -1)"
for spec in 'pointSize:Sources/WenshuApp/Shared/UI/WenshuTextStyle.swift' \
            'headline:Sources/WenshuApp/Features/Chat/View/ChatPlanPartView.swift' \
            'caption2:Sources/WenshuApp/Features/Chat/View/ChatPlanPartView.swift' \
            'multilineTextAlignment\(\.center:Sources/WenshuApp/Shared/UI/LibraryRootView.swift' \
            'multilineTextAlignment\(\.leading:Sources/WenshuApp/Shared/UI/LibraryRootView.swift'; do
  pat=${spec%%:*}; file=${spec#*:}
  printf '%s in %s: %s -> %s\n' "$pat" "${file##*/}" \
    "$(git show $B:$file | grep -cE "$pat" || true)" \
    "$(git show $M:$file | grep -cE "$pat" || true)"
done
printf 'nfi.md lines: %s -> %s\n' \
  "$(git show $B:docs/agents/nfi.md | grep -c '')" "$(git show $M:docs/agents/nfi.md | grep -c '')"
```

Sixteen rows, sixteen readings: the block prints the two `matchingText` rows and the two
`pointSize` tree rows (= 4 pairs), five `lines:` rows, the typesetter row, five per-file
occurrence rows and the registry row (= 16). The two alignment patterns carry the escaped
paren on purpose (= the source text is `.multilineTextAlignment(.center)`, so a pattern that
matches a bare dot matches nothing, and a block that prints `0 -> 0` under a table that says
`1 -> 0` is the row that lies).

### The test census this scope owns

Thirty test files changed, thirty suite names in the filter, 143 tests, one run, green
(= section 1, log 4). The census is the scope's own surface, not the directory's: the filter
is the union of every suite `ea00bb94ac` through `5500b471bc` touched, so it cannot go green
by dropping a suite it broke. The block below prints the file counts, which is where the
filter came from; the suite and test counts come from the runner's own summary line.

```bash
git diff --name-only e4818545d7f99156576db131081271f6ae11c05f..b18bcefd745e303d24f41c7eafac924316bcaf51 \
  -- Tests | wc -l | tr -d ' '
git diff --name-only e4818545d7f99156576db131081271f6ae11c05f..b18bcefd745e303d24f41c7eafac924316bcaf51 \
  -- Sources | wc -l | tr -d ' '
```

The filter string itself lives beside the scratch work
(`/Volumes/ANAN/.hermes/profiles/pocock/cache/scratch/typo-closeout/scope_filter.txt`,
30 names) and is a local artifact, not a tracked one.

## 7. Sweep the board's open columns

```bash
sqlite3 /Users/anbaiqiang/.hermes/kanban/boards/wenshu-par/kanban.db \
  "select id, status, assignee, substr(title,1,60) from tasks
   where status in ('ready','running','blocked','review','todo') and (body like '%typography-hig-fix%' or title like '%typography%')"
sqlite3 /Users/anbaiqiang/.hermes/kanban/boards/wenshu-par/kanban.db \
  "select id, status from tasks where id in ('t_d0b32896','t_a5854855')"
```

The first query is expected to print the closure cards this session dispatches, and
nothing else: the scope's own two cards are `done` (second query), and the plan of record's
seven index rows all read `landed`. Open cards belonging to other lanes, including the
ones the boss created, are read and not touched.

## 8. The card this record dispatches is its own to land

This file is a commit of its own, made after the requirement code, and it carries its own
registry row. It gets its own review card (tier `[T3]`, the review kind in its title, first paragraph naming the
SHA it reads, `## REVIEW HANDOFF`, a stated stopping rule) and, after a verdict, its own
landing card. Its landed SHA is recorded in the landing card's run metadata and NOT here:
a record cannot print its own landing. The last section is the only forward-looking claim
in this document.

## 9. Open items this scope leaves behind

1. **The boss's look is pending.** Section 7.7 wants a human reading of the running build
   for a UI-touching ticket. There is no screenshot or bundle tied to
   `b18bcefd745e303d24f41c7eafac924316bcaf51`, so this record claims source-level and
   test-level conclusions only. The alignment fix (007) and the plan header (003/004) are
   the two rows a human eye should confirm first.
2. **The scope landed without a landing card.** The nine commits are on `main`'s
   first-parent chain and on both remotes, but no landing card and no `landed_sha` run
   metadata names this branch, so the trail runs from the round-2 verdict to ancestry.
   Recorded here because it is the gap a future reader will trip on; repairing the record
   is not this scope's work.
3. **`old-origin` trails `origin` by one commit.** Read separately in section 1 (logs 11
   against 12: `bb107e8c1e` against `7de223281a`), and `git rev-list --count
   old-origin/main..origin/main` prints 1 with the reverse at 0. This closure commit will be
   pushed and read back on both; the one-commit lag that predates it is `bb107e8c1e`, another
   lane's test-and-record landing (= a retrieval test file, that scope's own closeout document,
   and the registry row it moved, three files in all), for whoever owns it to make up.
4. **Forty-three `.inlineSmall` call sites were never proven wrong.** The audit found them,
   the spec cut them out (an unfixed claim is not a defect list), and they stay out.
   Anyone reopening issue 002 should start by proving a mismatch, not by sweeping.
5. **The PDF's Markdown source rendering (headings, emphasis, lists) is out of scope.**
   Issue 001 bought a chapter's length accounting, not a Markdown renderer.
6. **Mobile, the board, the book reading view, and the editor paper canvas were not
   touched.** The scope was the desktop library, chat, onboarding and export paths.

## Stopping rule

This record is closed when: the thirteen merged-tree gate logs and the two red witnesses
are named and their numbers quoted; both scope cards read terminal on the board; the T7
rule in the shared `apple-ui-craft` skill says what the branch proved instead of what the
HIG quotation sounds like; the scope's own worktrees are removed with their SHA parked;
and this file plus its registry row are on `main` on both remotes. A wording complaint
against this document, once those hold, is not a reason to open another round.
