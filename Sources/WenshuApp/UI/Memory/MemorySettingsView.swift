//
//  MemorySettingsView.swift · Wenshu · v0.35 ticket 009
//
//  Settings pane for memory subsystem (= spec §6.4 🟥 must-UI).
//  Renders: scope config (per-book vs library-public) + retention settings
//  + memory entries list (= thin facade over MemoryAdapter).
//

import SwiftUI

// File-scope constant (= Apple HIG subtle surface tint = 0.05 alpha).
private let subtleSurfaceAlpha: CGFloat = 0.05

// File-scope constant (= Apple HIG inline form-field label column width).
private let rowLabelWidth: CGFloat = 80

public struct MemorySettingsView: View {
    @State public var scope: MemoryScope = .perBook
    @State public var retentionDays: Int = 90
    @State public var isMemoryEnabled: Bool = true
    @State public var recentEntries: [MemoryAdapter.MemoryEntry] = []

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Memory")
                .font(.headline)
            Text("Wenshu remembers context from past conversations. Configure scope + retention below.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            // Enable toggle
            Toggle("Enable memory subsystem", isOn: $isMemoryEnabled)
                .toggleStyle(.switch)

            // Scope selector
            Picker("Scope", selection: $scope) {
                Text("Per-book only").tag(MemoryScope.perBook)
                Text("Library-public (cross-book)").tag(MemoryScope.libraryPublic)
            }
            .pickerStyle(.segmented)
            .disabled(!isMemoryEnabled)

            // Retention slider
            HStack {
                Text("Retention")
                    .frame(width: rowLabelWidth, alignment: .leading)
                Slider(value: Binding(
                    get: { Double(retentionDays) },
                    set: { retentionDays = Int($0) }
                ), in: 7...365, step: 1)
                .disabled(!isMemoryEnabled)
                Text("\\(retentionDays) days")
                    .monospacedDigit()
                    .frame(width: rowLabelWidth, alignment: .trailing)
            }

            Divider()

            // Recent memory entries list
            Text("Recent memories (\\(recentEntries.count))")
                .font(.subheadline)

            if recentEntries.isEmpty {
                Text("No memories yet. Memories will appear here as you chat.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, DesignTokens.chromePaddingSmall)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(recentEntries) { entry in
                            MemoryEntryRow(entry: entry)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
        .padding(12)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

public enum MemoryScope: String, CaseIterable, Sendable {
    case perBook = "per_book"
    case libraryPublic = "library_public"
}

public struct MemoryEntryRow: View {
    public let entry: MemoryAdapter.MemoryEntry

    public init(entry: MemoryAdapter.MemoryEntry) {
        self.entry = entry
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.snippet)
                .font(.caption)
                .lineLimit(2)
            Text(entry.source)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(6)
        .background(Color.secondary.opacity(subtleSurfaceAlpha), in: RoundedRectangle(cornerRadius: 4))
    }
}