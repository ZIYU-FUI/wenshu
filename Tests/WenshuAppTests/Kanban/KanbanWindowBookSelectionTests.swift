//
//  KanbanWindowBookSelectionTests.swift · Wenshu
//
//  Behavior tests for the kanban window's book resolution.
//
//  The window cannot render a board without a book: the ticket file
//  lives inside the book's folder, so an unresolved book means no
//  directory and no board. The window reads the main window's live
//  sidebar selection for the book, because that is the one selection
//  the main window writes when the user clicks a row.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Kanban window book resolution")
struct KanbanWindowBookSelectionTests {

    @Test("a book row names its book")
    func testBookRowNamesBook() {
        let bookId = UUID()
        let resolved = KanbanWindow.bookId(for: .book(bookId))
        #expect(resolved == bookId,
                "A book row must resolve to that book")
    }

    @Test("a folder row names its parent book")
    func testFolderRowNamesBook() {
        let bookId = UUID()
        let resolved = KanbanWindow.bookId(for: .folder(bookId: bookId, folderName: "chapters"))
        #expect(resolved == bookId,
                "A folder row must resolve to the book that owns it")
    }

    @Test("a shelf, a reference category, a tag, and nothing name no book")
    func testNonBookSelectionsNameNoBook() {
        #expect(KanbanWindow.bookId(for: .shelf(UUID())) == nil,
                "A shelf names no book")
        #expect(KanbanWindow.bookId(for: .referenceCategory("anything")) == nil,
                "A reference category names no book")
        #expect(KanbanWindow.bookId(for: .referenceLibraryRoot) == nil,
                "The reference library names no book")
        #expect(KanbanWindow.bookId(for: .tag("any")) == nil,
                "A tag names no book")
        #expect(KanbanWindow.bookId(for: nil) == nil,
                "No selection names no book")
    }

    @Test("the window receives the shared workspace state")
    func testWindowTakesWorkspaceState() throws {
        let sourcePath = SourceLocator.repoRoot
            .appendingPathComponent("Sources/WenshuApp/Features/Kanban/View/KanbanWindow.swift")
            .path
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("workspaceUI: WorkspaceUIState"),
                "The kanban window must take the shared workspace state")
        #expect(source.contains("sidebarSelection"),
                "The kanban window must read the live sidebar selection")
    }

    @Test("the scene passes the workspace state to the kanban window")
    func testScenePassesWorkspaceState() throws {
        let sourcePath = SourceLocator.repoRoot
            .appendingPathComponent("Sources/WenshuApp/App/AppRootScene.swift")
            .path
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("KanbanWindow(workspaceUI: workspaceUI)"),
                "The kanban scene must hand the kanban window the shared workspace state")
    }
}
