# What the multi-agent work still owes the user

**Written 2026-11-04, after the librarian and the archive landed.**
The question this answers: = the audit said several things were
"registered, or in a registry, or in a design document", = and the
question is which of them are now real.

**⇒ The short answer: = five are still open, = and two of them are
open because the first one to close them was never closed.** = This
file says what is open, = what the evidence is, = and what closing
each one looks like. = It is a record of a decision, = not a plan to
be admired.

## The six roles are real

`SubAgentRoleRegistry` holds `researcher`, `librarian`, `writer`,
`analyst`, `archivist`, `auditor`, = and each row names tools that
exist in `ToolRegistry`. = That was false in the first audit (= the
writer named `paragraph_ai`, = which no production code has, = and
the analyst named two tools it did not have), = and it is now true,
= with a test that says so.

The librarian is activated **only** by an explicit input: =
`@librarian import|curate <arguments>`. = There is no timer, = no
background sweep, = and no self-starting path. = That is deliberate:
the user's words were "a role that works to a SOP, = activated by an
explicit input", = and a role that starts itself is a different
thing.

## The librarian's two procedures are not the same kind of thing

`curate` is **code**: = `Curator.curate` over the corpus, = no model
call, = and it reports rather than deletes. = The app runs it.

`import` is **the model with a tool**: = the librarian reads the
source, = decides what documents it describes, = and writes each one
through `reference_library`. = The model does the splitting, = because
splitting a source into documents is a judgement, = and the code
cannot make it.

**⇒ And the difference had consequences.** = The curator used to be
a prompt that promised the model something the code could not
deliver, = and that was fixed. = The import had the same shape and
was not fixed: = the report was the model's own word for what landed,
= and a model can say it landed a document it never wrote, = or write
one into the raw layer (= which the user cannot see) = and say it
landed it. = **⇒ The import's report is now checked against the
corpus** (= the branch `feature/library-and-archive-surfaces`), = and
the check is printed apart from the model's words. = The architecture
was not rewritten: = what changed is that the report is no longer a
promise.

## What is still open

### 1. The corpus cannot be searched

**⇒ CLOSED** on `feature/library-and-archive-surfaces`
(= `feat(library): the library can be searched by a word in a
document's body`).

**⇒ What it did NOT use, = and why.** = Not
`CSSearchableIndexSearch.search(query:limit:)`. = Two reasons, = both
measured: = the index is a mirror of the SESSION (= empty after a
relaunch until the documents are written again), = and its answer
depends on a synchronous wait on Spotlight (= `group.wait()`), = so a
slow Spotlight freezes the app. = The library's documents are on
disk, = so the library can answer without asking.

**⇒ The trap it walked around, = and the one it did not.**
`Tests/WenshuAppTests/Library/Search/CSSearchableIndexSearchTests.swift`
is skipped in the whole-suite runs, = and the skip exists because
that suite can hang in Core Spotlight. = The new read path never
touches Spotlight, = so it cannot hang there. = **⇒ The Spotlight
wait is still in `querySpotlight`, = and it is still a defect for
the path that DOES use the system index** (= the system-wide search,
= = `⌘Space`). = Closing that is a separate piece of work, = and it
is not closed.

**⇒ What is left of the original ask.** = The library's own search
finds a document by a word in its title or its body. = It does not
search the CHAPTERS (= the book's own documents).

### 2. The raw layer has no maintenance surface

**⇒ CLOSED** on `feature/library-and-archive-surfaces`
(= `feat(library): the raw layer is governed, = not hidden`).

**⇒ What closed it** (= three things, = and each one is a way the
app used to hide the raw layer):

1. **The librarian's curate report NAMES the raw-layer documents.**
   = A count tells the user that something is there; = the names
   tell him WHICH. = The agent could write to the raw layer and
   nothing in the app listed it, = so a report that said "landed"
   about a document the user cannot open was a report the user
   could not act on.
2. **The report says what the raw layer IS FOR** (= the originals,
   = kept for ingestion). = The layer was described in exactly one
   place, = and that place said only what the layer is CALLED; = so
   a user who found a document he could not browse had no way to
   tell whether it was lost (= a bug) = or kept on purpose (= the
   design).
3. **The sidebar's count is of what the user can SEE.** = The count
   was of every reference with a tag, = across BOTH layers, = while
   the grid shows the entities layer only = = so a tag row could say
   "3 items" and open to two documents.

**⇒ What was NOT done.** = **No new UI surface for the raw layer.**
= The raw layer is the librarian's territory (= the role owns the
`.ws` document chain), = so the report is where the user learns about
it.

**⇒ And the reason this entry gave for NOT doing it was false.**
= It said a new `PreviewScope` case would grow `PreviewPane.swift`,
= because that file "is 1174 LOC = 1.96x the 600-LOC cap". = **⇒
`PreviewPane.swift` is 302 LOC** (= 1174 was its count before the
§6.6 split, = and the figure was copied from a source comment that
had itself gone stale). = **⇒ So the file was never near the cap,
and the door was open the whole time.** = The raw layer's UI surface
is therefore NOT blocked by the size of a file: = it is a piece of
work that has not been done, = which is a different thing. = **⇒ A
number quoted as a reason has to be measured against the tree it
claims to describe** = and this one was quoted for weeks after it
stopped being true.

**⇒ And the root of "the user cannot see these documents" is still
there.** = `Reference.init`'s default layer is `.layerRaw` (= the
layer the user cannot browse), = so every construction that does not
name a layer lands there. = The writer's default was fixed (= the
tool writes `entities`), = and the test fixture was corrected (= it
now names the layer it means), = but the MODEL's default is still
raw. = Changing a model default is not a side effect of a count
fix, = and it is a separate piece of work.

### 3. The roles have no configuration surface

**Evidence.** = `AgentSettingsPane` is the **tool** permission pane
(= which tools the agent may use, = as presets), = and it is not a
role configuration pane. = There is nowhere in the app where the six
roles are listed, = with their tools, = or where a user can see what
the librarian is and what it is allowed to do.

**⇒ What closing it looks like.** = A read-only surface first: = which
roles exist, = what each one may call, = and how to activate it. = A
*configurable* role table is a bigger thing (= the registry is the
table, = and it is compiled in), = and nothing in the user's request
asks for it.

### 4. The archive narrows, = but the corpus does not

**Evidence.** = `WSChatRepository.listRuns(source:agentName:includeArchived:)`
has taken filters since the archive's data layer landed, = and the
pane now uses both (= the branch `feature/library-and-archive-surfaces`).
= The options come from the rows, = because a menu that names a role
the app does not have is worse than no menu.

**⇒ What is still missing** is the same gap as #1, = on the other
side: = the corpus is indexed and never read, = and the archive is
filtered and the corpus is not.

### 4b. A layer's MEMBERSHIP is its index, = and the body and the index are two writes

**⇒ The review of the corpus-unreadable fix found this, = and left it
for the next card** (= "Not this card's defect to fix; = flagged so
the next one inherits it knowingly").

**⇒ A layer's membership is defined by its INDEX.** = The `.md` bodies
are written by `ReferenceBodyStore.write`, = and the index by
`writeIndexToFileSystem` = = **two separate writes.** =
`AtomicFileWrite.write` makes each one atomic, = **⇒ but the PAIR is
not.**

**⇒ ⇒⇒ A crash between them leaves a body on disk that the index does
not list.** = And the report then says **"NOT in the library, so it did
not land"** about a document that IS there = = **the same shape of lie
the corpus-unreadable fix just closed, = one step further out.**

**⇒ ⇒⇒ The difference matters**: = the unreadable case is about a
corpus the reader could not open at all, = and this one is about a
corpus the reader opened successfully = = so **the strict read does
not help here**; = the corpus is READABLE and the answer is still
wrong.

**⇒ ⇒⇒ What closing it looks like**: = either the body and the index
are written as ONE unit, = or the layer's membership is read from what
is ON DISK (= the `.md` files) = and not from the index alone.

**⇒ Measured against the user's real library** (= the review measured
it, = and the strict path agrees with it): = `abstracts/` and
`indexes/` have no index AND no `.md` files (= genuinely empty), =
`raw/raw.json` decodes to `[]` (= 0 rows, = 0 files), = and
`entities/entities.json` decodes to **6 rows** against **6** `.md`
files. = **⇒ The reader reads the real library correctly today.**

### 5. Nothing has landed on main

**Evidence.** = The work is on local branches: =
`feature/librarian-corpus-p0` (8 commits), =
`feature/subagent-return-path` (22 commits), =
`feature/library-and-archive-surfaces` (= the two commits this
branch adds). = The machine has no SSH key for `old-origin`, = so
`git push` fails and the branches are local only.

**⇒ What closing it looks like.** = A push, = and then the merge
flow the repo already has: = `merge-preflight.sh` must say CLEAN, =
the card's own worktree rebases onto main, = the card's own gates are
re-run on the rebased tree, = and only then a fast-forward.

## What is not open, = and why

**⇒ A cron inside the app.** = The app does not schedule agents. =
Hermes's cron serves the development and runtime side, = and a cron
inside the app would make it a background manager of the user's
documents, = which is not what the user asked for.

**⇒ A generic chat surface for the librarian.** = The librarian's
job is the document chain inside `.ws`: = what is already filed and
what is about to be filed. = It is activated by a named procedure, =
and it is not a chat personality.

**⇒ The librarian writing prose.** = A chapter is the writer's, = and
a confirmed chapter is the user's. = The librarian files and reports.

## The durable facts this file rests on

| Fact | Where it is held |
| --- | --- |
| the six roles and their tools | `SubAgentRoleRegistry` (= the table), = and a test that every named tool resolves |
| the librarian's activation | `LibrarianActivation` (= the parser), = and the prompt that says the procedures |
| the corpus's one-document rule | `Reference.titlesMatch` (= trimmed, = case-insensitive, = whitespace-collapsed) |
| the import's report and its check | `LibrarianReport` (= the parser, = the verifier, = and the wording) |
| the curate procedure | `LibrarianCurator` + `Curator` (= deterministic, = no model call) |
| the archive's columns and its filters | `WSSession.source` / `.parentSessionID` / `.agentName`, = and `WSChatRepository.listRuns` |
| the retention window | `WSChatRepository+Archive` (= the purge), = and `ArchiveSettingsPane` (= the pane) |
