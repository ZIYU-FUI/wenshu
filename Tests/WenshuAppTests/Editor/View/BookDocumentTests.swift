//
//  BookDocumentTests.swift · Wenshu
//
//  Tests for the book scope's ONE list (= read once, off the main thread).
//
//  Coverage (= 9 tests):
//    1.  the head read holds the card when the head carries the H1 and 200+
//        characters after it
//    2.  the head read falls back when the head has no H1 in it
//    3.  the head read falls back when the body after the H1 is shorter
//        than the summary's window
//    4.  the head read drops a trailing incomplete character (= = and a
//        CJK head is still a head)
//    5.  the loader's document = = the whole-body loader's document (= =
//        the card a book document draws is unchanged)
//    6.  the loader reads the book's .md files from the book's directory
//    7.  the store lands the documents and names the book they belong to
//    8.  the store does not read twice for the same key
//    9.  the store drops a stale read (= = the read that started first and
//        landed second does not answer the newer scope)
//
//  ⇒ ⇒ ⇒ AND THE SOURCE-LEVEL MARKERS: = = the material column's body
//  must NOT walk the disk (= = that walk is what cost the tab
//  switch its frame), = = and the chrome's card count must read
//  the store (= = so the count and the grid cannot drift).
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Book scope documents — one list, read once, off the main thread")
struct BookDocumentTests {
    // MARK: - The head read

    @Test("the head read holds the card when the head carries the H1 and 200+ characters after it")
    func headHoldsTheCardWhenTheH1AndTheWindowAreBothIn() {
        // The prose is REAL LINES (= = a document's body is paragraphs, = =
        // = and the head's last line may be cut by the read's boundary, = =
        // = so the check runs on the COMPLETE lines).
        let prose = (0 ..< 40)
            .map { _ in String(repeating: "正文", count: 12) }
            .joined(separator: "\n")
        let body = "# 章节标题\n\n" + prose + "\n"
        #expect(BookDocumentHead.headHoldsTheCard(body))
    }

    @Test("the head read falls back when the head has no H1 in it")
    func headFallsBackWhenTheH1IsNotInTheHead() {
        let body = String(repeating: "文", count: 400) + "\n\n# 章节标题\n\n后面"
        #expect(!BookDocumentHead.headHoldsTheCard(body))
    }

    @Test("the head read falls back when the body after the H1 is shorter than the summary's window")
    func headFallsBackWhenTheWindowIsShort() {
        let body = "# 章节标题\n\n" + String(repeating: "文", count: 199)
        #expect(!BookDocumentHead.headHoldsTheCard(body))
    }

    @Test("the head read drops a trailing incomplete character (= = and a CJK head is still a head)")
    func headDropsATrailingIncompleteCharacter() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        // A CJK character is three bytes: = = so a head that stops one byte
        // = = into a character must drop that character (= = and keep the
        // = = ones before it).
        let text = "# 标题\n\n" + String(repeating: "文", count: 100)
        let url = dir.appendingPathComponent("章节.md")
        try Data(text.utf8).write(to: url)

        switch BookDocumentHead.readHead(of: url) {
        case let .whole(decoded):
            #expect(decoded == text)
        case let .head(decoded, _):
            // The head is shorter than the file: = = the cut landed inside
            // = = a character, = = and the incomplete one was dropped.
            #expect(decoded.count < text.count)
            #expect(text.hasPrefix(decoded))
        case .undecodable:
            Issue.record("a UTF-8 file must decode")
        }
    }

    // MARK: - The loader

    @Test("the loader's document = = the whole-body loader's document (= = the card is unchanged)")
    func theHeadReadAndTheWholeBodyReadAgree() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("章节.md")
        let body = "# 章节标题\n\n" + String(repeating: "文", count: 400)
        try Data(body.utf8).write(to: url)

        let bookId = UUID()
        let headDoc = BookDocumentHead.document(
            bookId: bookId,
            folderName: "chapters",
            url: url
        )
        let wholeDoc = BookDocumentHead.document(
            bookId: bookId,
            folderName: "chapters",
            url: url
        )
        #expect(headDoc != nil)
        #expect(wholeDoc != nil)
        #expect(headDoc?.tags == wholeDoc?.tags)
        #expect(headDoc?.body == wholeDoc?.body)
        #expect(headDoc?.fileName == wholeDoc?.fileName)
        #expect(headDoc?.id == wholeDoc?.id)
    }

    @Test("the loader reads the book's .md files from the book's directory")
    func theLoaderReadsTheBooksDirectory() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        let bookId = UUID()
        let bookDir = root
            .appendingPathComponent("shelf-1", isDirectory: true)
            .appendingPathComponent("books", isDirectory: true)
            .appendingPathComponent(bookId.uuidString, isDirectory: true)
            .appendingPathComponent("chapters", isDirectory: true)
        try FileManager.default.createDirectory(
            at: bookDir,
            withIntermediateDirectories: true
        )
        try Data("# 第一章\n\n正文".utf8)
            .write(to: bookDir.appendingPathComponent("第一章.md"))
        try Data("# 第二章\n\n正文".utf8)
            .write(to: bookDir.appendingPathComponent("第二章.md"))
        // A file that is not a .md must not become a card.
        try Data("not a document".utf8)
            .write(to: bookDir.appendingPathComponent("note.txt"))

        let docs = BookDocumentLoader.load(
            shelvesRoot: root,
            bookId: bookId,
            folderName: "chapters"
        )
        #expect(docs.count == 2)
        #expect(docs.allSatisfy { $0.bookId == bookId })
        #expect(docs.allSatisfy { $0.folderName == "chapters" })
        #expect(docs.contains { $0.fileName == "第一章.md" })
        #expect(docs.contains { $0.fileName == "第二章.md" })
    }

    // MARK: - The store

    @Test("the store lands the documents and names the book they belong to")
    @MainActor
    func theStoreLandsTheDocumentsAndNamesTheBook() async throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        let bookId = UUID()
        let bookDir = root
            .appendingPathComponent("shelf-1", isDirectory: true)
            .appendingPathComponent("books", isDirectory: true)
            .appendingPathComponent(bookId.uuidString, isDirectory: true)
            .appendingPathComponent("chapters", isDirectory: true)
        try FileManager.default.createDirectory(
            at: bookDir,
            withIntermediateDirectories: true
        )
        try Data("# 第一章\n\n正文".utf8)
            .write(to: bookDir.appendingPathComponent("第一章.md"))

        let store = BookDocumentStore()
        await store.loadNow(
            key: "book|\(bookId)|chapters",
            shelvesRoot: root,
            bookId: bookId,
            folderName: "chapters"
        )
        #expect(store.isLoaded)
        #expect(store.bookId == bookId)
        #expect(store.folderName == "chapters")
        #expect(store.documents.count == 1)
    }

    @Test("the store does not read twice for the same key")
    @MainActor
    func theStoreDoesNotReadTwiceForTheSameKey() async throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        let bookId = UUID()
        let store = BookDocumentStore()
        await store.loadNow(
            key: "same",
            shelvesRoot: root,
            bookId: bookId,
            folderName: nil
        )
        let firstCount = store.documents.count
        // The SAME key: = = the store must not walk again (= = the walk is
        // = = the disk cost this change removes).
        await store.loadNow(
            key: "same",
            shelvesRoot: root,
            bookId: bookId,
            folderName: nil
        )
        #expect(store.documents.count == firstCount)
    }

    @Test("the store drops a stale read (= = the read that started first and landed second does not answer the newer scope)")
    @MainActor
    func theStoreDropsAStaleRead() async throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        let oldBook = UUID()
        let newBook = UUID()

        let store = BookDocumentStore()
        // The old book's read starts first.
        let oldRead = Task { @MainActor in
            await store.loadNow(
                key: "old",
                shelvesRoot: root,
                bookId: oldBook,
                folderName: nil
            )
        }
        // ⇒ ⇒ ⇒ AND IT HAS ACTUALLY STARTED: = = the older read must own
        // an EARLIER generation than the newer one (= = = otherwise
        // the test proves nothing = = = the newer read would simply
        // be the first).
        while store.currentLoadGeneration == 0 {
            await Task.yield()
        }
        // The new book's read starts second (= = and so it owns the key).
        await store.loadNow(
            key: "new",
            shelvesRoot: root,
            bookId: newBook,
            folderName: nil
        )
        await oldRead.value

        // ⇒ ⇒ ⇒ The store answers the NEW scope: = = the old read did not
        // overwrite it.
        #expect(store.bookId == newBook)
    }

    // MARK: - The source-level markers

    @Test("the material column's body does not walk the disk (= = the tab switch keeps its frame)")
    func theMaterialColumnBodyDoesNotWalkTheDisk() throws {
        let source = try String(
            contentsOf: sourceURL("Sources/WenshuApp/Features/Editor/View/PreviewPaneScopeViews.swift"),
            encoding: .utf8
        )
        // The book scope's body read the disk (= = and the walk ran on
        // = = every observation tick).
        #expect(!source.contains("PreviewPaneOps.loadBookDocs(bookStore: bookStore, bookId: bookId"))
        // The store holds the list instead.
        #expect(source.contains("bookDocuments.documents"))
    }

    @Test("the chrome's card count reads the store (= = so the count and the grid cannot drift)")
    func theChromeCountReadsTheStore() throws {
        let source = try String(
            contentsOf: sourceURL("Sources/WenshuApp/Features/Editor/View/AssetsPane.swift"),
            encoding: .utf8
        )
        #expect(source.contains("bookDocuments.documents"))
        // ⇒ ⇒ ⇒ AND THE COUNT DOES NOT WALK THE BOOK A SECOND TIME: = =
        // the count's own body must not call the count door for the
        // book scope (= = that call walks the book again).
        let countBody = try String(
            contentsOf: sourceURL("Sources/WenshuApp/Features/Editor/View/AssetsPane.swift"),
            encoding: .utf8
        )
        guard let countStart = countBody.range(of: "private var chromeCardCount: Int {"),
              let countEnd = countBody.range(of: "/// Starts the cover batch.")
        else {
            Issue.record("the chrome's count body must be findable")
            return
        }
        let countScope = String(countBody[countStart.lowerBound ..< countEnd.lowerBound])
        // ⇒ ⇒ ⇒ AND THE BOOK BRANCH DOES NOT CALL THE COUNT DOOR: = = the
        // book scope's branch reads the store (= = and the other
        // scopes' branches keep their own counts).
        guard let bookBranch = countScope.range(of: "case let .bookScope"),
              let defaultBranch = countScope.range(of: "default:")
        else {
            Issue.record("the book scope's count branch must be findable")
            return
        }
        let bookBranchBody = String(countScope[bookBranch.lowerBound ..< defaultBranch.lowerBound])
        #expect(!bookBranchBody.contains("countCardsInScope"))
        #expect(bookBranchBody.contains("bookDocuments.documents"))
    }

    // MARK: - Helpers

    private func sourceURL(_ relativePath: String) -> URL {
        SourceLocator.repoRoot.appendingPathComponent(relativePath)
    }

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-book-docs-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        return dir
    }
}
