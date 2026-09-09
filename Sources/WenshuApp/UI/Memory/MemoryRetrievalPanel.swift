//
//  MemoryRetrievalPanel.swift · Wenshu · v0.35 ticket 009
//
//  Right-bottom panel for DynamicZone showing memory retrieval
//  (= spec §6.4 🟨 half-visible).
//
//  Displays the memories retrieved for the current turn, with source
//  file paths. Shown alongside the main chat view as a side panel.
//

import SwiftUI

public struct MemoryRetrievalPanel: View {
    @State public var entries: [MemoryAdapter.MemoryEntry]

    public init(entries: [MemoryAdapter.MemoryEntry] = []) {
        self._entries = State(initialValue: entries)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                LucideIcon("brain", size: 16)
                Text(WenshuI18n.t("b5.memoryretrievalpanel.l24.h99228791"))
                    .font(.headline)
                Spacer()
                Text(WenshuI18n.t("b5.memoryretrievalpanel.l27.h94615601"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            // STYLES-004 (2026-09-07): use the canonical content
            // inset modifier (= 18 PT horizontal + 6 PT top = boss
            // 9/7 round 2 audit recipe for memory panel). Previously
            // this was .padding(.horizontal, chromePaddingChipHorizontal
            // = 10 PT) + .padding(.top, chromePaddingSmall = 6 PT) =
            // 10 PT horizontal = too tight (= boss 'zone 6 too small').
            // chromePaddingLeading (= 8 PT per Apple HIG; = the value of
             // DesignTokens.chromePaddingLeading per boss 9/8
             // 'Apple API default spacing isn't PT, it's a semantic
             // name' = the semantic name is '.small' = 8 PT)
             // matches the rest of the
            // chrome (= zone chrome top bar uses 18 PT).
            .contentInsetStyle(.custom(18), edges: .horizontal)
            .padding(.top, DesignTokens.chromePaddingSmall)

            if entries.isEmpty {
                VStack {
                    Spacer()
                    Text(WenshuI18n.t("memory.no_entries"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(entries) { entry in
                            MemoryEntryRow(entry: entry)
                        }
                    }
                    // STYLES-004 (2026-09-07): use canonical 18 PT
                    // horizontal inset (= was 10 PT = too tight).
                    .contentInsetStyle(.custom(18), edges: .horizontal)
                }
            }
        }
        // v0.40 boss 2026-09-08 OOB 'sweep for remaining background colors: removed the
        // chrome tier background tint (= .controlBackgroundColor
        // = #1E = visible chrome tier = lighter than the surrounding
        // pane content = creates a visible strip in the memory
        // panel area = boss wants gone per the 'go up another layer and remove the background'
        // cleanup round). MemoryRetrievalPanel now matches the
        // surrounding tool zone's content tier (= no chrome tier
        // distinction per the v0.40 chrome cleanup).
    }
}