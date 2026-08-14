// WenshuLibrary.swift · Wenshu (Wenshu) · v0.02.0 (bookshelf module)
//
// @Observable state layer between the view (= SwiftUI BookshelfListView,
// v40+) and the storage backend (= LibraryStoring). Owns:
//
//   - the in-memory list of Bookshelf (= sorted by updatedAt desc on load)
//   - the user's current selection (= selectedShelfId; nil = no selection)
//   - the operations the view calls: add, rename, delete
//
// Architectural rules (= Owner 8/15 15:55, "lock the architecture first"):
//   - WenshuLibrary depends ONLY on the LibraryStoring protocol, never on
//     a concrete impl (= FileSystem / MetadataQuery / CoreData can all be
//     injected).
//   - All mutations go through the protocol (= no direct FileManager calls
//     in the state layer). If the UI needs new operations, they extend
//     LibraryStoring first, not WenshuLibrary.
//   - The state layer is the single source of truth for the view; the
//     view never reads the store directly.
//
// Concurrency: marked `@MainActor` so SwiftUI can read every property
// without `await`. The store calls (= async on FileManager etc.) are
// dispatched off-main by the store itself (= Future impl wraps each call
// in a Task). v0.02.0 keeps it MainActor-isolated for simplicity; the
// protocol can grow an async overload later if a remote store needs it.

import SwiftUI

@MainActor
@Observable
final class WenshuLibrary {
    /// All bookshelves, sorted by updatedAt descending (= Apple HIG Finder
    /// 'Recents' convention).
    private(set) var shelves: [Bookshelf] = []

    /// The user's current selection (= Apple HIG document-based apps
    /// default to a single selection; v0.02.0 is single-selection only).
    /// Nil means "no selection" (= fresh install, or user cleared).
    private(set) var selectedShelfId: UUID?

    /// Storage backend. Protocol-typed so a future swap to MetadataQuery /
    /// CoreData / CloudKit requires no UI changes. The store is held as a
    /// let (= not @Observable) because its state lives on disk; only the
    /// view-facing mirror (= shelves) is observable.
    private let store: any LibraryStoring

    init(store: any LibraryStoring) {
        self.store = store
        // Load on init so the view sees the existing library the moment
        // it renders. Failures (= missing root on a fresh install) are
        // handled by the loadShelves impl (= empty list, not a thrown
        // error).
        do {
            self.shelves = try store.loadShelves()
        } catch {
            self.shelves = []
        }
    }

    /// URL to display in the UI (= 'Library at <rootURL>'). The view
    /// uses this for the Apple HIG 'Show in Finder' affordance.
    var libraryRootURL: URL { store.rootURL }

    // MARK: - Mutations (= all delegate to the storage layer; mirror the
    // result back into `shelves` so the view sees the change.)

    /// Creates a new shelf. The shelf must have a unique id (one will be
    /// assigned by Bookshelf's default init if you don't pass one). The
    /// view is responsible for prompting the user for a name; this method
    /// just persists.
    func addShelf(_ shelf: Bookshelf) throws {
        try store.saveShelf(shelf)
        // Insert in sorted position. LibraryStoring guarantees the new
        // shelf has the latest updatedAt (= .now from the init), so it
        // goes to the front.
        shelves.insert(shelf, at: 0)
        // Auto-select the newly added shelf (= Apple HIG Finder behavior:
        // creating a folder also selects it).
        selectedShelfId = shelf.id
    }

    /// Renames an existing shelf. id stays the same (= Apple HIG
    /// document-based: URL = identity, name = display label only).
    /// Throws .shelfNotFound if no shelf with that id exists.
    func renameShelf(id: UUID, to newName: String) throws {
        guard let index = shelves.firstIndex(where: { $0.id == id }) else {
            throw LibraryStoringError(kind: .shelfNotFound(id))
        }
        var updated = shelves[index]
        updated.name = newName
        updated.updatedAt = .now
        // The contract is "first save wins on id", so a rename goes
        // through delete + save (= the directory already exists at the
        // id, and FileSystemLibraryStore refuses to re-save the same id).
        try store.deleteShelf(id: id)
        try store.saveShelf(updated)
        shelves[index] = updated
        // Re-sort to keep updatedAt-descending invariant.
        shelves.sort { $0.updatedAt > $1.updatedAt }
    }

    /// Removes a shelf. Idempotent: deleting an unknown id is a no-op.
    func deleteShelf(id: UUID) throws {
        try store.deleteShelf(id: id)
        shelves.removeAll { $0.id == id }
        if selectedShelfId == id {
            selectedShelfId = nil
        }
    }

    // MARK: - Selection (= driven by the view; not stored on disk)

    func setSelectedShelf(id: UUID) {
        selectedShelfId = id
    }

    func clearSelection() {
        selectedShelfId = nil
    }

    /// Returns the currently-selected Bookshelf, if any. Convenience for
    /// views that bind selection to content (= v0.02.0 only shows the
    /// name; v0.02.1+ shows the books inside).
    var selectedShelf: Bookshelf? {
        guard let id = selectedShelfId else { return nil }
        return shelves.first(where: { $0.id == id })
    }
}