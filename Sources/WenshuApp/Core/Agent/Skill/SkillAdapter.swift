//
//  SkillAdapter.swift · Wenshu · v0.35 ticket 010
//
//  Thin adapter over wenshu Core/Skills/* subsystem
//  (= AGENTS.md §11.3 wenshu-side wins pattern).
//
//  Per spec §3.6: ticket 010 reuses wenshu's existing SkillRegistry +
//  SkillMeta. The new agent layer exposes a unified /<skill> slash-command
//  surface (= hermes skill_commands.py port) and a Settings → Skills view.
//
//  v0.35 ticket 010 (= 🟥 must-UI per spec §6.4).
//

import Foundation

public actor SkillAdapter {
    public struct Skill: Sendable, Equatable, Identifiable {
        public let name: String
        public let description: String
        public let enabled: Bool

        public var id: String { name }
    }

    public init() {}

    /// List all available skills (= thin delegate to wenshu SkillRegistry.list).
    public func listSkills() async -> [Skill] {
        // Stub for sub-step 1; wenshu SkillRegistry wiring lands in v0.35.1
        return []
    }

    /// Invoke a skill by name (= thin delegate to wenshu SkillRegistry.invoke).
    public func invoke(name: String, input: String = "") async throws -> String {
        // Stub for sub-step 1
        _ = input
        return "stub: invoked \\(name) with input length \\(input.count)"
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
}