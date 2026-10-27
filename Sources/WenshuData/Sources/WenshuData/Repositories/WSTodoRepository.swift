//
//  Persistence/Repositories/WSTodoRepository.swift
//
//  Apple canonical layering per Backyard Birds:
//    - write API = raw fields in (= no app-side TodoStatus / TodoPriority
//      / TodoItem domain type; = caller converts to raw String status
//      and raw Int priority before calling; = caller consumes the
//      returned WSTodo inside MainActor scope).
//    - read  API = raw WSTodo out (= caller does the
//      WSTodo -> TodoItem conversion at the boundary).
//
//    - add(title:priority:dueDate:) throws -> WSTodo        (write: raw fields in, raw @Model out)
//    - add(id:title:priority:dueDate:) throws -> WSTodo
//    - setStatus(id:status:) throws                       (String status in, no return)
//    - get(id:) throws -> WSTodo?                         (read:  raw @Model out)
//    - list(status:orderByPriority:) throws -> [WSTodo]
//    - delete(id:) throws
//    - count(status:) throws -> Int
//
//  Per AGENTS.md §11.4. Mapping (caller-side owns the conversion):
//    TodoStatus rawValue = "pending" / "in_progress" / "completed" / "cancelled"
//    TodoPriority rawValue = Int 0..3 (= TodoPriority enum's raw value
//      is also Int, = 1:1 mapping with no further conversion needed).
//
//  Note on sendability: WSTodo (PersistentModel) is NOT Sendable, so
//  read-API results must not cross actor boundaries. TodoStoreTool
//  already runs read calls inside `MainActor.run { ... }` and only
//  forwards Sendable scalar fields (`id`, `status`, `priority`, etc.) in
//  its JSON response, so the boundary is kept clean.

import Foundation
import SwiftData

@MainActor
public final class WSTodoRepository {
    /// The store this repository reads and writes.
    ///
    /// A named container (= a test, an isolated run) is used as it is.
    /// Without one the repository reads and writes the app's live store
    /// (= the warehouse once it is activated), resolved per operation:
    /// the live store changes when the warehouse is activated, so a
    /// repository built before that moment must not keep the store it
    /// saw at construction time.
    public let store: WSStore
    private var context: ModelContext { store.context }

    public init(container: ModelContainer? = nil) {
        self.store = WSStore(container: container)
    }

    public func add(title: String, priority: Int = 1, dueDate: Date? = nil) throws -> WSTodo {
        return try add(id: UUID().uuidString, title: title, priority: priority, dueDate: dueDate)
    }

    public func add(id: String, title: String, priority: Int = 1, dueDate: Date? = nil) throws -> WSTodo {
        let model = WSTodo(id: id, title: title)
        model.status = "pending"
        model.priority = priority
        model.dueDate = dueDate
        context.insert(model)
        try context.save()
        return model
    }

    public func setStatus(id: String, status: String) throws {
        let descriptor = FetchDescriptor<WSTodo>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try context.fetch(descriptor).first else {
            throw WSTodoRepositoryError.notFound
        }
        model.updateStatus(status)
        try context.save()
    }

    public func get(id: String) throws -> WSTodo? {
        let descriptor = FetchDescriptor<WSTodo>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }

    public func list(status: String? = nil, orderByPriority: Bool = true) throws -> [WSTodo] {
        let descriptor: FetchDescriptor<WSTodo>
        if let status {
            descriptor = FetchDescriptor<WSTodo>(
                predicate: #Predicate { $0.status == status },
                sortBy: orderByPriority
                    ? [SortDescriptor(\.priority, order: .forward), SortDescriptor(\.createdAt, order: .reverse)]
                    : [SortDescriptor(\.createdAt, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<WSTodo>(
                sortBy: orderByPriority
                    ? [SortDescriptor(\.priority, order: .forward), SortDescriptor(\.createdAt, order: .reverse)]
                    : [SortDescriptor(\.createdAt, order: .reverse)]
            )
        }
        return try context.fetch(descriptor)
    }

    public func delete(id: String) throws {
        let descriptor = FetchDescriptor<WSTodo>(
            predicate: #Predicate { $0.id == id }
        )
        if let model = try context.fetch(descriptor).first {
            context.delete(model)
            try context.save()
        }
    }

    public func count(status: String? = nil) throws -> Int {
        let descriptor: FetchDescriptor<WSTodo>
        if let status {
            descriptor = FetchDescriptor<WSTodo>(
                predicate: #Predicate { $0.status == status }
            )
        } else {
            descriptor = FetchDescriptor<WSTodo>()
        }
        return try context.fetchCount(descriptor)
    }
}

public enum WSTodoRepositoryError: Error {
    case notFound
}

extension WSTodoRepositoryError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notFound:
            return "Todo not found."
        }
    }
}
