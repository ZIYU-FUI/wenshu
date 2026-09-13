//
//  Persistence/WSSession.swift · Wenshu · v0.72 SwiftData migration Phase 1
//
//  Updated in commit 13 to add @Relationship to WSSummary.

import Foundation
import SwiftData

@Model
final class WSSession {
    @Attribute(.unique) var sessionID: String
    var title: String?
    var createdAt: Date
    var updatedAt: Date
    var archivedAt: Date?

    /// 1↔N WSChatMessage via inverse = child.session
    @Relationship(deleteRule: .cascade, inverse: \WSChatMessage.session)
    var messages: [WSChatMessage] = []

    /// 1↔1 WSSummary via inverse = WSSummary.session
    @Relationship(deleteRule: .cascade, inverse: \WSSummary.session)
    var summary: WSSummary?

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
