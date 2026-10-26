# Session close — 2026-10-26 (second half) — the index opens in the app, and the library's tag rule holds everywhere

> Boss directives 2026-10-26 (rendered in English per rule 1.1):
> "the click on this index leaves the app and opens a browser, = that is a
> BUG; = if you want it to open directly, = open it with the wenshu editor";
> "that link's rendering is not good looking, = it is too conventional, = we
> already have the document cards, = can you show the card right in the file?";
> "if the cards can be shown, = they need to be smaller, = the picture only
> (= no video card), = not one card per row, = several in a row, = the size is
> yours to decide"; "the imported rewritten files carry the same name as their
> tags, = the library has had the rule since before (= the title is not a tag,
> = at most three, = at least one)"; "the thinking output holds a few
> characters per line".
>
> Session: this session's own arc (no board cards; = the work came from the
> boss's reports). Closure type: production source changed, = tests added, =
> this closure doc, = the live harness proven on both import paths.

## 1. What landed

| # | Deliverable | Where | Commit |
|---|-------------|-------|--------|
| 1 | An index entry opens in the app, = not in a browser | `BookDocumentIndex`, `BookAwareWikiLinkResolver`, `EditorActions`, `EditorView`, `EditorViewEditHelpers` | `4452fb54d2` |
| 2 | The world's index writes its links in the form the app opens | `ImportWorldPrompt.md`, `ImportDocumentTemplateSkeletons.swift`, `WCIRPromptHelpers.swift`, `ImportSOPLoader` | `4452fb54d2` |
| 3 | An index shows its documents as cards (= the picture is the card) | `LinkedDocumentCardBoard`, `LinkedDocumentBoardSection`, `DocumentLinkIndex`, `EditorView` | `a620098f44`, `21500d453b` |
| 4 | One streaming cursor per reply | `ChatMessage.trailingTextPartID`, `ChatPartView`, `ChatTextPartView` | `b10ce7680b` |
| 5 | The reply renders as markdown blocks, = the hermes way | `MarkdownBlocks`, `MarkdownBlocksView` | `c069a22ee1` |
| 6 | The library's tag rule holds on every import path | `ImportTagPolicy`, `ImportReferenceLibraryRouter`, `WenshuConductorImportRouterHelpers` | `50da2f5a6a` |
| 7 | The rule holds where the file lands (= and the title is the file's name) | `BookDocumentTagLine`, `WriteBookDocTool` | `d4cd276834` |
| 8 | The rule runs again once the folder is whole | `ImportAgentDriver` (= the post-pass) | `b0a39f94d5` |
| 9 | The sheet reads the reply as blocks, = not one line per chunk | `ImportReplyParts`, `ImportServiceRetryEntry` | `3263aabeb2` |

## 2. The root causes behind this session's reports

### 2.1 The click that left the app

The engine (`swift-markdown-engine` 0.13) rewrites a markdown link's target
to `https://<target>` and hands it to the OS, = so a markdown link in a
document always opens a browser. Only the app's own wiki link (`[[name]]`)
reaches the app, = and only when the resolver says the target exists. Two
gaps stood between that and a working click:

1. the resolver knew the reference library only, = so a link into the book had
   no answer, = the engine left it grey, = and the click never arrived;
2. the navigation's book lookup was a stub (`return nil`), = so even a
   resolved link had nowhere to land.

Both are closed: `BookDocumentIndex` = the one reader of a book's documents,
the resolver answers for the book, = and the navigation opens the real file
(= the editor edits it in place). The world's index writes `[[name.md]]`
(= the markdown spelling stays legal; = the reader accepts both).

### 2.2 The cards in the file

The engine renders text, images and links, = and it cannot host a SwiftUI
card. So the cards are the app's own: the reading view renders the body
without the link lines and lays the documents out as the app's card (= the
picture is the card), = 132 PT wide, = several on a row, = the picture only.
The edit view still shows the text (= the engine owns that surface).

### 2.3 The tag rule

The library's rule (the boss, 2026-10-09) lived in the old import path only:
the paths that came after it wrote the tags as the model gave them (= four
tags, = a tag that repeated the title, = or none at all). The rule is one
type now (`ImportTagPolicy`), = and every import path asks it. Two halves:

1. the title is not a tag, = a tag repeats no other tag, = a tag carries no
   punctuation, = at most three, = at least one (= the app's own vocabulary
   fills the gap);
2. a tag names no sibling document (= the children have their own place:
   the index's links and the card board), = so the index no longer tags
   itself with its own children.

The rule needed two passes: = at write time the index's siblings do not exist
yet (the index is written first), = so the rule runs again after the turn.

### 2.4 The few characters per line

The provider cuts its reasoning into small chunks (= "Let", " me look",
" at the task"), = and the sheet appended every chunk as its own part, = so
each chunk became its own row. The chat zone never had this problem: its
accumulator merges the chunks of the same kind into the trailing part. The
sheet does the same now.

## 3. How it was verified

| Check | Result |
|---|---|
| The book import on the real provider | 9 writes, 0 failures, 61.9 s |
| The library import on the real provider | 0 failures, 89.4 s, 8 searches |
| The tag rule on the real answer | 2 tags, = the title ∉ the tags, = 1..3 |
| The sibling rule on the real answer | the index's tag naming a child was dropped |
| The new tests | 39 (the index, the resolver, the navigation, the tag policy, the tag line, the merge) |
| The import + editor suite vs. the untouched baseline | 7 failures on both, = the same names, = 0 new |
| The build | `Scripts/build-app.sh` exit 0, = ad-hoc signed |

The library's live run first failed with the provider's refusal
(`input new_sensitive (1026)`), = which says nothing about the import: = the
harness read the world's material. = The harness now reads a neutral source
and asserts the rule on the real answer.

## 4. The decisions the boss made mid-session

1. **The index's link form changed** (= the 2026-10-10 pinned format was
   `[`name.md`](name.md)`). = That spelling always leaves the app (= the
   engine rewrites it to `https://name.md`). = The wiki spelling renders the
   same (= the engine hides the brackets) and opens in the app. = The SOP
   says why.
2. **The cards live in the reading view** (= the edit view keeps the text).
3. **The tag rule gained its second half** (= a tag names no sibling
   document), = and the index's own files were migrated in place
   (`故事宪法.md`, = 9 links).

## 5. What is still open

1. **The six existing library entities carry no tags** (= the old rule
   allowed it). = New imports fill the gap; = the old ones need a
   migration, = and the boss has not asked for one yet.
2. **The import preview column takes a third of the window** (= the rest
   is empty). = Not reported as a bug; = offered, = not done.
3. **The content quality is the boss's call** (= whether a generated
   worldview is any good, = whether 杜甫 belongs to category `I`).

## 6. The traps a new session must know

- **The engine's link rule**: = a markdown link becomes a web link, = and
  only a wiki link the app's resolver vouches for opens in the app. = The
  resolver must answer "exists" for the book, = or the link stays grey.
- **The index is written first**, = so a rule about siblings cannot run at
  write time; = it runs after the turn.
- **The provider's content filter** refuses some material
  (`input new_sensitive (1026)`), = and the live harness must read a
  neutral source, = or it measures the filter instead of the import.
- **A chunk is not a write**: = the driver's tally reads the tool's own
  answer, = and the sheet merges the stream's chunks (= the chat zone's
  accumulator is the reference).
- **The regression baseline** lives in
  `/Users/anbaiqiang/.hermes/profiles/wenshu-dev/cache/scratch/wt-baseline-main`
  (= HEAD `15901058d5`), = and the comparison is by failure name, = not by
  count alone.
