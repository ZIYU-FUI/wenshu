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
//  all 12 fields. Per boss 2026-09-22 '目标 UI，业务，数据，三分离'
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
public struct ChatMessage: Equatable, Identifiable, Sendable {
    public var header: ChatMessageHeader
    public var body: ChatMessageBody

    public var id: UUID { header.id }
    public var role: ChatRole { header.role }
    public var source: ChatSource { header.source }
    public var timestamp: Date { header.timestamp }

    // Forwarders to body (= read-write; the streaming pipeline
    // mutates these per turn). Removed in C-8/C-9/C-10 as UI
    // sub-components migrate to direct `body.xxx` reads.
    public var parts: [ChatMessagePart] {
        get { body.parts }
        set { body.parts = newValue }
    }
    public var streamState: StreamState {
        get { body.streamState }
        set { body.streamState = newValue }
    }
    public var content: String {
        get { body.content }
        set { body.content = newValue }
    }
    public var isPlaceholder: Bool {
        get { body.isPlaceholder }
        set { body.isPlaceholder = newValue }
    }
    public var tokens: Int? {
        get { body.tokens }
        set { body.tokens = newValue }
    }
    public var thinking: String? {
        get { body.thinking }
        set { body.thinking = newValue }
    }
    public var imagePath: String? {
        get { body.imagePath }
        set { body.imagePath = newValue }
    }

    /// v0.71 P1 batch 1: streaming state machine. Mirrors the Hermes
    /// `message.pending` boolean + the lifecycle hooks in
    /// `use-message-stream/index.ts` (`mutateStream` decides when
    /// to seal a pending bubble into a permanent one).
    public enum StreamState: String, Equatable, Sendable {
        case idle             // not yet streaming (= legacy ChatMessage)
        case streaming        // actively receiving LLMBlock events
        case sealed           // stream.complete fired; content is final
        case error            // stream terminated with error
    }

    public init(
        id: UUID = UUID(),
        role: ChatRole,
        source: ChatSource = .wenshu,
        content: String,
        timestamp: Date = Date(),
        isPlaceholder: Bool = false,
        tokens: Int? = nil,
        thinking: String? = nil,
        imagePath: String? = nil,
        // v0.71 P1 batch 1: parts + streamState init params (= default
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
    public init(header: ChatMessageHeader, body: ChatMessageBody) {
        self.header = header
        self.body = body
    }
}

/// Chat role ground truth (compatible with v0.20 ticket 01; actual display uses source)
public enum ChatRole: String, Equatable, Sendable {
    case user
    case agent
    case system
}

/// Message source ground truth (user = sent by the user / wenshu = Wenshu's reply / system = system error). Wenshu's internal multi-agent dispatch results do not show as ChatMessage; they go through the WSKanbanRepository board (= Phase 5 ticket 6 deleted KanbanStore actor).
public enum ChatSource: String, Equatable, Sendable, Codable {
    case user
    case wenshu
    case system
}
