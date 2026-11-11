// ChatScope.swift
//
// The ONE scope concept for the chat zone.
//
// Why this file exists: the chat zone's top bar, the directory tree and the
// asset pane all have to agree on "what is the chat talking about". Before
// this, the answer was a bare `BookID?` on the view model, which cannot
// name the two fixed scopes (the repository conversation and the reference
// library conversation) and which the tree could not map onto. This file
// holds the three scopes, the page list they produce, and the mapping in
// both directions.
//
// It lives in Features/Chat/Model/ (= the chat feature owns the concept;
// = no SwiftUI import; = the view layer and the tests can both read it).

import Foundation
import WenshuData

/// The scope a chat conversation belongs to.
///
/// Three cases, and the order the top bar shows them in:
///
/// - `.repository` — the Wenshu-level conversation (= the chat that is not
///   about any book). It is the FIRST page.
/// - `.book(BookID)` — one ordinary book. There is exactly one page per
///   ordinary book.
/// - `.library` — the reference-library conversation. It is the LAST page.
///
/// The help book is deliberately NOT a scope of its own: it is the app's own
/// document, it is read-only, and it gets no page. A book that is not
/// ordinary (the help book) simply does not appear in the page list.
enum ChatScope: Hashable, Sendable {
    /// The Wenshu-level conversation (= the global un-attached bucket).
    case repository
    /// The reference-library conversation.
    case library
    /// One ordinary book's conversation.
    case book(BookID)

    /// The identity of the book that holds the app's own help document.
    ///
    /// It is a FIXED id (= the migrator seeds this book under this id on
    /// every launch), so it is compared as an id and never by its display
    /// title (= the title is a localized string; = the id is the
    /// identity).
    ///
    /// The id itself is written down ONCE (= in `BookSessionLifecycle`,
    /// = the file that holds the book's protection rules), so the seed
    /// and the protection cannot drift apart.
    static let helpBookID = BookSessionLifecycle.helpBookID

    /// The book scope's id, or nil for the two fixed scopes.
    ///
    /// Nil = "not about a book" (= the repository conversation, = the
    /// reference-library conversation). The chat's persistence layer keys
    /// its rows by (sessionID, bookID), so both fixed scopes share a nil
    /// book id and are told apart by their session id (= see `sessionID`).
    var bookID: BookID? {
        switch self {
        case .repository, .library:
            return nil
        case let .book(bookID):
            return bookID
        }
    }

    /// The session key this scope's conversation lives under.
    ///
    /// The two fixed scopes share a nil book id (= the global un-attached
    /// bucket), so the session id is what tells them apart: the repository
    /// conversation keeps the historical `default` key (= the rows written
    /// before this feature existed stay reachable), and the library
    /// conversation takes its own key.
    var sessionID: SessionID {
        switch self {
        case .repository:
            return SessionID(rawValue: "default")
        case .library:
            return SessionID(rawValue: "library:default")
        case let .book(bookID):
            return SessionID(rawValue: "book:\(bookID.rawValue):default")
        }
    }

    /// Whether this scope names the app's own help document.
    ///
    /// The help book is read-only and has no page, so the page list skips
    /// it (= `pageList`) and the protection guards recognise it (= they
    /// compare this id, = never the title).
    var isHelpBook: Bool {
        switch self {
        case let .book(bookID):
            return bookID.rawValue == Self.helpBookID.uuidString
        case .repository, .library:
            return false
        }
    }
}

// MARK: - The tree ↔ scope mapping

extension ChatScope {
    /// The scope a directory-tree row names.
    ///
    /// The tree is the app's source of truth for "what is selected" (= the
    /// asset pane reads the same field), so the tree's rows map ONTO scopes
    /// and the bar's pages map back:
    ///
    /// - a book row (and a folder row, which belongs to a book) → that
    ///   book's scope;
    /// - the reference-library root → the library scope;
    /// - every other row (a shelf, a reference category, a tag, no row) →
    ///   the repository scope (= the conversation that is not about a book).
    ///
    /// The help book has no page, so its row maps to the repository scope
    /// (= the row is still selectable, = it just has no page of its own).
    static func scope(for selection: SidebarItem?) -> ChatScope {
        switch selection {
        case let .book(bookID):
            return scope(forBookID: bookID)
        case let .folder(bookID, _):
            return scope(forBookID: bookID)
        case .referenceLibraryRoot:
            return .library
        case .shelf, .referenceCategory, .referenceUnclassified, .tag, nil:
            return .repository
        }
    }

    /// The scope for one book id (= the book scope, = or the repository
    /// scope for the help book, which has no page).
    private static func scope(forBookID bookID: UUID) -> ChatScope {
        let scope = ChatScope.book(BookID(rawValue: bookID.uuidString))
        return scope.isHelpBook ? .repository : scope
    }

    /// The directory-tree row this scope selects.
    ///
    /// The inverse of `scope(for:)`: the bar's page names the row the tree
    /// highlights. The two fixed scopes name their fixed rows (= the
    /// reference-library root for the library, = no row for the repository
    /// conversation), and a book scope names its book row.
    ///
    /// The repository scope names NO row: it is the conversation that is not
    /// about any one row, so selecting it clears the tree selection (= the
    /// tree returns to "nothing selected"). That is the same state the tree
    /// was in before the user picked anything, so the write-back is a no-op
    /// in the common case.
    var treeSelection: SidebarItem? {
        switch self {
        case .repository:
            return nil
        case .library:
            return .referenceLibraryRoot
        case let .book(bookID):
            return .book(UUID(uuidString: bookID.rawValue) ?? ChatScope.helpBookID)
        }
    }
}

// MARK: - The page list

/// One page in the chat zone's top bar.
struct ChatScopePage: Identifiable, Hashable, Sendable {
    /// The scope this page switches the chat to.
    let scope: ChatScope
    /// The page's display name (= the book title, = or the fixed scope's
    /// localized name).
    let title: String

    var id: ChatScope {
        scope
    }
}

extension ChatScope {
    /// The pages the top bar shows, in display order.
    ///
    /// The order is fixed by the product: the repository page first, then one
    /// page per ordinary book, then the library page last.
    ///
    /// The pages come from the CURRENT BOOK COLLECTION and not from the
    /// session history: a book that was just created has no session rows
    /// yet, and it still gets its page (= the page list follows the
    /// collection); and a book that was just deleted leaves no page
    /// behind (= its pages came from the collection, = not from the rows
    /// it left behind).
    ///
    /// The help book contributes no page: it is read-only (= the app's own
    /// document), so it is not a conversation the user drives.
    ///
    /// - Parameters:
    ///   - books: the library's current books, in the order they should
    ///     appear (= the store's own order).
    ///   - repositoryTitle: the repository page's display name.
    ///   - libraryTitle: the library page's display name.
    static func pageList(
        books: [Book],
        repositoryTitle: String,
        libraryTitle: String
    ) -> [ChatScopePage] {
        var pages: [ChatScopePage] = [
            ChatScopePage(scope: .repository, title: repositoryTitle),
        ]
        for book in books where book.id != ChatScope.helpBookID {
            pages.append(ChatScopePage(scope: .book(BookID(rawValue: book.id.uuidString)), title: book.title))
        }
        pages.append(ChatScopePage(scope: .library, title: libraryTitle))
        return pages
    }
}
