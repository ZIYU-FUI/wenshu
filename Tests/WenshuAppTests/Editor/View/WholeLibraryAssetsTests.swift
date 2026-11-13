//
//  WholeLibraryAssetsTests.swift · Wenshu
//
//  The whole 文枢库's documents (= the boss's rule: "同时素材栏显示整个
//  文枢库的所有文档").
//
//  ⇒ ⇒ ⇒ MEASURED (= the review on this diff): = dropping the books'
//  documents behind the drawn grid left the WHOLE repository green, =
//  so the rule could break with no suite saying so. = ⇒ ⇒ ⇒ So the
//  whole library's documents have ONE door (= `PreviewPaneOps
//  .loadAllLibraryDocs`), = and THIS suite drives THAT door.
//

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import WenshuApp

@Suite("The whole 文枢库's documents (= the assets pane holds every one of them)")
@MainActor
struct WholeLibraryAssetsTests {
    // MARK: - The fixture (= two shelves, two books, one document each)

    private struct Fixture {
        let root: URL
        let bookStore: BookStore
        let bookIds: [UUID]
        let docTitles: [String]
        /// The 资料库's own cards (= the library's OTHER kind of
        /// document, = and the one the grid draws above the books').
        let cardTitles: [String]
    }

    /// A library on disk with two books (= one per shelf) and one
    /// document in each.
    ///
    /// The layout is the one the app reads:
    /// `shelves/<shelf>/books/<book>/book.json` and
    /// `shelves/<shelf>/books/<book>/<folder>/*.md`.
    private func makeFixture() throws -> Fixture {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-whole-library-\(UUID().uuidString)")
        let referenceLibraryRoot = root.appendingPathComponent("reference-library", isDirectory: true)
        try FileManager.default.createDirectory(
            at: referenceLibraryRoot,
            withIntermediateDirectories: true
        )
        let shelvesRoot = root.appendingPathComponent("shelves", isDirectory: true)
        try FileManager.default.createDirectory(at: shelvesRoot, withIntermediateDirectories: true)

        // One REFERENCE CARD (= the 资料库's layer), = written by the
        // PRODUCTION writer (= the app's own way of putting a card on
        // disk), = so the fixture is a REALISTIC library (= the review's
        // own probe measured that a fixture without one makes the
        // chrome count's equality hold for the wrong reason, = and that
        // the pane then draws only ONE of the library's two grids).
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

        var bookIds: [UUID] = []
        var docTitles: [String] = []
        for index in 0 ..< 2 {
            let shelfId = UUID()
            let bookId = UUID()
            let title = "整库文档\(index)"
            let fileName = "\(title).md"
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
            let book = Book(id: bookId, title: title, author: "wenshu", shelfId: shelfId)
            let data = try JSONEncoder().encode(book)
            try data.write(to: bookDir.appendingPathComponent("book.json"))
            try "# \(title)\n\n第\(index)章的正文。\n".write(
                to: folderDir.appendingPathComponent(fileName),
                atomically: true,
                encoding: .utf8
            )
            bookIds.append(bookId)
            docTitles.append(title)
        }
        return Fixture(
            root: root,
            bookStore: bookStore,
            bookIds: bookIds,
            docTitles: docTitles,
            cardTitles: [cardTitle]
        )
    }

    // MARK: - The door

    @Test("The whole library's door holds EVERY book's documents")
    func theDoorHoldsEveryBooksDocuments() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let docs = PreviewPaneOps.loadAllLibraryDocs(bookStore: fixture.bookStore).docs

        #expect(
            docs.count == 2,
            "the whole library's door MUST hold BOTH books' documents (= \(docs.count) found)"
        )
        #expect(
            Set(docs.map(\.bookId)) == Set(fixture.bookIds),
            "the whole library's door MUST hold a document of EVERY book"
        )
        #expect(
            Set(docs.map(\.title)) == Set(fixture.docTitles),
            "the whole library's door MUST hold every document's own title"
        )
    }

    @Test("The chrome count is the door's documents PLUS the library's cards")
    func theChromeCountIsTheDoorsDocumentsPlusTheLibrarysCards() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let docs = PreviewPaneOps.loadAllLibraryDocs(bookStore: fixture.bookStore).docs
        let cards = PreviewPaneOps.loadAllEntities(bookStore: fixture.bookStore).entities
            .filter { $0.layer == .layerEntities }
        let count = PreviewPaneOps.countCardsInScope(
            scope: .allLibraryScope,
            bookStore: fixture.bookStore,
            searchQuery: ""
        )

        // ⇒ ⇒ ⇒ THE FIXTURE MUST BE A REALISTIC LIBRARY: = the whole
        // library's chrome counts BOTH kinds (= the 资料库's cards AND
        // every book's documents). = ⇒ ⇒ ⇒ MEASURED (= the review on
        // this diff): = over a fixture with NO cards, = the count
        // happened to EQUAL the door's answer, = so the equality was
        // true for the wrong reason (= the empty side of the sum).
        #expect(
            cards.count == 1,
            "the fixture MUST hold a library card (= else the count's equality is vacuous)"
        )
        #expect(docs.count == 2, "the fixture MUST hold two books' documents")

        #expect(
            count == docs.count + cards.count,
            "the chrome count MUST be the door's documents PLUS the library's cards (= \(count) vs \(docs.count + cards.count))"
        )
        #expect(
            count == 3,
            "the chrome count of the whole library MUST count every card AND every document (= \(count))"
        )
    }

    // MARK: - The drawn pane

    @Test("The drawn pane SHOWS the whole library (= both kinds of card, = not a shell)")
    func theDrawnPaneShowsTheLibrarysDocuments() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        // The documents the door holds (= the grid must have something
        // to draw, = so the pane cannot be showing its empty state).
        let docs = PreviewPaneOps.loadAllLibraryDocs(bookStore: fixture.bookStore).docs
        #expect(!docs.isEmpty, "the fixture MUST hold documents (= the test would prove nothing)")

        let (host, window) = try hostPane(bookStore: fixture.bookStore)
        defer { window.orderOut(nil) }

        // ⇒ ⇒ ⇒ AND THE OBSERVABLE IS THE NUMBER OF GRIDS, = and the
        // COUNT is what makes it a count: = the whole library's pane
        // draws TWO grids (= the 资料库's cards, = and the 书房's .md
        // documents), = and each is a scroll area. = ⇒ ⇒ ⇒ MEASURED (=
        // the review's own probe on this diff): = asking only "does a
        // scroll area exist" = stayed GREEN under two mutations that
        // emptied one of the two grids (= the 资料库's cards dropped, =
        // and the grid drawing no card at all), = while the library's
        // half was gone. = ⇒ ⇒ ⇒ So the guard asks for BOTH.
        //
        // ⇒ ⇒ ⇒ AND THE TEXT IS NOT THE OBSERVABLE: = a hosted grid
        // publishes no cell's title here (= MEASURED), = so the grid
        // COUNT is what the tree can actually see.
        let elements = InspectorAXTree.elements(of: host)
        let grids = elements.filter { $0.role == "AXScrollArea" }
        #expect(
            grids.count == 2,
            "the whole-library pane MUST draw BOTH grids (= the 资料库's cards + the 书房's .md docs) = measured \(grids.count)"
        )
    }

    /// The REAL pane, hosted over the production store.
    ///
    /// ⇒ ⇒ ⇒ AND THE WINDOW SITS FAR OFFSCREEN: = the hosted pane must
    /// reach the screen's AppKit context (= or the grid never resolves
    /// its own size), = and it must never show on the writer's desktop.
    private func hostPane(bookStore: BookStore) throws -> (NSHostingView<AnyView>, NSWindow) {
        let pane = PreviewPane(
            scope: .allLibraryScope,
            onDoubleClick: { _ in },
            previewSortOrder: .constant(.modifiedAt),
            searchQuery: .constant(nil),
            activeTag: .constant(nil)
        )
        .environment(bookStore)

        // ⇒ ⇒ ⇒ AND THE WINDOW IS TALL: = a hosted grid materialises
        // only the cells it can show, = so a short window would leave
        // the second grid (= the books' documents) unmade, = and its
        // titles would never be published (= and the guard would be
        // measuring the window, = not the pane).
        let host = NSHostingView(rootView: AnyView(pane.frame(width: 1200, height: 1800)))
        host.frame = NSRect(x: 0, y: 0, width: 1200, height: 1800)
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.setFrameOrigin(NSPoint(x: -20000, y: -20000))
        window.contentView = host
        window.orderFront(nil)
        for _ in 0 ..< 40 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        host.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        return (host, window)
    }
}
