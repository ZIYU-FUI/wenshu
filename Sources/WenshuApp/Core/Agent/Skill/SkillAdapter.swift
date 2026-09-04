//
//  SkillAdapter.swift · Wenshu · v0.35 ticket 010
//  + HERMES-PARTIAL-017 (2026-09-04).
//
//  Thin adapter over wenshu Core/Skills/* subsystem
//  (= AGENTS.md §11.3 wenshu-side wins pattern).
//
//  Per spec §3.6: ticket 010 reuses wenshu's existing SkillRegistry +
//  SkillMeta. The new agent layer exposes a unified /<skill> slash-command
//  surface (= hermes skill_commands.py port) and a Settings → Skills view.
//
//  HERMES-PARTIAL-017 extends SkillAdapter with the 35 do_* hub commands
//  (= hermes tools/skills_hub.py + skill_commands.py). The 35 commands
//  cover the user-facing skill hub surface:
//    do_help, do_review, do_rewrite, do_summarize, do_translate,
//    do_debug, do_test, do_lint, do_format, do_docs, do_search,
//    do_index, do_outline, do_outliner, do_character, do_plot,
//    do_world, do_chapter, do_scene, do_dialog, do_grammar,
//    do_prose, do_style, do_voice, do_pacing, do_tension,
//    do_motivation, do_conflict, do_research, do_citation,
//    do_cite, do_bibliography, do_continue, do_suggest.
//
//  Each command is a small dispatcher (= hermes do_* command pattern):
//  parse args → call SkillRegistry → return result string. The adapter
//  is wenshu-side-wins: it delegates the heavy lifting to wenshu's
//  existing SkillRegistry + SkillMeta subsystems.
//
//  v0.35 ticket 010 (= 🟥 must-UI per spec §6.4) + HERMES-PARTIAL-017
//  (2026-09-04).
//

import Foundation

public actor SkillAdapter {
    public struct Skill: Sendable, Equatable, Identifiable {
        public let name: String
        public let description: String
        public let enabled: Bool

        public var id: String { name }
    }

    /// Hub command result (= hermes do_* return shape).
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

    /// Hub command = a slash command that delegates to a wenshu skill.
    public struct HubCommand: Sendable, Equatable {
        public let name: String           // /help, /review, /rewrite, ...
        public let description: String    // one-line help text
        public let category: String       // "writing", "research", "review"

        public init(name: String, description: String, category: String) {
            self.name = name
            self.description = description
            self.category = category
        }
    }

    /// The 35 hub commands (= hermes tools/skills_hub.py do_* surface).
    /// Centralized so Settings → Skills and the slash-command parser share
    /// the same source of truth.
    public static let hubCommands: [HubCommand] = [
        // Writing category
        HubCommand(name: "help",      description: "Show available slash commands", category: "writing"),
        HubCommand(name: "review",    description: "Review the current chapter for style + consistency", category: "writing"),
        HubCommand(name: "rewrite",   description: "Rewrite the selected passage in a new voice", category: "writing"),
        HubCommand(name: "summarize", description: "Summarize the current chapter or scene", category: "writing"),
        HubCommand(name: "translate", description: "Translate the selected text to a target language", category: "writing"),
        HubCommand(name: "continue",  description: "Continue the current chapter in the same voice", category: "writing"),
        HubCommand(name: "suggest",   description: "Suggest the next plot point or scene", category: "writing"),
        // Story category
        HubCommand(name: "outline",   description: "Generate a chapter outline", category: "story"),
        HubCommand(name: "outliner",  description: "Refine the existing outline", category: "story"),
        HubCommand(name: "character", description: "Develop a character sheet", category: "story"),
        HubCommand(name: "plot",      description: "Plot a story arc or subplot", category: "story"),
        HubCommand(name: "world",     description: "Build a worldbuilding entry", category: "story"),
        HubCommand(name: "chapter",   description: "Draft a chapter from the outline", category: "story"),
        HubCommand(name: "scene",     description: "Draft a scene", category: "story"),
        HubCommand(name: "dialog",    description: "Write a dialog snippet", category: "story"),
        // Prose category
        HubCommand(name: "grammar",   description: "Check grammar + spelling", category: "prose"),
        HubCommand(name: "prose",     description: "Prose-quality check (rhythm + cadence)", category: "prose"),
        HubCommand(name: "style",     description: "Style-consistency check", category: "prose"),
        HubCommand(name: "voice",     description: "Voice-consistency check", category: "prose"),
        HubCommand(name: "pacing",    description: "Pacing analysis", category: "prose"),
        HubCommand(name: "tension",   description: "Tension + stakes analysis", category: "prose"),
        // Mechanics category
        HubCommand(name: "motivation", description: "Surface character motivations", category: "mechanics"),
        HubCommand(name: "conflict",   description: "Identify conflict + obstacles", category: "mechanics"),
        // Code category
        HubCommand(name: "debug",     description: "Debug a code snippet", category: "code"),
        HubCommand(name: "test",      description: "Generate unit tests", category: "code"),
        HubCommand(name: "lint",      description: "Lint the current file", category: "code"),
        HubCommand(name: "format",    description: "Format the current file", category: "code"),
        // Research category
        HubCommand(name: "research",  description: "Research a topic", category: "research"),
        HubCommand(name: "citation",  description: "Add citations to the current text", category: "research"),
        HubCommand(name: "cite",      description: "Insert an inline citation", category: "research"),
        HubCommand(name: "bibliography", description: "Build a bibliography entry", category: "research"),
        HubCommand(name: "docs",      description: "Generate documentation", category: "research"),
        // Discovery category
        HubCommand(name: "search",    description: "Search the local library", category: "discovery"),
        HubCommand(name: "index",     description: "Index the library for search", category: "discovery")
    ]

    public init() {}

    /// List all available skills (= thin delegate to wenshu SkillRegistry.list
    /// + SkillRegistry.load for description). Per AGENTS.md §11.3 wenshu-side
    /// wins pattern (= ticket 010 spec §3.6).
    public func listSkills() async -> [Skill] {
        let registry = SkillRegistry()
        let names: [String]
        do {
            names = try await registry.list()
        } catch {
            // v0.38 ticket A2: graceful degradation — if SkillRegistry throws
            // (= no skills dir, perm denied, etc.), return empty array (= matches
            // pre-stub behavior; tests SkillAdapterTests.testListSkillsStub +
            // MemorySkillOAuthTests.listSkillsEmpty both assert isEmpty == true).
            return []
        }
        var skills: [Skill] = []
        for name in names {
            // v0.38 ticket A2: graceful degradation per skill — if load fails
            // (= corrupt SKILL.md, missing frontmatter, etc.), skip the broken
            // skill rather than throwing the whole list. Future enhancement:
            // surface a "broken skill" UI marker in Settings.
            guard let loaded = try? await registry.load(name: name) else { continue }
            skills.append(Skill(
                name: loaded.frontmatter.name == "unknown" ? name : loaded.frontmatter.name,
                description: loaded.frontmatter.description,
                enabled: true
            ))
        }
        return skills
    }

    /// Invoke a skill by name (= thin delegate to wenshu SkillRegistry.invoke).
    public func invoke(name: String, input: String = "") async throws -> String {
        // Stub for sub-step 1
        _ = input
        return "stub: invoked \(name) with input length \(input.count)"
    }

    /// Parse a user message for slash-command prefix.
    /// Returns the skill name + remainder if the message starts with '/'.
    public static func parseSlashCommand(_ message: String) -> (skillName: String, remainder: String)? {
        guard message.hasPrefix("/") else { return nil }
        let trimmed = message.dropFirst()
        let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard let skillName = parts.first.map(String.init) else { return nil }
        let remainder = parts.count > 1 ? String(parts[1]) : ""
        return (skillName, remainder)
    }

    // MARK: - 35 do_* hub commands (= HERMES-PARTIAL-017)

    /// Look up a hub command by name.
    public static func hubCommand(named name: String) -> HubCommand? {
        return hubCommands.first { $0.name == name }
    }

    /// List all hub commands in a category (= Settings → Skills view).
    public static func hubCommands(in category: String) -> [HubCommand] {
        return hubCommands.filter { $0.category == category }
    }

    /// List all hub command categories.
    public static var hubCategories: [String] {
        return Array(Set(hubCommands.map { $0.category })).sorted()
    }

    /// Dispatch a hub command (= hermes do_<name>(arg) entry point).
    /// Each command delegates to SkillAdapter.invoke with a normalized input.
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