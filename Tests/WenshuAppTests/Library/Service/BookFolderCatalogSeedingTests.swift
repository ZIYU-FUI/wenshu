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

    @Test("all three seeding places read the list FROM THE CATALOG")
    func allThreeSeedingPlacesReadTheListFromTheCatalog() throws {
        // = The house pattern for a page's coverage, = the adapter test
        // reads the command's source the same way: = the three places
        // that WRITE the folders are read, = because a hard-coded list
        // in any one of them is a second list to forget.
        let sources = [
            "Sources/WenshuApp/Features/Library/Service/LibraryBootstrapper.swift",
            "Sources/WenshuApp/Features/Library/Service/LibraryMigrator+HelpDoc.swift",
            "Sources/WenshuApp/Features/Library/View/SidebarServiceMutation.swift",
        ]
        for path in sources {
            let url = SourceLocator.repoRoot.appendingPathComponent(path)
            let source = try String(contentsOf: url, encoding: .utf8)
            #expect(source.contains("BookFolderCatalog.allBookFolders"),
                    "\(path) reads its folder list from the catalog")
        }
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
