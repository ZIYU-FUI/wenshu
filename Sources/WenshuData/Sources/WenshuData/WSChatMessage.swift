//
//  Persistence/WSChatMessage.swift
//
//   : WSChatMessage adds the
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
    public var sessionID: String
    // chat-by-book row-level split: denormalized bookID copied from
    // the parent WSSession at write time. Why denormalize (= avoid
    // relying on `$0.session?.bookID` keyPath in SwiftData #Predicate
    // macros, which has historic fragility across SDK versions):
    // each message row carries its own bookID, matching the
    // WSChatMessage.sessionID pattern (= FK by convention).
    //
    // Invariant (= maintained by WSChatRepository.append): message.bookID
    // MUST equal session.bookID for the session this message belongs to.
    // WSChatRepository.append verifies this via getSession before insert
    // and throws WSChatRepositoryError on mismatch.
    //
    // nil = global un-attached (= session was created without a book).
    public var bookID: String?
    public var role: String
    public var status: String
    public var content: String
    // assistant reasoning content was streaming into parts[] in memory
    // but never persisted to SwiftData (= on reload from the
    // warehouse, the parts[] was empty and the thinking section
    // collapsed to zero bytes). New string column (= nullable for
    // pre-v1.65-cleanup messages; = SwiftData auto-handles additive
    // schema changes for optional stored properties; = no migration
    // step required for existing user libraries). Stores the joined
    // reasoning part text (= multiple reasoning blocks joined by
    // '\n\n'; = the streaming path emits
    // separate .reasoning parts, = persistence collapses them into
    // one thinking string for fast restore).
    public var thinking: String?
    public var model: String?
    public var toolCallsJSON: String?
    public var toolResultsJSON: String?
    public var tokenCount: Int
    public var position: Int
    public var createdAt: Date
    public var updatedAt: Date

    /// Inverse relationship target (= declared on WSSession via @Relationship(inverse:))
    public var session: WSSession?

    public init(id: String, sessionID: String, role: String, content: String, position: Int, status: String = "ok", thinking: String? = nil, bookID: String? = nil) {
        self.id = id
        self.sessionID = sessionID
        self.role = role
        self.status = status
        self.content = content
        self.position = position
        self.tokenCount = -1
        self.thinking = thinking
        self.bookID = bookID
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
