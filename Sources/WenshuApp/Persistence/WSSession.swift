//
//  Persistence/WSSession.swift · Wenshu · v0.72 SwiftData migration Phase 1
//
//  Migration commit 10 of 21 @Model classes: WSSession.
//  Mirrors `chat_sessions` table from ChatSessionStore.swift (= v0.18 ticket 04
//  local chat history; = hermes chat_history_table.py 1:1 port).
//
//  WSSession is a chat session grouping (= a chat has 1+ sessions).
//
//  IMPORTANT: This commit defines WSSession WITHOUT @Relationship children.
//  The children (WSChatMessage, WSSummary, WSSubAgentRun) land in subsequent
//  commits and will add their inverse @Relationship at that time (= SwiftData
//  requires both sides to compile together, so we land them in pairs):
//
//    commit 10: WSSession (this file)
//    commit 11: WSChatMessage (1↔N messages) + inverse back to WSSession
//    commit 12: WSSummary (1↔1 summary) + inverse
//    commit 13: WSSubAgentRun (1↔N subAgentRuns) + inverse
//
//  Until then, foreign keys are stored as optional strings (= sessionID).
//  This pattern matches the old sqlite3 schema (= it was already string-FK
//  not enforced).

import Foundation
import SwiftData

@Model
final class WSSession {
    @Attribute(.unique) var sessionID: String
    /// "default" for the main session; otherwise hermes-generated UUID string
    var title: String?
    var createdAt: Date
    var updatedAt: Date
    var archivedAt: Date?

    init(sessionID: String, title: String? = nil) {
        self.sessionID = sessionID
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    func archive() {
        self.archivedAt = Date()
        self.updatedAt = Date()
    }
}
