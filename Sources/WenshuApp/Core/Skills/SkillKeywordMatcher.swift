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
        let candidates = keywords.values.filter { keyword in
            let textTriggers = [keyword.primaryKeyword] + keyword.aliases + keyword.contextPatterns
            let matchesText = textTriggers.contains { text.contains($0.lowercased()) }
            let matchesFile = keyword.fileTypeTriggers.contains { trigger in
                contextFiles.contains { $0.lowercased().hasSuffix(trigger.lowercased()) }
            }
            return matchesText || matchesFile
        }
        let sortedCandidates = candidates.sorted {
            if $0.priority != $1.priority { return $0.priority < $1.priority }
            return $0.skillName < $1.skillName
        }
        return sortedCandidates.first
    }
    public func matchByFileType(_ filePath: String) -> SkillKeyword? {
        keywords.values.filter { keyword in keyword.fileTypeTriggers.contains { filePath.lowercased().hasSuffix($0.lowercased()) } }.sorted { $0.priority < $1.priority }.first
    }
}
