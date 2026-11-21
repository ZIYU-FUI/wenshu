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
    let isStreaming: Bool
    /// T22: optional closure for plan part approval (= flows down
    /// through ChatPartRow to ChatPlanPartView). Nil = no approve
    /// action (= the plan is read-only). Future ticket wires the
    /// actual approve-reinvoke path.
    let onApprovePlan: ((Plan) -> Void)?
    /// Writes back the reader's choice about one block's detail. Nil = the
    /// row has nothing to write to (= a hand-built preview).
    let onThinkingReveal: ChatThinkingRevealWriter?

    init(
        message: ChatMessage,
        isStreaming: Bool = false,
        onApprovePlan: ((Plan) -> Void)? = nil,
        onThinkingReveal: ChatThinkingRevealWriter? = nil
    ) {
        self.message = message
        self.isStreaming = isStreaming
        self.onApprovePlan = onApprovePlan
        self.onThinkingReveal = onThinkingReveal
    }

    /// Outgoing = the message came from the user, not the assistant.
    private var isOutgoing: Bool {
        message.source == .user
    }

    /// The text part the streaming cursor belongs to.
    private var trailingTextPartID: UUID? {
        message.trailingTextPartID
    }

    /// The steps the assistant performed during this reply.
    ///
    /// Derived once per body evaluation and handed to the part rows, so a
    /// part row does not have to hold the whole reply to describe the work
    /// (= a part row holding the reply is a part row whose input changes on
    /// every appended token, whatever the part itself did with the token).
    private var activity: [ToolActivity] {
        ToolActivity.activity(from: message.parts)
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
                    isStreaming: isStreaming
                )
            } else {
                ForEach(message.parts) { part in
                    ChatPartRow(
                        part: part,
                        messageID: message.id,
                        activity: activity,
                        isOutgoing: isOutgoing,
                        isStreaming: isStreaming,
                        showsCursor: part.id == trailingTextPartID,
                        onApprovePlan: onApprovePlan,
                        onThinkingReveal: onThinkingReveal
                    )
                    // A reply that grew by one token changed one part. The
                    // rows that were handed the same part, the same steps
                    // and the same flags are asked to say so instead of
                    // being built again, which is what keeps the cost of an
                    // append at the leaf that grew.
                    .equatable()
                }
                // O3 driver for the four .transition(.wenshuThinkingAppear())
                // sites in ChatPartRow.body: the transitions existed since
                // T40/T41/T49 (2026-09-18) but no animation ever observed
                // the insertion, so every part landed as a hard jump. The
                // value is the parts' identities, so an edit in place (the
                // StreamingAccumulator appending text to an existing part)
                // animates nothing (= the stable-identity rule the audit's
                // info row names), while an added or removed part row runs
                // the appear transition. Craft audit 2026-11-21.
                .animation(.default, value: message.parts.map(\.id))
            }
        }
        .foregroundStyle(roleForeground)
    }
}

/// The row for one part is the same row when everything it draws is the
/// same.
///
/// The two closures are the parent's own and are left out: they are built
/// per reply, not per token, and comparing them would make every row differ
/// on every frame (= the comparison the row is being spared).
extension ChatMessageBodyView: Equatable {
    nonisolated static func == (lhs: ChatMessageBodyView, rhs: ChatMessageBodyView) -> Bool {
        lhs.message == rhs.message && lhs.isStreaming == rhs.isStreaming
    }
}

/// Writes the reader's choice about a thinking block back into the model.
///
/// The row hands over the reply it belongs to, the block it drew (= nil
/// when the reply keeps its thinking as a field rather than as a part) and
/// the answer the reader picked. The answer is stored with the data, never
/// in the view: Apple's own rule for a scroll view is "Do not depend on
/// view state for data that needs to be kept alive after scrolling", and a
/// streamed append tears the row down just as surely as a scroll does.
typealias ChatThinkingRevealWriter = (_ messageID: UUID, _ partID: UUID?, _ revealed: Bool) -> Void

/// Single-part row (= dispatches to the right Chat*PartView based
/// on `part.kind`). Extracted so `ForEach` stays clean (= per
/// Hermes' `parts: { ... }` callback pattern in the assistant-ui
/// runtime).
private struct ChatPartRow: View {
    let part: ChatMessagePart
    let isOutgoing: Bool
    let isStreaming: Bool
    /// Whether this row carries the streaming cursor (= it is the
    /// trailing text block).
    let showsCursor: Bool
    /// The reply this row belongs to, by identity only.
    ///
    /// The row needs to say which reply a block was opened in (= the model
    /// writes the answer back to the part this row was handed). It does not
    /// need the reply's contents, and holding them would make this row's
    /// input change on every appended token of every part.
    let messageID: UUID
    /// The steps the assistant performed, which the thinking block lists.
    ///
    /// The reply derives these once in its own body and hands the block the
    /// finished list, so redrawing one row cannot re-derive the trace.
    let activity: [ToolActivity]
    /// T22: optional approval closure for plan parts (= the user
    /// clicks Approve & Run = the parent = ChatMessageView = decides
    /// how to re-invoke the conductor with the approved plan). Nil
    /// for non-plan parts (= unused). Future ticket wires the actual
    /// approve-reinvoke path.
    let onApprovePlan: ((Plan) -> Void)?
    /// Writes the reader's collapse of a thinking block back to the part.
    let onThinkingReveal: ChatThinkingRevealWriter?

    init(
        part: ChatMessagePart,
        messageID: UUID,
        activity: [ToolActivity],
        isOutgoing: Bool,
        isStreaming: Bool,
        showsCursor: Bool = false,
        onApprovePlan: ((Plan) -> Void)? = nil,
        onThinkingReveal: ChatThinkingRevealWriter? = nil
    ) {
        self.part = part
        self.messageID = messageID
        self.activity = activity
        self.isOutgoing = isOutgoing
        self.isStreaming = isStreaming
        self.showsCursor = showsCursor
        self.onApprovePlan = onApprovePlan
        self.onThinkingReveal = onThinkingReveal
    }

    /// The reader's own view of this block, read from the part the row was
    /// handed and written back to the model.
    private var revealBinding: Binding<Bool> {
        Binding(
            get: { part.isThinkingRevealed },
            set: { onThinkingReveal?(messageID, part.id, $0) }
        )
    }

    var body: some View {
        #if DEBUG
        #endif
        switch part.kind {
        case .text(let s):
            // A reply that carries markers is drawn in two layers: the
            // answer in the body, the steps as labelled lines. While
            // the reply streams it stays plain text, because a marker
            // that is only half written would make the body flicker
            // between the two renderings.
            textRow(for: s)
                // T49-TEXT-FADEIN (2026-09-18): apply the same
                // appear-from-top transition as T40 reasoning parts
                // + T41 tool parts. Text parts also fade in when
                // they appear in a streaming message (= each text
                // chunk = the model "typing" = visual feedback that
                // streaming is alive).
                .transition(.wenshuThinkingAppear())
        case .reasoning(let s):
            ChatReasoningPartView(
                text: s,
                isRunning: isStreaming,
                activity: activity,
                isRevealed: revealBinding
            )
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

    /// The body of a text part.
    ///
    /// A reply that carries markers is drawn in two layers: the answer
    /// in the body, the steps as labelled lines. While the reply
    /// streams it stays plain text, because a marker that is only half
    /// written would make the body flicker between the two renderings.
    @ViewBuilder
    private func textRow(for text: String) -> some View {
        if !isStreaming, ReasoningMarkupParser.hasMarkup(text) {
            ChatTraceTextView(text: text)
        } else {
            ChatTextPartView(
                text: text,
                isStreaming: isStreaming,
                showsCursor: showsCursor
            )
        }
    }
}

/// One part's row is the same row when everything it draws is the same.
///
/// The comparison leaves out the two closures for the reason ChatMessageBodyView
/// leaves them out. What it does compare is the part itself (= including the
/// reader's own collapse of it, which is why opening a block reaches the
/// screen) and the steps the thinking block lists.
extension ChatPartRow: Equatable {
    nonisolated static func == (lhs: ChatPartRow, rhs: ChatPartRow) -> Bool {
        lhs.part == rhs.part
            && lhs.messageID == rhs.messageID
            && lhs.activity == rhs.activity
            && lhs.isOutgoing == rhs.isOutgoing
            && lhs.isStreaming == rhs.isStreaming
            && lhs.showsCursor == rhs.showsCursor
    }
}

// MARK: - User message hover actions (= hermes MessageActions)

// Hover actions overlay for user messages (= the Hermes
// `MessageActions` pattern = copy + delete buttons that fade
// in on hover).
//
// Usage:
// ```
// messageContent
//     .overlay(alignment: .topTrailing) {
//         if isOutgoing {
//             ChatMessageHoverActions(content: message.content)
//         }
//     }
// ```
