# Session close — the editor's tab strip has no double-click close (2026-11-19)

## 1. What was asked

The owner's ruling, given while the first round of this scope was already in
review: a double-click close on the editor's tab strip is not wanted at all.
Not "make it agree with the other close paths" — delete the path. The strip
closes a tab from the segment's own X (the selected tab) and from the
right-click menu (the tab the pointer names); a third path only duplicated
those two.

This supersedes the wording of the earlier scope card `t_8d594cc2`, which
listed the double-click as part of the required behaviour.

## 2. What the tree shipped before

`LabelSegmentedControl` (the shared AppKit control the editor's strip hosts)
attached an `NSClickGestureRecognizer` with `numberOfClicksRequired = 2` and a
gesture delegate whose only job was to refuse the gesture when the pointer was
over the X. `EditorTabStrip` wired the resulting `onDoubleClickSegment`
callback to its own close. Nothing else in `Sources` consumed that callback
(measured by `grep -rn onDoubleClickSegment Sources` on the pre-change tree).

## 3. Why it came back once (the rework's real subject)

Round one was reviewed at `ccf4443fa522ae89d53476e7daf25a6f652a5757` and came
back `changes_requested` (card `t_014a4e3f`, run 4576). The reviewer's own
words: "the CODE is right and I proved it, not read it". What failed was the
record, not the change:

- **R1** — `EditorView.swift:102-103` still described the strip as keeping
  "its own close path (= a double click on a segment)". One production comment
  still taught the deleted behaviour.
- **R2** — the card published a gate number the machine would not reprint. The
  four-suite filter was published as `53 tests in 4 suites passed`; on both the
  tip and the base it reads `53 tests in 4 suites failed with 12 issues`. The
  published run had been real (measured two hours earlier on the same commit) —
  the suite is load-sensitive, so the published gate was a coin flip.
- **R3** — the whole-suite claim "6 failures in the base and 6 in the tip, the
  same six" counted `recorded an issue` LINES, not distinct sites.

All three closed in `c58db7b06ada568008dac6abcfb34ee017f71052`, which round two
approved in nine minutes (card `t_f5f901e0`, run 4584).

## 4. What the change does

| File | Change |
| --- | --- |
| `Sources/WenshuApp/Shared/UI/LabelSegmentedControl.swift` | the `onDoubleClickSegment` callback, the `NSClickGestureRecognizer`, and the gesture delegate are removed; `Coordinator` is a plain `NSObject` again |
| `Sources/WenshuApp/Features/Editor/Store/EditorTabStrip.swift` | the callback that closed the tab is removed |
| `Sources/WenshuApp/Features/Editor/View/EditorView.swift` | the docblock names the two paths that remain instead of the deleted one |
| `Tests/WenshuAppTests/Shared/UI/PaneTabStripCloseTests.swift` | the delegate test is replaced by one absence guard with two assertions |
| `Tests/WenshuAppTests/Workspace/EditorViewIconMigrationTests.swift` | a stale comment corrected |
| `docs/agents/nfi.md` | the registry's LOC value for the test file |

The guard asserts an ABSENCE, because the requirement is an absence: the
control the REAL strip hosts (`hostedStrip(tabCount: 3, columnWidth: 240)`, so
the production `makeNSView` path, not a hand-made control) carries no gesture
recognizer, and neither production file names the deleted path any more.

## 5. Measured before and after

Every number names the tree it was printed on. Units are stated because a bare
count died on re-measurement once already (R3).

- `LabelSegmentedControl.swift`: 670 lines before, **590 lines** after
  (`wc -l`, the file ends with a newline).
- Owning suite: `swift test --filter 'PaneTabStripCloseTests'` = **29 tests in
  1 suite passed** (4.510 s on `c58db7b06a`; 2.031 s on the merged tree
  `124ce32757`; 1.833 s inside `pre_review_gate.py`).
- Guard bites: one line put back into `makeNSView`
  (`control.addGestureRecognizer(NSClickGestureRecognizer())`) = **29 tests in
  1 suite failed with 2 issues** at `PaneTabStripCloseTests.swift:916` and
  `:925`. Measured by the author before the card, and re-measured independently
  by both review runs.
- Deletion is complete: `grep -rn "onDoubleClickSegment\|NSClickGestureRecognizer"
  Sources` = 0 hits; in `Tests` the only hits are the guard's own assertions.
- No close-path sentence survives: `grep -rniE "double.?click" Sources |
  grep -iE "clos"` plus the CJK verb for "close" (kept out of this doc, which
  must stay zero-CJK) = 1 hit, and that hit is the word `closure` in
  `PreviewPaneCard.swift:42`'s `onDoubleClick closure` (= the card's OPEN path).
  The broader tab/strip grep returns 3 hits, all of them double-click to OPEN a
  tab from a pane (`AssetsPane.swift:211`, `CardOpenOps.swift:353`,
  `PreviewPaneCard+Body.swift:265`) — a different, still-live feature.

## 6. Gates on the MERGED tree

Run after the rebase onto `b0ba0e0e2b`, in the shared checkout at
`124ce3275727955162a896fa4d90657c334c3375` (the reviewed sha `c58db7b06a` and
the landed sha differ only by that clean rebase, which resolved nothing, so the
verdict still covers the change):

- `review_gate.py --card t_f5f901e0` = `approved` rc 0.
- `Scripts/merge-preflight.sh wt/dblclick-2026-11-19` = `CLEAN`.
- `ci_change_gate.py --base main~1 --check formatting` = ok, 5 changed Swift
  files; `--check pollution` = ok; `--check markdown-newline` = ok, 1 .md.
- `pre_review_gate.py --base main --card <the card body>` = every gate measured
  on this tree and green (build exit 0, the filter exit 0, CJK audit exit 0
  over 58 added lines, `verify-dead` exit 0 with 0 dead declarations, the
  registry's round-trip exit 0).

The CJK audit is comment-shaped: it greps a line's COMMENT part only, so on a
markdown file it scans nothing and still exits 0 (`no new CJK comment line
(0 added line(s) scanned)` was printed for this doc's commit). A tracked .md's
zero-CJK rule is therefore proved by the direct Han-range scan of the file
itself, which this record's commit carries: 0 occurrences in the range
U+4E00-U+9FFF, over `wc -l` = 246 lines. That gap is a gate defect in its own
right (= nothing in CI enforces rule 1.1 on markdown) and is listed in §11.

## 7. Attribution of the tree's red — an A/B, not a whole-suite run

The tree carries a family of timing-dependent suites. One filter over the seven
of them:

```
swift test --filter 'EditorTabStripOverflowTests|EditorTabTitleTests|PaneTabStripTitleTests|EditorPersistenceTests|AsyncDelegationRegistryTests|SidebarTreeReloadTests|ChatViewHistoryShortcutTests'
```

printed, back to back on `b0ba0e0e2b` (before the merge) and on `124ce32757`
(after it), the identical line `59 tests in 7 suites failed with 17 issues` at
the identical ten sites with the identical multiplicities:
`EditorTabStripOverflowTests:532` x5, `:582` x4, `:403`/`:435`/`:499` x1 each,
`EditorTabTitleTests:60`, `PaneTabStripTitleTests:476`,
`SidebarTreeReloadTests:189`, `ChatViewHistoryShortcutTests:35`,
`AsyncDelegationRegistryTests:104`. **This change moved zero test outcomes.**

Two whole-suite runs (`swift test --skip CSSearchableIndexSearchTests`) on the
same trees printed 19 issue lines at 12 sites and 7 issue lines at 4 sites, and
NEITHER printed a summary for the bundle that failed — a bundle that aborts
mid-run (a `swiftpm-testing-helper` signal 11 was recorded in an earlier
review's run) emits its issues and never its summary line. A whole-suite run on
this machine is therefore evidence of nothing about attribution; the same-filter
A/B minutes apart is.

## 8. The shipped binary carries it, and the owner's look is PENDING

The preview bundle is the one the owner looks at for a UI-touching ticket
(AGENTS.md 7.7). The recipe was never written down, which is why this section
records it end to end:

1. `bash Scripts/build-app.sh` from the merged checkout = `BUILD_RC=0`,
   `build/Wenshu.app/Contents/MacOS/WenshuApp`, 15:40 local.
2. `cp -R build/Wenshu.app build/MergedCheck.app`; rename the executable to
   `MergedCheck`; `plutil -replace CFBundleExecutable -string MergedCheck`,
   `CFBundleIdentifier -string com.wenshu.app.look`,
   `CFBundleName -string MergedCheck`.
3. `codesign --force --deep --sign - build/MergedCheck.app` = adhoc,
   `Identifier=com.wenshu.app.look`.
4. Its data copy stays `build/wenshu-look.ws`. The independent bundle id, the
   independent executable and the independent data copy are required: a second
   instance of `com.wenshu.app` restores the same saved window geometry and
   AppKit's update-constraints guard aborts BOTH processes.

Byte-level proof that this binary is the changed tree (`nm -a`, with the
pre-change binary kept as the positive control so a zero cannot mean "the tool
selects nothing"):

| binary | `onDoubleClickSegment` | `handleDoubleClick` | control `closeSegment` |
| --- | --- | --- | --- |
| preview built 2026-11-18 (tree HAD the path) | 20 | 4 | 46 |
| `build/MergedCheck.app` built from `124ce32757` | **0** | **0** | **62** |

- Which build: `build/MergedCheck.app`, from `124ce32757`, adhoc-signed.
- Owner's verdict on the running build: **NOT YET GIVEN**. The last look the
  owner took was at the build that still had the double-click.
- App left running: **no**. No instance of `com.wenshu.app.look` was alive when
  this bundle was rebuilt; the pre-change binary is preserved at
  `/Volumes/ANAN/.hermes/profiles/pocock/cache/scratch/MergedCheck-1118-control.bin`
  (= a scratch file, so it can be pruned; it is re-creatable by building
  `31b5c3929a` with the same recipe).
- The one command that completes it: `open
  /Volumes/ANAN/Engineering/wenshu/build/MergedCheck.app`, then close a tab
  twice as fast as possible — nothing should close on the second click, while
  the X and the right-click menu still close the tab they name.
- A sibling session's instance (`pid 83611`, from
  `.worktrees/wt-cover-menu-2026-11-19/build/Wenshu.app`) was running
  throughout; it is not this session's to touch.

## 9. What this scope cost on the board

The scope is a comment-and-deletion change. It spent five review runs and about
two hours of reviewer wall time, and the reason is worth recording because it
will recur:

- The machine rebooted mid-review (run 4523 `crashed`, "managed worker lost:
  EOFError"); the dispatcher requeued the card.
- The provider then hit its quota wall: runs 4528/4534/4540/4541 ended
  `rate_limited`, and run 4538 — alive for 84 minutes and 61 API calls deep
  into the review — died with exit 78 (`429 (2067)` then `403 Access to model
  denied`). A `rate_limited` outcome does not count toward the failure budget,
  so the card looped; three consecutive provider deaths blocked it, and the
  review lane unblocked it at 13:46 after re-probing the provider (HTTP 200).
- The card was created at the tier's 90-minute floor. The fix for the next one
  is in the tier tool's own guidance and in memory: a review card gets
  `--max-runtime 10800` at creation, because a requeue is a fresh session that
  re-reads the tree from zero. `t_f5f901e0` was created with 10800 and approved
  in nine minutes.
- Both cards were first subscribed with `--platform desktop`, which the gateway
  does not serve (= a dead row, `notify-list` still shows it subscribed). They
  were re-subscribed with `--platform local` and the dead rows deleted.

## 10. Scope's commits, and the ones that are not

- `31b5c3929a` — the previous scope's landed work (the X, the conditional
  collapse, the right-click menu). Not this ticket's change; it is this
  ticket's base.
- `ccf4443fa5` → `c58db7b06a` → landed `124ce32757` — **this scope**: one
  ticket, one commit, rebased clean onto `b0ba0e0e2b`.
- `b0ba0e0e2b` — a sibling session's sidebar work (card `t_803f54f2`). It was
  already on local `main`; pushing it to the remotes with this scope's commit
  was maintenance of the shared server state, not authorship.
- The closure doc's own commit, and this doc's registry row in the same commit.

Read the current tip with `git rev-parse main`; a doc cannot name the tip its
own commit creates. Server truth: `git ls-remote origin refs/heads/main` and
`git ls-remote old-origin refs/heads/main` both read back the landed sha at the
time of writing.

## 11. Open items left behind

1. **The owner's look at the double-click-free build is PENDING** (§8). Nothing
   else blocks it; the bundle is built and proved.
2. **The timing-dependent suite family** (§7): ten sites that flip with machine
   load, red on the tree itself, and NOT filed as a card, because the board
   spawns exactly one profile (`kanban.dispatch_profiles: [wenshu-review]`) so a
   diagnostic card assigned to the developer lands in `skipped_nonspawnable`. It
   needs either an owner order or in-session work. Until then no card should use
   those suites as a gate.
3. **`t_a43d3e2f`** (open, assigned to the developer, created by the review
   lane): `Scripts/merge-preflight.sh` reads `UNREVIEWED` when the card the
   BRANCH NAME claims answers `contract_error`, instead of falling through to the
   sha that carries the approving verdict. A ruling on which of its three options
   is the house rule is owed; the durable fix is option 3.
4. **The 600-line cap** on the strip's two files stays sibling scope (AGENTS.md
   6.6 is DEFERRED per ADR-0025).
5. **`scratch/lib/verdict.md`** is an untracked file in the shared checkout from
   another session's card. Left in place; it is not this session's residue.
6. **The board still holds ~312 `desktop`-platform subscription rows** from
   before the mechanism was measured. Not this session's to rewrite.
7. **The zero-CJK rule (AGENTS.md 1.1) has no gate on markdown.** The CJK audit
   reads a line's comment part, so a `.md`-only commit passes it with exit 0
   while carrying Han characters. The fix is a check over the added lines of
   every tracked text file, not only `//` comments. This record caught itself
   doing exactly that: the first draft of §5 quoted a Chinese search term, and
   the draft was wrong twice over (= the term belongs in the closed card's
   command, not in an artifact the rule covers, and the audit never saw it).
