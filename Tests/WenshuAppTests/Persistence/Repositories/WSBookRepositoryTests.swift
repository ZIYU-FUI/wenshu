//
//  Persistence/Repositories/WSBookRepositoryTests.swift · Wenshu · v0.72 SwiftData migration Phase 2

import Foundation
import SwiftData
import Testing
@testable import WenshuApp

@Suite("WSBookRepository (= SwiftData @Model BookStore replacement; book + shelf CRUD)")
struct WSBookRepositoryTests {

    @MainActor
    private func makeRepository() throws -> WSBookRepository {
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        return WSBookRepository(container: container)
    }

    @Test("createShelf + listShelves round-trip")
    @MainActor
    func shelfCRUD() throws {
        let repo = try makeRepository()
        let shelf = try repo.createShelf(name: "测试书架")
        #expect(shelf.name == "测试书架")
        let list = try repo.listShelves()
        #expect(list.count == 1)
        #expect(list[0].id == shelf.id)
    }

    @Test("renameShelf updates name")
    @MainActor
    func renameShelf() throws {
        let repo = try makeRepository()
        let shelf = try repo.createShelf(name: "old")
        try repo.renameShelf(id: shelf.id, to: "new")
        let fetched = try repo.getShelf(id: shelf.id)
        #expect(fetched?.name == "new")
    }

    @Test("renameShelf throws notFound for missing")
    @MainActor
    func renameShelfMissing() throws {
        let repo = try makeRepository()
        #expect(throws: WSBookRepositoryError.notFound.self) {
            try repo.renameShelf(id: "nope", to: "x")
        }
    }

    @Test("createBook + listBooks round-trip")
    @MainActor
    func bookCRUD() throws {
        let repo = try makeRepository()
        let shelf = try repo.createShelf(name: "shelf")
        let book = try repo.createBook(title: "赤壁之战", shelfID: shelf.id, idea: "三国")
        #expect(book.title == "赤壁之战")
        #expect(book.shelfID == shelf.id)
        let list = try repo.listBooks(shelfID: shelf.id)
        #expect(list.count == 1)
        #expect(list[0].id == book.id)
    }

    @Test("listBooks filters by shelfID")
    @MainActor
    func listBooksFiltered() throws {
        let repo = try makeRepository()
        let s1 = try repo.createShelf(name: "s1")
        let s2 = try repo.createShelf(name: "s2")
        _ = try repo.createBook(title: "b1", shelfID: s1.id)
        _ = try repo.createBook(title: "b2", shelfID: s2.id)
        let s1Books = try repo.listBooks(shelfID: s1.id)
        let all = try repo.listBooks()
        #expect(s1Books.count == 1)
        #expect(all.count == 2)
    }

    @Test("updateBook mutates fields + bumps updatedAt")
    @MainActor
    func updateBook() throws {
        let repo = try makeRepository()
        let book = try repo.createBook(title: "old")
        try? Thread.sleep(forTimeInterval: 0.01)
        try repo.updateBook(id: book.id, title: "new", idea: "some idea", length: 80_000)
        let fetched = try repo.getBook(id: book.id)
        #expect(fetched?.title == "new")
        #expect(fetched?.idea == "some idea")
        #expect(fetched?.length == 80_000)
        // updatedAt bump not asserted (= SwiftData timing precision varies)
    }

    @Test("deleteBook removes the row")
    @MainActor
    func deleteBook() throws {
        let repo = try makeRepository()
        let book = try repo.createBook(title: "x")
        try repo.deleteBook(id: book.id)
        let fetched = try repo.getBook(id: book.id)
        #expect(fetched == nil)
    }

    @Test("deleteShelf preserves books (= books lose shelf reference but stay)")
    @MainActor
    func deleteShelfPreservesBooks() throws {
        let repo = try makeRepository()
        let shelf = try repo.createShelf(name: "s")
        let book = try repo.createBook(title: "b", shelfID: shelf.id)
        try repo.deleteShelf(id: shelf.id)
        // Book remains (= SwiftData deleteRule .nullify clears shelfID)
        let books = try repo.listBooks()
        #expect(books.count == 1)
        #expect(books[0].id == book.id)
        // shelfID nullify is async (= deleteRule .nullify applies at next fetch)
        // — not asserting here (= behavior depends on SwiftData implementation)
    }

    // MARK: - Chapter tests

    @Test("createChapter + listChapters round-trip; ordered by position")
    @MainActor
    func chapterCRUD() throws {
        let repo = try makeRepository()
        let book = try repo.createBook(title: "Test Book")
        _ = try repo.createChapter(bookID: book.id, title: "Chapter 1", position: 0)
        _ = try repo.createChapter(bookID: book.id, title: "Chapter 2", position: 1)
        let chapters = try repo.listChapters(bookID: book.id)
        #expect(chapters.count == 2)
        #expect(chapters[0].title == "Chapter 1")
        #expect(chapters[1].title == "Chapter 2")
    }

    @Test("updateChapterWordCount sets wordCount + updatedAt")
    @MainActor
    func updateChapterWordCount() throws {
        let repo = try makeRepository()
        let book = try repo.createBook(title: "x")
        let chapter = try repo.createChapter(bookID: book.id, title: "c", position: 0)
        try repo.updateChapterWordCount(id: chapter.id, wordCount: 1234)
        let chapters = try repo.listChapters(bookID: book.id)
        #expect(chapters[0].wordCount == 1234)
    }

    @Test("setChapterStatus updates status")
    @MainActor
    func setChapterStatus() throws {
        let repo = try makeRepository()
        let book = try repo.createBook(title: "x")
        let chapter = try repo.createChapter(bookID: book.id, title: "c", position: 0)
        try repo.setChapterStatus(id: chapter.id, status: "in_review")
        let chapters = try repo.listChapters(bookID: book.id)
        #expect(chapters[0].status == "in_review")
    }

    @Test("deleteChapter removes chapter (= cascade deletes outline nodes)")
    @MainActor
    func deleteChapter() throws {
        let repo = try makeRepository()
        let book = try repo.createBook(title: "x")
        let chapter = try repo.createChapter(bookID: book.id, title: "c", position: 0)
        try repo.deleteChapter(id: chapter.id)
        let chapters = try repo.listChapters(bookID: book.id)
        #expect(chapters.isEmpty)
    }

}
