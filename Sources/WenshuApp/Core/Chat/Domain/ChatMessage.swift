//
//  ChatMessage.swift · Wenshu · refactor chat-mvvm-3layer C-2
//
//  Glue type that composes a ChatMessageHeader (= cover page) with
//  a ChatMessageBody (= inner pages). This is the type the rest of
//  the app reads today; C-8/C-9/C-10 will progressively migrate UI
//  fields off the forwarders to direct `header` / `body` reads, then
//  the forwarders go away.
//
//  Pre-C-2 history: ChatMessage was a single 98-line struct holding
// 
//  the type was split:
//  - ChatMessageHeader (= identity)  -> Core/Chat/Domain/ChatMessageHeader.swift
//  - ChatMessageBody   (= content)   -> Core/Chat/Domain/ChatMessageBody.swift
//  - ChatMessage       (= composite) -> this file
//
//  Forwarding pattern (= zero UI churn this commit):
//  - All 12 fields are accessible via the original property names
//    on ChatMessage itself (= `msg.content`, `msg.parts`,
//    `msg.imagePath`, etc.). UI code that hasn't migrated yet
//    still compiles unchanged.
//  - Forwarders are read-only computed properties for header fields
//    (= id / role / source / timestamp = immutable post-creation
//    anyway) and read-write computed properties for body fields
//    (= content / parts / streamState / etc. = the streaming
//    pipeline mutates them per turn).
//  - Mutation through a forwarder (= `msg.parts = [...]`) is
//    allowed for body fields; it forwards to `self.body.parts = ...`.
//  - C-8/C-9/C-10 will migrate UI sub-components to direct
//    `msg.body.xxx` reads. Each migration removes one forwarder.
//    Final state (= after C-10): zero forwarders, ChatMessage is
//    a pure composition wrapper with no logic of its own.
//
//  StreamState enum moved to ChatMessage (= where callers still
//  look it up) but its declaration stays as a nested type so
//  `ChatMessage.StreamState.idle` keeps working.
//
//  Equatable / Identifiable / Sendable: synthesized. Both header
//  and body are Equatable + Sendable value types, so the composite
//  is too.
//

import Foundation

/// Composite chat-message type (= header + body). The UI / business
/// layers consume this; the data layer maps it to StoredChatMessage
/// (= §11.4 SwiftData row) at the repository boundary.
struct ChatMessage: Equatable, Identifiable, Sendable {
    var header: ChatMessageHeader
    var body: ChatMessageBody

    var id: UUID { header.id }
    var role: ChatRole { header.role }
    var source: ChatSource { header.source }
    var timestamp: Date { header.timestamp }

    // Forwarders to body (= read-write; the streaming pipeline
    // mutates these per turn). Removed in C-8/C-9/C-10 as UI
    // sub-components migrate to direct `body.xxx` reads.
    var parts: [ChatMessagePart] {
        get { body.parts }
        set { body.parts = newValue }
    }
    var streamState: StreamState {
        get { body.streamState }
        set { body.streamState = newValue }
    }
    var content: String {
        get { body.content }
        set { body.content = newValue }
    }
    var isPlaceholder: Bool {
        get { body.isPlaceholder }
        set { body.isPlaceholder = newValue }
    }
    var tokens: Int? {
        get { body.tokens }
        set { body.tokens = newValue }
    }
    var thinking: String? {
        get { body.thinking }
        set { body.thinking = newValue }
    }
    var imagePath: String? {
        get { body.imagePath }
        set { body.imagePath = newValue }
    }

    /// streaming state machine. Mirrors the Hermes
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
        // parts + streamState init params (= default
        // = empty / idle for backward compat). When ChatMessage is
        // created from the streaming pipeline (= ChatViewModel.append),
        // pass the parts array (= the streaming pipeline owns the
        // parts); otherwise the parts[] is empty + content is the
        // legacy plain-text source-of-truth.
        parts: [ChatMessagePart] = [],
        streamState: StreamState = .idle
    ) {
        self.header = ChatMessageHeader(
            id: id,
            role: role,
            source: source,
            timestamp: timestamp
        )
        self.body = ChatMessageBody(
            content: content,
            parts: parts,
            streamState: streamState,
            isPlaceholder: isPlaceholder,
            tokens: tokens,
            thinking: thinking,
            imagePath: imagePath
        )
    }

    /// Convenience initializer for callers that already hold a
    /// header + body (= e.g. the streaming pipeline after sealing).
    init(header: ChatMessageHeader, body: ChatMessageBody) {
        self.header = header
        self.body = body
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
