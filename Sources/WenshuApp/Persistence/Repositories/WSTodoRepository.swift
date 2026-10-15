//
//  Persistence/Repositories/WSTodoRepository.swift
//
//  v3.1 governance A1 refactor (= boundary probe 4/8).
//  Apple canonical layering per Backyard Birds:
//    - write API = domain in -> domain out (= Repository converts
//      TodoItem -> WSTodo @Model internally, returns the persisted
//      domain type)
//    - read  API = @Model out (caller converts WSTodo -> TodoItem)
//
//  Public API after A1 probe:
//    - add(title:priority:dueDate:) throws -> TodoItem        (write: domain-in/domain-out)
//    - add(id:title:priority:dueDate:) throws -> TodoItem
//    - setStatus(id:status:) throws                       (TodoStatus in, no return)
//    - get(id:) throws -> WSTodo?                         (read:  raw @Model out)
//    - list(status:orderByPriority:) throws -> [WSTodo]
//    - delete(id:) throws
//    - count(status:) throws -> Int
//
//  Per AGENTS.md §11.4. Mapping (via static toDomain):
//    TodoStatus rawValue = "pending"/"in_progress"/"completed"/"cancelled"
//    TodoPriority rawValue = Int 0..3.
//
//  Note on sendability: WSTodo (PersistentModel) is NOT Sendable, so
//  read-API results must not cross actor boundaries. TodoStoreTool
//  already runs read calls inside `MainActor.run { ... }` and only
//  forwards Sendable scalar fields (`id`, `status`, `priority`, etc.) in
//  its JSON response, so the boundary is kept clean.

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
        return Self.toDomain(model)
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

    func get(id: String) throws -> WSTodo? {
        let descriptor = FetchDescriptor<WSTodo>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }

    func list(status: TodoStatus? = nil, orderByPriority: Bool = true) throws -> [WSTodo] {
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
        return try context.fetch(descriptor)
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

    /// A1 boundary bridge (= caller-side converter Sendable-safe).
    nonisolated private static func toDomain(_ model: WSTodo) -> TodoItem {
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
