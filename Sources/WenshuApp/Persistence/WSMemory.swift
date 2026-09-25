//
//  Persistence/WSMemory.swift · Wenshu · v0.72 SwiftData migration 
//
//  WSMemory mirrors the memories table schema (= hermes mem0 port):
//    - memory_id TEXT PRIMARY KEY
//    - user_id TEXT NOT NULL
//    - content TEXT NOT NULL
//    - created_at REAL NOT NULL
//    - updated_at REAL NOT NULL
//
//  Old code: MemoryStore.swift (raw sqlite3 + actor isolation)
//  New code: SwiftData @Model (= Apple-recommended; = free migration framework)

import Foundation
import SwiftData

@Model
final class WSMemory {
    @Attribute(.unique) var memoryID: String
    var userID: String
    var content: String
    var createdAt: Date
    var updatedAt: Date

    init(memoryID: String, userID: String, content: String) {
        self.memoryID = memoryID
        self.userID = userID
        self.content = content
        // Shared `now` so createdAt and updatedAt are bit-identical
        // on init (= Swift Testing's CI clock is coarser than Date's
        // precision, so two separate Date() calls frequently differ
        // at sub-second ticks).
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }

    /// Touch updatedAt on content edit (= mirrors old MemoryStore.append behavior).
    func update(content newContent: String) {
        self.content = newContent
        self.updatedAt = Date()
    }
}
