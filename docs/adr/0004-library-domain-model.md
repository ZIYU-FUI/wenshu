# ADR-0004: Bookshelf = WenshuLibrary / Bookshelf / Book three layers

> Status: accepted
> Date: 2026-08-15
> Decision-maker(s): 老板 (8/15 17:05, 8/18 answered Q2)

## Context

老板 8/15 17:05 拍 "structure is wrong, reference fcp. The bookshelf is the parent, it can be clicked to collapse and expand". Pre-v0.07, LibraryScaffold used HStack of BookshelfListView | splitter | BookListView = fixed two-column, wrong. Apple HIG document-based apps (Notes / Pages / Finder) use a single outline + DisclosureGroup (click header to collapse / expand, click row to select).

## Decision

Domain model = `WenshuLibrary: Observable` + `Bookshelf: Identifiable` + `Book: Identifiable` three layers. Bookshelf is the parent; Book hangs under Bookshelf. LibraryScaffold uses `LibraryOutlineView` (single outline + DisclosureGroup), no longer split.

`Book.length` + `Book.idea` fields (8/18 Q2 answer) = New Book Creation Wizard 3 fields (name + length + idea).

Storage uses `LibraryStoring` protocol + `FileSystemLibraryStore` truth source (Apple HIG document-based-app convention = `~/Documents/wenshu/<id>/`). Swapping to CoreData / CloudKit in the future only replaces the store implementation; WenshuLibrary does not change.

## Consequences

- Any "BookshelfListView | splitter | BookListView" pattern = anti-pattern = change back to outline
- Storage choice is swappable, protocol contract stays constant

## Alternatives considered

- Old HStack two-column (BookshelfListView + BookListView) — rejected, not Apple HIG
- CoreData bound directly to UI — rejected, 老板 8/15 15:55 "architecture must be locked in first, can't keep adding things"
- iCloud / CloudKit — deferred until v0.10+