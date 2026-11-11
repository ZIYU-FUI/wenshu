//
//  BookSessionLifecycle.swift
//
//  The book ⇄ session relationship, in ONE place.
//
//  Why this file exists: a book has a conversation, and the two must move
//  together. Renaming a book renames its conversation (= the same session,
//  the new title); deleting a book deletes its conversation and the
//  messages in it. The same rule also decides which books may be renamed
//  at all: the help book is the app's own document (= read-only), and the
//  default shelf is the library's own shelf (= its name is the app's, not
//  the user's).
//
//  Why ONE place: the rules are reached from two doors (= the sidebar's
//  menus and the agent's book tools), and the two doors are in different
//  files. When the rules lived in each door separately, they drifted:
//  the sidebar could rename the help book while the agent could not.
//
//  The coordinator holds the RULES. The doors call it. That way a rule
//  added here reaches every door at once.
//

import Foundation
import WenshuData

/// The rules that bind a book to its conversation, and the guards that
/// decide which books the user may change.
///
/// It is a namespace of pure functions over ids and titles: it holds no
/// state, so both doors (= the sidebar's menus and the agent's tools)
/// can call it without owning it.
enum BookSessionLifecycle {
    // MARK: - The protected ids

    /// The identity of the book that holds the app's own help document.
    ///
    /// It is a FIXED id (= the migrator seeds this book under this id on
    /// every launch), so it is compared as an id and never by its display
    /// title (= the title is a localized string; = the id is the
    /// identity).
    static let helpBookID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

    /// The identity of the library's default shelf (= the shelf the
    /// app's own documents live in).
    static let defaultShelfID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    // MARK: - The guards

    /// Whether this book is the app's own help document.
    ///
    /// The help book is read-only for the user: it cannot be renamed, and
    /// its content cannot be edited. It CAN be deleted (= the user may
    /// clear the app's own document out of the way).
    static func isHelpBook(_ bookID: UUID) -> Bool {
        bookID == helpBookID
    }

    /// Whether this shelf is the library's default shelf.
    ///
    /// The default shelf's NAME is the app's (= the localized
    /// default-shelf title), so the user may not rename it. It CAN be
    /// deleted (= the boss ruled that the shelf is not a protected row,
    /// = only its name is).
    static func isDefaultShelf(_ shelfID: UUID) -> Bool {
        shelfID == defaultShelfID
    }

    /// The book id a book directory names.
    ///
    /// The library's layout puts the book id in the directory's own
    /// name (= `<shelves>/<shelf>/books/<book-id>/`), so the directory
    /// names its book. Nil when the name is not a UUID (= the caller
    /// handed over something that is not a book directory).
    static func bookID(inBookDirectory directory: URL) -> UUID? {
        UUID(uuidString: directory.lastPathComponent)
    }

    /// Whether a book directory belongs to a read-only book.
    ///
    /// The filesystem layer needs this (= the layer that writes the
    /// bytes), and it gets there by the path, = not by an id the caller
    /// passed in (= a caller that passes the wrong id is exactly the
    /// case the filesystem layer exists to catch).
    static func isReadOnlyBookDirectory(_ directory: URL) -> Bool {
        guard let bookID = bookID(inBookDirectory: directory) else { return false }
        return isHelpBook(bookID)
    }

    /// The book a DOCUMENT path belongs to.
    ///
    /// The library's layout puts every book under a `books` directory
    /// (= `shelves/<shelf>/books/<book-id>/`), = so the book id is the
    /// component right after that marker (= the book directory's own
    /// name). = ⇒ THE DERIVATION IS BY LAYOUT, = NOT BY DEPTH: = a
    /// document may sit at any depth under its book (= `world/`, =
    /// `chapters/`, = or the book directory itself), = and a depth-based
    /// rule would name the wrong book for one of them.
    ///
    /// Nil when the path names no book (= a reference-library document,
    /// = or a path that is not a library path at all).
    static func bookID(ofDocumentPath path: String) -> UUID? {
        let components = URL(fileURLWithPath: path).pathComponents
        // ⇒ FROM THE DEEPEST MARKER BACKWARDS, = and the first one whose
        // successor is a UUID wins: = a FILE may itself be named
        // `books` (= it has no successor), = and the deepest such
        // component must not hide the real book directory above it.
        for marker in components.indices.reversed() where components[marker] == "books" {
            guard marker + 1 < components.count else { continue }
            if let bookID = UUID(uuidString: components[marker + 1]) {
                return bookID
            }
        }
        return nil
    }

    /// Whether this document path belongs to the read-only book.
    ///
    /// This is the key that SURVIVES A RELAUNCH: = the editor's tab
    /// keeps its document path across launches, = and it does NOT keep
    /// the tab's scope (= `PersistedEditorTab` carries no scope field),
    /// = so a guard that reads only the scope fails OPEN on every
    /// restored tab.
    static func isReadOnlyDocumentPath(_ path: String?) -> Bool {
        guard let path, let bookID = bookID(ofDocumentPath: path) else { return false }
        return isHelpBook(bookID)
    }

    // MARK: - The book ⇄ session movement

    /// Rename a book's conversation.
    ///
    /// The session keeps its identity (= its id, = its rows, = its
    /// history): only its title changes. The identity is what the
    /// messages point at, so replacing the session would throw the
    /// conversation away.
    ///
    /// The repository is MainActor-isolated (= SwiftData's contexts are),
    /// so this call hops to the main actor.
    ///
    /// - Parameters:
    ///   - bookID: the book's id.
    ///   - newTitle: the book's new name (= the session's new title).
    ///   - repository: the store to write to. It defaults to the app's
    ///     own store (= the production path), and a test passes its own
    ///     (= so a test never writes into the user's library).
    @MainActor
    static func renameSession(
        bookID: UUID,
        newTitle: String,
        repository: WSChatRepository = .shared
    ) {
        _ = try? repository.renameSessions(bookID: bookID.uuidString, title: newTitle)
    }

    /// Delete a book's conversation, and everything in it.
    ///
    /// The session's messages, summary and sub-agent runs carry a
    /// relationship to the session, so deleting the session row takes
    /// them with it.
    ///
    /// The repository is MainActor-isolated (= SwiftData's contexts are),
    /// so this call hops to the main actor.
    ///
    /// - Parameters:
    ///   - bookID: the book's id.
    ///   - repository: the store to write to. It defaults to the app's
    ///     own store (= the production path), and a test passes its own.
    @MainActor
    static func deleteSession(
        bookID: UUID,
        repository: WSChatRepository = .shared
    ) {
        _ = try? repository.deleteSessions(bookID: bookID.uuidString)
    }
}
