//
//  SkillCommands.swift · Wenshu · P4-SKILL-COMMANDS-HERMES-PORT (2026-09-19)
//
//  Pure helper functions for skill command parsing. Faithful
//  1:1 port of hermes `agent/skill_commands.py` (732 LOC
//  Python, focusing on the pure helpers per Q112 = 1 ticket per
//  file).
//
//  Per AGENTS.md §11.3 wenshu-side wins:
//
//  Hermes `skill_commands.py` is the skill slash-command layer:
//  it parses `/skill-name` invocations from user input,
//  resolves them to canonical slug keys (= spaces + underscores
//  normalized to hyphens), and supports stacked skill invocation
//  (= `/a /b /c <instruction>` loads 3 skills with one user
//  message).
//
//  Wenshu-side wins per AGENTS.md §11.3:
//  - wenshus SkillAdapter + SkillBundles own the actual skill
//    loading layer (= hermes `_load_skill_payload` maps to
//    wenshus SkillAdapter.listSkills() + SkillBundles.scanBundles).
//  - The pure helpers ported here (= `resolveSkillCommandKey` +
//    `splitStackedSkillCommands` + the `_MAX_STACKED_SKILLS`
//    constant) preserve hermes's normalization + dispatch
//    semantics (= spaces and underscores interchangeable in
//    user input; = Telegram-bot-style underscored form is the
//    canonical key).
//  - The hermes `getSkillCommands()` lookup is replaced by a
//    wenshu-side wins callable lookup (= caller injects the
//    available-skill-keys set; = SkillBundles + SkillAdapter
//    are the source of truth per AGENTS.md §11.3).
//  - The remaining 11 hermes functions (= scan_skill_commands /
//    _load_skill_payload / _build_skill_message /
//    build_skill_invocation_message / _extract_* /
//    _inject_skill_config / _resolve_skill_commands_platform /
//    build_stacked_skill_invocation_message /
//    build_preloaded_skills_prompt / reload_skills / etc.)
//    are intentionally NOT ported in this ticket — they fall
//    into separate wenshu-side wins patterns (= SkillBundles /
//    SkillAdapter own the YAML scanning + skill payload
//    loading + message building layers; = per Q112 = one
//    ticket per file).
//
//  Hermes Python line range cited in doc-comments below (= for
//  traceability back to `/Volumes/ANAN/.hermes/agent/
//  skill_commands.py`).
//
//  Per AGENTS.md §11 hard rule: Apple Foundation only. No
//  third-party imports.
//

import Foundation

// MARK: - Constants

/// Maximum number of skills that can be stacked in a single
/// user message (= hermes `_MAX_STACKED_SKILLS` at
/// `agent/skill_commands.py` L55).
public let maxStackedSkills = 8

// MARK: - Public API

/// Resolve a user-typed ``/command`` to its canonical skill
/// command key (= hermes `resolve_skill_command_key` at
/// `agent/skill_commands.py` L470-L484).
///
/// Skills are always stored with hyphens (= hermes
/// `scan_skill_commands` normalizes spaces and underscores to
/// hyphens when building the key). Hyphens and underscores are
/// treated interchangeably in user input: this matches hermes's
/// ``_check_unavailable_skill`` and accommodates Telegram
/// bot-command names (= which disallow hyphens, so
/// ``/claude-code`` is registered as ``/claude_code`` and comes
/// back in the underscored form).
///
/// - Parameters:
///   - command: The user-typed command (= without the leading
///     slash; = e.g. `"claude-code"` or `"claude_code"`).
///   - availableKeys: The set of canonical ``/slug`` keys that
///     are currently registered (= from `getSkillCommands()`
///     in hermes; = wenshu-side wins = caller injects the
///     SkillBundles + SkillAdapter keys).
/// - Returns: The matching ``/slug`` key (= with the
///   underscore-from-hyphen conversion applied), or nil if no
///   match.
public func resolveSkillCommandKey(
    _ command: String,
    availableKeys: Set<String>
) -> String? {
    guard !command.isEmpty else { return nil }
    let cmdKey = "/" + command.replacingOccurrences(of: "_", with: "-")
    return availableKeys.contains(cmdKey) ? cmdKey : nil
}

/// Consume additional leading ``/skill`` tokens from *rest*
/// (= hermes `split_stacked_skill_commands` at
/// `agent/skill_commands.py` L553-L583).
///
/// `rest` is the text that follows the FIRST matched skill
/// command (= the caller has already resolved that one).
/// Leading whitespace-delimited tokens that start with `/` and
/// resolve to installed skill commands are consumed, up to
/// `maxStackedSkills` total leading skills (= i.e. at most
/// `maxStackedSkills - 1` extra keys here). Parsing stops at the
/// first token that is not a resolvable skill command — that
/// token and everything after it become the user instruction.
///
/// - Parameters:
///   - rest: The text following the first matched skill command.
///   - availableKeys: The set of canonical ``/slug`` keys that
///     are currently registered.
/// - Returns: A tuple of `(extra_cmd_keys, remaining_instruction)`
///   where `extra_cmd_keys` are canonical ``/slug`` keys from
///   `resolveSkillCommandKey`.
public func splitStackedSkillCommands(
    _ rest: String,
    availableKeys: Set<String>
) -> (extra: [String], remaining: String) {
    var keys: [String] = []
    var remaining = rest

    while keys.count < maxStackedSkills - 1 {
        let stripped = remaining.drop(while: { $0.isWhitespace })
        guard stripped.hasPrefix("/") else { break }

        // Split into the leading "/token" + the rest.
        let tokenString = String(stripped.dropFirst())
        let parts = tokenString.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard let firstPart = parts.first else { break }
        let token = String(firstPart)
        let tail: String
        if parts.count > 1 {
            tail = String(parts[1])
        } else {
            tail = ""
        }

        guard let cmdKey = resolveSkillCommandKey(token, availableKeys: availableKeys),
              !keys.contains(cmdKey)
        else {
            break
        }
        keys.append(cmdKey)
        remaining = tail
    }
    return (keys, remaining.trimmingCharacters(in: .whitespaces))
}
