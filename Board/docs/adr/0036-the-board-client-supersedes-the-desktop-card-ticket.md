# ADR-0036: The Board client supersedes the desktop card ticket

> Status: accepted
> Date: 2026-11-03
> Decision-maker(s): 老板 (the directives), pocock (the implementation)

## Context

The card feature began as a ticket for the shipping desktop app: one new
`@Model` row for a card, a store beside it, and six agent verbs to read and
write cards (`WSChapterCard`, `ChapterCardStore`, `card_list` / `card_read` /
`card_insert` / `card_update` / `card_move` / `card_delete`). That design is
recorded in the ticket's 4-section spec
(`.scratch/2026-11-02-card-chapters/spec.md`).

The boss ruled twice that the work does not land there:

- 2026-11-02: the replica is NOT built inside the shipping desktop app; it
  gets its own client and directory, sharing the data and model layer
  (ADR-0034).
- 2026-11-03: the infinite canvas IS the core thing to borrow from the
  reference.

The delivered work follows both rulings: `Board/` is a separate SwiftPM
package, it reads the library and never writes it (ADR-0035), and it builds
its own infinite canvas from Apple's public pieces
(`Board/docs/freeform-card-model.md`).

The spec was never retired or rewritten to match. The result is that the
repository stated the same feature two incompatible ways: the spec says a
card is a row with its own lifecycle, with a write channel of six agent
verbs, and with no canvas; the client says a card is a projection of the
chapter's Markdown, there is no write channel, and the canvas is the centre.
A reader of either document alone gets a wrong picture.

Measured 2026-11-03 against the repository and the installed SDK, the spec's
own file-and-line discipline aside, three of its claims were wrong:

- It calls `FileSystemChapterStore` the production model for chapters. The
  store is instantiated at four sites and every one of them is under
  `Tests/`; the SwiftData chapter row holds zero rows on a live library.
- It repeats the store's own stale header as the state of the file tier. The
  file tier is live: `FileSystemLibraryStore.swift:286` writes
  `chapters/<docId>.md`. The `chapters.json` index beside it is live too, and
  its one object writer (`LibraryMigrator+HelpDoc.swift:328-329`) disagrees
  with its array readers (`FileSystemChapterStore.swift:364`), with the
  decode failure swallowed into an empty list (`:365-369`).
- It says there is no public `PKCanvasView` in the macOS SDK. The class IS
  exported by the macOS PencilKit; what is absent is its header and its
  exposure in the macOS Swift interface.

Each of these is corrected in the spec itself, because a current-state
section that is wrong is wrong in every timeline.

## Decision

The Board client is the vehicle for the card feature, and the desktop-app
card ticket is superseded.

- The spec stays as the ticket's §8.3 artifact. Its CURRENT STATE and APPLE
  CANONICAL sections are corrected against the repository and the installed
  SDK, and its scope is banner-marked as superseded. §4 keeps the original
  design as the record of what was proposed, not of what was built.
- The live design is `Board/docs/board-plan.md`; the live teardowns are
  `Board/docs/milanote-card-model.md` and `Board/docs/freeform-card-model.md`.
- The one ruling the spec asked for — `AGENTS.md` §4.2 says "21 `@Model`
  classes" and the card ticket makes it 22 — did not happen and is not
  needed yet: the client adds no `@Model` at all, so the count stays 21 and
  the row stays true. The same question is still open in a different form and
  still blocks the client's phase 4: `Board/docs/board-plan.md` §10
  decision 3, "does a card become a first-class record, or stay a projection
  of the chapter's Markdown?".
- The desktop app stays the only writer of a library (ADR-0035). Nothing in
  this decision relaxes that, and the client's phase 4 may not create a
  second writer.

## Consequences

Easier: the repository states the feature once. A reader who opens the
client's plan, its teardowns or its ADRs finds the shape that was built, and
the spec reads as the ticket's original proposal with a dated correction
rather than as a competing design.

Harder: the six agent verbs, the per-card row and the generation view named
in the spec are not delivered, and they are not delivered by accident — they
are the desktop-app shape the boss moved away from. If the agent is to write
cards, that is new work against the Board client, and it has to respect the
writer rule.

Locked in: `AGENTS.md` §4.2 stays at 21 `@Model` classes until a boss OOB
changes it. The canvas is in the client's scope, so no later ticket may
treat it as out of scope again.

## Alternatives considered

- Rewrite the spec into the Board client's design. Rejected: the spec is the
  ticket's §8.3 artifact and its §4 is the record of the decision taken at
  the time; rewriting it would erase the trail and would make the correction
  indistinguishable from the original.
- Delete the spec. Rejected: the spec holds the ticket's business framing and
  its measured current state, and §8.3 requires the artifact to exist.
- Put the correction only in the closure record. Rejected: a reader who opens
  the spec would still take the wrong facts from it.
- Add a `@Model` to the desktop app so the spec's ticket 1 becomes true.
  Rejected: it is the shape the boss moved away from, and it would make the
  desktop app a writer of a card shape the client only reads.
