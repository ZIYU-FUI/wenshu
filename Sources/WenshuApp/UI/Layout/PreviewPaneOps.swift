//
//  PreviewPaneOps.swift · Wenshu · v1.75 preview-pane-mvvm T1b
//
//  Reference-card data loading + sorting business layer, extracted from
//  PreviewPane (= the largest P0 view listed in
//  .scratch/2026-09-23-mvvm-audit/spec.md §9 v1.75 arc).
//
//  Per v1.72 KanbanOps template (= @MainActor enum + Result types +
//  static funcs). Per Q112 1 ticket = 1 file. Per boss rule:
//  "PreviewPane single-consumer (B)" (= BookDocLoaderOps is
//  PreviewPane's private copy; = future ticket lifts to shared service
//  when ZoneModuleView consumes it too).
//
//  Public surface (= 11 entry points + 5 Result types):
//    1. loadAllEntities(bookStore:) -> LoadEntitiesResult
//    2. loadBooksInShelf(bookStore:shelfId:) -> LoadBooksResult
//    3. loadShelfBooksAsync(bookStore:shelfId:) async -> LoadBooksResult
//    4. loadBody(bookStore:for:) -> LoadBodyResult
//    5. loadBookDocs(bookStore:bookId:folderName:) -> LoadBookDocsResult
//    6. sortBookDocs(_:by:) -> [BookDoc]
//    7. sortEntities(_:by:) -> [Reference]
//    8. searchFilteredEntities(_:query:) -> [Reference]   (= spec §9.2 row 6)
//    9. searchFilteredBookDocs(_:query:) -> [BookDoc]      (= spec §9.2 row 6)
//    10. matchesSearch(title:summary:query:) -> Bool       (= spec §9.2 row 6)
//    11. pinyinFirstLetters(_:) -> String                  (= spec §9.2 row 6)
//
//  No actor involvement (= pure filesystem + JSON helpers).
//  All bookStore input preserved as view-supplied.
//

import Foundation

/// Stateless business layer for PreviewPane. Mirrors the v1.72 +
/// v1.74 + v1.75a-i precedents.
@MainActor
enum PreviewPaneOps {

    // MARK: - Result types

    struct LoadEntitiesResult {
        var entities: [Reference]
        var error: String?
    }

    struct LoadBooksResult {
        var books: [Book]
    }

    struct LoadBodyResult {
        var body: String?
    }

    struct LoadBookDocsResult {
        var docs: [BookDoc]
    }

    // MARK: - Entry points

    /// Load all reference entities (= the picker source).
    static func loadAllEntities(bookStore: BookStore?) -> LoadEntitiesResult {
        guard let bookStore else {
            return LoadEntitiesResult(entities: [], error: "bookStore is nil")
        }
        do {
            let allRefs = try bookStore.referenceStore.loadAllReferences()
            let layer = allRefs.filter { $0.layer == .layerEntities }
            return LoadEntitiesResult(entities: layer, error: nil)
        } catch {
            return LoadEntitiesResult(entities: [], error: String(describing: error))
        }
    }

    /// Load all books in one shelf (= the shelf scope source).
    static func loadBooksInShelf(bookStore: BookStore?, shelfId: UUID) -> LoadBooksResult {
        guard let bookStore else { return LoadBooksResult(books: []) }
        let allBooks = (try? bookStore.sidebarLoadAllBooks()) ?? []
        return LoadBooksResult(books: allBooks.filter { $0.shelfId == shelfId })
    }

    /// Async wrapper around `loadBooksInShelf` (= the picker reload trigger).
    static func loadShelfBooksAsync(bookStore: BookStore?, shelfId: UUID) async -> LoadBooksResult {
        // Yield first so SwiftUI can finish rendering the empty state
        // before we touch disk (= same yield discipline as the
        // pre-extraction inline impl).
        await Task.yield()
        return loadBooksInShelf(bookStore: bookStore, shelfId: shelfId)
    }

    /// Load the body text for one reference entity (= the preview pane content).
    static func loadBody(bookStore: BookStore?, for entity: Reference) -> LoadBodyResult {
        guard let bookStore else { return LoadBodyResult(body: nil) }
        return LoadBodyResult(body: bookStore.referenceStore.loadReferenceBody(id: entity.id))
    }

    /// Load the book docs for one book (= the doc list source; = file scan).
    static func loadBookDocs(
        bookStore: BookStore?,
        bookId: UUID,
        folderName: String?
    ) -> LoadBookDocsResult {
        guard let bookStore else { return LoadBookDocsResult(docs: []) }
        // Walk shelves root to find which shelf this bookId lives in.
        // Layout = shelves/<shelf-uuid>/books/<book-uuid>/...
        let shelvesRoot = bookStore.stores.shelvesRoot
        guard FileManager.default.fileExists(atPath: shelvesRoot.path) else {
            return LoadBookDocsResult(docs: [])
        }
        let bookDirs: [URL]
        if let shelfDirs = try? FileManager.default.contentsOfDirectory(
            at: shelvesRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            bookDirs = shelfDirs.compactMap { shelfDir in
                let candidate = shelfDir
                    .appendingPathComponent("books")
                    .appendingPathComponent(bookId.uuidString)
                return FileManager.default.fileExists(atPath: candidate.path)
                    ? candidate
                    : nil
            }
        } else {
            bookDirs = []
        }
        guard let bookDir = bookDirs.first else { return LoadBookDocsResult(docs: []) }

        // Determine which folders to scan.
        let folders: [String]
        if let folderName {
            folders = [folderName]
        } else {
            folders = BookFolder.allCases.map(\.directoryName)
        }

        var docs: [BookDoc] = []
        for folder in folders {
            let dir = bookDir.appendingPathComponent(folder)
            guard let entries = try? FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [
                    URLResourceKey.contentModificationDateKey,
                    URLResourceKey.creationDateKey
                ],
                options: [.skipsHiddenFiles]
            ) else { continue }
            for url in entries where url.pathExtension == "md" {
                let body = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                let attrs = try? url.resourceValues(forKeys: [
                    URLResourceKey.contentModificationDateKey,
                    URLResourceKey.creationDateKey
                ])
                let modifiedAt = attrs?.contentModificationDate ?? Date.distantPast
                let createdAt = attrs?.creationDate ?? Date.distantPast
                docs.append(BookDoc(
                    id: stableBookDocId(
                        bookId: bookId,
                        folderName: folder,
                        fileName: url.lastPathComponent
                    ),
                    bookId: bookId,
                    folderName: folder,
                    fileName: url.lastPathComponent,
                    modifiedAt: modifiedAt,
                    createdAt: createdAt,
                    body: body
                ))
            }
        }
        return LoadBookDocsResult(docs: docs)
    }

    /// Sort book docs by the active sort order (= .pinyinFirstLetter default).
    /// Stable sort by fileName tiebreaker.
    static func sortBookDocs(_ docs: [BookDoc], by order: EntitySortOrder) -> [BookDoc] {
        switch order {
        case .pinyinFirstLetter:
            return docs.sorted { lhs, rhs in
                let lKey = pinyinFirstLetter(lhs.title)
                let rKey = pinyinFirstLetter(rhs.title)
                if lKey != rKey { return lKey < rKey }
                return lhs.fileName < rhs.fileName
            }
        case .createdAt:
            return docs.sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.fileName < rhs.fileName
            }
        case .modifiedAt:
            return docs.sorted { lhs, rhs in
                if lhs.modifiedAt != rhs.modifiedAt {
                    return lhs.modifiedAt > rhs.modifiedAt
                }
                return lhs.fileName < rhs.fileName
            }
        }
    }

    /// Sort reference entities by the active sort order.
    /// Stable sort by id tiebreaker (= prevents visual re-shuffle).
    static func sortEntities(_ entities: [Reference], by order: EntitySortOrder) -> [Reference] {
        switch order {
        case .pinyinFirstLetter:
            return entities.sorted { lhs, rhs in
                let lKey = pinyinFirstLetter(lhs.title)
                let rKey = pinyinFirstLetter(rhs.title)
                if lKey != rKey { return lKey < rKey }
                return lhs.id.uuidString < rhs.id.uuidString
            }
        case .createdAt:
            return entities.sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
        case .modifiedAt:
            return entities.sorted { lhs, rhs in
                let lMod = lhs.updatedAt
                let rMod = rhs.updatedAt
                if lMod != rMod {
                    return lMod > rMod
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
        }
    }

    // MARK: - Search filter (= per spec §9.2 row 6 extension)

    /// Filter reference entities by the current search query.
    /// Matches against BOTH:
    /// 1. Original title / summary substring (= case-insensitive)
    /// 2. Pinyin first-letter substring (= e.g. "d" matches "X" -> DX)
    /// Empty query = pass-through (= show all entities).
    static func searchFilteredEntities(_ entities: [Reference], query: String) -> [Reference] {
        return entities.filter { matchesSearch(title: $0.title, summary: $0.summary, query: query) }
    }

    /// Filter book docs by the current search query.
    /// Same filter shape as `searchFilteredEntities` but for book
    /// docs (= filesystem .md files loaded by `loadBookDocs`).
    static func searchFilteredBookDocs(_ docs: [BookDoc], query: String) -> [BookDoc] {
        return docs.filter { matchesSearch(title: $0.title, summary: $0.summary, query: query) }
    }

    /// Substring matcher shared between entities and book docs
    /// (= per boss 'use one common interface').
    /// Empty query = pass-through. Pure function (= no actor,
    /// no MainActor; = trivially testable).
    static func matchesSearch(title: String, summary: String, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        let lowered = trimmed.lowercased()
        if title.localizedCaseInsensitiveContains(trimmed)
            || summary.localizedCaseInsensitiveContains(trimmed) {
            return true
        }
        let pinyinKey = pinyinFirstLetters(title)
        if pinyinKey.lowercased().contains(lowered) {
            return true
        }
        return false
    }

    /// Pinyin first-letter sequence for one title.
    /// Tokenises on whitespace, drops pure-punctuation tokens,
    /// takes the first letter of each (= per Q99 Standards axis
    /// LOW fix: emoji titles now produce one initial char too).
    /// Pure function (= no actor, no MainActor).
    static func pinyinFirstLetters(_ title: String) -> String {
        let mutable = NSMutableString(string: title)
        CFStringTransform(mutable, nil, kCFStringTransformToLatin, false)
        CFStringTransform(mutable, nil, kCFStringTransformStripDiacritics, false)
        let latinized = (mutable as String)
        let initials = latinized
            .split(whereSeparator: { $0.isWhitespace })
            .compactMap { token -> String? in
                guard let first = token.first else { return nil }
                guard first.isLetter || first.isNumber || first.isSymbol else { return nil }
                return String(first).uppercased()
            }
            .joined()
        return String(initials)
    }

    // MARK: - Private helpers

    /// Stable id for a book doc (= bookId + folderName + fileName).
    /// Pure function (= no actor, no MainActor). Returns UUID
    /// via BookDocIDFactory (= SHA256 hash of canonical path).
    nonisolated static func stableBookDocId(bookId: UUID, folderName: String, fileName: String) -> UUID {
        return BookDocIDFactory.make(bookId: bookId, folderName: folderName, fileName: fileName)
    }

    /// Convert Chinese title to its pinyin first letter (= uppercase).
    /// Uses Apple CFStringTransform (kCFStringTransformToLatin +
    /// kCFStringTransformStripDiacritics). Pure function (= no actor).
    private static func pinyinFirstLetter(_ title: String) -> String {
        let mutable = NSMutableString(string: title)
        CFStringTransform(mutable, nil, kCFStringTransformToLatin, false)
        CFStringTransform(mutable, nil, kCFStringTransformStripDiacritics, false)
        let latinized = (mutable as String).trimmingCharacters(in: .whitespaces)
        if let first = latinized.first {
            return String(first).uppercased()
        }
        return "~"
    }
}