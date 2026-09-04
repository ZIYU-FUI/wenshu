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
                Image(systemName: "brain.head.profile")
                Text("Memory")
                    .font(.headline)
                Spacer()
                Text("\\(entries.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, DesignTokens.chromePaddingChipHorizontal)
            .padding(.top, DesignTokens.chromePaddingSmall)

            if entries.isEmpty {
                VStack {
                    Spacer()
                    Text("No memories retrieved this turn")
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
                    .padding(.horizontal, DesignTokens.chromePaddingChipHorizontal)
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}