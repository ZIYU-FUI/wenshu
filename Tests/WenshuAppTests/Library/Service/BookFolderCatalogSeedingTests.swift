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
//
//  EACH seeding place is measured by WHAT IT WROTE ON DISK, = through its
//  own production path, = and the folders are compared as SETS: = a
//  folder the catalog declares and the seeder missed (= or one it seeded
//  and the catalog does not declare) = fails the comparison. = The
//  source-text check beside them is the weaker guard: = it says the list
//  is READ from the catalog, = and it reads the CODE (= not the prose),
//  = because a comment can carry any token at all.

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

    /// The DIRECTORY names a book directory carries: = the folders
    /// themselves, = and not the files beside them (= book.json, =
    /// kanban.json, = todo.json).
    private func folderNames(in book: URL) throws -> Set<String> {
        let fm = FileManager.default
        return try Set(
            fm.contentsOfDirectory(atPath: book.path).filter { name in
                var isDirectory: ObjCBool = false
                let exists = fm.fileExists(
                    atPath: book.appendingPathComponent(name).path,
                    isDirectory: &isDirectory
                )
                return exists && isDirectory.boolValue
            }
        )
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
        let seeded = try folderNames(in: book)
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

    @Test("the migrator's help-doc book carries EVERY folder the catalog declares")
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
        let seeded = try folderNames(in: book)
        let declared = Set(BookFolderCatalog.allBookFolders.map(\.directoryName))
        #expect(seeded == declared,
                "the help-doc book carries exactly the folders the catalog declares; = seeded \(seeded.sorted()) vs declared \(declared.sorted())")
    }

    @Test("the sidebar's OWN create path seeds EVERY folder the catalog declares")
    func theSidebarCreatePathSeedsEveryCatalogFolder() throws {
        // = The THIRD seeding place, = measured through its own
        // = production path: = `SidebarService.createBook(input:)` = the
        // = one the sidebar runs when the user creates a book
        // = (`AppleSidebarView.swift:393`).
        // =
        // = The previous version of this test called
        // = `bookStore.sidebarSaveBook(book)`, = which seeds through the
        // = BOOTSTRAPPER (= `BookStore+SidebarInline.swift:93-94`), = so
        // = it measured the bootstrapper twice and this place zero
        // = times: = a narrowing of THIS list (= the five user-facing
        // = folders, = or all but `ideas`) = left the suite green.
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
        // = The service is built WITHOUT a reload: = a reload sweeps the
        // = cover library (= a side effect on the user's own covers), =
        // = and the seeding path reads none of the reload's caches.
        let service = SidebarService(
            loadShelves: { [] },
            loadAllBooks: { [] },
            loadReferences: { [] },
            bookStore: bookStore
        )
        let shelfID = UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID()
        let shelf = shelvesRoot.appendingPathComponent(shelfID.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: shelf, withIntermediateDirectories: true)

        let bookID = try service.createBook(input: NewBookSheet.NewBookInput(
            title: "A new book",
            author: "wenshu",
            shelfId: shelfID,
            icon: "book"
        ))

        let created = shelf
            .appendingPathComponent("books", isDirectory: true)
            .appendingPathComponent(bookID.uuidString, isDirectory: true)
        // = A SET, = so a folder the catalog declares and this place
        // = missed (= `outlines`, = `sessions`, = `ideas`) = fails it, =
        // = and so does a folder it seeded and the catalog does not
        // = declare.
        let seeded = try folderNames(in: created)
        let declared = Set(BookFolderCatalog.allBookFolders.map(\.directoryName))
        #expect(seeded == declared,
                "the created book carries exactly the folders the catalog declares; = seeded \(seeded.sorted()) vs declared \(declared.sorted())")
    }

    @Test("the three seeding places declare the list FROM THE CATALOG")
    func theThreeSeedingPlacesDeclareTheListFromTheCatalog() throws {
        // = The weaker guard beside the on-disk measurements: = it says
        // = the list is READ from the catalog, = so a folder added to
        // = the catalog cannot be missed by a place that keeps its own
        // = copy of the list.
        // =
        // = It reads the CODE, = not the prose: = a comment can carry
        // = any token, = so a comment must not be able to claim the
        // = marker.  (= The reviewer measured that attack: = a decoy
        // = comment carrying the token + a hard-coded list written one
        // = folder per line satisfied the old check, = and the old
        // = literal check looked for one exact substring = (`"world",
        // = "characters"`), = which a list written one per line does not
        // = carry.)
        let sources: [(path: String, namesNoFolder: Bool)] = [
            ("Sources/WenshuApp/Features/Library/Service/LibraryBootstrapper.swift", false),
            ("Sources/WenshuApp/Features/Library/Service/LibraryMigrator+HelpDoc.swift", false),
            ("Sources/WenshuApp/Features/Library/View/SidebarServiceMutation.swift", true),
        ]
        for source in sources {
            let url = SourceLocator.repoRoot.appendingPathComponent(source.path)
            let text = try String(contentsOf: url, encoding: .utf8)
            let code = Self.codeLines(of: text)
            let declarations = code.indices.filter { code[$0].code.contains("let standardFolders =") }
            #expect(declarations.count == 1,
                    "\(source.path) declares the folder list exactly once (= no second copy to drift)")
            let declaration = declarations.last.map { code[$0].code } ?? ""
            #expect(declaration.contains("BookFolderCatalog.allBookFolders"),
                    "\(source.path) declares the list FROM the catalog")
            // = The declaration's WHOLE statement, = so a list written
            // = one folder per line is read whole = and cannot hide a
            // = literal behind the line break.
            let statement = Self.statement(of: code, at: declarations.last ?? 0)
            for folder in BookFolderCatalog.allBookFolders {
                #expect(!statement.contains("\"\(folder.directoryName)\""),
                        "\(source.path) writes no folder name out (= the list is not written here)")
            }
            // = The sidebar's file names NO folder at all: = every name
            // = it uses comes from the catalog.  (= The migrator names
            // = folders on purpose (= the destinations of the help
            // = documents it writes), = and the bootstrapper names the
            // = legacy root-level orphan, = so the file-wide rule is
            // = the sidebar's alone.)
            if source.namesNoFolder {
                let wholeFile = code.map(\.code).joined(separator: "\n")
                for folder in BookFolderCatalog.allBookFolders {
                    #expect(!wholeFile.contains("\"\(folder.directoryName)\""),
                            "\(source.path) carries no folder name (= every name comes from the catalog)")
                }
            }
        }
    }

    // MARK: - Reading a Swift source's CODE (= a comment cannot claim the marker)

    /// The source's CODE, = line by line: = the comments removed, = and
    /// the string bodies left out.  (= A comment seeds nothing, = so it
    /// cannot carry the list, = and it must not be able to claim the
    /// marker either.)
    ///
    /// = The scan is a WHOLE-FILE pass with a state machine, = not one
    /// = line at a time: = these sources carry `"""` prose blocks (= the
    /// = migrator's help documents), = and a per-line scan loses its
    /// = place in the middle of one.
    private static func codeLines(of source: String) -> [(code: String, balance: Int)] {
        // The scanner's states: = `normal` = code, = `lineComment` = to
        // the end of the line, = `blockComment` = to the closing `*/`,
        // = `string` = to the closing quote, = `multiLine` = to the
        // closing `"""`.
        enum State {
            case normal, lineComment, blockComment, string, multiLine
        }
        let characters = Array(source)
        var result: [(code: String, balance: Int)] = []
        var code = ""
        var balance = 0
        var state = State.normal
        var index = 0
        func flush() {
            result.append((code, balance))
            code = ""
            balance = 0
        }
        while index < characters.count {
            let character = characters[index]
            let next = index + 1 < characters.count ? characters[index + 1] : nil
            switch state {
            case .normal:
                if character == "/", next == "/" {
                    state = .lineComment
                    index += 2
                    continue
                }
                if character == "/", next == "*" {
                    state = .blockComment
                    index += 2
                    continue
                }
                if character == "\"", index + 2 < characters.count,
                   characters[index + 1] == "\"", characters[index + 2] == "\""
                {
                    state = .multiLine
                    code.append("\"\"\"")
                    index += 3
                    continue
                }
                if character == "\"" {
                    state = .string
                    code.append(character)
                    index += 1
                    continue
                }
                if character == "\n" {
                    flush()
                    index += 1
                    continue
                }
                if "([{".contains(character) {
                    balance += 1
                }
                if ")]}".contains(character) {
                    balance -= 1
                }
                code.append(character)
                index += 1
            case .lineComment:
                if character == "\n" {
                    state = .normal
                    flush()
                }
                index += 1
            case .blockComment:
                if character == "*", next == "/" {
                    state = .normal
                    index += 2
                    continue
                }
                if character == "\n" {
                    flush()
                }
                index += 1
            case .string:
                if character == "\\" {
                    code.append(character)
                    if let next {
                        code.append(next)
                    }
                    index += 2
                    continue
                }
                if character == "\"" {
                    state = .normal
                }
                code.append(character)
                index += 1
            case .multiLine:
                if character == "\\" {
                    index += 2
                    continue
                }
                if character == "\"", index + 2 < characters.count,
                   characters[index + 1] == "\"", characters[index + 2] == "\""
                {
                    state = .normal
                    index += 3
                    continue
                }
                if character == "\n" {
                    flush()
                }
                index += 1
            }
        }
        if !code.isEmpty || balance != 0 {
            flush()
        }
        return result.filter { !$0.code.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    /// The statement that starts at a line: = the lines it spans, = so a
    /// list written one folder per line is read whole.
    private static func statement(of code: [(code: String, balance: Int)], at index: Int) -> String {
        var text = code[index].code
        var balance = code[index].balance
        var next = index + 1
        while balance > 0, next < code.count {
            text += "\n" + code[next].code
            balance += code[next].balance
            next += 1
        }
        return text
    }

    // MARK: - The tree names the directory (= through the production seam)

    @Test("a folder row resolves to its directory AND to its book's id")
    func aFolderRowResolvesToItsDirectoryAndToItsBooksId() {
        // = This is the seam the sidebar click actually runs: =
        // `parentBookInfo` walks the tree, = finds the book, = and maps
        // = the folder row's TITLE back to its directory name. = The first
        // = version of this card left that half UNTESTED: = a mutation
        // = that reverted only the reverse map left every suite green, =
        // = because the suite asserted the catalog's own map and never
        // = called the code the tree runs.
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
