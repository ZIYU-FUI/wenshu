//
//  MemorySettingsView.swift · Wenshu
//

import SwiftUI

// (smallChipCornerRadius / subtleSurfaceAlpha removed 2026-10 in
//  q99-spec-p0-batch2 — verify-dead.py confirmed 0 external callers;
//  = the file-private constants were retained as "tiered chrome
//  values" (= smallChipCornerRadius = 3 for chip-level rounding;
//  subtleSurfaceAlpha = 0.05 for subtle surface tint) but the
//  MemorySettingsView now uses DesignTokens.surfaceCornerRadiusSmallChip
//  + .accentTintOpacitySubtle (= the canonical Apple HIG-measured
//  token set; = wenshu-pocock-workflow references/v3.0-design-system-rule.md).
//  See wenshu-dead-code-cleanup SKILL.md.)


struct MemorySettingsView: View {
    @AppStorage(MemoryAdapter.DefaultsKey.enabled)
    var isMemoryEnabled: Bool = true

    @AppStorage(MemoryAdapter.DefaultsKey.scope)
    var scopeRaw: String = MemoryScope.perBook.rawValue

    @AppStorage(MemoryAdapter.DefaultsKey.retentionDays)
    var retentionDays: Int = 90

    @State var recentEntries: [MemoryAdapter.MemoryEntry] = []
    @State var isLoadingEntries: Bool = false
    @State var lastPurgeCount: Int = 0

    init() {}

    var scope: MemoryScope {
        MemoryScope(rawValue: scopeRaw) ?? .perBook
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingModerate) {
            Text(String(localized: "settings.memory.title"))
                .font(.headline)
            Text(String(localized: "settings.memory.subtitle"))
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Toggle(String(localized: "settings.memory.enable"), isOn: $isMemoryEnabled)
                .toggleStyle(.switch)

            Picker(String(localized: "settings.memory.scope"), selection: $scopeRaw) {
                Text(String(localized: "settings.memory.scope.perBook")).tag(MemoryScope.perBook.rawValue)
                Text(String(localized: "settings.memory.scope.libraryPublic")).tag(MemoryScope.libraryPublic.rawValue)
            }
            .pickerStyle(.segmented)
            .disabled(!isMemoryEnabled)

            // Closed-enum retention picker (= wenshu v2.4 product philosophy:
// = users pick from a closed set, no free-text input).
// The numeric slider becomes a Picker over 30 / 90 / 180 / 365 days.
// Each preset maps to a fixed retention budget (= per retentionDays
// in hermes MEMORY_RETENTION_BUCKETS).

            HStack {
                Text(String(localized: "settings.memory.retention"))
                    .frame(width: DesignTokens.settingsRowLabelWidth, alignment: .leading)
                Picker(String(localized: "settings.memory.retention"), selection: $retentionDays) {
                    Text(String(localized: "settings.memory.retention.d30")).tag(30)
                    Text(String(localized: "settings.memory.retention.d90")).tag(90)
                    Text(String(localized: "settings.memory.retention.d180")).tag(180)
                    Text(String(localized: "settings.memory.retention.d365")).tag(365)
                }
                .pickerStyle(.segmented)
                .disabled(!isMemoryEnabled)
            }
            .onChange(of: retentionDays) { _, newValue in
                Task {
                    let deleted = MemoryAdapter().setRetentionDays(newValue)
                    await MainActor.run { self.lastPurgeCount = deleted }
                    await reloadEntries()
                }
            }

            if lastPurgeCount > 0 {
                Text(WenshuI18n.tf("settings.memory.purge.count", lastPurgeCount))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                Text(WenshuI18n.tf("settings.memory.recent", recentEntries.count))
                    .font(.subheadline)
                Spacer()
                if isLoadingEntries {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if recentEntries.isEmpty {
                Text(String(localized: "settings.memory.recent.empty"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, DesignTokens.spacingTight)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
                        ForEach(recentEntries) { entry in
                            MemoryEntryRow(entry: entry, compact: false)
                        }
                    }
                }
                .frame(maxHeight: DesignTokens.settingsListMaxHeight)
            }
        }
        .padding(DesignTokens.spacingModerate)
        // Removed the chrome tier background tint (= .windowBackgroundColor
        // = #1E = creates a visible lighter strip = gone per the
        // 'go up another layer and remove the background' cleanup).
        // Settings panel now matches the surrounding Settings content.
        .task {
            await reloadEntries()
        }
    }

    private func reloadEntries() async {
        await MainActor.run { self.isLoadingEntries = true }
        let entries = MemoryAdapter().recentEntries(limit: 20)
        await MainActor.run {
            self.recentEntries = entries
            self.isLoadingEntries = false
        }
    }
}

enum MemoryScope: String, CaseIterable, Sendable {
    case perBook = "per_book"
    case libraryPublic = "library_public"
}
