# The librarian, and what it owns

Decision record for the librarian role (= the role that keeps the library), and
for the one product decision the merge left open.

Date: 2026-11-04. Branch: `feature/librarian-corpus-p0`.

## What the librarian is

A role that runs a named procedure on a named task. Two procedures:

| Procedure | What it does |
| --- | --- |
| `import` | Takes a source document into the library: = read it, = split it into the documents it describes, = file each one. |
| `curate` | Tidies what is already there: = report the duplicates, = the orphans, = the stale entries. = It reports; = it does not delete. |

It is activated by one surface: `@librarian <procedure> <arguments>`. There is no
timer, no background sweep, and no way for it to start itself. A mention that names
no procedure falls through to the ordinary path, because a run with no named
procedure has no defined behaviour.

Its scope: = the documents already in the library and the documents about to enter
it. It does not search the open web (= the researcher gathers, = the librarian
files), and it does not write prose (= the writer drafts, = a confirmed chapter is
the user's).

## The one product decision

The spec left this open: **does the librarian write into `chapters/`, or only into
`drafts/`?**

**Answer: the import's existing behaviour stands, and the librarian inherits it.**
= The import already routes per the user's chosen target folder, = and the user
chooses that folder explicitly in the import sheet. = Choosing a folder IS the
user's decision; = the drafts-first gate is the rule for what an AGENT writes on
its own initiative, = and a user who picked "chapters" has already made the
decision the gate protects.

What this means concretely:

- The import keeps writing where the user pointed it.
- The librarian's own procedures do NOT write chapter bodies. = Its tools are the
  corpus (`reference_library`), the book's structure (`book_outline`,
  `book_entity`) and the files already there (`file`, `ReadFile`). = It has no
  `book_chapter` and no `book_edit_chapter`.
- So the gate holds for every writer that writes on its own initiative, and the
  user's explicit choice is honoured.

## The corpus has one writer's RULE, not one writer

The library's identity rule is one: = a document is identified by its title (=
trimmed, = case-insensitive, = whitespace-collapsed). It lives on the model
(`Reference.titlesMatch`), and every writer answers with it: = the tool's create,
= the tool's upsert, = the store's own upsert, = the import's dedup.

Two roles can reach the corpus writer, and that is deliberate:

- The **librarian** files. = It creates, extends and updates.
- The **researcher** contributes. = It reads the corpus to know what is already
  there, = because a summary that repeats a document the user already has is a
  worse answer than one that adds to it.

What must not happen is BOTH writing under different rules. The rule is enforced
by the writer: = the tool's create now refuses a title that already exists and
names the document that does, = so a second copy is a refusal rather than a card
the user has to clean up by hand.

Why the researcher keeps the write path (rather than being demoted to read-only):
= `delegate_research` already promises the user, in the tool's own reply, that
the findings will land in the reference library. = Removing the write path would
break a promise the product makes in its own voice. = The librarian's `curate`
procedure is where the corpus gets its governance: = the duplicates, = the
orphans, = the stale entries, = reported for the user to decide.

## What the librarian is not

- Not a chat partner. = It does not converse; = it runs a procedure and reports.
- Not a scheduler. = The app gets no cron. = A periodic sweep of the corpus is a
  Hermes-side job over the `.ws` directory if it is ever wanted, = not an in-app
  timer.
- Not the archivist. = The archivist snapshots the workspace (= `.ws/archives/`);
  = the librarian files documents. = They share the ledger, = not the job.
- Not the auditor. = The auditor reads and rules; = it writes nothing.

## The ledger they share

Every explicit run leaves a row: = a session tagged with the agent that did the
work, = a run row under it with the task, = the outcome and the tokens. The row
is written when the run STARTS, = so a run that crashes leaves a row that says it
started and never finished.

A run gets its own session row, = not a row on the chat's session: = a chat and a
run are different things, = and the archive reads the tagged rows, = so the two
never land in the same list.

The librarian's runs are rows too, = which is why the librarian and the archive
share one ledger instead of two.

## What is still open

- The archive pane's UI (= the ninth settings pane, = the list, = the filters, =
  the detail view). = The ledger and the read path are ready; = the surface is
  not built.
- The library-level board (`TaskScope.referenceLibrary` is offered by
  `availableScopes` and read by nobody).
- A retrieval surface over the corpus (`CSSearchableIndexSearch.search` has zero
  callers). = The index is written; = nothing reads it.
- The librarian's `curate` procedure's analyser is `Curator.curate`, which exists
  and has no caller yet.
