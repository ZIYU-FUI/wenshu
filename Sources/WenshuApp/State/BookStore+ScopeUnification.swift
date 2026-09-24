//
//  BookStore+ScopeUnification.swift · Wenshu · B-13 scope unification
//
//  P2-06 (audit 2026-09-24): extracted from `BookStore.swift` (= 118
//  LOC of B-13 scope-directory resolution). BookStore was 555 LOC;
//  this extension brings it down to ~340 LOC.
//

import Foundation

// MARK: - B-13 scope unification (= Kanban / Todo / reference-library data tree)
//
// Boss 2026-09-04 OOB scope unification: the old `bookDirectory(bookId:)`
// only resolved the book root. The 8 standard sub-folders (= `chapters/`
// etc.) and the `reference-library/` root are now valid scope targets
// too. The reference library (= `reference-library/` at the workspace
// root) is added as `TaskScope.referenceLibrary` (= its own kanban /
// todo JSON files at the library root).
//
// Design (= per spec `.scratch/2026-09-04-b-13-scope-unification.md`):
//   - Scope is a VIEW FILTER, not a data-layer change. One kanban.json /
//     todo.json per (book, sub-folder) pair + a library-kanban.json /
//     library-todo.json at the library root.
//   - `TaskScope` enumerates the valid scope variants. The UI scope picker
//     in Kanban + Todo views uses `availableScopes(bookId:)` to enumerate
//     the user's choices for the active book.
//   - `scopeDirectory(bookId:scope:)` is the single helper views call to
//     resolve the URL that BookKanbanStore / BookTodoStore should write to.

/// One of the 8 standard sub-folders every book carries (= `chapters/`,
/// `world/`, `characters/`, etc., per LibraryBootstrapper). Each case is
/// also a valid `TaskScope` (= the picker lets the user target one).
enum StandardBookFolder: String, CaseIterable, Sendable, Codable {
    case world
    case characters
    case outlines
    case chapters
    case drafts
    case sessions
    case foreshadowing
    case placeholders

    /// Filesystem directory name (= derives from BookFolderCatalog
    /// = the SSOT for id → directoryName mapping).
    var folderName: String {
        BookFolderCatalog.spec(for: rawValue)?.directoryName ?? rawValue
    }

    /// User-facing Chinese label (= derives from BookFolderCatalog
    /// = the SSOT for id → cardDisplayName mapping; = the Kanban
    /// / Todo scope picker shows this label per folder).
    var displayName: String {
        BookFolderCatalog.spec(for: rawValue)?.cardDisplayName ?? rawValue
    }
}

/// A scope variant for Kanban / Todo data. Either the book root, one of
/// the 8 standard sub-folders inside the active book, or the reference
/// library (= library-public, cross-book). Scope is a view filter, not
/// a data-layer change: BookKanbanStore / BookTodoStore resolve to
/// different JSON filenames per scope (see `bookKanbanStoreURL` /
/// `bookTodoStoreURL` on the store types).
enum TaskScope: Hashable, Identifiable, Sendable {
    case book
    case folder(StandardBookFolder)
    case referenceLibrary

    var id: String {
        switch self {
        case .book: return "book"
        case .folder(let f): return "folder-\(f.folderName)"
        case .referenceLibrary: return "reference-library"
        }
    }

    var displayName: String {
        switch self {
        case .book: return "(全书)"
        case .folder(let f): return f.displayName
        case .referenceLibrary: return "资料库"
        }
    }

    /// All 8 standard sub-folder scopes (= the entries the picker
    /// shows between "" and "" when a book is active).
    public static func folderScopes() -> [TaskScope] {
        StandardBookFolder.allCases.map { .folder($0) }
    }
}

extension BookStore {
    /// Resolve the on-disk directory for a given `(bookId, scope)` pair.
    ///
    /// - `.book` (= book root): `bookDirectory(bookId:)` (= unchanged).
    /// - `.folder(f)`: `bookDirectory/<f.folderName>/` (= the standard
    ///   sub-folder inside the active book).
    /// - `.referenceLibrary`: `stores.referenceLibraryRoot` (= the
    ///   library-public archive; `bookId` is ignored).
    ///
    /// Returns nil if the book id is unknown AND the scope is per-book
    /// (= `.book` / `.folder`). The reference library always resolves if
    /// the workspace is bootstrapped.
    func scopeDirectory(bookId: UUID?, scope: TaskScope) -> URL? {
        switch scope {
        case .book:
            return bookId.flatMap { bookDirectoryCached(bookId: $0) }
        case .folder(let folder):
            guard let bookDir = bookId.flatMap({ bookDirectoryCached(bookId: $0) }) else {
                return nil
            }
            return bookDir.appendingPathComponent(folder.folderName, isDirectory: true)
        case .referenceLibrary:
            return stores.referenceLibraryRoot
        }
    }

    /// Enumerate the scope variants the UI picker should offer for the
    /// active book (= book root + 8 standard sub-folders + reference
    /// library). When no book is selected (= `bookId == nil`), the
    /// 8 sub-folder options are hidden (= they all live inside a book).
    func availableScopes(bookId: UUID?) -> [TaskScope] {
        var scopes: [TaskScope] = [.book]
        if bookId != nil {
            scopes.append(contentsOf: TaskScope.folderScopes())
        }
        scopes.append(.referenceLibrary)
        return scopes
    }
}