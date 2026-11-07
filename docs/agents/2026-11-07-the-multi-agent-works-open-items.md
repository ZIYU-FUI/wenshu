# The multi-agent work's open items, and what closed them

Closure doc for the four items the multi-agent work still owed the user: = the
roles' configuration surface, = the corpus's narrowing, = a layer's
membership, = and the model's default layer.

Date: 2026-11-07. Branch: `feature/multiagent-gaps`.

## What was open

Measured against the tree at `main` = `434de8692d4746003d38ab169c2a638d61774a11`,
the multi-agent work left four items open:

1. **The six roles had no configuration surface.** = The role table was
   reachable only through the model and the debug surfaces. = A user who
   asked "what is the researcher allowed to write into my library?" had no
   answer in the app.
2. **The archive narrowed, and the corpus did not.** = The archive's pane
   filters by agent and by kind (= `ArchiveSettingsPane`), = and the corpus's
   read surface had no filter at all.
3. **A layer's membership was its index, = and the body and the index were
   two writes.** = `AtomicFileWrite` makes each one atomic, = **⇒ but the
   pair is not.** = A crash between them left a body on disk that the index
   did not list, = and the report then said **"NOT in the library, = so it
   did not land"** about a document that was sitting there.
4. **`Reference.init`'s default layer was `.layerRaw`** (= the layer the user
   cannot browse), = so every construction that did not name a layer landed
   there. = The writer's default was fixed (= the tool writes `entities`),
   = and the test fixture was corrected (= it now names the layer it
   means), = **⇒ but the model's default was still raw.**

**⇒ And one defect sat beside them, = outside the multi-agent work's own
ledger:** the system index's wait was a `DispatchGroup.wait()` on the search
actor's own executor, = so a slow Spotlight froze every other caller on that
actor, = and the whole-suite test run had to SKIP the index's own suite
because that wait could hang.

## What closed them

### 1. The roles have a surface (= read-only)

`Sources/WenshuApp/Features/Settings/View/RolesSettingsPane.swift` = the
six roles, = what each one may call, = and where it runs.

**⇒ It is READ-ONLY, = and that is the honest shape.** = The role table is
the app's contract with the model (= each role's prompt and its tool
subset), = and the prompt is what the app's own guarantee is written in. = A
pane that EDITED the table would be offering to break the guarantee while
showing it.

**⇒ The rows come from `SubAgentRoleRegistry.roles`, = never from a copy
here.** = The registry is the table the runner dispatches from, = so a pane
that listed its own copy would be a second table that could drift.

**⇒ And the pane says WHERE each role runs** (= the archivist and the
auditor do not call a model at all, = they run as the archive run and the
audit run), = because a role table of names hides that.

### 2. The corpus narrows by kind and by owner

`Sources/WenshuApp/Features/Library/Service/ReferenceCorpusNarrowing.swift`
= the two axes, = and the witness that answers the owner axis.

**⇒ The kind axis is `EntityType`** (= the corpus's own closed set of 9:
character / location / event / concept / artifact / organization / era /
work / other). = It is a FIELD on every reference, = so narrowing by it
costs no index and no disk.

**⇒ The owner axis is "you vs. an agent", = and that is the WHOLE truth.**
Measured 2026-11-07: = **no producer records WHICH agent wrote a
reference.** = The `reference_library` tool protocol carries no caller
identity (= `Tool.execute(input:)` takes only the input), = the `Reference`
model has no agent/role/provenance field, = and the only write provenance
that exists is the second-writer rule's binary owner (= `ReferenceWriteRecord.Owner`
= `.agent` / `.user`). = **⇒ A menu that names six roles the app cannot
prove is a menu of lies** (= the archive's own rule for its agent picker: =
"the options come from the rows"), = so this axis offers exactly the two
owners the witness can prove.

**⇒ And the witness is the SAME one the second-writer rule uses.**
`ReferenceWriteGuard.resolveOwnership` already answers "whose text does the
truth hold", = so this file does NOT re-decide ownership (= a second answer
to the same question is how the two copies of a body drifted in the first
place): = it reads that one answer. = **⇒ An owner the witness cannot name
is the USER's** (= the agent may never replace text it cannot prove it
wrote).

**⇒ The narrowing runs BEFORE the matching** (= a document the user
excluded must not be read at all, = and must not be counted in what the
search found).

### 3. A layer's membership is what is on disk

`Sources/WenshuApp/Features/Library/Service/ReferenceLayerMembership.swift`
= the index rows (= the METADATA) = plus the bodies the layer holds (= the
MEMBERSHIP).

**⇒ And a document with no metadata is still a MEMBER.** = The corpus's own
identity rule reads a body's first H1 as its title, = so a body on disk
names itself. = What is NOT knowable is its kind, = its tags, = its
category, = and its summary: = those lived in the index row that was lost,
= and **⇒ this type does not invent them** (= `.other` and empty, = which
is what the model's own decode fallback uses for a row whose kind it cannot
read). = A document filed under a kind nobody chose is a worse lie than one
filed under "other".

**⇒ And the WRITERS are not affected.** = A writer rewrites the index from
the index's own rows, = so a recovered member never becomes a permanent
index row with invented metadata. = **⇒ The membership read and the index
read are two different questions, = and this type is the answer to only one
of them.**

**⇒ And the scan does not read the bodies it does not need.** = The
corpus's UI read runs on every library change, = so reading every body's
text on that path would make the sidebar slower for a library of any size.
= **⇒ Only the bodies the index does NOT list are read** (= the crash
window, = which is empty in a healthy library), = and the rest are
recognised by their FILENAME alone.

### 4. The model's default layer is the layer the user can browse

`Sources/WenshuApp/Features/Library/Model/Reference.swift` = `Reference.init`'s
default layer is now `.layerEntities`.

**⇒ Changing a model default is not a side effect of a count fix, = and it
is a separate piece of work** (= this is that piece). = **⇒ And it moves NO
production document** (= every production construction names its layer, =
which a test asserts by reading the tree), = so the change is a guard for
the NEXT construction that forgets.

**⇒ The graceful migration path is NOT the default.** = A row persisted
under a layer the app no longer has must not throw (= one unknown value
would fail the whole index decode, = and the library would read as empty).
= It falls back to the raw layer, = because a row nobody can place is a
document the app does not claim.

### 5. The system index is waited for, = not blocked on

`Sources/WenshuApp/Features/Library/Service/SpotlightQueryWait.swift` = a
SUSPENDED CONTINUATION with a DEADLINE.

**⇒ The old wait was a `DispatchGroup.wait()` on the actor's own executor.**
= The index's answer decided when the actor came back, = so a slow, =
disabled, = or wedged index held every other caller on that actor for as
long as it liked. = **⇒ Now the caller is SUSPENDED, = not blocked; = the
index answers on its own queue; = and the wait ends on whichever comes
first** (= the answer, = the deadline, = or the cancellation).

**⇒ The index is a SECONDARY source** (= the app's own mirror answers
immediately), = so a slow index costs the caller LATENCY, = not the answer.
= Two seconds is long enough for a warm index, = and short enough that an
index which never answers does not hold the app.

**⇒ The deadline CANCELS the index** (= the index stops working on a
question nobody is waiting for), = and exactly one of {the answer, = the
deadline, = the cancellation} finishes the wait (= a continuation resumed
twice traps).

## What was NOT done (= the honest boundary)

- **The owner axis does not name an agent.** = The app cannot prove which
  agent wrote a document, = so it offers the two owners it can. = A filter
  that named the six roles would be a filter that lies.
- **The roles pane is read-only.** = The role table is the app's contract
  with the model, = and editing it is a different piece of work (= and one
  nothing in the user's request asked for).
- **The body and the index are still two writes.** = This change makes the
  READ answer the question (= the membership is what is on disk), = and it
  does not make the WRITE one unit (= that is a different change, = and it
  would touch every writer).
- **The recovered member carries no kind, = no tags, = and no category.**
  = They lived in the lost index row, = and inventing them is a worse lie
  than "other".
- **The corpus's search still does not search the CHAPTERS** (= the book's
  own documents). = That is the original ask's other half, = and it is
  still open.

## The measurements

**⇒ The baseline this change was measured against** (= `main` =
`434de8692d4746003d38ab169c2a638d61774a11`, = in a DETACHED worktree, =
with the full suite run to completion and NOT truncated):
= **3483 tests / 542 suites**, = and the failing set is the union of two
runs' = **6 flaky tests**, = every one of which also fails at the base.

**⇒ And the real library was read, = never written.** = The user's
`~/Documents/anbaiqiang.ws` holds 6 entities rows against 6 `.md` bodies,
= 0 raw rows, = and NO `.write-records/` directory (= so the second-writer
rule's witness has never been written for the user's own documents). = Five
of the six truth/mirror pairs differ by a leading newline only, = and ONE
(= `A9D67320-55B1-49FD-B9D3-0261FB4BEA98.md`) differs in CONTENT (= the
user's own edit). = **⇒ And the truth's newest mtime is unchanged by this
work.**
