# Board — Plan

Date: 2026-11-02
Status: the client's plan, written before the client is built out. The two
reference teardowns are the inputs: `milanote-card-model.md` and
`freeform-card-model.md`.

## 1. What this client is for

The boss wants two things in a future version of Wenshu: **card-based chapter
organization** and **a content generation view**. He also wants them borrowed
from Milanote and Apple Freeform rather than invented, and he wants the
replica built as its own client rather than inside the shipping desktop app.

So the client is a **board**: a chapter seen as a column of cards, with the
agent able to put generated content into a card and the user able to move the
cards around. It is the place the shape gets tried, before the desktop app
carries it.

It is not a feature of the desktop app. The desktop app is an executable
target, so its views are not consumable, and a card board inside it would have
to be a copy of the desktop's views rather than a client of the shared model.

## 2. What the two references contribute

| From | What | Where it landed |
| --- | --- | --- |
| Milanote | One envelope, many kinds: a board, a column and a card are the same record. | `BoardElement` |
| Milanote | Two placement regimes in one `location` field: a free canvas, and an ordered list. | `BoardLocation` |
| Milanote | The order key: a list order an insert does not have to renumber. | `BoardOrderKey` |
| Milanote | The open content map: one writable path per kind, not a union of every field. | `BoardContent` |
| Milanote | The graph edges: a clone is a reference, a comment thread is a reference, a line is two endpoint references. | `BoardLocation.parentID`, `BoardContent.fields` |
| Freeform | The item vocabulary and the board's own flags, in Apple's own words. | `BoardElementKind`, the plan for the board's settings |
| Freeform | The Apple-canonical answer: what Apple ships, and what it does not ship on macOS. | §4 |
| Freeform | The way a third party writes to an Apple board: App Intents, not a file format. | §6 |

## 3. What the client has, and what it does not have yet

Has:

- `BoardElement` — the envelope, the kinds, the placement regimes, the content map, the metadata, the permission masks.
- `BoardOrderKey` — the order key, with the insert, the head rung, the rebalance and the ordering.
- `ChapterFileReader` — where a chapter actually comes from.
- `ChapterColumnBuilder` — the join: a chapter becomes a board and a column of cards.
- `BoardViewport` — the viewport as a pure function: the world-to-screen mapping and its inverse, the zoom clamp, the visible rectangle.
- `BoardCanvasView` — the infinite canvas view, built from the public pieces.
- `BoardCanvasDemo` — the demo elements the canvas renders.
- `RenderProof` — the offscreen proof: the canvas rendered into a bitmap, with no window and no human.
- `WenshuBoardApp` — one window with two tabs: a column of cards, and the canvas.

Does not have yet:

- A real library connection (the app shows the demo column).
- A card's own lifecycle: no status, no retry, no error, no per-card persistence.
- A card editor.
- The generation view.
- The board's own settings (the dot grid and the connector mode Freeform exposes).

## 4. The Apple-canonical answer, and the two places it is negative

Checked in the installed SDK, because the rule is to quote a signature that
exists.

| Need | Canonical symbol | The negative |
| --- | --- | --- |
| A card grid | `SwiftUI.LazyVGrid` | — |
| An ordered, rearrangeable list | `SwiftUI.List` + `.onMove` | — |
| A drag gesture | `.draggable` / `.dropDestination` | — |
| Rich text in a card | `SwiftUI.TextEditor` | — |
| Generated imagery | `ImagePlayground.imagePlaygroundSheet` | `ImageCreator` is **deprecated in 27.0** (= this client's floor), so the programmatic path is out |
| A canvas | `SwiftUICore.Canvas` + `MagnifyGesture` + `DragGesture` + `zIndex` (= the scroll geometry and the offscreen composite are for the later slices) | **PencilKit ships the drawing data model and not the canvas view**: `PKCanvasView` is exported by PencilKit, but Apple ships no header for it on macOS and the macOS Swift interface does not expose it. macOS 27 adds no infinite canvas of its own. PencilKit ships the drawing data model and not the canvas view |
| Icons | SF Symbols 6 | The desktop app's icon factory is in the app target and is **not consumable** |

Two consequences for this client:

- **The canvas is hand-rolled, and that is the point.** Apple ships the
  pieces and not the product: there is no public infinite canvas on macOS, and
  the reference's own canvas is private classes. The client builds it from
  `SwiftUICore.Canvas`, `MagnifyGesture`, `DragGesture` and `zIndex`; the
  scroll geometry and the offscreen composite come with the later slices.
  The arithmetic that matters is the viewport,
  and it is a pure function, so it is testable without a window.

  The first slice of it exists: `BoardViewport` + `BoardCanvasView`, with an
  offscreen `ImageRenderer` proof that renders the canvas into a bitmap with
  no window and no human. The model needed no change to carry it — the
  section already decides which regime reads which field of the position, so
  the canvas is a **view**, not a data migration.
- **The client needs its own design layer.** The desktop app's `SFIcon`,
  `DesignTokens`, `IconStyle` and `IconColor` live in
  `Sources/WenshuApp/Shared/UI/`, which is the app target. Either the tokens
  move into `WenshuData` (a change to the shared layer, which the desktop's
  own gates would have to accept) or the client carries its own. **Open.**

## 5. What must not be copied

- **The chapter concept.** Milanote has boards, columns and cards. "Chapter" is
  a Wenshu concept: a board is a chapter, a column is the ordered card list,
  a card is a chapter's content block.
- **The LLM authoring.** Milanote has no model for it. The generation view is
  Wenshu's own; Milanote contributes the container shape only.
- **The canvas regime's expensive extras.** The regime itself is borrowed;
  these parts of it are not: the collision reflow (cards push each other when
  one grows), the locked position, the 3D drag effects, the connector mode,
  and the per-board brush and shape settings. The z-order is borrowed.
  The reference's reflow is now measured: a grid-aligned cascade with a
  hard cap of 150 candidates and a five-second cooldown, and it never runs
  while a card is being dragged, resized or edited. The grid alignment is
  worth copying; the cascade is not.
- **`attrs.key`.** Every block in Milanote's ProseMirror document carries a
  short random id, because ProseMirror needs a node identity to reconcile a
  re-parse. Wenshu's text is Markdown, and Markdown does not need it. Copying
  it would put an editor implementation detail into the domain model.
- **The trash with a restore point.** Milanote's `restoreLocation` is a
  graph-database convenience. Wenshu has its own deletion semantics.
- **Grammarly per card.** Out of scope.

## 6. The interoperation question, answered by Apple's own answer

Freeform's board is a package (`com.apple.freeform.board`), but **its layout
is not documented**, so reading or writing one is not a safe commitment. What
Apple ships instead is **App Intents**: nineteen of them, including
`CRLAddItemToBoardIntent`, which adds a sticky note, a text box, a shape, a
link or a file to a board, with `openAppWhenRun: false`.

So if this client is ever asked to put something into a Freeform board, the
Apple-canonical route is an App Intent, not a file parser. The full surface is
in `freeform-card-model.md` §2.5.

The same question inside Wenshu has the same shape of answer: the client's own
model, and the shared data tier underneath it.

## 7. Where the data comes from

The file tier is the truth for a chapter's body.

`WSChapter` is in the SwiftData schema and holds **zero rows** on a live
library: the store that would populate it (`FileSystemChapterStore`) is never
instantiated in production, so the table the migrations left empty stays
empty. A client built on that row would read an empty library and never know
why. The body of a chapter is a Markdown file under the book's `chapters/`
folder, and the index beside it is a `chapters.json` whose writer and reader
disagree about the shape (the writer emits one object, every reader expects an
array, and the decode failure is swallowed into an empty list).

So the client reads the same files the desktop app writes
(`ChapterFileReader`), and the row path stays for a library that has been
migrated.

The order is worth stating, because the two sides do not agree: the client
takes the file name's order (= UUID order, because the file name is a
UUID), and the desktop app's own document list is sorted by the document's
last update, newest first. Neither is a chapter number, and no tie-break
between them is promised.

## 8. The writer rule

One library, one writer. The desktop app owns the library. This client is a
**reader** of it, and it must never write a `.ws` the desktop app has open.

That is a constraint the reference does not have to face, and it is the one
decision that shapes the client's architecture. Two ways to honour it:

- **(a) Read the files directly**, and never write. The risk is a torn read
  while the desktop app is saving.
- **(b) Read through a companion API**, the way the mobile client does. The
  clean answer, and a bigger piece of work: the companion service does not
  exist yet.

**Open.** The first release takes (a) and says so in the README.

## 9. The phases

| # | Slice | Why it is separate |
| --- | --- | --- |
| 1 | The model: the envelope, the kinds, the placement regimes, the order key, the file reader, the join. | Done, in the first commit. It is the whole reference model with no UI on it. |
| 2 | A real library connection: open a `.ws`, list its books, read a chapter, show its cards. | Depends on the writer rule (§8). |
| 3 | The card view: one chapter as a column, cards that can be selected, moved and reordered. | A UI slice; the boss looks at it in person. |
| 3a | The canvas: the viewport arithmetic, the pan and the zoom, the dot grid, the z-order, the cull. | The core of the reference's canvas, built from the public pieces. Its arithmetic is proven by the viewport tests and by the offscreen render. |
| 3b | The canvas as a layout tree: a transform chain to the root, a clip rect, a culling bound, and a live manipulation that keeps a dynamic geometry beside the committed one. | The reference's canvas is a tree with a dynamic/committed split, and that split is what lets a drag avoid writing the library. |
| 4 | A card's own lifecycle: a status, an attempt, an error, and a row per card. | A persistence slice; it needs the shared model layer, so it decides §4's design-layer question. |
| 5 | The generation view: `ImagePlayground` for imagery, the agent for text, into a card. | Depends on 3 and 4. |

## 10. The open decisions

1. The writer rule: read the files, or read through a companion API?
2. The design layer: do the desktop's tokens move into `WenshuData`, or does the
   client carry its own?
3. Does a card become a first-class record, or stay a projection of the
   chapter's Markdown? A record can carry its own state and be referenced from
   two places; a projection cannot.
4. Does the chapter's body stay the source of truth, or do the cards become it?
   The second is a non-additive change and needs a declared schema version.
5. Which of Freeform's board settings carry over: the dot grid (taken), the
   connector mode, the shape library, the brush set?
6. Does the zoom snap to a ladder? The reference pins the view scale: a fast
   pinch snaps to the ladder and a slow pinch is continuous. A replica that
   only zooms continuously feels different in the hand.
7. Does the board open in the list regime or the canvas regime by default, and
   does a chapter keep both? Milanote's board holds both at once (a section
   decides which), so the client can too.
8. Does the client get its own CI job? The repository's runner (`macos-14`, Xcode 15.4) is
   behind the repository's own macOS 27 floor, so a job for `Board/` would be red on
   arrival. Until a runner that can build the floor exists, the client's build and test
   gates are manual (`cd Board && swift build`, `cd Board && swift test`).


## 11. The measured facts behind this plan

The two teardowns are the evidence, and both are reproducible:

- `milanote-card-model.md` — the element envelope, nineteen kinds, the two
  placement regimes, the 65536-step order key, the 142 registered property
  paths (122 content, 11 location, 9 meta), the ProseMirror document, the read
  endpoints, and the one write endpoint.
- `freeform-card-model.md` — the two exported UTIs, the nineteen App Intents,
  the item type enum, the board entity's properties, the internal `CRL*`
  classes, the CloudKit persistence, and the SDK quotes for the Apple-canonical
  answer.
