# 01 — sidebar migrated to Apple HIG standard List

**What to build:**

Boss 2026-08-30 OOB '如果你要 100% Apple native, 我想选这个' (= chose
option A2 = full Apple HIG migration). Pre-v0.30 sidebar used hand-rolled
recursive `VStack { FCPRowView }` (= 700 LOC, manual indentation,
manual selection highlight, custom chevron Lucide icon).

Fix: rewrite sidebar to use Apple's standard `List(selection:) +
.listStyle(.sidebar)`. Per Apple HIG Sidebars:

1. "A sidebar's row height, text, and glyph size depend on its overall
   size, which can be small, medium, or large." (= follow system
   preference, NO hardcoded sizes)
2. "In general, show no more than two levels of hierarchy in a sidebar."
   (= DisclosureGroup nesting, max 2 levels)
3. "By default, sidebar icons use your app's accent color. On macOS
   Tahoe, sidebar icon tint = black in light mode / white in dark mode."
   (= `.foregroundStyle(.primary)`)
4. Apple std APIs: `Label { Text } icon: { View }`, `.badge(count)`,
   `.listStyle(.sidebar)`.

**Blocked by:** None (= can start immediately).

**Status:** ready-for-agent (= already committed as `c5ed76169`,
this ticket documents the commit after-the-fact per Q5.6 partial
commit 接管规范).

## Fix specification

### File: `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift`

Full rewrite. Key elements:

1. **New enum `SidebarItem: Hashable`** for List(selection:) composite:
   - `.book(UUID)`
   - `.referenceCategory(String)` (= EntityCategory.directoryName)
   - `.referenceLibraryRoot` (static)

2. **body uses `List(selection: $sidebarSelection)`** with:
   - `ForEach(shelves)` → `Section { ForEach(booksInShelf(shelf))
     { bookRowWithFolders(book) } }`
   - One Section for reference library (with DisclosureGroup of
     categories)

3. **`@State sidebarSelection: SidebarItem?`** mirrors both book
   and category selection. Single onChange handler routes to
   `bookStore.selectedBookId` + `selectedEntityCategory`.

4. **`bookRowWithFolders(_ book:)`** uses `DisclosureGroup` for
   book → folder nesting (2 levels).

5. **Icons: `.foregroundStyle(.primary)`** (= macOS Tahoe HIG:
   black/white).

6. **Count badges: `.badge(count)`** (= Apple std).

7. **Row contents: `Label { Text } icon: { LucideIcon }`** (= Apple
   std row composition).

### Removed (= what was deleted in the rewrite)

- FCPRowView (= replaced by List rows)
- FCPTreeNode (= no longer needed)
- buildTreeNodes, standardFolderNodes (= List handles structure)
- categoryRow, bookRow, shelfHeader, entityLayerWithCategories (= replaced
  by Label + DisclosureGroup)
- readShelves, readBooks, saveBook, saveShelf (= KEPT, same filesystem
  logic)

## Acceptance

- [x] Uses List(selection:) + .listStyle(.sidebar)
- [x] All rows use Label + .badge (= Apple std)
- [x] Icons use .foregroundStyle(.primary) (= black/white)
- [x] No hardcoded 18 PT icon / 28 PT row (= Apple std)
- [x] No manual selection highlight (= Apple std automatic)
- [x] 2-level hierarchy via DisclosureGroup (= Apple HIG compliant)
- [x] Build exit 0
- [x] Screenshot verified (= looks like Apple Mail/Notes sidebar)

## Trade-offs (= what wenshu boss taste was removed)

Per boss OOB "100% Apple native": wenshu lost custom 18 PT icon size +
28 PT row height + 18 PT trailing padding + category-color icons + manual
selection highlight. These were wenshu-boss-taste that deviated from
Apple HIG. Boss chose Apple HIG explicitly.
