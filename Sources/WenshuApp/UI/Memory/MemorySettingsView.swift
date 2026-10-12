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

    // The recent-entries / loading-state trio was moved to the
    // independent `MemoryHistoryView` per the user's 2026-10-12
    // directive (= the inline list that used to live here is now
    // a separate `Window` Scene). The retention-change callback
    // (= `lastPurgeCount` + `reloadEntries`) is preserved because
    // the configuration surface still wants to surface "N memories
    // purged" after a retention-change.
    @State var lastPurgeCount: Int = 0

    init() {}

    var scope: MemoryScope {
        MemoryScope(rawValue: scopeRaw) ?? .perBook
    }

    var body: some View {
        // The inline "最近记忆" list (= 100-row cap, scrollable)
        // that used to live here was moved to the independent
        // `MemoryHistoryView` (= `Sources/WenshuApp/UI/Memory/
        // MemoryHistoryView.swift`) per the user's 2026-10-12
        // directive "最近记忆不应该在设置中, 而是在一个独立的
        // weindows, 在工具栏加一个 ICON 入口, 做一个独立
        // windows 放记忆历史". This pane now owns the configuration
        // surface only (= enable / scope / retention) and the
        // list entry lives in its own `Window` Scene
        // (`WindowID.memoryHistory`).
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
                    // The `reloadEntries()` call was removed when
                    // the inline list was moved to the independent
                    // `MemoryHistoryView` (= the configuration
                    // surface no longer holds the entries array,
                    // = reload is the new window's responsibility).
                    // The purge count stays here so the "N memories
                    // purged" footer keeps updating on retention
                    // changes.
                    let deleted = MemoryAdapter().setRetentionDays(newValue)
                    await MainActor.run { self.lastPurgeCount = deleted }
                }
            }

            if lastPurgeCount > 0 {
                Text(String.localizedStringWithFormat(NSLocalizedString("settings.memory.purge.count", comment: ""), lastPurgeCount))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(DesignTokens.spacingModerate)
        // Removed the chrome tier background tint (= .windowBackgroundColor
        // = #1E = creates a visible lighter strip = gone per the
        // 'go up another layer and remove the background' cleanup).
        // Settings panel now matches the surrounding Settings content.
        // The `.task { await reloadEntries() }` block was removed
        // alongside the inline list (= `recentEntries` /
        // `isLoadingEntries` no longer exist; = the configuration
        // surface reads from `lastPurgeCount` only, which the
        // retention-change callback updates in place).
    }
}

enum MemoryScope: String, CaseIterable, Sendable {
    case perBook = "per_book"
    case libraryPublic = "library_public"
}
