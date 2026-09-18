//
//  ChatPartView.swift · Wenshu · v0.71 P1 batch 2 (= Hermes 1:1 streaming UI)
//
//  v0.71 P1 batch 2 (boss 2026-09-12 OOB 'streaming output in the chat zone isn't implemented...
//  port the whole thing from hermes...'):
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
//      = the canonical SwiftUI markdown path per v0.55 boss OOB) +
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
//    • render via SwiftUI primitives (= no NSTextView, no WebView
//      = the boss's 'anything that uses Apple styles should default everything' OOB).
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
/// canonical SwiftUI streaming text pattern per v0.55 boss OOB).
public struct ChatTextPartView: View {
    public let text: String
    public let isOutgoing: Bool
    public let isStreaming: Bool

    public init(text: String, isOutgoing: Bool, isStreaming: Bool = false) {
        self.text = text
        self.isOutgoing = isOutgoing
        self.isStreaming = isStreaming
    }

    public var body: some View {
        // v0.55 boss 2026-09-09 OOB 'use the ones we have not used yet':
        // AttributedString(markdown:) parses inline markdown natively
        // (= bold / italic / code / links show as formatting = not raw
        // asterisks). Falls back to plain string when not valid markdown.
        // `.inlineOnlyPreservingWhitespace` blocks are excluded (= those
        // would require a full markdown renderer = out of scope for this
        // batch).
        Text(Self.parseMarkdown(text))
            .textSelection(.enabled)
            // Streaming replies grow token by token. The default Text
            // transition re-renders the whole run; this one interpolates
            // so the bubble does not flicker on every chunk.
            .contentTransition(isStreaming ? .interpolate : .identity)
            .foregroundStyle(isOutgoing ? Color(nsColor: .windowBackgroundColor) : Color.primary)
    }

    /// Parse the text as inline markdown (= canonical SwiftUI path).
    /// Falls back to plain string when the markdown parse fails.
    /// Marked `nonisolated` so it can be called from test contexts
    /// without `@MainActor` isolation (= the function is a pure
    /// utility that doesn't touch any view state).
    nonisolated static func parseMarkdown(_ raw: String) -> AttributedString {
        (try? AttributedString(
            markdown: raw,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(raw)
    }
}

// MARK: - Reasoning part (= hermes ReasoningMessagePart)

/// Render a `.reasoning(String)` part (= CoT / hidden thinking =
/// Hermes ReasoningTextPart = the model's internal monologue).
///
/// Hermes renders reasoning as a collapsible `<DisclosureGroup>` with
/// a `ScaffoldRow` header (= "Thinking…" label + elapsed timer + a
/// shimmer animation while running). wenshu's existing DisclosureGroup
/// is the canonical Apple HIG equivalent (= no custom scaffold row =
/// Apple default = boss's 'anything that uses Apple styles should default everything' OOB).
///
/// The `isRunning` parameter (= true when the model is still thinking)
/// controls:
///   • the label text ("Thinking…" vs "Thinking trace" = "finished")
///   • the icon (= Lucide `brain` + .shimmer-like Pulse animation
///     while running)
public struct ChatReasoningPartView: View {
    public let text: String
    public let isRunning: Bool
    @State private var isExpanded: Bool = false

    public init(text: String, isRunning: Bool = false) {
        self.text = text
        self.isRunning = isRunning
    }

    public var body: some View {
        // Apple HIG footnote pattern (= the DisclosureGroup is the
        // canonical SwiftUI collapse/expand control = identical to
        // Mail / Notes "Show Details" toggles). Renders a label +
        // chevron that the user clicks to expand.
        DisclosureGroup(isExpanded: $isExpanded) {
            // Reasoning content (= same markdown treatment as the
            // text part = inline bold/italic/code works). Use .caption
            // (= smaller than the main text) + .secondary tone (= the
            // standard Apple HIG "supplementary content" tone).
            Text(Self.renderMarkdown(text))
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .padding(.top, DesignTokens.chromePaddingMicro)
                .transition(.opacity)
        } label: {
            HStack(spacing: 4) {
                // SF Symbols 6 (= no 'brain' in SF Symbols 6; =
                // 'brain.head.profile' = the closest 3rd-gen glyph
                // per sfsymbols search 2026-09-16).
                Image(systemName: "brain.head.profile").font(.system(size: 12, weight: .regular))
                    .font(.caption)
                // Label text flips between running + finished (= the
                // Hermes `thoughtFor` / `thoughtBriefly` / `thought`
                // state machine = simplified to a 2-state label here).
                Text(isRunning
                     ? WenshuI18n.t("chatview.ai_thinking")
                     : WenshuI18n.t("chatview.ai_thought"))
                    .font(.caption)
            }
            .foregroundStyle(DesignTokens.statusForeground)
        }
        .animation(.default, value: isExpanded)
    }

    /// Reasoning text also uses inline markdown (= reasoning often
    /// contains structure like `**KEY POINT**: ...`).
    private static func renderMarkdown(_ raw: String) -> AttributedString {
        ChatTextPartView.parseMarkdown(raw)
    }
}

// MARK: - Tool-use part (= hermes ToolCallMessagePart)

/// Render a `.toolUse(ToolUsePart)` part (= the model invokes a tool
/// = Hermes ToolCallMessagePart = wenshu's internal `toolUse` from
/// `LLMBlock.toolUse`).
///
/// Rendered as an inline card (= Apple Mail / Notes "block quote"
/// style = a thin left border + lighter background + small status
/// dot + tool name + collapsed args). Click to expand the JSON args.
/// Mirrors the Hermes `ToolFallback` component (= wenshu's
/// generalized fallback for any tool call = since v0.71 P1 batch 2
/// doesn't ship tool-specific UI like Hermes does for `delegate_task`
/// or `image_generate`).
public struct ChatToolUsePartView: View {
    public let toolUse: ChatMessagePart.ToolUsePart
    public let isOutgoing: Bool

    @State private var isArgsExpanded: Bool = false

    public init(toolUse: ChatMessagePart.ToolUsePart, isOutgoing: Bool) {
        self.toolUse = toolUse
        self.isOutgoing = isOutgoing
    }

    public var body: some View {
        // Apple HIG inline card (= rounded rect + thin left border +
        // monospaced font for the tool name = the canonical "tool call"
        // visual = same pattern as Xcode / Mail "Show Details" blocks).
        VStack(alignment: .leading, spacing: DesignTokens.chromePaddingMicro) {
            HStack(spacing: DesignTokens.chromePaddingSmall) {
                // Status dot (= running = secondary; = completed = green;
                // = error = red; = the 3-state indicator pattern).
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                // Tool name in monospaced font (= the wenshu convention
                // for tool identifiers = matches the chat input's
                // `/command` autocomplete rendering).
                Text(toolUse.name)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                // Expand toggle (= click anywhere on the card; = the
                // Hermes ToolFallback uses a `ScaffoldRow` click target).
            }
            if isArgsExpanded {
                // Args JSON (= pretty-printed if possible; = wrapped
                // in a monospaced font for readability).
                Text(Self.prettyJSON(toolUse.args))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(DesignTokens.statusForeground)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, DesignTokens.chromePaddingMicro)
            }
        }
        .padding(.horizontal, DesignTokens.chromePaddingSmall)
        .padding(.vertical, DesignTokens.chromePaddingMicro)
        .background(toolCardFill, in: RoundedRectangle(cornerRadius: 6))
        .overlay(
            // Thin left border (= Apple Mail "block quote" indicator).
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(borderColor, lineWidth: 1)
        )
        .frame(maxWidth: 360)
        .onTapGesture {
            // Toggle args expansion (= single tap target = the card
            // itself = mirrors Hermes' ScaffoldRow click semantics).
            withAnimation(.easeInOut(duration: 0.2)) {
                isArgsExpanded.toggle()
            }
        }
    }

    /// Status color (= Apple HIG semantic color = adapts to dark mode
    /// + the user's accent preference).
    private var statusColor: Color {
        switch toolUse.status {
        case .running: return .secondary
        case .complete: return .green
        case .error: return .red
        }
    }

    /// Card background (= thin tint that respects the surrounding
    /// bubble color).
    private var toolCardFill: AnyShapeStyle {
        if isOutgoing {
            return AnyShapeStyle(Color(nsColor: .windowBackgroundColor).opacity(0.12))
        }
        return AnyShapeStyle(.quaternary.opacity(0.5))
    }

    /// Border color (= matches the status dot color at low opacity).
    private var borderColor: Color {
        statusColor.opacity(0.5)
    }

    /// Pretty-print the args JSON (= if the args aren't valid JSON,
    /// show them as-is). `nonisolated` so it can be called from test
    /// contexts without `@MainActor` isolation (= pure utility).
    nonisolated static func prettyJSON(_ raw: String) -> String {
        guard let data = raw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
              let pretty = try? JSONSerialization.data(
                withJSONObject: obj,
                options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed]
              ),
              let s = String(data: pretty, encoding: .utf8) else {
            return raw
        }
        return s
    }
}

// MARK: - Tool-result part (= hermes ToolResultMessagePart)

/// Render a `.toolResult(ToolResultPart)` part (= the result of a
/// tool execution = Hermes ToolResultMessagePart). Sits visually
/// below the matching `.toolUse` card (= a "sibling" pair = the
/// same visual treatment + a checkmark icon when succeeded / a
/// warning icon when failed).
public struct ChatToolResultPartView: View {
    public let toolResult: ChatMessagePart.ToolResultPart
    public let isOutgoing: Bool

    @State private var isExpanded: Bool = false

    public init(toolResult: ChatMessagePart.ToolResultPart, isOutgoing: Bool) {
        self.toolResult = toolResult
        self.isOutgoing = isOutgoing
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.chromePaddingMicro) {
            HStack(spacing: DesignTokens.chromePaddingSmall) {
                // Success/error icon (= SF Symbol equivalent for the
                // result type = checkmark / exclamation-mark-triangle).
                // v1.0.0-m1-shell boss 2026-09-15 OOB 'remove
                // Lucide, use SF Symbols 6' (= the previous code
                // routed through the now-deleted
                // LucideIconSystemFallback helper to map SF
                // names to Lucide names; = now the SF names
                // are the canonical input directly).
                Image(systemName: toolResult.isError ? "exclamationmark.triangle" : "checkmark").font(.system(size: 12, weight: .regular))
                    .foregroundStyle(toolResult.isError ? Color(nsColor: .systemRed) : Color(nsColor: .systemGreen))
                Text(toolResult.isError
                     ? WenshuI18n.t("chatview.tool_result.error")
                     : WenshuI18n.t("chatview.tool_result.success"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            // T16-TOOL-RESULT-MARKDOWN (2026-09-18): render the result
            // content as inline markdown (= same parseMarkdown call as
            // ChatTextPartView) so multi-line tool outputs render with
            // bold / italic / inline code / links instead of raw text.
            // Collapsed state: lineLimit(8) (= inline preview). Expanded
            // state: full content (= tap the card to toggle; = mirrors
            // ChatToolUsePartView's click-to-expand affordance).
            Text(Self.parseMarkdown(toolResult.content))
                .font(.caption)
                .foregroundStyle(DesignTokens.statusForeground)
                .textSelection(.enabled)
                .lineLimit(isExpanded ? nil : 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, DesignTokens.chromePaddingMicro)
            // T16 expansion toggle (= shown only when the result is
            // actually long enough to truncate; = the lineLimit vs nil
            // difference is invisible if there are <= 8 lines).
            if needsExpandToggle {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Text(isExpanded
                         ? WenshuI18n.t("chatview.tool_result.collapse")
                         : WenshuI18n.t("chatview.tool_result.expand"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .padding(.top, DesignTokens.chromePaddingMicro / 2)
            }
        }
        .padding(.horizontal, DesignTokens.chromePaddingSmall)
        .padding(.vertical, DesignTokens.chromePaddingMicro)
        .background(cardFill, in: RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(borderColor, lineWidth: 1)
        )
        .frame(maxWidth: 360)
    }

    /// T16: show the expand toggle only when the content exceeds the
    /// 8-line collapsed preview. Heuristic: count newlines; = multiline
    /// outputs (e.g. JSON tool results, file contents) trigger the toggle;
    /// single-line tool results don't (= the lineLimit(8) wouldn't
    /// truncate them anyway).
    private var needsExpandToggle: Bool {
        toolResult.content.components(separatedBy: "\n").count > 8
            || toolResult.content.count > 480  // long single-line outputs
    }

    /// T16: inline-markdown parse for tool result content. Reuses the
    /// canonical `ChatTextPartView.parseMarkdown` (= same inline-only
    /// treatment; = preserves whitespace).
    nonisolated static func parseMarkdown(_ raw: String) -> AttributedString {
        ChatTextPartView.parseMarkdown(raw)
    }

    private var cardFill: AnyShapeStyle {
        if isOutgoing {
            return AnyShapeStyle(Color(nsColor: .windowBackgroundColor).opacity(0.12))
        }
        return AnyShapeStyle(.quinary.opacity(0.5))
    }

    private var borderColor: Color {
        (toolResult.isError ? Color(nsColor: .systemRed) : Color(nsColor: .systemGreen)).opacity(0.5)
    }
}

// MARK: - Body view (= iterates parts[])

/// v0.71 P1 batch 2: the canonical renderer for the message body
/// of a `ChatMessage`. Iterates `message.parts[]` (= the Hermes
/// canonical state) and renders each part via the appropriate
/// `Chat*PartView`.
///
/// Falls back to rendering `message.content` (= the legacy v0.34
/// single-string field) when `parts` is empty (= back-compat with
/// older persisted messages that didn't carry parts).
public struct ChatMessageBodyView: View {
    public let message: ChatMessage
    public let isOutgoing: Bool
    public let isStreaming: Bool

    public init(message: ChatMessage, isOutgoing: Bool, isStreaming: Bool = false) {
        self.message = message
        self.isOutgoing = isOutgoing
        self.isStreaming = isStreaming
    }

    public var body: some View {
        // Hermes `MessagePrimitive.Parts` (= the canonical part-by-part
        // render = wenshu's equivalent). We use `ForEach` over
        // `message.parts` (= each part is Identifiable via its UUID)
        // and route through a switch on `part.kind` (= the 4-case
        // enum = text / reasoning / toolUse / toolResult).
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
                ChatPartRow(part: part, isOutgoing: isOutgoing, isStreaming: isStreaming)
            }
        }
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

    var body: some View {
        switch part.kind {
        case .text(let s):
            ChatTextPartView(text: s, isOutgoing: isOutgoing, isStreaming: isStreaming)
        case .reasoning(let s):
            ChatReasoningPartView(text: s, isRunning: isStreaming)
        case .toolUse(let tu):
            ChatToolUsePartView(toolUse: tu, isOutgoing: isOutgoing)
        case .toolResult(let tr):
            ChatToolResultPartView(toolResult: tr, isOutgoing: isOutgoing)
        }
    }
}

// MARK: - User message hover actions (= hermes MessageActions)

/// v0.71 P1 batch 2 (boss 2026-09-12 OOB 'streaming output in the chat zone isn't implemented... port the
/// whole thing from hermes...'): hover actions overlay for user messages (= the
/// Hermes `MessageActions` pattern = copy + delete buttons that fade
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
///
/// Apple HIG convention:
/// - hover = automatic via `.onHover`
/// - opacity fade = `.animation(.easeInOut(duration: 0.15), value: isHovering)`
/// - small icon buttons = `.controlSize(.small)` (= the canonical
///   SwiftUI compact toolbar button)
/// - monospaced icon labels = SF Symbols 6 `doc.on.doc` (= copy)
///   + `trash` (= delete). Canonical Apple HIG chat action
///   affordances (= matches Mail / Messages / Notes).
public struct ChatMessageHoverActions: View {
    /// The message content to copy when the user clicks Copy.
    public let content: String
    @State private var isHovering: Bool = false

    public init(content: String) {
        self.content = content
    }

    public var body: some View {
        HStack(spacing: DesignTokens.chromePaddingSmall) {
            // Copy button (= SF Symbols 6 `document.on.document` icon;
            // = copies the message text to NSPasteboard).
            Button {
                copyToPasteboard()
            } label: {
                Image(systemName: "document.on.document").font(.system(size: 12, weight: .regular))
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .help(WenshuI18n.t("chatview.message_action.copy"))
            // Delete button (= SF Symbols 6 `trash` icon; = marks the
            // message for deletion = the caller wires the actual
            // delete logic via a parent state).
            Button {
                // (= the delete action is wired at the call site via
                // a parent State binding; = this button just emits
                // a Notification for the parent to observe; = the
                // parent can decide whether to remove from the
                // message list or just hide).
                NotificationCenter.default.post(
                    name: .wenshuChatMessageDeleteRequested,
                    object: content
                )
            } label: {
                Image(systemName: "trash").font(.system(size: 12, weight: .regular))
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .help(WenshuI18n.t("chatview.message_action.delete"))
        }
        .padding(.horizontal, DesignTokens.chromePaddingSmall)
        .padding(.vertical, DesignTokens.chromePaddingMicro)
        .background(.regularMaterial, in: Capsule())
        .opacity(isHovering ? 1 : 0)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
    }

    /// Copy the message text to NSPasteboard (= the canonical macOS
    /// clipboard). Uses `NSPasteboard.general` (= the shared system
    /// pasteboard).
    private func copyToPasteboard() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(content, forType: .string)
    }
}

/// Notification name posted when the user clicks the delete button
/// on a chat message (= the parent view observes this notification
/// and wires the actual deletion logic).
extension Notification.Name {
    public static let wenshuChatMessageDeleteRequested = Notification.Name("wenshu.chat.message.deleteRequested")
}

/// View modifier that wires the hover state (= a `View` extension
/// that captures the hover event and stores it in `@State`).
public struct ChatHoverModifier: ViewModifier {
    @State private var isHovering: Bool = false
    public func body(content: Content) -> some View {
        content.onHover { hovering in
            isHovering = hovering
        }
    }
}

public extension View {
    /// Convenience: attach the hover state to any view. The state's
    /// `$isHovering` is NOT exposed (= this modifier is for inline
    /// use where the parent owns its own hover state; = use the
    /// `ChatMessageHoverActions` overlay directly for the canonical
    /// user-message hover pattern).
    @MainActor
    func wenshuChatHover() -> some View {
        modifier(ChatHoverModifier())
    }
}
