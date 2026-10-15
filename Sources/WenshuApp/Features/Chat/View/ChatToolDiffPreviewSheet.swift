//
//  ChatToolDiffPreviewSheet.swift · wenshu · chat-diff-sheet 2026-09-28
//
//  Long-diff sheet (= future ticket 3 of §11.20 + the long-form
//  counterpart to KanbanTicketDetailSheet). When the LLM produces
//  a chapter edit with a multi-line body change (= old_text /
//  new_text spanning many lines), the inline ChatToolDiffPreview
//  truncates at .lineLimit(6) (= same UX as kanban cards). The
//  user can tap the card to open this sheet and see the full
//  diff (= untruncated, scrollable, textSelection(.enabled) for
//  clipboard copy).
//
//  Apple HIG: NavigationStack + toolbar Close. Mirrors
//  KanbanTicketDetailSheet's structural choices so the two
//  "tap-to-expand diff" surfaces share visual identity.
//

import SwiftUI

/// Long-form diff sheet (= tap a ChatToolDiffPreview to open).
/// Mirrors KanbanTicketDetailSheet's NavigationStack + toolbar Close
/// structure so the chat surface and kanban surface share one
/// "expand" affordance.
struct ChatToolDiffPreviewSheet: View {
    let diff: String
    let filename: String

    private var display: String { ChatToolDiffPreview.stripFileHeaders(diff) }
    private var stats: ChatToolDiffPreview.LineStats {
        ChatToolDiffPreview.countLineStats(display)
    }

    /// Close button (= Apple HIG macOS convention = toolbar
    /// navigation item + .cancellation action label).
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content
                .padding(.horizontal, DesignTokens.spacingTight)
                .padding(.vertical, DesignTokens.spacingTight)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .navigationTitle(filename)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "chatview.diff_sheet.close")) {
                    dismiss()
                }
            }
        }
        .frame(minWidth: 540, minHeight: 360)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
            header
            diffBody
        }
    }

    private var header: some View {
        HStack(spacing: DesignTokens.spacingTight) {
            SFIcon("doc.text", style: .inlineSmall, color: IconColor.secondary)
            Text(filename)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
            HStack(spacing: DesignTokens.spacingIconic) {
                Text("+\(stats.addedChars)")
                    .foregroundStyle(.green)
                Text("−\(stats.removedChars)")
                    .foregroundStyle(.red)
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    /// Scrollable, selectable diff body. Reuses the same per-line
    /// color + present logic as the inline preview (= so the user
    /// sees the same visual model in both states).
    private var diffBody: some View {
        let lines = display.split(separator: "\n", omittingEmptySubsequences: false)
        return ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(ChatToolDiffPreview.present(line: String(line)))
                        .font(.caption.monospaced())
                        .foregroundStyle(ChatToolDiffPreview.color(for: String(line)))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, DesignTokens.spacingIconic)
                        .padding(.vertical, DesignTokens.spacingHairline)
                        .textSelection(.enabled)
                }
            }
            .padding(.vertical, DesignTokens.spacingIconic)
        }
        .background(
            AnyShapeStyle(.quinary.opacity(0.3)),
            in: RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusProgressCard)
        )
    }
}