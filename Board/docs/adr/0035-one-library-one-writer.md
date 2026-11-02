# ADR-0035: One library, one writer

> Status: accepted
> Date: 2026-11-02
> Decision-maker(s): 老板 (the directive), pocock (the implementation)

## Context

The board client is a Mac app that reads the same `.ws` library the desktop
app owns. The product line's ruling 4 is that the Mac holds the only writer,
because a single writer needs no distributed merge, no CRDT and no operation
transform — and the phone client is a thin remote control for exactly that
reason.

Two measurements make the risk concrete rather than theoretical:

- The desktop app writes a chapter's body by overwriting its `.md` file in
  place (`EditorPersistence.save` writes the file atomically, and the draft
  path binds `chapters/<tab.id>.md`), and it writes the index beside it
  separately. A reader that lands between the two sees a body and an index
  that disagree.
- The index's writer and its readers already disagree permanently: the writer
  emits one object and every reader expects an array, and the decode failure
  is swallowed into an empty list, so a structure error is indistinguishable
  from an empty book.

A second writer would make both worse, and the desktop app's own store is
SwiftData with a shared SQLite file underneath, so a second process opening
the same store is a second writer of the same rows.

## Decision

The desktop app is the only writer of a library. The board client **reads**
one and never writes a `.ws` the desktop app has open.

The constraints that follow:

- The client's SwiftData access, when it has any, is a read. It opens the
  shared store read-only and never creates, updates or deletes a row.
- The client's file access is a read. `ChapterFileReader` reads the bodies and
  writes nothing.
- The first release reads the files directly and says so; a client that must
  see a consistent snapshot while the desktop app is saving is a separate
  decision (see the plan's open item 1: read the files, or read through a
  companion API the way the phone client does).

## Consequences

Easier: the desktop app's ten merge gates and its existing file format stay
authoritative; the client cannot corrupt a library it is only reading; and
the client's own slices can land without a migration.

Harder: the client can observe a torn state while the desktop app is saving,
so it must tolerate a body and an index that disagree, and it must not treat
an empty index as "this book has no chapters". The phone client's answer to
the same problem — a companion API with a single writer — is the answer if
the board ever needs a consistent snapshot.

Locked in: the client is a reader. Any card write, any card generation, and
any reorder that changes the library is a command to the desktop app, not a
local write.

## Alternatives considered

- **The client writes too, with the desktop app closed**: rejected — it makes
  the library's ownership ambiguous, and the desktop app's SwiftData store and
  the file tier are two representations of the same thing.
- **The client reads through a companion API from the start**: rejected for
  the first release — the companion does not exist yet, and the board's value
  is that the shape can be tried now. It stays the answer for a consistent
  snapshot.
- **The client copies the library into its own sandbox**: rejected — the copy
  drifts, and the boss's directive is to share the data and model layer.
