//
//  MemorySettingsView.swift · Wenshu · v0.35 ticket 009
//  + SETTINGS-PERSISTENCE-001 (2026-09-05).
//

import SwiftUI

private let smallChipCornerRadius: CGFloat = 3
private let subtleSurfaceAlpha: CGFloat = 0.05


public struct MemorySettingsView: View {
    @AppStorage(MemoryAdapter.DefaultsKey.enabled)
    public var isMemoryEnabled: Bool = true

    @AppStorage(MemoryAdapter.DefaultsKey.scope)
    public var scopeRaw: String = MemoryScope.perBook.rawValue

    @AppStorage(MemoryAdapter.DefaultsKey.retentionDays)
    public var retentionDays: Int = 90

    @State public var recentEntries: [MemoryAdapter.MemoryEntry] = []
    @State public var isLoadingEntries: Bool = false
    @State public var lastPurgeCount: Int = 0

    public init() {}

    public var scope: MemoryScope {
        MemoryScope(rawValue: scopeRaw) ?? .perBook
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.chromePaddingMedium) {
            Text(WenshuI18n.t("settings.memory.title"))
                .font(.headline)
            Text(WenshuI18n.t("settings.memory.subtitle"))
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Toggle(WenshuI18n.t("settings.memory.enable"), isOn: $isMemoryEnabled)
                .toggleStyle(.switch)

            Picker(WenshuI18n.t("settings.memory.scope"), selection: $scopeRaw) {
                Text(WenshuI18n.t("settings.memory.scope.perBook")).tag(MemoryScope.perBook.rawValue)
                Text(WenshuI18n.t("settings.memory.scope.libraryPublic")).tag(MemoryScope.libraryPublic.rawValue)
            }
            .pickerStyle(.segmented)
            .disabled(!isMemoryEnabled)

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
            .onChange(of: retentionDays) { _, newValue in
                Task {
                    let deleted = await MemoryAdapter().setRetentionDays(newValue)
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
                Text(WenshuI18n.t("settings.memory.recent.empty"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, DesignTokens.chromePaddingSmall)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignTokens.chromePaddingSmall) {
                        ForEach(recentEntries) { entry in
                            MemoryEntryRow(entry: entry, compact: false)
                        }
                    }
                }
                .frame(maxHeight: DesignTokens.settingsListMaxHeight)
            }
        }
        .padding(DesignTokens.chromePaddingMedium)
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            await reloadEntries()
        }
    }

    private func reloadEntries() async {
        await MainActor.run { self.isLoadingEntries = true }
        let entries = await MemoryAdapter().recentEntries(limit: 20)
        await MainActor.run {
            self.recentEntries = entries
            self.isLoadingEntries = false
        }
    }
}

public enum MemoryScope: String, CaseIterable, Sendable {
    case perBook = "per_book"
    case libraryPublic = "library_public"
}
