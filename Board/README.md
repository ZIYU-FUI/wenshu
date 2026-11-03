# Wenshu Board

The card board: a sibling package of the macOS app, the way `Mobile/` is.

It exists because the desktop app is not where a card board belongs. The boss
ordered it on 2026-11-02 while the Milanote and Apple Freeform teardowns were
being read: understand the two references first, and build the replica as its
own client rather than inside the shipping app.

## What it is

| Path | What it is |
| ---- | ---------- |
| `AGENTS.md` | The SSOT: 10 sections of hard rules, gates, and the workflow. |
| `Package.swift` | Its own SwiftPM package. Consumes `../Sources/WenshuData` as a local path package, so the two sides resolve the same bytes by construction. |
| `Sources/WenshuBoardKit/` | The card model: the element envelope, the placement regimes, the order key, and the join to a Wenshu chapter. |
| `Sources/WenshuBoardApp/` | The app target: one window, one column of cards. |
| `Tests/WenshuBoardTests/` | The test target. |
| `docs/board-plan.md` | What the client is for, what the two references contribute, what must not be copied, the phases, and the open decisions. |
| `docs/milanote-card-model.md` | The Milanote teardown: the element model, measured live against its API and its own bundles. |
| `docs/freeform-card-model.md` | The Apple Freeform teardown: the board app's own model, its App Intents, and the SDK quotes for the Apple-canonical answer. |
| `docs/adr/` | The client's decision records. |

## What it borrows, and from where

The model is ported from Milanote, measured live against its API and its own
bundles, and from Apple Freeform, read out of the installed app and the
installed SDK. Both teardowns live in this directory:
`docs/milanote-card-model.md` and `docs/freeform-card-model.md`.

Four things came across:

- **One envelope, many kinds.** A board, a column and a card are the same
  record (`BoardElement`); only the kind differs. A container holds cards and
  boards alike.
- **Two placement regimes.** A free canvas (`x`/`y` plus a z-order score) and
  an ordered list (an ordinal plus an order key), in one `location` field.
- **The order key.** A list order an insert does not have to renumber: the
  step is 65536, and a card placed above the head takes a negative rung
  (`BoardOrderKey`).
- **A canvas that is a view, not a migration.** The section decides which
  placement regime reads which field of the position, so the same record moves
  between the column and the free canvas (`BoardViewport`, `BoardCanvasView`).

## What it does not borrow

- No freeform file format. Apple's board package is not documented.
- No second writer. One library, one writer: this client does not open the
  same `.ws` the desktop app has open.

## Build

```bash
cd Board
swift build
swift test
```

## Where a chapter comes from

The file tier, not the SwiftData row.

`WSChapter` is in the schema and holds **zero rows** on a live library: the
store that would populate it (`FileSystemChapterStore`) is never instantiated
in production, so the table the migrations left empty stays empty. A client
built on that row would read an empty library and never know why.

So the client reads the same files the desktop app writes: a book's
`chapters/` folder, one Markdown file per chapter. `ChapterFileReader` reads
them, and `ChapterColumnBuilder` turns a chapter into a board and a column of
cards. The row path is still there for a library that has been migrated, and
it is marked as such.

## The one rule

The card model is the client's. The shared data tier is the repository's.
Neither reaches into the other: `ChapterColumnBuilder` is the whole join, and
it is a pure function.
