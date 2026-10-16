//
//  ChatPartView.swift
//
//  Renders a single ChatMessagePart in the wenshu streaming chat
//  zone. Each Hermes `ChatMessagePart` kind (= text / reasoning /
//  tool_use / tool_result) maps to a dedicated render view (= the
//  wenshu equivalent of Hermes' `<MessagePart>` components in
//  apps/desktop/src/components/assistant-ui/thread/message-parts.tsx).
//
//  The 4 part renderers (= each is a self-contained SwiftUI View):
//    • ChatTextPartView: text fragment with inline markdown rendering
//      (= AttributedString(markdown:options:.inlineOnlyPreservingWhitespace);
//      = the canonical SwiftUI markdown path) +
//      `.contentTransition(.interpolate)` for smooth token-by-token
//      streaming (= no per-chunk flicker).
//    • ChatReasoningPartView: CoT / hidden thinking block rendered
//      as a collapsible DisclosureGroup (= Apple HIG footnote
//      pattern = .secondary text + dimmed + .caption font).
//    • ChatToolUsePartView: tool invocation as an inline card
//      (= rounded rectangle + status dot + tool name + collapsed
//      args JSON + click-to-expand). Maps Hermes ToolCallMessagePart.
//    • ChatToolResultPartView: tool execution result as a sibling
//      card (= matched pair with the .toolUse card; = shows output
//      or error indicator).
//
//  All 4 components:
//    • are `public` (= the ChatMessageBodyView uses them).
//    • conform to `View` (= SwiftUI).
//    • use DesignTokens (= no magic numbers; = iron-rule 6).
//    • render via SwiftUI primitives (= no NSTextView, no WebView).
//    • support `message.source == .user` (= outgoing = accent fill)
//      AND `message.source == .wenshu` (= incoming = quaternary fill)
//      via the caller-supplied `isOutgoing: Bool` parameter.
//

import SwiftUI

// MARK: - Text part (= hermes TextMessagePart)

/// Render a single `.text(String)` part of a chat message (= one
/// chunk of the assistant's reply = multiple per message = Hermes
/// emits one text part per token stream segment).
///
/// The text content is rendered via `AttributedString(markdown:)`
/// with `.inlineOnlyPreservingWhitespace` (= headings/lists/code
/// blocks are NOT parsed = the inline markdown subset that SwiftUI
/// Text can natively render; = bold/italic/code/links do format).
/// `.contentTransition(.interpolate)` smoothly interpolates text
/// growth across streaming chunks (= no per-chunk flicker = the
/// canonical SwiftUI streaming text pattern).
struct ChatMessageBodyView: View {
    let message: ChatMessage
    let isOutgoing: Bool
    let isStreaming: Bool
    /// T22: optional closure for plan part approval (= flows down
    /// through ChatPartRow to ChatPlanPartView). Nil = no approve
    /// action (= the plan is read-only). Future ticket wires the
    /// actual approve-reinvoke path.
    let onApprovePlan: ((Plan) -> Void)?

    init(
        message: ChatMessage,
        isOutgoing: Bool,
        isStreaming: Bool = false,
        onApprovePlan: ((Plan) -> Void)? = nil
    ) {
        self.message = message
        self.isOutgoing = isOutgoing
        self.isStreaming = isStreaming
        self.onApprovePlan = onApprovePlan
    }

    var body: some View {
        // Apple HIG: writing body text uses `.primary` foreground,
        // uniformly (= Pages / Notes / Mail body). User-vs-assistant
        // distinction comes from alignment (= iMessage right vs left)
        // + bubble background, NOT from text color dimming. Both
        // chat (this body) and editor (= NSTextView labelColor = .label
        // = .primary) read the same SwiftUI semantic foreground, so
        // the two zones feel like one app's two text surfaces.
        // RATIONALE: wenshu writing-tool requirement per boss 2026-10-16
        // "editor + chat body text share Apple text style" — body text
        // = always `.primary`; no `opacity()` mutators on the tint
        // (Apple HIG forbids `.primary.opacity(0.X)`; the four-tier
        // `.primary / .secondary / .tertiary / .quaternary` semantic
        // ladder covers all muted cases without opacity tweaks).
        let roleForeground: HierarchicalShapeStyle = .primary
        return Group {
            if message.parts.isEmpty {
                // Back-compat path: no parts (= a v0.34 message). Render
                // the single content string as before.
                ChatTextPartView(
                    text: message.content,
                    isOutgoing: isOutgoing,
                    isStreaming: isStreaming
                )
            } else {
                ForEach(message.parts) { part in
                    ChatPartRow(
                        part: part,
                        isOutgoing: isOutgoing,
                        isStreaming: isStreaming,
                        onApprovePlan: onApprovePlan
                    )
                }
            }
        }
        .foregroundStyle(roleForeground)
    }
}

/// Single-part row (= dispatches to the right Chat*PartView based
/// on `part.kind`). Extracted so `ForEach` stays clean (= per
/// Hermes' `parts: { ... }` callback pattern in the assistant-ui
/// runtime).
private struct ChatPartRow: View {
    let part: ChatMessagePart
    let isOutgoing: Bool
    let isStreaming: Bool
    /// T22: optional approval closure for plan parts (= the user
    /// clicks Approve & Run = the parent = ChatMessageView = decides
    /// how to re-invoke the conductor with the approved plan). Nil
    /// for non-plan parts (= unused). Future ticket wires the actual
    /// approve-reinvoke path.
    let onApprovePlan: ((Plan) -> Void)?

    init(
        part: ChatMessagePart,
        isOutgoing: Bool,
        isStreaming: Bool,
        onApprovePlan: ((Plan) -> Void)? = nil
    ) {
        self.part = part
        self.isOutgoing = isOutgoing
        self.isStreaming = isStreaming
        self.onApprovePlan = onApprovePlan
    }

    var body: some View {
        switch part.kind {
        case .text(let s):
            ChatTextPartView(text: s, isOutgoing: isOutgoing, isStreaming: isStreaming)
                // T49-TEXT-FADEIN (2026-09-18): apply the same
                // appear-from-top transition as T40 reasoning parts
                // + T41 tool parts. Text parts also fade in when
                // they appear in a streaming message (= each text
                // chunk = the model "typing" = visual feedback that
                // streaming is alive).
                .transition(.wenshuThinkingAppear())
        case .reasoning(let s):
            ChatReasoningPartView(text: s, isRunning: isStreaming)
                // T40-THINKING-FADEIN (2026-09-18): when a reasoning
                // part is added to or removed from a streaming message,
                // the view fades in from the top (= Apple HIG content
                // insertion pattern; = matches the visual rhythm of
                // streamed tokens appearing). Pair with .animation on
                // the parent ForEach for smooth transitions.
                .transition(.wenshuThinkingAppear())
        case .toolUse(let tu):
            ChatToolUsePartView(toolUse: tu, isOutgoing: isOutgoing)
                // T41-TOOL-USE-FADEIN (2026-09-18): apply the same
                // appear-from-top transition as T40 reasoning parts.
                // Tool-use calls appearing in a streaming message
                // (= the model invoking a tool) also benefit from
                // a soft fade-in (= matches the Apple HIG content
                // insertion pattern). Reuses AnyTransition.wenshuThinkingAppear()
                // because the visual idiom is identical (= streaming
                // event lands on screen; = fade in).
                .transition(.wenshuThinkingAppear())
        case .toolResult(let tr):
            ChatToolResultPartView(toolResult: tr, isOutgoing: isOutgoing)
                // T41-TOOL-USE-FADEIN (2026-09-18): tool-result parts
                // (= the output of a tool call) fade in too (= the
                // whole tool lifecycle = call + result = a single
                // visual unit; = both halves should animate in sync).
                .transition(.wenshuThinkingAppear())
        case .plan(let p):
            // T22: render the plan via ChatPlanPartView (= T20b
            // primitive). The onApprove closure is passed through;
            // when nil = the Approve button is hidden (= the user
            // can still read the plan = they just can't re-invoke).
            ChatPlanPartView(
                plan: p,
                onApprove: { plan in
                    onApprovePlan?(plan)
                }
            )
        }
    }
}

// MARK: - User message hover actions (= hermes MessageActions)

// Hover actions overlay for user messages (= the Hermes
/// `MessageActions` pattern = copy + delete buttons that fade
/// in on hover).
///
/// Usage:
/// ```
/// messageContent
///     .overlay(alignment: .topTrailing) {
///         if isOutgoing {
///             ChatMessageHoverActions(content: message.content)
///         }
///     }
/// ```
