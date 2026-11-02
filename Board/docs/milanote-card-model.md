# Milanote — Card Model Teardown

Date: 2026-11-02
Target: the Milanote web app, version `3.18.142` (`GET /api/version/status?version=3.18.142&appType=web` → `currentVersion`)
Why: the boss plans card-based chapter organization and a content generation view in Wenshu, and wants both references read before any of it is built. Milanote is the reference for the **data model**.
Status: reference teardown. Measured against a live account; no Wenshu code in this document.

Its sibling: `freeform-card-model.md` (Apple's own board app = the reference for the Apple-canonical answer). The synthesis that turns both into a client is `board-plan.md`.

## 1. Method and evidence grade

Measured against a real account, one workspace, one board.

| Evidence | How | Grade |
| --- | --- | --- |
| Element envelope, field names, live values | `GET /api/boards?loadAncestors=true&ids=1TRVcg19Es2pe6` | measured |
| Type registry, property paths, enums, action names | static read of the app's own JS bundles (26 chunks, 9.2 MB) | measured |
| Toolbar palette, preferences text | `locales-en-f9788f827ce4-modern.js` (the app's own English strings) | measured |
| View-layer component contract | `propTypes` of the element component in `main-…-modern.js` | measured |
| Canvas layout semantics, ordering key | live values across 32 elements | measured |
| Per-type rendering, drag mechanics, animation | not inspected | not measured |

Auth: `POST /api/auth/login` with `{"email","password"}` returns `{"token","userId"}`. Every later call carries `authorization: Bearer <token>`. No AWS WAF challenge on the JSON API from a plain client, even though the web app loads `static.milanote.com/awswaf/…/challenge.compact.js`.

Reproduction: see §17.

## 2. The one idea to copy: one envelope, many types

Every entity on a Milanote board — a board, a column, a note, a table, a comment thread — is the **same record shape**. Only `elementType` and the keys inside `content` differ.

```
{
  __v: 0,                       // record schema version
  _id: "1TRVcg19Es2pe6",
  id:  "1TRVcg19Es2pe6",
  elementType: "BOARD",
  location: { … },              // where it sits (see §4)
  content:  { … },              // type-specific payload (see §6)
  meta: { … },                  // who/when (see §5)
  acl:  { "<userId>": 31 }      // per-user permission bitmask, null when inherited
}
```

Consequences worth copying:

- A container and a card are the same type of thing. A column holds cards; a column also holds boards. Nothing in the record says "this is a leaf".
- `content` is open per type. The record never carries a union of every field.
- `acl` is a map user → bitmask (`31` on the root board), not a boolean. Null on children = inherit from the parent.

## 3. Type registry

19 element types (`main-…-modern.js`, the `ALIAS_TYPE` enum). `SKELETON` and `UNKNOWN` are internal and excluded from the searchable set.

| `elementType` | Toolbar label | Icon class | Notes |
| --- | --- | --- | --- |
| `CARD` | Note | `element-card` | the default text card |
| `BOARD` | Board | `element-board` | also the container for columns and boards |
| `COLUMN` | Column | `element-column` | an ordered stack of cards |
| `LINK` | Link | `element-link` | `content.linkType` selects the flavour |
| `LINE` | Line | `element-line` | has `content.start`/`content.end` element ids |
| `IMAGE` | Add image | `element-image` | `content.image.*` size ladder |
| `FILE` | Upload | `element-file` | `content.file.{filename,size,url,mime,type}` |
| `COMMENT_THREAD` | Comment | `element-comment-thread` | body lives in a separate collection |
| `TASK_LIST` | To-do | `element-task-list` | ordered list of `TASK` children |
| `TASK` | — | — | one row of a `TASK_LIST` |
| `CLONE` | — | `element-clone` | a reference to another element |
| `SKETCH` | Sketch | `element-sketch` | freehand drawing |
| `ANNOTATION` | — | — | image annotation |
| `COLOR_SWATCH` | Color | `element-color-swatch` | a palette colour chip |
| `DOCUMENT` | Document | `element-document` | long-form rich text |
| `TABLE` | Table | `element-table` | grid of styled cells |
| `ALIAS` | — | — | alias record |
| `SKELETON` / `UNKNOWN` | — | — | internal |

The **toolbar** exposes 22 items, i.e. the palette a user can place: Add image, AI Ideas, Audio, Board, Color, Column, Comment, Document, Draw, Folder, Heading, Line, Link, Map, Note, Sketch, Table, To-do, Upload, Video. The toolbar is wider than the type registry because `Audio`, `Map`, `Video` are `LINK` flavours (`content.linkType`), `Folder` is a sidebar container rather than a board element, and `Heading` is a text block rather than an element.

`AI Ideas` is a real toolbar entry and a real analytics event (`AI:"AI Ideas"`). Its implementation was not located in the fetched bundles; it is most likely entitlement-gated or lazily chunked. **Not verified.**

## 4. Placement: two regimes, one field

`location` carries the parent edge and the placement mode.

```jsonc
"location": {
  "parentId": "1TRVcg19Es2pe6",
  "section":  "CANVAS",         // CANVAS | INBOX | TRASH | DELETED | ATTACHED | QUICK_NOTES
  "position": { "x": 67, "y": 11, "score": 65536, "index": 0, … }
}
```

| Section | Position means | Container shape |
| --- | --- | --- |
| `CANVAS` | free `x`/`y` in pixels + `score` as z-order | infinite canvas |
| `INBOX` | `index` (ordinal) + `score` (order key) | ordered stack |
| `TRASH` / `DELETED` | soft-delete target | trash bin |
| `ATTACHED` | child of another element | attachment slot |
| `QUICK_NOTES` | the Quick notes root | — |

`position` also carries `addedDate`, `deletedDate`, `attachMode`, and `restoreLocation {parentId, section}` — **the restore point**, which is how undo/trash-restore returns an element to its former parent.

Two boards are `location.rootBoard: true` and carry `content.rootType`:

| `rootType` | Title | Meaning |
| --- | --- | --- |
| `WORKSPACE` | Home | the workspace root board |
| `TEMPLATES` | Templates | template library root |
| `QUICK_NOTES` | Quick notes | a special always-present scratch board |

Everything else is a `BOARD` with `location.parentId` set.

### 4.1 The ordering key

List order is **not** the `index` alone. Every `INBOX` child also carries a `score`, and the scores in the live board are `0, 65536, 131072, 196608, …` — a fixed step of **65536** — with **negative** multiples for items inserted before the head (`-262144, -327680, …`).

That is a fractional index: `score` alone totally orders the list, and a new item can be inserted between two neighbours without renumbering the whole list. `index` is a denormalised ordinal.

**This is the single most directly copyable mechanism in Milanote.** Wenshu's chapter order needs exactly this (insert a chapter between two, from the agent, without rewriting the list).

### 4.1.1 The order key, in the reference's own source

The step is a named constant and the insert rule is a pure function, both read
out of the main bundle (module 69045):

```js
const c = 65536;                                   // the step
const d = e => { const t = []; for (let n = 0; n < e; n++) t[n] = n * c; return t; };
const u = (prev, next, n) => next == null ? c : prev == null ? -c : (next - prev) / (n + 1);
const p = (prev, next, gap) => (prev == null && next == null) ? 0 : (prev == null) ? next + gap : prev + gap;
const m = (list, at, n) => {
  const r = clamp(0, list.length, at),
        i = list[r - 1], s = list[r],
        gap = u(i, s, n), base = p(i, s, gap);
  if (base === i || base === s) return null;        // no room: the caller must rebalance
  return base + n * gap;
};
```

Four facts, and the client's `BoardOrderKey` has to match all four:

| Fact | Consequence |
| --- | --- |
| The step is `65536` | The gap between two neighbours divides evenly. |
| A head insert takes a **negative** score (`next - 65536`) | The head is not special-cased in the data; it sits below zero. |
| A batch insert of `n` items divides the gap by `(n + 1)` | Inserting three cards at once needs one gap, not three. |
| The insert returns **`null`** when the gap is exhausted | The caller must rebalance (= renumber) instead of writing a colliding key. |

The measured ladder (`0, 65536, 131072, 196608`, and the head's `-262144,
-327680`) is this function's output.

### 4.2 Canvas to column

`element.groupIntoColumn` is the action that converts free-canvas cards into one ordered column. The reverse (`inList` flag on the element component) is what the view reads. So the two regimes are not separate features — they are two renderings of the same record, and the product can move a card between them.

## 5. `meta`

```
meta.creator, meta.modifiedBy, meta.createdTime, meta.modifiedTime,
meta.significantModified, meta.aclModifiedTime, meta.locationSectionModifiedTime,
meta.platform ("Desktop web"), meta.versionId ("1Wnsn4djtM-1"), meta.tempId
```

`versionId` is `<elementId>-<counter>`: the version counter belongs to the element, not to a revision chain. `significantModified` separates "content changed" from "position changed" (the latter only bumps `locationSectionModifiedTime`) — that split is what lets the app skip a full-board refresh when a card is merely dragged.

## 6. Content payload: 142 registered property paths

The app registers every writable path of every element type against the store. 122 are `content.*`, 11 `location.*`, 9 `meta.*`. Grouped by concern:

| Concern | Paths |
| --- | --- |
| Identity | `content.title`, `content.originalTitle`, `content.icon.{id,type}`, `content.showTitle` |
| Colour | `content.color`, `content.secondaryColor`, `content.color.{space,value}`, `content.showColorValue`, `content.defaultColorPalette`, `content.autoColorIndex` |
| Geometry | `content.width`, `content.height`, `content.minHeight`, `content.maxHeight`, `content.autoHeight` |
| Text | `content.textContent`, `content.caption`, `content.captionModified`, `content.keywords` |
| Media | `content.media.{width,height,originalWidth,originalHeight}`, `content.mediaType`, `content.mediaOnlyDisplay`, `content.image.{regular,large,huge,original,thumb,error,width,height,colors,primaryColor,isDataUri}`, `content.imageOriginal`, `content.backgroundRemoval`, `content.previewReady`, `content.audioOnly`, `content.mediaPlayerLoop`, `content.mediaPlayerAutoplay` |
| Link | `content.link.{url,title,favicon,type}`, `content.linkType` |
| File | `content.file.{filename,size,url,mime,type,uploadedTimestamp}`, `content.attachmentId` |
| Table | `content.tableContent.{version,data,colWidthsGU}` |
| Task | `content.isComplete`, `content.assignments`, `content.dueDate`, `content.dueReminder`, `content.dueReminderTimestamp` |
| Sketch | `content.drawing.{svg,width,height}`, `content.drawingMode` |
| Line | `content.start.elementId`, `content.end.elementId`, `content.startStyle`, `content.endStyle`, `content.lineStyle`, `content.lineWeight`, `content.lineLabel` |
| Clone | `content.linkTo`, `content.clonedElementType` |
| Board | `content.rootType`, `content.inbox`, `content.locked`, `content.start`/`content.end` element ids |
| Document | `content.displayMode`, `content.welcomeMessage.{textContent,modifier}`, `content.showBackground`, `content.background.{color,showGrid,hideImage}`, `content.originalImage.*`, `content.originalIcon`, `content.originalColor`, `content.originalSecondaryColor` |
| Comment | `content.threadId`, `content.duplicatedFromThreadId`, `content.collapsed` |
| Misc | `content.reactions`, `content.type`, `content.keywords`, `content.previousCanvasOrigin`, `content.inboxAutomaticOpenTimestamp`, `content.mobileInboxAutomaticOpenTimestamp`, `content.publicEditEnabledTimestamp`, `content.publishedFeedbackEnabled`, `content.publishedMediaDownloadDisabled` |

Two naming details worth copying: `tableContent.colWidthsGU` — column widths are stored in **graph units**, not pixels, so a table keeps its proportions across zoom; and `content.previousCanvasOrigin` — where the element was before it was moved into a container.

## 7. Rich text: a ProseMirror document

`content.textContent` is a ProseMirror JSON doc:

```jsonc
{ "type": "doc", "content": [
  { "type": "paragraph", "attrs": { "key": "UZKvM", "textAlign": "left" } },
  { "type": "heading",   "attrs": { "key": "bCD9", "textAlign": "center", "level": 1 } },
  { "type": "taskList",  "content": [
      { "type": "taskItem", "attrs": { "taskId": "1Wnspz1ukG9Ifc", "checked": false },
        "content": [ { "type": "paragraph" } ] } ] }
] }
```

Every block carries `attrs.key`, a short random id. That id is the **node identity** the editor uses to reconcile re-parsed markdown against a live document. `textAlign` is per block, so alignment is a property of the block, not the card.

Observed node kinds: `doc`, `paragraph`, `heading` (with `level`), `taskList`, `taskItem`, `text`. A richer schema exists in a lazily loaded editor chunk that was not fetched.

### 7.1 Task items are elements, not text

A `TASK_LIST` holds `content.textContent` whose `taskItem` nodes carry only `taskId` and `checked`. The task itself is a separate element: `TASK` with `location.parentId` = the `TASK_LIST` id. So the list is normalized — the text document references rows, and each row is an addressable element that can carry its own `isComplete`, `assignments`, `dueDate`.

## 8. The graph

The store is a property graph. `graphDbSyncDate` on the user record and `initialisationMethod: "graph"` on the app-init payload both say so.

- An element is a node. `location.parentId` is the containment edge.
- `CLONE` is a reference edge: `content.linkTo` points at another element id, and `content.clonedElementType` records what it pointed at. The product asks the user *"When a note is duplicated, ask 'Keep this copy in sync?'"* — a clone is a synced copy, not a copy.
- `COMMENT_THREAD` is a reference edge: `content.threadId` points into the separate `comments` collection returned alongside `elements` by the boards API.
- `LINE` is a reference edge pair: `content.start.elementId` and `content.end.elementId`.

`GET /api/boards` returns five collections: `elements`, `comments`, `labels`, `errors` — plus `childrenReturned`, `canvasOrder`, `boardIds`, `elementCount`, `commentCount`, `errorCount`, `fetchedTime`. `GET /api/users/me/app-init` returns `elements`, `elementsCreated`, `elementCount` **per element type**, `remoteUserIds`, `boardHierarchies`, `initialisationMethod`, `initialised`, `cache`.

## 9. View contract for a card

The element component's `propTypes` in `main-…-modern.js` is the cleanest statement of the runtime contract:

```
element, elementId, gridSize, inList, inTrash, isSelected, isSingleSelected,
isEditing, isEditable, updateTitle, navigateToBoard, connectDropTarget,
connectLineEdgeDropTarget, onTitleEditDone, setLineHoverEffect,
setElementHoverEffect, className, documentMode, isBoardFetched,
isBoardDuplicating, elementEvents, canConnectLineEdge, isPresentationModeEnabled
```

Reading it as a specification:

- `gridSize` — the canvas has a **grid**, and cards snap to it (`element.cropImageToFitDotGrid`).
- `inList` — the same card renders differently inside a column than on the canvas. One component, two layouts.
- `inTrash` — deleted state is a render mode, not a different type.
- `isEditable` / `isEditing` — read-only boards (published, or shared without edit rights) reuse the same component.
- `documentMode` — the document card switches between icon and detail presentation.

User-facing element actions (`element.*` in the bundle): `move`, `copy`, `cut`, `paste`, `pasteStyles`, `duplicate`, `delete`, `rename`, `download`, `downloadOriginalImage`, `downloadSvg`, `bringToFront`, `lockPosition`, `groupIntoColumn`, `convertToBoard`, `convertToDocument`, `convertToNote`, `convertToSketchCard`, `createShortcut`, `createSyncedCopy`, `duplicateLinkedBoard`, `findOriginalBoard`, `collision`, `dnd`, `modal`.

`element.collision` is the reflow rule: *"Prevent cards from overlapping — Automatically move nearby cards when editing causes a card to grow."*

## 10. The product states its own behaviour

From the preferences panel (`locales-en`). This is a behavioural spec, written by the product:

| Setting | Behaviour |
| --- | --- |
| Prevent cards from overlapping | Automatically move nearby cards when editing causes a card to grow |
| Keep this copy in sync? | Asked when a note is duplicated |
| Convert to a document? | Asked when a note becomes too long |
| Delete completed tasks? | Asked when items are checked off a to-do list |
| Add a title to this list? | Asked when you create multiple to-do items |
| Double click/tap to create new notes | Quick creation on canvas and in columns |
| Show grid by default | Per-board, toggled by right-clicking the background |
| Enable 3D effects when dragging | Disabling improves performance on older devices |
| Enable ink effect when drawing | Speed and pressure affect line thickness |
| Show undo/redo arrows | Visual alternative to the keyboard shortcut |
| Show template suggestions | Recommended templates shown on board creation |

Three of these are **type-promotion prompts**: note → document, duplicate → synced clone, task list → titled list. The product treats the element type as something that changes as the user works.

## 11. Read and write protocol

Read:

```
GET /api/boards?loadAncestors=true&ids=<boardId>
  → { elements: {id: element}, comments: {}, labels: {}, errors: {},
      childrenReturned: {boardId: []}, canvasOrder: {}, boardIds: [],
      elementCount, commentCount, errorCount, fetchedTime }
```

The client-side fetch action carries `{boardIds, loadAncestors, excludeSelf, canvasOrder}` and is debounced 250 ms; the result is cached per board id, with a cache hit served locally and a miss going to the network.

Write (from the update action in `main-…-modern.js`):

```js
dispatchSetMediaAutoplay({ updates: [{ id: "1Wnsq71ukG9Ife", changes: { mediaPlayerAutoplay: true } }] })
```

So a mutation is a **batch of `{id, changes}` patches against the content tree**, not a whole-record PUT. The endpoint was not located in the fetched bundles (constructed dynamically); the shape above is what the client emits.

### 11.1 The write protocol is one endpoint

Every mutation goes to **`POST /api/actions`**. Measured: the endpoint answers `POST` with `200`; `POST /api/boards` is not a REST route (it returns the SPA HTML), so board creation is an action too. The wire envelope is not documented and could not be pinned down by probing (an empty or malformed body returns the same `500 {"detail":"TypeError: Cannot read properties of undefined (reading 'type')"}` for every shape tried), so the **client-side action creators are the measured truth**:

```js
// update
dispatchSetMediaAutoplay({ updates: [{ id: "1Wnsq71ukG9Ife", changes: { mediaPlayerAutoplay: true } }] })

// move
dispatchMoveElements({
  moves: [{ id, location: { parentId, section: "ATTACHED", position: { attachMode: "inline" } } }],
  moveOperation: undefined,
  initialMeasurements: undefined,
  transactionId,
  actionOrigin: undefined
})
```

Two things to copy: **a mutation is a patch against the content tree, not a whole-record write** (`{id, changes}`), and **a move is expressed as a location change** (= the same `location` field a read returns). The move carries `transactionId` and `actionOrigin`, so the server can attribute and de-duplicate.

### 11.2 The read endpoints (measured, 16 of them)

| Endpoint | Shape |
| --- | --- |
| `GET /api/boards?loadAncestors=true&ids=<id>` | the board graph (the `elements` dict) |
| `GET /api/boards?excludeSelf=false&loadAncestors=false&ids=<ids>` | several boards at once |
| `GET /api/boards/modified?ids=<ids>` | what changed since a revision |
| `GET /api/users/me` | the user, with `contentLimit` and `graphDbSyncDate` |
| `GET /api/users/me/app-init?timezone=<offset>` | the boot payload: elements, the per-type census, `initialisationMethod: "graph"` |
| `GET /api/users/me/notification-preferences` | preferences |
| `GET /api/users?ids=<ids>` | other users on shared boards |
| `GET /api/users/activity?ids=<ids>` | the activity feed |
| `GET /api/notifications?after=<n>` | the notification cursor |
| `GET /api/actions` | the action log |
| `GET /api/cms/releases?platform=Web` | the release notes |
| `GET /api/locales` | the locale bundle |
| `GET /api/version/status?version=<v>&appType=web` | the version gate |
| `POST /api/auth/login` | `{email, password}` → `{token, userId}` |
| `POST /api/auth/upgrade-better-auth-session` | session refresh |

Auth is `authorization: Bearer <token>`; there is no cookie. The board graph endpoint accepts several board ids at once, which is how the client prefetches a board plus its ancestors.

### 11.3 The write envelope, in the reference's own source

The single write call site, read out of the main bundle:

```js
await transport({ url: "actions", method: POST, data: { action: s } });
```

so the body is **one action per request, wrapped in `{ action: { type, ... } }`**.
An earlier attempt with `{ updates: [...] }` and `{ moves: [...] }` at the top
level returned `500 TypeError: Cannot read properties of undefined (reading
'type')`, and this is why: the server reads `body.action.type`.

The action creators and the shapes they build:

| Action | Shape | Source |
| --- | --- | --- |
| update content | `{ type, updates: [{ id, data }], transactionId }` | module 65992 |
| update element (undoable) | `{ type, id, elementType, changes, undoChanges, transactionId }` | `Cr.DD` |
| create element | `{ type, elementType, location, content, transactionId, select }` | `Tr.OX` |
| select | `{ type, ids, transactionId, rangeAnchors }` | `Sr.lj` |
| delete | `{ type, ids, transactionId }` | `Sr.b9` |
| **move** | `{ type, parentId, section, sortFn, moveOperation, initialMeasurements, transactionId, actionOrigin }` | `Yr.DL` / reducer case `b.ce` |

**The move action carries no score.** It carries the target `parentId` and
`section` plus a `sortFn`, and the client recomputes every moved element's
`location.position.score` locally, from the sorted order:

```js
case MOVE: (state, t) => {
  const graph = elementGraph(state),
        sorted = sortElements({ elements: state, elementGraph: graph, parentId: t.parentId, section: t.section, sortFn }),
        scores  = scoreLadder(sorted.size);
  return state.merge(sorted.reduce((acc, el, i) => {
    acc[idOf(el)] = el.setIn(["location", "position", "score"], scores[i]);
    return acc;
  }, {}));
}
```

That is the whole reason the score ladder is fractional: **the client
computes the order, and the server only has to believe it.**

### 11.4 A live edit is not a write

The action-type vocabulary includes two constants that answer the drag
question:

```
ELEMENT_EDIT_START
ELEMENT_EDIT_COMPLETE
```

plus `ELEMENTS_SELECTED`, `ELEMENTS_DESELECTED`, `ELEMENTS_DESELECT_ALL`,
`ELEMENTS_FORCE_REMOTE_DESELECT`, `TABLE_ELEMENT_CELL_SELECTIONS_UPDATE`,
`ELEMENTS_RESET_SCORES`, `TRASH_CLEAR_START` / `_COMPLETE` / `_FAILED`.

`ELEMENT_EDIT_START` marks the beginning of a manipulation and
`ELEMENT_EDIT_COMPLETE` the commit. So Milanote, like Freeform (§4.3 of the
other teardown), keeps the live manipulation transient and writes only the
committed state. **A drag is not a write, and this is how the reference says
so.**

## 12. Feature surface Milanote has, and the question each raises for Wenshu

| Milanote feature | Status in Milanote | Question for Wenshu |
| --- | --- | --- |
| Free canvas | Yes, first-class | Wenshu is document-first. Does a chapter get a canvas at all? |
| Column = ordered card stack | Yes | This is the chapter → card list mapping |
| Card type promotion (note → document) | Yes, prompted | Should Wenshu promote a chapter to a different card kind? |
| Synced clone | Yes, prompted | Should Wenshu chapters be referenceable from two places? |
| Trash with restore point | Yes | Wenshu has its own delete semantics — do not copy blindly |
| Comments | Yes, a separate collection | Does Wenshu need comments on a chapter card? |
| Labels | Yes, a separate collection | Wenshu has tags — map or skip |
| Published read-only board | Yes | A share view for Wenshu chapters? |
| Templates | Yes, a root board | Wenshu has `Sources/WenshuApp/Resources/SOPs/ImportChaptersPrompt.md` — is that the analogue? |
| Folders in the sidebar | Yes | Wenshu has shelves + books — map onto those, not onto Milanote folders |
| AI Ideas | Toolbar entry + analytics event; implementation not located | This is the closest thing to the boss's "content generation view" |
| Activity digest | Yes, daily summary of shared-board changes | Wenshu's agent session log is the analogue |
| Grammarly per card | Yes | Out of scope |

## 13. Mapping to Wenshu — card-based chapter organization

> **Where this lands.** The replica is its own client, at `Board/`, a third SwiftPM
> package beside the root app and `Mobile/`. It is NOT a feature of the shipping
> desktop app (= the desktop app is an executable target, so its views are not
> consumable, and a card board inside it would have to be a copy). The client
> consumes `Sources/WenshuData` as a local path package, so both sides resolve the
> same bytes by construction. Branch `wt/board-client`, commit `041143d626`.


Wenshu's current chapter storage is a per-book `chapters` JSON plus a `FileSystemChapterStore`. The Milanote model contributes four things:

1. **One envelope for every chapter artifact.** A Wenshu chapter currently has one shape. A card-based organization needs a chapter to be able to hold several kinds of child (a note, a table, a sub-board, a generated draft). Milanote's answer is that `content` is open per `elementType`, and the container type is independent of the child type. Wenshu's equivalent is one `@Model` with a `kind` discriminator and a payload, instead of one `@Model` per chapter kind.
2. **A fractional order key, not an integer index.** Milanote's `score` (step 65536, negative for pre-head) is the mechanism for "insert a chapter between two without rewriting the list". Wenshu's chapter list needs the same, because the agent inserts chapters mid-list.
3. **`location.parentId` + `section`, not a nested array.** Milanote's containment is an edge on a flat record. Wenshu's chapter tree should be an edge too, so a chapter can be reparented by one field write instead of rebuilding a nested tree.
4. **One card component, two layouts.** Milanote renders the same card on the canvas and in a column (`inList`). Wenshu's chapter card should render the same in a chapter list and in a board/grid view.

## 14. Mapping to Wenshu — the content generation view

Milanote has no LLM in the data model; `content.textContent` is whatever the user typed or pasted. So the generation view is **not** a Milanote feature to copy — it is a Wenshu feature that Milanote's *shape* makes possible.

What Milanote supplies is the destination shape:

- The generated text lands in a `DOCUMENT` element's `content.textContent`, as a ProseMirror doc with per-block `attrs.key`.
- A generated artifact is an element in the same graph as everything else, so it can be moved, ordered, cloned, and commented like a hand-made one.
- `content.isComplete`, `content.assignments`, `content.dueDate` are how a generated item carries workflow state rather than just text.

Wenshu's equivalent, in its own stack:

- Wenshu's text is Markdown (`swift-markdown-engine` 0.13.x is an approved upstream). Milanote's is ProseMirror JSON. The mapping is a converter at the boundary, not a storage change.
- `attrs.key` per block has no Wenshu equivalent and **should not be copied** — it exists to reconcile a ProseMirror re-parse, which Wenshu's Markdown parser does not need. Copying it would put an editor implementation detail into the domain model.
- The order key and the containment edge **do** transfer, because they are storage concerns, not editor concerns.

## 15. Open questions for the replication plan

1. Does the Wenshu chapter card need more than one kind (note / table / generated draft), or is one rich-text card enough for v1?
2. Is the chapter tree allowed to be reparented by the agent, or is the tree fixed by the book structure (AGENTS.md §3.6)?
3. Does the generation view write into the chapter in place, or into a staging area that the user promotes?
4. Where does the order key live — on the chapter record, or on a separate ordering table?

## 16. Reproduction

```bash
# 1. session token
curl -sS -X POST https://app.milanote.com/api/auth/login \
  -H 'content-type: application/json' \
  -d '{"email":"<account>","password":"<password>"}'

# 2. board graph (Bearer token)
curl -sS -H "authorization: Bearer <token>" \
  'https://app.milanote.com/api/boards?loadAncestors=true&ids=<boardId>'

# 3. app-init census by element type
curl -sS -H "authorization: Bearer <token>" \
  'https://app.milanote.com/api/users/me/app-init?timezone=-480'

# 4. bundles (public CDN, no auth)
curl -sS https://static.milanote.com/main-0d527f601f26-modern.js -o main.js
# the type registry, the 142 property paths, the section/rootType enums,
# the element component propTypes and the toolbar palette all live in the
# bundles + the locales chunk
```

Bundle URLs are version-pinned by content hash; the names above are from version `3.18.142` and will move on the next release.

## 17. The canvas interaction rules, in the reference's own source

### 17.1 The collision engine: an auto-shift measured in grid points

The reference pushes a card out of the way when another card grows into it.
The engine (main bundle, module 64955, channel `element.collision`) is a
pure function of the geometry, and its rules are:

| Rule | The source says |
| --- | --- |
| **It only runs in the canvas regime** | `if (!a || a.section !== CANVAS) return;` — a list never pushes anything |
| **The overlap is measured in grid points** | the warning reads `shifting %s by %s grid points`; the grid unit is `A` and the shift is `round((bottom + 4) / A) + overlap - (top mod A)` |
| **The collision box is the neighbour's box grown by four grid units** | `{...z, bottom: z.bottom + 4 * A}` |
| **A push is snapped to the grid** | the new top is `floor(top / A) * A + shift + offset`, so a pushed card lands on the lattice |
| **The shift is at least two grid points once the overlap exceeds three** | `const g = u > 3 ? 2 : u` |
| **A card is never pushed above where it started** | the new y is `max(computed, original)` |
| **Locked cards are not pushed, and a card in another parent is not a neighbour** | `if (isInList(t) && (isLocked(t) || parentOf(t) !== parentOf(moved))) return;` |
| **A card with no area is skipped** | it warns `Neighbour element has no area` and continues |
| **The push cascades** | the pushed cards are re-checked with their new measurements, so a push travels down the column |
| **If a card is pushed twice, the larger push wins** | a dedupe pass keeps the record with the greatest y |
| **The original position is saved, but only for a downward push with an overlap over three** | `saveOriginalLocation: s && u > 3` — so a push can be undone |
| **A card that is not pushed but overlaps is recorded locally only** | `autoPush: false, saveOriginalLocation: true, noSync: true` |
| **There is a hard cap of 150 candidates** | `if (candidates.length > 150 && !disableAutoShiftLimit) return []` — past 150 neighbours the auto-shift is skipped entirely |
| **The cap is lifted by a server-side feature flag** | `disableAutoShiftLimit` is one of the app-init feature flags, so it is per account, not per user |
| **A card that is being resized, dragged or edited does not trigger it** | three guards return early, so the engine never fights a live manipulation |
| **It runs at most every five seconds** | the cooldown is `5 * SECOND` |
| **There is a recursion guard** | `Blocked collision recursion for %s` |

⇒ The whole behaviour is **a grid-aligned cascade with a cap**, not a
constraint solver. A replica that wants the same feel has to copy the grid
alignment and the cap, and can leave the cascade out.

### 17.2 The element action vocabulary

The element context menu is a list of actions, each with an availability
predicate and a locale key:

| Action | Predicate | Locale key |
| --- | --- | --- |
| group into a column | `canGroupIntoColumn` | `element.groupIntoColumn` |
| lock / unlock | `willEnableLock` | `element.lockPosition` |
| bring to front | `canBringToFront` | `element.bringToFront` |
| send to back | `canSendToBack` | `element.sendToBack` |

and the capability set the predicates are drawn from:
`canBringToFront`, `canSendToBack`, `canGroupIntoColumn`, `canConnectWithLines`,
`canConvertTemplate`, `canConvertToBoard`, `canConvertToDocument`,
`canConvertToNote`, `canConvertToSketch`, `isSelectedBoardTemplate`,
`willEnableLock`.

⇒ **Every element action has a predicate**, so the same list is both the
feature set and the availability rule. A replica that copies the list without
the predicates shows actions that cannot work.

### 17.3 `gridSize` is a card unit, not a canvas grid

`gridSize` is the unit an element's own text box snaps to: the auto-grow
bounds are `minHeight: n * gridSize` and `maxHeight: r * gridSize`, and it
also positions the popups. It is **not** a dot grid on the canvas — the
reference has no canvas dot grid at all, unlike Freeform (§4 of the other
teardown).

### 17.4 The feature-flag list

The app-init payload carries the flags the client reads: `betterAuth`,
`notificationsJobApm`, `disableInviteLimit`, `disableAutoShiftLimit`,
`bypassRecaptchaChecks`, `publicTemplateCreation`,
`renderSecureImagesThroughCF`, `customTemplatesGraphMigration`,
`disableGraphDbAppInit`, `graphDbSynced`, `boardSearchIndexComplete`,
`clientPersistence`, `fetchLocalesFromCDN`, and a set of per-locale flags.

⇒ **Some behaviour is switched off by the server, not by the user.** The
auto-shift cap is one of them, so a replica that copies the rule has to
decide whether its cap is a setting or a constant.
