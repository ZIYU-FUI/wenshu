//
//  Persistence/Repositories/WSMemoryRepository.swift · Wenshu · v0.72 SwiftData migration 
//
//  Thin wrapper that exposes the same public API as the prior
//  MemoryStore actor (= hermes mem0 port).
//
//  Public API (preserved 1:1):
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
//  canonical Domain.Memory type, unchanged).
//
//  WSMemoryRepository is the canonical memory persistence
//  (@MainActor SwiftData wrapper for WSMemory @Model class).

import Foundation
import SwiftData

@MainActor
final class WSMemoryRepository {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init(container: ModelContainer = WSPersistenceContainer.shared) {
        self.container = container
    }

    func add(userId: String, content: String, memoryID: MemoryID? = nil) throws -> Memory {
        let resolvedMemoryID = memoryID ?? MemoryID.newID()
        let memoryIDString = resolvedMemoryID.rawValue
        let model = WSMemory(memoryID: memoryIDString, userID: userId, content: content)
        context.insert(model)
        try context.save()
        return Memory(
            userId: userId,
            memoryId: resolvedMemoryID,
            content: content,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }

    func get(memoryId: MemoryID) throws -> Memory? {
        let descriptor = FetchDescriptor<WSMemory>(
            predicate: #Predicate { $0.memoryID == memoryId.rawValue }
        )
        return try context.fetch(descriptor).first.map { model in
            Memory(
                userId: model.userID,
                memoryId: MemoryID(rawValue: model.memoryID),
                content: model.content,
                createdAt: model.createdAt,
                updatedAt: model.updatedAt
            )
        }
    }

    func search(userId: String, query: String, limit: Int = 10) throws -> [Memory] {
        let descriptor = FetchDescriptor<WSMemory>(
            predicate: #Predicate { mem in
                mem.userID == userId && mem.content.localizedStandardContains(query)
            },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).prefix(limit).map { model in
            Memory(
                userId: model.userID,
                memoryId: MemoryID(rawValue: model.memoryID),
                content: model.content,
                createdAt: model.createdAt,
                updatedAt: model.updatedAt
            )
        }
    }

    func update(memoryId: MemoryID, content: String) throws {
        let descriptor = FetchDescriptor<WSMemory>(
            predicate: #Predicate { $0.memoryID == memoryId.rawValue }
        )
        guard let model = try context.fetch(descriptor).first else {
            throw WSMemoryRepositoryError.notFound
        }
        model.update(content: content)
        try context.save()
    }

    func delete(memoryId: MemoryID) throws {
        let descriptor = FetchDescriptor<WSMemory>(
            predicate: #Predicate { $0.memoryID == memoryId.rawValue }
        )
        if let model = try context.fetch(descriptor).first {
            context.delete(model)
            try context.save()
        }
    }

    func count(userId: String) throws -> Int {
        let descriptor = FetchDescriptor<WSMemory>(
            predicate: #Predicate { $0.userID == userId }
        )
        return try context.fetchCount(descriptor)
    }

    func listRecent(userId: String, limit: Int = 20) throws -> [Memory] {
        let descriptor = FetchDescriptor<WSMemory>(
            predicate: #Predicate { $0.userID == userId },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).prefix(limit).map { model in
            Memory(
                userId: model.userID,
                memoryId: MemoryID(rawValue: model.memoryID),
                content: model.content,
                createdAt: model.createdAt,
                updatedAt: model.updatedAt
            )
        }
    }

    func purgeOlderThan(userId: String, retentionDays: Int) throws -> Int {
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

/// Repository-specific error (= distinct from the pre-Phase-5
/// MemoryStore actor error; = 
/// switch will require call sites to handle this error type).
enum WSMemoryRepositoryError: Error {
    case notFound
}

extension WSMemoryRepositoryError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Memory entry not found."
        }
    }
}
