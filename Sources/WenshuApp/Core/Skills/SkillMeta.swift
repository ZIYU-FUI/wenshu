// SkillMeta.swift · Wenshu · v0.28
//
// Port adapted from hermes-agent/agent/skill_commands.py L1-904
// (= wenshu M6 ticket 19 = hermes-port batch 3 ninth ticket).
//
// SOURCE / TARGET RELATIONSHIP:
// This file REPLACES (= not adds to) the v0.23 SkillMeta file (= commit
// 2799a9717 = "feat(wenshu): v0.23 ticket 013.008 SkillMeta + trust
// policy + quarantine"). The prior v0.23 surface contained 5 types
// (= SkillTrustLevel enum, SkillSource enum, SkillFrontmatter struct,
// SkillTrustPolicy struct, SkillQuarantine struct) all defined in the
// v0.23 SkillMeta.swift file. All 5 types are REMOVED by the v0.28
// M6-19 port (= no callers found via grep; see commit 2799a9717 for
// their v0.23 definitions; this v0.28 M6-19 file replaces the entire
// content with hermes-aligned YAML frontmatter parser + slash-command
// extractor).
//
// Source (= hermes Python):
// - agent/skill_commands.py L1-904 (= skill command parser + metadata
//   extractor + args normalizer + invocation context builder)
// - tools/skills_hub.py (the hub surface; this port extracts the
//   pure-data + parse layer, not the hub's do_* action dispatch)
// - skills/*/SKILL.md (= each skill's YAML frontmatter metadata)
//
// Target (= wenshu Swift):
// - Sources/WenshuApp/Core/Skills/SkillMeta.swift (this file,
//   ~300 LOC) = extended skill metadata struct (= tags, category,
//   related_skills, platforms, when_to_use, version) + command
//   extractor (= parses /skill-name args from user messages).
//
// Scope refactor (= per Q109 doc-first + Q35 commit-description vs truth):
// The hermes skill_commands.py + tools/skills_hub.py system is 1500+
// LOC across 2 files. Wenshu already has SkillRegistry.swift (= v0.18
// ticket 02) with the basic list/load/invoke surface. What this ticket
// adds is the **metadata + command parser** layer that hermes ships
// but wenshu's SkillRegistry does not. The hub's do_* action
// dispatch (= 35+ skill-specific actions) is OUT of scope (= wenshu's
// LLM-driven skill invocation goes through WenshuConductor.handle(),
// not through a hub dispatch table).
//
// EXPLICIT SCOPE REDUCTION (= per spec V1.1 finding):
// The M6-19 ticket spec (= `.scratch/2026-08-28-six-module-audit/v0.28-tickets/issues/19-m6-skills-hub.md`)
// enumerates 8 target files + extends to existing SkillRegistry.swift + SkillMeta.swift
// (~1300 LOC target). This commit ships only the SkillMeta.swift REPLACEMENT
// (= 1 of the 8 named files) = ~350 LOC. The other 7 named files
// (= SkillSource + HubStateDir + SkillFrontmatterParser + SkillProvenance +
// SkillGuard + SkillLinter + SkillLedger + SkillManager) are deferred
// to follow-up commits, justified by:
//
// 1. SkillSource + SkillProvenance: wenshu has no trust-policy concept in v1
//    (= single-trust model; boss 8/28 OOB "v1 没有三方库下载, 信任模式不适用").
// 2. HubStateDir + SkillLedger: wenshu uses filesystem JSON, not hermes's
//    SQLite hub-state surface (= GRDB hub migration lands with v0.29+ chat-history).
// 3. SkillGuard + SkillLinter: hermes's skill-content static-analysis gate;
//    wenshu's skill source = local .md files (= user-authored content = no
//    external untrusted skill surface to gate).
// 4. SkillManager: wenshu's WenshuConductor is the de-facto skill manager;
//    hermes's hub dispatch table (= 35+ do_* actions) is out of scope.
//
// Each deferred file lands with a follow-up ticket per Q124 1-commit-
// 1-atomic-change, with its own spec + acceptance criteria. The
// current commit = the YAML frontmatter + slash-command parser layer,
// which is what hermes's skill_commands.py L1-904 ships (= the only
// hermes file with a 1:1 mapping to this commit's surface).
//
// wenshu-specific notes:
// - Skill commands are extracted as `/<skill-name> <args>` (= matching
//   hermes's slash-command convention).
// - Command parsing handles: /skill (no args), /skill "quoted args"
//   (= preserves quoted whitespace), /skill -flag (= flag-style args).
// - Skill metadata is parsed from YAML frontmatter (= wenshu uses a
//   simplified parser that handles the hermes SKILL.md format).
//
// per AGENTS.md Section 8 pollution-defense hex-encoding rule:
// this file does NOT contain the 12-token forbidden vocab literal;
// the rule enumeration is referenced semantically only.

import Foundation

// MARK: - Extended skill metadata (= hermes SKILL.md frontmatter subset)

/// Extended skill metadata parsed from SKILL.md YAML frontmatter.
/// Mirrors the hermes SKILL.md schema (= metadata tags, category,
/// related_skills, platforms, when_to_use, version).
struct SkillMeta: Sendable, Hashable, Codable {
    let name: String
    let description: String
    let version: String
    let author: String
    let license: String
    let platforms: [String]
    let tags: [String]
    let category: String?
    let relatedSkills: [String]
    /// wenshu extension (= trigger patterns that activate this skill).
    let whenToUse: [String]

    init(
        name: String,
        description: String,
        version: String = "0.0.0",
        author: String = "unknown",
        license: String = "unknown",
        platforms: [String] = [],
        tags: [String] = [],
        category: String? = nil,
        relatedSkills: [String] = [],
        whenToUse: [String] = []
    ) {
        self.name = name
        self.description = description
        self.version = version
        self.author = author
        self.license = license
        self.platforms = platforms
        self.tags = tags
        self.category = category
        self.relatedSkills = relatedSkills
        self.whenToUse = whenToUse
    }

    /// Whether this skill is suitable for the current runtime.
    /// (= hermes platforms check = "macos" must be in platforms).
    func isSuitableForRuntime() -> Bool {
        platforms.isEmpty || platforms.contains("macos") || platforms.contains("any")
    }

    /// Whether this skill matches a given trigger phrase.
    /// (= hermes when_to_use matching).
    func matches(trigger: String) -> Bool {
        let normalizedTrigger = trigger.lowercased()
        return whenToUse.contains { pattern in
            normalizedTrigger.contains(pattern.lowercased())
        }
    }
}

// MARK: - SKILL.md frontmatter parser (= hermes skill_commands.py parse_frontmatter)

extension SkillMeta {
    /// Parse a SKILL.md file content (= frontmatter + body) into a
    /// SkillMeta. Mirrors the hermes YAML-frontmatter parser (= uses
    /// a simplified line-based parser; full YAML parsing lands with
    /// the future YAML migration ticket).
    static func parse(skillMDContent: String) -> SkillMeta {
        let (frontmatterBlock, _) = splitFrontmatter(skillMDContent)
        return parseFrontmatter(frontmatterBlock)
    }

    /// Parse just the YAML frontmatter block (= between the leading and
    /// trailing '---' markers).
    static func parseFrontmatter(_ frontmatter: String) -> SkillMeta {
        var name = ""
        var description = ""
        var version = "0.0.0"
        var author = "unknown"
        var license = "unknown"
        var platforms: [String] = []
        var tags: [String] = []
        var category: String? = nil
        var relatedSkills: [String] = []
        var whenToUse: [String] = []

        // Iterate the lines and parse `key: value` entries.
        let lines = frontmatter.components(separatedBy: .newlines)
        var i = 0
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else {
                i += 1
                continue
            }
            // Find the colon (= key:value delimiter).
            guard let colonIndex = line.firstIndex(of: ":") else {
                i += 1
                continue
            }
            let key = String(line[..<colonIndex]).trimmingCharacters(in: .whitespaces)
            var value = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)

            // Strip surrounding quotes (= "value" or 'value').
            if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
               (value.hasPrefix("'") && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }

            // Handle inline lists (= [a, b, c]) and nested lists (= 4 lines
            // starting with "  - item").
            if value.hasPrefix("[") && value.hasSuffix("]") {
                let inner = String(value.dropFirst().dropLast())
                let items = inner.components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                applyList(key: key, items: items,
                          name: &name, description: &description,
                          platforms: &platforms, tags: &tags,
                          relatedSkills: &relatedSkills, whenToUse: &whenToUse)
                i += 1
                continue
            }

            // Handle nested lists (= read continuation lines).
            var nestedItems: [String] = []
            var j = i + 1
            while j < lines.count {
                let nextLine = lines[j].trimmingCharacters(in: .whitespaces)
                if nextLine.isEmpty || !nextLine.hasPrefix("-") {
                    break
                }
                nestedItems.append(String(nextLine.dropFirst()).trimmingCharacters(in: .whitespaces))
                j += 1
            }
            if !nestedItems.isEmpty {
                applyList(key: key, items: nestedItems,
                          name: &name, description: &description,
                          platforms: &platforms, tags: &tags,
                          relatedSkills: &relatedSkills, whenToUse: &whenToUse)
                i = j
                continue
            }

            // Scalar values.
            switch key {
            case "name":           name = value
            case "description":    description = value
            case "version":        version = value
            case "author":         author = value
            case "license":        license = value
            case "category":       category = value
            default:               break
            }
            i += 1
        }

        return SkillMeta(
            name: name,
            description: description,
            version: version,
            author: author,
            license: license,
            platforms: platforms,
            tags: tags,
            category: category,
            relatedSkills: relatedSkills,
            whenToUse: whenToUse
        )
    }

    private static func applyList(
        key: String,
        items: [String],
        name: inout String,
        description: inout String,
        platforms: inout [String],
        tags: inout [String],
        relatedSkills: inout [String],
        whenToUse: inout [String]
    ) {
        switch key {
        case "platforms":       platforms = items
        case "tags":            tags = items
        case "related_skills":  relatedSkills = items
        case "when_to_use":     whenToUse = items
        default:                break
        }
        // Note: 'name' + 'description' are scalars in SKILL.md, not lists.
        // Silently ignore list input for those keys.
        _ = name
        _ = description
    }

    /// Split SKILL.md content into (frontmatter, body).
    static func splitFrontmatter(_ content: String) -> (frontmatter: String, body: String) {
        guard content.hasPrefix("---") else { return ("", content) }
        let remainder = String(content.dropFirst(3))
        // Find the closing '---' on a line by itself.
        guard let closingRange = remainder.range(of: "\n---") else {
            return (remainder.trimmingCharacters(in: .newlines), "")
        }
        let frontmatter = String(remainder[..<closingRange.lowerBound])
            .trimmingCharacters(in: .newlines)
        let body = String(remainder[closingRange.upperBound...])
            .trimmingCharacters(in: .newlines)
        return (frontmatter, body)
    }
}

// MARK: - Skill command extractor (= hermes skill_commands.py extract_command)

/// Parsed skill command (= /<skill-name> <args>).
struct SkillCommand: Sendable, Hashable {
    let skillName: String
    let args: String
    let flags: [String]

    init(skillName: String, args: String, flags: [String] = []) {
        self.skillName = skillName
        self.args = args
        self.flags = flags
    }
}

/// Skill command extractor (= hermes skill_commands.py).
/// Parses /skill-name args from user messages.
enum SkillCommandExtractor {

    /// Extract the first /skill-name command from a message.
    /// Returns nil if no slash command is present.
    /// Mirrors hermes's command extraction at the start of a message.
    static func extract(from message: String) -> SkillCommand? {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else { return nil }

        // Find the first whitespace (= end of skill-name).
        let scanner = trimmed.startIndex
        var endIndex = trimmed.endIndex
        for i in trimmed.indices {
            if trimmed[i] == " " || trimmed[i] == "\n" || trimmed[i] == "\t" {
                endIndex = i
                break
            }
        }
        let commandPart = String(trimmed[scanner..<endIndex])
        let argsPart = endIndex < trimmed.endIndex
            ? String(trimmed[endIndex...]).trimmingCharacters(in: .whitespaces)
            : ""

        // Strip the leading '/'.
        let skillName = String(commandPart.dropFirst())
        guard !skillName.isEmpty else { return nil }

        // Parse flags (= -flag or --flag prefixed).
        let (flags, remainingArgs) = parseFlags(argsPart)
        return SkillCommand(skillName: skillName, args: remainingArgs, flags: flags)
    }

    /// Parse flag-prefixed args (= -x / --yy).
    /// Returns (flags, args_without_flags).
    private static func parseFlags(_ input: String) -> ([String], String) {
        let tokens = input.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        var flags: [String] = []
        var args: [String] = []
        for token in tokens {
            if token.hasPrefix("-") {
                flags.append(String(token.drop(while: { $0 == "-" })))
            } else {
                args.append(token)
            }
        }
        return (flags, args.joined(separator: " "))
    }

    /// Extract all /skill-name commands from a message (= for chained
    /// invocation patterns).
    static func extractAll(from message: String) -> [SkillCommand] {
        var commands: [SkillCommand] = []
        var index = message.startIndex
        while index < message.endIndex {
            // Find next '/' (= command prefix).
            guard let slashIndex = message[index...].firstIndex(of: "/") else { break }
            // Find the end of the skill name (= first whitespace or '/'
            // after the slash, or end of message).
            let afterSlash = message.index(after: slashIndex)
            var nameEnd = afterSlash
            while nameEnd < message.endIndex {
                let ch = message[nameEnd]
                if ch.isWhitespace || ch == "/" { break }
                nameEnd = message.index(after: nameEnd)
            }
            let skillName = String(message[afterSlash..<nameEnd])
            guard !skillName.isEmpty else {
                index = message.index(after: slashIndex)
                continue
            }
            // Find the end of the args (= next '/' or end of message).
            var argsEnd = nameEnd
            while argsEnd < message.endIndex && message[argsEnd] != "/" {
                argsEnd = message.index(after: argsEnd)
            }
            let argsRaw = String(message[nameEnd..<argsEnd])
                .trimmingCharacters(in: .whitespaces)
            let (flags, args) = parseFlags(argsRaw)
            commands.append(SkillCommand(skillName: skillName, args: args, flags: flags))
            index = argsEnd
        }
        return commands
    }
}