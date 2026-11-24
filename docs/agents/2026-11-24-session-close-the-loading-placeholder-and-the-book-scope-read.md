# Session close — the project's one loading placeholder, and the book scope's read out of the tab switch's frame

Date: 2026-11-24 (Asia/Shanghai). Tree this record was written against: `main` at
`1a2327f795` — an ancestry SNAPSHOT, not a tip claim. Read your own current tip with
`git rev-parse --short main`; the ancestry test is the check, never the tip:

```bash
cd /Volumes/ANAN/Engineering/wenshu
git merge-base --is-ancestor 37a8f04bf2 main && echo 'the scope is in main ancestry'
git log --oneline main -- Sources/WenshuApp/Shared/UI/LoadingPlaceholder.swift | head -3
```

Reproduce this record's readings the same way: `Scripts/gate_run.sh` writes each gate's
`rc` and tail to a log, and `git show <sha> -- <path>` returns any named file's body.

## 1. The two requests this scope answers

1. The chat zone's tab switch stuttered. The cause named by the request was not the chat
   zone itself: the related columns (the material column, the inspector) load together
   with the tab, so switching to the chat tab paid for another zone's work. The request was
   that the chat zone's own motion must not be affected by the other zones' loads.
2. The waiting state must be one project-wide mechanism, not a patch on the right column:
   while a region is loading it reserves the space its real content will occupy, and the
   real content replaces it in place, so nothing jumps. Implemented with Apple's own
   SwiftUI primitives; no longer or extra animation was used to hide a blocked main thread.

## 2. Root cause (two, independent)

**2.1 The tab switch's frame carried another scope's disk read.** The app's selection
follows the chat tab, so switching tabs changes the material column's scope inside the
same frame the chat zone animates in, and that scope walked the book's documents on the
main thread. It walked the same book twice per pass: once for the pane's own body, once for
the chrome's card count.

Measured before the fix (the app's own probe, one body pass in the book scope):

| reading | value | Apple's line |
| --- | --- | --- |
| main-thread work, min | 821 microseconds | one frame's hitch budget is 5000 microseconds |
| main-thread work, median | 2634 microseconds | — |
| main-thread work, p95 | 8087 microseconds | over the hitch line |
| bytes read per body pass | 115832 (123854 at the landing probe's read) | — |
| disk walks of the same book per pass | 2 | — |

**2.2 Every zone that waits improvised its own placeholder.** Three zones drew three
different empty shapes, and because none of them reserved the real content's space, the
layout jumped when the content arrived.

## 3. The fix as it stands on `main`

| file | role |
| --- | --- |
| `Sources/WenshuApp/Shared/UI/LoadingPlaceholder.swift` | the one placeholder. One component, three shapes (`rows`, `cards`, `groups`) so each zone reserves the shape its real content takes. Honours Reduce Motion (the cycle is empty when it is on). |
| `Sources/WenshuApp/Features/Editor/View/PreviewPaneBookDocuments.swift` | the book scope's documents read ONCE per book, off the main thread, behind a generation counter so a stale read cannot write over a newer one. |
| the zones that wait | the material column's scopes, the library list, the kanban board and the sidebar draw the shared placeholder; the chat transcript is the named exclusion, with the reason in the test (its own streaming lane is the waiting state there). |
| `docs/agents/ComponentIndex.md` | registers the component in the part table, so a reader finds it by concern. |

## 4. What landed — ancestry, not tips

Seven commits, twenty files touched, 2649 lines added and 484 removed (measured with
`git show --numstat` over the seven, summed).

| commit | subject | card |
| --- | --- | --- |
| `f0b4c889a7` | feat: the project's one loading placeholder, and the zones that wait draw it | `t_6765a05c` |
| `a4cfc41a62` | perf: the material column's book scope reads its documents once, off the main thread | `t_498766b6` |
| `d34741da44` | fix: the review's notes, and the citations that did not reproduce | `t_498766b6` |
| `1c13915934` | fix: the comment scaffold's runaway, the number family, and the evidence | `t_498766b6` |
| `988c12eb5d` | fix: the runaway probe's dead arm, and the four records that were over-claiming | `t_498766b6` |
| `6a8941d389` | fix: the three open findings from the first audit, measured against the landed tree | `t_ecbf4bc8` |
| `37a8f04bf2` | fix: the loading mechanism's own three loose ends, measured against the landed tree | `t_77e63bf6` |

`a4cfc41a62` is the landing of the work the board first recorded as `7be1cf15b8`: the lane
was rebased onto the landed tree and the reviewer proved the two trees byte-identical, so
the number that was never rewritten names nothing (`git cat-file -e` reads missing) and the
merge-base of the old branch is its own commit. Both shas are held under `refs/keep/` so the
card's citations resolve; `git for-each-ref refs/keep` lists what is parked.

## 5. Measured before and after

| reading | before | after (landing probe at `a4cfc41a62`) |
| --- | --- | --- |
| disk walks of the same book per body pass | 2 | 0 |
| bytes read inside the body pass | 123854 | 0 |
| where the read happens | the tab switch's frame, on the main thread | one background read per book, published into the view |

The mechanism's shape test bites four ways (the arms are attached to `t_6765a05c` and
re-run at `t_77e63bf6`): drop a shape that is in use, 2 issues; add a fourth shape that no
zone asks for, 3 issues; ignore Reduce Motion, 1 issue; draw it in the excluded chat file,
the exclusion test reddens. Reverting every arm returns the suite to green.

## 6. The gates, re-run on the merged tree

Rounds 1 through 4 each ran the whole gate set at their own tip and posted the readings in
the card bodies on the board (`hermes kanban show <card>`). This closeout re-ran them on the
merged tree instead of inheriting them, because main had moved under the branch.

| gate | command | reading at this tree |
| --- | --- | --- |
| build | `swift build -c debug` | exit 0 |
| the scope's own suites | `swift test --filter 'LoadingPlaceholderTests\|BookDocumentTests'` | exit 0, 28 tests in 2 suites passed |
| the full suite | `swift test --skip CSSearchableIndexSearchTests` | exit 0 (the one skip is the named pre-existing red; it is not in this scope) |
| the change gate | `python3 Tools/wenshu-devtool/ci_change_gate.py --base 26ef07472d --check <name>` for `formatting`, `pollution`, `loc-cap`, `markdown-newline` | 0 offending files in each |
| comment lineage | `python3 Tools/wenshu-devtool/comment_lineage.py --base 26ef07472d --head 37a8f04bf2 --format table` | 2667 added comment lines, 0 offenders |
| the design sweep | `bash Tools/wenshu-devtool/design-sweep.sh $(git diff --name-only f0b4c889a7^ 37a8f04bf2 -- '*.swift')` | no violation inside this scope's files |
| the registry | `python3 Tools/wenshu-devtool/nfi-loc-check.py --check` | every row carries its own count (32 rows checked) |
| dead code | `bash Scripts/verify-dead.sh <name>` | `LoadingPlaceholder` ALIVE, `PreviewPaneBookDocuments` ALIVE |

One sweep hit exists at this tree and it belongs to another scope: `design-sweep` reports a
naked `Image(systemName: "exposure")` in a chat-zone view (`ChatToolUsePartView.swift`), a
file no commit in this scope touches. It is recorded here as a finding against that lane, not
silently fixed here and not counted against this scope.

The pollution gate reads the changed lines only, so it cannot tell who introduced a
character: a CJK or curly-quote hit in a diff must be checked against the parent file with
`git show <sha>^:<path>` before anyone calls it a violation.

## 7. The change that was NOT kept

The card `book-scope-param-2026-11-24` proposed threading `folderName` down to
`PreviewPaneBookDocuments` because `PreviewPane.swift`'s `case let .bookScope(bookId,
folderName)` binding is unused at that site. Two facts, both measured:

- the binding is not dead where it is written — the value is passed to
  `PreviewPaneScopeViews.bookPreview(...)` at the use site inside the view builder, where it
  reaches `.inspector(folderName:)`;
- the tool that reported it is `swiftformat`'s `unusedArguments` rule, and that rule does not
  see argument uses inside a `@ViewBuilder` result-builder branch.

The edit was reverted before any commit (`git status --porcelain` empty, build green). The durable lesson is in the `comment-lineage-comment-rewrite` skill as Pitfall 4: an
`unusedArguments` report is a false-positive source on this tree, because the rule cannot see an
argument used inside a `@ViewBuilder` result-builder branch. The rule to apply before deleting a
binding: find its uses with a repo-wide grep over every call site, not with the linter's verdict.

## 8. The pre-rebase line that was not landed

`wt/skeleton-loading-2026-11-23` still names `ff2ea717b6`. Measured against
`git merge-base main ff2ea717b6` it carries eighteen files, 1657 added and 191 removed lines;
measured against current `main` the same comparison reads 99 files with 7414 lines of main's
content missing from it, and its `LoadingPlaceholder.swift` is 417 lines against main's 424 —
the pre-rebase ancestor line, plus a revert of the landed soft-cites sweep. Do not land it:

```bash
cd /Volumes/ANAN/Engineering/wenshu
git rev-list --count ff2ea717b6..main    # what main has gained since the branch's point
git diff --shortstat ff2ea717b6 main     # the direction of the difference, read not assumed
```

## 9. The tests this scope owns

| suite | what it holds | LOC on main |
| --- | --- | --- |
| `Tests/WenshuAppTests/UI/DesignSystem/LoadingPlaceholderTests.swift` | the shape census (declared set against the set asked for at the call sites), the reserved-space invariant, Reduce Motion, the chat exclusion | 417 |
| `Tests/WenshuAppTests/Editor/View/BookDocumentTests.swift` | the one read per book, the generation counter dropping a stale write, the card showing the same content while waiting | 344 |

Named together: `LoadingPlaceholderTests`, `BookDocumentTests`, `AppleSidebarMVVMSplitTests`,
`InspectorCardTests`, `InspectorRightColumnPushTests`, `InspectorCardLazinessTests`,
`KanbanViewTests`, `EmptyStateViewTests`, `ComponentIndexTests`, `DesignTokenTests` — 87 tests
in 8 suites at `37a8f04bf2`, and the first two re-run green on the merged tree at this closeout.

## 10. Independent verdicts

| card | tier | named sha | outcome |
| --- | --- | --- | --- |
| `t_6765a05c` | T2 | mechanism's first landing | approved (`review_gate.py` reads approved) |
| `t_498766b6` | T3 | rebased landing of the read moved off the main thread | approved at `a4cfc41a62` |
| `t_ecbf4bc8` | T3 | the first audit's three findings | approved at `6a8941d389` |
| `t_77e63bf6` | T3 | the mechanism's three loose ends | approved at `37a8f04bf2` |

## 11. OPEN ITEMS

1. The look check (gate 7.7) — an isolated copy of this tree (`MergedCheck1124`, bundle id
   unchanged, assembled from `.build/debug` in a scratch worktree under the gitignored
   `build/`) is running from `1a2327f795`; the acceptance is the human look at the tab switch
   and at each zone's waiting state, not the numbers in section 5.
2. Two cards sit in `ready` on this board and neither is this scope's: a `ci.yml` gate card and
   the `⌘⇧K` double-binding card. They stay with their owners.
3. The `design-sweep` hit named in section 6 belongs to the chat lane's file and is open there.
4. `173` worktree registrations are live on disk, and this session's two are removed by this
   closeout; the rest belong to other lanes and other sessions, and are not this session's to
   delete. Two of those lanes still carry commits that have not landed (`wt/citation-guard-widen-2026-11-24`
   and `wt/apple-api-2026-11-22`) — recorded here so the next reader knows they exist, not
   claimed as this scope's work.
5. The p95 of the tab switch's frame was NOT re-measured on the merged tree at this closeout.
   Section 5's after-row is the landing probe's walks and bytes, which is what the fix claims;
   a fresh timing run at this tree is still open.

## 12. What this record does not claim

It does not claim the whole board is empty, that the other sessions' lanes landed, or that the
chat tab switch is now measurably hitch-free at this tree — the load moved out of the frame and
the counters prove the walk count and the bytes, nothing more. It names the commits that are
not this scope's, and it publishes no count of itself.
