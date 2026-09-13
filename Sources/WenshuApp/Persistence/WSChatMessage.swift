//
//  Persistence/WSChatMessage.swift · Wenshu · v0.72 SwiftData migration Phase 1
//
//  Migration commit 12 of 21 @Model classes: WSChatMessage adds the
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
final class WSChatMessage {
    @Attribute(.unique) var id: String
    /// FK to WSSession.sessionID (= string FK, = legacy)
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

    /// Inverse relationship target (= declared on WSSession via @Relationship(inverse:))
    var session: WSSession?

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
