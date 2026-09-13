//
//  Persistence/Repositories/WSBookRepository.swift · Wenshu · v0.72 SwiftData migration Phase 2
//
//  Migration commit 28 of 42: WSBookRepository (= book + shelf CRUD).
//  Per AGENTS.md §11.4.
//
//  Thin wrapper for BookStore (= filesystem-based; = SwiftData is
//  metadata index, = filesystem remains canonical source of truth).
//
//  Scope of this commit (= book + shelf CRUD):
//    Shelves:
//      - listShelves() -> [WSBookShelf]
//      - getShelf(id:) -> WSBookShelf?
//      - createShelf(name:) -> WSBookShelf
//      - renameShelf(id:to:) throws
//      - deleteShelf(id:) throws
//    Books:
//      - listBooks(shelfID:) -> [WSBook]
//      - getBook(id:) -> WSBook?
//      - createBook(title:shelfID:idea:length:) -> WSBook
//      - updateBook(id:title:idea:length:) throws
//      - deleteBook(id:) throws
//
//  Future commits will add chapter/outline/character/world/foreshadowing/
//  placeholder/outlineDocument wrappers (one entity per commit).

import Foundation
import SwiftData

@MainActor
public final class WSBookRepository {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    public init(container: ModelContainer = WSPersistenceContainer.shared) {
        self.container = container
    }

    // MARK: - Shelves

    public func listShelves() throws -> [WSBookShelf] {
        let descriptor = FetchDescriptor<WSBookShelf>(
            sortBy: [SortDescriptor(\.position), SortDescriptor(\.createdAt)]
        )
        return try context.fetch(descriptor)
    }

    public func getShelf(id: String) throws -> WSBookShelf? {
        let descriptor = FetchDescriptor<WSBookShelf>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }

    @discardableResult
    public func createShelf(name: String, position: Int = 0) throws -> WSBookShelf {
        let shelf = WSBookShelf(id: UUID().uuidString, name: name, position: position)
        context.insert(shelf)
        try context.save()
        return shelf
    }

    public func renameShelf(id: String, to newName: String) throws {
        guard let shelf = try getShelf(id: id) else {
            throw WSBookRepositoryError.notFound
        }
        shelf.name = newName
        shelf.updatedAt = Date()
        try context.save()
    }

    public func deleteShelf(id: String) throws {
        guard let shelf = try getShelf(id: id) else { return }
        context.delete(shelf)
        try context.save()
    }

    // MARK: - Books

    public func listBooks(shelfID: String? = nil) throws -> [WSBook] {
        let descriptor: FetchDescriptor<WSBook>
        if let shelfID = shelfID {
            descriptor = FetchDescriptor<WSBook>(
                predicate: #Predicate { $0.shelfID == shelfID },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<WSBook>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        }
        return try context.fetch(descriptor)
    }

    public func getBook(id: String) throws -> WSBook? {
        let descriptor = FetchDescriptor<WSBook>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }

    @discardableResult
    public func createBook(
        title: String,
        shelfID: String? = nil,
        idea: String? = nil,
        length: Int? = nil
    ) throws -> WSBook {
        let book = WSBook(
            id: UUID().uuidString,
            title: title,
            idea: idea,
            length: length,
            shelfID: shelfID
        )
        context.insert(book)
        try context.save()
        return book
    }

    public func updateBook(
        id: String,
        title: String? = nil,
        idea: String? = nil,
        length: Int? = nil
    ) throws {
        guard let book = try getBook(id: id) else {
            throw WSBookRepositoryError.notFound
        }
        if let title = title { book.title = title }
        if let idea = idea { book.idea = idea }
        if let length = length { book.length = length }
        book.updatedAt = Date()
        try context.save()
    }

    public func deleteBook(id: String) throws {
        guard let book = try getBook(id: id) else { return }
        context.delete(book)
        try context.save()
    }
}

public enum WSBookRepositoryError: Error {
    case notFound
}
