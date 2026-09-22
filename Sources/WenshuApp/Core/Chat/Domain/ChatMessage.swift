//
//  ChatMessage.swift · Wenshu · refactor chat-mvvm-3layer C-1
//
//  Display-side chat message type (= the "UI-facing" view of one
//  chat turn). Lives in the business layer because:
//  - both `ChatViewModel` (business) and `ChatMessageView` (UI)
//    consume it
//  - it carries streaming state + parts that are intermediate
//    between LLM and persistence (= business concern, not UI
//    decoration)
//  - the persistence layer has its own leaner type
//    (`StoredChatMessage` in Core/Chat/ChatDomain.swift) used by
//    `WSChatRepository`
//
//  Pre-C-1 history: this type lived at the top of
//  `Sources/WenshuApp/Views/Chat/ChatView.swift` (= same file as
//  the SwiftUI view) — physically coupled to UI. Per boss
//  2026-09-22 directive "目标 UI，业务，数据，三分离" + Apple
//  SwiftUI MVVM standard (= `@Observable @MainActor` view model
//  holding domain types; = UI binds via `@Bindable`), domain
//  types belong in the business layer directory, not the Views
//  directory.
//
//  C-1 scope: PHYSICAL MOVE only. Zero behavior change. The
//  follow-up commits will:
//  - C-2 split this into ChatMessageHeader + ChatMessageBody
//  - C-3 move ChatViewModel to its own file
//  - C-4-C-6 introduce the ChatRepositoryProtocol seam
//

import Foundation

/// One chat message: three roles (user / Wenshu / system); Wenshu's internal multi-agent dispatch does not surface as ChatMessage (it goes through the Kanban board)
public struct ChatMessage: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let role: ChatRole
    public let source: ChatSource
    /// v0.71 P1 batch 1 (boss 2026-09-12 OOB 'streaming output in the chat zone isn't implemented... port the whole thing from hermes...'):
    /// streaming parts (= Hermes `parts: ChatMessagePart[]` in
    /// `lib/chat-messages/types.ts:15`). Each part is a typed content
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
    public var streamState: StreamState
    /// Backward-compat: original chat content. Now a computed getter
    /// (= joined .text parts). Stays public so callers that read
    /// `content` keep working without changes.
    public var content: String
    public let timestamp: Date
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
        self.id = id
        self.role = role
        self.source = source
        // v0.71 P1 batch 1: parts[] is canonical. content + thinking
        // are derived getters. init keeps content as a stored field so
        // callers that pass plain text (= ChatView user message path)
        // don't have to construct [parts]. The init builds a single
        // .text part if content is non-empty AND parts[] is empty.
        if parts.isEmpty && !content.isEmpty {
            self.parts = [.text(content, timestamp: timestamp.timeIntervalSinceReferenceDate)]
        } else {
            self.parts = parts
        }
        self.streamState = streamState
        self.content = content
        self.timestamp = timestamp
        self.isPlaceholder = isPlaceholder
        self.tokens = tokens
        // If thinking was passed but parts[] is empty (= legacy caller),
        // synthesize a reasoning part so the streaming UI sees it.
        if let thinking, !thinking.isEmpty, parts.isEmpty {
            self.parts = self.parts + [.reasoning(thinking, timestamp: timestamp.timeIntervalSinceReferenceDate)]
        }
        self.thinking = thinking
        self.imagePath = imagePath
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
