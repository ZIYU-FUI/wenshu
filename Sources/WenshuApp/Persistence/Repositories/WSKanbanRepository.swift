//
//  Persistence/Repositories/WSKanbanRepository.swift
//
//  v3.1 governance A1 refactor (= boundary probe 5/8).
//  Apple canonical layering per Backyard Birds:
//    - write API = domain-in/domain-out (Repository converts
//      KanbanTask -> WSKanbanTask @Model internally, returns the
//      persisted domain type for fresh inserts).
//    - read  API = @Model out (caller converts WSKanbanTask -> KanbanTask).
//
//  Public API after A1 probe:
//    - add(...) throws -> KanbanTask                      (write: domain-in/domain-out)
//    - transition(id:to:) throws                        (KanbanStatus in, no return)
//    - get(id:) throws -> WSKanbanTask?                 (read:  raw @Model out)
//    - list(status:) throws -> [WSKanbanTask]            (read:  raw @Model out)
//    - delete(id:) throws
//    - count(status:) throws -> Int
//
//  Per AGENTS.md §11.4. Mapping (via static toDomain):
//    KanbanStatus rawValue = "new"/"triage"/"ready"/"running"/"blocked"/"review"/"done"/"failed"
//
//  Note on sendability: WSKanbanTask (PersistentModel) is NOT Sendable.
//  Caller must convert INSIDE the @MainActor scope (e.g. inside
//  MainActor.run {}) or use Sendable scalar tuples across actor boundary.

import Foundation
import SwiftData

@MainActor
final class WSKanbanRepository {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init(container: ModelContainer = WSPersistenceContainer.shared) {
        self.container = container
    }

    func add(
        title: String,
        status: KanbanStatus = .new,
        priority: Int = 5,
        assignee: String? = nil,
        modelOverride: String? = nil,
        body: String? = nil
    ) throws -> KanbanTask {
        let id = UUID().uuidString
        let now = Date()
        let model = WSKanbanTask(
            id: id,
            title: title,
            status: status.rawValue,
            priority: priority,
            assignee: assignee,
            modelOverride: modelOverride,
            body: body
        )
        // Lifecycle hooks ( parity with legacy KanbanStore actor:
        // startedAt auto-set when status = .running at add time, completedAt
        // auto-set when status = .done or .failed at add time).
        if status == .running {
            model.startedAt = now
        } else if status == .done || status == .failed {
            model.completedAt = now
        }
        context.insert(model)
        try context.save()
        return Self.toDomain(model)
    }

    func transition(id: String, to newStatus: KanbanStatus) throws {
        let descriptor = FetchDescriptor<WSKanbanTask>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try context.fetch(descriptor).first else {
            throw WSKanbanRepositoryError.notFound
        }
        model.status = newStatus.rawValue
        model.updatedAt = Date()
        // Lifecycle hooks
        switch newStatus {
        case .running:
            if model.startedAt == nil {
                model.startedAt = Date()
            }
        case .done, .failed:
            if model.completedAt == nil {
                model.completedAt = Date()
            }
        default:
            break
        }
        try context.save()
    }

    func get(id: String) throws -> WSKanbanTask? {
        let descriptor = FetchDescriptor<WSKanbanTask>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }

    func list(status: KanbanStatus? = nil) throws -> [WSKanbanTask] {
        let descriptor: FetchDescriptor<WSKanbanTask>
        if let status = status {
            descriptor = FetchDescriptor<WSKanbanTask>(
                predicate: #Predicate { $0.status == status.rawValue },
                sortBy: [SortDescriptor(\.priority, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<WSKanbanTask>(
                sortBy: [SortDescriptor(\.priority, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)]
            )
        }
        return try context.fetch(descriptor)
    }

    func delete(id: String) throws {
        let descriptor = FetchDescriptor<WSKanbanTask>(
            predicate: #Predicate { $0.id == id }
        )
        if let model = try context.fetch(descriptor).first {
            context.delete(model)
            try context.save()
        }
    }

    func count(status: KanbanStatus? = nil) throws -> Int {
        let descriptor: FetchDescriptor<WSKanbanTask>
        if let status = status {
            descriptor = FetchDescriptor<WSKanbanTask>(
                predicate: #Predicate { $0.status == status.rawValue }
            )
        } else {
            descriptor = FetchDescriptor<WSKanbanTask>()
        }
        return try context.fetchCount(descriptor)
    }

    /// A1 boundary bridge (Sendable-safe; = static nonisolated).
    nonisolated private static func toDomain(_ model: WSKanbanTask) -> KanbanTask {
        KanbanTask(
            id: model.id,
            title: model.title,
            status: KanbanStatus(rawValue: model.status) ?? .new,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt,
            priority: model.priority,
            assignee: model.assignee,
            startedAt: model.startedAt,
            completedAt: model.completedAt,
            modelOverride: model.modelOverride,
            body: model.body
        )
    }
}

enum WSKanbanRepositoryError: Error {
    case notFound
}

extension WSKanbanRepositoryError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Kanban task not found."
        }
    }
}
