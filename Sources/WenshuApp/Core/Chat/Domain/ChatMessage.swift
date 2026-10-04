//
//  ChatMessage.swift · Wenshu
//
//  One chat turn (= a single user / agent / system message).
//
//  Pre-C-2 history (= refactor chat-mvvm-3layer): this type was
//  decomposed into a `ChatMessageHeader` (= identity = id / role /
//  source / timestamp) + a `ChatMessageBody` (= content = parts /
//  streamState / content / isPlaceholder / tokens / thinking /
//  imagePath) pair, with 12 forwarders on ChatMessage so existing
//  UI code kept compiling unchanged. C-8/C-9/C-10 (= the migration
//  to direct `body.xxx` reads in UI sub-components) never landed.
//  The header/body split added 153 LOC of abstraction + 12 forwarders
//  with zero external benefit (= grep across Sources/WenshuApp shows
//  no caller reads `msg.header.*` or `msg.body.*` outside ChatMessage
//  itself).
//
//  This commit inlines the header + body fields back into a single
//  ChatMessage struct, deletes the two companion files, and drops
//  the 12 forwarders. ChatMessage now holds the full 12-field shape
//  directly (= the original pre-C-2 surface).
//

import Foundation

/// One chat turn (= user / agent / system). Mutable per turn via
/// the streaming pipeline; immutable across turns.
struct ChatMessage: Equatable, Identifiable, Sendable {
    let id: UUID
    let role: ChatRole
    let source: ChatSource
    let timestamp: Date

    var parts: [ChatMessagePart]
    var streamState: StreamState
    var content: String
    var isPlaceholder: Bool
    var tokens: Int?
    var thinking: String?
    var imagePath: String?

    /// Streaming state machine. Mirrors Hermes's
    /// `message.pending` boolean + the lifecycle hooks in
    /// `use-message-stream/index.ts` (`mutateStream` decides when
    /// to seal a pending bubble into a permanent one).
    enum StreamState: String, Equatable, Sendable {
        case idle             // not yet streaming (= legacy ChatMessage)
        case streaming        // actively receiving LLMBlock events
        case sealed           // stream.complete fired; content is final
        case error            // stream terminated with error
    }

    init(
        id: UUID = UUID(),
        role: ChatRole,
        source: ChatSource = .wenshu,
        content: String,
        timestamp: Date = Date(),
        isPlaceholder: Bool = false,
        tokens: Int? = nil,
        thinking: String? = nil,
        imagePath: String? = nil,
        parts: [ChatMessagePart] = [],
        streamState: StreamState = .idle
    ) {
        self.id = id
        self.role = role
        self.source = source
        self.timestamp = timestamp
        // Mirror the legacy ChatMessageBody.init: synthesize a
        // single .text part when caller gives plain content + empty
        // parts (= the streaming UI sees consistent parts[] state).
        if parts.isEmpty && !content.isEmpty {
            let ts = timestamp.timeIntervalSinceReferenceDate
            var synth = [ChatMessagePart.text(content, timestamp: ts)]
            if let thinking, !thinking.isEmpty {
                synth.append(.reasoning(thinking, timestamp: ts))
            }
            self.parts = synth
        } else {
            self.parts = parts
        }
        self.streamState = streamState
        self.content = content
        self.isPlaceholder = isPlaceholder
        self.tokens = tokens
        self.thinking = thinking
        self.imagePath = imagePath
    }
}

/// Chat role ground truth (= the actual display uses the source
/// text, not the role's display name).
enum ChatRole: String, Equatable, Sendable {
    case user
    case agent
    case system
}

/// Message source ground truth (user = sent by the user / wenshu = Wenshu's reply / system = system error). Wenshu's internal multi-agent dispatch results do not show as ChatMessage; they go through the WSKanbanRepository board.
enum ChatSource: String, Equatable, Sendable, Codable {
    case user
    case wenshu
    case system
}