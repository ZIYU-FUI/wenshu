//
//  BookStyleSheetWriteBackTests.swift · Wenshu
//
//  The knob moved, and the book ON DISK carries it.
//
//  The write-back is measured through the PRODUCTION seam (= the app's
//  own save path for an existing book, = `BookStore.sidebarSaveBook`,
//  = which writes `book.json`), = and the file's bytes are read back.
//  = So a change that stops writing the sheet down turns THIS red,
//  = and not only a test of the sheet's own value.
//
//  The mutations these hold against (= the ones that would break the
//  write-back) are named per case.
//

import Foundation
@testable import WenshuApp
import XCTest

@MainActor
final class BookStyleSheetWriteBackTests: XCTestCase {
    /// A real library root, = and a store on it.
    private func makeStore() throws -> (BookStore, URL) {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wenshu-sheet-writeback-\(UUID().uuidString)", isDirectory: true)
        let shelvesRoot = root.appendingPathComponent("shelves", isDirectory: true)
        let referenceLibraryRoot = root.appendingPathComponent("reference-library", isDirectory: true)
        try FileManager.default.createDirectory(at: shelvesRoot, withIntermediateDirectories: true)
        let stores = LibraryStores(
            shelvesRoot: shelvesRoot,
            referenceLibraryRoot: referenceLibraryRoot,
            referenceStore: FileSystemReferenceStore(referenceLibraryRoot: referenceLibraryRoot)
        )
        return (BookStore(stores: stores), root)
    }

    /// A book on disk, = with its own `book.json`.
    private func makeBook(in store: BookStore) throws -> Book {
        let shelfID = UUID()
        let book = Book(
            title: "A book",
            author: "wenshu",
            icon: "book",
            shelfId: shelfID
        )
        try store.sidebarSaveBook(book)
        store.books.append(book)
        store.books.sort { $0.createdAt < $1.createdAt }
        return book
    }

    /// The book's `book.json`, = read back from disk.
    private func readBookJSON(in store: BookStore, _ book: Book) throws -> Data {
        let path = store.stores.shelvesRoot
            .appendingPathComponent(book.shelfId.uuidString, isDirectory: true)
            .appendingPathComponent("books", isDirectory: true)
            .appendingPathComponent(book.id.uuidString, isDirectory: true)
            .appendingPathComponent("book.json")
        return try Data(contentsOf: path)
    }

    /// The knob lands IN THE FILE, = and the file reads back as the
    /// sheet that was written.
    ///
    /// MUTATION: = not saving the book (= or saving it before the
    /// sheet is set) = leaves the file without the knob.
    func testTheKnobLandsInTheBooksOwnFile() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let book = try makeBook(in: store)

        _ = try BookStyleSheetWriteBack.apply(
            knob: .bodySize,
            position: BookBodySize.large.rawValue,
            to: book.id,
            store: store
        )

        let data = try readBookJSON(in: store, book)
        let written = try JSONDecoder().decode(Book.self, from: data)
        XCTAssertEqual(written.styleSheet?.bodySize, .large)
        // The whole sheet is written, = not just the knob: = the other
        // knobs keep their own positions.
        XCTAssertEqual(written.effectiveStyleSheet.lineSpacing, .standard)
        XCTAssertEqual(written.effectiveStyleSheet.bodyFamily, .songti)
    }

    /// A book with NO sheet reads the print baseline, = and the knob
    /// moves THAT (= so the file carries a whole sheet, = not a patch).
    func testABookWithNoSheetWritesTheWholeBaseline() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let book = try makeBook(in: store)
        XCTAssertNil(book.styleSheet, "the book starts with no sheet of its own")

        _ = try BookStyleSheetWriteBack.apply(
            knob: .bodyFamily,
            position: BookBodyFamily.kai.rawValue,
            to: book.id,
            store: store
        )

        let data = try readBookJSON(in: store, book)
        let written = try JSONDecoder().decode(Book.self, from: data)
        XCTAssertEqual(written.effectiveStyleSheet.bodyFamily, .kai)
        XCTAssertEqual(written.effectiveStyleSheet.bodySize, .medium)
        XCTAssertEqual(written.effectiveStyleSheet.headingLadder, .printStandard)
    }

    /// A knob already at that position changes nothing, = so the file
    /// is not rewritten with a different value.
    ///
    /// MUTATION: = writing a free value (= not a position) = would
    /// put a number in the file, = and the sheet could not read it
    /// back.
    func testAnUnknownPositionChangesNothing() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let book = try makeBook(in: store)

        _ = try BookStyleSheetWriteBack.apply(
            knob: .bodySize,
            position: "enormous",
            to: book.id,
            store: store
        )

        let data = try readBookJSON(in: store, book)
        let written = try JSONDecoder().decode(Book.self, from: data)
        XCTAssertNil(written.styleSheet, "an unreadable position writes nothing")
    }

    /// The store's own array is in step with the file, = so the page
    /// reads back what it wrote.
    func testTheStoresOwnArrayIsInStep() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let book = try makeBook(in: store)

        _ = try BookStyleSheetWriteBack.apply(
            knob: .lineSpacing,
            position: BookLineSpacing.tight.rawValue,
            to: book.id,
            store: store
        )

        let inStore = store.books.first(where: { $0.id == book.id })
        XCTAssertEqual(inStore?.effectiveStyleSheet.lineSpacing, .tight)
    }

    /// A BOOK THE STORE DOES NOT CARRY CHANGES NOTHING.
    ///
    /// Without the guard, `apply` on an unknown book id would write the
    /// sheet onto `books[0]` = = the WRONG book. = So the case is
    /// named, = and it is the card's own named scenario.
    func testABookTheStoreDoesNotCarryChangesNothing() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let book = try makeBook(in: store)

        let result = try BookStyleSheetWriteBack.apply(
            knob: .bodySize,
            position: BookBodySize.small.rawValue,
            to: UUID(),
            store: store
        )

        XCTAssertNil(result, "a book the store does not carry changes nothing")
        // And the book that IS in the store is untouched.
        let data = try readBookJSON(in: store, book)
        let written = try JSONDecoder().decode(Book.self, from: data)
        XCTAssertNil(written.styleSheet, "no other book is written to")
    }

    /// THE PAGE'S OWN MODEL OUTPUT MUST MOVE THE SHEET.
    ///
    /// This is the seam the page and the write-back share: = the model
    /// the page renders (= `InspectorStylePageModel(sheet:)`) produces
    /// the positions the menu shows, = and the menu hands the chosen
    /// one to the write-back. = So the test drives THE PAGE'S OWN
    /// MODEL into the write-back, = and reads the file back.
    ///
    /// WHY IT IS WRITTEN THIS WAY: = the write-back reads a position
    /// by its RAW value (= the sheet's own enum's name), = and a model
    /// that carried only the localized label could never move the
    /// sheet (= every write was a no-op, = and the service's own tests
    /// passed because they handed it raw values). = So the test hands
    /// it exactly what the page hands it.
    func testThePagesOwnModelOutputMovesTheSheet() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let book = try makeBook(in: store)

        // The page's own model (= the one the view renders).
        let model = InspectorStylePageModel(sheet: book.effectiveStyleSheet)
        let bodySize = try XCTUnwrap(
            model.knobs.first { $0.id == BookStyleKnob.bodySize.rawValue }
        )
        // The position the menu would hand the write-back.
        let large = try XCTUnwrap(
            bodySize.positions.first { $0.rawValue == BookBodySize.large.rawValue }
        )

        try BookStyleSheetWriteBack.apply(
            knob: .bodySize,
            position: large.rawValue,
            to: book.id,
            store: store
        )

        let data = try readBookJSON(in: store, book)
        let written = try JSONDecoder().decode(Book.self, from: data)
        XCTAssertEqual(written.styleSheet?.bodySize, .large)
    }

    /// EVERY position the page's model offers must be one the sheet
    /// can read back.
    ///
    /// MUTATION: = a model that localizes the position (= the display
    /// name instead of the raw value) = would make every knob a no-op.
    func testEveryPositionThePageOffersIsReadableByTheSheet() {
        let model = InspectorStylePageModel(sheet: .default)
        var unreadable: [String] = []
        for knob in model.knobs {
            for position in knob.positions {
                let readable: Bool
                switch BookStyleKnob(rawValue: knob.id) {
                case .bodySize: readable = BookBodySize(rawValue: position.rawValue) != nil
                case .lineSpacing: readable = BookLineSpacing(rawValue: position.rawValue) != nil
                case .firstLineIndent: readable = BookFirstLineIndent(rawValue: position.rawValue) != nil
                case .segmentSpacing: readable = BookSegmentSpacing(rawValue: position.rawValue) != nil
                case .bodyFamily: readable = BookBodyFamily(rawValue: position.rawValue) != nil
                case nil: readable = false
                }
                if !readable {
                    unreadable.append("\(knob.id).\(position.rawValue)")
                }
            }
        }
        XCTAssertTrue(
            unreadable.isEmpty,
            "the sheet cannot read these positions: \(unreadable)"
        )
    }

    /// THE SIDEBAR'S SELECTION WRITES THE STORE'S SELECTED BOOK.
    ///
    /// The sheet is keyed by book id, = and the store's selected book
    /// is the app's one record of WHICH BOOK IS ACTIVE. = It had no
    /// writer in production (= the field stayed nil, = and every
    /// reader fell back to the print baseline), = so the sidebar's
    /// selection writes it.
    ///
    /// This is the repo's own source-check idiom (= the same check the
    /// reviewer made), = because the write lives in a SwiftUI view
    /// whose environment cannot be driven from a test.
    func testTheSidebarWritesTheStoresSelectedBook() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Service
            .deletingLastPathComponent() // Library
            .deletingLastPathComponent() // WenshuAppTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // the worktree's root
        let code = try String(
            contentsOf: root.appendingPathComponent(
                "Sources/WenshuApp/Features/Library/View/AppleSidebarSelection.swift"
            ),
            encoding: .utf8
        )
        XCTAssertTrue(
            code.contains("bookStore.selectedBookId ="),
            "nothing writes the store's selected book (= the sheet's book), = so every reader falls back to the print baseline"
        )
    }

    /// A WHOLE SET is written down in one action, = and the file on
    /// disk carries it.
    ///
    /// MUTATION: = writing the set knob by knob (= and not the whole
    /// sheet) = would leave the book half written.
    func testTheGeneralSetLandsInTheBooksOwnFile() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let book = try makeBook(in: store)

        // = the book has fine-tuned a knob, = so the set has to put it
        // back (= the set is a WHOLE sheet).
        _ = try BookStyleSheetWriteBack.apply(
            knob: .bodySize,
            position: BookBodySize.large.rawValue,
            to: book.id,
            store: store
        )

        _ = try BookStyleSheetWriteBack.apply(
            preset: .general,
            to: book.id,
            store: store
        )

        let data = try readBookJSON(in: store, book)
        let written = try JSONDecoder().decode(Book.self, from: data)
        // = the headings wear the body's own face, = and the rest of the
        // sheet is the print baseline's own positions, = including the
        // knob the book had fine-tuned.
        XCTAssertEqual(written.styleSheet?.headingFamily, .songti)
        XCTAssertEqual(written.effectiveStyleSheet.lineSpacing, .standard)
        XCTAssertEqual(written.effectiveStyleSheet.bodySize, .medium)
        XCTAssertEqual(written.effectiveStyleSheet.headingLadder, .printStandard)
    }

    /// THE WRITE-BACK LETS THE SAVE'S FAILURE THROUGH.
    ///
    /// = The source-text guard (= "the file carries no `catch`") =
    /// holds a SPELLING, = not the harm: = `_ = Result { try
    /// store.sidebarSaveBook(book) }` carries no `catch` anywhere, =
    /// still carries `try store.sidebarSaveBook(book)` verbatim, = and
    /// still carries no `try?` = = so all three source assertions
    /// hold, = while the failure IS swallowed (= `Result` swallows it,
    /// = and `apply` returns the book as if it were written).
    ///
    /// = So this case holds the harm at the BEHAVIOUR level: = the save
    /// is made to FAIL, = and the failure must ESCAPE `apply`. = A
    /// book that did not reach the disk must not be reported as
    /// written.
    ///
    /// MUTATION: = `_ = Result { try store.sidebarSaveBook(book) }` =
    /// the failure is swallowed, = so `apply` returns the book (= and
    /// this case fails).
    func testTheWriteBackLetsTheSaveFailureThrough() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let book = try makeBook(in: store)

        // = Make the save FAIL: = the book's own directory is replaced
        // by a FILE, = so the store's `createDirectory` cannot make
        // the directory it writes into, = and the save throws.
        let bookDir = store.stores.shelvesRoot
            .appendingPathComponent(book.shelfId.uuidString, isDirectory: true)
            .appendingPathComponent("books", isDirectory: true)
            .appendingPathComponent(book.id.uuidString, isDirectory: true)
        try FileManager.default.removeItem(at: bookDir)
        try Data("not a directory".utf8).write(to: bookDir)

        // = The failure must ESCAPE: = a write that could not reach
        // the disk is not a write, = and a caller that cannot see the
        // failure would report success for a book that did not change.
        XCTAssertThrowsError(
            try BookStyleSheetWriteBack.apply(
                knob: .bodySize,
                position: BookBodySize.large.rawValue,
                to: book.id,
                store: store
            ),
            "the write-back must let the save's failure through (= a swallowed failure reports a book written that never reached the disk)"
        )
    }
}
