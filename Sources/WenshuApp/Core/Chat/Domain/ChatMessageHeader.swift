//
//  ChatMessageHeader.swift · Wenshu · refactor chat-mvvm-3layer C-2
//
//  The "cover page" of one chat turn (= who said it, when, and
//  what source-channel it came from). Lifted out of the monolithic
//  ChatMessage struct so the three layers can hold just the slice
//  they need:
//
//  - UI layer (= ChatMessageView): reads `header` to render avatar
//    + timestamp + role badge. Doesn't touch `body` for routing.
//  - Business layer (= ChatSessionViewModel): holds a full
//    `ChatMessage` (= header + body) and mutates `body` during
//    streaming. The header stays immutable after creation
//    (= id + role + source + timestamp = the message's identity).
//  - Data layer (= ChatRepository): maps `ChatMessageHeader` 1:1
//    onto the leaner `StoredChatMessage` (= §11.4 SwiftData row).
//    The body never crosses the repository boundary
//    (= streaming parts live only in memory; = sealed content
//    collapses into `StoredChatMessage.content`).
//
//  Identity: `id` is held by the header (= the UUID is the message's
//  canonical identifier; = body is a value bag). ChatMessage itself
//  is `Identifiable` via `header.id`.
//
//  Equatable + Sendable: synthesized. All stored fields are
//  value types (`UUID`, `ChatRole`, `ChatSource`, `Date`) so the
//  compiler-synthesized conformance is correct.
//

import Foundation

/// The cover page of one chat turn (= identity + provenance).
/// Immutable after creation.
public struct ChatMessageHeader: Equatable, Sendable, Hashable {
    public let id: UUID
    public let role: ChatRole
    public let source: ChatSource
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        role: ChatRole,
        source: ChatSource = .wenshu,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.source = source
        self.timestamp = timestamp
    }
}
