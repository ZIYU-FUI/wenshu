# The board is a dispatch board — what stopped echoing the chat, and what proves it

This record covers `t_6fda7f0b` (round 1, `changes_requested`) and `t_52d1c551`
(round 2, `approved`), landed as `297d01b522` plus `8d494e16b5` on `main`.
Those two are the only card ids named anywhere below: a card id further down
is a mention of one of them, and the one inside a published command is the
card that holds the number beside it.

## The symptom, counted

The right-hand column listed one card per chat sentence. The live warehouse
store, read before the fix shipped:

| reading | value |
| --- | --- |
| rows in `ZWSKANBANTASK` | 58 |
| rows titled `conductor: ` | 58 |
| of those, with no owner | 58 |
| rows that are NOT a chat echo | 0 |

The column was therefore not "cluttered with echoes" — it was entirely echoes,
and it held no hand-off at all.

## Root cause

`WenshuConductor.handle()` filed a card for every user turn
(`repositories.kanban.add(title: "conductor: <first 50 chars>", status:
"running")`, kept for parity with an older build). Two further defects made
that look intentional rather than wrong:

- the tool that files a real hand-off dropped the owner and the instruction, so
  a genuine card and an echo were indistinguishable;
- the card view drew the owner line only when a name existed, so every row
  rendered as a bare title.

A card on this board means one thing: role A hands work to role B. A turn of
conversation is not that. Nothing in the tree pinned the per-turn write, so the
write could return silently.

## The fix, per file

`297d01b522` — the board records a hand-off:

- `Sources/WenshuAgent/Sources/WenshuAgent/Agent/WenshuConductor.swift`: the
  per-turn write is gone, together with the store member and the data import,
  so the runtime package no longer reaches the board at all.
- `Sources/WenshuApp/Features/Agent/Service/DelegateResearchTool.swift`,
  `.../KanbanTools.swift`: a card is stamped with owner, instruction and book.
- `Sources/WenshuApp/Features/Kanban/View/KanbanView.swift`,
  `KanbanTicketDetailSheet.swift`: the owner is drawn above the title.
- `Sources/WenshuApp/App/WenshuAppDelegate.swift`: at launch,
  `removeCards(withTitlePrefix: "conductor: ")` clears the historic echoes.
- `Sources/WenshuData/Sources/WenshuData/Repositories/WSKanbanRepository.swift`:
  the sweep itself.

`8d494e16b5` — the guard, widened, and the sweep's question:

- `Tests/WenshuAppTests/Agent/Conversation/WenshuConductorE2ETests.swift`: the
  structural guard filters a LIST of names (`WSKanbanRepository`,
  `WSRepositoryContainer`, `.kanban.`), an arm proves the list bites on the
  historical line with its comments stripped, and no production file outside
  the sweep may build the echo title.
- `WSKanbanRepository.swift` + `WSKanbanRepositoryTests.swift`: an empty owner
  or an empty instruction counts as none, so the delete asks the same question
  the board draws; two rows (`assignee: ""`, `body: ""`) are now in the test.

## Measured at the merged tree

Read in `/Volumes/ANAN/Engineering/wenshu/.worktrees/board-dispatch-2026-11-26`
(`HEAD` = `8d494e16b5`, `status --porcelain` = 0), logs under
`/Volumes/ANAN/Engineering/wenshu/.gate-logs/` — `closeout-landed_*.log` and
`m1-build_*.log`, thirteen files. They sit in the shared checkout because the
gate script resolves its log directory beside the script it was invoked
through, and the shared checkout's copy is the one that ran the commands
against this worktree:

| gate | reading |
| --- | --- |
| `swift build --scratch-path build` | Build complete (0.87 s) |
| `swift test --package-path Sources/WenshuData --filter WSKanbanRepositoryTests` | 5 tests in 1 suite passed |
| `swift test --filter WenshuConductorE2ETests` | 8 tests in 1 suite passed |
| `swift test --filter <the other seven suites>` | 36 tests in 7 suites passed |
| `comment_lineage.py --base 64b97c7f08` | exit 0; added comment lines 146; offending 11 rows / 4 files (P0=0, P1=11), all carried, REPORTED ONLY |
| `nfi-loc-check.py --base 64b97c7f08` | exit 0 at `8d494e16b5` printing `nothing to check`; at this record's own tip the same command exits 0 printing `1 row(s) checked` (= the row this record adds, whose LOC cell equals `grep -c ""` of the file it names) |
| `ci_change_gate.py --check formatting / loc-cap / pollution` | exit 0, exit 0, exit 0 (14 changed Swift files) |
| `review_gate.py --card t_52d1c551` | approved by wenshu-review, matched by change |
| `git merge-base --is-ancestor 8d494e16b5 refs/remotes/origin/main` | rc 0 (= the landed tip is an ancestor of the server's `main`; the tip itself is not published here, because a tip is an instant — see "Re-taking the readings") |

The three test rows were read over the wider window `e17c5f30ce..8d494e16b5`
because that is what the landing push carried; the four gate rows were re-taken
over the scope's own window `64b97c7f08..8d494e16b5`, and both readings agree.

The scope's window at the merged tree is `64b97c7f08..8d494e16b5` (two commits,
14 files). Its content equals the approved tree: `git diff 4b02c68dcf main --
<the 14 paths>` prints 0 lines.

## The push, and whose commits it carried

`main` moved `e17c5f30ce` -> `8d494e16b5` by compare-and-swap on the ref and
fast-forward, so no merge commit was created. That push carried nine commits.
Two are this scope's (`297d01b522`, `8d494e16b5`). Seven belong to sibling
lanes and were already on local `main` but not on the server — pushing them was
maintenance of shared server state, not authorship: `53e2ab2ff2`,
`7f13793106`, `2a4d34c473`, `f4e7cbed66`, `2f6abe45a8`, `545cf55bed`,
`64b97c7f08` (the retrieval whole-corpus write and its acceptance records).

## Open items

1. **The look is PENDING the owner's verdict.** This is a UI-touching scope, so
   its merge gate is the owner looking at the running build, not a screenshot.
   Four facts about that build: it is
   `/Volumes/ANAN/Engineering/wenshu/.worktrees/board-dispatch-2026-11-26/build/Wenshu.app`,
   assembled by `bash Scripts/build-app.sh` from a tree whose `HEAD` was
   `8d494e16b5` (the tip this scope landed; `main` has since moved on), ad-hoc
   signed, `Identifier=com.wenshu.app`; its own bytes carry the change — `nm -a`
   on `Contents/MacOS/WenshuApp` gives 8 hits on `removeCards` and 232 on
   `WSKanbanRepository` as the positive control, and the sweep's literal
   `conductor: ` prefix appears once in `strings -a` on the same binary (a
   string literal is not a symbol, so `nm` prints none of it). It was launched
   with a plain
   `open` (never `-n`) and is left RUNNING, holding the live store: after launch
   that store reads `0|` where it read `58|58` before, and the right column shows
   the empty state. What has NOT happened is the owner's judgement of what the
   column should now look like — that verdict is not recorded here, and the next
   reader should not read the empty column as an approved appearance.
2. **The sweep is shape-scoped.** It deletes only title-prefixed, bookless,
   ownerless rows, so a card that names anything survives. The 58 rows in the
   live store match that shape; no other store was cleared by hand.
3. **A stale working tree makes a git-window gate lie.** Measured the same
   evening: `ci_change_gate.py --check formatting --base 64b97c7f08` exits 0 in
   the clean worktree and exits 1 in the shared checkout, whose index predates
   the landing by 49 paths. The gate takes its line numbers from a commit
   window and its file bodies from disk, so the two must be the same tree. Run
   repository gates in a worktree whose `status --porcelain` is 0 and whose
   `HEAD` is the tree being claimed.
4. **Reviewer notes that stay open** (non-blocking, from `t_52d1c551`): the
   echo-title arm exempts by content rather than by path; it pins the literal
   prefix, so an interpolated title could evade it; the reach guard matches raw
   text including comments, so a future prose mention inside the runtime
   package turns it red; `removeCards` fetches wider than it needs to, bounded
   by the ownerless set.
5. **This record's own review lives on the board**, in the card filed for this
   commit. No further section is added for it: a closeout doc that keeps logging
   its own meta-reviews has become the defect it was written to report.

## Re-taking the readings

```bash
cd /Volumes/ANAN/Engineering/wenshu && git merge-base --is-ancestor 8d494e16b5 main && echo LANDED
```

```bash
cd /Volumes/ANAN/Engineering/wenshu && git diff --quiet 4b02c68dcf main -- \
  Sources/WenshuAgent/Sources/WenshuAgent/Agent/WenshuConductor.swift \
  Sources/WenshuData/Sources/WenshuData/Repositories/WSKanbanRepository.swift \
  Tests/WenshuAppTests/Agent/Conversation/WenshuConductorE2ETests.swift \
  && echo APPROVED_CONTENT_IS_ON_MAIN
```

```bash
sqlite3 -readonly /Users/anbaiqiang/Documents/anbaiqiang.ws/WenshuStore.store \
  "select count(*), sum(ZTITLE like 'conductor: %') from ZWSKANBANTASK;"
```

The two `git` blocks above assert ancestry and content and never a tip: `main`
moves under every lane, and by the time this paragraph was written it had already
grown past `8d494e16b5` by two sibling commits whose only touched file is
`Tests/WenshuAppTests/Library/View/SidebarIconUniformityTests.swift` — disjoint
from this scope's 14 paths, which is why the content block still prints its word.
A reader who finds `main` further along should re-run the blocks, not trust the
sha named here.

The invariant this scope is responsible for, re-asserted against whatever `main`
currently is:

```bash
cd /Volumes/ANAN/Engineering/wenshu && git grep -ln '"conductor: "' main -- '*.swift'
```

That list is exactly three files: the launch sweep
(`Sources/WenshuApp/App/WenshuAppDelegate.swift`), the repository test that
exercises it, and the conductor test that holds the pin. A fourth production file
in the list means a card title is being built outside the sweep again — the board
defect this record describes is back, and the reach-guard test is what should turn
red first.
