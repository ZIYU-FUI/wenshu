# Session closeout: the sidebar tree's reveal, and the chat's launch scope

= = = 2026-11-18. = = = The scope of this session is TWO carriers, = = and
they are independent of each other (= one is the tree's behaviour, = the
other is the chat's launch behaviour):

= = = 1. `73244ba4c` = = "feat(sidebar): the tree opens the row a
conversation names, = = and the open rows survive a relaunch" = = = = the
sidebar tree opens the path to the row a conversation names, = = and the
set of open rows is the app's own state, = = so it survives a relaunch;

= = = 2. `8ea2727be` = = "fix(chat): the zone opens on the conversation
the restored selection names" = = = = the chat zone opens on the
conversation the restored selection names, = = instead of the default
one.

= = = Both landed on `main`, = = both were cleared by an INDEPENDENT
verdict (= the review cards `t_c8abe108` and `t_9b8c9330`, = = each with
`review_outcome` = `approved` in its run metadata, = = not a word in a
summary).

## 1. The symptom, the root cause, the fix

= = = 1.1 THE TREE = = =

= = = THE SYMPTOM: = = the boss asked for the left tree to open the row
a conversation names, = = and for the open rows to survive a relaunch.
The framework's own outline (= `List(data, children:)`) = = keeps its
expansion INSIDE itself: = = it exposes neither the open rows nor a way
to open one, = = so a row named by a conversation cannot be revealed, =
= and the open rows are lost on every relaunch.

= = = THE ROOT CAUSE: = = the expansion state was the framework's
private state. = = ⇒ ⇒ ⇒ The app now owns it: = = the rows are drawn
with Apple's own disclosure control (= the platform's triangle, = the
row's chrome, = the indent), = = and the set of open rows is the app's
state (= `wenshu.sidebar.expandedRows`, = = a JSON `Set<SidebarItem>`).

= = = THE FIX: = = `SidebarTreeView` draws the hierarchy with recursive
`DisclosureGroup(isExpanded:)`, = = the tree's rows carry the selection
bridge (= the row's title selects, = the triangle opens), = = and the
reveal (= the conversation's page pick) opens the rows ABOVE the named
row. = = ⇒ ⇒ ⇒ The reveal only ADDS: = = the rows the user opened
elsewhere stay open, = = and a row the user closed comes back when a
selection needs its path.

= = = THE KEY: = = the row's expansion key is the row's BUSINESS
identity (= the shelf's id, = the book's id, = the category's routing
key), = = not a per-process id. = = ⇒ ⇒ ⇒ `Hasher` was measured and
rejected: = = three runs of the same input printed three different
hashes (= `b1`, = `42`, = `36`), = = so a hash cannot key a value that
has to survive a relaunch.

= = = 1.2 THE CHAT = = =

= = = THE SYMPTOM: = = the boss reported that after a relaunch the chat
did not carry the conversation's content: = = with the book's own
conversation on screen (= and the book had content), = = the restored
selection named a different book, = = and the transcript stayed on the
library's default conversation (= or came up empty), = = and it looked
slow.

= = = THE ROOT CAUSE: = = the restored `sidebarSelection` is read back
in `WorkspaceUIState.init`, = = so it EXISTS before the view is born.
The zone's `onChange` therefore never fires for it: = = a value that was
already there when the view appeared is not a change to that view.
⇒ ⇒ ⇒ The chat opened on the default scope instead of the restored one.

= = = THE FIX: = = the zone's own `.task` applies the scope before it
publishes it (= `applyScope(currentScope)`), = = and
`ChatViewModel.setScope` is a no-op for the same scope (= so the fix
costs no extra history load).

## 2. The measured before and after

= = = 2.1 THE CHAT'S CONTENT = = = the app's own pixels (= the app's
screenshot hook, = so no other window is in the shot) and the app's own
AX, = = on the SAME persisted state:

= = = BEFORE (= the base build): = = the transcript carries the
library's warehouse message;

= = = AFTER (= the fix): = = the transcript carries the book's own
conversation (= the scope prompt that names the book and says to talk
following the book's setting).

= = = THE ARRIVAL TIME: = = **0.01-0.02 s** on 6 of 6 cold launches
(= the same script, = = the same persisted state). = = ⇒ ⇒ ⇒ So the
content is not slow: = = it is either there in a hundredth of a second
or it is the wrong conversation (= = the root cause above), = = and the
fix makes it the right one.

= = = 2.2 THE TREE'S OPEN ROWS = = = the live acceptance (= the app's
own pixels, = = the app's own AX): = = the conversation's page pick
reopened the collapsed shelf (= 3 -> 4 rows, = = the open-row set 125 ->
189 bytes, = = the selection byte-identical); = = the relaunch restored
the open rows, = = including the library part's root opened by the
persisted key alone (= = no reveal from the shelves part could name it);
= = every row's triangle carries the platform's disclosure identifier;
= = the book row's menu and the shelf row's menu each opened at their
own row.

= = = 2.3 WHAT THE ACCESSIBILITY TREE SAID = = = the census walks EVERY
`AXRow`, = = so a duplicated row would be counted. = = In every run the
hierarchy was clean (= 8 rows in the shelves part, = = 6 in the library
part, = = no duplicate). = = ⇒ ⇒ ⇒ So the model and the accessibility
tree were RIGHT, = = and only the drawn tree was wrong. = = That is the
discriminator that separates "the data is wrong" from "the pixels are
wrong".

## 3. The gates on the MERGED tree

= = = The gates are re-run on the merged tree (= = `main` at
`b5fe8f17d`), = = not on the branch they were measured on before the
merge, = = because a merge brings in a sibling's commit and that can
change the build, = = the inventory and the test set.

| the gate | the merged tree | the scope's own diff |
| --- | --- | --- |
| 7.1 the build | `swift build` exit 0 | exit 0 |
| 7.2 the suite | = = the base's own failing set, = = no new site | 3766 tests in 576 suites, = = 5 issues (= = the base's 5) |
| 7.3 the design sweep | = = the sweep suites pass on the changed view files | = = 51 tests in 6 suites |
| 7.5 the CJK audit | = = 0 new CJK in the scope's added lines | = = **0 of 3641** (the tree) and = = **0 of 56** (the chat) |
| 7.6 the dead code | DEAD 0 (= = the base reads DEAD 0 too) | DEAD 0 |
| 7.8 the commit hygiene | = = a conventional prefix, = = an English subject, = = a body that says why | = = both carriers |
| 7.9 the verdict field | = = `review_outcome` = `approved` on both cards | = = both carriers |

= = = The three repository gates that read a diff (= the formatting
gate, = = the registry's LOC gate, = = the pollution gate) exit 0 on
the scope's own diff.

## 4. The boss's own look (= the 7.7 gate)

= = = WHICH BUILD: = = the bundle at `build/Wenshu.app`, = = rebuilt from
`main` at `73244ba4c` with `Scripts/build-app.sh`, = = ad-hoc signed
(= `Identifier=com.wenshu.app`), = = launched with a PLAIN `open` (= = a
second instance of the same bundle id aborts both).

= = = THE BOSS'S VERDICT: = = the switching of the tree was accepted
(= the boss's words: = = the switching has no problem), = = and the boss
REPORTED one defect on that build: = = the drawn tree keeps a stale row
after the part switches (= an empty slot, = = or the previous row's
content drawn twice). = = ⇒ ⇒ ⇒ That defect is NOT closed by this
session: = = see the open items.

= = = THE APP IS LEFT RUNNING: = = yes (= the instance the boss was
testing, = = from the merged build).

## 5. The open items

= = = 5.1 THE STALE ROW (= = a defect found while landing, = = its own
row, = = not folded into the two carriers) = = the drawn tree keeps a
row it no longer had after the part switches. = = ⇒ ⇒ ⇒ MEASURED: = = the
accessibility tree is clean, = = and the BASE build (= = `84c3a6386`, =
= the framework's own outline) reproduces the same class of artifact in
its own pixels (= = a stale slot where the book row belongs). = = ⇒ ⇒ ⇒
So it is PRE-EXISTING and not caused by the two carriers above. = = Its
fix is committed (= `2a8e03fe8` on `feature/tree-stale-row-2026-11-18`,
= = the tree's outline gets an identity that follows its shape, = = so a
fresh outline is built when the shape changes) and is in review on the
card `t_f6148388`. = = The next session lands it. = = Two notes for
that session: = = the automated sequence produces the EMPTY form of the
artifact (= = the base's own pixels) = = and the double-drawn form (= =
the boss's screenshot) = = is the same class but was not reproduced by the
sequence; = = and the registry's row for `SidebarTreeView.swift` still
says 118 while the file is 154 (= = the registry's rule is that a row is
the count when the row was written, = = corrected when the same change
rewrites the file; = = it does not gate, = = because the LOC gate only
reads the rows a change ADDS).

= = = 5.2 THE LIBRARY HAS NO SECOND BOOK = = = the boss's report was
phrased with two books in it (= = the one with content, = = and another
one). = = This machine's library holds two books (= = the default help
document, = = and the novel the boss was testing). = = ⇒ ⇒ ⇒ The fix is
generic (= = the chat follows whatever the restored selection names, = =
= which book that is), = = and it was verified on the book that has
content.

= = = 5.3 THE EXPANSION KEY'S EDGE CASES = = = the key is the row's
business identity, = = so a row that MOVES (= = a book moved to another
shelf) keeps its key, = = and a row that is RENAMED keeps its key (= = the
key is the id, = = not the title). = = ⇒ ⇒ ⇒ A row's key does NOT
survive a DELETE and a re-CREATE with a new id (= = that is a new row),
= = and the reference library's category rows are keyed by their routing
key (= = so a category whose title changes keeps its key, = = and a
category whose ROUTING key changes does not). = = Those edges were not
exhaustively measured.

## 6. The commits this session pushed that are NOT this session's

= = = The push of `main` carries whatever `main` holds. = = The range
`41b82a8fa..73244ba4c` = = the range this session's two landings
carried = = holds SEVENTEEN commits, = = and only TWO of them are this
session's (= = `73244ba4c` and `8ea2727be`). = = The other fifteen
belong to sibling sessions (= = the inspector's card pages, = = the
selected-segment fill probe and its docs, = = the App Store scope's
closeout, = = the registries' trailing-newline fix, = = and their
documentation). = = ⇒ ⇒ ⇒ Pushing them was maintenance of the shared
server state, = = not authorship: = = their own cards carry their own
verdicts.

= = = THE SERVER-SIDE PROOF: = = `origin/main` and `old-origin/main`
both read back = = the same sha as the local `main` at the time of this
closeout.

## 7. The next session's starting point

= = = 1. The tree's reveal and the chat's launch scope are ON `main`
(= = `73244ba4c` and `8ea2727be`), = = with their verdicts on the
board.

= = = 2. The stale-row card `t_f6148388` (= = the branch
`feature/tree-stale-row-2026-11-18`, = = the carrier `2a8e03fe8`) = = is
in review: = = land it with `Scripts/land_card.sh` once its verdict
reads approved.

= = = 3. The app's own pixels are the evidence: = = the base build's
pixels show the stale slot, = = the fix's pixels show every row once.
