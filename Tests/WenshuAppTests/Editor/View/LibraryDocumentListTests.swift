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

    @Test("A CJK document longer than the head, = = whose cut lands inside a character, = = is STILL a head read")
    func theHeadKeepsItsCompleteCharactersWhenTheCutLandsInsideOne() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        // A CJK document whose byte 8192 lands INSIDE a character (= = the
        // common case for a Chinese book, = = because a UTF-8 character is
        // three bytes and the head's count is not a multiple of three).
        //
        // = = ⇒ The head read MUST keep its complete characters (= = it
        // MUST NOT discard the whole read, = = which would make the head
        // read a whole-body read for every CJK document).
        let bookId = UUID()
        let shelfId = UUID()
        let folderDir = fixture.bookStore.stores.shelvesRoot
            .appendingPathComponent(shelfId.uuidString, isDirectory: true)
            .appendingPathComponent("books", isDirectory: true)
            .appendingPathComponent(bookId.uuidString, isDirectory: true)
            .appendingPathComponent(BookFolder.outlines.directoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: folderDir, withIntermediateDirectories: true)
        let book = Book(id: bookId, title: "长文书", author: "wenshu", shelfId: shelfId)
        try JSONEncoder().encode(book).write(to: folderDir.deletingLastPathComponent().appendingPathComponent("book.json"))

        let body = String(repeating: "文枢的正文内容。", count: 1200)
        let text = "# 长文第一章\n\n\(body)\n"
        let fileName = "长文第一章.md"
        let url = folderDir.appendingPathComponent(fileName)
        try text.write(to: url, atomically: true, encoding: .utf8)
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        #expect(size > 8192, "the fixture's document MUST be longer than the head (= \(size) bytes)")

        // The head read itself (= = the card's content is the same whether
        // the read works or falls back, = = so only the read's own result
        // can tell the two apart).
        switch LibraryDocumentLoader.readHead(of: url) {
        case .undecodable:
            Issue.record("the head read MUST NOT be discarded (= = the cut landed inside a CJK character, = = and the read threw the whole block away)")
        case let .head(head, _):
            #expect(
                head.utf8.count <= 8192,
                "the head MUST hold no more than the head's byte count (= \(head.utf8.count))"
            )
            #expect(
                head.utf8.count > 8000,
                "the head MUST hold its complete characters (= \(head.utf8.count) bytes = = a discarded read would hold 0)"
            )
        case let .whole(whole):
            Issue.record("a document longer than the head MUST NOT be read whole (= \(whole.utf8.count) bytes)")
        }

        // And the card still shows what the whole-body read shows.
        let list = LibraryDocumentLoader.load(
            bookStore: fixture.bookStore,
            sortOrder: .pinyinFirstLetter
        )
        let document = list.documents.first { $0.title == "长文第一章" }
        #expect(document != nil, "the list MUST hold the long document")
        #expect(
            document?.tags == ["长文第一章"],
            "the long document's CHIP TAG MUST be its first H1 (= \(document?.tags ?? []))"
        )
        let wholeSummary = String(body.prefix(200))
        #expect(
            document?.summary == wholeSummary,
            "the long document's SUMMARY MUST be the whole-body read's summary (= \(document.map { $0.summary.count } ?? -1) characters vs \(wholeSummary.count))"
        )
    }

    @Test("A chapter whose H1 line ends near the head's boundary, = = shows the whole-body read's card")
    func aChapterWhoseH1EndsNearTheBoundaryShowsTheWholeBodyReadsCard() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        // The review's shape: = = a chapter whose H1 LINE ends near the
        // head's boundary (= = 8192 bytes), = = with a body after it.
        //
        // = = ⇒ The head does NOT hold the H1 line complete (= = and the
        // summary's window is not in the head either), = = so the whole
        // file is read (= = and the card shows exactly what the
        // whole-body read showed).
        let bookId = UUID()
        let shelfId = UUID()
        let folderDir = fixture.bookStore.stores.shelvesRoot
            .appendingPathComponent(shelfId.uuidString, isDirectory: true)
            .appendingPathComponent("books", isDirectory: true)
            .appendingPathComponent(bookId.uuidString, isDirectory: true)
            .appendingPathComponent(BookFolder.outlines.directoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: folderDir, withIntermediateDirectories: true)
        let book = Book(id: bookId, title: "边界书", author: "wenshu", shelfId: shelfId)
        try JSONEncoder().encode(book).write(to: folderDir.deletingLastPathComponent().appendingPathComponent("book.json"))

        // The H1 line runs to the head's boundary (= = 8100 ASCII
        // characters = = 8102 bytes with the "# "), = = and the body
        // follows it.
        //
        // = = ⇒ THE BODY IS ASCII ON PURPOSE: = = a CJK body would make
        // the head's cut land INSIDE a character, = = and the pre-fix
        // read discarded the whole head for that reason (= = so the test
        // would pass on the broken code for the wrong reason). = = With
        // an ASCII body the head decodes, = = so the pre-fix read takes
        // the "the head holds an H1" path and gives a TRUNCATED summary.
        let longTitle = String(repeating: "T", count: 8100)
        let body = String(repeating: "the body of the chapter. ", count: 40)
        let text = "# \(longTitle)\n\n\(body)\n"
        let fileName = "边界章.md"
        let url = folderDir.appendingPathComponent(fileName)
        try text.write(to: url, atomically: true, encoding: .utf8)
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        #expect(size > 8192, "the fixture's chapter MUST be longer than the head (= \(size) bytes)")

        // The head read itself: = = it MUST NOT claim to hold the card.
        if case let .head(_, holdsTheCard) = LibraryDocumentLoader.readHead(of: url) {
            #expect(
                !holdsTheCard,
                "the head MUST NOT claim to hold the card (= = its H1 line is cut by the boundary)"
            )
        }

        // And the card shows what the whole-body read shows.
        let list = LibraryDocumentLoader.load(
            bookStore: fixture.bookStore,
            sortOrder: .pinyinFirstLetter
        )
        let document = list.documents.first { $0.title == "边界章" }
        #expect(document != nil, "the list MUST hold the boundary chapter")
        let wholeBodies = PreviewPaneOps.loadAllLibraryDocs(bookStore: fixture.bookStore).docs
        let whole = wholeBodies.first { $0.title == "边界章" }
        #expect(whole != nil, "the whole-body read MUST hold the boundary chapter")
        #expect(
            document?.tags == whole?.tags,
            "the boundary chapter's CHIP TAG MUST be the whole-body read's (= \(document?.tags ?? []) vs \(whole?.tags ?? []))"
        )
        #expect(
            document?.summary == whole?.summary,
            "the boundary chapter's SUMMARY MUST be the whole-body read's (= \(document.map { $0.summary.count } ?? -1) characters vs \(whole.map { $0.summary.count } ?? -1))"
        )
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
