//
//  MemoryHistoryView.swift · Wenshu
//
//  Independent 记忆 history window (= the user-facing surface
//  for the per-conversation memory write history that previously
//  lived inlined inside `MemorySettingsView`).
//
//  Standards axis:
//    S1 (Apple-API-first): pure SwiftUI primitives + Apple HIG
//        `controlSize(.regular)` + SF Symbols 6 (= the toolbar
//        brain icon + the per-row `brain` SF Symbol).
//    S2 (tool philosophy): read-only listing (= no CRUD surface;
//        = toggling / scope / retention stay in `MemorySettingsView`
//        inside the Settings scene).
//    S3 (single source of truth): reads memory entries via
//        `MemoryAdapter.recentEntries(limit:)` (= the canonical
//        fetch path shared with the original inline list).
//
//  Matched on the v2.9b independent-window pattern (= Kanban /
//  Todo / Summaries / Attachments / Manifest / Foreshadowing /
//  Canvas / Composer / Cron): `Window(id: WindowID.memoryHistory)`
//  mounted as a single-instance Scene = the user can't open
//  duplicates and tapping the toolbar entry while the window is
//  already shown brings it to front (= macOS HIG canonical
//  behavior for utility panels).
//

import SwiftUI

struct MemoryHistoryView: View {
    @State private var entries: [MemoryAdapter.MemoryEntry] = []
    @State private var isLoading: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingModerate) {
            // H4 — the `window.memoryHistory.title` / `.subtitle`
            // keys land the canonical Apple-HIG `panel + helper text`
            // pairing (= a bold title + a 1-line secondary caption).
            Text(String(localized: "window.memoryHistory.title"))
                .font(.headline)
            Text(String(localized: "window.memoryHistory.subtitle"))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Text(String.localizedStringWithFormat(
                    NSLocalizedString("settings.memory.recent", comment: ""),
                    entries.count
                ))
                .font(.subheadline)
                Spacer()
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if entries.isEmpty {
                Text(String(localized: "settings.memory.recent.empty"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, DesignTokens.spacingTight)
            } else {
                // `frame(maxHeight: .infinity)` (= take whatever
                // vertical space is left after the title + count row;
                // = the window's `.contentSize` resize policy will
                // size the window around this content; = adds the
                // Apple HIG canonical "swim in the leftover space"
                // behavior = the list expands to fill the window
                // height instead of being clipped at a fixed cap).
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
                        ForEach(entries) { entry in
                            MemoryEntryRow(entry: entry, compact: false)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .padding(DesignTokens.spacingModerate)
        .task {
            await reload()
        }
    }

    private func reload() async {
        await MainActor.run { self.isLoading = true }
        let fresh = MemoryAdapter().recentEntries(limit: 200)
        await MainActor.run {
            self.entries = fresh
            self.isLoading = false
        }
    }
}
