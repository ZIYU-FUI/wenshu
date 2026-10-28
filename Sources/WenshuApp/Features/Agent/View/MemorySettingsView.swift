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
//  (= the canonical Apple HIG-measured token set;
//  = wenshu-pocock-workflow/references/design-system-rule.md).
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

    // Where the memories live. Backed by the agent settings store rather than
    // its own @AppStorage, because ContextEngine reads the same value when it
    // resolves a provider: two copies of one setting drift, and the drift shows
    // up as memory that was written somewhere the reader never looks.
    @State private var backend: MemoryBackend = AgentSettingsStore.shared.load().memory.backend
    @State private var remoteEndpoint: String = AgentSettingsStore.shared.load().memory.remoteEndpoint

    /// What the engine actually used last turn. Non-nil with a reason means the
    /// choice above is not what is running, and the user needs to know why.
    @State private var substitutionNotice: MemoryBackendProblem?

    init() {}

    // MARK: - Where the memories live

    /// Two options answering two different questions, presented as a radio
    /// group rather than a picker: each carries a paragraph saying what it
    /// costs, and a segmented control has no room for that. The order is
    /// local first because it needs nothing (= choosing it must not feel like
    /// a decision about infrastructure).
    private var backendSection: some View {
        Section {
            backendRow(.localMarkdown)
            backendRow(.remoteService)
        } header: {
            Text(String(localized: "settings.memory.backend.title"))
        } footer: {
            if let problem = substitutionNotice {
                Text(problem.explanation)
                    .foregroundStyle(.secondary)
            } else {
                Text(String(localized: "settings.memory.backend.footer"))
            }
        }
    }

    private func backendRow(_ option: MemoryBackend) -> some View {
        let description = MemoryBackendResolver.description(for: option)
        return Button {
            backend = option
            persistBackend()
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: backend == option ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(backend == option ? Color.accentColor : .secondary)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 3) {
                    Text(description.title)
                        .foregroundStyle(.primary)
                    Text(backendDetail(option))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isMemoryEnabled)
        .accessibilityLabel(description.title)
        .accessibilityValue(backend == option ? String(localized: "settings.agent.selected") : "")
    }

    /// Localised detail line for one backend.
    ///
    /// Written as a switch rather than interpolating the raw value into the
    /// key: String(localized:) takes its key as a compile-time literal, so an
    /// interpolated one is treated as a literal string and renders as itself.
    /// That failure is invisible in a unit test and obvious on screen.
    private func backendDetail(_ option: MemoryBackend) -> String {
        switch option {
        case .localMarkdown:
            return String(localized: "settings.memory.backend.localMarkdown.detail")
        case .remoteService:
            return String(localized: "settings.memory.backend.remoteService.detail")
        }
    }

    @ViewBuilder
    private var remoteEndpointSection: some View {
        if backend == .remoteService {
            Section {
                TextField(
                    String(localized: "settings.memory.backend.remote.endpoint"),
                    text: $remoteEndpoint
                )
                .textContentType(.URL)
                .onSubmit { persistBackend() }
            } header: {
                Text(String(localized: "settings.memory.backend.remote.title"))
            } footer: {
                Text(String(localized: "settings.memory.backend.remote.footer"))
            }
        }
    }

    /// Write the choice where the turn runtime reads it, then ask the engine
    /// what it would actually use. A choice that cannot be honoured comes back
    /// with a reason, and the footer shows it rather than letting the user
    /// believe a setting took effect.
    private func persistBackend() {
        var settings = AgentSettingsStore.shared.load()
        settings.memory.backend = backend
        settings.memory.remoteEndpoint = remoteEndpoint
        AgentSettingsStore.shared.save(settings)

        let resolver = ContextEngine.makeBackendResolver(settings: settings.memory)
        substitutionNotice = resolver.resolve(settings: settings.memory)?.substitutedReason
    }

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
            backendSection
            remoteEndpointSection

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

            // The prompt cache's saving, per conversation.
            //
            // It lives here because the memory pane is the agent's
            // running-state surface, and the number is only meaningful
            // next to the conversation it belongs to (= the running
            // chat). The agent settings pane is owned by another card,
            // so the control does not go there.
            //
            // No conversation id: the settings pane is not the chat, so
            // the most recent conversation's total is the one shown.
            PromptCacheStatusView(conversationId: nil)
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
