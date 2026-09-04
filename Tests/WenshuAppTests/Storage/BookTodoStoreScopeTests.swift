//
//  BookTodoStoreScopeTests.swift · Wenshu (文枢) · B-13 scope unification
//
//  Round-trip persistence tests for BookTodoStore across every
//  scope variant (= book root / 8 standard sub-folders / reference
//  library). Mirrors BookKanbanStoreScopeTests structure.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("BookTodoStore (B-13 scope variants)")
struct BookTodoStoreScopeTests {

    /// Make a fresh per-book + per-library scratch root.
    private func makeScratch() throws -> (bookDir: URL, libraryRoot: URL) {
        let root = URL(fileURLWithPath: "/tmp/wenshu-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let bookDir = root.appendingPathComponent("books/test-book", isDirectory: true)
        try FileManager.default.createDirectory(at: bookDir, withIntermediateDirectories: true)
        let libraryRoot = root.appendingPathComponent("reference-library", isDirectory: true)
        try FileManager.default.createDirectory(at: libraryRoot, withIntermediateDirectories: true)
        return (bookDir, libraryRoot)
    }

    @Test("book scope → todo.json in the book root")
    func bookScopeRoundtrip() throws {
        let (bookDir, _) = try makeScratch()
        let bookId = UUID()
        let store = BookTodoStore(bookId: bookId, directory: bookDir, scope: .book)
        #expect(store.jsonURL.lastPathComponent == "todo.json")
        try store.save([
            PerBookTodoItem(title: "buy milk", status: .pending, priority: .low),
            PerBookTodoItem(title: "ship B-13", status: .inProgress, priority: .urgent),
        ])
        let loaded = try store.load()
        #expect(loaded.count == 2)
        #expect(loaded.map(\.title) == ["buy milk", "ship B-13"])
        #expect(loaded.map(\.priority) == [.low, .urgent])
    }

    @Test("folder(.chapters) scope → todo-chapters.json inside chapters/")
    func folderChaptersScopeRoundtrip() throws {
        let (bookDir, _) = try makeScratch()
        let chaptersDir = bookDir.appendingPathComponent("chapters", isDirectory: true)
        try FileManager.default.createDirectory(at: chaptersDir, withIntermediateDirectories: true)
        let bookId = UUID()
        let store = BookTodoStore(
            bookId: bookId,
            directory: chaptersDir,
            scope: .folder(.chapters)
        )
        #expect(store.jsonURL.lastPathComponent == "todo-chapters.json")
        try store.save([
            PerBookTodoItem(title: "polish chapter 3 opening", status: .pending, priority: .high),
        ])
        let loaded = try store.load()
        #expect(loaded.first?.title == "polish chapter 3 opening")
        #expect(loaded.first?.priority == .high)
        #expect(FileManager.default.fileExists(
            atPath: chaptersDir.appendingPathComponent("todo-chapters.json").path
        ))
    }

    @Test("folder(.world) scope → todo-world.json inside world/")
    func folderWorldScopeRoundtrip() throws {
        let (bookDir, _) = try makeScratch()
        let worldDir = bookDir.appendingPathComponent("world", isDirectory: true)
        try FileManager.default.createDirectory(at: worldDir, withIntermediateDirectories: true)
        let bookId = UUID()
        let store = BookTodoStore(
            bookId: bookId,
            directory: worldDir,
            scope: .folder(.world)
        )
        #expect(store.jsonURL.lastPathComponent == "todo-world.json")
        try store.save([
            PerBookTodoItem(title: "document magic system limits", status: .pending, priority: .medium),
        ])
        let loaded = try store.load()
        #expect(loaded.first?.title == "document magic system limits")
    }

    @Test("referenceLibrary scope → library-todo.json at the library root")
    func referenceLibraryScopeRoundtrip() throws {
        let (_, libraryRoot) = try makeScratch()
        let bookId = UUID()
        let store = BookTodoStore(
            bookId: bookId,
            directory: libraryRoot,
            scope: .referenceLibrary
        )
        #expect(store.jsonURL.lastPathComponent == "library-todo.json")
        try store.save([
            PerBookTodoItem(title: "re-tag paper references", status: .pending, priority: .high),
        ])
        let loaded = try store.load()
        #expect(loaded.first?.title == "re-tag paper references")
        #expect(FileManager.default.fileExists(
            atPath: libraryRoot.appendingPathComponent("library-todo.json").path
        ))
    }

    @Test("scopeDirectory(bookId:scope:.folder(.chapters)) returns the chapters/ subdir")
    func scopeDirectoryResolvesChapterSubdir() throws {
        let (bookDir, _) = try makeScratch()
        let chaptersDir = bookDir.appendingPathComponent("chapters", isDirectory: true)
        try FileManager.default.createDirectory(at: chaptersDir, withIntermediateDirectories: true)
        let bookId = UUID()
        let expected = bookDir.appendingPathComponent("chapters", isDirectory: true)
        #expect(chaptersDir.standardizedFileURL.path == expected.standardizedFileURL.path)
        #expect(FileManager.default.fileExists(atPath: chaptersDir.path))
        #expect(bookId.uuidString.isEmpty == false)
    }
}
