//
//  LibraryBookFolderLayoutTests.swift · Wenshu
//
//  The per-book folder layout is written in three places (the
//  bootstrapper that repairs an existing book, the migrator that
//  seeds the default help-doc book, and the sidebar that creates a
//  book). All three have to agree, or a book created by one path
//  carries folders the other paths never know about.
//
//  This suite pins the layout itself: the folders a book carries,
//  and the folders it does not.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Per-book folder layout (= what a book directory carries)")
@MainActor
struct LibraryBookFolderLayoutTests {

    /// The folders every book directory carries.
    private static let standardFolders = [
        "world", "characters", "outlines", "chapters", "drafts", "sessions",
    ]

    /// A temporary library root, removed when the test ends.
    private func makeLibraryRoot() throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wenshu-book-layout-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func bookDirectory(in root: URL, bookID: String = "book-1") throws -> URL {
        let shelf = root
            .appendingPathComponent("shelves", isDirectory: true)
            .appendingPathComponent("00000000-0000-0000-0000-000000000000", isDirectory: true)
            .appendingPathComponent("books", isDirectory: true)
            .appendingPathComponent(bookID, isDirectory: true)
        try FileManager.default.createDirectory(at: shelf, withIntermediateDirectories: true)
        return shelf
    }

    private func hasFolder(_ url: URL, _ name: String) -> Bool {
        FileManager.default.fileExists(
            atPath: url.appendingPathComponent(name, isDirectory: true).path
        )
    }

    @Test("The bootstrapper creates the standard folders and no others")
    func bootstrapperCreatesTheStandardFolders() throws {
        let root = try makeLibraryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let book = try bookDirectory(in: root)

        try LibraryBootstrapper(wsRoot: root).ensureValidStructure()

        for folder in Self.standardFolders {
            #expect(hasFolder(book, folder), "the book carries the \(folder) folder")
        }
        #expect(!hasFolder(book, "foreshadowing"))
        #expect(!hasFolder(book, "placeholders"))
    }

    @Test("The bootstrapper leaves the folders it did not create alone")
    func bootstrapperLeavesTheOtherFoldersAlone() throws {
        let root = try makeLibraryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let book = try bookDirectory(in: root)

        try LibraryBootstrapper(wsRoot: root).ensureValidStructure()

        // The folder the outline documents live in, and a document
        // inside it: the repair pass adds what is missing and takes
        // nothing away.
        let outlines = book.appendingPathComponent("outlines", isDirectory: true)
        let document = outlines.appendingPathComponent("x.md")
        try Data("# outline".utf8).write(to: document)

        try LibraryBootstrapper(wsRoot: root).ensureValidStructure()

        #expect(FileManager.default.fileExists(atPath: document.path),
                "the repair pass keeps the documents it finds")
    }

    @Test("The migrator seeds the default help-doc book with the standard folders and no others")
    func migratorSeedsTheStandardFolders() throws {
        let root = try makeLibraryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        // The migrator writes the default book under the default
        // shelf, so the shelf has to be there first.
        let shelf = root
            .appendingPathComponent("shelves", isDirectory: true)
            .appendingPathComponent("00000000-0000-0000-0000-000000000000", isDirectory: true)
        try FileManager.default.createDirectory(at: shelf, withIntermediateDirectories: true)

        try LibraryMigrator(wsRoot: root).migrateIfNeeded()

        let seededBook = shelf
            .appendingPathComponent("books", isDirectory: true)
            .appendingPathComponent("11111111-1111-1111-1111-111111111111", isDirectory: true)
        #expect(FileManager.default.fileExists(atPath: seededBook.path),
                "the migrator seeds the default book")
        for folder in Self.standardFolders {
            #expect(hasFolder(seededBook, folder), "the seeded book carries the \(folder) folder")
        }
        #expect(!hasFolder(seededBook, "foreshadowing"))
        #expect(!hasFolder(seededBook, "placeholders"))
    }

    @Test("The sidebar creates a book with the standard folders and no others")
    func sidebarCreatesTheStandardFolders() throws {
        let root = try makeLibraryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let shelvesRoot = root.appendingPathComponent("shelves", isDirectory: true)
        let referenceLibraryRoot = root.appendingPathComponent("reference-library", isDirectory: true)
        let stores = LibraryStores(
            shelvesRoot: shelvesRoot,
            referenceLibraryRoot: referenceLibraryRoot,
            referenceStore: FileSystemReferenceStore(referenceLibraryRoot: referenceLibraryRoot)
        )
        let bookStore = BookStore(stores: stores)
        let book = Book(
            id: UUID(),
            title: "A new book",
            author: "wenshu",
            shelfId: UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID()
        )

        try bookStore.sidebarSaveBook(book)

        let created = shelvesRoot
            .appendingPathComponent(book.shelfId.uuidString, isDirectory: true)
            .appendingPathComponent("books", isDirectory: true)
            .appendingPathComponent(book.id.uuidString, isDirectory: true)
        for folder in Self.standardFolders {
            #expect(hasFolder(created, folder), "the new book carries the \(folder) folder")
        }
        #expect(!hasFolder(created, "foreshadowing"))
        #expect(!hasFolder(created, "placeholders"))
    }
}
