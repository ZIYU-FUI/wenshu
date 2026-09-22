//
//  Persistence/WSChatMessage.swift · Wenshu · v0.72 SwiftData migration Phase 1
//
//  Phase 1 commit 12/21: WSChatMessage adds the
//  child-side `session` property (= plain Optional, NOT @Relationship;
//  = the parent WSSession declares @Relationship(inverse:) referring
//  back to this property).
//
//  This pattern (= one-sided @Relationship with keyPath inverse) avoids
//  the SwiftData circular reference issue (= both files compile because
//  the keyPath is resolved at macro expansion time, but no second
//  @Relationship attribute is needed here).

import Foundation
import SwiftData

@Model
public final class WSChatMessage {
    @Attribute(.unique) public var id: String
    /// FK to WSSession.sessionID (= string FK, = legacy)
    var sessionID: String
    var role: String
    var status: String
    var content: String
    // v1.65-cleanup E2 boss 2026-09-21 OOB 'AI 思考过程不显示' (= the
    // assistant reasoning content was streaming into parts[] in memory
    // but never persisted to SwiftData; = on reload from the warehouse
    // .ws/WenshuStore.store, the parts[] was empty and the
    // thinking section collapsed to zero bytes). New string column
    // (= nullable for pre-v1.65-cleanup messages; = SwiftData
    // auto-handles additive schema changes for optional stored
    // properties; = no migration step required for existing user
    // libraries). Stores the joined reasoning part text (= multiple
    // reasoning blocks joined by '\n\n'; = the streaming path emits
    // separate .reasoning parts, = persistence collapses them into
    // one thinking string for fast restore).
    var thinking: String?
    var model: String?
    var toolCallsJSON: String?
    var toolResultsJSON: String?
    var tokenCount: Int
    var position: Int
    var createdAt: Date
    var updatedAt: Date

    /// Inverse relationship target (= declared on WSSession via @Relationship(inverse:))
    var session: WSSession?

    init(id: String, sessionID: String, role: String, content: String, position: Int, status: String = "ok", thinking: String? = nil) {
        self.id = id
        self.sessionID = sessionID
        self.role = role
        self.status = status
        self.content = content
        self.position = position
        self.tokenCount = -1
        self.thinking = thinking
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
