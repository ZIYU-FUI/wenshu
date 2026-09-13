//
//  Persistence/Repositories/WSKanbanRepository.swift · Wenshu · v0.72 SwiftData migration Phase 2
//
//  Migration commit 26 of 42: WSKanbanRepository.
//  Per AGENTS.md §11.4.
//
//  Thin wrapper for KanbanStore actor (= v0.23 ticket 013.003).
//
//  Public API (preserved 1:1 from old KanbanStore actor):
//    - add(...) throws -> KanbanTask
//    - transition(id:to:) throws
//    - get(id:) throws -> KanbanTask?
//    - list(status:) throws -> [KanbanTask]
//    - delete(id:) throws
//    - count(status:) throws -> Int
//
//  Domain types (preserved): KanbanTask + KanbanStatus
//
//  Status mapping (KanbanStatus ↔ WSKanbanTask.status string):
//    new / triage / ready / running / blocked / review / done / failed

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
        status: KanbanStatus = .new,
        priority: Int = 5,
        assignee: String? = nil,
        modelOverride: String? = nil
    ) throws -> KanbanTask {
        let id = UUID().uuidString
        let now = Date()
        let model = WSKanbanTask(
            id: id,
            title: title,
            status: status.rawValue,
            priority: priority,
            assignee: assignee,
            modelOverride: modelOverride
        )
        // Lifecycle hooks (Phase 5 ticket 6 parity with legacy KanbanStore actor:
        // startedAt auto-set when status = .running at add time, completedAt
        // auto-set when status = .done or .failed at add time).
        if status == .running {
            model.startedAt = now
        } else if status == .done || status == .failed {
            model.completedAt = now
        }
        context.insert(model)
        try context.save()
        return KanbanTask(
            id: id,
            title: title,
            status: status,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt,
            priority: priority,
            assignee: assignee,
            startedAt: model.startedAt,
            completedAt: model.completedAt,
            modelOverride: modelOverride
        )
    }

    public func transition(id: String, to newStatus: KanbanStatus) throws {
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

    public func get(id: String) throws -> KanbanTask? {
        let descriptor = FetchDescriptor<WSKanbanTask>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first.map { mapToDomain(model: $0) }
    }

    public func list(status: KanbanStatus? = nil) throws -> [KanbanTask] {
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
        return try context.fetch(descriptor).map { mapToDomain(model: $0) }
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

    public func count(status: KanbanStatus? = nil) throws -> Int {
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

    private func mapToDomain(model: WSKanbanTask) -> KanbanTask {
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
            modelOverride: model.modelOverride
        )
    }
}

public enum WSKanbanRepositoryError: Error {
    case notFound
}
