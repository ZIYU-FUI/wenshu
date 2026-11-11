# Session closeout — the chat zone's session tab bar

The scope: the chat area had no top bar at all. The conversation the user
was in was one bare `BookID?` on the view model, so it could name neither
the repository conversation nor the reference-library conversation, and the
directory tree could not map onto it. There was no way to see which
conversation was open, and no way to move between a book's conversations.

This is the session closeout of record for that scope: the symptom, the
root cause, the fix, the measured before/after, the tests, and the open
items left behind.

## The scope's commits, and the ancestry

The scope is ONE commit on `main`:

| commit | carries |
| --- | --- |
| `72c3f5eb3de069025fc833283a7faa7de8b695cb` | the whole scope (= 29 files, = +2562 / -160) |

`72c3f5eb3d` is the tip of `main` at the moment this record was written, and
this record's own commit sits ON TOP of it. = ⇒ So the doc cannot name its
own sha (= writing it in would change the sha it names), and a reader who
wants the landed tip runs `git rev-parse main`. = The landed tree is the
scope's tree: `git show --stat 72c3f5eb3d` lists exactly the scope's 29
files.

The scope was reviewed at `f79a21344e7188d81afbed597a060e5e1196bdcf`
(= the same edit, = before it was rebased onto a moved `main`), and the
verdict on that sha is on card `t_503ce8df` (= `approved` by
`wenshu-review`). = ⇒ The two shas carry the SAME change identity:
`review_gate.change_id` reads `56c84dd9b80c4d0cdea164a9c2ddecbe622f719e680a42e286356ba9b3749054`
for both, = and the gate matched the card by that identity after the
rebase (= "matched by change (= the branch was rebased; the change is the
same)").

The scope's base is `225366259b` (= the tree the change was measured
against).

## The symptom, the root cause, and the fix

**The symptom.** The chat area offered no way to see or switch the
conversation, = and a book's conversation and the book's own lifecycle were
two unrelated things: renaming a book left its conversation titled with the
old name, = and deleting a book left its conversation (= and every message
in it) on disk.

**The root cause, in three parts.**

1. There was no scope concept. = One `BookID?` cannot name the repository
   conversation, = cannot name the reference-library conversation, = and
   cannot be mapped onto a tree row.
2. The tree and the chat were two views over nothing. = The asset pane
   already read `workspaceUI.sidebarSelection`, = but the chat area had no
   bar at all, = so the two surfaces could not disagree — they simply did
   not exist together.
3. The rules that say which books the user may change lived in ONE place
   (= the sidebar's menus). = A rule that only hides a menu item is a rule
   some other caller walks past: = the agent's book tool could rename the
   app's own help document while the menu hid the button.

**The fix.**

- `ChatScope` is the one scope concept now: `enum ChatScope` (= `.repository`,
  `.library`, `.book(BookID)`) + `struct ChatScopePage`. = It owns the page
  list, the tree-row mapping in both directions, and the session key per
  scope. = ⇒ The bar's pages come from the CURRENT book collection (= not
  from the session history), = so a new book gets a page the moment it is
  created and a deleted book leaves no page behind; = the help book
  contributes none (= it is the app's own document, = it is read-only, = it
  is not a conversation the user drives).
- `ChatZoneTabBar` renders the pages with the house's `LabelSegmentedControl`
  (= an AppKit `NSSegmentedControl` in the `.valueSelection` role) inside a
  horizontal scroll view (= the same shape the editor's tab strip uses, =
  and the scroll is what keeps a growing page list inside the chat column).
- The bar and the tree are two views over ONE selection (=
  `workspaceUI.sidebarSelection`), = so they cannot disagree, = and the
  asset pane keeps its rules for free (= it already read that field; = the
  pane's filtering was NOT touched by this scope).
- A book and its conversation move together, = because they are two views of
  the same thing: renaming a book renames its conversation (= the same
  session, = the new title, = the identity and the history kept), = and
  deleting a book takes its conversation and its messages with it. = The
  rules live in ONE service (= `BookSessionLifecycle`) because they are
  reached from TWO doors (= the sidebar's menus and the agent's book tool).
- The delete names the child rows itself instead of leaving them to the
  cascade rule: = the relationships declare `deleteRule: .cascade`, = but
  `append` writes the denormalized `sessionID` string and never sets the
  child's inverse (= so `WSChatMessage.session` is nil on every row), = and
  a cascade with no inverse to walk never fires. = MEASURED: the
  delete-then-read-back test failed against the cascade-only implementation.
- The help book is read-only and the default shelf's name belongs to the
  app, = and both rules hold on EVERY path (= the sidebar's menus, = the
  library mutation API, = the filesystem, = the editor entry point, = the
  editor's own auto-save, = and the agent's write tools), = because a rule
  that only hides a menu item is a rule that some other caller walks past.
  = The default shelf is still deletable (= only its NAME is the app's).

## The new files, and what each one owns

| file | LOC | owns |
| --- | --- | --- |
| `Sources/WenshuApp/Features/Chat/Model/ChatScope.swift` | 211 | the scope concept, the page list, the tree mapping, the session keys |
| `Sources/WenshuApp/Features/Chat/View/ChatZoneTabBar.swift` | 65 | the bar (= the house control, in a horizontal scroll view) |
| `Sources/WenshuApp/Features/Library/Service/BookSessionLifecycle.swift` | 175 | the protected identities, the read-only rule, the book-to-session movement |
| `Sources/WenshuApp/Features/Editor/Service/EditorReadOnlyGuard.swift` | 74 | the ONE rule the editor's two doors ask |
| `Sources/WenshuData/Sources/WenshuData/Repositories/WSChatRepository+BookSessions.swift` | 139 | the store's book-to-session movement, = the child rows named explicitly |
| `Sources/WenshuApp/Features/Library/View/SidebarServiceMutation+References.swift` | 84 | the sidebar's reference mutations (= split out so the mutation file stays under the cap) |

## The measured before/after

**The whole suite, on the LANDED tree, against the base's own run** (= the
failure SET, = not a count: = a count moves with the machine's load):

| | failures | the set |
| --- | --- | --- |
| base `225366259b` | 5 | `AsyncDelegationRegistryTests.swift:104`, `ChatViewHistoryShortcutTests.swift:35`, `EditorPersistenceTests.swift:253`, `EditorPersistenceTests.swift:259`, `EditorTabTitleTests.swift:60` |
| landed `72c3f5eb3d` | 5 | the same five, byte-identical |

`python3 Tools/wenshu-devtool/swift_test_compare.py` on those two logs
prints "the tip introduced NO new failure" and exits 0. = ⇒ The three
deterministic sites fail on BOTH trees, = and the two load-sensitive ones
(`EditorPersistenceTests.swift:253` and `:259`) pass alone on both trees.

**The gates, re-run on the MERGED tree** (= `main`, = not the branch):

| gate | result |
| --- | --- |
| `swift build` | `Build complete!` |
| the scope's own suites (= 7) | 61 tests in 6 suites passed, 0 failures |
| the design sweep (`swift test --filter 'Sweep'`) | 56 tests in 21 suites passed, 0 failures |
| `python3 Tools/wenshu-devtool/verify-dead.py` | ALIVE 124, PARTIAL 4, DEAD 0 |
| `ci_change_gate.py --base 225366259b --check formatting` | "the change adds no unformatted line", exit 0 |
| `ci_change_gate.py --base 225366259b --check pollution` | "the change adds no forbidden vocabulary", exit 0 |
| `nfi-loc-check.py --base 225366259b` | "every rewritten file's row carries its own count (11 rows)", exit 0 |
| `nfi-split.py --check` | PASS |
| the CJK audit (= gate 7.5) | "the change adds no NEW CJK" |

**The live application** (= the Accessibility tree, = read only, = no
synthetic events): on the app built from `8840d384f42bbc360dc0f287f78982b6581b58ed`
the bar's three segments read the repository page, = then the one ordinary
book's page, = then the reference-library page; = and the help book's page
was ABSENT (= the help title appeared 0 times in the whole tree). = ⇒ The
segment labels are the app's localized titles, = so the tree reads them as
the repository conversation, = the book's own title, = and the
reference-library conversation. = ⇒ Since that sha the bar's
rendering code changed ONLY by formatting: = `git diff -w 8840d384 --
Sources/WenshuApp/Features/Chat/View/ChatZoneTabBar.swift
Sources/WenshuApp/Features/Chat/Model/ChatScope.swift
Sources/WenshuApp/Features/Chat/View/ChatZoneView.swift` shows only
`case .book(let x)` -> `case let .book(x)`, = one removed redundant
`@ViewBuilder`, = one wrapped property body, = and one trailing comma.

## The tests

| suite | cases | what it holds |
| --- | --- | --- |
| `ChatScopeTests` | 17 | the page list (= the repository page, = one page per ordinary book, = and the library page, = in that order); = the help book contributes NO page; = the tree row and the page name each other, = and the round trip is the identity for all three scopes |
| `BookSessionLifecycleTests` | 15 | the identities are compared as ids (= never by the localized title); = renaming a book renames its conversation and the session keeps its id; = deleting a book deletes its session, = every session under it, = and its messages; = another book's session is untouched |
| `BookProtectionMutationTests` | 8 | the permission matrix through the sidebar's OWN mutation layer (= the door the user's right-click menu opens): = the help book cannot be renamed and CAN be deleted; = the default shelf cannot be renamed and CAN be deleted; = an ordinary book renames; = and a removal that FAILS leaves the book in the shared list |
| `EditorPersistenceReadOnlyTests` | 7 | the editor's own WRITE path refuses a read-only book: = a RESTORED tab (= no scope) whose path is in the help book is refused with the file untouched; = an ordinary book's document still saves; = and the auto-save leaves the tab DIRTY when the save is refused or when the write failed |
| `SidebarBookListSyncTests` | 5 | the PRODUCTION door keeps the shared list current: = a created book gets a page at once, = a renamed book shows its new name, = and a deleted book leaves no page behind |
| `SidebarCreateDeleteRenameTests` | 18 | the sidebar's existing mutation contract, = with the default shelf's deletion expectation updated to the rule the boss ruled |

**EACH CLAIM THAT CARRIES A RULE HAS A CASE THAT CAN FAIL WITHOUT THE
FIX** (= the cases were measured RED against the broken shape):

- "a removal that FAILS leaves the book in the shared list" = FAILS on the
  tree with the `defer` (= and the `defer` ran on every exit path, = so a
  removal that failed dropped the book from the list anyway).
- "a RESTORED tab whose path is in the read-only book is still refused" =
  FAILS when the guard's path key is removed (= 4 issues in the suite).
- "the auto-save leaves the tab DIRTY when the save is REFUSED" and "...when
  the write FAILED" = FAIL when the auto-save marks the tab clean
  unconditionally, = and the failed-write case fails on its own when
  `save()` returns the path after a failed write.

## The review chain

Five rounds on one branch, = and every round's finding was a real defect
in the tree at that round's sha:

| round | card | sha reviewed | verdict | what it found |
| --- | --- | --- | --- | --- |
| 1 | `t_6bada246` | `8840d384f42b` | changes_requested | F1: the bar's page list read a collection the user's own door did not write (= no page for a book the user had just created, = and a page for a book just deleted) |
| 2 | `t_3ab7bae8` | `970c631adbd8` | changes_requested | F2: the split left the doc blocks behind; = F3: two registry rows were glued with `||`; = F4: the `defer` forgot a book whose removal FAILED |
| 3 | `t_1e87441b` | `0d6c22991981` | changes_requested | F5: the editor's read-only guard's key died when a tab was restored from a relaunch (= the app's own help document could be overwritten); = F6: a failed write reported success and marked the tab clean; = F7: three doc blocks still advertised the removed default-shelf delete guard |
| 4 | `t_89c61671` | `0ff17c53fd5f` | changes_requested | F8: three doc blocks still advertised the rule the change had just replaced (= the guard's file header, = the write path's comment, = and the registry's row) |
| 5 | `t_503ce8df` | `f79a21344e71` | **approved** | = the delta was three text edits, = verified with a third arm |

Each card keeps its own verdict, = because the two shas are two different
trees; = the closing verdict and its numbers are on the card whose branch
landed (`t_503ce8df`).

## The landing

`Scripts/land_card.sh t_503ce8df wt/teb-chat <the gates>` printed
`RESULT: LANDED (t_503ce8df) sha=72c3f5eb3de069025fc833283a7faa7de8b695cb`.

**The server-side proof** (= `ls-remote` per remote, = not the local ref):

| remote | main |
| --- | --- |
| `origin` (= gitcode.com:ZIYU1983/wenshu) | `72c3f5eb3de069025fc833283a7faa7de8b695cb` |
| `old-origin` (= github.com/ZIYU-FUI/wenshu) | `72c3f5eb3de069025fc833283a7faa7de8b695cb` |

**The commits this push carried that are NOT this scope's** (= a sibling's
work, = pushed as maintenance of the shared server state, = not
authorship): `7851ccb3fc` (= the literal mask), `a900af5559`, `1730401c6a`,
`fb18cd9fac`, `3c9b23df8b` (= the sibling's closure record and its
corrections), `f0bfcedb42`, `52c6016cea`, `d893480191`, `f4f0c3ed40`
(= the word-count reader's scope). = ⇒ The scope's own contribution is the
single commit `72c3f5eb3d`.

**One thing the landing taught that the skill tree now carries:** a rebase
that REORDERS a shared file changes the CHANGE's identity (= `git patch-id`
hashes the diff's lines in order), = and the registry is where that happens
(= every card appends rows to it, = so a rebase re-applies "append N rows at
the end" onto a table that grew, = and the rows land mid-table). = ⇒ The
landing's first attempt was refused by the gate with "NO REVIEW CARD names
the sha this branch points at" = for a branch that WAS reviewed; = the fix
was to rebuild the registry from `main`'s copy and re-apply this scope's own
edit, = so both diffs carry the same lines in the same order and the two
change ids match.

## The boss's own look (= gate 7.7)

Gate 7.7 is the boss's step, = not a screenshot and = not the worker's. = ⇒
The record of what was looked at, and what was found:

- **Which build was reviewed:** the Accessibility proof was taken on the app
  built from `8840d384f42bbc360dc0f287f78982b6581b58ed`, = and its bundle
  uuid was `4609DD1C-77CD-3A46-FDE49817BB36`. = The bar's rendering code
  has changed since ONLY by formatting (= the `git diff -w` above).
- **The boss's verdict on the running build:** NOT YET GIVEN for the landed
  build. = The live instance still holds that earlier binary in memory, = and
  terminating it was refused by the tool's safety policy (= "the user did
  NOT consent"), = and a second instance against the user's own library was
  not launched (= two instances on one SwiftData store is a risk no reviewer
  needs). = ⇒ So the boss quits the stale instance, = launches the landed
  build, = and looks: = the bar's segments should read the same three names
  (= the repository conversation, = one page per ordinary book, = and the
  reference-library conversation).
- **Whether the app was left running:** YES (= a stale instance, = from the
  earlier build, = whose bundle directory was removed with the development
  worktree, = so it must be quit rather than reused).

## The open items

| item | state | owner |
| --- | --- | --- |
| the boss's look at the landed build (= gate 7.7) | open | the boss (= one quit and one launch, = and the three segment names) |
| the stale app instance (= pid 194, = from the earlier build) | open | the boss (= it must be quit; = it cannot be terminated from here, = because the tool's safety policy refused it) |
| `AppState.closeTab` marks the tab clean after a save whose result it ignores | unfixed, = pre-existing, = NOT this scope's diff | a future card (= `AppState.swift` is not in this scope) |
| `saveDraft` in `EditorViewEditHelpers.swift` marks the tab clean before saving | unfixed, = pre-existing, = no production caller | a future card |
| `EditorPersistence.save`'s /tmp fallback reports a failed write as a success | fixed in this scope (= it returns nothing when the write did not land) | closed |

## The lessons, and where they were persisted

| lesson | where it lives now |
| --- | --- |
| a review card is created with `--max-runtime 10800` (= double the review lane's floor), = because a run that hits the cap is SIGTERM'd and the dispatcher respawns it as a NEW session that re-reads the work from zero (= measured: a round was killed at 5418 s against a 5400 s cap) | `wenshu-parallel-dev/references/board-cli.md` (= at the create snippet, = where the cap is written) |
| a rebase that reorders a shared file changes the change's identity, = and the registry is where that happens; = rebuild the shared file from `main`'s copy and re-apply your own edit, = then check that the two change ids match before landing | `wenshu-parallel-dev/references/merge-back-to-main.md` |
| the CJK audit measures NEW CJK: = a moved or re-indented line and a string catalog's translation value are not new, = and the discriminator is a literal search of the base tree; = and a gate needs a control that shows it catches a real new line | `wenshu-parallel-dev/references/merge-back-to-main.md` |
| the sha of a review card goes in the FIRST paragraph of `WHAT TO BUILD`, = because the merge gate reads that paragraph alone | `wenshu-parallel-dev/templates/kanban-review-card-body.md` |
| a guard that reads an optional field fails OPEN on every shape that rebuilds the object without it (= a restore, = a deserialize, = a migrate) | written by the reviewer into the review lane's own skill (`sdlc-review`) |
