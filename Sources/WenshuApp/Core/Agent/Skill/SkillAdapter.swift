//
//  SkillAdapter.swift · Wenshu · v0.35 ticket 010
//  + HERMES-PARTIAL-017 (2026-09-04)
//  + SETTINGS-PERSISTENCE-002 (2026-09-05).
//

import Foundation

enum SkillAdapterError: Error {
    case noMatch(String)
    /// Unknown skill name passed to `invoke(name:input:)` — the
    /// name is not present in `listSkills()`. Surfaces typos in
    /// chat-side slash commands as actionable errors instead of
    /// silently returning a stub string.
    case unknownSkill(name: String)
}

public actor SkillAdapter {
    public static let shared = SkillAdapter()

    public enum DefaultsKey {
        public static func skillEnabled(_ name: String) -> String {
            return "wenshu.skills.enabled.\(name)"
        }
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public struct Skill: Sendable, Equatable, Identifiable {
        public let name: String
        public let description: String
        public let enabled: Bool
        public var id: String { name }
    }

    public struct HubCommandResult: Sendable, Equatable {
        public let command: String
        public let success: Bool
        public let output: String

        public init(command: String, success: Bool, output: String) {
            self.command = command
            self.success = success
            self.output = output
        }
    }

    public struct HubCommand: Sendable, Equatable {
        public let name: String
        public let description: String
        public let category: String

        public init(name: String, description: String, category: String) {
            self.name = name
            self.description = description
            self.category = category
        }
    }

    public static let hubCommands: [HubCommand] = [
        HubCommand(name: "help", description: "Show available slash commands", category: "writing"),
        HubCommand(name: "review", description: "Review chapter", category: "writing"),
        HubCommand(name: "rewrite", description: "Rewrite passage", category: "writing"),
        HubCommand(name: "summarize", description: "Summarize chapter", category: "writing"),
        HubCommand(name: "translate", description: "Translate text", category: "writing"),
        HubCommand(name: "continue", description: "Continue chapter", category: "writing"),
        HubCommand(name: "suggest", description: "Suggest plot point", category: "writing"),
        HubCommand(name: "outline", description: "Generate outline", category: "story"),
        HubCommand(name: "outliner", description: "Refine outline", category: "story"),
        HubCommand(name: "character", description: "Character sheet", category: "story"),
        HubCommand(name: "plot", description: "Plot arc", category: "story"),
        HubCommand(name: "world", description: "Worldbuilding entry", category: "story"),
        HubCommand(name: "chapter", description: "Draft chapter", category: "story"),
        HubCommand(name: "scene", description: "Draft scene", category: "story"),
        HubCommand(name: "dialog", description: "Dialog snippet", category: "story"),
        HubCommand(name: "grammar", description: "Grammar check", category: "prose"),
        HubCommand(name: "prose", description: "Prose-quality check", category: "prose"),
        HubCommand(name: "style", description: "Style check", category: "prose"),
        HubCommand(name: "voice", description: "Voice check", category: "prose"),
        HubCommand(name: "pacing", description: "Pacing analysis", category: "prose"),
        HubCommand(name: "tension", description: "Tension analysis", category: "prose"),
        HubCommand(name: "motivation", description: "Character motivations", category: "mechanics"),
        HubCommand(name: "conflict", description: "Conflict + obstacles", category: "mechanics"),
        HubCommand(name: "debug", description: "Debug snippet", category: "code"),
        HubCommand(name: "test", description: "Generate tests", category: "code"),
        HubCommand(name: "lint", description: "Lint file", category: "code"),
        HubCommand(name: "format", description: "Format file", category: "code"),
        HubCommand(name: "research", description: "Research topic", category: "research"),
        HubCommand(name: "citation", description: "Add citations", category: "research"),
        HubCommand(name: "cite", description: "Inline citation", category: "research"),
        HubCommand(name: "bibliography", description: "Bibliography entry", category: "research"),
        HubCommand(name: "docs", description: "Generate documentation", category: "research"),
        HubCommand(name: "search", description: "Search library", category: "discovery"),
        HubCommand(name: "index", description: "Index library", category: "discovery"),
        // HERMES-AGENT-SMC-READYNESS v0.41 fix: add the 35th hub
        // command (= `cron` for scheduled-job management per the
        // audit at .scratch/hermes-agent-smc-readiness-evidence/
        // triggers.md M15: "SkillAdapter.hubCommands has no `cron`
        // entry"). The 35 count is the canonical hermes parity
        // contract (= tools/skills_hub.py ships 35 do_* functions);
        // SkillAdapterHubCommandsTests.testHubCommandsCount pins it.
        // Without this entry the test fails with hubCommands.count
        // == 34 instead of 35 and the seeder's "35 hub commands"
        // contract (= CommandPaletteRegistrySeeder.swift line 12
        // header) is wrong by one.
        HubCommand(name: "cron", description: "Manage scheduled cron jobs", category: "ops")
    ]

    public init() { self.init(defaults: .standard) }

    public func listSkills() async -> [Skill] {
        let registry = SkillRegistry()
        let names: [String]
        do {
            names = try await registry.list()
        } catch {
            return []
        }
        var skills: [Skill] = []
        for name in names {
            guard let loaded = try? await registry.load(name: name) else { continue }
            let isOn = isSkillEnabled(name: name)
            skills.append(Skill(
                name: loaded.frontmatter.name == "unknown" ? name : loaded.frontmatter.name,
                description: loaded.frontmatter.description,
                enabled: isOn
            ))
        }
        return skills
    }

    public func isSkillEnabled(name: String) -> Bool {
        let key = DefaultsKey.skillEnabled(name)
        if defaults.object(forKey: key) == nil { return true }
        return defaults.bool(forKey: key)
    }

    public func currentEnabled(name: String) -> Bool {
        return isSkillEnabled(name: name)
    }

    public func setEnabled(name: String, enabled: Bool) {
        defaults.set(enabled, forKey: DefaultsKey.skillEnabled(name))
    }

    public func invoke(name: String, input: String = "") async throws -> String {
        _ = input
        // Per `MemorySkillOAuthTests.SkillAdapter.invoke: throws for unknown
        // skill` Z contract: invoking a skill that is NOT registered in
        // the underlying SkillRegistry AND has no UserDefaults toggle
        // entry AND is not a known hub command must throw. The previous
        // implementation also blocked default-enabled names (= `isSkillEnabled`
        // returns true when no key is set) that were not in the registry,
        // which broke SettingsPersistenceTests.testSkillAdapterInvokeEnabled
        // (= "review" never toggled, but the test expects the stub string).
        // The new gate is: accept if any of (a) registry, (b) defaults key
        // present, (c) known hub command. Unknown strings with no toggle
        // activity still throw — the dispatch test then surfaces the error
        // in its `HubCommandResult` shape.
        let registeredSkills = await listSkills()
        let inRegistry = registeredSkills.contains(where: { $0.name == name })
        let inDefaults = defaults.object(forKey: DefaultsKey.skillEnabled(name)) != nil
        let inHub = Self.hubCommand(named: name) != nil
        guard inRegistry || inDefaults || inHub else {
            throw SkillAdapterError.unknownSkill(name: name)
        }
        if !isSkillEnabled(name: name) {
            return "[skill /\(name) is disabled in settings]\n\n(Available once you enable this skill in Settings → Skills.)"
        }
        return "[stub: invoked \(name) — real skill execution lands in v0.41+. The current output above is a placeholder.]"
    }

    public struct ParsedInvocation: Sendable, Equatable {
        public let skillName: String
        public let remainder: String
        public let result: String
        public let source: Source
        public enum Source: String, Sendable, Equatable {
            case slashCommand
            case keywordMatch
        }
        public init(skillName: String, remainder: String, result: String, source: Source) {
            self.skillName = skillName
            self.remainder = remainder
            self.result = result
            self.source = source
        }
    }

    public func parseAndInvoke(_ input: String, contextFiles: [String] = []) async throws -> ParsedInvocation {
        if let slash = Self.parseSlashCommand(input) {
            let result = try await invoke(name: slash.skillName, input: slash.remainder)
            return ParsedInvocation(
                skillName: slash.skillName,
                remainder: slash.remainder,
                result: result,
                source: .slashCommand
            )
        }
        if let match = await SkillKeywordMatcher.shared.match(input: input, contextFiles: contextFiles) {
            let result = try await invoke(name: match.skillName, input: input)
            return ParsedInvocation(
                skillName: match.skillName,
                remainder: input,
                result: result,
                source: .keywordMatch
            )
        }
        throw SkillAdapterError.noMatch(input)
    }

    public static func parseSlashCommand(_ message: String) -> (skillName: String, remainder: String)? {
        guard message.hasPrefix("/") else { return nil }
        let trimmed = message.dropFirst()
        let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard let skillName = parts.first.map(String.init) else { return nil }
        let remainder = parts.count > 1 ? String(parts[1]) : ""
        return (skillName, remainder)
    }

    public func routeInput(_ input: String, contextFiles: [String] = []) async throws -> (skillName: String, remainder: String) {
        if let match = await SkillKeywordMatcher.shared.match(input: input, contextFiles: contextFiles) {
            return (match.skillName, input)
        }
        if let slash = Self.parseSlashCommand(input) { return slash }
        throw SkillAdapterError.noMatch(input)
    }

    public static func hubCommand(named name: String) -> HubCommand? {
        return hubCommands.first { $0.name == name }
    }

    public static func hubCommands(in category: String) -> [HubCommand] {
        return hubCommands.filter { $0.category == category }
    }

    public static var hubCategories: [String] {
        return Array(Set(hubCommands.map { $0.category })).sorted()
    }

    public func dispatch(command: String, input: String = "") async -> HubCommandResult {
        guard let cmd = Self.hubCommand(named: command) else {
            return HubCommandResult(
                command: command,
                success: false,
                output: "Unknown hub command: /\(command). Type /help to list available commands."
            )
        }
        do {
            let result = try await invoke(name: cmd.name, input: input)
            return HubCommandResult(command: command, success: true, output: result)
        } catch {
            return HubCommandResult(
                command: command,
                success: false,
                output: "Hub command /\(command) failed: \(error)"
            )
        }
    }
}
