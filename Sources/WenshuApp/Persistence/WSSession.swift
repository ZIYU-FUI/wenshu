//
//  Persistence/WSSession.swift · Wenshu · v0.72 SwiftData migration Phase 1
//
//  Migration commit 12 of 21 @Model classes: WSSession adds
//  @Relationship to WSChatMessage.
//
//  This commit defines the parent-side @Relationship (with inverse
//  keyPath pointing to WSChatMessage.session). The child's `session`
//  property is a plain Optional (= not @Relationship) — SwiftData
//  accepts this pattern: parent declares @Relationship with inverse,
//  child declares a matching optional property.

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
