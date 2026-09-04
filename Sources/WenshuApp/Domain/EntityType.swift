// Sources/WenshuApp/Domain/EntityType.swift
//
// v0.30 boss 2026-08-30 OOB '分类法有没有预置大量, 因为我们无法预知用户
// [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
// 会调研什么. 实体如何定义, 是不是有规则, 你不是已经复刻了 llm wiki,
// 那里面有规则吗'. Boss chose option A: 'v0.30 加 EntityType enum +
// strict schema':
//
// = Universal entity-type classification (= orthogonal to EntityCategory).
// EntityCategory answers 'what subject area does this belong to' (= e.g.
// I = literature, K = history). EntityType answers 'what kind of object
// is this' (= e.g. character / location / event / concept).
//
// Why both (= 2-dimensional classification)?
// - Category = subject matter (= library taxonomy)
// - Type = object nature (= domain ontology)
//
// Example: '李白' = character (type) + literature I (category).
//          '赤壁之战' = event (type) + history K (category).
//          '唐朝' = era (type) + history K (category).
//
// This is the v0.30 strict schema (= codable, validated by linter, enforced
// by LLM classifier). It is the FIRST explicit entity-definition rule
// wenshu has (= previous versions relied on hermes Python's 4 regex rules
// for surface forms, not semantic type).
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
public enum EntityType: String, CaseIterable, Codable, Sendable, Identifiable, Hashable {
    // MARK: - 8 specific types + 1 catch-all

    case character    // 人物: a person (real or fictional)
    case location     // 地点: a place (city, region, building, geographic feature)
    case event        // 事件: a historical or fictional happening
    case concept      // 概念: an abstract idea, theory, ideology, school of thought
    case artifact     // 物品: a tangible object (weapon, tool, document, relic)
    case organization // 组织: a group (government, sect, party, company)
    case era          // 朝代: a time period (dynasty, century, era)
    case work         // 作品: a creative work (poem, novel, painting, film)
    case other        // catch-all: doesn't fit any of the above

    public var id: String { rawValue }

    /// Chinese display name (= boss 8/25 'UI 全中文' carve-out).
    public var displayName: String {
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

    /// v0.30 boss OOB: '别用缩写, 就是那个念, 地, 人, 全称不也就才两个字,
    /// 最多四个字, 够显示'. Full Chinese name (= 2-4 chars, plenty of
    /// sidebar space). Used as inline prefix in sidebar (= '[人物] 李白').
    public var shortName: String {
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

    /// Ultra-compact 1-char abbreviation (= only for very tight UIs
    /// like the projectPreview card header chip where space is critical).
    /// Boss OOB prefers shortName (full 2-4 char Chinese name); this
    /// 1-char variant is kept for future use but NOT the default.
    public var ultraShortName: String {
        switch self {
        case .character: return "人"
        case .location: return "地"
        case .event: return "事"
        case .concept: return "念"
        case .artifact: return "物"
        case .organization: return "组"
        case .era: return "代"
        case .work: return "作"
        case .other: return "?"
        }
    }

    /// Lucide icon name (= for sidebar tree display).
    public var icon: String {
        switch self {
        case .character: return "user-round"        // = user / person
        case .location: return "map-pin"            // = location
        case .event: return "calendar-days"        // = scheduled event
        case .concept: return "lightbulb"           // = idea / concept
        case .artifact: return "package"            // = package / item
        case .organization: return "building-2"     // = institution
        case .era: return "clock-4"                 // = time period
        case .work: return "book-open"              // = creative work
        case .other: return "circle-question-mark"   // = unknown / unclassified
        }
    }

    /// Description (= for LLM classifier prompt context).
    public var description: String {
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
    public var promptNumber: Int {
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
    public static func fromPromptNumber(_ n: Int) -> EntityType {
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