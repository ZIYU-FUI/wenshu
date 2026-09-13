//
//  Persistence/WSSession.swift · Wenshu · v0.72 SwiftData migration Phase 1
//
//  Phase 1 commit 10/21: WSSession.
//  Updated in phase 1 commit 14 to add @Relationship to WSSubAgentRun.

import Foundation
import SwiftData

@Model
public final class WSSession {
    @Attribute(.unique) var sessionID: String
    var title: String?
    var createdAt: Date
    var updatedAt: Date
    var archivedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \WSChatMessage.session)
    var messages: [WSChatMessage] = []

    @Relationship(deleteRule: .cascade, inverse: \WSSummary.session)
    var summary: WSSummary?

    @Relationship(deleteRule: .cascade, inverse: \WSSubAgentRun.session)
    var subAgentRuns: [WSSubAgentRun] = []

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
