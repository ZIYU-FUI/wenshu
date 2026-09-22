// LazySidebarFileOps.swift · Wenshu · v1.68
//
// Boss 2026-09-22 OOB 'UI 与功能分离, UI 是 UI, 加载的内容是内容,
// 不要混合写大文件': extracted from LazySidebarView.swift (= the
// 957-LOC file that the v1.64 / v1.65 sidebar rewrite produced).
//
// This file owns the sidebar's FILE OPERATIONS (= the things the
// LazySidebarView's sheet onSave + delete-confirmation buttons +
// rename sheet handler actually invoke). They are PURE FUNCTIONS:
// every input is a parameter (= no @State, no @Environment); the
// caller passes in the current in-memory shelves / books / sidebarSelection
// + the bookStore (= for the shelvesRoot URL + folderDocumentCount).
// This means they're testable in isolation (= the v1.68 boss 2026-
// 09-22 OOB 'UI 与功能分离' implies they belong to 'content / 加载的
// 内容', not the view).
//
// What lives here:
//   - pendingDeleteChildCount
//   - resolveNewItemTargetShelf
//   - deleteShelf
//   - deleteBook
//   - renameShelf
//   - renameBook
//
// What does NOT live here:
//   - view body or sheet view rendering (= LazySidebarView /
//     LazySidebarSheets / LazySidebarRow).
//   - state persistence (= LazySidebarState).
//
// v1.68 restore notes: the v1.67 LazySidebarView had these as
// private methods (= depended on @State + @Environment implicitly
// through method scope). Splitting them out surfaces their hidden
// inputs (= the shelves / books / bookStore arguments) and makes
// them reusable from any caller (= test code, future Apple HIG
// sidebar rewrite, BookManagerTool, etc.).

import Foundation

/// The sidebar's 5 standard sub-folders (= matches BookManager's
/// canonical folder list). Exposed here (= was inline in the v1.67
/// LazySidebarView's standardFolderNames getter) so both file ops
/// and row rendering can refer to the same constant.
struct LazySidebarStandardFolders {
    let name: String
    let displayName: String
    let icon: String

    static let all: [LazySidebarStandardFolders] = [
        .init(name: "world",      displayName: "世界观",   icon: "globe"),
        .init(name: "characters", displayName: "角色",     icon: "person"),
        .init(name: "outlines",   displayName: "章节大纲", icon: "list.bullet.rectangle"),
        .init(name: "chapters",   displayName: "小说正文", icon: "text.book.closed"),
        .init(name: "drafts",     displayName: "小说草稿", icon: "pencil"),
    ]
}

enum LazySidebarFileOps {

    /// Count the number of children that will be cascade-deleted when
    /// the user confirms deletion. Shelve children = books; book
    /// children = documents across all 5 standard folders.
    static func pendingDeleteChildCount(
        target: LazyPendingDelete,
        books: [Book],
        bookStore: BookStore
    ) -> Int {
        switch target.kind {
        case .shelf:
            return books.filter { $0.shelfId == target.itemId }.count
        case .book:
            return LazySidebarStandardFolders.all.reduce(0) { sum, folder in
                sum + bookStore.folderDocumentCount(
                    bookId: target.itemId,
                    folderDirectoryName: folder.name
                )
            }
        }
    }

    /// Resolve the target shelf for the new-book sheet. Priority
    /// (matches v1.67): if a book is selected, use its shelf; if a
    /// shelf is selected, use that shelf; otherwise the special
    /// "从这里开始" default shelf (= UUID
    /// 00000000-0000-0000-0000-000000000000).
    static func resolveNewItemTargetShelf(
        selection: SidebarItem?,
        books: [Book],
        shelves: [Bookshelf]
    ) -> (id: UUID, name: String) {
        if case .book(let bookId) = selection,
           let book = books.first(where: { $0.id == bookId }),
           let shelf = shelves.first(where: { $0.id == book.shelfId }) {
            return (shelf.id, shelf.name)
        }
        if case .shelf(let shelfId) = selection,
           let shelf = shelves.first(where: { $0.id == shelfId }) {
            return (shelf.id, shelf.name)
        }
        let defaultId = UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID()
        let defaultName = shelves.first(where: { $0.id == defaultId })?.name ?? "从这里开始"
        return (defaultId, defaultName)
    }

    /// Delete a shelf directory. Refuses to delete the default shelf.
    static func deleteShelf(id: UUID, shelvesRoot: URL) throws {
        guard id.uuidString != "00000000-0000-0000-0000-000000000000" else {
            throw NSError(domain: "LazySidebar", code: 1)
        }
        let dir = shelvesRoot.appendingPathComponent(id.uuidString, isDirectory: true)
        if FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.removeItem(at: dir)
        }
    }

    /// Delete a book directory (= scans each shelf's books/ for the
    /// matching UUID). Walks every shelf (= O(N×M) but N is tiny).
    static func deleteBook(id: UUID, shelves: [Bookshelf], shelvesRoot: URL) throws {
        guard let parentShelf = shelves.first(where: { shelf in
            let booksDir = shelvesRoot
                .appendingPathComponent(shelf.directoryName, isDirectory: true)
                .appendingPathComponent("books", isDirectory: true)
            return FileManager.default.fileExists(
                atPath: booksDir.appendingPathComponent(id.uuidString).path
            )
        }) else { return }
        let dir = shelvesRoot
            .appendingPathComponent(parentShelf.directoryName, isDirectory: true)
            .appendingPathComponent("books", isDirectory: true)
            .appendingPathComponent(id.uuidString, isDirectory: true)
        if FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.removeItem(at: dir)
        }
    }

    /// Rename a shelf by rewriting its shelf.json. Refuses reserved
    /// names (= 资料库 / 参考库 / reference library) and duplicate
    /// case-insensitive names against the other shelves.
    static func renameShelf(
        id: UUID,
        newName: String,
        shelves: [Bookshelf],
        shelvesRoot: URL
    ) throws {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let reserved: Set<String> = ["资料库", "参考库", "reference library"]
        if reserved.contains(where: { trimmed.caseInsensitiveCompare($0) == .orderedSame }) {
            throw NSError(domain: "LazySidebar", code: 2)
        }
        let others = shelves
            .filter { $0.id != id }
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
        if others.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            throw NSError(domain: "LazySidebar", code: 3)
        }
        let shelfDir = shelvesRoot
            .appendingPathComponent(id.uuidString, isDirectory: true)
        let shelfJSONURL = shelfDir.appendingPathComponent("shelf.json")
        guard FileManager.default.fileExists(atPath: shelfJSONURL.path),
              let data = try? Data(contentsOf: shelfJSONURL),
              var existing = try? JSONDecoder().decode(Bookshelf.self, from: data)
        else { return }
        existing.name = trimmed
        existing.updatedAt = Date()
        let updated = try JSONEncoder().encode(existing)
        try updated.write(to: shelfJSONURL)
    }

    /// Rename a book by rewriting its book.json. Refuses duplicate
    /// case-insensitive titles against the other books.
    static func renameBook(
        id: UUID,
        newTitle: String,
        books: [Book],
        shelves: [Bookshelf],
        shelvesRoot: URL
    ) throws {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let otherTitles = books
            .filter { $0.id != id }
            .map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines) }
        if otherTitles.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            throw NSError(domain: "LazySidebar", code: 4)
        }
        guard let parentShelf = shelves.first(where: { shelf in
            let booksDir = shelvesRoot
                .appendingPathComponent(shelf.directoryName, isDirectory: true)
                .appendingPathComponent("books", isDirectory: true)
            return FileManager.default.fileExists(
                atPath: booksDir.appendingPathComponent(id.uuidString).path
            )
        }) else { return }
        let bookJSONURL = shelvesRoot
            .appendingPathComponent(parentShelf.directoryName, isDirectory: true)
            .appendingPathComponent("books", isDirectory: true)
            .appendingPathComponent(id.uuidString, isDirectory: true)
            .appendingPathComponent("book.json")
        guard FileManager.default.fileExists(atPath: bookJSONURL.path),
              let data = try? Data(contentsOf: bookJSONURL),
              var existing = try? JSONDecoder().decode(Book.self, from: data)
        else { return }
        existing.title = trimmed
        existing.updatedAt = Date()
        let updated = try JSONEncoder().encode(existing)
        try updated.write(to: bookJSONURL)
    }
}