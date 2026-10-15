//
//  MemoryEntryRow.swift
//
//  Single source of truth for memory entry display rows.
//  Originally two near-identical structs (= MemoryEntryRow in
//  MemorySettingsView.swift + MemoryEntryRowCompact in
//  MemoryRetrievalPanel.swift); unified here per Standards-axis S4 .
//  Duplicated Code smell.
//
//  Two display variants via `compact: Bool` flag:
//  - compact = false (MemorySettingsView, full Settings pane context):
//    VStack { snippet lineLimit 2, source } with full chip background
//  - compact = true (MemoryRetrievalPanel, DynamicZone sidebar):
//    VStack { snippet lineLimit 2, HStack { source + relevance score % } }
//    with subtle background tint
//
//  Per /domain-modeling 'update CONTEXT.md inline' rule, this is a
//  vocabulary primitive (= display row type, not a domain entity).
//

import SwiftUI

struct MemoryEntryRow: View {
    let entry: MemoryAdapter.MemoryEntry
    let compact: Bool

    init(entry: MemoryAdapter.MemoryEntry, compact: Bool = false) {
        self.entry = entry
        self.compact = compact
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingIconic) {
            Text(entry.snippet)
                .font(compact ? .caption2 : .caption)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            if compact {
                HStack {
                    Text(entry.source)
                        .font(.caption2)
                        .foregroundStyle(DesignTokens.statusForeground)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    if entry.relevanceScore > 0 {
                        Text(String(format: "%.0f%%", entry.relevanceScore * 100))
                            .font(.caption2)
                            .foregroundStyle(DesignTokens.statusForeground)
                    }
                }
            } else {
                Text(entry.source)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    // The `source` (= "memory:<UUID>" — 36-char hex id)
                    // is structurally a fixed-width one-line token. On
                    // macOS 27 SwiftUI Settings scenes (= Apple
                    // default Form cell rendering), `.caption2`
                    // defaults to `.lineLimit(1)` — a single-line
                    // 41-char token silently forced SwiftUI to expand
                    // the Settings window horizontally (= the user's
                    // 2026-10-12 "还是很宽 这一页的 UI 没有调整" complaint
                    // while they were on the 记忆 pane). `.lineLimit(2)`
                    // + `.fixedSize(horizontal: false, vertical: true)`
                    // lets the UUID wrap to two lines instead of
                    // stretching the window past the user's
                    // `.defaultSize(width: 950, height: 517)` =
                    // the canonical Apple-HIG fix for the same
                    // `.lineLimit(2) + .lineLimit(nil)` recipe used
                    // earlier in this arc on `model.reasoning.effortHint`).
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DesignTokens.spacingIconic)
        // `.fixedSize(horizontal: false, vertical: true)` (= horizontal
        // `flexible` so the row respects the parent's horizontal cap;
        // vertical `fit` so row height grows with content)
        // design-system canonical way to let a long snippet wrap to
        // multiple lines without expanding the parent (= SwiftUI
        // macOS 27 Form/VStack otherwise expands horizontally to fit
        // the widest intrinsic content line). = the user's 2026-10-12
        // "还是很宽 这一页的 UI 没有调整" report was rooted here: the
        // MemoryEntryRow outer VStack was 0-constrained horizontally,
        // so a 36-char UUID source line forced the row (= and thus the
        // Form column and the Settings window) to widen past the
        // requested `.defaultSize(950, 517)`. The same recipe shipped
        // earlier in this arc on `model.reasoning.effortHint` for
        // the same root cause.
        .fixedSize(horizontal: false, vertical: true)
        .background(
            // macOS 27 doc-alignment ((see OOB.md #2026-09-18) —
            // '', ): HierarchicalShapeStyle.tertiary
            // (= Apple semantic ShapeStyle = auto-adapts to dark
            // mode + Liquid Glass). Color.secondary.opacity(N)
            // is a static gray that does NOT adapt to dark mode
            // or accent tint. Wrap in AnyShapeStyle for the
            // .background ShapeStyle parameter.
            AnyShapeStyle(.tertiary.opacity(compact ? 0.5 : DesignTokens.surfaceActiveTintAlpha)),
            in: RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusSmallChip, style: .continuous)
        )
    }
}