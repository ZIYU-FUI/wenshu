//
//  PreviewPaneDataAccess.swift
//
//  3 data accessor helpers extracted from PreviewPane.swift
//  (= §6.6 god-class split + discoverability: ensureCardService +
//  loadBooksInShelf + loadShelfBooksAsync moved out of the main
//  file into this dedicated cross-file `extension PreviewPane`
//  module).
//
//  Why extracted (= §6.6 god-class split + discoverability): the main
//  `struct PreviewPane: View` is 1063 LOC = 1.77x the 600-LOC cap. The
//  3 data accessors are a single concern (= "load books + the
//  SidebarService that manages them"). Putting them in a dedicated
//  file named after the concern (= PreviewPaneDataAccess.swift) lets
//  the next reader find the data-access logic by name.
//
//  The 3 funcs are instance methods on `PreviewPane` (as a cross-file
//  extension). The `private func` was relaxed to `func` (= internal
//  scope; = required for the cross-file extension access).
//

import Foundation

extension PreviewPane {
    // (emptyState extracted to PreviewPaneGrids.swift in A79; = see that file)


    /// the 3 helpers that the right-click `Card` callbacks call into. They
    /// mirror the `AppleSidebarView` `renaming` / `pendingDelete` state pattern
    /// (= the rename sheet + delete alert pick up the local @State and show the
    /// corresponding UI). The service is built lazily from the same closures
    /// the sidebar uses (= the same source of truth for the business methods
    /// `renameReference` / `deleteReference`). Lazy service init (= the service
    /// is an actor; = we build it on first access and cache it in
    /// `cardService`). Returns the service (= creates a new one if the cache is
    /// empty).
    func ensureCardService() -> SidebarService {
        if let cached = cardService {
            return cached
        }
        let service = SidebarService(
            loadShelves: { try self.bookStore.sidebarLoadShelves() },
            loadAllBooks: { try self.bookStore.sidebarLoadAllBooks() },
            loadReferences: { try self.bookStore.loadAllReferences() },
            bookStore: self.bookStore
        )
        cardService = service
        return service
    }

    // (beginReferenceRename extracted to PreviewPaneCardActions.swift in A80; = see that file)

    // (beginReferenceDelete extracted to PreviewPaneCardActions.swift in A80; = see that file)

    // (beginBookDocRename extracted to PreviewPaneCardActions.swift in A80; = see that file)

    // (beginBookDocDelete extracted to PreviewPaneCardActions.swift in A80; = see that file)


    /// helper for shelfScopeView. Returns the books that live under the given
    /// shelf (= the books whose `.shelfId` matches). Reads from the same
    /// BookStore.sidebarLoadAllBooks source the sidebar already uses (= single
    /// source of truth; = no parallel book list). Returns [] (= empty shelf =
    /// empty-state card grid) when the lookup fails (= disk error) so the
    /// caller doesn't have to do its own error-handling.
    func loadBooksInShelf(shelfId: UUID) -> [Book] {
        return PreviewPaneOps.loadBooksInShelf(bookStore: bookStore, shelfId: shelfId).books
    }

    func loadShelfBooksAsync(shelfId: UUID) async {
        let result = await PreviewPaneOps.loadShelfBooksAsync(bookStore: bookStore, shelfId: shelfId)
        cachedShelfBooks[shelfId] = result.books
    }


}
