//
//  ChatMessageBody.swift · Wenshu · refactor chat-mvvm-3layer C-2
//
//  The "inner pages" of one chat turn (= what was said, how it's
//  being delivered, and any attached media). Lifted out of the
//  monolithic ChatMessage struct so the three layers can hold just
//  the slice they need:
//
//  - UI layer (= ChatMessageView / ChatPartView): reads `body.parts`
//    to render each part independently. Reads `body.imagePath` to
//    show the attachment thumbnail.
//  - Business layer (= ChatSessionViewModel): holds a full
//    `ChatMessage` (= header + body) and mutates `body` during
//    streaming (= appending text parts, advancing `streamState`,
//    collapsing into the final sealed form).
//  - Data layer (= ChatRepository): reads `body.content` to persist
//    (= the joined text) + reads `body.thinking` to persist the
//    reasoning + reads `body.tokens` to persist usage stats. The
//    parts[] array never crosses the repository boundary (= it
//    collapses into `content` + `thinking` at seal-time).
//
//  Mutability: most body fields are `var` (= the streaming pipeline
//  mutates them). Identity-bearing fields (= none on body) stay
//  in the header.
//
//  Streaming state machine (= `streamState`): idle → streaming →
//  sealed | error. The business layer transitions; UI observes.
//

import Foundation

/// The inner pages of one chat turn (= content + streaming state +
/// attachments). Mutated during streaming; sealed on stream.complete.
public struct ChatMessageBody: Equatable, Sendable {
    /// v0.71 P1 batch 1 (boss 2026-09-12 OOB 'streaming output in the
    /// chat zone isn't implemented... port the whole thing from
    /// hermes...'): streaming parts (= Hermes `parts: ChatMessagePart[]`
    /// in `lib/chat-messages/types.ts:15`). Each part is a typed content
    /// block (text / reasoning / tool_use / tool_result). The streaming
    /// pipeline accumulates LLMBlock events into this array. UI renders
    /// each part independently (= Hermes `message-parts.tsx`). Backward
    /// compat: `content` + `thinking` getters derive from this array
    /// (= existing ChatMessageView still works unchanged).
    public var parts: [ChatMessagePart]
    /// v0.71 P1 batch 1: streaming state. hermes uses `message.pending`
    /// (= bool on ChatMessage); wenshu uses an enum so SwiftUI
    /// exhaustive-switch renders the right state (idle / streaming /
    /// sealed / error).
    public var streamState: ChatMessage.StreamState
    /// Backward-compat: original chat content. Now a computed getter
    /// (= joined .text parts). Stays public so callers that read
    /// `content` keep working without changes.
    public var content: String
    public var isPlaceholder: Bool
    public var tokens: Int?    // real LLM API usage.total_tokens (nil if user message or unavailable)
    public var thinking: String?    // v0.71 P1: also a computed getter (= joined reasoning parts)
    // CHATIMG-001 (2026-09-07): absolute file URL of an attached
    // screenshot/image. When non-nil, ChatMessageView renders the image
    // thumbnail above the text content. The file lives in
    // `<libraryPath>/cache/chat-uploads/` (= per §11 .ws bundle layout =
    // cache subfolder holds thumbnails + search index + export temp; this
    // ticket adds `chat-uploads` as the canonical chat-attachment cache
    // dir). nil = no image attached. Send-time semantics: the user
    // message carries the path; LLM send path (per §11.3 wenshu-side
    // wins) does NOT forward the image bytes to the provider this round
    // (= out-of-scope for ticket CHATIMG-001; ticket CHATIMG-002 covers
    // the multimodal upload protocol).
    public var imagePath: String?

    public init(
        content: String,
        parts: [ChatMessagePart] = [],
        streamState: ChatMessage.StreamState = .idle,
        isPlaceholder: Bool = false,
        tokens: Int? = nil,
        thinking: String? = nil,
        imagePath: String? = nil
    ) {
        // Mirror ChatMessage.init's parts synthesis (= if caller passes
        // plain text + empty parts, build a single .text part so the
        // streaming UI sees consistent parts[] state).
        let synthParts: [ChatMessagePart]
        if parts.isEmpty && !content.isEmpty {
            synthParts = [.text(content, timestamp: Date().timeIntervalSinceReferenceDate)]
        } else {
            synthParts = parts
        }
        // Mirror ChatMessage.init's reasoning synthesis.
        let finalParts: [ChatMessagePart]
        if let thinking, !thinking.isEmpty, parts.isEmpty {
            finalParts = synthParts + [.reasoning(thinking, timestamp: Date().timeIntervalSinceReferenceDate)]
        } else {
            finalParts = synthParts
        }
        self.parts = finalParts
        self.streamState = streamState
        self.content = content
        self.isPlaceholder = isPlaceholder
        self.tokens = tokens
        self.thinking = thinking
        self.imagePath = imagePath
    }
}
