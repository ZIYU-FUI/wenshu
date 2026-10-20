//
//  MemorySettingsView.swift · Wenshu
//

import SwiftUI
import WenshuAgent

// (smallChipCornerRadius / subtleSurfaceAlpha removed 2026-10 in
//  q99-spec-p0-batch2 — verify-dead.py confirmed 0 external callers;
//  = the file-private constants were retained as "tiered chrome
//  values" (= smallChipCornerRadius = 3 for chip-level rounding;
//  subtleSurfaceAlpha = 0.05 for subtle surface tint) but the
//  MemorySettingsView now uses DesignTokens.surfaceCornerRadiusSmallChip
//  + .accentTintOpacitySubtle (= the canonical Apple HIG-measured
//  token set; = wenshu-pocock-workflow/references/design-system-rule.md).
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
        // Canonical Apple HIG macOS Settings layout (= Form with
        // `.grouped` style; = the same shape the other Settings panes
        // use, including the freshly-added "网络" (= Network) pane).
        // The previous incarnation used a custom `VStack + .padding`
        // (= title + subtitle + Divider + Toggle + 2 segmented
        // pickers) which broke visual consistency with the rest of
        // the Settings scene tree.
        // Each logical row now lives in its own Section (= header +
        // content + footer per Apple settings convention): Section
        // 1 = the description + enable toggle (= the conceptual
        // on/off for the entire Memory subsystem); Section 2 = the
        // per-book / library-wide scope selector; Section 3 = the
        // closed-enum retention picker (= 30 / 90 / 180 / 365 days)
        // + last-purge confirmation footer.
        Form {
            Section {
                Toggle(String(localized: "settings.memory.enable"), isOn: $isMemoryEnabled)
                    .toggleStyle(.switch)
            } header: {
                Text(String(localized: "settings.memory.title"))
            } footer: {
                Text(String(localized: "settings.memory.subtitle"))
            }

            Section {
                Picker(String(localized: "settings.memory.scope"), selection: $scopeRaw) {
                    Text(String(localized: "settings.memory.scope.perBook")).tag(MemoryScope.perBook.rawValue)
                    Text(String(localized: "settings.memory.scope.libraryPublic")).tag(MemoryScope.libraryPublic.rawValue)
                }
                .pickerStyle(.segmented)
                .disabled(!isMemoryEnabled)
            } header: {
                Text(String(localized: "settings.memory.scope"))
            }

            Section {
                Picker(String(localized: "settings.memory.retention"), selection: $retentionDays) {
                    Text(String(localized: "settings.memory.retention.d30")).tag(30)
                    Text(String(localized: "settings.memory.retention.d90")).tag(90)
                    Text(String(localized: "settings.memory.retention.d180")).tag(180)
                    Text(String(localized: "settings.memory.retention.d365")).tag(365)
                }
                .pickerStyle(.segmented)
                .disabled(!isMemoryEnabled)
            } header: {
                Text(String(localized: "settings.memory.retention"))
            } footer: {
                if lastPurgeCount > 0 {
                    Text(String.localizedStringWithFormat(NSLocalizedString("settings.memory.purge.count", comment: ""), lastPurgeCount))
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(String(localized: "settings.memory.title"))
        .onChange(of: retentionDays) { _, newValue in
            Task {
                let deleted = MemoryAdapter().setRetentionDays(newValue)
                await MainActor.run { self.lastPurgeCount = deleted }
            }
        }
    }
}

enum MemoryScope: String, CaseIterable, Sendable {
    case perBook = "per_book"
    case libraryPublic = "library_public"
}
