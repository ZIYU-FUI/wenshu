//
//  Persistence/WSChatMessage.swift · Wenshu · v0.72 SwiftData migration Phase 1
//
//  Migration commit 11 of 21 @Model classes: WSChatMessage.
//  Mirrors `chat_messages` table from ChatSessionStore.swift.
//
//  Note: No @Relationship to WSSession in this commit (= SwiftData
//  circular reference prevention; = a follow-up commit will add the
//  @Relationship once both sides have compatible keyPath declarations).
//  For now, the FK is `sessionID: String` (= matches old sqlite3).

import Foundation
import SwiftData

@Model
final class WSChatMessage {
    @Attribute(.unique) var id: String
    /// FK to WSSession.sessionID (= string FK, = matches old sqlite3)
    var sessionID: String
    var role: String
    var status: String
    var content: String
    var model: String?
    var toolCallsJSON: String?
    var toolResultsJSON: String?
    var tokenCount: Int
    var position: Int
    var createdAt: Date
    var updatedAt: Date

    init(id: String, sessionID: String, role: String, content: String, position: Int, status: String = "ok") {
        self.id = id
        self.sessionID = sessionID
        self.role = role
        self.status = status
        self.content = content
        self.position = position
        self.tokenCount = -1
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
