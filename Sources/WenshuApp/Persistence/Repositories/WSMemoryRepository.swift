//
//  Persistence/Repositories/WSMemoryRepository.swift · Wenshu · v0.72 SwiftData migration Phase 2
//
//  Migration commit 22 of 42: WSMemoryRepository.
//  Per AGENTS.md §11.4 + .scratch/2026-09-13-swiftdata-migration-spec.md.
//
//  Thin wrapper that exposes the same public API as MemoryStore actor
//  (= v0.18 ticket 01 SQLite long-term memory, hermes mem0 port).
//
//  Public API (preserved 1:1 from old MemoryStore actor):
//    - add(userId:content:) throws -> Memory
//    - search(userId:query:limit:) throws -> [Memory]
//    - get(memoryId:) throws -> Memory?
//    - update(memoryId:content:) throws
//    - delete(memoryId:) throws
//    - count(userId:) throws -> Int
//    - listRecent(userId:limit:) throws -> [Memory]
//    - purgeOlderThan(userId:retentionDays:) throws -> Int
//
//  Implementation: SwiftData @Model WSMemory → Memory struct (= the
//  old Domain.Memory type, = unchanged).
//
//  Phase 5 ticket 8 deleted MemoryStore.swift; = WSMemoryRepository
//  is now the sole canonical memory persistence (= @MainActor
//  SwiftData wrapper for WSMemory @Model class).

import Foundation
import SwiftData

@MainActor
public final class WSMemoryRepository {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    public init(container: ModelContainer = WSPersistenceContainer.shared) {
        self.container = container
    }

    public func add(userId: String, content: String) throws -> Memory {
        let memoryID = UUID().uuidString
        let model = WSMemory(memoryID: memoryID, userID: userId, content: content)
        context.insert(model)
        try context.save()
        return Memory(
            userId: userId,
            memoryId: memoryID,
            content: content,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }

    public func get(memoryId: String) throws -> Memory? {
        let descriptor = FetchDescriptor<WSMemory>(
            predicate: #Predicate { $0.memoryID == memoryId }
        )
        return try context.fetch(descriptor).first.map { model in
            Memory(
                userId: model.userID,
                memoryId: model.memoryID,
                content: model.content,
                createdAt: model.createdAt,
                updatedAt: model.updatedAt
            )
        }
    }

    public func search(userId: String, query: String, limit: Int = 10) throws -> [Memory] {
        let descriptor = FetchDescriptor<WSMemory>(
            predicate: #Predicate { mem in
                mem.userID == userId && mem.content.localizedStandardContains(query)
            },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).prefix(limit).map { model in
            Memory(
                userId: model.userID,
                memoryId: model.memoryID,
                content: model.content,
                createdAt: model.createdAt,
                updatedAt: model.updatedAt
            )
        }
    }

    public func update(memoryId: String, content: String) throws {
        let descriptor = FetchDescriptor<WSMemory>(
            predicate: #Predicate { $0.memoryID == memoryId }
        )
        guard let model = try context.fetch(descriptor).first else {
            throw WSMemoryRepositoryError.notFound
        }
        model.update(content: content)
        try context.save()
    }

    public func delete(memoryId: String) throws {
        let descriptor = FetchDescriptor<WSMemory>(
            predicate: #Predicate { $0.memoryID == memoryId }
        )
        if let model = try context.fetch(descriptor).first {
            context.delete(model)
            try context.save()
        }
    }

    public func count(userId: String) throws -> Int {
        let descriptor = FetchDescriptor<WSMemory>(
            predicate: #Predicate { $0.userID == userId }
        )
        return try context.fetchCount(descriptor)
    }

    public func listRecent(userId: String, limit: Int = 20) throws -> [Memory] {
        let descriptor = FetchDescriptor<WSMemory>(
            predicate: #Predicate { $0.userID == userId },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).prefix(limit).map { model in
            Memory(
                userId: model.userID,
                memoryId: model.memoryID,
                content: model.content,
                createdAt: model.createdAt,
                updatedAt: model.updatedAt
            )
        }
    }

    public func purgeOlderThan(userId: String, retentionDays: Int) throws -> Int {
        let cutoff = Date().addingTimeInterval(-Double(retentionDays) * 86400)
        let descriptor = FetchDescriptor<WSMemory>(
            predicate: #Predicate { mem in
                mem.userID == userId && mem.updatedAt < cutoff
            }
        )
        let old = try context.fetch(descriptor)
        for model in old {
            context.delete(model)
        }
        try context.save()
        return old.count
    }
}

/// Repository-specific error (= distinct from MemoryStoreError; = Phase 3
/// switch will require call sites to handle this error type).
public enum WSMemoryRepositoryError: Error {
    case notFound
}
