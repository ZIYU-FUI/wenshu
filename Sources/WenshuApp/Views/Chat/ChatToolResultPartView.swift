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
// :
//  UI-only (= no business logic).
//

import SwiftUI

struct ChatToolResultPartView: View {
    let toolResult: ChatMessagePart.ToolResultPart
    let isOutgoing: Bool

    @State private var isExpanded: Bool = false
    // chat-diff-sheet 2026-09-28: holds the parsed diff payload
    // (= nil = sheet closed) so the long-diff card can present
    // a tap-to-expand affordance into ChatToolDiffPreviewSheet.
    @State private var sheetDiff: DiffPayload?

    init(toolResult: ChatMessagePart.ToolResultPart, isOutgoing: Bool) {
        self.toolResult = toolResult
        self.isOutgoing = isOutgoing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingIconic) {
            HStack(spacing: DesignTokens.spacingTight) {
                // Success/error icon (= SF Symbol equivalent for the
                // result type = checkmark / exclamation-mark-triangle).
                // -m1-shell boss 2026-09-15 OOB 'remove
                // Lucide, use SF Symbols 6' (= the previous code
                // routed through the now-deleted
                // LucideIconSystemFallback helper to map SF
                // names to Lucide names; = now the SF names
                // are the canonical input directly).
                SFIcon(
                    toolResult.isError ? "exclamationmark.triangle" : "checkmark",
                    style: .inlineSmall,
                    color: toolResult.isError ? Color(nsColor: .systemRed) : Color(nsColor: .systemGreen)
                )
                Text(toolResult.isError
                     ? WenshuI18n.t("chatview.tool_result.error")
                     : WenshuI18n.t("chatview.tool_result.success"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            // chat-diff-preview 2026-09-28: when the tool result is a
            // kind:'diff' envelope (= BookChapterTool.update + future
            // file-edit surfaces emit this), render the unified-diff
            // preview card instead of the markdown fallback (= hermes
            // 0.21.5 file-edit preview surface, 1:1 mirrored).
            // Fall-through for plain text / non-diff envelopes.
            //
            // chat-diff-sheet 2026-09-28: long-diff cards are
            // tappable (= tap opens ChatToolDiffPreviewSheet for
            // the full untruncated diff). Short diffs stay inline
            // (= the tap target = the card body; = sheet would be
            // empty otherwise).
            if let diff = Self.extractDiffPayload(from: toolResult.content) {
                ChatToolDiffPreview(diff: diff.body, filename: diff.path)
                    .padding(.top, DesignTokens.spacingIconic)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        sheetDiff = diff
                    }
            } else {
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
                    .padding(.top, DesignTokens.spacingIconic)
            }
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
                .padding(.top, DesignTokens.spacingIconic / 2)
            }
        }
        .padding(.horizontal, DesignTokens.spacingTight)
        .padding(.vertical, DesignTokens.spacingIconic)
        .background(cardFill, in: RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusCard))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusCard)
                .strokeBorder(borderColor, lineWidth: 1)
        )
        .frame(maxWidth: 360)
        // chat-diff-sheet 2026-09-28: long-diff tap-to-expand host.
        // (= same .sheet(item:) pattern as KanbanView's kanban-card
        // sheet per the kanban-detail-sheet arc; = nil state means
        // sheet closed.)
        .sheet(item: $sheetDiff) { diff in
            ChatToolDiffPreviewSheet(diff: diff.body, filename: diff.path)
        }
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

    /// Parsed `kind:"diff"` payload, surface that feeds
    /// `ChatToolDiffPreview`. nil = fall through to the markdown
    /// render path (= the existing behaviour).
    ///
    /// Mirrors the hermes 0.21.5 file-edit preview card surface:
    /// any tool result carrying `kind:"diff"` routes here so the
    /// chat panel renders +N/−N char counts and red/green diff
    /// lines instead of a flat text blob (= `BookChapterTool`'s
    /// update action emits this envelope; future `WriteChapterTool`
    /// and `EditChapterTool` should follow the same contract).
    ///
    /// `Identifiable` so the chat-tool-result part view can use
    /// it as the `item:` parameter of `.sheet(item:)` for the
    /// long-diff tap-to-expand affordance.
    struct DiffPayload: Equatable, Sendable, Identifiable {
        let id: String
        let path: String
        let oldText: String
        let newText: String
        let body: String           // unified diff text (= rendered)
        let addedChars: Int
        let removedChars: Int

        init(
            id: String = UUID().uuidString,
            path: String,
            oldText: String,
            newText: String,
            body: String,
            addedChars: Int,
            removedChars: Int
        ) {
            self.id = id
            self.path = path
            self.oldText = oldText
            self.newText = newText
            self.body = body
            self.addedChars = addedChars
            self.removedChars = removedChars
        }
    }

    /// Parse the tool result content into a `DiffPayload` if it's a
    /// `kind:"diff"` envelope (= a JSON object with `"kind":"diff"`).
    /// Returns nil for plain-text / non-diff envelopes (= those fall
    /// through to the existing markdown render).
    nonisolated static func extractDiffPayload(from content: String) -> DiffPayload? {
        // Fast path: must look like a JSON envelope (= starts with '{').
        // This avoids paying JSONSerialization on every tool result.
        guard content.first == "{" else { return nil }
        let data = Data(content.utf8)
        guard let obj = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return nil
        }
        guard obj["kind"] as? String == "diff" else { return nil }
        guard let diff = obj["diff"] as? [String: Any] else { return nil }
        let stats = diff["stats"] as? [String: Any] ?? [:]
        let body = (obj["diff_text"] as? String)
            ?? (diff["text"] as? String)
            ?? Self.reconstructDiffBody(diff: diff)
        return DiffPayload(
            path: diff["path"] as? String ?? "untitled.md",
            oldText: diff["old_text"] as? String ?? "",
            newText: diff["new_text"] as? String ?? "",
            body: body,
            addedChars: stats["added_chars"] as? Int ?? 0,
            removedChars: stats["removed_chars"] as? Int ?? 0
        )
    }

    /// Best-effort reconstruction of a unified-diff body when only
    /// `old_text` / `new_text` are present (= useful for tool
    /// envelopes from other surfaces that didn't emit `diff_text`).
    /// The result still carries +N/-N counts through `ChatToolDiffPreview`.
    private nonisolated static func reconstructDiffBody(diff: [String: Any]) -> String {
        let oldText = diff["old_text"] as? String ?? ""
        let newText = diff["new_text"] as? String ?? ""
        let oldLines = oldText.components(separatedBy: "\n")
        let newLines = newText.components(separatedBy: "\n")
        var out = "--- old\n+++ new\n@@\n"
        for line in oldLines where !line.isEmpty {
            out += "-\(line)\n"
        }
        for line in newLines where !line.isEmpty {
            out += "+\(line)\n"
        }
        return out
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

/// 
/// of a `ChatMessage`. Iterates `message.parts[]` (= the Hermes
/// canonical state) and renders each part via the appropriate
/// `Chat*PartView`.
///
/// Falls back to rendering `message.content` (= the legacy v0.34
/// single-string field) when `parts` is empty (= back-compat with
