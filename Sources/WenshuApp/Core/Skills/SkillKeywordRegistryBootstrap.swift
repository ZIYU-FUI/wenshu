//
//  SkillKeywordRegistryBootstrap.swift · Wenshu · HERMES-AGENT-SMC-READYNESS T-SkillKeywordBootstrap
//
//  One-shot seeder for SkillKeywordMatcher.shared. Populates the
//  matcher at app launch (= App.swift applicationDidFinishLaunching
//  spawns a detached task calling `seed()`). Before this commit the
//  matcher was empty (= zero register callers); the chat router's
//  keyword-match path silently fell through to the LLM per the audit
//  at .scratch/hermes-agent-smc-readiness-evidence/triggers.md M1.
//
//  Bootstrap strategy (= per the audit fix path recommendation):
//    - For each SkillAdapter.hubCommand, register a SkillKeyword
//      whose primaryKeyword = the command name and aliases = the
//      slash form (/name) + natural-language words from the
//      description.
//    - fileTypeTriggers empty (= M33 stays dead by design: no
//      workspace file-open path hands extensions to the matcher yet).
//    - Priority = 50 (= hermes default; lower than a sub-agent
//      mention, which routeInput() handles before keyword matching).
//    - Idempotent: `seed()` register upserts by skillName so
//      re-running seed() (= e.g. after a Settings install) replaces
//      the prior list without duplication.
//
//  Apple stack exclusive per AGENTS.md §11.1 (= no third-party deps).
//

import Foundation

/// Seeds SkillKeywordMatcher.shared with the existing wenshu skill
/// keywords (= per the audit recommendation).
public enum SkillKeywordRegistryBootstrap {

    /// Populate the matcher. Safe to call multiple times (= the
    /// matcher's `register(_:)` is upsert-by-skillName).
    public static func seed() async {
        let keywords: [SkillKeyword] = SkillAdapter.hubCommands.map { cmd in
            SkillKeyword(
                skillName: cmd.name,
                primaryKeyword: cmd.name,
                aliases: aliasList(for: cmd),
                fileTypeTriggers: [],
                contextPatterns: [cmd.category],
                priority: 50
            )
        }
        for keyword in keywords {
            await SkillKeywordMatcher.shared.register(keyword)
        }
    }

    /// Build the alias list for a hub command. Includes the slash
    /// form (= "/name") and natural-language triggers derived from
    /// the command's description so the user can write a sentence
    /// (= "review the chapter for style") and the matcher picks up
    /// "review" → /review. Words shorter than 4 chars are dropped
    /// (= too noisy; "add" / "run" / "fix" match too much).
    private static func aliasList(for cmd: SkillAdapter.HubCommand) -> [String] {
        var aliases: [String] = ["/\(cmd.name)"]
        let descriptionWords = cmd.description
            .lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { $0.count >= 4 }
        aliases.append(contentsOf: descriptionWords)
        return aliases
    }
}
