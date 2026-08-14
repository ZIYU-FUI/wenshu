// LibraryStoring.swift · Wenshu (Wenshu) · v0.02.0 (bookshelf module)
//
// Owner 8/15 15:55: '架构需要先定好, 不能没事加个东西, 然后重构一堆东西'.
//
// This file is the architectural root of the wenshu library system.
// LibraryStoring defines the contract that all storage backends must
// satisfy. v0.02.0 ships one implementation (FileSystemLibraryStore);
// future versions can swap it for MetadataQuery / CoreData / CloudKit
// without touching the view layer (= the contract tests in
// Tests/WenshuAppTests/Storage/LibraryStoringContractTests.swift
// guarantee no conformance drift).
//
// Apple HIG document-based-app convention:
//   ~/Documents/wenshu/<shelf-id-uuid>/
//     shelf.json     ← encoded Bookshelf (the metadata)
//     books/         ← v0.02.1: book subdirs land here
//     chapters/      ← v0.02.1: chapter .md files land here
//
// Writes are atomic (= write-to-temp + rename) so a crash mid-write
// leaves the existing file intact. This matches the Apple HIG pattern
// used by NSDocument / FileWrapper.write(to:options:originalContents:).

import Foundation

// MARK: - Errors

struct LibraryStoringError: Error, Sendable {
    enum Kind: Sendable {
        case rootDirectoryUnavailable(URL)
        case shelfAlreadyExists(UUID)
        case shelfNotFound(UUID)
        case invalidShelfData(URL, underlying: String)
        case ioFailed(URL, underlying: String)
    }
    let kind: Kind

    var localizedDescription: String {
        switch kind {
        case .rootDirectoryUnavailable(let url):
            return "wenshu library root directory unavailable at \(url.path)"
        case .shelfAlreadyExists(let id):
            return "a shelf with id \(id) already exists"
        case .shelfNotFound(let id):
            return "no shelf with id \(id)"
        case .invalidShelfData(let url, let err):
            return "shelf.json at \(url.path) is not valid: \(err)"
        case .ioFailed(let url, let err):
            return "I/O failed at \(url.path): \(err)"
        }
    }
}

// MARK: - Search hit (v0.03.0 will populate; v0.02.0 stays empty)

struct SearchHit: Sendable, Hashable {
    /// The shelf that contains the hit. Even when search expands to books
    /// / chapters (= v0.02.1+), the shelf is always part of the result so
    /// the UI can route the user to the right container without an extra
    /// lookup.
    let shelfId: UUID
    let shelfName: String
    /// Free-form context for the hit. v0.02.0 is unused (= the protocol
    /// returns []); v0.02.1+ will populate this with a short snippet
    /// (= NSMetadataQuery result.snippet).
    let matchContext: String
}

// MARK: - Protocol

protocol LibraryStoring: Sendable {
    /// Where shelves are persisted on disk (= the ~/Documents/wenshu/ root
    /// for the FileSystem impl). Exposed so the UI can show 'Library at
    /// ~/Documents/wenshu' (= Apple HIG 'Show in Finder' affordance) and
    /// so tests can inject an isolated /tmp root.
    var rootURL: URL { get }

    /// Returns all shelves sorted by updatedAt descending (= most-recently
    /// edited first, Apple HIG Finder 'Recents' convention).
    func loadShelves() throws -> [Bookshelf]

    /// Persists the shelf (= creates the directory + writes shelf.json).
    /// Atomic write: writes to shelf.json.tmp, renames into place.
    /// Throws .shelfAlreadyExists if a shelf with the same id is already
    /// on disk (= the contract is "first save wins"; renaming is a
    /// separate operation that updates the existing shelf).
    func saveShelf(_ shelf: Bookshelf) throws

    /// Removes the shelf directory and its contents. Idempotent: if the
    /// shelf is already gone (= user deleted it via Finder), this is a
    /// no-op rather than an error. (= Apple HIG document-based apps treat
    /// delete as forgiving — Finder trashed the file from outside the
    /// app and the app should reconcile, not crash.)
    func deleteShelf(id: UUID) throws

    /// Search stub for v0.03.0 (= NSMetadataQuery on ~/Documents/wenshu).
    /// v0.02.0 always returns []. The signature is locked now so the UI
    /// can wire up its search bar without an API change later.
    /// Owner 8/15 15:55: lock the contract now, not when search ships.
    func search(query: String) throws -> [SearchHit]
}