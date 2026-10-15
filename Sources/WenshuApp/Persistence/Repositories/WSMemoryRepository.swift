//
//  Persistence/Repositories/WSMemoryRepository.swift
//
//  v3.1 governance A1 refactor (= boundary probe 7/8).
//  Apple canonical layering per Backyard Birds:
//    - write API = domain-in/domain-out (Repository constructs
//      WSMemory @Model internally, returns the persisted Memory).
//    - read  API = @Model out (caller converts WSMemory -> Memory).
//
//  Public API after A1 probe:
//    - add(userId:content:memoryID:) throws -> Memory        (write: domain-in/domain-out)
//    - get(memoryId:) throws -> WSMemory?                  (read:  raw @Model out)
//    - search(userId:query:limit:) throws -> [WSMemory]
//    - listRecent(userId:limit:) throws -> [WSMemory]
//    - update(memoryId:content:) throws                    (MemoryID in, no return)
//    - delete(memoryId:) throws
//    - count(userId:) throws -> Int
//    - purgeOlderThan(userId:retentionDays:) throws -> Int
//
//  Per AGENTS.md §11.4.
//
//  Note on sendability: WSMemory (PersistentModel) is NOT Sendable.
//  Caller must convert INSIDE the @MainActor scope (e.g. inside
//  MainActor.run {}) or use Sendable scalar tuples across actor boundary.

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
        return Self.toDomain(model, memoryID: resolvedMemoryID)
    }

    func get(memoryId: MemoryID) throws -> WSMemory? {
        let descriptor = FetchDescriptor<WSMemory>(
            predicate: #Predicate { $0.memoryID == memoryId.rawValue }
        )
        return try context.fetch(descriptor).first
    }

    func search(userId: String, query: String, limit: Int = 10) throws -> [WSMemory] {
        let descriptor = FetchDescriptor<WSMemory>(
            predicate: #Predicate { mem in
                mem.userID == userId && mem.content.localizedStandardContains(query)
            },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).prefix(limit).map { $0 }
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

    func listRecent(userId: String, limit: Int = 20) throws -> [WSMemory] {
        let descriptor = FetchDescriptor<WSMemory>(
            predicate: #Predicate { $0.userID == userId },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).prefix(limit).map { $0 }
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

    /// A1 boundary bridge (Sendable-safe). Static + nonisolated so the
    /// converter can be called from inside MainActor.run closures without
    /// capturing actor-isolated state.
    nonisolated private static func toDomain(_ model: WSMemory, memoryID: MemoryID? = nil) -> Memory {
        Memory(
            userId: model.userID,
            memoryId: memoryID ?? MemoryID(rawValue: model.memoryID),
            content: model.content,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
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
