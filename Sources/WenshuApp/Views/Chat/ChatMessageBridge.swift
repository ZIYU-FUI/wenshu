//
//  ChatMessageBridge.swift · Wenshu · v0.35 ticket 003 sub-step 5 followup
//
//  Single source of truth for ChatMessage ↔ LLMMessage mapping.
//  Originally lived as internal extensions in ChatViewCompressionRow.swift;
//  extracted here per Standards-axis S2 Feature Envy smell (= view was
//  reaching into ChatMessage internals + LLMMessage internals; bridge
//  belongs on a dedicated type, not in a view's manualCompress()).
//
//  Per /domain-modeling 'update CONTEXT.md inline' rule, this is a
//  vocabulary primitive (= bridge type, not a domain entity). Per §11.3
//  wenshu-side wins, ChatMessage is the wenshu-side source of truth
//  (= canonical identity preservation); LLMMessage is the hermes-port
//  contract (= wire format to the LLM API).
//

import Foundation

// MARK: - Role bridge (ChatRole ↔ LLMMessage.Role)
//
// Ticket 003 sub-step 5 acceptance: compression round-trip preserves
// message identity. Role bridge lives in this file (= single source of
// truth for ChatView ↔ LLMMessage role mapping). Per §11.3 wenshu-side
// wins, this bridge is a thin adapter over the existing ChatRole enum.
//
// System role travels as user in LLMMessage (= system prompt is always a
// top-level parameter, not an in-band message, per LLMConnector
// Anthropic-native semantics). Tool result travels as user-visible status
// in ChatView (= tool execution is rendered inline above the agent response,
// see ChatMessageView line 941).

extension ChatRole {
    /// Convert wenshu's ChatRole to LLMMessage.Role for sending to LLM API.
    public var toLLMRole: LLMMessage.Role {
        switch self {
        case .user: return .user
        case .agent: return .assistant
        case .system: return .user
        }
    }
}

extension LLMMessage.Role {
    /// Convert LLMMessage.Role back to wenshu's ChatRole for UI display.
    public var fromLLMRole: ChatRole {
        switch self {
        case .user: return .user
        case .assistant: return .agent
        case .tool: return .user
        }
    }
}

// MARK: - Content bridge (LLMMessage.blocks → ChatMessage.content)
//
// ChatMessage.content is a String (= single concatenation), but
// LLMMessage.blocks is `[LLMBlock]` (= union of text / toolUse /
// toolResult / thinking). The compression round-trip may collapse
// multiple text blocks into one; for display, concatenate all text
// blocks. Empty string if no text blocks.

extension LLMMessage {
    /// First text content (= concatenate text blocks; empty if none).
    public var textContent: String {
        blocks.compactMap { block in
            if case let .text(text) = block { return text }
            return nil
        }.joined(separator: "\n")
    }
}

// MARK: - ChatMessage → LLMMessage mapping

extension ChatMessage {
    /// Convert this ChatMessage to LLMMessage for compression / LLM API.
    public var asLLMMessage: LLMMessage {
        LLMMessage(
            role: role.toLLMRole,
            blocks: [.text(content)]
        )
    }
}