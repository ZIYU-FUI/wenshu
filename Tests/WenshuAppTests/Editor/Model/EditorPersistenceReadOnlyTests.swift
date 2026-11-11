//
//  Tests/Editor/Model/EditorPersistenceReadOnlyTests.swift · Wenshu
//
//  The editor's own write path refuses a read-only book.
//
//  The editor has TWO doors, = and the read-only rule needs both:
//  the SURFACE (= `EditorView`'s `isEditable` gate, = so the user cannot
//  type into the help book) and the WRITE PATH (= `EditorPersistence.save`,
//  = which is what the auto-save actually calls). = A tab that was
//  already open when the book was selected would otherwise keep
//  auto-saving into a book the user may not change.
//
//  ⇒ THIS TEST IS IN A FILE OF ITS OWN on purpose: the base-vs-tip
//  comparison (= `Tools/wenshu-devtool/swift_test_compare.py`) matches a
//  failure by its file AND its line, = so adding a test to an existing
//  file shifts that file's line numbers and makes the tool read a
//  pre-existing failure as a NEW one.
//

import Foundation
import Testing
@testable import WenshuApp

@MainActor
@Suite("The editor's write path refuses a read-only book")
struct EditorPersistenceReadOnlyTests {
    /// Real /tmp directory for the test target (= the FS IS the test).
    private func makeTempDir() throws -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wenshu-EditorPersistenceReadOnly-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// A fresh EditorTab (= the type that owns draft / originalBody /
    /// documentPath).
    ///
    /// `bookID` is the tab's OWN book (= `tab.sourceScope`), = which is
    /// the key the refusal asks. = It is NOT the tree's selection.
    private func makeTab(
        documentPath: String? = nil,
        draft: String = "",
        originalBody: String = "",
        bookID: UUID? = nil
    ) -> EditorTab {
        var tab = EditorTab(
            id: UUID(),
            documentPath: documentPath,
            draft: draft,
            originalBody: originalBody,
            mode: .preview,
            title: nil
        )
        if let bookID {
            tab.sourceScope = .bookScope(bookId: bookID, folderName: nil)
        }
        return tab
    }

    /// A document path inside a book (= the library's own layout: =
    /// `shelves/<shelf>/books/<book-id>/<folder>/<file>`).
    private func libraryDocumentPath(
        root: URL,
        bookID: UUID,
        folder: String = "chapters",
        file: String = "note.md"
    ) throws -> URL {
        let url = root
            .appendingPathComponent("shelves", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("books", isDirectory: true)
            .appendingPathComponent(bookID.uuidString, isDirectory: true)
            .appendingPathComponent(folder, isDirectory: true)
            .appendingPathComponent(file)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        return url
    }

    /// A store whose SELECTED book is the help book.
    private func makeStoreSelectingTheHelpBook() throws -> (BookStore, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-editor-readonly-\(UUID().uuidString)")
        let referenceLibraryRoot = root.appendingPathComponent("reference-library", isDirectory: true)
        try FileManager.default.createDirectory(at: referenceLibraryRoot, withIntermediateDirectories: true)
        let shelvesRoot = root.appendingPathComponent("shelves", isDirectory: true)
        try FileManager.default.createDirectory(at: shelvesRoot, withIntermediateDirectories: true)
        let stores = LibraryStores(
            shelvesRoot: shelvesRoot,
            referenceLibraryRoot: referenceLibraryRoot,
            referenceStore: FileSystemReferenceStore(referenceLibraryRoot: referenceLibraryRoot)
        )
        let bookStore = BookStore(stores: stores)
        // The selected book IS the help book (= the app's own document).
        bookStore.selectedBookId = BookSessionLifecycle.helpBookID
        return (bookStore, root)
    }

    /// A store whose SELECTED book is an ordinary one.
    private func makeStoreSelectingAnOrdinaryBook() throws -> (BookStore, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-editor-ordinary-\(UUID().uuidString)")
        let referenceLibraryRoot = root.appendingPathComponent("reference-library", isDirectory: true)
        try FileManager.default.createDirectory(at: referenceLibraryRoot, withIntermediateDirectories: true)
        let shelvesRoot = root.appendingPathComponent("shelves", isDirectory: true)
        try FileManager.default.createDirectory(at: shelvesRoot, withIntermediateDirectories: true)
        let stores = LibraryStores(
            shelvesRoot: shelvesRoot,
            referenceLibraryRoot: referenceLibraryRoot,
            referenceStore: FileSystemReferenceStore(referenceLibraryRoot: referenceLibraryRoot)
        )
        let bookStore = BookStore(stores: stores)
        bookStore.selectedBookId = UUID()
        return (bookStore, root)
    }

    @Test("save refuses to write into a tab whose OWN book is the read-only one")
    func saveRefusesTheReadOnlyBook() throws {
        // ⇒ THE TAB'S OWN BOOK IS THE KEY, = NOT the tree's selection.
        // = The selection here points at an ORDINARY book, = so a guard
        // keyed on the selection would write the help book's file (= the
        // protection would not hold) = and a tab in an ordinary book
        // would be refused (= the user's edit would be dropped).
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = dir.appendingPathComponent("read-only.md").path
        try "# old\n".write(toFile: path, atomically: true, encoding: .utf8)
        let tab = makeTab(
            documentPath: path,
            draft: "# new\n",
            originalBody: "# old\n",
            bookID: BookSessionLifecycle.helpBookID
        )

        let (bookStore, root) = try makeStoreSelectingAnOrdinaryBook()
        defer { try? FileManager.default.removeItem(at: root) }

        let written = EditorPersistence.save(tab: tab, bookStore: bookStore)

        #expect(written == nil, "the save must refuse a read-only book (= the help book)")
        let onDisk = try String(contentsOfFile: path, encoding: .utf8)
        #expect(onDisk == "# old\n",
                "the file must be untouched: the read-only book takes no write")
    }

    @Test("save writes an ordinary tab even while the read-only book is SELECTED")
    func saveWritesAnOrdinaryTabWhileTheHelpBookIsSelected() throws {
        // ⇒ THE COUNTER-PROBE FOR THE DEFECT ABOVE: = the selection
        // points at the help book, = the tab's own book is ordinary, = and
        // the edit must still land. = A refusal keyed on the selection
        // dropped this edit (= the reviewer measured it: = the auto-save
        // then marked the tab clean, = so the edit vanished).
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = dir.appendingPathComponent("ordinary.md").path
        try "# old\n".write(toFile: path, atomically: true, encoding: .utf8)
        let tab = makeTab(
            documentPath: path,
            draft: "# new\n",
            originalBody: "# old\n",
            bookID: UUID()
        )

        let (bookStore, root) = try makeStoreSelectingTheHelpBook()
        defer { try? FileManager.default.removeItem(at: root) }

        let written = EditorPersistence.save(tab: tab, bookStore: bookStore)

        #expect(written == path, "an ordinary tab's edit must land")
        let onDisk = try String(contentsOfFile: path, encoding: .utf8)
        #expect(onDisk == "# new\n", "the ordinary book's file is written")
    }

    @Test("a RESTORED tab (= no scope) whose path is in the read-only book is still refused")
    func aRestoredTabInTheReadOnlyBookIsStillRefused() throws {
        // ⇒ THE KEY THAT SURVIVES A RELAUNCH IS THE PATH. = A restored
        // tab keeps its document path (= `PersistedEditorTab` carries it)
        // and loses its scope (= the persisted tab has no scope field),
        // = so a guard that reads only the scope fails OPEN here: = the
        // user could type into the help book's document and the
        // auto-save would write it. = MEASURED at round 3 (= the help
        // book's own file was overwritten).
        let (bookStore, root) = try makeStoreSelectingAnOrdinaryBook()
        defer { try? FileManager.default.removeItem(at: root) }
        let path = try libraryDocumentPath(root: root, bookID: BookSessionLifecycle.helpBookID)
        try "# old\n".write(to: path, atomically: true, encoding: .utf8)

        // The restored shape: = a path, = and NO scope.
        let tab = makeTab(
            documentPath: path.path,
            draft: "# new\n",
            originalBody: "# old\n"
        )

        let written = EditorPersistence.save(tab: tab, bookStore: bookStore)

        #expect(written == nil, "a restored tab in the read-only book must be refused")
        let onDisk = try String(contentsOf: path, encoding: .utf8)
        #expect(onDisk == "# old\n",
                "the help book's own document must be untouched")
    }

    @Test("a RESTORED tab whose path is in an ordinary book still saves")
    func aRestoredTabInAnOrdinaryBookStillSaves() throws {
        // ⇒ THE COUNTER-PROBE FOR THE CASE ABOVE: = the restored shape
        // must not refuse an ordinary book's document.
        let (bookStore, root) = try makeStoreSelectingAnOrdinaryBook()
        defer { try? FileManager.default.removeItem(at: root) }
        let path = try libraryDocumentPath(root: root, bookID: UUID())
        try "# old\n".write(to: path, atomically: true, encoding: .utf8)

        let tab = makeTab(
            documentPath: path.path,
            draft: "# new\n",
            originalBody: "# old\n"
        )

        let written = EditorPersistence.save(tab: tab, bookStore: bookStore)

        #expect(written == path.path, "an ordinary book's document still saves")
        let onDisk = try String(contentsOf: path, encoding: .utf8)
        #expect(onDisk == "# new\n", "an ordinary book's document is written")
    }

    @Test("the auto-save leaves the tab DIRTY when the save is REFUSED")
    func theAutoSaveLeavesTheTabDirtyWhenTheSaveIsRefused() async throws {
        // ⇒ THE AUTO-SAVE MUST NOT MARK A TAB CLEAN WHEN THE SAVE DID
        // NOT HAPPEN. = Otherwise the edit vanishes: = the tab reads as
        // saved (= the draft equals the original body) = and the file on
        // disk never got the text.
        let (bookStore, root) = try makeStoreSelectingAnOrdinaryBook()
        defer { try? FileManager.default.removeItem(at: root) }
        let path = try libraryDocumentPath(root: root, bookID: BookSessionLifecycle.helpBookID)
        try "# old\n".write(to: path, atomically: true, encoding: .utf8)

        let tab = makeTab(
            documentPath: path.path,
            draft: "# new\n",
            originalBody: "# old\n"
        )

        EditorPersistence.handleDirtyTransition(true, tab: tab, bookStore: bookStore)
        try await Task.sleep(for: .seconds(5))

        #expect(tab.originalBody != tab.draft,
                "a refused save must leave the tab dirty (= the edit is still pending)")
        let onDisk = try String(contentsOf: path, encoding: .utf8)
        #expect(onDisk == "# old\n", "the help book's own document must be untouched")
    }

    @Test("the auto-save leaves the tab DIRTY when the write FAILED")
    func theAutoSaveLeavesTheTabDirtyWhenTheWriteFailed() async throws {
        // ⇒ A WRITE THAT DID NOT LAND IS A FAILED SAVE. = The save
        // returns the path even when the write failed (= the flag was
        // only logged), = so the auto-save marked the tab clean and the
        // edit vanished. = Here the write fails on purpose: = the
        // document's own directory cannot be written to.
        let (bookStore, root) = try makeStoreSelectingAnOrdinaryBook()
        defer { try? FileManager.default.removeItem(at: root) }
        let path = try libraryDocumentPath(root: root, bookID: UUID())
        try "# old\n".write(to: path, atomically: true, encoding: .utf8)

        // The document's parent cannot be written to, = so the write
        // fails with a permission error.
        let parent = path.deletingLastPathComponent()
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o555],
            ofItemAtPath: parent.path
        )
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: parent.path
            )
        }

        let tab = makeTab(
            documentPath: path.path,
            draft: "# new\n",
            originalBody: "# old\n"
        )

        EditorPersistence.handleDirtyTransition(true, tab: tab, bookStore: bookStore)
        try await Task.sleep(for: .seconds(5))

        #expect(tab.originalBody != tab.draft,
                "a failed write must leave the tab dirty (= the edit is still pending)")
        let onDisk = try String(contentsOf: path, encoding: .utf8)
        #expect(onDisk == "# old\n", "the document must be untouched")
    }

    @Test("save still writes into an ordinary book")
    func saveStillWritesIntoAnOrdinaryBook() throws {
        // The refusal is scoped to the help book (= it is not a blanket
        // "the editor never saves" rule): = an ordinary book keeps
        // saving exactly as before.
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = dir.appendingPathComponent("ordinary.md").path
        try "# old\n".write(toFile: path, atomically: true, encoding: .utf8)
        let tab = makeTab(
            documentPath: path,
            draft: "# new\n",
            originalBody: "# old\n",
            bookID: UUID()
        )

        let (bookStore, root) = try makeStoreSelectingAnOrdinaryBook()
        defer { try? FileManager.default.removeItem(at: root) }

        let written = EditorPersistence.save(tab: tab, bookStore: bookStore)

        #expect(written == path, "an ordinary book still saves")
        let onDisk = try String(contentsOfFile: path, encoding: .utf8)
        #expect(onDisk == "# new\n", "an ordinary book's file is written")
    }
}
