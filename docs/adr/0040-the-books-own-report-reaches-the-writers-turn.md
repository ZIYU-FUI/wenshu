# ADR-0040: The book's own report reaches the writer's turn

## Status

Accepted (2026-11-25).

## Context

Two kernels exist and are proven by their own suites: `StoryConsistency` (= ADR-0037)
weighs a book's claims against the world's rules and reports the conflicts;
`StoryForeshadow` (= ADR-0038) reads a book's thread chains and reports the breaks.
`StoryClaimReader` (= ADR-0039) reads a book's own field lines into claims.

None of them has ever been pointed at a book, and nothing in the tree has ever handed
a finding to the agent. The context bundle carries two arrays for exactly this —
`worldContext` and `foreshadowContext` — and `ContextEngine.aggregateContextForTurn`
returns both empty on every turn, so the prompt's `World:` and `Foreshadowing:` sections
never appear. The writer is asked to keep the book consistent with nothing that knows
where the book contradicts itself.

The two kernels live in the data package and know nothing about the disk. The agent
package owns the turn and knows nothing about the disk. The app owns the book on disk.
Somebody has to join them.

## Decision

**The report is a value type; the app reads the book and the turn reads the report.**

### The report travels as values

`ContinuityReport` holds the world's conflicts and the book's broken threads. Each row
says what was found **and where it is**: a conflict names its subject, its property,
the rule that found it, and the claims that met; a break names the chapter it happens
in. A report the writer cannot locate is a report the writer cannot fix.

The report reads no file. It is produced by the layer that owns the book.

### The agent asks once per turn

`ContinuityProvider` is a protocol the runtime holds and reads once per turn. The
runtime's own bundle then carries the report's rows in its `worldContext` and
`foreshadowContext`, which are the arrays the prompt already renders. Nothing new was
added to the prompt's grammar: the report arrived in a slot that was already there and
always empty.

A turn with no provider, or a provider that says nothing, carries no report. A book
that contradicts itself in no way must not make the prompt say so.

### The app owns the book, and the app reads it

`BookContinuityReader` reads a book through the stores that already own it — the
chapter store's own filesystem reader and the documents under the book's `world/` and
`characters/` folders — and runs the two kernels over what it read. It writes nothing,
and the `.ws` format does not change: there is still one persistence system.

`BookContinuityProvider` is the app's implementation of the protocol. It finds the
turn's book from the turn's own scope (`TurnScope.currentBookID` — the same way the
agent's other book-scoped tools find it), resolves it against the shelves, reads it,
and caches the report.

### The report is read once, and dropped when the book changes

The report is cached per book, so a conversation does not re-read the whole book on
every message. The cache is dropped when the library posts its change signal — the
app's own signal, the same one the editor's fingerprint cache uses. A book that was
edited since the last turn is read again.

### The rules are the book's, counted by the app

The consistency kernel takes rules as arguments (= ADR-0037). A novel's documents do
not name their rules in a shape a machine can read, so the app does not guess which
rules a book obeys: **measured over a real book's world documents, the properties its
claims state are 117 different names the author wrote**, and no fixed list of them can
be right for every book.

So the app counts what the book itself repeats: a property a book states more than once
about one subject gets the rule that weighs one value at one moment, and each such
property gets its own rule. A book that states every property once reports no
conflict, and that is the honest state of it.

The property's own name is the book's, so it is carried at run time and the file stays
English-only.

### A claim names the document it came from

The claim reader names a claim after its subject and the line it came from, and a book
may hold two documents about one subject (= a world's sheet and a character's sheet,
both named after the same person). Their claims would then share a name, and a report
that points at a name two files hold is a report the writer cannot locate. So the
document's own path is folded into the claim's name, and the subject stays what the
document is about — so the kernel still weighs two documents about one subject
together.

## Consequences

- **The data package keeps its no-I/O shape.** The kernels and the reader stay pure
  functions over values; the reading lives in the app, which owns the disk.
- **The agent package gains no knowledge of books.** It gains a protocol, a value type,
  and a call in its own prompt path. It opens no file and names no path.
- **Nothing is rendered.** The report reaches the prompt as text rows. There is no
  view, no panel, no badge, and the report is never displayed.
- **The report is only as good as the book's own lines.** A book whose documents hold no
  field lines reports no conflict. That is a limit of the input, not a bug in the
  report, and the reader's measurement (= 121 claims over 17 documents) is what says how
  much of a book is reachable this way.
- **One book, one report.** The report belongs to the book the turn is about, so a
  conversation about another book carries that book's report.

## The measurement this rests on

### What the real book produces today

The one real book in the library (= `build/wenshu-look.ws`, = = the book
`68F9A258-ECEC-4CFE-8FB0-49409E5EB750`) was read through the shipped reader:

| what | measured |
|---|---|
| the book's world documents the reader reads | **17** |
| the claims it reads out of them | **121** |
| the rules the book's own claims call for | **0** |
| the conflicts those rules find | **0** |
| the breaks the book's chapters produce | **0** |
| the report | **empty** |

So the two kernels now run over a real book, and what they find, today, is nothing: the
book has no chapters yet (= its `chapters/` folder holds nothing, and its store holds no
chapter rows), so the thread kernel has nothing to scan; = = and no subject repeats a
property across the book's documents, so the app derives no rule and the consistency
kernel has nothing to weigh. The writer's prompt is therefore byte-identical to what it
was before this change, = = on this book. That is the book's state and not a defect in
the reading: the 121 claims are what says the reader reads it, = = and a book whose
chapters plant a thread and never pay it off produces a break.

- The reader's fixtures carry the book's own Chinese lines, because the reader splits on
  the book's own punctuation and a fixture written in English would not prove the two
  agree.
- The prompt path is driven through the runtime's own composition (`composeSystemPrompt`),
  not through the renderer alone: a report that renders but does not reach the turn's
  prompt is a report nobody reads.
- The reader's own test proves it writes nothing: the book's directory is listed before
  and after a report, and the two lists are equal.
