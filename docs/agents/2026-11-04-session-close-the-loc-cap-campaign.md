# Session closeout: the 600-LOC campaign reaches the chat, and the comment policy's matcher stops lying

## The scope, and what it produced

This session took the production tree's file-size debt and the tree's comment
debt, and it fixed the two CI steps that could not fail. Everything below is
measured on the merged tree, not on a branch.

| the requirement | the commit that carries it | the independent verdict |
| --- | --- | --- |
| The CI's build and test steps could not fail | `f4029c1888` | the review card's gate (a harness proves the mutation bites) |
| The tool registration waited on a clock | `d00e56fca4` | the review card's gate |
| Seven production compiler warnings | `049d42b4ef` | the review card's gate |
| The kanban tools' tests shared one repository | `8efea9a173` | the review card's gate |
| The help document is its own file | `83a2b120bf` | approved |
| The reference store's fallback is its own file | `278e0270c8` | approved |
| The reference library's classification is its own file | `b1c5d10aa1` | approved |
| The sidebar's row lookup is its own file | `e039fc555e` | approved |
| The settings' provider and model panes are their own file | `906079ac0d` | approved |
| The chapter actor's tool-protocol face is its own file | `853290031e` | approved |
| The entity actor's tool-protocol face is its own file | `03ac3e9684` | approved |
| The outline actor's tool-protocol face is its own file | `10725edba9` | approved |
| The import router's tool-use loop is its own file | `96faf0eed6` | approved (second request) |
| The app delegate's drain loop is its own file | `2e23aea130` | approved (second request) |
| The preview card's body is its own file | `17b4f794c3` | approved |
| The OpenAI wire is its own file | `63b1f4669d` | approved |
| The inventory's counts name their methods | `8333b13181` | approved (sixth review) |
| The registry's row is the table's last row | `123839e987` | the driver's byte-for-byte check |

The census, re-derived on the merged tree by `Tools/wenshu-devtool/inventory-measure.py`:
**508 production files, median 155 LOC, p90 451 LOC, 4 files over the 600-LOC cap**
(= the baseline's 18, and the baseline's median 150.5 / p90 470).

## The three defects, and what each one was

**The CI's two steps could not go red.** The build step piped into `tail`, so
the pipeline's exit status was the pipe's; the test step read only the
Swift Testing summaries, so a failure that only the XCTest bundles reported
was invisible. Both are fixed and both now have a harness that proves the
mutation bites: the build step captures the first command's status, and the
test step reads every target's summary AND the XCTest failures AND the
`Note: Some test targets reported failures:` trailer.

**The tool registration waited on the clock.** A registration that took longer
than sixty seconds was treated as a failure, so a loaded machine read an empty
registry. The wait is now on the registration's own event; the sixty seconds
survive only as the backstop for a registration that never comes.

**The certification of the comment policy read green while the tokens were
there.** The inventory tool measured the ticket ids with
`\b[A-Z]{1,3}\d{2,4}\b`, which cannot see the tree's own forms (`T4-`, `T8-`,
`P1-02`, `A112`, `Q112`, `round-19`) and which counted the collapse receipts'
own `A112`/`A115` labels as ticket references. The row therefore read
"base 468 -> tip 0", where the true reading was "base 71 -> tip 2". The
matcher is now form-complete and the receipts are the receipts' measure; the
tool prints its own method, so the row can be reproduced.

## The gates on the merged tree

- `swift build --build-tests`: exit 0.
- The deterministic test core: **three** assertion sites, and they are the
  tree's own pre-existing ones (`ChatViewHistoryShortcutTests.swift:35`,
  `EditorTabTitleTests.swift:60`, `AsyncDelegationRegistryTests.swift:104`).
  They fail the same way on the tree before this session
  (`f224ad6f26`), so they are the base's debt and not this session's.
- The XCTest side: 56 suite lines, every one with zero failures.
- `verify-dead.py`: ALIVE 111, PARTIAL 4, **DEAD 0**.
- Every split's own diff passed the formatting gate (exit 0), the pollution
  gate (exit 0) and `verify-dead.py` before it was reviewed, and every split's
  own named suite passed on the rebased tree.

**The whole suite did not complete on the merged tree.** The run sat at 0.0%
CPU for nine minutes in the `WenshuAppTests` target and was stopped (it is
this session's own process, so it was this session's to stop). The tree's
whole suite hangs this way intermittently, in Core Spotlight, and the skip
that was added for it does not cover the suite that actually indexes. So no
whole-suite count is quoted here: the number that is quoted is the
deterministic core, measured by running the three owning suites alone.

## The open items, and who owns them

| the open item | its state | the card that owns it |
| --- | --- | --- |
| The comment policy (= the eight densest files carry their reasons again) | the branch is `wt/comment-policy` at `c3781bbe9a`; the fourth review round is in flight | `t_c829bec2` |
| The conversation loop's turn, conversation and streaming paths | delivered and independently verified; the review card is queued | `t_e011e210` |
| The layout tree's operations | delivered and independently verified; the review card is queued | `t_84a81f55` |
| The chat turn | delivered and independently verified; the review card is queued | `t_13a57201` |
| The chat column's rendering and its hidden shortcut buttons | delivered and independently verified; the review card is queued | `t_c2525070` |

The four splits cannot land before the comment policy does: their branches are
based on the comment policy's tip, and a rebase onto `main` before that lands
would replay the comment policy's commit and conflict with it. When the
comment policy lands, each branch is rebased onto `main` (its commit is
skipped, the diff's content is unchanged, and the verdict still binds), the
registry row is appended at the table's new end, and the branch is
fast-forwarded.

The four over-cap files that remain are exactly these four:
`ConversationLoop.swift` (1109), `ChatSessionViewModel.swift` (942),
`ChatView.swift` (892), `LayoutTreeState.swift` (773).

## What the next session should read first

The handoff file `scratch/handoff-chat-splits.md` holds each branch's commit,
its promotion list, the registry row's text and the landing order. The three
move-proofs are in `scratch/verify-move3.py`: the moved cluster comes from the
diff's deleted lines (a line-matching subsequence cannot tell one brace from
another), a promotion is derived from both sides of the seam (the members that
lose `private` in the NEW files never appear in the parent's diff), and a
split into two new files is measured as a multiset over the two bodies.

## What is not this session's work

The board client's documentation and the devtool's tooling landed on `main`
from the lane that owns them (46 of the last 90 commits). They are named here
so the landing table is read correctly: the rows above are this session's, and
the board client's rows are the other lane's. Their commits are on `main` and
on both remotes, and this session pushed them as maintenance when it pushed
`main`.
