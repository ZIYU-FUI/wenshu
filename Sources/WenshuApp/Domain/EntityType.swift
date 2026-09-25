// Sources/WenshuApp/Domain/EntityType.swift
//
// Universal entity-type classification (= orthogonal to EntityCategory).
// EntityCategory answers 'what subject area does this belong to' (= e.g.
// I = literature, K = history). EntityType answers 'what kind of object
// is this' (= e.g. character / location / event / concept).
//
// Why both (= 2-dimensional classification)?
// - Category = subject matter (= library taxonomy)
// - Type = object nature (= domain ontology)
//
// Example: 'Li Bai' = character (type) + literature I (category).
//          'Battle of Red Cliffs' = event (type) + history K (category).
//          'Tang dynasty' = era (type) + history K (category).
//
// Codable + validated by linter + enforced by LLM classifier. First
// explicit entity-definition rule (= pre-hasher format relied on
// Python's 4 surface-form regexes, not as type).
//
// Reference: hermes-agent/skills/research/llm-wiki/SKILL.md v2.1.0 lists
// 4 entity types in its `concepts/` + `comparisons/` convention (= implicit).
// Wenshu's EntityType is more granular (= 8 + catch-all = 9) to match
// creative-writing research needs (= characters / locations / events
// / artifacts matter for fiction, not just academic research).

import Foundation

/// Top-level entity-type classification (= orthogonal to EntityCategory).
///
/// 9 cases total:
/// - 8 specific types (covers the common research objects for creative
///   writing + academic research)
/// - .other catch-all (= for entities that don't fit any specific type)
///
/// Used by `Reference.entityType` (= v0.30 new field) to enforce strict
/// schema (= Codable + LLM-extracted + linter-validated).
enum EntityType: String, CaseIterable, Codable, Sendable, Identifiable, Hashable {
    // MARK: - 8 specific types + 1 catch-all

    case character    //: a person (real or fictional)
    case location     //: a place (city, region, building, geographic feature)
    case event        //: a historical or fictional happening
    case concept      //: an abstract idea, theory, ideology, school of thought
    case artifact     //: a tangible object (weapon, tool, document, relic)
    case organization // group: a group (government, sect, party, company)
    case era          //: a time period (dynasty, century, era)
    case work         //: a creative work (poem, novel, painting, film)
    case other        // catch-all: doesn't fit any of the above

    var id: String { rawValue }

    /// Chinese display name. Active caller = EntityClassifier.swift LLM
    /// prompt (= the classifier prompt embeds Chinese labels so the LLM
    /// can map raw output back to the canonical entity type).
    var displayName: String {
        switch self {
        case .character: return "人物"
        case .location: return "地点"
        case .event: return "事件"
        case .concept: return "概念"
        case .artifact: return "物品"
        case .organization: return "组织"
        case .era: return "朝代"
        case .work: return "作品"
        case .other: return "其他"
        }
    }

    /// SF Symbols 6 icon name (= for sidebar tree display; outline-only
    /// = no .fill variant).
    var icon: String {
        switch self {
        case .character: return "person"            // SF Symbols 6: person (= canonical character badge)
        case .location: return "mappin.and.ellipse" // SF Symbols 6: location pin
        case .event: return "calendar"              // SF Symbols 6: scheduled event
        case .concept: return "lightbulb"           // SF Symbols 6: idea / concept
        case .artifact: return "shippingbox"        // SF Symbols 6: package / item
        case .organization: return "building.2"     // SF Symbols 6: institution
        case .era: return "clock"                   // SF Symbols 6: time period
        case .work: return "book.pages"             // SF Symbols 6: creative work (replaces Lucide 'book-open')
        case .other: return "questionmark.circle"   // SF Symbols 6: unknown / unclassified
        }
    }

    /// Description (= for LLM classifier prompt context).
    var description: String {
        switch self {
        case .character: return "人物: 一个真实或虚构的人 (= e.g. 李白, 杜甫, 汉尼拔, 武则天)"
        case .location: return "地点: 一个地方 (= e.g. 长安, 罗马, 赤壁, 长江)"
        case .event: return "事件: 一个历史或虚构事件 (= e.g. 赤壁之战, 贞观之治, 安史之乱)"
        case .concept: return "概念: 一个抽象思想或理论 (= e.g. 心学, 禅宗, 浪漫主义)"
        case .artifact: return "物品: 一个有形物体 (= e.g. 静夜思, 茅屋, 宝剑)"
        case .organization: return "组织: 一个机构或团体 (= e.g. 朝廷, 学派, 政党)"
        case .era: return "朝代: 一个时期 (= e.g. 唐朝, 宋朝, 文艺复兴)"
        case .work: return "作品: 一个创作 (= e.g. 诗集, 小说, 电影, 画作)"
        case .other: return "其他: 不属于以上任何类型 (= catch-all)"
        }
    }

    /// Compact representation for LLM prompt (= e.g. '1', '2', ..., '9').
    /// Used in structured LLM output like 'K 5' (= category K, type 5 = artifact).
    var promptNumber: Int {
        switch self {
        case .character: return 1
        case .location: return 2
        case .event: return 3
        case .concept: return 4
        case .artifact: return 5
        case .organization: return 6
        case .era: return 7
        case .work: return 8
        case .other: return 9
        }
    }

    /// Reverse lookup: prompt number → entity type.
    /// Returns `.other` (= safe default) if number is out of range.
    static func fromPromptNumber(_ n: Int) -> EntityType {
        switch n {
        case 1: return .character
        case 2: return .location
        case 3: return .event
        case 4: return .concept
        case 5: return .artifact
        case 6: return .organization
        case 7: return .era
        case 8: return .work
        default: return .other
        }
    }
}
