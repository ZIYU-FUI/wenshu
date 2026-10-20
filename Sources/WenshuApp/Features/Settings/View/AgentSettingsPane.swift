//
// AgentSettingsPane.swift · Wenshu
//
// Which tools the agent may use, and how it should behave (see OOB.md
// #2026-10-20: give users at different levels of comfort with AI different
// choices, keep the third-party options, recommend what is reachable from
// here).
//
// Layout is Apple HIG macOS Settings: a grouped Form, one Section per
// question, each with a header and a footer that says what the choice costs.
// The footers are the load-bearing part. A checkbox labelled "web search"
// teaches nothing; "搜索会联网" tells a user whether turning it on means their
// text leaves the machine, which is the thing they are actually deciding.
//
// Presets rather than twenty checkboxes, because the presets are ordered by
// how much they cost and a user picks a level rather than assembling a set.
// The full list stays visible underneath for anyone who wants it, so the
// preset is a shortcut and not a ceiling.

import SwiftUI
import WenshuAgent

struct AgentSettingsPane: View {
    /// Saved settings. A draft rather than a live binding, so cancelling a
    /// dialog has not already changed what the agent does.
    @State private var draft = AgentSettingsStore.shared.load()
    @State private var enabledPresets: [String] = AgentSettingsStore.shared.loadEnabledPresetIDs()

    private var presets: [ToolPreset] {
        ToolExposure.standardPresets(registry: ToolCatalogue.exposureRegistry)
    }

    /// Which preset card shows as ticked. Derived rather than stored, because
    /// the user can also toggle individual tools and then no single preset is
    /// the whole truth.
    private func isPresetOn(_ id: String) -> Bool {
        enabledPresets.contains(id)
    }

    private var visibleToolNames: Set<String> {
        Set(ToolCatalogue.exposure(enabledPresetIDs: enabledPresets).visible.map(\.name))
    }

    var body: some View {
        Form {
            presetsSection
            toolDetailSection
            behaviourSection
        }
        .formStyle(.grouped)
        .onChange(of: enabledPresets) { _, new in
            AgentSettingsStore.shared.applyPresets(new, to: &draft)
        }
    }

    // MARK: - Presets

    private var presetsSection: some View {
        Section {
            ForEach(presets) { preset in
                Button {
                    toggle(preset)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Image(systemName: isPresetOn(preset.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isPresetOn(preset.id) ? Color.accentColor : .secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(preset.title)
                                .foregroundStyle(.primary)
                            Text(preset.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(preset.title)
                .accessibilityHint(preset.summary)
                .accessibilityAddTraits(isPresetOn(preset.id) ? [.isSelected] : [])
            }
        } header: {
            Text(String(localized: "settings.agent.presets.title"))
        } footer: {
            Text(String(localized: "settings.agent.presets.footer"))
        }
    }

    private func toggle(_ preset: ToolPreset) {
        if let index = enabledPresets.firstIndex(of: preset.id) {
            enabledPresets.remove(at: index)
        } else {
            // Presets are ordered simplest first, so turning on "系统" without
            // "写作" would leave the user unable to write. Adding one adds
            // everything before it.
            let order = presets.map(\.id)
            let target = order.firstIndex(of: preset.id) ?? 0
            enabledPresets = Array(order.prefix(target + 1))
        }
    }

    // MARK: - Individual tools

    private var toolDetailSection: some View {
        Section {
            ForEach(ToolCategory.allCases, id: \.self) { category in
                let tools = ToolCatalogue.all.filter { $0.category == category }
                if !tools.isEmpty {
                    DisclosureGroup {
                        ForEach(tools, id: \.name) { tool in
                            Toggle(isOn: binding(for: tool)) {
                                Text(tool.name)
                                    .font(.callout.monospaced())
                            }
                            .disabled(!isPresetOn("system") && tool.category == .system)
                        }
                    } label: {
                        Text(categoryTitle(category))
                    }
                }
            }
        } header: {
            Text(String(localized: "settings.agent.tools.title"))
        } footer: {
            Text(String(localized: "settings.agent.tools.footer"))
        }
    }

    private func binding(for tool: CataloguedTool) -> Binding<Bool> {
        Binding(
            get: { visibleToolNames.contains(tool.name) },
            set: { isOn in
                var names = visibleToolNames
                if isOn {
                    names.insert(tool.name)
                } else {
                    names.remove(tool.name)
                }
                draft.prompt.visibleTools = names
                AgentSettingsStore.shared.save(draft)
                // Individual edits are no longer exactly any preset, so the
                // cards reflect the toolset rather than the preset ids.
                enabledPresets = presets
                    .filter { Set($0.tools).isSubset(of: names) }
                    .map(\.id)
            }
        )
    }

    private func categoryTitle(_ category: ToolCategory) -> String {
        String(localized: "settings.agent.category.\(category.rawValue)")
    }

    // MARK: - Behaviour

    private var behaviourSection: some View {
        Section {
            Toggle(String(localized: "settings.agent.behaviour.checkStopGates"), isOn: recoveryBinding(\.checkStopGates))
            Toggle(String(localized: "settings.agent.behaviour.continueOnTruncation"), isOn: recoveryBinding(\.continueOnTruncation))
            Toggle(String(localized: "settings.agent.behaviour.retryOnEmptyReply"), isOn: recoveryBinding(\.retryOnEmptyReply))
            Stepper(
                value: iterationsBinding,
                in: 4...200,
                step: 2
            ) {
                Text(String(localized: "settings.agent.behaviour.maxIterations"))
            }
        } header: {
            Text(String(localized: "settings.agent.behaviour.title"))
        } footer: {
            Text(String(localized: "settings.agent.behaviour.footer"))
        }
    }

    private func recoveryBinding(_ keyPath: WritableKeyPath<RecoverySettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { draft.recovery[keyPath: keyPath] },
            set: { draft.recovery[keyPath: keyPath] = $0; AgentSettingsStore.shared.save(draft) }
        )
    }

    private var iterationsBinding: Binding<Int> {
        Binding(
            get: { draft.turn.maxIterations },
            set: { draft.turn.maxIterations = $0; AgentSettingsStore.shared.save(draft) }
        )
    }
}

#Preview {
    AgentSettingsPane()
        .frame(width: 560, height: 620)
}