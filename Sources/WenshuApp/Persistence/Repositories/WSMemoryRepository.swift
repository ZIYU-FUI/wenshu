//
//  Persistence/Repositories/WSMemoryRepository.swift
//
//  v3.1 governance A1g.2 step 3/3 (= boundary decouple, A1 probe 7/8
//  layered on top).
//  Apple canonical layering per Backyard Birds:
//    - write API = raw fields in (= no app-side MemoryID / Memory
//      domain type; = caller converts MemoryID -> String rawValue
//      before calling; = caller consumes the returned WSMemory
//      inside MainActor scope).
//    - read  API = raw WSMemory out (= caller does the
//      WSMemory -> Memory conversion at the boundary).
//
//  Public API after A1g.2:
//    - add(userId:content:memoryID:) throws -> WSMemory   (write: raw fields in, raw @Model out)
//    - get(memoryID:) throws -> WSMemory?                  (read:  raw @Model out)
//    - search(userId:query:limit:) throws -> [WSMemory]
//    - listRecent(userId:limit:) throws -> [WSMemory]
//    - update(memoryID:content:) throws
//    - delete(memoryID:) throws
//    - count(userId:) throws -> Int
//    - purgeOlderThan(userId:retentionDays:) throws -> Int
//
//  Per AGENTS.md §11.4. MemoryID is the caller-side domain type;
//  data layer treats it as a raw String. Caller converts at the
//  boundary (= MemoryID(rawValue: model.memoryID) or .rawValue).
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

    func add(userId: String, content: String, memoryID: String? = nil) throws -> WSMemory {
        let memoryIDString = memoryID ?? UUID().uuidString
        let model = WSMemory(memoryID: memoryIDString, userID: userId, content: content)
        context.insert(model)
        try context.save()
        return model
    }

    func get(memoryID: String) throws -> WSMemory? {
        let descriptor = FetchDescriptor<WSMemory>(
            predicate: #Predicate { $0.memoryID == memoryID }
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

    func update(memoryID: String, content: String) throws {
        let descriptor = FetchDescriptor<WSMemory>(
            predicate: #Predicate { $0.memoryID == memoryID }
        )
        guard let model = try context.fetch(descriptor).first else {
            throw WSMemoryRepositoryError.notFound
        }
        model.update(content: content)
        try context.save()
    }

    func delete(memoryID: String) throws {
        let descriptor = FetchDescriptor<WSMemory>(
            predicate: #Predicate { $0.memoryID == memoryID }
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
