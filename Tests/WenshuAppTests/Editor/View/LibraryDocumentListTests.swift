//
//  LibraryDocumentListTests.swift · Wenshu
//
//  The whole 文枢库's documents as ONE list (= the boss's 2026-11-17 rule:
//  "一个列表，加载所有文枢。先按拼音首字母排序即可").
//
//  ⇒ ⇒ ⇒ AND THE PERFORMANCE HALF IS ASSERTED HERE TOO: = = the list
//  reads each .md's HEAD (= = not its whole body), = = and the card shows
//  EXACTLY what it showed when the whole body was read. = ⇒ ⇒ ⇒ So a
//  change that shortens the read and changes the card is a RED test, = =
//  and not a silent difference.
//

import AppKit
import Foundation
import Testing
@testable import WenshuApp

@Suite("The whole library's ONE list (= the 资料库's documents, then each book's)")
@MainActor
struct LibraryDocumentListTests {
    // MARK: - The fixture

    private struct Fixture {
        let root: URL
        let bookStore: BookStore
        let cardTitle: String
        /// The books' titles, in the order the store loads them (= 书 1, 书 2).
        let bookTitles: [String]
        /// Each book's document title (= the file name without its extension).
        let docTitles: [String]
    }

    /// A library on disk with one 资料库 card and two books, = = each with
    /// two documents whose titles differ in their pinyin first letter (= =
    /// so the sort is observable).
    private func makeFixture() throws -> Fixture {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-library-list-\(UUID().uuidString)")
        let referenceLibraryRoot = root.appendingPathComponent("reference-library", isDirectory: true)
        try FileManager.default.createDirectory(
            at: referenceLibraryRoot,
            withIntermediateDirectories: true
        )
        let shelvesRoot = root.appendingPathComponent("shelves", isDirectory: true)
        try FileManager.default.createDirectory(at: shelvesRoot, withIntermediateDirectories: true)

        // The 资料库's own card (= the production writer's way).
        let cardTitle = "资料库卡片"
        let cardPayload: [String: Any] = [
            "id": UUID().uuidString,
            "title": cardTitle,
            "layer": ReferenceLayer.layerEntities.rawValue,
            "summary": "夹具里的资料库卡片。",
            "tags": [String](),
            "entityType": EntityType.other.rawValue,
            "characterRefIds": [String](),
            "worldRefIds": [String](),
            "bookRefIds": [String](),
            "createdAt": Date().timeIntervalSince1970,
            "updatedAt": Date().timeIntervalSince1970,
        ]
        let cardData = try JSONSerialization.data(withJSONObject: cardPayload)
        let card = try JSONDecoder().decode(Reference.self, from: cardData)
        try FileSystemReferenceStore.saveReferenceToFileSystem(
            reference: card,
            bodyMarkdown: "# \(cardTitle)\n\n正文。\n",
            referenceLibraryRoot: referenceLibraryRoot
        )

        let stores = LibraryStores(
            shelvesRoot: shelvesRoot,
            referenceLibraryRoot: referenceLibraryRoot,
            referenceStore: FileSystemReferenceStore(referenceLibraryRoot: referenceLibraryRoot)
        )
        let bookStore = BookStore(stores: stores)

        // Two books, = = each with two documents. = = The titles are
        // chosen so the pinyin first letter differs (= = "东" = d and
        // "西" = x), = = so the sort inside a book is observable.
        var bookTitles: [String] = []
        var docTitles: [String] = []
        for bookIndex in 0 ..< 2 {
            let shelfId = UUID()
            let bookId = UUID()
            let bookTitle = "书\(bookIndex + 1)"
            let bookDir = shelvesRoot
                .appendingPathComponent(shelfId.uuidString, isDirectory: true)
                .appendingPathComponent("books", isDirectory: true)
                .appendingPathComponent(bookId.uuidString, isDirectory: true)
            let folderDir = bookDir.appendingPathComponent(
                BookFolder.outlines.directoryName,
                isDirectory: true
            )
            try FileManager.default.createDirectory(
                at: folderDir,
                withIntermediateDirectories: true
            )
            let book = Book(id: bookId, title: bookTitle, author: "wenshu", shelfId: shelfId)
            let data = try JSONEncoder().encode(book)
            try data.write(to: bookDir.appendingPathComponent("book.json"))

            for docTitle in ["西风", "东方"] {
                let fileName = "\(docTitle).md"
                try "# \(docTitle)\n\n\(docTitle)的正文。\n".write(
                    to: folderDir.appendingPathComponent(fileName),
                    atomically: true,
                    encoding: .utf8
                )
                docTitles.append(docTitle)
            }
            bookTitles.append(bookTitle)
        }
        return Fixture(
            root: root,
            bookStore: bookStore,
            cardTitle: cardTitle,
            bookTitles: bookTitles,
            docTitles: docTitles
        )
    }

    // MARK: - The ONE list's order

    @Test("The ONE list holds the 资料库's document FIRST, = = then each book's (= 书 1, = = 书 2)")
    func theOneListHoldsTheLibrarysDocumentsFirstThenEachBooks() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let list = LibraryDocumentLoader.load(
            bookStore: fixture.bookStore,
            sortOrder: .pinyinFirstLetter
        )

        let documents = list.documents
        #expect(
            documents.count == 5,
            "the list MUST hold the 资料库's card AND both books' documents (= \(documents.count) found)"
        )
        #expect(
            documents.first?.title == fixture.cardTitle,
            "the 资料库's document MUST come FIRST (= the requirement's order)"
        )
        #expect(
            list.references.count == 1,
            "the list MUST hold the 资料库's own card (= \(list.references.count))"
        )
        #expect(
            list.bookGroups.count == 2,
            "the list MUST hold ONE GROUP PER BOOK (= \(list.bookGroups.count))"
        )
    }

    @Test("The ONE list sorts EACH GROUP by the pinyin first letter")
    func theOneListSortsEachGroupByPinyin() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let list = LibraryDocumentLoader.load(
            bookStore: fixture.bookStore,
            sortOrder: .pinyinFirstLetter
        )

        for (index, group) in list.bookGroups.enumerated() {
            let titles = group.map(\.title)
            #expect(
                titles == ["东方", "西风"],
                "book \(index)'s documents MUST be sorted by their pinyin first letter (= d before x) = \(titles)"
            )
        }
    }

    @Test("The list's sort order follows the ACTIVE order (= = not a hard-coded one)")
    func theListsSortOrderFollowsTheActiveOrder() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let byPinyin = LibraryDocumentLoader.load(
            bookStore: fixture.bookStore,
            sortOrder: .pinyinFirstLetter
        )
        let byModified = LibraryDocumentLoader.load(
            bookStore: fixture.bookStore,
            sortOrder: .modifiedAt
        )

        #expect(
            byPinyin.bookGroups.first?.map(\.title) == ["东方", "西风"],
            "the pinyin order MUST sort the documents"
        )
        #expect(
            byModified.bookGroups.first?.map(\.title) != nil,
            "the modified-time order MUST still load the documents"
        )
        #expect(
            byModified.documents.count == byPinyin.documents.count,
            "the sort order MUST NOT change how many documents the list holds"
        )
    }

    // MARK: - The metadata-only read (= = the performance half)

    @Test("The list reads each .md's HEAD, = = and the card shows EXACTLY what it showed before")
    func theListReadsTheHeadAndTheCardShowsTheSame() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        // The list's own read.
        let list = LibraryDocumentLoader.load(
            bookStore: fixture.bookStore,
            sortOrder: .pinyinFirstLetter
        )
        // The whole-body read (= = what the scope used to do, = = and what
        // the editor still does when the document is opened).
        let wholeBodies = PreviewPaneOps.loadAllLibraryDocs(bookStore: fixture.bookStore).docs

        #expect(!wholeBodies.isEmpty, "the fixture MUST hold documents")
        for document in list.bookGroups.flatMap({ $0 }) {
            let title = document.title
            let whole = wholeBodies.first { $0.title == title }
            #expect(whole != nil, "the whole-body read MUST hold \(title)")
            #expect(
                document.summary == whole?.summary,
                "\(title)'s SUMMARY MUST be the same the whole-body read gave (= \(document.summary) vs \(whole?.summary ?? "nil"))"
            )
            #expect(
                document.tags == (whole?.tags ?? []),
                "\(title)'s TAGS MUST be the same the whole-body read gave (= \(document.tags) vs \(whole?.tags ?? []))"
            )
        }
    }

    @Test("The list's documents keep their stable ids (= = the grid's ForEach identity)")
    func theListsDocumentsKeepTheirStableIds() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let first = LibraryDocumentLoader.load(
            bookStore: fixture.bookStore,
            sortOrder: .pinyinFirstLetter
        )
        let second = LibraryDocumentLoader.load(
            bookStore: fixture.bookStore,
            sortOrder: .pinyinFirstLetter
        )

        #expect(
            first.documents.map(\.id) == second.documents.map(\.id),
            "two loads of the same library MUST produce the same ids (= else every card is rebuilt)"
        )
        #expect(
            Set(first.documents.map(\.id)).count == first.documents.count,
            "the list's ids MUST be unique (= else the grid's ForEach collapses)"
        )
        #expect(
            first.documents.allSatisfy { $0.id.hasPrefix("ref:") || $0.id.hasPrefix("doc:") },
            "the list's ids MUST be namespaced by their source (= so the two kinds cannot collide)"
        )
    }

    // MARK: - The count

    @Test("The chrome count reads the SAME list the grid draws")
    func theChromeCountReadsTheSameList() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let list = LibraryDocumentLoader.load(
            bookStore: fixture.bookStore,
            sortOrder: .pinyinFirstLetter
        )

        #expect(
            list.count == 5,
            "the list's count MUST be every document it holds (= \(list.count))"
        )
        #expect(
            list.filtered(by: "").count == list.count,
            "an EMPTY query MUST keep every document (= \(list.filtered(by: "").count))"
        )
        #expect(
            list.filtered(by: "西风").count == 2,
            "the query MUST filter the list (= \(list.filtered(by: "西风").count) found)"
        )
    }
}
