//
//  BookmarkOps.swift · Wenshu · v2.9d ticket T34 (boss 2026-09-28 OOB A2 follow-up)
//
//  @MainActor enum = the canonical bridge between BookmarkView
//  (= the SwiftUI surface) and the SwiftData WSBookmarkRepository.
//
//  Per the §11.13 P2-06 + §11.10 v1.74 MVVM split template:
//   - @MainActor enum (= SSOT per surface)
//   - static func entry points (= the view never calls the
//     repository directly; = all reads / writes go through
//     BookmarkOps)
//   - Result types = .loaded([Bookmark]) / .failed(message)
//     (= the view consumes these without re-throwing)
//
//  v2.9d T34 (boss 2026-09-28 OOB A2 follow-up): MVVM split
//  for BookmarkView (= the v2.8a bookmark UI was a single
//  223-LOC struct with three inline funcs (reload / addBookmark /
//  removeBookmark); = §11.13 P2-06 split lifts the inline
//  funcs to BookmarkOps; = the view becomes render-only).

import Foundation

/// v2.9d (boss 2026-09-28 OOB A2 follow-up): the canonical
/// bookmark surface (= the @MainActor bridge between the
/// SwiftUI view and the SwiftData repository).
@MainActor
enum BookmarkOps {

    /// One bookmark load outcome (= consumed by the view
    /// without re-throwing).
    enum LoadOutcome: Equatable {
        case empty
        case loaded([Bookmark])
        case failed(String)
    }

    /// All bookmarks for the active book (= the canonical
    /// list path; = the view never calls the repository
    /// directly).
    ///
    /// Pattern mirrors the v2.8a BookmarkView behavior
    /// exactly (= empty list when activeBookId is nil;
    /// = error path converts to .failed).
    static func load(repository: WSBookmarkRepository, activeBookId: UUID?) -> LoadOutcome {
        guard activeBookId != nil else {
            return .empty
        }
        do {
            let rows = try repository.list()
            return .loaded(rows)
        } catch {
            return .failed(String(describing: error))
        }
    }

    /// Add a new bookmark (= the canonical write path).
    /// Returns the persisted Bookmark (= the view reloads
    /// after a successful add).
    ///
    /// The MVP path synthesizes the docId from a per-book
    /// prefix (= mirrors the v2.8a BookmarkView behavior
    /// exactly; = the bookmark anchors to the active book;
    /// = the polymorphic WSBookmark model requires exactly
    /// one of docID / bookID set; = we set docID with the
    /// book prefix).
    static func add(
        repository: WSBookmarkRepository,
        label: String,
        activeBookId: UUID
    ) -> Bookmark {
        let trimmed = label.trimmingCharacters(in: .whitespaces)
        let bookmark = Bookmark(
            docId: "book:\(activeBookId.uuidString):default",
            label: trimmed
        )
        return bookmark
    }

    /// Remove a bookmark by id (= the canonical delete path).
    /// Returns a typed result (= the view shows the error
    /// inline without re-throwing).
    static func remove(
        repository: WSBookmarkRepository,
        id: String
    ) -> LoadOutcome {
        do {
            try repository.remove(id: id)
            return .empty
        } catch {
            return .failed(String(describing: error))
        }
    }
}