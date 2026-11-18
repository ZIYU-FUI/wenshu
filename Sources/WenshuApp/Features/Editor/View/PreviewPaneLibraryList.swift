// PreviewPaneLibraryList.swift · The whole 文枢库's documents as ONE list.
//
// WHY THIS FILE EXISTS
//
// The boss's rule (2026-11-17): the materials column's whole-library scope
// shows its documents in ONE list (= the 资料库's documents first, = = then
// 书 1, = = then 书 2), = = not as two stacked grids (= the 资料库's grid
// above and the 书房's grid below).
//
// ⇒ ⇒ ⇒ AND THAT SCOPE WAS THE ONE THAT PAID ITS WHOLE-LIBRARY WALK ON
// EVERY BODY PASS. = = SwiftUI re-evaluates a view's body on every
// observation tick (= every store mutation, = = every selection change), = =
// and the old shape walked the whole library TWICE per pass (= the grid
// walked it, = = and the chrome's card count walked it again), = = and each
// walk read every .md's FULL body. = = ⇒ So the walk is here, ONCE, = =
// and the list it builds is what the grid draws and what the count reads.
//
// ⇒ ⇒ ⇒ AND THE LIST CARRIES METADATA ONLY. = = A card shows a title, a
// summary and a chip tag, = = and all three live in the file's HEAD. = =
// The document's body is read when the document is OPENED (= =
// `CardOpenOps.loadBookDocBody` reads the file from disk, = = so the
// editor never sees a truncated body).
//
// ⇒ ⇒ ⇒ AND THE ORDER IS THE REQUIREMENT'S ORDER: = = the 资料库's
// documents first, = = then each book's documents in the order the books
// load (= 书 1, = = 书 2 = = `sidebarLoadAllBooks`'s own createdAt
// order), = = and each group sorted by the active sort order (= = the
// pinyin first letter by default, = = the rule the boss named: = = "先按
// 拼音首字母排序即可").

import Foundation

// MARK: - One document of the list

/// One document of the whole library's ONE list.
///
/// = = The list's own item: = = it carries the card's data (= the only
/// shape the card knows) and the ONE extra field the list needs (= = the
/// identity, = = namespaced so a reference's id and a book document's id
/// can never collide in one list).
struct LibraryDocument: Identifiable {
    /// The list's identity (= = "ref:<uuid>" or "doc:<uuid>").
    let id: String

    /// The card's own data (= = `CardSource` = = the only shape the card
    /// knows).
    let source: CardSource

    /// The title the card shows.
    let title: String

    /// The summary the card shows (= = the document's own first lines).
    let summary: String

    /// The chip tags the card shows.
    let tags: [String]

    /// The pinyin first-letters key (= = computed ONCE, = = at the load).
    ///
    /// = = The search filter needs it for every document on every body
    /// pass, = = and the transliteration is a `CFStringTransform` (= = a
    /// measured 47us), = = so computing it at the load takes it out of the
    /// body pass entirely.
    let searchKey: String

    /// Whether this document matches the search query.
    ///
    /// = = The same rule the scope filters use (= =
    /// `PreviewPaneOps.matchesSearch`), = = with the pinyin key already
    /// computed.
    func matches(query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        let lowered = trimmed.lowercased()
        if title.localizedCaseInsensitiveContains(trimmed)
            || summary.localizedCaseInsensitiveContains(trimmed)
        {
            return true
        }
        return searchKey.contains(lowered)
    }
}

// MARK: - The list

/// The whole library's documents, in the ONE order the materials column
/// draws them.
struct LibraryDocumentList {
    /// The 资料库's documents (= = the library's references), = = sorted.
    let references: [LibraryDocument]

    /// The 书房's documents, = = one group per book, = = in the order the
    /// books load (= = 书 1, = = 书 2).
    let bookGroups: [[LibraryDocument]]

    /// THE ONE LIST (= = the 资料库's group, = = then each book's group).
    var documents: [LibraryDocument] {
        references + bookGroups.flatMap { $0 }
    }

    /// How many documents the list holds (= = the chrome's card count
    /// reads this, = = instead of walking the library a second time).
    var count: Int {
        references.count + bookGroups.reduce(0) { $0 + $1.count }
    }

    /// The list with the search query applied (= = in memory, = = over the
    /// already-loaded documents).
    func filtered(by query: String) -> [LibraryDocument] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return documents }
        return documents.filter { $0.matches(query: trimmed) }
    }
}

// MARK: - The loader

/// Builds the whole library's ONE list (= = the one walk).
@MainActor
enum LibraryDocumentLoader {
    /// Build the whole library's list.
    ///
    /// - Parameters:
    ///   - bookStore: the library (= = `nil` = = an empty list).
    ///   - sortOrder: the active sort order (= = the pinyin first letter
    ///     by default).
    /// - Returns: the list, in the requirement's order.
    static func load(
        bookStore: BookStore?,
        sortOrder: EntitySortOrder
    ) -> LibraryDocumentList {
        LibraryDocumentList(
            references: loadReferences(bookStore: bookStore, sortOrder: sortOrder),
            bookGroups: loadBooks(bookStore: bookStore, sortOrder: sortOrder)
        )
    }

    /// The 资料库's documents (= = the library's references).
    ///
    /// = = The same loader the reference scope uses (= =
    /// `loadAllEntities`), = = and the same user-facing layer filter (= =
    /// the raw layer is for ingestion, = = not for browsing).
    private static func loadReferences(
        bookStore: BookStore?,
        sortOrder: EntitySortOrder
    ) -> [LibraryDocument] {
        let entities = PreviewPaneOps.loadAllEntities(bookStore: bookStore).entities
            .filter { $0.layer == .layerEntities }
        return PreviewPaneOps.sortEntities(entities, by: sortOrder).map { entity in
            LibraryDocument(
                id: "ref:\(entity.id.uuidString)",
                source: .reference(entity),
                title: entity.title,
                summary: entity.summary,
                tags: entity.tags.sorted(),
                searchKey: PreviewPaneOps.pinyinFirstLetters(entity.title).lowercased()
            )
        }
    }

    /// The 书房's documents, = = one group per book, = = in the order the
    /// books load.
    ///
    /// = = The books come from the store's own door (= =
    /// `sidebarLoadAllBooks`, = = which sorts by createdAt = = 书 1, = =
    /// 书 2), = = and each book's directory is derived from the book
    /// model (= = `<shelvesRoot>/<shelf-uuid>/books/<book-uuid>`, = = the
    /// store's own layout), = = so the shelves tree is walked ONCE for the
    /// whole library instead of once per book (= = the old shape looked
    /// the shelves root up for EVERY book).
    private static func loadBooks(
        bookStore: BookStore?,
        sortOrder: EntitySortOrder
    ) -> [[LibraryDocument]] {
        guard let bookStore else { return [] }
        let books = (try? bookStore.sidebarLoadAllBooks()) ?? []
        let shelvesRoot = bookStore.stores.shelvesRoot
        return books.map { book in
            let bookDir = shelvesRoot
                .appendingPathComponent(book.shelfId.uuidString, isDirectory: true)
                .appendingPathComponent("books", isDirectory: true)
                .appendingPathComponent(book.id.uuidString, isDirectory: true)
            return loadBookDocuments(book: book, bookDir: bookDir, sortOrder: sortOrder)
        }
    }

    /// One book's documents (= = every .md in its folders).
    private static func loadBookDocuments(
        book: Book,
        bookDir: URL,
        sortOrder: EntitySortOrder
    ) -> [LibraryDocument] {
        var docs: [BookDoc] = []
        for folder in BookFolder.allCases {
            let dir = bookDir.appendingPathComponent(folder.directoryName)
            guard let entries = try? FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [
                    URLResourceKey.contentModificationDateKey,
                    URLResourceKey.creationDateKey,
                ],
                options: [.skipsHiddenFiles]
            ) else { continue }
            for url in entries where url.pathExtension == "md" {
                guard let doc = loadBookDocument(book: book, folder: folder, url: url) else {
                    continue
                }
                docs.append(doc)
            }
        }
        return PreviewPaneOps.sortBookDocs(docs, by: sortOrder).map { doc in
            LibraryDocument(
                id: "doc:\(doc.id.uuidString)",
                source: .bookDoc(doc),
                title: doc.title,
                summary: doc.summary,
                tags: doc.tags.sorted(),
                searchKey: PreviewPaneOps.pinyinFirstLetters(doc.title).lowercased()
            )
        }
    }

    /// Read one .md's CARD metadata (= = its head, = = not its whole body).
    ///
    /// = = The card needs three things from the file: = = the title (= =
    /// the file name), = = the chip tag (= = the file's first H1) and = =
    /// the summary (= = the first 200 characters after that H1). = = All
    /// three live in the file's HEAD.
    ///
    /// = = ⇒ The body is NOT read here. = = The document's body is read
    /// when the document is OPENED (= = `CardOpenOps.loadBookDocBody`,
    /// = = which reads the file from disk), = = so a truncated body never
    /// reaches the editor.
    ///
    /// = = ⇒ The head is EXACT: = = the file's first H1 may sit anywhere,
    /// = = so a head with no H1 in it (= = and the file is longer than the
    /// head) = = falls back to the whole file, = = and a head that would
    /// cut a multi-byte character in half falls back too. = = The card
    /// then shows exactly what it showed before.
    private static func loadBookDocument(
        book: Book,
        folder: BookFolder,
        url: URL
    ) -> BookDoc? {
        let rawBody: String
        switch readHead(of: url) {
        case let .whole(text):
            rawBody = text
        case let .head(text, holdsTheCard: false):
            // The head does NOT hold everything the card needs (= = its
            // H1 was cut by the head's boundary, = = or the body after
            // that H1 is shorter than the summary's window), = = so the
            // whole file is read (= = and the card shows exactly what it
            // showed before).
            rawBody = (try? String(contentsOf: url, encoding: .utf8)) ?? text
        case let .head(text, holdsTheCard: true):
            // The head holds the H1 line COMPLETE = = and the summary's
            // whole 200-character window after it, = = so the card shows
            // exactly what it showed before (= = the review's finding: = =
            // "holdsH1 only proves the head CONTAINS an H1" = = and that
            // inference was false near the boundary).
            rawBody = text
        case .undecodable:
            rawBody = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        }
        let (firstH1, bodyWithoutH1) = PreviewPaneOps.splitFirstH1(rawBody)
        let attrs = try? url.resourceValues(forKeys: [
            URLResourceKey.contentModificationDateKey,
            URLResourceKey.creationDateKey,
        ])
        return BookDoc(
            id: PreviewPane.stableBookDocId(
                bookId: book.id,
                folderName: folder.directoryName,
                fileName: url.lastPathComponent
            ),
            bookId: book.id,
            folderName: folder.directoryName,
            fileName: url.lastPathComponent,
            modifiedAt: attrs?.contentModificationDate ?? Date.distantPast,
            createdAt: attrs?.creationDate ?? Date.distantPast,
            tags: firstH1.map { [$0] } ?? [],
            body: bodyWithoutH1
        )
    }

    /// How many bytes of a .md the card needs.
    ///
    /// = = The summary is the first 200 characters after the H1, = = and
    /// the H1 sits at the top of a chapter, = = so 8 KB holds both with
    /// room to spare. = = A chapter's body (= = the document's content)
    /// is not read here.
    static let headByteCount = 8 * 1024

    /// What a head read found.
    enum HeadRead {
        /// The whole file (= = the file is shorter than the head).
        case whole(String)
        /// The head of a longer file (= = and whether it holds EVERYTHING
        /// the card needs: = = the H1 line complete = = and the summary's
        /// whole window after it).
        case head(String, holdsTheCard: Bool)
        /// The head could not be decoded (= = the caller must read the
        /// whole file).
        case undecodable
    }

    /// Read a file's head.
    ///
    /// = = INTERNAL (= = not private) = = so the test can pin the READ
    /// itself (= = the card's content is the same whether the head read
    /// works or falls back, = = so only the read's own result can tell
    /// the two apart).
    ///
    /// = = The read stops at the head's byte count, = = and a head that
    /// ends mid-character keeps its COMPLETE characters (= = the trailing
    /// incomplete one is dropped) = = so a CJK document's head is still a
    /// head (= = dropping the whole read would make the head read a
    /// whole-body read for every CJK file, = = because the cut lands
    /// inside a character in almost every one of them).
    ///
    /// = = A head that cannot be decoded AT ALL is reported as
    /// undecodable (= = so the caller reads the whole file and the card
    /// shows exactly what it showed before).
    static func readHead(of url: URL) -> HeadRead {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return .undecodable }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: headByteCount) else { return .undecodable }
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        guard let text = Self.decodePrefix(data) else { return .undecodable }
        if size <= headByteCount {
            return .whole(text)
        }
        // The file is longer than the head: = = the head is a prefix, = =
        // and the card can be built from it ONLY when the head holds
        // everything the card needs (= = see `headHoldsTheCard`).
        return .head(text, holdsTheCard: headHoldsTheCard(text))
    }

    /// Whether the head holds everything the card needs.
    ///
    /// = = The card needs TWO things from the body: = = the chip tag (= =
    /// the H1's text) = = and the summary (= = the first 200 characters of
    /// the body after that H1).
    ///
    /// = = ⇒ The head is sufficient when it holds the H1 line COMPLETE
    /// (= = not cut by the head's boundary, = = or the chip tag is a
    /// truncated title) = = AND at least 200 characters of the body after
    /// it (= = or the summary is shorter than the whole-body read's).
    ///
    /// = = ⇒ AND the head's LAST line may be cut (= = the head's boundary
    /// can land in the middle of a line), = = so the check runs on the
    /// head's COMPLETE lines only (= = the lines before that cut).
    ///
    /// = = ⇒ MEASURED, = = at the review that asked for it: = = "holdsH1
    /// only proves the head CONTAINS an H1" = = and that inference was
    /// false near the boundary (= = a chapter whose H1 line ends near the
    /// boundary gave an 88-character summary against the whole-body
    /// read's 200, = = and a 2740-character CJK title gave a TRUNCATED
    /// chip tag).
    static func headHoldsTheCard(_ text: String) -> Bool {
        let (h1, body) = PreviewPaneOps.splitFirstH1(Self.completeLines(of: text))
        guard h1 != nil else { return false }
        return body.count >= 200
    }

    /// The text's COMPLETE lines (= = minus a last line that a read's
    /// boundary may have cut).
    ///
    /// = = A head that ends with a line break holds whole lines (= = and
    /// nothing is cut); = = a head that ends mid-line holds a partial
    /// last line (= = and that line is dropped).
    private static func completeLines(of text: String) -> String {
        guard !text.hasSuffix("\n") else { return text }
        guard let lastNewline = text.lastIndex(of: "\n") else { return "" }
        return String(text[...lastNewline])
    }

    /// Decode a byte block, = = dropping a trailing incomplete character.
    ///
    /// = = A UTF-8 character is at most four bytes, = = so a block that
    /// ends mid-character is repaired by dropping up to three trailing
    /// bytes (= = and the longest decodable prefix is what the caller
    /// gets).
    private static func decodePrefix(_ data: Data) -> String? {
        if let text = String(data: data, encoding: .utf8) {
            return text
        }
        var trimmed = data
        for _ in 0 ..< 3 {
            guard !trimmed.isEmpty else { return nil }
            trimmed = trimmed.dropLast()
            if let text = String(data: trimmed, encoding: .utf8) {
                return text
            }
        }
        return nil
    }
}

// MARK: - The store

/// The whole library's list, held ONCE (= = not once per body pass).
///
/// = = An `@Observable` object (= = the house's store shape, = = the same
/// one `BookStore` uses): = = the pane's body reads `documents`, = = and
/// the load writes them, = = so the view updates when the load lands.
@MainActor
@Observable
final class LibraryDocumentStore {
    /// The list (= = empty until the first load lands).
    private(set) var documents: LibraryDocumentList = .init(
        references: [],
        bookGroups: []
    )

    /// Whether the list has been loaded at least once.
    private(set) var isLoaded = false

    /// The key of the load that is current (= = the scope + the tick + the
    /// sort order).
    ///
    /// = = NOT observable (= = `@ObservationIgnored`): = = the body sets
    /// it while it runs, = = and an observable write there would make the
    /// view invalidate itself mid-update.
    @ObservationIgnored private var loadedKey: String?

    /// Walk the library and land the list (= = the one walk).
    ///
    /// = = This is the store's ONLY door (= = the pane's `.task(id:)` and
    /// a test both come here): = = the walk is disk IO, = = and it runs
    /// ONCE per key (= = not once per body pass, = = which was the cost
    /// this change removes). = = The call yields first (= = the house's
    /// own discipline in `loadShelfBooksAsync`), = = so the pane can
    /// finish rendering the frame it is on before the walk starts.
    ///
    /// = = ⇒ AND THE KEY IS THE GUARD: = = a caller whose key is already
    /// loaded does not walk again (= = so the pane's task and a test's own
    /// call cannot walk the library twice for the same list).
    func loadNow(
        key: String,
        bookStore: BookStore?,
        sortOrder: EntitySortOrder
    ) async {
        guard loadedKey != key || !isLoaded else { return }
        loadedKey = key
        await Task.yield()
        let loaded = LibraryDocumentLoader.load(bookStore: bookStore, sortOrder: sortOrder)
        documents = loaded
        isLoaded = true
    }
}
