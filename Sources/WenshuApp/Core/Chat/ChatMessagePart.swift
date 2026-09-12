//
//  ChatMessagePart.swift · Wenshu · v0.71 P1 batch 1
//
//  Part data model for streaming agent output (= Hermes
//  `lib/chat-messages/parts.ts` + `tool-parts.ts` + `types.ts`).
//
//  Source (= hermes TypeScript; LOC counts are approximated at port time:
    //    external reference files not present in this worktree, so numbers
    //    are baseline figures from the v0.71 P1 batch 1 port and may drift
    //    upstream):
    //    - apps/desktop/src/lib/chat-messages/parts.ts (≈304 LOC)
    //    - apps/desktop/src/lib/chat-messages/tool-parts.ts (≈855 LOC)
    //    - apps/desktop/src/lib/chat-messages/types.ts (≈191 LOC)
//
//  Target (= wenshu Swift):
//    - Core/Chat/ChatMessagePart.swift (this file)
//
//  Part kinds (= hermes ChatMessagePart types):
//    - .text(String)              (= parts.ts:5 textPart)
//    - .thinking(String, signature: String?) (= parts.ts:9 reasoningPart)
//    - .toolUse(id, name, args, result, status, timestamp) (= tool-parts.ts)
//    - .toolResult(toolUseID, content, isError) (= tool-parts.ts)
//
//  Each Hermes gateway event (`message.delta`, `message.complete`,
//  `tool.start`, `tool.complete`, `reasoning.delta`, etc.) maps to one of
//  these parts. The streaming UI renders the array of parts in order.
//  No intermediate text concatenation (= the Hermes `chatMessageText`
//  helper joins .text parts when the consumer wants the full assistant
//  text; the parts[] array IS the canonical state).
//
//  Scope (= P1 batch 1):
//    - Part data type (= this file).
//    - ChatMessage.parts field (= ChatView.swift edit).
//    - Stream state machine (= ChatView.swift edit).
//
//  Out-of-scope (= P2-P3):
//    - Tool part UI cards (= P2 batch 2).
//    - Markdown rendering (= P3 batch 1).
//

import Foundation

/// A single content block within a chat message. Multiple parts per
/// message (= e.g. reasoning + text + tool_use + text is the standard
/// Hermes turn shape = narration → tool call → result narration → final
/// answer).
///
/// Equatable + Hashable + Sendable so SwiftUI views can diff parts
/// (= the streaming UI only re-renders the new part + the surrounding
/// shell; = same perf strategy as Hermes's `parts: ChatMessagePart[]`
/// + `React.memo` boundary).
public struct ChatMessagePart: Equatable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let kind: Kind
    /// Unix seconds when this part began (= hermes TimelinePartMetadata.timestamp).
    public let timestamp: TimeInterval?
    /// Unix seconds when this part stopped streaming (= hermes
    /// TimelinePartMetadata.completedAt). nil while still streaming.
    public let completedAt: TimeInterval?

    public enum Kind: Equatable, Hashable, Sendable {
        /// Plain text fragment (= multiple per message when the agent
        /// emits text-then-tool-then-text). Mirrors hermes `text` type.
        case text(String)
        /// Hidden reasoning / CoT block. First `.reasoning` part is
        /// the canonical place for the model's thinking. Mirrors
        /// hermes `reasoning` type.
        case reasoning(String)
        /// Tool invocation with args, status, and result (= hermes
        /// `tool-call` type). Rendered as a collapsible card with a
        /// status dot (= batch 2 P7-P8).
        case toolUse(ToolUsePart)
        /// Tool execution result (= hermes `tool-result` type).
        /// Distinct from `.toolUse` because Hermes sometimes
        /// appends a result WITHOUT a prior use (= e.g. orphan tool
        /// result surfaced for context).
        case toolResult(ToolResultPart)
    }

    public struct ToolUsePart: Equatable, Hashable, Sendable {
        public let id: String                 // hermes `tool_call_id`
        public let name: String                // hermes `name`
        public let args: String                // JSON-encoded args (= hermes args_text)
        public let context: String?           // hermes `context` (optional)
        public var status: Status              // mutable so streaming UI updates in place
        public var result: String?            // result text when status = .complete / .error
        public var errorMessage: String?       // populated when status = .error
        public var durationSeconds: Double?  // hermes duration_s

        public enum Status: String, Equatable, Hashable, Sendable {
            case running    // tool.start received, no tool.complete yet
            case complete   // tool.complete with success
            case error      // tool.complete with error
        }
    }

    public struct ToolResultPart: Equatable, Hashable, Sendable {
        public let toolUseID: String   // hermes `tool_use_id`
        public let content: String     // result content
        public let isError: Bool       // hermes `is_error`
    }

    // MARK: - Factory helpers (= mirror hermes parts.ts:5-9)

    public static func text(_ s: String, timestamp: TimeInterval? = nil) -> ChatMessagePart {
        ChatMessagePart(id: UUID(), kind: .text(s), timestamp: timestamp, completedAt: nil)
    }

    public static func reasoning(_ s: String, timestamp: TimeInterval? = nil) -> ChatMessagePart {
        ChatMessagePart(id: UUID(), kind: .reasoning(s), timestamp: timestamp, completedAt: nil)
    }

    public static func toolUse(
        id: String,
        name: String,
        args: String,
        context: String? = nil,
        timestamp: TimeInterval? = nil
    ) -> ChatMessagePart {
        ChatMessagePart(
            id: UUID(),
            kind: .toolUse(ToolUsePart(
                id: id, name: name, args: args, context: context,
                status: .running, result: nil, errorMessage: nil, durationSeconds: nil
            )),
            timestamp: timestamp,
            completedAt: nil
        )
    }

    public static func toolResult(
        toolUseID: String,
        content: String,
        isError: Bool,
        timestamp: TimeInterval? = nil
    ) -> ChatMessagePart {
        ChatMessagePart(
            id: UUID(),
            kind: .toolResult(ToolResultPart(toolUseID: toolUseID, content: content, isError: isError)),
            timestamp: timestamp,
            completedAt: nil
        )
    }
}

extension ChatMessagePart {
    /// Concatenated text content (= hermes `chatMessageText` =
    /// joins all .text parts in order). Used by `ChatMessage.text`
    /// computed property and the streaming pipeline's
    /// "accumulated buffer" before `message.complete`.
    public static func joinedText(_ parts: [ChatMessagePart]) -> String {
        parts.compactMap { part in
            if case let .text(s) = part.kind { return s }
            return nil
        }.joined()
    }

    /// Concatenated reasoning content (= first `.reasoning` part;
    /// hermes only has one reasoning per turn in the typical case).
    public static func joinedReasoning(_ parts: [ChatMessagePart]) -> String? {
        for part in parts {
            if case let .reasoning(s) = part.kind { return s }
        }
        return nil
    }
}