//
//  MemorySettingsView.swift · Wenshu · v0.35 ticket 009
//
//  Settings pane for memory subsystem (= spec §6.4 🟥 must-UI).
//  Renders: scope config (per-book vs library-public) + retention settings
//  + memory entries list (= thin facade over MemoryAdapter).
//

import SwiftUI

// File-scope constant (= Apple HIG small-chip corner radius standard).
private let smallChipCornerRadius: CGFloat = 3

// File-scope constant (= Apple HIG subtle surface tint = 0.05 alpha).
private let subtleSurfaceAlpha: CGFloat = 0.05


public struct MemorySettingsView: View {
    @State public var scope: MemoryScope = .perBook
    @State public var retentionDays: Int = 90
    @State public var isMemoryEnabled: Bool = true
    @State public var recentEntries: [MemoryAdapter.MemoryEntry] = []

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(WenshuI18n.t("settings.memory.title"))
                .font(.headline)
            Text(WenshuI18n.t("settings.memory.subtitle"))
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            // Enable toggle
            Toggle(WenshuI18n.t("settings.memory.enable"), isOn: $isMemoryEnabled)
                .toggleStyle(.switch)

            // Scope selector
            Picker(WenshuI18n.t("settings.memory.scope"), selection: $scope) {
                Text(WenshuI18n.t("settings.memory.scope.perBook")).tag(MemoryScope.perBook)
                Text(WenshuI18n.t("settings.memory.scope.libraryPublic")).tag(MemoryScope.libraryPublic)
            }
            .pickerStyle(.segmented)
            .disabled(!isMemoryEnabled)

            // Retention slider
            HStack {
                Text(WenshuI18n.t("settings.memory.retention"))
                    .frame(width: DesignTokens.settingsRowLabelWidth, alignment: .leading)
                Slider(value: Binding(
                    get: { Double(retentionDays) },
                    set: { retentionDays = Int($0) }
                ), in: 7...365, step: 1)
                .disabled(!isMemoryEnabled)
                Text(WenshuI18n.tf("settings.memory.retention.value", retentionDays))
                    .monospacedDigit()
                    .frame(width: DesignTokens.settingsRowLabelWidth, alignment: .trailing)
            }

            Divider()

            // Recent memory entries list
            Text(WenshuI18n.tf("settings.memory.recent", recentEntries.count))
                .font(.subheadline)

            if recentEntries.isEmpty {
                Text(WenshuI18n.t("settings.memory.recent.empty"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, DesignTokens.chromePaddingSmall)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(recentEntries) { entry in
                            MemoryEntryRow(entry: entry, compact: false)
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
