//
//  Persistence/Repositories/WSTodoRepository.swift · Wenshu · v0.72 SwiftData migration 
//
//  Migration commit 24 of 42: WSTodoRepository.
//  Per AGENTS.md §11.4.
//
//  Thin wrapper for TodoStore actor (= v0.18 ticket 06).
//
//  Public API (preserved 1:1 from old TodoStore actor):
//    - add(title:priority:dueDate:) throws -> TodoItem
//    - add(id:title:priority:dueDate:) throws -> TodoItem
//    - setStatus(id:status:) throws
//    - get(id:) throws -> TodoItem?
//    - list(status:orderByPriority:) throws -> [TodoItem]
//    - delete(id:) throws
//    - count(status:) throws -> Int
//
//  Domain types (preserved): TodoItem, TodoStatus, TodoPriority
//  Mapping: TodoStatus ↔ WSTodo.status (string "pending" / "in_progress" / "completed" / "cancelled")
//           TodoPriority (enum) ↔ WSTodo.priority (Int 0/1/2/3)

import Foundation
import SwiftData

@MainActor
final class WSTodoRepository {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init(container: ModelContainer = WSPersistenceContainer.shared) {
        self.container = container
    }

    func add(title: String, priority: TodoPriority = .medium, dueDate: Date? = nil) throws -> TodoItem {
        return try add(id: UUID().uuidString, title: title, priority: priority, dueDate: dueDate)
    }

    func add(id: String, title: String, priority: TodoPriority = .medium, dueDate: Date? = nil) throws -> TodoItem {
        let model = WSTodo(id: id, title: title)
        model.status = TodoStatus.pending.rawValue
        model.priority = priority.rawValue
        model.dueDate = dueDate
        context.insert(model)
        try context.save()
        return TodoItem(
            id: model.id,
            title: model.title,
            status: TodoStatus(rawValue: model.status) ?? .pending,
            priority: TodoPriority(rawValue: model.priority) ?? .medium,
            dueDate: model.dueDate,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }

    func setStatus(id: String, status: TodoStatus) throws {
        let descriptor = FetchDescriptor<WSTodo>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try context.fetch(descriptor).first else {
            throw WSTodoRepositoryError.notFound
        }
        model.updateStatus(status.rawValue)
        try context.save()
    }

    func get(id: String) throws -> TodoItem? {
        let descriptor = FetchDescriptor<WSTodo>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first.map { model in
            TodoItem(
                id: model.id,
                title: model.title,
                status: TodoStatus(rawValue: model.status) ?? .pending,
                priority: TodoPriority(rawValue: model.priority) ?? .medium,
                dueDate: model.dueDate,
                createdAt: model.createdAt,
                updatedAt: model.updatedAt
            )
        }
    }

    func list(status: TodoStatus? = nil, orderByPriority: Bool = true) throws -> [TodoItem] {
        let descriptor: FetchDescriptor<WSTodo>
        if let status = status {
            descriptor = FetchDescriptor<WSTodo>(
                predicate: #Predicate { $0.status == status.rawValue },
                sortBy: orderByPriority
                    ? [SortDescriptor(\.priority, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)]
                    : [SortDescriptor(\.createdAt, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<WSTodo>(
                sortBy: orderByPriority
                    ? [SortDescriptor(\.priority, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)]
                    : [SortDescriptor(\.createdAt, order: .reverse)]
            )
        }
        return try context.fetch(descriptor).map { model in
            TodoItem(
                id: model.id,
                title: model.title,
                status: TodoStatus(rawValue: model.status) ?? .pending,
                priority: TodoPriority(rawValue: model.priority) ?? .medium,
                dueDate: model.dueDate,
                createdAt: model.createdAt,
                updatedAt: model.updatedAt
            )
        }
    }

    func delete(id: String) throws {
        let descriptor = FetchDescriptor<WSTodo>(
            predicate: #Predicate { $0.id == id }
        )
        if let model = try context.fetch(descriptor).first {
            context.delete(model)
            try context.save()
        }
    }

    func count(status: TodoStatus? = nil) throws -> Int {
        let descriptor: FetchDescriptor<WSTodo>
        if let status = status {
            descriptor = FetchDescriptor<WSTodo>(
                predicate: #Predicate { $0.status == status.rawValue }
            )
        } else {
            descriptor = FetchDescriptor<WSTodo>()
        }
        return try context.fetchCount(descriptor)
    }
}

enum WSTodoRepositoryError: Error {
    case notFound
}

extension WSTodoRepositoryError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Todo not found."
        }
    }
}
