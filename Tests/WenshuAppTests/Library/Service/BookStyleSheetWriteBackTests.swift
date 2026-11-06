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

        _ = BookStyleSheetWriteBack.apply(
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

        _ = BookStyleSheetWriteBack.apply(
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

        _ = BookStyleSheetWriteBack.apply(
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

        _ = BookStyleSheetWriteBack.apply(
            knob: .lineSpacing,
            position: BookLineSpacing.tight.rawValue,
            to: book.id,
            store: store
        )

        let inStore = store.books.first(where: { $0.id == book.id })
        XCTAssertEqual(inStore?.effectiveStyleSheet.lineSpacing, .tight)
    }

    /// A book the store does not carry changes nothing (= no crash, =
    /// no file).
    func testABookTheStoreDoesNotCarryChangesNothing() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let result = BookStyleSheetWriteBack.apply(
            knob: .bodySize,
            position: BookBodySize.small.rawValue,
            to: UUID(),
            store: store
        )
        XCTAssertNil(result)
    }
}
