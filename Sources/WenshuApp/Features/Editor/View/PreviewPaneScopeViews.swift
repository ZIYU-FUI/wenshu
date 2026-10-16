//
//  PreviewPaneScopeViews.swift
//
//  3 scope view helpers extracted from PreviewPane.swift
//  (= §6.6 god-class split + discoverability: referenceScopeView +
//  bookScopeView + shelfScopeView moved out of the main file into
//  this dedicated cross-file `extension PreviewPane` module).
//
//  Why extracted (= §6.6 god-class split + discoverability): the main
//  `struct PreviewPane: View` is 1174 LOC = 1.96x the 600-LOC cap. The
//  3 scope views are a single concern (= "render the 3 main scope
//  cases in the body's switch" — the 4th emptyScopeView was already
//  moved to PreviewPaneGrids.swift in A81). Putting them in a
//  dedicated file named after the concern
//  (= PreviewPaneScopeViews.swift) lets the next reader find the
//  scope logic by name.
//
//  The 3 funcs are view methods on `PreviewPane` (as a cross-file
//  extension). The `private func` was already relaxed to `func`
//  (= internal scope; = required for the cross-file extension access).
//  They access self.activeTag / self.bookStore (= both @Binding /
//  @Environment properties = already internal).
//

import SwiftUI

extension PreviewPane {
    @ViewBuilder

    func referenceScopeView(category: EntityCategory?, tagOverride: String? = nil) -> some View {
        // (see OOB.md #2026-09-07) — 'search,': apply the search filter (=
        // previewSearchQuery) on top of the category filter. Both filters
        // compose (= all entities → search filter → category filter).
        let searched = PreviewPaneOps.searchFilteredEntities(PreviewPaneOps.loadAllEntities(bookStore: bookStore).entities, query: resolvedSearchQuery)
        // SidebarItem.tag preview-pane filter: apply the tag filter (= self.activeTag OR
        // tagOverride from PreviewScope.tagScope) on top of the search +
        // category filter. tag nil = show all (= the user picked the reference
        // library root). tagOverride takes precedence (= the new
        // PreviewScope.tagScope is the canonical route; =
        // workspaceUI.activeTag remains supported for backward compatibility
        // with the prior .referenceScope(nil) routing path that AssetsPane
        // uses to set activeTag in addition).
        let effectiveTag = tagOverride ?? activeTag
        let allEntities: [Reference] = {
            guard let effectiveTag else {
                return searched
            }
            return searched.filter { entity in
                entity.tags.contains(effectiveTag)
            }
        }()
        VStack(spacing: 0) {
            Group {
                if let cat = category {
                    categoryGrid(category: cat, allEntities: allEntities)
                } else {
                    overviewGrid(allEntities: allEntities)
                }
            }
        }
    }


    /// Book scope: scan filesystem for .md files in the book folders.
    /// folderName nil = union of all 8 standard folders; non-nil = just that
    /// folder.
    @ViewBuilder
    func bookScopeView(bookId: UUID, folderName: String?) -> some View {
        // the `libraryChangeTick` `@State` is read in the body's `.onReceive` (= the
        // parent's body re-evaluates when the tick changes; = this view is re-
        // instantiated as part of the body re-render; = the `loadBookDocs`
        // call below re-walks the FS; = the deleted card disappears). No
        // explicit read needed here (= the body's re-evaluation is enough).
        let allDocs = PreviewPaneOps.loadBookDocs(bookStore: bookStore, bookId: bookId, folderName: folderName).docs
        // Search-field padding rationale: actually filter the cards' (= typing in the
        // search field did not filter cards in the book scope). The previous
        // code passed the unfiltered `docs` to `bookDocsGrid(docs:)`; = the
        // search field only filtered reference entities (= in
        // `referenceScopeView`), but book .md cards bypassed the filter
        // entirely. Apply the same shape as `searchFilteredEntities` (= title
        // / summary / pinyin first-letter substring) to book docs.
        let docs = PreviewPaneOps.searchFilteredBookDocs(allDocs, query: resolvedSearchQuery)
        VStack(spacing: 0) {
            if docs.isEmpty {
                emptyState(
                    icon: "book.pages",
                    titleKey: folderName != nil
                        ? "preview.empty_state.book_with_folder"
                        : "preview.empty_state.book_no_folder",
                    bodyKey: "preview.empty.pick_book"
                )
            } else {
                bookDocsGrid(docs: docs)
            }
        }
    }


    /// Shelf scope: union of every book's docs under the shelf. The shelf row
    /// is a scope (= shows every .md card from every book under that shelf; =
    /// union of all `loadBookDocs(bookId:, folderName: nil)` results filtered
    /// to books whose `shelfId == shelfId`).
    @ViewBuilder
    func shelfScopeView(shelfId: UUID) -> some View {
        // see the comment on `bookScopeView` (= the body's `.onReceive` reads the
        // `libraryChangeTick` @State; = no explicit read needed here). Stable-
        // id root-cause fix: the original ran FileManager I/O (= walk shelves
        // tree + read every .md) inside this ViewBuilder body. SwiftUI re-
        // evaluates this body on EVERY Observation tick (= every AppState
        // mutation, every sidebarSelection change, every parent re-render), so
        // the I/O ran hundreds of times per second while the shelf was
        // selected → NSHostingView size constraint invalidation storm → 'more
        // Update Constraints in Window passes than there are views in the
        // window' NSGenericException crash. Fix: read the pre-computed, cached
        // book list from `@State cachedShelfBooks` (= populated exactly once
        // per shelfId via `.task(id: shelfId)` at the call site below = the
        // I/O runs at most once per shelfId change = no storm = no constraint
        // cycle). The `.id(shelfId)` at the call site gives SwiftUI a stable
        // identity for the subtree (= SwiftUI skips body re-evaluation
        // entirely when the shelfId is unchanged = the cached state survives
        // every observation tick).
        let books = cachedShelfBooks[shelfId] ?? []
        let allDocs = books.flatMap { PreviewPaneOps.loadBookDocs(bookStore: bookStore, bookId: $0.id, folderName: nil).docs }
        let filteredDocs = PreviewPaneOps.searchFilteredBookDocs(allDocs, query: resolvedSearchQuery)
        if filteredDocs.isEmpty {
            // Empty shelf branch (= no books under the shelf, or every book has no .md
            // cards, or the search filter excluded everything). Reuse the
            // existing emptyState view (= matches the cross-scope fallback
            // shape that the other scopes fall back to) but with a shelf-
            // specific bodyKey.
            emptyState(
                icon: "books.vertical",
                titleKey: "preview.empty_state.shelf_empty",
                bodyKey: "preview.empty.shelf_no_books"
            )
        } else {
            // Non-empty: reuse the canonical bookDocsGrid (= same LazyVGrid +
            // adaptiveColumns(width:) + sort + Card styling as
            // bookScopeView). Avoids the draft duplicate LazyVGrid (=
            // different .padding(24) vs .padding(.vertical,
            // DesignTokens.spacingStandard); = the user's "width is wrong"
            // complaint was the duplicate-render path bypassing the
            // existing chromePaddingVertical / card chrome contract).
            bookDocsGrid(docs: filteredDocs)
        }
    }


}
