//
//  Persistence/Repositories/WSMemoryRepository.swift
//
//  Apple canonical layering per Backyard Birds:
//    - write API = raw fields in (= no app-side MemoryID / Memory
//      domain type; = caller converts MemoryID -> String rawValue
//      before calling; = caller consumes the returned WSMemory
//      inside MainActor scope).
//    - read  API = raw WSMemory out (= caller does the
//      WSMemory -> Memory conversion at the boundary).
//
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
public final class WSMemoryRepository {
    /// How many of the user's memories a search ranks (= the candidate
    /// pool; = the most recent ones, = the ones a question about the
    /// current work is about).
    static let candidatePoolSize = 500

    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    public init(container: ModelContainer = WSPersistenceContainer.shared) {
        self.container = container
    }

    public func add(userId: String, content: String, memoryID: String? = nil) throws -> WSMemory {
        let memoryIDString = memoryID ?? UUID().uuidString
        let model = WSMemory(memoryID: memoryIDString, userID: userId, content: content)
        context.insert(model)
        try context.save()
        return model
    }

    public func get(memoryID: String) throws -> WSMemory? {
        let descriptor = FetchDescriptor<WSMemory>(
            predicate: #Predicate { $0.memoryID == memoryID }
        )
        return try context.fetch(descriptor).first
    }

    /// The memories that answer a query.
    ///
    /// The query is a SET of terms, not a substring: the retrieval
    /// used to ask whether the whole query string was a literal
    /// substring of the memory, so a question ("what did the third
    /// scene of this chapter say?") answered nothing every time and
    /// the constraints never reached the context. The memories are
    /// ranked by how many of the terms they carry, and the recency
    /// breaks a tie.
    ///
    /// A blank query asks for the most recent memories (= the
    /// caller's "give me the context" call; = not a search).
    public func search(userId: String, query: String, limit: Int = 10) throws -> [WSMemory] {
        var descriptor = FetchDescriptor<WSMemory>(
            predicate: #Predicate { mem in mem.userID == userId },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        // The ranking happens in memory (= SwiftData cannot compare
        // term overlap), so the candidate pool is bounded: the
        // memories the user wrote most recently.
        descriptor.fetchLimit = Self.candidatePoolSize
        let candidates = try context.fetch(descriptor)

        let terms = MemorySearchTerms(query)
        guard !terms.isEmpty else {
            return Array(candidates.prefix(limit))
        }

        var scored: [(memory: WSMemory, score: Double)] = []
        for memory in candidates {
            let score = terms.score(content: memory.content)
            if score > 0 {
                scored.append((memory, score))
            }
        }
        scored.sort { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.memory.updatedAt > rhs.memory.updatedAt
            }
            return lhs.score > rhs.score
        }
        return Array(scored.prefix(limit).map(\.memory))
    }

    public func update(memoryID: String, content: String) throws {
        let descriptor = FetchDescriptor<WSMemory>(
            predicate: #Predicate { $0.memoryID == memoryID }
        )
        guard let model = try context.fetch(descriptor).first else {
            throw WSMemoryRepositoryError.notFound
        }
        model.update(content: content)
        try context.save()
    }

    public func delete(memoryID: String) throws {
        let descriptor = FetchDescriptor<WSMemory>(
            predicate: #Predicate { $0.memoryID == memoryID }
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

    public func listRecent(userId: String, limit: Int = 20) throws -> [WSMemory] {
        let descriptor = FetchDescriptor<WSMemory>(
            predicate: #Predicate { $0.userID == userId },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).prefix(limit).map { $0 }
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

/// Repository-specific error (= distinct from the pre-Phase-5
/// MemoryStore actor error; =
/// switch will require call sites to handle this error type).
public enum WSMemoryRepositoryError: Error {
    case notFound
}

extension WSMemoryRepositoryError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notFound:
            return "Memory entry not found."
        }
    }
}
