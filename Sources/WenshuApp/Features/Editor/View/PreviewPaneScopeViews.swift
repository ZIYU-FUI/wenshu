//
//  PreviewPaneScopeViews.swift
//
//  3 scope view helpers extracted from PreviewPane.swift
//  (= §6.6 god-class split + discoverability: referenceScopeView +
//  bookScopeView + shelfScopeView moved out of the main file into
//  this dedicated cross-file `extension PreviewPane` module).
//
//  Why extracted (= §6.6 god-class split + discoverability): the main
//  `struct PreviewPane: View` was 1174 LOC = 1.96x the 600-LOC cap
//  when this split was made. = **⇒ It is 302 LOC today** (= the
//  §6.6 split moved the rest out), = so the number above is the
//  split's REASON and not the file's size. = **⇒ A figure quoted in a
//  comment has to say which tree it was measured on**: = 1174 was
//  copied forward for weeks after it stopped being true, = and a
//  later reader used it to decide that a new `PreviewScope` case
//  could not be added (= the file was nowhere near the cap).
//
//  The 3 scope views are a single concern (= "render the 3 main scope
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
        //  — 'search,': apply the search filter (=
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
            // The library's own full-text hits (= the search field's
            // text, but against the DOCUMENTS: their layer and their
            // body, = the two things the grid's card filter cannot
            // reach). The grid below keeps filtering the cards as it
            // did; this adds what the search found in the library's
            // documents.
            LibraryFullTextSearchView(
                query: resolvedSearchQuery,
                onOpen: { reference in
                    onDoubleClick(.reference(reference))
                }
            )
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
    /// folderName nil = union of all standard folders; non-nil = just that
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

    /// The WHOLE 文枢库 scope: every document the library holds.
    ///
    /// The boss's rule (= 2026-11-12): "同时素材栏显示整个文枢库的所有
    /// 文档" (= the assets pane shows all the documents of the whole
    /// 文枢库). = It is the scope the HIDDEN "全部分段" row names, = so
    /// picking the 文枢 chat page lands here.
    ///
    /// ⇒ ⇒ ⇒ SO THE SCOPE HOLDS BOTH KINDS OF DOCUMENT: = the reference
    /// library's documents (= the 资料库's cards) AND every book's
    /// documents (= the 书房's .md cards). = The whole library is both.
    /// The whole 文枢库's scope (= the HIDDEN "全部分段" row's scope).
    ///
    /// ⇒ ⇒ ⇒ THE DOCUMENTS ARRIVE AS A VALUE THE VIEW CANNOT MAKE:
    /// = `AllLibraryDocs`' initializer is `fileprivate`, = so the door
    /// (`PreviewPaneOps.loadAllLibraryDocs`) = is the only thing that
    /// can build one. = ⇒ ⇒ ⇒ So the shape "the view drops the
    /// documents" = does not compile, = and the boss's rule ("素材栏显示
    /// 整个文枢库的所有文档") = cannot be broken here. = ⇒ ⇒ ⇒ MEASURED
    /// (= the review on this diff): = the documents used to be collected
    /// The whole-library scope: the library's documents as ONE list.
    ///
    /// = = The boss's rule (2026-11-17): = = ONE list (= the 资料库's
    /// documents first, = = then 书 1, = = then 书 2), = = not the two
    /// stacked grids this scope used to draw.
    ///
    /// = = The list arrives ALREADY BUILT (= = `LibraryDocumentStore`
    /// walks the library once, = = when the library changes, = = not once
    /// per body pass), = = and already SORTED (= = the pinyin first
    /// letter by default, = = the order the boss named).
    @ViewBuilder
    func allLibraryScopeView(documents: [LibraryDocument], isLoaded: Bool) -> some View {
        if !isLoaded {
            // The list has not landed yet (= = the walk is still running).
            // ⇒ ⇒ ⇒ This is NOT the empty state: = = the library is not
            // empty, = = the list is not here yet. = = Showing the empty
            // state here would tell the user the library holds nothing
            // (= = and it does).
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if documents.isEmpty {
            emptyState(
                icon: "books.vertical",
                titleKey: "preview.empty_state.shelf_empty",
                bodyKey: "preview.empty.shelf_no_books"
            )
        } else {
            libraryDocumentGrid(documents: documents)
        }
    }

    /// The whole library's ONE grid of cards.
    ///
    /// = = ONE `LazyVGrid` in ONE `ScrollView` (= = the two grids this
    /// scope used to draw were two scroll views stacked, = = which is the
    /// "上下结构" the boss's rule removes), = = and the cards flow in the
    /// list's order (= = the 资料库's documents, = = then each book's).
    func libraryDocumentGrid(documents: [LibraryDocument]) -> some View {
        // ONE covers folder for the whole pass (= the ForEach below asks
        // every card's cover); resolving it per card is work the frame
        // must not do.
        let coversRoot = CardCoverService.coversRoot
        return GeometryReader { geometry in
            ScrollView {
                LazyVGrid(
                    columns: adaptiveColumns(width: geometry.size.width),
                    spacing: 16
                ) {
                    ForEach(documents) { document in
                        card(for: document, root: coversRoot)
                            // per-card transition (= see the scope grids'
                            // rationale).
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                }
                // per-card animation trigger (= search filter add/remove
                // within the list).
                .animation(.smooth(duration: 0.18), value: documents.map(\.id))
                .padding(.vertical, DesignTokens.spacingStandard)
                // 2026-10-12 [archived-round] — see the `categoryGridContent` LazyVGrid for the
                // doc on the `.contentMargins(.bottom, 33, for:
                // .scrollContent)` chrome-footer gap-absorber.
                .contentMargins(.bottom, 33, for: .scrollContent)
            }
            .scrollIndicators(.hidden, axes: .vertical)
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
            // a hard-coded padding vs the token-driven vertical
            // padding; = the user's "width is wrong"
            // complaint was the duplicate-render path bypassing the
            // existing chromePaddingVertical / card chrome contract).
            bookDocsGrid(docs: filteredDocs)
        }
    }

    /// The card for one document of the whole library's ONE list.
    ///
    /// = = The card is the SAME card the two scope grids draw (= = the
    /// card knows only `CardSource`), = = so the whole-library list draws
    /// the same cards the 资料库 and the 书房 draw.
    ///
    /// = = The rename and the delete callbacks switch on the source
    /// (= = a reference renames as a reference, = = a book document as a
    /// book document), = = because the two kinds have two different
    /// flows (= = `beginReferenceRename` vs `beginBookDocRename`).
    func card(for document: LibraryDocument, root: URL?) -> Card {
        let source = document.source
        let target: CardCoverTarget
        switch source {
        case let .reference(entity):
            target = coverTarget(forReference: entity.id)
        case let .bookDoc(doc):
            target = coverTarget(forBookDoc: doc.id)
        }
        let cover = coverEntry(for: target, root: root)
        return Card(
            source: source,
            onDoubleClick: { source in
                onDoubleClick(source)
            },
            onRename: {
                switch source {
                case let .reference(entity): beginReferenceRename(entity)
                case let .bookDoc(doc): beginBookDocRename(doc)
                }
            },
            onDelete: {
                switch source {
                case let .reference(entity): beginReferenceDelete(entity)
                case let .bookDoc(doc): beginBookDocDelete(doc)
                }
            },
            coverImageURL: cover.imageURL,
            coverVideoURL: cover.videoURL,
            onGenerateCover: {
                generateCover(
                    for: target,
                    title: document.title,
                    summary: document.summary
                )
            },
            onMakeDynamicCover: {
                makeVideo(for: target)

            },

            onRemoveCover: {
                removeCover(for: target)

            },
            onRemoveDynamicCover: {
                removeDynamicCover(for: target)

            },
            hasCover: cover.hasCover,
            isGeneratingCover: coverGenerationService.isGenerating(target),
            coverErrorMessage: cover.record?.lastError,
            coverClipErrorMessage: cover.record?.clipError,
            isMakingVideo: coverVideoService.isMakingVideo(target)
        )
    }
}
