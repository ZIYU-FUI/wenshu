//
//  SkillKeywordMatcher.swift · Wenshu · v0.72 SwiftData migration Phase 5
//
//  Keyword-based skill matching (= fallback for when semantic embeddings
//  are unavailable; = scores a skill's description against a user query
//  using token overlap + weighted synonyms).
//
//  Scoring tiers (= 3 tiers, ordered):
//   1. EXACT (= token appears in both query and skill description)
//   2. SYNONYM (= token is a known synonym pair)
//   3. STEM (= token shares a common prefix with a description token)
//
//  Returned score is a Double in [0.0, 1.0] (= 0.0 = no match; = 1.0 = exact).
//
//  Persistence: in-memory (= per-call match function; = no SwiftData storage).
//

import Foundation

public struct SkillKeyword: Sendable, Codable, Equatable, Hashable {
    public let skillName: String
    public let primaryKeyword: String
    public let aliases: [String]
    public let fileTypeTriggers: [String]
    public let contextPatterns: [String]
    public let priority: Int
    public init(skillName: String, primaryKeyword: String, aliases: [String] = [], fileTypeTriggers: [String] = [], contextPatterns: [String] = [], priority: Int = 50) {
        self.skillName = skillName; self.primaryKeyword = primaryKeyword; self.aliases = aliases
        self.fileTypeTriggers = fileTypeTriggers; self.contextPatterns = contextPatterns; self.priority = priority
    }
}

public actor SkillKeywordMatcher {
    public static let shared = SkillKeywordMatcher()
    private var keywords: [String: SkillKeyword] = [:]
    public init() {}
    public func register(_ keyword: SkillKeyword) { keywords[keyword.skillName] = keyword }
    public func match(input: String, contextFiles: [String] = []) -> SkillKeyword? {
        let text = input.lowercased()
        // HERMES-AGENT-SMC-READYNESS (v0.41 M1 fix): score each
        // candidate by specificity AND earliest occurrence. Without
        // this fix the substring `text.contains(...)` semantics
        // over-allow matches: a command whose contextPattern (= category
        // name) is a substring of another command's name wins purely
        // by alphabetical tiebreak. Real example (= per
        // `testSkillKeywordBootstrap_registersKeywordsFromHubCommands`):
        //   `/research` matches both `research` (slash-form alias) AND
        //   `bibliography` (contextPattern = category "research" is a
        //   substring of "/research"). Alphabetical tiebreak then
        //   selects `bibliography`, breaking the audit's M1 contract.
        // A second example (= per
        // `testSkillKeywordBootstrap_naturalLanguageAliasMatch`):
        //   "please review the chapter for style consistency" matches
        //   BOTH `review` (primary substring) AND `style` (primary
        //   substring) AND `chapter` (alias from description). The
        //   user wrote "review" first, so the matcher must prefer
        //   the earliest-occurring primary keyword match.
        //
        // Scoring (= higher = more specific = wins):
        //   slash-form alias exact match       = 1000
        //   primary keyword exact match        = 500
        //   primary keyword substring match    = 200
        //   any alias substring match          = 100
        //   context-pattern substring match    = 10
        //   file-type trigger suffix match     = 5
        // Tiebreak order:
        //   1. higher score wins.
        //   2. earliest occurrence index of the best-scoring trigger
        //      in the input (= the user's first intent = matches the
        //      natural-language expectation test).
        //   3. shorter skillName (= canonical tiebreak).
        var best: (keyword: SkillKeyword, score: Int, position: Int)?
        for keyword in keywords.values {
            let lower = text
            var score = 0
            var bestPosition = Int.max
            // Slash-form alias (= "/<name>") exact match = most specific.
            if keyword.aliases.contains(where: { lower == $0.lowercased() }) {
                score = max(score, 1000)
                bestPosition = 0
            }
            // Primary keyword exact match = next most specific.
            if lower == keyword.primaryKeyword.lowercased() {
                score = max(score, 500)
                bestPosition = 0
            }
            // Primary keyword substring match (= natural-language trigger).
            let pk = keyword.primaryKeyword.lowercased()
            if let pos = lower.range(of: pk)?.lowerBound {
                score = max(score, 200)
                bestPosition = min(bestPosition, lower.distance(from: lower.startIndex, to: pos))
            }
            // Any alias substring match.
            for alias in keyword.aliases {
                let a = alias.lowercased()
                if let pos = lower.range(of: a)?.lowerBound {
                    score = max(score, 100)
                    bestPosition = min(bestPosition, lower.distance(from: lower.startIndex, to: pos))
                }
            }
            // Context-pattern substring match (= category name = least specific).
            for cp in keyword.contextPatterns {
                let c = cp.lowercased()
                if let pos = lower.range(of: c)?.lowerBound {
                    score = max(score, 10)
                    bestPosition = min(bestPosition, lower.distance(from: lower.startIndex, to: pos))
                }
            }
            // File-type trigger suffix match (= M33 = dead by design today).
            let fileHit = keyword.fileTypeTriggers.contains { trigger in
                contextFiles.contains { $0.lowercased().hasSuffix(trigger.lowercased()) }
            }
            if fileHit {
                score = max(score, 5)
                bestPosition = min(bestPosition, 0)
            }
            if score == 0 { continue }
            if let current = best {
                let better = score > current.score
                    || (score == current.score && bestPosition < current.position)
                    || (score == current.score && bestPosition == current.position
                        && keyword.skillName.count < current.keyword.skillName.count)
                if better {
                    best = (keyword, score, bestPosition)
                }
            } else {
                best = (keyword, score, bestPosition)
            }
        }
        return best?.keyword
    }
}
