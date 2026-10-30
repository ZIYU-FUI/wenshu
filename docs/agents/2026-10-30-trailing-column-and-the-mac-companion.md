# 2026-10-30 Trailing Column and the Mac Companion — closeout

Status: merged to `main` and pushed to `origin` and `old-origin`. This
document records the ANCESTRY, not the tips (= the tips move as other lanes
land; the ancestry does not).

Four commits carry this scope, and each is an ancestor of `main`:

| Commit | Subject |
| --- | --- |
| `9d67957806` | feat(editor): the todo page lists the todos the assistant wrote |
| `51b5d4641` | feat(kanban): the task board lives in the trailing column, stacked vertically |
| `d48a30770` | feat(companion): the app listens on the loopback, and answers the phone |
| `10214b2ec` | fix(companion): the token read is one task, and a split request is read again |

One devtool commit came out of the same session and is not part of the
product scope: `4b30995b2` (the tier tool reads the board's run history).

Cards: `t_f73b3afd` (the todo page), `t_e196a5a9` (the board), `t_a6449dd8`
(the companion service). Each carries an approving independent verdict from
`wenshu-review`, and the reviewer is never the implementer.

## The landing table

One row per original requirement. The commit that carries it, the
independent verdict that cleared it, and the SERVER-side proof it is on the
remote (= a push that reported success on one remote says nothing about the
other). The two remotes read the same sha, and every commit below is an
ancestor of both.

| Requirement | Commit | Verdict | Server truth |
| --- | --- | --- | --- |
| The todos the assistant wrote reach the trailing column | `9d67957806` | `t_f73b3afd` run 1960, `wenshu-review`, `review_outcome=approved`, round 1 | ancestor of `origin/main` and `old-origin/main` |
| The task board moves into the trailing column, stacked vertically | `51b5d4641` | `t_e196a5a9` run 2207, `wenshu-review`, `review_outcome=approved` | ancestor of `origin/main` and `old-origin/main` |
| The Mac companion answers the phone on the loopback | `d48a30770` | `t_a6449dd8` run 2213, `wenshu-review`, `review_outcome=approved`, round 1 | ancestor of `origin/main` and `old-origin/main` |
| The companion's token read is one task, and a split request is read again | `10214b2ec` | the same run 2213 (both commits are the branch the reviewer cleared) | ancestor of `origin/main` and `old-origin/main` |
| The board's book-resolution helper is covered again | `55f9fcbe5` | the devtool fix's own suite (four cases, three mutations caught) | ancestor of `origin/main` and `old-origin/main` |
| The tier tool reads the board's run history | `4b30995b2` | the devtool fix's own suite (four cases, three mutations caught) | ancestor of `origin/main` and `old-origin/main` |
| The closure record | `da31e0149` | this document | ancestor of `origin/main` and `old-origin/main` |

**Commits that are NOT this scope's, and that the pushes carried along.**
The branch was rebased onto `main` and fast-forwarded, so the pushes also
carried the commits that `main` already held. These are other lanes' work,
named here because the boss reads the landing table and needs to know who
owns each row: `0c7fe47e3` (the client's own rules), `410621062` (the
welcome page's wordmark), and the mobile line's `dd3164b77`,
`a148fcb7d`, `1399e98c6`, `cd3c6caa2`, `45f11fbe7`, `8f9ddd025`,
`88a1aa647`, `1a8129b48`, `4351d48db` (= the mobile line's own commits, authored by another
engineer), plus
`145d70555` (the cap floor rule, = a devtool rule that predates this
scope).

## The trailing column

The trailing inspector column carries three pages, switched by the
segmented control in its chrome band: the todos, the sub-agent tasks, and
the task board. This session delivered the first and the third.

### The todo page

`Sources/WenshuApp/Features/Editor/View/InspectorTodoPageView.swift` lists
the todos the assistant wrote. It reads `WSTodoRepository` (= the same
repository the agent's `TodoStoreTool` writes through), shows the
outstanding rows first and the finished ones after, and renders the
outstanding count in the header from the SAME snapshot the rows come from,
so the count and the rows cannot disagree. The state rides on a symbol,
never on dimming the row.

The reviewer measured every acceptance criterion against the tree rather
than from the handoff: the rows come from one `WSTodoRepository.list()`
read, the compiled bundle's `zh-Hans.lproj/Localizable.strings` carries
`inspector.todo.queue.count` = "%d 条排队", the new suite drives the app's
OWN `TodoStoreTool` into a throwaway in-memory container and asserts that
the written todo appears, is counted, leaves the outstanding set when
finished, and is dropped when removed.

### The board

The board moved out of its own window into the trailing column's task page
(`Sources/WenshuApp/Features/Editor/View/InspectorTaskPageView.swift`),
and the standalone window is gone: the window file and the test file
that covered it are both deleted from the tree, and the `WindowID.kanban`
constant no longer exists. The board's columns stack vertically
(`ScrollView(.vertical)` around a `VStack`) and each column fills the width
the trailing column gives it (`.frame(maxWidth: .infinity)`, = the 256-point
`kanbanColumnWidth` that fitted the old window no longer applies).

The board follows the app's shared selection: `KanbanView` takes
`init(workspaceUI:)`, watches `workspaceUI.sidebarSelection`, and writes
the book that selection names into the shared `BookStore.selectedBookId`.
The helper that maps a selection to a book (`KanbanView.bookId(for:)`) came
back with the board, because the deleted window had owned it.

Two consequences of that design are worth knowing, and the reviewer named
both. Before this change the shared `BookStore.selectedBookId` had NO
production writer at all (= `BookStore.reload(bookId:)` and
`WenshuLibrary.setSelectedBook` have no callers), so the editor's
`LinkedDocumentBoardSection` and `EditorActions` always saw nil. Now the
board writes the sidebar's book into the shared store, so those two editor
paths can resolve a real book. And the board's own header picker now moves
the APP-WIDE book selection rather than a private one.

### The order card that made the difference

The board card was the second attempt at the same scope. The first body
named a seam that no longer existed (= the board's own window block in
`AppRootScene.swift` had already been deleted by the previous round), and
the worker spent every run re-deriving facts the body should have carried:
five runs, 104 / 92 / 82 / 41 / 30 reads against 1 / 0 / 0 / 0 / 0 writes,
each cut at 1.001-1.007 of the cap.

The rewrite named the real seam (= `InspectorTaskPageView.swift:31`, where
`KanbanView(workspaceUI:)` cannot compile because `KanbanView` declared
only `init()`), the property and initializer to add, the selection-to-book
helper to write (with the six `SidebarItem` cases named, and the note that
`referenceLibraryRoot` no longer exists = the deleted window's version of
that helper does not compile against today's enum), and the remaining three
seams with their exact text. The card then landed in one run.

## The Mac companion service

`Sources/WenshuApp/Features/Companion/` adds a service inside the running
app process: a loopback listener, a device token in the Keychain, and the
two routes the phone needs to start. `WenshuAppDelegate` starts it
(`CompanionService.shared.start()`, line 380) and stops it (line 478), so
the port does not outlive the process.

The reviewer proved the four claims with its own probe against the real
listener over a real socket, NOT by the branch's own suite: the listener
holds the port on `127.0.0.1` only (free on every other IPv4 of this host,
connects refused); the ping body is exactly the capabilities and the
version, carrying no token, no path and no home directory; every non-ping
route AND an unknown path answer 401 with the single field
`{"error":"unauthorized"}`; and the token goes through `KeychainOps` under
its own service and account, with no `UserDefaults` and no file.

The second commit fixes two defects the first one carried. The device
token was read from the Keychain off the main actor, and two requests that
arrived together each started their own read; the second published its
value over the first, so a pairing that landed while a read was in flight
was overwritten by the older value and a revoked device could keep working
for the length of one read. The read is now ONE task, and it publishes only
if nothing else owns the session while it runs. And TCP keeps no message
boundaries, so a request can arrive in two segments; the read that brought
the first segment delivered it and no read was pending, so the rest was
never read. The read is armed again when the buffer does not hold a whole
request.

## Gates on the MERGED tree

Measured on `main` after the merges, not on the branches:

- `swift build` exits 0.
- `swift test --filter WSTodoRepositoryTests` = 6 tests in 1 suite passed.
- `swift test --filter InspectorViewShellTests` = 10 tests in 1 suite passed.
- `swift test --filter KanbanViewTests` = 8 tests in 1 suite passed.
- `swift test --filter CompanionServiceTests` = 12 tests in 1 suite passed.
- The design sweep: 24 suites. All pass except two issues that are NOT
  from this scope: the `PreviewPane` 64x64 hero-card boundary exception
  moved to `PreviewPaneCard.swift` while the sweep still reads the old
  path (= the Editor feature extraction), and `SidebarRowView`'s naked
  `.frame(width: N)` was reported against a file whose current copy has
  none. Both files were last changed by other commits, before this scope.
- `python3 Tools/wenshu-devtool/verify-dead.py` = 102 ALIVE, 4 PARTIAL,
  0 DEAD.
- CJK audit on the added lines: `51b5d4641` = 0, `d48a30770` = 0,
  `10214b2ec` = 0. `4b30995b2` = 2 lines, and both are the card-type tag
  literals in a test fixture (`[审核]`, `[工单]`), which the tier tool
  accepts only in that spelling (= the tool's tag table is Chinese and the
  board's cards are written in Chinese).

## Not done, and why

**No in-person visual proof of the trailing column.** The gates for this
scope are build, the named suites, the design sweep and the dead-code
check; the board's own layout in a narrow trailing column was never
looked at by a person. The boss verifies UI in person, and that step has
not happened for this scope.

**Three follow-ups the reviewer filed, none of them a blocker:**

1. `WindowOpenButton` has no production caller left (= the kanban toolbar
   button was its last one). `verify-dead.py` still reports it ALIVE,
   because the test suites read it.
2. `ChromeMainToolbar.swift`'s own header comment still says "the row
   carries the kanban window button and export" and names kanban among the
   registered window ids, and `ComponentIndex.md` still says "the 11
   windows: kanban + todo + ...". Both are stale prose in files this scope
   touched; both were already stale before these commits.
3. Deleting the window's own book-selection test removed the only test
   of the book-resolution helper, and no replacement was added, because
   the kanban view's own suite was outside the card's write set.
   `KanbanView.bookId(for:)` is a non-private static and remains directly
   testable.

**One defect the reviewer found and filed as its own card
(`t_ee9ed1f1`):** the service arms a read in two places on the keep-alive
path, so every request leaves one `NWConnection.receive` pending forever
(= 5000 keep-alive requests leave 5001 outstanding). It changes no answer
and breaks no security claim, so it did not block this landing.

## The devtool fix in the same session

`ticket_tier.py` derives a card's type from its body AND the board, and one
of the judgements needs the card's run history: a card whose every run
carries the reviewer's profile has no implementation phase, and that is
what separates a review card from a build card that happens to be sitting
in the review lane. The derivation had that judgement, but the reader
never gave it the evidence: `hermes kanban list --json` does not carry a
card's runs, so the runs were always `None` and the judgement could never
fire.

The consequence was a card the board itself calls a review card being
derived as a build card = it owed an independent verdict it was about to
give, its declared type was reported as a contradiction against its own
body, and it paid the build lane's cap instead of the review lane's 3600 s
floor. The runs are now read from the board's own record, with the board
database resolved the way the review gate resolves it. The suite gained
four cases for it, and the mutations are caught: dropping the read,
reading the wrong table and dropping the profile each fail three cases.
The whole devtool suite passes (14 files).
