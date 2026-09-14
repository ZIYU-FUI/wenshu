//
//  Core/Memory/MemoryDomain.swift · Wenshu · v0.72 SwiftData migration Phase 5 ticket 8
//
//  Domain types (Memory) extracted from the deleted
//  Core/Memory/MemoryStore.swift (= sqlite3 legacy actor, now obsolete).
//
//  These types are the canonical wenshu-side public API surface for memory entries.
//  The SwiftData-backed persistence lives in Persistence/WSMemory (@Model) and is
//  wrapped by Persistence/Repositories/WSMemoryRepository (@MainActor).
//
//  Moved 2026-09-13 (= phase 5 ticket 8 — see AGENTS.md §11.4.2).
//

import Foundation

public struct Memory: Equatable, Sendable {
    public let userId: String
    public let memoryId: String
    public var content: String
    public let createdAt: Date
    public var updatedAt: Date

    public init(userId: String, memoryId: String = UUID().uuidString, content: String, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.userId = userId
        self.memoryId = memoryId
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}


/// Reserved for future-hook callers (= no consumers yet; = the
/// pre-Phase 5 deleted MemoryStore actor's error type was extracted
/// in Phase 5 ticket 8 and renamed here; = currently dead code but
/// preserved for potential future callers that want the legacy
/// 4-case error shape from the old actor's sqlite3 failures).

