//
//  Persistence/Repositories/WSKanbanRepository.swift
//
//  Apple canonical layering per Backyard Birds:
//    - write API = raw fields in (= no app-side domain type;
//      caller converts KanbanStatus -> String rawValue before calling;
//      caller consumes the returned WSKanbanTask inside MainActor scope).
//    - read  API = raw WSKanbanTask out (= caller does the
//      WSKanbanTask -> KanbanTask conversion at the boundary).
//
//    - add(...) throws -> WSKanbanTask             (write: raw @Model in/out)
//    - transition(id:to: String) throws           (write: raw String status)
//    - get(id:) throws -> WSKanbanTask?            (read:  raw @Model out)
//    - list(status: String?) throws -> [WSKanbanTask]   (read:  raw @Model out)
//    - delete(id:) throws
//    - count(status: String?) throws -> Int
//
//  Per AGENTS.md §11.4. KanbanStatus rawValue values
//  (= caller-side owns the conversion):
//    "new" / "triage" / "ready" / "running" / "blocked" / "review" / "done" / "failed"
//
//  Note on sendability: WSKanbanTask (PersistentModel) is NOT Sendable.
//  Caller must convert INSIDE the @MainActor scope (e.g. inside
//  MainActor.run {}) or use Sendable scalar tuples across actor boundary.

import Foundation
import SwiftData

@MainActor
public final class WSKanbanRepository {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    public init(container: ModelContainer = WSPersistenceContainer.shared) {
        self.container = container
    }

    public func add(
        title: String,
        status: String = "new",
        priority: Int = 5,
        assignee: String? = nil,
        modelOverride: String? = nil,
        body: String? = nil
    ) throws -> String {
        let id = UUID().uuidString
        let now = Date()
        let model = WSKanbanTask(
            id: id,
            title: title,
            status: status,
            priority: priority,
            assignee: assignee,
            modelOverride: modelOverride,
            body: body
        )
        // Lifecycle hooks (parity with legacy KanbanStore actor:
        // startedAt auto-set when status = "running" at add time, completedAt
        // auto-set when status = "done" or "failed" at add time).
        if status == "running" {
            model.startedAt = now
        } else if status == "done" || status == "failed" {
            model.completedAt = now
        }
        context.insert(model)
        try context.save()
        return id
    }

    public func transition(id: String, to newStatus: String) throws {
        let descriptor = FetchDescriptor<WSKanbanTask>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try context.fetch(descriptor).first else {
            throw WSKanbanRepositoryError.notFound
        }
        model.status = newStatus
        model.updatedAt = Date()
        // Lifecycle hooks
        switch newStatus {
        case "running":
            if model.startedAt == nil {
                model.startedAt = Date()
            }
        case "done", "failed":
            if model.completedAt == nil {
                model.completedAt = Date()
            }
        default:
            break
        }
        try context.save()
    }

    public func get(id: String) throws -> WSKanbanTask? {
        let descriptor = FetchDescriptor<WSKanbanTask>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }

    public func list(status: String? = nil) throws -> [WSKanbanTask] {
        let descriptor: FetchDescriptor<WSKanbanTask>
        if let status {
            descriptor = FetchDescriptor<WSKanbanTask>(
                predicate: #Predicate { $0.status == status },
                sortBy: [SortDescriptor(\.priority, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<WSKanbanTask>(
                sortBy: [SortDescriptor(\.priority, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)]
            )
        }
        return try context.fetch(descriptor)
    }

    public func delete(id: String) throws {
        let descriptor = FetchDescriptor<WSKanbanTask>(
            predicate: #Predicate { $0.id == id }
        )
        if let model = try context.fetch(descriptor).first {
            context.delete(model)
            try context.save()
        }
    }

    public func count(status: String? = nil) throws -> Int {
        let descriptor: FetchDescriptor<WSKanbanTask>
        if let status {
            descriptor = FetchDescriptor<WSKanbanTask>(
                predicate: #Predicate { $0.status == status }
            )
        } else {
            descriptor = FetchDescriptor<WSKanbanTask>()
        }
        return try context.fetchCount(descriptor)
    }
}

public enum WSKanbanRepositoryError: Error {
    case notFound
}

extension WSKanbanRepositoryError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notFound:
            return "Kanban task not found."
        }
    }
}
