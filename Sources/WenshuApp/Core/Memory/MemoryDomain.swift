//
//  Core/Memory/MemoryDomain.swift · Wenshu
//
//  Domain types for memory entries.
//  SwiftData-backed persistence lives in Persistence/WSMemory (@Model) and
//  is wrapped by Persistence/Repositories/WSMemoryRepository (@MainActor).
//

import Foundation

struct Memory: Equatable, Sendable {
    let userId: String
    let memoryId: MemoryID
    var content: String
    let createdAt: Date
    var updatedAt: Date

    init(
        userId: String,
        memoryId: MemoryID = MemoryID.newID(),
        content: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.userId = userId
        self.memoryId = memoryId
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}


/// Reserved for future-hook callers (= no consumers yet).
/// Preserved for future callers that want the legacy 4-case error
/// shape from the deleted sqlite3 actor.

