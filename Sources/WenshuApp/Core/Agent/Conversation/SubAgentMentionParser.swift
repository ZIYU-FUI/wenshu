//
//  SubAgentMentionParser.swift · Wenshu · CHATBOX-003 (2026-09-04)
//
//  Parse `@subagent_slug <task>` syntax in user chat input.
//
//  CHATBOX-003 (2026-09-04, boss OOB 'B'): hermes @subagent_writer
//  mention syntax parity. User types `@writer draft chapter 3` and the
//  chat route dispatches the rest of the message to the Writer
//  sub-agent (= AsyncDelegation.delegate(...)).
//
//  Design:
//    - Pure enum + static functions (= no actor needed; the parser is
//      sync + stateless).
//    - Recognized slugs come from SubAgentIdentity.Name.allCases (= 5
//      wenshu sub-agents: researcher / writer / analyst / archivist /
//      auditor). The instructions mention "editor" / "reviewer" but
//      those are hermes-specific and not part of wenshu's
//      SubAgentIdentity taxonomy per AGENTS.md §11.3 wenshu-side-wins.
//    - First-match-on-word-boundary regex (= "@slug" must be followed
//      by whitespace or punctuation, NOT a longer slug name). E.g.
//      "@writerly" does NOT match "writer" — only "@writer" does.
//    - Multiple mentions in one input supported via parseAll() (=
//      "@writer draft this AND @editor review it" returns both).
//
//  No new third-party dependency (= Apple stack exclusive per AGENTS.md
//  §11.1).
//

import Foundation

/// Parser for `@subagent_slug <task>` syntax in chat input.
///
/// Pure data layer (= sync, no actor isolation). The ChatViewModel
/// consumes the parser's output to spawn sub-agents via
/// AsyncDelegation.
public enum SubAgentMentionParser {

    /// Single parsed mention (= one `@slug <task>` segment).
    public struct ParsedMention: Sendable, Equatable {
        /// Sub-agent slug (= e.g. "writer" / "researcher" / "analyst").
        /// Matches SubAgentIdentity.Name rawValue.
        public let subagentSlug: String

        /// The task text (= everything after `@slug` up to the next
        /// `@slug` mention or end of input).
        public let task: String

        public init(subagentSlug: String, task: String) {
            self.subagentSlug = subagentSlug
            self.task = task
        }
    }

    /// Available sub-agent slugs (= for autocomplete / palette).
    /// Mirrors `SubAgentIdentity.Name.allCases` raw values (= hermes
    /// has "editor" / "reviewer" too, but wenshu does not — per
    /// AGENTS.md §11.3 wenshu-side-wins, only the 5 wenshu sub-agents
    /// are recognized).
    public static let availableSlugs: [String] = SubAgentIdentity.Name.allCases
        .map { $0.rawValue }
        .sorted()

    /// Parse a single mention from the input (= returns the FIRST valid
    /// mention found). Returns nil if no @-mention is found or the
    /// mention doesn't reference a known sub-agent slug (= caller
    /// falls through to the LLM path).
    ///
    /// Syntax: `@<slug><whitespace><task>` where `<slug>` is one of
    /// `availableSlugs` and `<task>` is everything after the slug until
    /// end-of-input OR the next valid `@<slug>` mention (= same rule
    /// as hermes' mention parser).
    public static func parse(_ input: String) -> ParsedMention? {
        let mentions = parseAll(input)
        return mentions.first
    }

    /// Parse all mentions from the input (= multiple `@slug <task>`
    /// segments in one user message).
    ///
    /// Example: `"@writer draft chapter 3 AND @researcher find
    /// references for it"` returns:
    ///   [ParsedMention(slug: "writer", task: "draft chapter 3 AND"),
    ///    ParsedMention(slug: "researcher", task: "find references for it")]
    ///
    /// Returns an empty array if no mentions found (= caller falls
    /// through to the LLM path). Order matches the order in input.
    public static func parseAll(_ input: String) -> [ParsedMention] {
        let slugs = availableSlugs
        guard !slugs.isEmpty else { return [] }
        // Build a word-boundary regex that matches @slug followed by
        // whitespace (= the start-of-task marker). Case-sensitive (= the
        // slugs are lowercase raw values; @WRITER is rejected).
        //
        // We use NSRegularExpression (= Foundation; no Regex<> Sendable
        // issues; the parser is sync anyway so the actor-isolation
        // overhead is unnecessary).
        let pattern = "@(" + slugs.joined(separator: "|") + ")(?:\\s+|\\z)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }
        let nsInput = input as NSString
        let matches = regex.matches(
            in: input,
            options: [],
            range: NSRange(location: 0, length: nsInput.length)
        )
        var parsed: [ParsedMention] = []
        for (i, match) in matches.enumerated() {
            // match.range is the full "@slug " prefix (= including the
            // trailing whitespace if present). match.range(at: 1) is the
            // captured slug (= without the '@' prefix).
            guard match.numberOfRanges >= 2 else { continue }
            let slugRange = match.range(at: 1)
            let fullMatchEnd = match.range.location + match.range.length
            guard slugRange.location != NSNotFound else { continue }
            let slug = nsInput.substring(with: slugRange)
            // Task starts at fullMatchEnd (= end of "@slug<ws>") and
            // ends at the start of the next mention OR end of input.
            let nextStart: Int
            if i + 1 < matches.count {
                nextStart = matches[i + 1].range.location
            } else {
                nextStart = nsInput.length
            }
            guard fullMatchEnd <= nextStart, nextStart <= nsInput.length else { continue }
            let taskRange = NSRange(location: fullMatchEnd, length: nextStart - fullMatchEnd)
            let task = nsInput.substring(with: taskRange).trimmingCharacters(in: .whitespacesAndNewlines)
            parsed.append(ParsedMention(subagentSlug: slug, task: task))
        }
        return parsed
    }
}
