//
//  MemoryEntryRow.swift · Wenshu · v0.35 ticket 009 followup
//
//  Single source of truth for memory entry display rows.
//  Originally two near-identical structs (= MemoryEntryRow in
//  MemorySettingsView.swift + MemoryEntryRowCompact in
//  DynamicZoneMemoryPanel.swift); unified here per Standards-axis S4
//  Duplicated Code smell.
//
//  Two display variants via `compact: Bool` flag:
//  - compact = false (MemorySettingsView, full Settings pane context):
//    VStack { snippet lineLimit 2, source } with full chip background
//  - compact = true (DynamicZoneMemoryPanel, sidebar context):
//    VStack { snippet lineLimit 2, HStack { source + relevance score % } }
//    with subtle background tint
//
//  Per /domain-modeling 'update CONTEXT.md inline' rule, this is a
//  vocabulary primitive (= display row type, not a domain entity).
//

import SwiftUI

public struct MemoryEntryRow: View {
    public let entry: MemoryAdapter.MemoryEntry
    public let compact: Bool

    public init(entry: MemoryAdapter.MemoryEntry, compact: Bool = false) {
        self.entry = entry
        self.compact = compact
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.chromePaddingMicro) {
            Text(entry.snippet)
                .font(compact ? .caption2 : .caption)
                .lineLimit(2)
            if compact {
                HStack {
                    Text(entry.source)
                        .font(.caption2)
                        .foregroundStyle(DesignTokens.statusForeground)
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
            }
        }
        .padding(DesignTokens.chromePaddingMicro)
        .background(
            Color.secondary.opacity(compact ? 0.5 : DesignTokens.surfaceActiveTintAlpha),
            in: RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusSmallChip, style: .continuous)
        )
    }
}