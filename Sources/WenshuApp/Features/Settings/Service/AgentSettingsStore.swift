// AgentSettingsStore.swift
//
// Persistence for the agent settings (= the app half of OOB.md #2026-10-20:
// the package owns the values, the app owns where they are stored).
//
// AgentSettings is a plain value with no UserDefaults anywhere in the package,
// so a turn runtime can be constructed with whatever the user chose and tested
// without touching global state. This is the only place the two halves meet.
//
// A settings screen edits a draft and saves it; a turn reads the saved value.
// The draft and the saved value are separate types on purpose, because a
// screen that binds straight to UserDefaults writes on every keystroke and a
// cancelled dialog has already changed the agent's behaviour.

import Foundation
import WenshuAgent

/// Reads and writes the agent settings.
@MainActor
public final class AgentSettingsStore {
    public static let shared = AgentSettingsStore()

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Keys

    /// Keys are namespaced per setting rather than per struct, so a later
    /// version can migrate one field without rewriting the rest.
    private enum Key {
        static let visibleTools = "wenshu.agent.prompt.visibleTools"
        static let promptIdentityEnabled = "wenshu.agent.prompt.identityEnabled"
        static let promptProviderGuidanceEnabled = "wenshu.agent.prompt.providerGuidanceEnabled"
        static let promptMemoryGuidanceEnabled = "wenshu.agent.prompt.memoryGuidanceEnabled"
        static let promptSkillGuidanceEnabled = "wenshu.agent.prompt.skillGuidanceEnabled"
        static let promptToolGuidanceEnabled = "wenshu.agent.prompt.toolGuidanceEnabled"
        static let promptHelpGuidanceEnabled = "wenshu.agent.prompt.helpGuidanceEnabled"
        static let promptIncludeProjectContextFiles = "wenshu.agent.prompt.includeProjectContextFiles"
        static let promptIncludeBookContext = "wenshu.agent.prompt.includeBookContext"
        static let promptIncludeEnvironmentHints = "wenshu.agent.prompt.includeEnvironmentHints"
        static let promptProjectContextFileMaxChars = "wenshu.agent.prompt.projectContextFileMaxChars"
        static let memoryBackend = "wenshu.agent.memory.backend"
        static let memoryRetentionDays = "wenshu.agent.memory.retentionDays"
        static let memoryMaxEntries = "wenshu.agent.memory.maxEntries"
        static let memoryLocalDirectory = "wenshu.agent.memory.localDirectory"
        static let memoryRemoteEndpoint = "wenshu.agent.memory.remoteEndpoint"
        static let memoryEnabled = "wenshu.agent.memory.enabled"
        static let turnMaxIterations = "wenshu.agent.turn.maxIterations"
        static let recoverySettings = "wenshu.agent.recovery"
        static let contextSettings = "wenshu.agent.context"
        static let toolsSettings = "wenshu.agent.tools"
        static let enabledPresets = "wenshu.agent.tools.enabledPresets"
        static let providerBaseURLs = "wenshu.agent.providers.baseURLs"
    }

    // MARK: - Read

    /// The saved settings. Defaults apply per field, so a setting introduced in
    /// a later version reads as its default rather than as a decode failure.
    public func load() -> AgentSettings {
        var settings = AgentSettings()
        var prompt = settings.prompt
        prompt.visibleTools = decodeStringSet(defaults, Key.visibleTools) ?? prompt.visibleTools
        prompt.identityEnabled = decodeBool(defaults, Key.promptIdentityEnabled) ?? prompt.identityEnabled
        prompt.providerGuidanceEnabled = decodeBool(defaults, Key.promptProviderGuidanceEnabled) ?? prompt.providerGuidanceEnabled
        prompt.memoryGuidanceEnabled = decodeBool(defaults, Key.promptMemoryGuidanceEnabled) ?? prompt.memoryGuidanceEnabled
        prompt.skillGuidanceEnabled = decodeBool(defaults, Key.promptSkillGuidanceEnabled) ?? prompt.skillGuidanceEnabled
        prompt.toolGuidanceEnabled = decodeBool(defaults, Key.promptToolGuidanceEnabled) ?? prompt.toolGuidanceEnabled
        prompt.helpGuidanceEnabled = decodeBool(defaults, Key.promptHelpGuidanceEnabled) ?? prompt.helpGuidanceEnabled
        prompt.includeProjectContextFiles = decodeBool(defaults, Key.promptIncludeProjectContextFiles) ?? prompt.includeProjectContextFiles
        prompt.includeBookContext = decodeBool(defaults, Key.promptIncludeBookContext) ?? prompt.includeBookContext
        prompt.includeEnvironmentHints = decodeBool(defaults, Key.promptIncludeEnvironmentHints) ?? prompt.includeEnvironmentHints
        prompt.projectContextFileMaxChars = defaults.object(forKey: Key.promptProjectContextFileMaxChars) as? Int ?? prompt.projectContextFileMaxChars
        settings.prompt = prompt

        var memory = settings.memory
        memory.backend = decodeBackend(defaults, Key.memoryBackend) ?? memory.backend
        memory.enabled = defaults.object(forKey: Key.memoryEnabled) as? Bool ?? memory.enabled
        memory.retentionDays = defaults.object(forKey: Key.memoryRetentionDays) as? Int ?? memory.retentionDays
        memory.maxEntries = defaults.object(forKey: Key.memoryMaxEntries) as? Int ?? memory.maxEntries
        memory.localDirectory = defaults.string(forKey: Key.memoryLocalDirectory) ?? memory.localDirectory
        memory.remoteEndpoint = defaults.string(forKey: Key.memoryRemoteEndpoint) ?? memory.remoteEndpoint
        settings.memory = memory

        var turn = settings.turn
        turn.maxIterations = defaults.object(forKey: Key.turnMaxIterations) as? Int ?? turn.maxIterations
        settings.turn = turn

        settings.recovery = decode(RecoverySettings.self, defaults, Key.recoverySettings) ?? settings.recovery
        settings.context = decode(ContextSettings.self, defaults, Key.contextSettings) ?? settings.context
        settings.tools = decode(ToolSettings.self, defaults, Key.toolsSettings) ?? settings.tools
        settings.providers = decodeProviderSettings(defaults) ?? settings.providers
        publishContextNumbers(settings)
        publishToolSafetyPolicy(settings)
        return settings
    }

    /// Install the saved context numbers where the runtime reads them.
    ///
    /// The package owns the values, the app owns where they are stored, so
    /// the app hands them over at the edge (= the same pattern as
    /// `ProviderEndpointOverrides`).
    ///
    /// Published on every load and every save, so the numbers the runtime
    /// reads are the ones the user last chose: the settings screen writes
    /// them and the next turn reads them.
    ///
    /// The holder is one process-wide value, so a store over a private
    /// defaults suite publishes too (= the tests restore what they found).
    private func publishContextNumbers(_ settings: AgentSettings) {
        ContextOverrides.install(
            compressionThreshold: settings.context.compressionThreshold,
            keepFraction: settings.context.compressionKeepRatio,
            memoryCap: settings.memory.maxEntries
        )
    }

    /// Install the tool-safety policy where the runtime reads it.
    ///
    /// The same edge as the context numbers: the package owns the rule,
    /// the app owns the facts (= which tools mutate, and whether the user
    /// approved the hazard class). The catalogue already flags every
    /// mutating tool, so the fact is read rather than restated.
    ///
    /// Published on every load and every save, so the policy the runtime
    /// enforces is the one the user last chose.
    private func publishToolSafetyPolicy(_ settings: AgentSettings) {
        let mutating = Set(
            ToolCatalogue.all
                .filter { $0.mutates }
                .map { $0.name }
        )
        // The unbounded tools are the ones a turn may ask for as often as
        // the round limit allows (= a search, a delegation). The catalogue
        // does not know that, so the app names them.
        let unbounded: Set<String> = ["web_search", "delegate_research", "web"]
        ToolSafetyPolicy.install(
            ToolSafetyPolicy.Values(
                mutatingToolNames: mutating,
                unboundedToolNames: unbounded,
                autoApprove: settings.tools.autoApprove
            )
        )
    }

    /// The custom endpoints, keyed by provider slug.
    ///
    /// `UserDefaults.dictionary(forKey:)` returns `[String: Any]`; a value
    /// that is not a string dictionary is ignored (= the defaults apply)
    /// rather than crashing the settings screen.
    private func decodeProviderSettings(_ defaults: UserDefaults) -> ProviderSettings? {
        guard let raw = defaults.dictionary(forKey: Key.providerBaseURLs) else { return nil }
        var baseURLs: [String: String] = [:]
        for (slug, value) in raw {
            if let url = value as? String {
                baseURLs[slug] = url
            }
        }
        return ProviderSettings(baseURLs: baseURLs)
    }

    /// Install the saved custom endpoints where the connector factory reads them.
    ///
    /// The package owns the values, the app owns where they are stored, so
    /// the app hands them over at the edge (= the same pattern as
    /// `ProviderKeychain.backend`).
    ///
    /// Nonisolated so the connector factory can call it: that function
    /// already reads UserDefaults for the active provider slug.
    nonisolated static func installProviderEndpoints() {
        let raw = UserDefaults.standard.dictionary(forKey: Key.providerBaseURLs) ?? [:]
        var baseURLs: [String: String] = [:]
        for (slug, value) in raw {
            if let url = value as? String {
                baseURLs[slug] = url
            }
        }
        ProviderEndpointOverrides.baseURLs = baseURLs
    }

    /// Preset ids the user turned on. Stored apart from the resolved tool
    /// names so the settings screen can show which cards are ticked without
    /// having to reverse-engineer the union.
    public func loadEnabledPresetIDs() -> [String] {
        defaults.stringArray(forKey: Key.enabledPresets) ?? []
    }

    // MARK: - Write

    public func save(_ settings: AgentSettings) {
        defaults.set(Array(settings.prompt.visibleTools).sorted(), forKey: Key.visibleTools)
        defaults.set(settings.prompt.identityEnabled, forKey: Key.promptIdentityEnabled)
        defaults.set(settings.prompt.providerGuidanceEnabled, forKey: Key.promptProviderGuidanceEnabled)
        defaults.set(settings.prompt.memoryGuidanceEnabled, forKey: Key.promptMemoryGuidanceEnabled)
        defaults.set(settings.prompt.skillGuidanceEnabled, forKey: Key.promptSkillGuidanceEnabled)
        defaults.set(settings.prompt.toolGuidanceEnabled, forKey: Key.promptToolGuidanceEnabled)
        defaults.set(settings.prompt.helpGuidanceEnabled, forKey: Key.promptHelpGuidanceEnabled)
        defaults.set(settings.prompt.includeProjectContextFiles, forKey: Key.promptIncludeProjectContextFiles)
        defaults.set(settings.prompt.includeBookContext, forKey: Key.promptIncludeBookContext)
        defaults.set(settings.prompt.includeEnvironmentHints, forKey: Key.promptIncludeEnvironmentHints)
        defaults.set(settings.prompt.projectContextFileMaxChars, forKey: Key.promptProjectContextFileMaxChars)
        defaults.set(settings.memory.backend.rawValue, forKey: Key.memoryBackend)
        defaults.set(settings.memory.enabled, forKey: Key.memoryEnabled)
        defaults.set(settings.memory.retentionDays, forKey: Key.memoryRetentionDays)
        defaults.set(settings.memory.maxEntries, forKey: Key.memoryMaxEntries)
        defaults.set(settings.memory.localDirectory, forKey: Key.memoryLocalDirectory)
        defaults.set(settings.memory.remoteEndpoint, forKey: Key.memoryRemoteEndpoint)
        defaults.set(settings.turn.maxIterations, forKey: Key.turnMaxIterations)
        encode(settings.recovery, defaults, Key.recoverySettings)
        encode(settings.context, defaults, Key.contextSettings)
        encode(settings.tools, defaults, Key.toolsSettings)
        defaults.set(settings.providers.baseURLs, forKey: Key.providerBaseURLs)
        publishContextNumbers(settings)
        publishToolSafetyPolicy(settings)
    }

    public func saveEnabledPresetIDs(_ ids: [String]) {
        defaults.set(ids, forKey: Key.enabledPresets)
    }

    /// Apply the presets to the prompt settings in one step, so a screen
    /// picking cards does not have to know that a preset is really a tool set.
    public func applyPresets(_ ids: [String], to settings: inout AgentSettings) {
        let exposure = ToolCatalogue.exposure(enabledPresetIDs: ids)
        settings.prompt.visibleTools = Set(exposure.visible.map(\.name))
        saveEnabledPresetIDs(ids)
        save(settings)
    }

    // MARK: - Codable plumbing

    private func decodeStringSet(_ defaults: UserDefaults, _ key: String) -> Set<String>? {
        guard let values = defaults.stringArray(forKey: key) else { return nil }
        return Set(values)
    }

    /// A stored switch, or nil when it was never written.
    ///
    /// A value that is not a bool is ignored rather than crashing the
    /// settings screen: a corrupt entry reads as the default.
    private func decodeBool(_ defaults: UserDefaults, _ key: String) -> Bool? {
        defaults.object(forKey: key) as? Bool
    }

    private func decodeBackend(_ defaults: UserDefaults, _ key: String) -> MemoryBackend? {
        guard let raw = defaults.string(forKey: key) else { return nil }
        return MemoryBackend(rawValue: raw)
    }

    private func decode<T: Decodable>(
        _ type: T.Type, _ defaults: UserDefaults, _ key: String
    ) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func encode<T: Encodable>(
        _ value: T, _ defaults: UserDefaults, _ key: String
    ) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}