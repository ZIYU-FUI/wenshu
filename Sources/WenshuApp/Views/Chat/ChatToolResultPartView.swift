//
//  ChatToolResultPartView.swift · Wenshu · refactor chat-mvvm-3layer C-9d
//
//  Apple MVVM canonical part view: renders one tool result card
//  (= the "tool X returned Y" cell, paired with the ChatToolUsePartView
//  card above it). Lifted out of ChatPartView.swift so:
//
//  - The chat part surface follows 1-view-1-file.
//  - Tool-result UI can evolve independently of tool-use UI.
//
//  Boss 2026-09-22 '目标 UI，业务，数据，三分离':
//  UI-only (= no business logic).
//

import SwiftUI

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
        .background(cardFill, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
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
