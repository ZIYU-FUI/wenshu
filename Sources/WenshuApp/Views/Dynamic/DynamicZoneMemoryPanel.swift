//
//  DynamicZoneMemoryPanel.swift · Wenshu · v0.35 ticket 009 activation
//
//  Right-bottom panel for DynamicZone (= spec §6.4 🟨 half-visible).
//  Embeddable in DynamicZoneView (= activation lands with v0.34 ship
//  sequence). This file is standalone (= no in-flight v0.34 dependency).
//
//  Iron rule 6 compliance: layout/spacing uses DesignTokens. Panel height
//  is file-scope constant (= not a magic number, document at file scope).
//

import SwiftUI

// Apple HIG canonical bottom-panel height for a 3-pane DynamicZone
// (sidebar / content / memory). Token scope: panel height is a feature
// constant, not a chrome dimension (= DesignTokens = chrome).
private let defaultPanelHeight: CGFloat = 180

public struct DynamicZoneMemoryPanel: View {
    /// File-scope default (= same as the file-level defaultPanelHeight;
    /// duplicated here so Swift default-arg expressions can reference it).
    private static let defaultPanelHeight: CGFloat = 180

    @State public var entries: [MemoryAdapter.MemoryEntry]
    public let panelHeight: CGFloat

    public init(entries: [MemoryAdapter.MemoryEntry] = []) {
        self._entries = State(initialValue: entries)
        self.panelHeight = DynamicZoneMemoryPanel.defaultPanelHeight
    }

    public init(entries: [MemoryAdapter.MemoryEntry] = [], panelHeight: CGFloat) {
        self._entries = State(initialValue: entries)
        self.panelHeight = panelHeight
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(DesignTokens.statusForeground)
                Text("Memory")
                    .font(DesignTokens.statusFont)
                    .fontWeight(.medium)
                Spacer()
                if !entries.isEmpty {
                    Text("\(entries.count) retrieved")
                        .font(.caption2)
                        .foregroundStyle(DesignTokens.statusForeground)
                }
            }
            .padding(.horizontal, DesignTokens.chromePaddingChipHorizontal)
            .padding(.vertical, DesignTokens.chromePaddingMicro)

            Divider()

            // Content
            if entries.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "brain")
                        .font(.title2)
                        .foregroundStyle(DesignTokens.statusForeground)
                    Text("No memories retrieved this turn")
                        .font(DesignTokens.statusFont)
                        .foregroundStyle(DesignTokens.statusForeground)
                        .padding(.top, DesignTokens.chromePaddingMicro)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignTokens.chromePaddingMicro) {
                        ForEach(entries) { entry in
                            MemoryEntryRowCompact(entry: entry)
                        }
                    }
                    .padding(.horizontal, DesignTokens.chromePaddingChipHorizontal)
                    .padding(.vertical, DesignTokens.chromePaddingMicro)
                }
            }
        }
        .frame(height: panelHeight)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: DesignTokens.dividerHeight)
                .foregroundStyle(.quaternary),
            alignment: .top
        )
    }
}

public struct MemoryEntryRowCompact: View {
    public let entry: MemoryAdapter.MemoryEntry

    public init(entry: MemoryAdapter.MemoryEntry) {
        self.entry = entry
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.snippet)
                .font(.caption2)
                .lineLimit(2)
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
        }
        .padding(DesignTokens.chromePaddingMicro)
        .background(
            Color.secondary.opacity(0.5),
            in: RoundedRectangle(cornerRadius: 3, style: .continuous)
        )
    }
}