//
//  Persistence/WSMemory.swift · Wenshu · v0.72 SwiftData migration Phase 1
//
//  Migration commit 2 of 21 @Model classes: WSMemory.
//  Per AGENTS.md §11.4 + .scratch/2026-09-13-swiftdata-migration-spec.md.
//
//  WSMemory mirrors the `memories` table from MemoryStore.swift:
//    - memory_id TEXT PRIMARY KEY
//    - user_id TEXT NOT NULL
//    - content TEXT NOT NULL
//    - created_at REAL NOT NULL
//    - updated_at REAL NOT NULL
//
//  Old code: MemoryStore.swift (raw sqlite3 + actor isolation)
//  New code: SwiftData @Model (= Apple-recommended; = free migration framework)
//
//  v0.18 ticket 01 = wenshu local SQLite long-term memory (replica of
//  hermes mem0 platform pattern).

import Foundation
import SwiftData

@Model
public final class WSMemory {
    @Attribute(.unique) var memoryID: String
    var userID: String
    var content: String
    var createdAt: Date
    var updatedAt: Date

    init(memoryID: String, userID: String, content: String) {
        self.memoryID = memoryID
        self.userID = userID
        self.content = content
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Touch updatedAt on content edit (= mirrors old MemoryStore.append behavior).
    func update(content newContent: String) {
        self.content = newContent
        self.updatedAt = Date()
    }
}
