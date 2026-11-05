//  BookFolderCatalogSeedingTests.swift
//  wenshu
//
//  The catalog is the SSOT for the standard book folders, = and the
//  folders a book actually carries on disk are written in three places
//  (= the bootstrapper that repairs an existing book, = the migrator that
//  seeds the default help-doc book, = and the sidebar that creates a
//  book).
//
//  These tests pin the ONE thing that was not pinned: = that a seeded
//  book carries EVERY folder the catalog declares. = Each of those three
//  places used to carry its own hard-coded list, = and each of those
//  lists missed the same folder (= `ideas`), = and the suite that
//  checked the layout carried a COPY of the same list, = so it was green
//  while a seeded book had no ideas directory at all. = Two independent
//  audits found it.

import Foundation
import Testing
@testable import WenshuApp

@Suite("BookFolderCatalog seeding (= every declared folder is on disk)")
@MainActor
struct BookFolderCatalogSeedingTests {
    private func makeLibraryRoot() throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wenshu-catalog-seeding-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func bookDirectory(in root: URL, bookID: String = "book-1") throws -> URL {
        let dir = root
            .appendingPathComponent("shelves", isDirectory: true)
            .appendingPathComponent("00000000-0000-0000-0000-000000000000", isDirectory: true)
            .appendingPathComponent("books", isDirectory: true)
            .appendingPathComponent(bookID, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func hasFolder(_ url: URL, _ name: String) -> Bool {
        FileManager.default.fileExists(atPath: url.appendingPathComponent(name, isDirectory: true).path)
    }

    // MARK: - The seeded folders ARE the catalog's folders

    @Test("the bootstrapper seeds EVERY folder the catalog declares")
    func theBootstrapperSeedsEveryCatalogFolder() throws {
        let root = try makeLibraryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let book = try bookDirectory(in: root)

        try LibraryBootstrapper(wsRoot: root).ensureValidStructure()

        // = The comparison is a SET, = so a folder the catalog declares
        // and the seeder missed (= or one it seeded and the catalog does
        // not declare) = fails it. = A list compared against a list of
        // the same length could hide a swap.
        let fm = FileManager.default
        let seeded = try Set(
            fm.contentsOfDirectory(atPath: book.path).filter { name in
                var isDir: ObjCBool = false
                let exists = fm.fileExists(
                    atPath: book.appendingPathComponent(name).path,
                    isDirectory: &isDir
                )
                return exists && isDir.boolValue
            }
        )
        let declared = Set(BookFolderCatalog.allBookFolders.map(\.directoryName))
        #expect(seeded == declared,
                "a seeded book carries exactly the folders the catalog declares; = seeded \(seeded.sorted()) vs declared \(declared.sorted())")
    }

    @Test("the ideas folder is one of them (= the defect that hid)")
    func theIdeasFolderIsOneOfThem() throws {
        let root = try makeLibraryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let book = try bookDirectory(in: root)

        try LibraryBootstrapper(wsRoot: root).ensureValidStructure()

        #expect(hasFolder(book, "ideas"),
                "the ideas folder is declared by the catalog, = so it is seeded")
        #expect(BookFolderCatalog.allBookFolders.map(\.directoryName).contains("ideas"))
    }

    // MARK: - The other two seeding places read the same list

    @Test("the migrator's help-doc book carries every catalog folder")
    func theMigratorsHelpDocBookCarriesEveryCatalogFolder() throws {
        let root = try makeLibraryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let shelf = root.appendingPathComponent("shelf-1", isDirectory: true)
        try FileManager.default.createDirectory(at: shelf, withIntermediateDirectories: true)

        let migrator = LibraryMigrator(wsRoot: root)
        try migrator.seedDefaultHelpDoc(in: shelf)

        let book = shelf
            .appendingPathComponent("books", isDirectory: true)
            .appendingPathComponent("11111111-1111-1111-1111-111111111111", isDirectory: true)
        for folder in BookFolderCatalog.allBookFolders {
            #expect(hasFolder(book, folder.directoryName),
                    "the help-doc book carries the \(folder.directoryName) folder")
        }
    }

    @Test("the sidebar's created book carries every catalog folder")
    func theSidebarsCreatedBookCarriesEveryCatalogFolder() throws {
        // = The third seeding place, = measured by what it produced on
        // disk, = not by what its source mentions: = a source-text
        // assertion is satisfied by a COMMENT, = and this card's first
        // version of that check proved it (= restoring the hard-coded
        // list while the literal survived in a comment left the suite
        // fully green).
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
        for folder in BookFolderCatalog.allBookFolders {
            #expect(hasFolder(created, folder.directoryName),
                    "the created book carries the \(folder.directoryName) folder")
        }
    }

    @Test("the three seeding places declare the list FROM THE CATALOG")
    func theThreeSeedingPlacesDeclareTheListFromTheCatalog() throws {
        // = Scoped to the DECLARATION, = and paired with the ABSENCE of
        // the hard-coded literal. = A whole-file `contains` check is
        // satisfied by a COMMENT: = the reviewer measured that, = by
        // restoring the hard-coded list while the literal survived in a
        // comment, = and the suite stayed fully green. = So the check
        // reads the line that DECLARES the list, = and it also requires
        // that the old literal is nowhere in the file.
        let sources = [
            "Sources/WenshuApp/Features/Library/Service/LibraryBootstrapper.swift",
            "Sources/WenshuApp/Features/Library/Service/LibraryMigrator+HelpDoc.swift",
            "Sources/WenshuApp/Features/Library/View/SidebarServiceMutation.swift",
        ]
        for path in sources {
            let url = SourceLocator.repoRoot.appendingPathComponent(path)
            let source = try String(contentsOf: url, encoding: .utf8)
            let declaration = source
                .split(separator: "\n", omittingEmptySubsequences: false)
                .first { $0.contains("let standardFolders =") }
            #expect(declaration != nil, "\(path) declares the folder list")
            #expect(declaration?.contains("BookFolderCatalog.allBookFolders") == true,
                    "\(path) declares the list FROM the catalog")
            #expect(!source.contains("\"world\", \"characters\""),
                    "\(path) carries no hard-coded folder list")
        }
    }

    // MARK: - The tree names the directory (= through the production seam)

    @Test("a folder row resolves to its directory AND to its book's id")
    func aFolderRowResolvesToItsDirectoryAndToItsBooksId() {
        // = This is the seam the sidebar click actually runs: =
        // `parentBookInfo` walks the tree, = finds the book, = and maps
        // the folder row's TITLE back to its directory name. = The first
        // version of this card left that half UNTESTED: = a mutation
        // that reverted only the reverse map left every suite green, =
        // because the suite asserted the catalog's own map and never
        // called the code the tree runs.
        let bookId = UUID()
        for folder in BookFolderCatalog.userFacing {
            let rowId = UUID()
            let tree: [SidebarNode] = [
                SidebarNode(
                    id: UUID(),
                    kind: .shelf,
                    title: "Shelf",
                    subtitle: nil,
                    systemImage: "books.vertical",
                    children: [
                        SidebarNode(
                            id: bookId,
                            kind: .book,
                            title: "A Book",
                            subtitle: nil,
                            systemImage: "book",
                            children: [
                                SidebarNode(
                                    id: rowId,
                                    kind: .book,
                                    title: folder.sidebarDisplayName,
                                    subtitle: nil,
                                    systemImage: folder.icon ?? "folder",
                                    children: nil
                                ),
                            ]
                        ),
                    ]
                ),
            ]
            let info = AppleSidebarView.parentBookInfo(for: rowId, in: tree)
            #expect(info != nil,
                    "the \(folder.sidebarDisplayName) row resolves to a book")
            #expect(info?.folderName == folder.directoryName,
                    "the \(folder.sidebarDisplayName) row resolves to the \(folder.directoryName) directory")
            #expect(info?.bookId == bookId,
                    "the \(folder.sidebarDisplayName) row carries its book's id")
        }
    }

    @Test("the ideas row resolves to the ideas directory (= the defect that hid)")
    func theIdeasRowResolvesToTheIdeasDirectory() {
        let bookId = UUID()
        let rowId = UUID()
        let ideas = BookFolderCatalog.ideas
        let tree: [SidebarNode] = [
            SidebarNode(
                id: UUID(),
                kind: .shelf,
                title: "Shelf",
                subtitle: nil,
                systemImage: "books.vertical",
                children: [
                    SidebarNode(
                        id: bookId,
                        kind: .book,
                        title: "A Book",
                        subtitle: nil,
                        systemImage: "book",
                        children: [
                            SidebarNode(
                                id: rowId,
                                kind: .book,
                                title: ideas.sidebarDisplayName,
                                subtitle: nil,
                                systemImage: ideas.icon ?? "folder",
                                children: nil
                            ),
                        ]
                    ),
                ]
            ),
        ]
        let info = AppleSidebarView.parentBookInfo(for: rowId, in: tree)
        #expect(info?.folderName == "ideas")
        #expect(info?.bookId == bookId)
    }

    // MARK: - The label maps back to the directory

    @Test("every folder's sidebar label maps back to its directory")
    func everyFoldersSidebarLabelMapsBackToItsDirectory() {
        for folder in BookFolderCatalog.allBookFolders {
            #expect(BookFolderCatalog.directoryName(forSidebarDisplayName: folder.sidebarDisplayName)
                == folder.directoryName,
                "the \(folder.sidebarDisplayName) row resolves to the \(folder.directoryName) directory")
        }
    }

    @Test("every user-facing folder's label is reversible (= the tree can answer)")
    func everyUserFacingFoldersLabelIsReversible() {
        for folder in BookFolderCatalog.userFacing {
            #expect(BookFolderCatalog.directoryName(forSidebarDisplayName: folder.sidebarDisplayName) != nil,
                    "the \(folder.sidebarDisplayName) row is reversible")
        }
    }
}
